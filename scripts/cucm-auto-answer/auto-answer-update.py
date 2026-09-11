#!/usr/bin/env python3
"""Set speakerphone auto-answer for explicitly listed, unshared Line 1 DNs.

Python 3.10+, requests. CUCM AXL 15.0 target; live qualification still required.
See README.md for scope, audit records, usage, and recovery limitations.
"""
from __future__ import annotations

import argparse
import csv
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import getpass
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

import requests

AXL_VERSION = "15.0"
AXL_NS = f"http://www.cisco.com/AXL/API/{AXL_VERSION}"
SOAP_NS = "http://schemas.xmlsoap.org/soap/envelope/"
DESIRED = "Auto Answer with Speakerphone"
KNOWN_VALUES = {"Auto Answer Off", "Auto Answer with Headset", DESIRED}


class AXLException(RuntimeError):
    """A request or its response could not be trusted."""


@dataclass(frozen=True)
class Target:
    device: str
    extension: str
    partition: str
    row_number: int


@dataclass(frozen=True)
class Snapshot:
    dn_uuid: str
    auto_answer: str
    appearances: tuple[tuple[str, int], ...]


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def children(parent: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in parent if local(child.tag) == name]


def one(parent: ET.Element, name: str) -> ET.Element:
    found = children(parent, name)
    if len(found) != 1:
        raise AXLException(f"Expected exactly one {name} element")
    return found[0]


def value(parent: ET.Element, name: str, *, empty: bool = False) -> str:
    text = (one(parent, name).text or "").strip()
    if not text and not empty:
        raise AXLException(f"Missing value for {name}")
    return text


def canonical_uuid(raw: str) -> str:
    try:
        return str(uuid.UUID(raw))
    except (ValueError, AttributeError) as exc:
        raise AXLException("Missing or invalid DN UUID") from exc


def normalize_device(raw: str) -> str:
    raw = raw.strip().upper()
    if re.fullmatch(r"SEP[0-9A-F]{12}", raw):
        return raw
    if any(re.fullmatch(pattern, raw) for pattern in (
        r"[0-9A-F]{12}", r"(?:[0-9A-F]{2}:){5}[0-9A-F]{2}",
        r"(?:[0-9A-F]{2}-){5}[0-9A-F]{2}", r"[0-9A-F]{4}(?:\.[0-9A-F]{4}){2}",
    )):
        return "SEP" + re.sub(r"[:.\-]", "", raw)
    raise ValueError("Invalid device: expected SEP plus 12 hex digits or a MAC address")


def load_csv(path: Path) -> list[Target]:
    targets = []
    devices = set()
    dns = set()
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream, strict=True)
        headers = next(reader, [])
        normalized = [h.strip().lower() for h in headers]
        if len(normalized) != 3 or set(normalized) != {"device", "extension", "partition"}:
            raise ValueError("CSV must have exactly Device,Extension,Partition headers")
        for row in reader:
            if not row or all(not cell.strip() for cell in row):
                continue
            if len(row) != 3:
                raise ValueError(f"CSV line {reader.line_num}: expected exactly three fields")
            fields = dict(zip(normalized, (cell.strip() for cell in row)))
            if any(any(ord(c) < 32 or ord(c) == 127 for c in v) for v in fields.values()):
                raise ValueError(f"CSV line {reader.line_num}: control characters are not allowed")
            device = normalize_device(fields["device"])
            dn, pt = fields["extension"], fields["partition"]
            if not dn:
                raise ValueError(f"CSV line {reader.line_num}: Extension is required")
            if device in devices or (dn, pt) in dns:
                raise ValueError(f"CSV line {reader.line_num}: duplicate device or DN/partition")
            devices.add(device)
            dns.add((dn, pt))
            targets.append(Target(device, dn, pt, reader.line_num))
    if not targets:
        raise ValueError("CSV contains no targets")
    return targets


def publisher_host(raw: str) -> str:
    # Accept only an authority host, never userinfo, a URL, path, or custom port.
    candidate = raw[1:-1] if raw.startswith("[") and raw.endswith("]") else raw
    try:
        address = ipaddress.ip_address(candidate)
        return f"[{address}]" if address.version == 6 else str(address)
    except ValueError:
        if len(raw) <= 253 and all(re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", label)
                                   for label in raw.rstrip(".").split(".")):
            return raw.lower()
    raise argparse.ArgumentTypeError("Publisher must be a hostname or IP, without URL, port, or credentials")


