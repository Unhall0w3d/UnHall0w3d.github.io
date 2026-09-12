#!/usr/bin/env python3
"""Update one or more BLF labels per phone while preserving the full collection.

Python 3.10+, requests, zeep, and a local Cisco AXL 14.0/15.0 toolkit.
Dry-run by default. Every run produces a private JSONL report. See README.md.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from copy import deepcopy
import csv
from datetime import datetime, timezone
import getpass
import ipaddress
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
import shutil
import stat
import tempfile
import zipfile
import warnings
import uuid
import xml.etree.ElementTree as ET

import requests
from urllib3.exceptions import InsecureRequestWarning
from zeep import Client, Settings, xsd
from zeep.helpers import serialize_object
from zeep.transports import Transport

SOAP = 'http://schemas.xmlsoap.org/soap/envelope/'
AXL = 'http://www.cisco.com/AXL/API/'
SUPPORTED = ('15.0', '14.0')
BLF_FIELDS = {'index', 'label', 'asciiLabel', 'blfDest', 'blfDirn',
              'routePartition', 'associatedBlfSdFeatures'}


class CheckError(RuntimeError):
    pass


def host(value):
    candidate = value[1:-1] if value.startswith('[') and value.endswith(']') else value
    try:
        address = ipaddress.ip_address(candidate)
        if '%' in candidate:
            raise ValueError('Scoped addresses are not supported')
        return f'[{address}]' if address.version == 6 else str(address)
    except ValueError:
        if len(value) <= 253 and all(re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?', s)
                                    for s in value.rstrip('.').split('.')):
            return value.lower()
    raise argparse.ArgumentTypeError('Use a hostname or IP without URL, credentials, or port')


def clean_text(value, field, empty=True):
    if value is None and empty:
        return ''
    if not isinstance(value, str) or (not value and not empty):
        raise CheckError(f'{field}: expected {"nonempty " if not empty else ""}text')
    if any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise CheckError(f'{field}: control characters are not allowed')
    return value


def load_updates(path, match_index=False):
    groups = defaultdict(list)
    seen = set()
    required = {'device', 'destination', 'partition', 'new_label'}
    if match_index:
        required.add('buttonindex')
    with Path(path).open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.reader(stream, strict=True)
        headers = [s.strip().lower() for s in next(reader, [])]
        if len(headers) != len(required) or set(headers) != required:
            raise CheckError('CSV requires exactly: ' + ','.join(sorted(required)))
        for values in reader:
            if not values or all(not s.strip() for s in values):
                continue
            if len(values) != len(headers):
                raise CheckError(f'CSV line {reader.line_num}: wrong field count')
            row = dict(zip(headers, (s.strip() for s in values)))
            for key, value in row.items():
                clean_text(value, key, empty=key == 'partition')
            row['device'] = row['device'].upper()
            if not re.fullmatch(r'SEP[0-9A-F]{12}', row['device']):
                raise CheckError(f'CSV line {reader.line_num}: expected SEP plus 12 hex digits')
            index = row.get('buttonindex')
            if index is not None:
                if not index.isascii() or not index.isdecimal() or int(index) < 1:
                    raise CheckError('buttonindex must be a positive integer')
                index = int(index)
            row['buttonindex'] = index
            row['line_number'] = reader.line_num
            identity = (row['device'], row['destination'], row['partition'], index)
            if identity in seen:
                raise CheckError(f'CSV line {reader.line_num}: duplicate/conflicting target')
            seen.add(identity)
            groups[row['device']].append(row)
    if not groups:
        raise CheckError('CSV contains no targets')
    return dict(groups)


class Session(requests.Session):
    """No redirects, no automatic retries; retain TLS verification and cookies."""
    def request(self, method, url, **kwargs):
        kwargs['allow_redirects'] = False
        if self.verify is False:
            kwargs['verify'] = False  # Explicit override also takes precedence over CA environment variables.
        with warnings.catch_warnings():
            if self.verify is False:
                warnings.simplefilter('ignore', InsecureRequestWarning)
            response = super().request(method, url, **kwargs)
        if 300 <= response.status_code < 400:
            raise CheckError('HTTP redirect rejected')
        return response


def local(tag):
    return tag.rsplit('}', 1)[-1]


def negotiate(session, endpoint, timeout):
    """Read-only negotiation. Retry only a server-advertised version mismatch."""
    version, attempted, evidence = '14.0', set(), []
    while version not in attempted:
        attempted.add(version)
        body = (f'<s:Envelope xmlns:s="{SOAP}" xmlns:a="{AXL}{version}">'
                '<s:Body><a:getCCMVersion/></s:Body></s:Envelope>')
        response = session.post(endpoint, data=body.encode(), timeout=timeout,
                                headers={'Content-Type': 'text/xml; charset=utf-8',
                                         'SOAPAction': f'CUCM:DB ver={version} "getCCMVersion"'})
        if response.status_code in (401, 403):
            raise CheckError('AXL authentication/authorization failed; no schema retry')
        if response.status_code != 200:
            text = response.text
            if 'incorrect axl version' not in text.lower():
                raise CheckError(f'AXL discovery HTTP {response.status_code}; no schema retry')
            match = re.search(r'Supported\s+axl\s+versions\s+are\s+([^<\r\n]+)', text, re.I)
            advertised = re.findall(r'\d+(?:\.\d+|\.x)?', match[1], re.I) if match else []
            normalized = {v.lower().replace('.x', '.0') for v in advertised}
            evidence.append({'attempted_schema': version, 'advertised_schemas': sorted(normalized)})
            version = next((v for v in SUPPORTED if v in normalized and v not in attempted), None)
            if version is None:
                raise CheckError('No untried supported schema in the server response')
            continue
        try:
            root = ET.fromstring(response.content)
        except ET.ParseError as exc:
            raise CheckError('AXL discovery returned invalid XML') from exc
        soap_body = root.find(f'{{{SOAP}}}Body')
        if root.tag != f'{{{SOAP}}}Envelope' or soap_body is None or len(soap_body) != 1:
            raise CheckError('Unexpected discovery SOAP response')
        result = soap_body[0]
        if result.tag != f'{{{AXL}{version}}}getCCMVersionResponse':
            raise CheckError('Discovery response schema or operation mismatch')
        versions = [e.text.strip() for e in result.iter()
                    if local(e.tag) == 'version' and e.text and e.text.strip()]
        if len(versions) != 1:
            raise CheckError('Expected one CUCM version in discovery response')
        software = clean_text(versions[0], 'CUCM version', empty=False)
        if not re.match(r'^(14|15)\.', software):
            raise CheckError('This utility is restricted to CUCM 14/15')
        evidence.append({'accepted_schema': version, 'cucm_version': software})
        return version, software, evidence
    raise CheckError('Schema discovery exhausted')


class LocalTransport(Transport):
    """Toolkit files must be local and contained in the selected toolkit tree."""
    def __init__(self, toolkit_root, **kwargs):
        super().__init__(**kwargs)
        self.toolkit_root = toolkit_root.resolve()

    def load(self, url):
        from urllib.parse import urlparse
        from urllib.request import url2pathname
        # Windows drive paths are local paths, not URL schemes.
        if Path(str(url)).is_absolute():
            path = Path(str(url)).resolve()
        else:
            parsed = urlparse(str(url))
            if parsed.scheme not in ('', 'file') or parsed.netloc:
                raise CheckError('Remote WSDL/XSD imports are not permitted')
            path = Path(url2pathname(parsed.path) if parsed.scheme == 'file' else str(url)).resolve()
        if not path.is_relative_to(self.toolkit_root):
            raise CheckError('Schema import escapes the selected toolkit directory')
        return path.read_bytes()


MAX_ZIP_BYTES = 64 * 1024 * 1024
MAX_UNPACKED_BYTES = 256 * 1024 * 1024
MAX_ZIP_ENTRIES = 5000


def extract_schemas(archive, destination):
    """Validate every archive member; extract only WSDL/XSD files, never code."""
    from pathlib import PurePosixPath
    with zipfile.ZipFile(archive) as source:
        entries = source.infolist()
        if len(entries) > MAX_ZIP_ENTRIES or sum(e.file_size for e in entries) > MAX_UNPACKED_BYTES:
            raise CheckError('Toolkit ZIP exceeds extraction limits')
        seen = set()
        selected = []
        for entry in entries:
            name = entry.filename
            parts = name.rstrip('/').split('/')
            path = PurePosixPath(name)
            mode = entry.external_attr >> 16
            if (not name or path.is_absolute() or '\\' in name or ':' in name
                    or any(part in ('', '.', '..') or part.endswith((' ', '.'))
                           or re.fullmatch(r'(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?', part, re.I)
                           or any(ord(c) < 32 or ord(c) == 127 for c in part) for part in parts)
                    or stat.S_ISLNK(mode)
                    or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)
                    or entry.flag_bits & 1):
                raise CheckError('Toolkit ZIP contains an unsafe path, link, or encrypted entry')
            key = '/'.join(parts).casefold()
            if key in seen:
                raise CheckError('Toolkit ZIP contains duplicate or case-colliding paths')
            seen.add(key)
            if not entry.is_dir() and path.suffix.lower() in ('.wsdl', '.xsd'):
                selected.append((entry, destination.joinpath(*parts)))
        total = 0
        for entry, output in selected:
            output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with source.open(entry) as data, output.open('xb') as target:
                while chunk := data.read(65536):
                    total += len(chunk)
                    if total > MAX_UNPACKED_BYTES:
                        raise CheckError('Toolkit extraction exceeded its byte limit')
                    target.write(chunk)
        return len(selected)


def matching_wsdl(root, version):
    candidates = []
    for path in root.rglob('*'):
        if not path.is_file() or path.name.lower() != 'axlapi.wsdl':
            continue
        # Namespace declarations and import attributes both identify the schema.
        namespaces = {ns for _, (_, ns) in ET.iterparse(path, events=('start-ns',))}
        tree = ET.parse(path)
        namespaces.update(e.get('namespace') for e in tree.iter())
        if AXL + version in namespaces:
            candidates.append(path)
    preferred = [path for path in candidates if path.parent.name == version]
    candidates = preferred or candidates
    if len(candidates) != 1:
        raise CheckError(f'Toolkit must contain one unambiguous WSDL for accepted schema {version}; found {len(candidates)}')
    return candidates[0]


def ensure_toolkit(explicit, schema_dir, version, session, endpoint, timeout, journal):
    if version not in SUPPORTED:
        raise CheckError('Unsupported toolkit version')
    cache = Path(schema_dir).expanduser().resolve()
    directory = cache / version
    path = Path(explicit).expanduser().resolve() if explicit else directory / 'AXLAPI.wsdl'
    if path.is_file():
        journal.write('toolkit_local', wsdl=str(path), accepted_schema=version)
        return path
    if explicit:
        raise CheckError(f'Explicit WSDL does not exist: {path}; not substituting a download')
    if directory.exists() or directory.is_symlink():
        raise CheckError(f'Local toolkit directory is incomplete: {directory}; preserve/review it or select another --schema-dir')
    # This URL is derived only from the authenticated AXL endpoint, never a redirect.
    from urllib.parse import urlsplit, urlunsplit
    origin = urlsplit(endpoint)
    if origin.scheme != 'https' or origin.username or origin.password or origin.path != '/axl/':
        raise CheckError('Invalid publisher endpoint for toolkit download')
    url = urlunsplit((origin.scheme, origin.netloc, '/plugins/axlsqltoolkit.zip', '', ''))
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = cache / f'.{version}.install-lock'
    try:
        lockfd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise CheckError(f'Toolkit setup is already running or left a lock: {lock}') from exc
    os.close(lockfd)
    try:
        if directory.exists() or directory.is_symlink():
            raise CheckError('Toolkit directory appeared during setup; rerun to use/review it')
        print(f'Local schema {version} missing; downloading AXL toolkit from the publisher...')
        journal.write('toolkit_download_started', url=url, accepted_schema=version,
                      tls_verification=session.verify is not False)
        with tempfile.TemporaryDirectory(prefix='.toolkit-', dir=cache) as temp:
            stage = Path(temp)
            archive = stage / 'toolkit.zip'
            digest, size = hashlib.sha256(), 0
            with session.get(url, stream=True, timeout=timeout) as response:
                if response.status_code in (401, 403):
                    raise CheckError('Publisher denied toolkit download with this login; download through Application > Plugins and use --wsdl')
                if response.status_code != 200:
                    raise CheckError(f'Toolkit download HTTP {response.status_code}; no redirects or login-page fallback')
                with archive.open('xb') as output:
                    for chunk in response.iter_content(chunk_size=65536):
                        size += len(chunk)
                        if size > MAX_ZIP_BYTES:
                            raise CheckError('Toolkit ZIP exceeds download size limit')
                        digest.update(chunk)
                        output.write(chunk)
            if not zipfile.is_zipfile(archive):
                raise CheckError('Publisher response is not a ZIP toolkit (possibly an HTML login page)')
            unpacked = stage / 'unpacked'
            unpacked.mkdir(mode=0o700)
            files = extract_schemas(archive, unpacked)
            selected = matching_wsdl(unpacked, version)
            # Load the staged toolkit with local-only imports before placing it in the cache.
            PhoneClient(session, endpoint, selected, version, timeout)
            if directory.exists() or directory.is_symlink():
                raise CheckError('Refusing to replace an existing toolkit directory')
            selected_name = selected.name
            selected.parent.rename(directory)
            path = directory / selected_name
            # Standardize only the WSDL filename for subsequent cache lookups.
            if selected_name != 'AXLAPI.wsdl':
                path.rename(directory / 'AXLAPI.wsdl')
                path = directory / 'AXLAPI.wsdl'
            journal.write('toolkit_downloaded', url=url, accepted_schema=version,
                          wsdl=str(path), archive_sha256=digest.hexdigest(),
                          archive_bytes=size, extracted_schema_files=files)
            print(f'Installed schema {version}: {path}')
            return path
    finally:
        lock.unlink()


def scalar(value, field):
    # Some AXL return types wrap text with a UUID attribute.
    if isinstance(value, dict):
        if set(value) - {'_value_1', 'uuid'} or '_value_1' not in value:
            raise CheckError(f'Unsupported {field} representation')
        value = value['_value_1']
    return clean_text(value, field)


def canonical_blfs(raw):
    if raw is None:
        return []
    if not isinstance(raw, dict) or set(raw) != {'busyLampField'}:
        raise CheckError('Incomplete or unexpected busyLampFields structure')
    items = raw['busyLampField']
    if items is None:
        return []
    if not isinstance(items, list):
        raise CheckError('BLF collection is not a list')
    result, indexes = [], set()
    for item in items:
        if not isinstance(item, dict) or set(item) - BLF_FIELDS:
            raise CheckError('Unsupported BLF fields; refusing a lossy replacement')
        item = deepcopy(item)
        try:
            index = int(str(item.get('index', '')))
        except ValueError as exc:
            raise CheckError('Invalid BLF index') from exc
        if index < 1 or index in indexes:
            raise CheckError('Missing/duplicate/invalid BLF index')
        indexes.add(index)
        item['index'] = index
        for key in ('blfDirn', 'blfDest', 'routePartition', 'label'):
            item[key] = scalar(item.get(key), key)
        if 'asciiLabel' in item:
            item['asciiLabel'] = scalar(item['asciiLabel'], 'asciiLabel')
        if bool(item['blfDirn']) == bool(item['blfDest']):
            raise CheckError('BLF must have exactly one destination representation')
        if item['blfDest'] and item['routePartition']:
            raise CheckError('Free-form BLF has an unexpected partition')
        result.append(item)
    return sorted(result, key=lambda item: item['index'])


def prepare(before, targets):
    after = deepcopy(before['blfs'])
    touched, changes = set(), []
    for target in targets:
        # This utility changes directory-number BLFs only. Free-form entries are preserved.
        matches = [b for b in after if b['blfDirn'] == target['destination']
                   and b['routePartition'] == target['partition']
                   and (target['buttonindex'] is None or b['index'] == target['buttonindex'])]
        if len(matches) != 1:
            raise CheckError(f"CSV line {target['line_number']}: expected one DN/partition BLF; found {len(matches)}")
        entry = matches[0]
        if entry['index'] in touched:
            raise CheckError('Multiple CSV rows resolve to the same BLF index')
        touched.add(entry['index'])
        changes.append({'index': entry['index'], 'destination': target['destination'],
                        'partition': target['partition'], 'old_label': entry['label'],
                        'new_label': target['new_label'],
                        'status': 'already_ok' if entry['label'] == target['new_label'] else 'update_needed'})
        entry['label'] = target['new_label']
    return after, changes


class PhoneClient:
    def __init__(self, session, endpoint, wsdl, version, timeout):
        transport = LocalTransport(wsdl.parent, session=session, timeout=timeout, operation_timeout=timeout)
        self.client = Client(str(wsdl), transport=transport,
                             settings=Settings(strict=True, forbid_dtd=True, forbid_entities=True,
                                               forbid_external=True))
        self.service = self.client.create_service('{http://www.cisco.com/AXLAPIService/}AXLAPIBinding', endpoint)
        self.version = version
        self.blf_type = self.client.get_type(f'{{{AXL}{version}}}XBusyLampField')
        self.fields = {name for name, _ in self.blf_type.elements}
        if not {'index', 'label', 'blfDest', 'blfDirn', 'routePartition'} <= self.fields:
            raise CheckError('Loaded XBusyLampField lacks expected fields')

    def read(self, device):
        response = serialize_object(self.service.getPhone(name=device), target_cls=dict)
        if not isinstance(response, dict) or not isinstance(response.get('return'), dict):
            raise CheckError('Missing getPhone return')
        phone = response['return'].get('phone')
        if not isinstance(phone, dict) or phone.get('name') != device or 'busyLampFields' not in phone:
            raise CheckError('Phone identity or complete BLF collection missing')
        try:
            identity = str(uuid.UUID(phone.get('uuid', '')))
        except (ValueError, AttributeError) as exc:
            raise CheckError('Missing/invalid phone UUID') from exc
        return {'device': device, 'uuid': identity,
                'blfs': canonical_blfs(phone['busyLampFields']),
                'raw_blfs': deepcopy(phone['busyLampFields']),
                'speeddials': deepcopy(phone.get('speeddials')),
                'blfDirectedCallParks': deepcopy(phone.get('blfDirectedCallParks'))}

    def payload(self, blfs):
        result = []
        for entry in blfs:
            if set(entry) - self.fields:
                raise CheckError('Read BLF fields cannot all be represented by the write schema')
            item = deepcopy(entry)
            if item['blfDirn']:
                item['blfDest'] = xsd.SkipValue
            else:
                item['blfDirn'] = xsd.SkipValue
                item['routePartition'] = xsd.SkipValue
            result.append(item)
        return {'busyLampField': result}

    def validate_payload(self, identity, blfs):
        message = self.client.create_message(self.service, 'updatePhone', uuid=identity,
                                             busyLampFields=self.payload(blfs))
        body = message.find(f'{{{SOAP}}}Body')
        if body is None or len(body) != 1 or body[0].tag != f'{{{AXL}{self.version}}}updatePhone':
            raise CheckError('Loaded WSDL updatePhone namespace differs from accepted schema')
        # Assert on serialized output, not only the Python list supplied to Zeep.
        collection = next((e for e in body[0] if local(e.tag) == 'busyLampFields'), None)
        if collection is None or len(collection) != len(blfs):
            raise CheckError('Serialized update would omit BLF entries')
        expected = {str(entry['index']): entry for entry in blfs}
        seen = set()
        for element in collection:
            fields = {local(child.tag): child for child in element}
            index = fields.get('index')
            key = index.text if index is not None else None
            if local(element.tag) != 'busyLampField' or key not in expected or key in seen:
                raise CheckError('Serialized BLF indexes differ from the complete plan')
            seen.add(key)
            entry = expected[key]
            for name in ('label', 'asciiLabel', 'blfDirn', 'blfDest', 'routePartition'):
                if name not in entry:
                    continue
                actual = fields[name].text or '' if name in fields else ''
                if actual != entry[name]:
                    raise CheckError(f'Serialized BLF {name} differs from the plan')

    def write(self, identity, blfs):
        self.service.updatePhone(uuid=identity, busyLampFields=self.payload(blfs))


def comparable(snapshot):
    return {k: v for k, v in snapshot.items() if k != 'raw_blfs'}


class Journal:
    def __init__(self, path):
        self.stream = os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w', encoding='utf-8')

    def write(self, event, **fields):
        self.stream.write(json.dumps({'time': datetime.now(timezone.utc).isoformat(),
                                      'event': event, **fields}, ensure_ascii=True) + '\n')
        self.stream.flush()
        os.fsync(self.stream.fileno())

    def close(self):
        self.stream.close()


def reason(exc):
    # Unknown exception messages can contain raw SOAP, credentials, or server data.
    return str(exc) if isinstance(exc, CheckError) else type(exc).__name__


def run(client, groups, journal, apply=False):
    plans, rejected = [], False
    for device, targets in groups.items():
        try:
            before = client.read(device)
            journal.write('precheck', device=device, snapshot=before)
            desired, changes = prepare(before, targets)
            client.validate_payload(before['uuid'], desired)
        except OSError:
            raise
        except Exception as exc:
            journal.write('rejected', device=device, reason=reason(exc))
            print(f'{device}: rejected ({reason(exc)})')
            rejected = True
            continue
        status = 'already_ok' if desired == before['blfs'] else 'update_needed'
        journal.write(status, device=device, changes=changes, expected_blfs=desired)
        print(f'{device}: {status} ({len(before["blfs"])} BLFs retained)')
        for change in changes:
            print(f'  index {change["index"]}: {change["status"]}; {change["old_label"]!r} -> {change["new_label"]!r}')
        plans.append((device, before, desired))
    if rejected or not apply:
        journal.write('stopped' if rejected else 'dry_run_complete', writes_attempted=0)
        return 1 if rejected else 0
    updated = 0
    for device, before, desired in plans:
        try:
            fresh = client.read(device)
            journal.write('prewrite_check', device=device, snapshot=fresh)
            if comparable(fresh) != comparable(before):
                raise CheckError('Phone/BLF/speed-dial state changed since preflight')
        except OSError:
            raise
        except Exception as exc:
            journal.write('stopped', device=device, reason=reason(exc), previous_updates=updated)
            print(f'{device}: stopped ({reason(exc)}); earlier updates retained')
            return 1
        if desired == before['blfs']:
            journal.write('postcheck_already_ok', device=device, snapshot=fresh)
            continue
        journal.write('write_intent', device=device, before=fresh, expected_blfs=desired)
        try:
            client.write(before['uuid'], desired)
            after = client.read(device)
        except (Exception, KeyboardInterrupt) as exc:
            journal.write('uncertain', device=device, reason=reason(exc))
            print(f'{device}: uncertain; stopped. Reconcile the log with CUCM before rerunning.')
            return 1
        # Log even a bad read-back before evaluating it, retaining recovery evidence.
        journal.write('postcheck', device=device, snapshot=after)
        expected = {**comparable(before), 'blfs': desired}
        if comparable(after) != expected:
            journal.write('verification_failed', device=device, expected=expected, actual=comparable(after))
            print(f'{device}: verification_failed; stopped. Inspect full pre/post collections in the log.')
            return 1
        journal.write('updated', device=device, verified_blf_count=len(after['blfs']))
        print(f'{device}: updated ({len(after["blfs"])} BLFs verified; other speed-dial collections unchanged)')
        updated += 1
    journal.write('complete', updated=updated, already_ok=len(plans) - updated)
    return 0


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError('Expected a finite positive number')
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cucm', required=True, type=host)
    parser.add_argument('--username', help='AXL username; prompted when omitted')
    parser.add_argument('--csv', required=True, dest='csv_file', type=Path)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--match-index', action='store_true')
    parser.add_argument('--wsdl', type=Path, help='Explicit local WSDL; must match the accepted schema')
    parser.add_argument('--schema-dir', type=Path, default=Path(__file__).resolve().parent / 'schema')
    tls = parser.add_mutually_exclusive_group()
    tls.add_argument('--ca-file', type=Path)
    tls.add_argument('--insecure', action='store_true',
                     help='Disable TLS certificate and hostname verification; warn and record this in the log')
    parser.add_argument('--timeout', type=positive, default=30.0)
    parser.add_argument('--log', '--report', dest='log', type=Path, help='New private JSONL report (default: timestamped file in current directory)')
    args = parser.parse_args(argv)
    journal = None
    session = None
    try:
        groups = load_updates(args.csv_file, args.match_index)
        if args.ca_file and not args.ca_file.is_file():
            raise CheckError('CA bundle does not exist')
        logfile = args.log or Path('blf-label-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8] + '.jsonl')
        journal = Journal(logfile)
        journal.write('start', publisher=args.cucm, mode='apply' if args.apply else 'dry_run', phones=len(groups),
                      tls_verification=not args.insecure, ca_file=str(args.ca_file) if args.ca_file else None)
        print(f'Log: {logfile.resolve()}')
        if args.insecure:
            print('WARNING: --insecure disables TLS certificate and hostname verification. Server identity is not verified.', file=sys.stderr)
        username = args.username or input('AXL username: ').strip()
        password = getpass.getpass('AXL password: ')
        if not password or not username.strip():
            raise CheckError('Nonempty credentials required')
        session = Session()
        session.auth = (username, password)
        session.verify = False if args.insecure else (str(args.ca_file) if args.ca_file else True)
        endpoint = f'https://{args.cucm}:8443/axl/'
        version, software, discovery = negotiate(session, endpoint, args.timeout)
        journal.write('discovery', accepted_schema=version, cucm_version=software, attempts=discovery)
        wsdl = ensure_toolkit(args.wsdl, args.schema_dir, version, session, endpoint, args.timeout, journal)
        print(f'CUCM: {software}; accepted AXL schema: {version}; WSDL: {wsdl}')
        journal.write('toolkit', wsdl=str(wsdl), accepted_schema=version)
        client = PhoneClient(session, endpoint, wsdl, version, args.timeout)
        return run(client, groups, journal, args.apply)
    except (Exception, KeyboardInterrupt) as exc:
        print(f'STOPPED: {reason(exc)}. Review the log before rerunning; an unmatched write_intent is uncertain.', file=sys.stderr)
        return 130 if isinstance(exc, KeyboardInterrupt) else 2
    finally:
        if session is not None:
            session.close()
        if journal is not None:
            journal.close()


if __name__ == '__main__':
    raise SystemExit(main())