class AXLClient:
    def __init__(self, publisher: str, username: str, password: str,
                 verify: bool | str = True, timeout: float = 30):
        self.url = f"https://{publisher_host(publisher)}:8443/axl/"
        self.timeout = timeout
        self.session = requests.Session()
        self.session.auth = (username, password)
        self.session.verify = verify

    def close(self) -> None:
        self.session.close()

    def _post(self, operation: str, body: str) -> ET.Element:
        envelope = (f'<s:Envelope xmlns:s="{SOAP_NS}" xmlns:axl="{AXL_NS}">'
                    f"<s:Body>{body}</s:Body></s:Envelope>")
        try:
            response = self.session.post(
                self.url, data=envelope.encode("utf-8"), timeout=self.timeout,
                allow_redirects=False,
                headers={"Content-Type": "text/xml; charset=utf-8",
                         "SOAPAction": f'"CUCM:DB ver={AXL_VERSION} {operation}"'},
            )
        except requests.RequestException as exc:
            # Do not echo request bodies, credentials, or server-provided text.
            raise AXLException(f"{operation}: transport error ({type(exc).__name__})") from exc
        if response.status_code != 200:
            raise AXLException(f"{operation}: HTTP {response.status_code}; inspect CUCM logs")
        try:
            root = ET.fromstring(response.content)
        except ET.ParseError as exc:
            raise AXLException(f"{operation}: invalid XML response") from exc
        if root.tag != f"{{{SOAP_NS}}}Envelope":
            raise AXLException("Unexpected SOAP envelope")
        soap_body = root.find(f"{{{SOAP_NS}}}Body")
        if soap_body is None or len(soap_body) != 1:
            raise AXLException("Unexpected SOAP body")
        result = soap_body[0]
        if result.tag != f"{{{AXL_NS}}}{operation}Response":
            raise AXLException(f"{operation}: SOAP fault or unexpected response")
        return one(result, "return")

    def phone_line1(self, target: Target) -> None:
        result = self._post("getPhone", f"""<axl:getPhone>
          <name>{escape(target.device)}</name><returnedTags><name/><lines><line>
          <index/><dirn><pattern/><routePartitionName/></dirn>
          </line></lines></returnedTags></axl:getPhone>""")
        phone = one(result, "phone")
        if value(phone, "name") != target.device:
            raise AXLException("Returned phone name differs from requested device")
        lines = [line for line in children(one(phone, "lines"), "line")
                 if value(line, "index") == "1"]
        if len(lines) != 1:
            raise AXLException("Expected exactly one configured Line 1")
        dirn = one(lines[0], "dirn")
        if (value(dirn, "pattern"), value(dirn, "routePartitionName", empty=True)) != (
            target.extension, target.partition
        ):
            raise AXLException("Configured Line 1 DN/partition differs from CSV")

    def line(self, target: Target) -> tuple[str, str]:
        result = self._post("getLine", f"""<axl:getLine>
          <pattern>{escape(target.extension)}</pattern>
          <routePartitionName>{escape(target.partition)}</routePartitionName>
          <returnedTags><pattern/><routePartitionName/><autoAnswer/></returnedTags>
          </axl:getLine>""")
        line = one(result, "line")
        if (value(line, "pattern"), value(line, "routePartitionName", empty=True)) != (
            target.extension, target.partition
        ):
            raise AXLException("Returned DN/partition differs from CSV")
        current = value(line, "autoAnswer")
        if current not in KNOWN_VALUES:
            raise AXLException("Unrecognized autoAnswer value")
        return canonical_uuid(line.get("uuid", "")), current

    def appearances(self, dn_uuid: str) -> tuple[tuple[str, int], ...]:
        dn_uuid = canonical_uuid(dn_uuid)
        sql = ("select d.name as device, m.numplanindex as lineindex "
               "from devicenumplanmap m inner join device d on d.pkid=m.fkdevice "
               f"where m.fknumplan='{dn_uuid}'")
        result = self._post("executeSQLQuery", f"<axl:executeSQLQuery><sql>{escape(sql)}</sql></axl:executeSQLQuery>")
        appearances = []
        for row in result:
            if local(row.tag) != "row":
                raise AXLException("Unexpected SQL response element")
            try:
                index = int(value(row, "lineindex"))
            except ValueError as exc:
                raise AXLException("Invalid appearance index") from exc
            appearances.append((value(row, "device"), index))
        return tuple(sorted(appearances))

    def inspect(self, target: Target) -> Snapshot:
        self.phone_line1(target)
        dn_uuid, current = self.line(target)
        appearances = self.appearances(dn_uuid)
        if appearances != ((target.device, 1),):
            raise AXLException(f"DN must appear only on the selected phone at Line 1; found {appearances!r}")
        return Snapshot(dn_uuid, current, appearances)

    def update(self, dn_uuid: str) -> None:
        result = self._post("updateLine", f"""<axl:updateLine>
          <uuid>{canonical_uuid(dn_uuid)}</uuid><autoAnswer>{DESIRED}</autoAnswer>
          </axl:updateLine>""")
        if canonical_uuid((result.text or "").strip()) != canonical_uuid(dn_uuid):
            raise AXLException("Update response UUID differs from requested DN")


class Journal:
    """Exclusive, durable JSONL journal; an unmatched WRITE_INTENT is uncertain."""
    def __init__(self, path: Path):
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        self.stream = os.fdopen(fd, "w", encoding="utf-8")

    def write(self, event: str, **fields) -> None:
        record = {"time": datetime.now(timezone.utc).isoformat(), "event": event, **fields}
        self.stream.write(json.dumps(record, ensure_ascii=True) + "\n")
        self.stream.flush()
        os.fsync(self.stream.fileno())

    def close(self) -> None:
        self.stream.close()


def run(client: AXLClient, targets: list[Target], apply: bool,
        journal: Journal | None, delay: float = 0.15) -> int:
    def record(event: str, **fields) -> None:
        if journal is not None:
            journal.write(event, **fields)

    if apply and journal is None:
        raise ValueError("Apply requires a durable journal")
    plans = []
    invalid = False
    for target in targets:
        try:
            snapshot = client.inspect(target)
        except AXLException as exc:
            invalid = True
            record("REJECTED", target=asdict(target), detail=str(exc))
            print(f"REJECTED {target.device}: {exc}")
            continue
        plans.append((target, snapshot))
        status = "ALREADY_OK" if snapshot.auto_answer == DESIRED else "READY"
        record(status, target=asdict(target), before=asdict(snapshot), desired=DESIRED)
        print(f"{status} {target.device}: {snapshot.auto_answer} -> {DESIRED}")
    if invalid:
        record("STOPPED", reason="Preflight failed; no writes attempted")
        print("Preflight failed; no writes attempted.")
        return 1
    if not apply:
        record("DRY_RUN_COMPLETE")
        print("Dry run complete; no writes attempted.")
        return 0
    updated = 0
    for target, before in plans:
        # Recheck even ALREADY_OK rows so completion does not silently ignore drift.
        try:
            fresh = client.inspect(target)
            if fresh != before:
                raise AXLException("State changed since preflight")
        except AXLException as exc:
            record("STOPPED", target=asdict(target), reason=str(exc), verified_updates=updated)
            print(f"STOPPED {target.device}: {exc}; {updated} earlier updates retained.")
            return 1
        if fresh.auto_answer == DESIRED:
            continue
        record("WRITE_INTENT", target=asdict(target), before=asdict(before), desired=DESIRED)
        try:
            client.update(before.dn_uuid)
            after = client.inspect(target)
            if after != Snapshot(before.dn_uuid, DESIRED, before.appearances):
                raise AXLException("Post-write verification did not match the intended state")
        except (AXLException, KeyboardInterrupt) as exc:
            record("UNCERTAIN", target=asdict(target), reason=str(exc) or "Interrupted during write/verification")
            print(f"UNCERTAIN {target.device}: stop and reconcile CUCM with the journal before rerunning.")
            return 1
        record("UPDATED", target=asdict(target), after=asdict(after))
        updated += 1
        print(f"UPDATED {target.device}: stored configuration verified")
        time.sleep(delay)
    record("COMPLETE", verified_updates=updated, already_ok=len(plans) - updated)
    print(f"Complete: {updated} updates verified. Endpoint test calls remain an operator check.")
    return 0


def nonnegative(raw: str) -> float:
    number = float(raw)
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("Expected a finite nonnegative number")
    return number


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    parser.add_argument("--publisher", required=True, type=publisher_host)
    parser.add_argument("--username", default=os.getenv("CUCM_AXL_USERNAME"))
    parser.add_argument("--apply", action="store_true", help="Write after full preflight; requires --report")
    parser.add_argument("--report", type=Path, help="New JSONL audit file (never overwritten); required for apply")
    parser.add_argument("--ca-file", type=Path, help="Trusted PEM CA bundle; TLS verification remains enabled")
    parser.add_argument("--timeout", type=nonnegative, default=30.0)
    parser.add_argument("--delay", type=nonnegative, default=0.15)
    args = parser.parse_args(argv)
    if args.timeout == 0:
        parser.error("--timeout must be greater than zero")
    if args.apply and not args.report:
        parser.error("--apply requires --report with a new audit-file path")
    client = journal = None
    try:
        targets = load_csv(args.csv_file)
        if args.ca_file and not args.ca_file.is_file():
            raise ValueError("CA file does not exist or is not a file")
        if args.report:
            journal = Journal(args.report)
            journal.write("START", publisher=args.publisher, axl_version=AXL_VERSION,
                          mode="APPLY" if args.apply else "DRY_RUN", target_count=len(targets))
        username = args.username or input("CUCM AXL username: ").strip()
        password = os.getenv("CUCM_AXL_PASSWORD")
        if password is None:
            password = getpass.getpass("CUCM AXL password: ")
        if not username or not password:
            raise ValueError("Username and password must be nonempty")
        client = AXLClient(args.publisher, username, password,
                           str(args.ca_file) if args.ca_file else True, args.timeout)
        return run(client, targets, args.apply, journal, args.delay)
    except (OSError, ValueError, csv.Error, EOFError) as exc:
        print(f"STOPPED: {exc}. No further writes attempted. If applying, inspect the audit file; an unmatched WRITE_INTENT is uncertain.", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("Interrupted. Review the audit file before rerunning.", file=sys.stderr)
        return 130
    finally:
        if client is not None:
            client.close()
        if journal is not None:
            journal.close()


if __name__ == "__main__":
    raise SystemExit(main())
