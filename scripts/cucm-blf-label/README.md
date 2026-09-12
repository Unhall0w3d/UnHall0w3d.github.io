# CUCM BLF label updater

Update the visible `label` of an existing directory-number BLF on explicitly
listed phones. Every update sends the **entire BLF collection**. There is no
single-index patch request, BLF addition, BLF deletion, or automatic rollback.

## Current revision and qualification

Documentation revision: 2026-09-11. This guide describes the current script with
automatic toolkit setup, explicit `--insecure`, scoped warning suppression,
mandatory full-collection read-back, and durable per-phone JSONL records.

Testing completed successfully on **CUCM 14 (14.0.1.16900(4))**, using AXL
**14.0**, with both single-phone and multiple-phone CSV files.

CUCM 15 / AXL 15.0 paths have offline coverage using real Zeep and synthetic
schemas, but no live CUCM 15 result has been established. Handset/expansion-module
display and pickup behavior require separate operator checks.

## What is preserved and checked

- All existing BLF entries, their indexes and destination representations.
- Every unrelated label, `asciiLabel` where present, and BLF pickup features.
- The target BLF's `asciiLabel`; only its visible `label` is changed.
- Ordinary `speeddials` and `blfDirectedCallParks` are omitted from updatePhone
  and compared before/after as additional guards.
- Device name and UUID must remain the same.

An unsupported field, ambiguous target, missing identity, or collection that
cannot be mapped to the loaded write schema causes rejection. Unsupported
free-form `blfDest` entries are preserved, but cannot be selected for a label
change with this DN/partition CSV. Both destination alternatives populated is
rejected rather than guessing which to keep.

The phone's full configuration is not resubmitted. The update contains its UUID
and full `busyLampFields` only. Multiple requested label edits on one phone are
combined into one update.

## Requirements

- Python 3.10+ with `requests` and `zeep` installed in your chosen environment.
- CUCM 14 or 15, publisher AXL HTTPS port 8443, and an appropriate AXL account.
- TLS verification defaults to system trust or a PEM `--ca-file`. An explicit
  `--insecure` override is available when required.
- Cisco AXL toolkit files matching the negotiated schema. The script reuses a
  local toolkit or downloads it from the target publisher when absent. The login
  must be permitted to download the toolkit; manual `--wsdl` remains available.

Example local installation (use an existing suitable environment if available):

```sh
python -m venv .venv
```

On Windows:

```powershell
.venv\Scripts\python.exe -m pip install requests zeep
```

On Linux/macOS:

```sh
.venv/bin/python -m pip install requests zeep
```

Use that interpreter in place of `python` below, or activate the environment.

## Schema discovery

The script first sends a **read-only getCCMVersion** to the publisher with schema
14.0, following the existing AletheiaUC negotiation pattern. If the server reports
an incorrect AXL version and advertises supported alternatives, it may retry with
an advertised supported 15.0 schema. Authentication, TLS, timeout, and unrelated
HTTP failures do not trigger version guessing.

The successful schema is fixed for the rest of the run. A CUCM 15 server accepting
14.0 means the script uses the 14.0 toolkit, not that the server is CUCM 14. Both
the reported CUCM release and the accepted AXL schema are printed and logged.
Updates never participate in negotiation and are never automatically retried.

Default toolkit paths relative to the script:

```text
schema/14.0/AXLAPI.wsdl
schema/15.0/AXLAPI.wsdl
```

Use `--schema-dir` for another writable schema parent directory, or `--wsdl` for
one explicit WSDL. When no explicit WSDL was supplied and the selected schema is
absent, first-run setup performs the following:

1. Reuse the username/password already entered for the read-only discovery call.
   If `--username` was omitted, the script prompts for it as well as the password.
2. Download `https://<publisher>:8443/plugins/axlsqltoolkit.zip` from that same
   publisher, using the session's authentication and TLS settings. `--insecure`
   applies to this download too and is recorded in the log.
3. Check that the response is a ZIP, validate its paths and size, and stage only
   WSDL/XSD files. No toolkit executable or Java code is run or installed.
4. Locate the accepted schema by WSDL namespace, preferring the explicitly named
   version directory. This also handles a matching `schema/current` directory.
5. Load that schema with Zeep and local-only imports, then move its directory to
   `schema/<accepted-version>/`. Keep companion XSDs and subdirectories intact.
6. Continue with normal phone preflight. Later runs reuse the local files.

The compressed download is capped at 64 MiB, archive contents at 256 MiB, and the
ZIP at 5,000 entries. Traversal paths, links, encrypted entries, ambiguous matching
schemas, and duplicate/case-colliding paths are rejected. Installation uses a
staging directory and a per-version setup lock. An interrupted process can leave
that lock; review whether another setup is active before removing a stale lock.
The downloaded ZIP is temporary; its SHA-256 and source URL are retained in the
log as provenance, not as independent proof of authenticity.

Existing incomplete directories and explicit `--wsdl` paths are never silently
replaced. Select another `--schema-dir` or review the existing files. If CUCM
returns a login page, redirect, 401/403, or a toolkit without the required schema,
setup stops before phone processing. In that case, download the toolkit through
CUCM Administration > Application > Plugins, then supply `--wsdl`. The script does
not automate a separate browser/SSO login or guess another download endpoint.

The loaded XBusyLampField type and serialized updatePhone namespace must match
the accepted schema. Remote WSDL/XSD imports and imports outside the WSDL directory
tree are rejected. This utility supports only server releases 14/15 and schemas
14.0/15.0; no vendor schema modification occurs.

## CSV

Required headers (case-insensitive; order may vary):

```csv
device,destination,partition,new_label
SEP020000000001,4001,EXAMPLE_PT,Example Name
```

All values above are fictional. Replace them with one approved phone and its
actual BLF destination/partition for the first test. A blank partition explicitly
means an unpartitioned DN. Preserve leading zeros in destination numbers.

If the same destination appears multiple times, add the index and use
`--match-index` on both preview and apply:

```csv
device,destination,partition,new_label,buttonindex
SEP020000000001,4001,EXAMPLE_PT,Example Name,8
```

The index is the AXL BLF index, not an inferred screen position. The example
updates an existing DN-based BLF; it does not create index 8 or configure a DN.
Duplicate or conflicting selections are rejected, including rows that resolve to
the same actual index. Multiple different BLFs on one phone are supported.

## First-phone test

Put only the first test phone in `one-phone.csv`. First run a preview:

```sh
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --csv one-phone.csv --ca-file ca.pem --log phone-preview.jsonl
```

The password is prompted with hidden input. Check `precheck` in the report:
confirm the device, full BLF inventory, target index, current label and proposed
label. The report also shows the complete expected BLF collection.

Then, during the approved change window:

```sh
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --csv one-phone.csv --ca-file ca.pem --apply --log phone-apply.jsonl
```

Add `--match-index` when using the five-column CSV. Omit `--ca-file` when the
normal trust store already trusts the server. If certificate verification must
be bypassed, use `--insecure` instead of `--ca-file`:

```sh
python blf-label-update.py --cucm 192.0.2.10 --username axluser --csv one-phone.csv --insecure --log phone-preview-insecure.jsonl
```

`--insecure` disables certificate-chain and hostname verification for discovery
and subsequent AXL requests. HTTPS remains in use, but server identity is not
verified. The script prints a warning and records `tls_verification: false` in
the log's `start` record. Repeated urllib3 `InsecureRequestWarning` messages
are suppressed only during requests using this explicit override; other warnings
and connection errors remain visible. TLS verification stays enabled unless this option is
supplied; `--ca-file` and `--insecure` cannot be combined. This option does not
enable writes: `--apply` is still required. `--timeout` defaults to 30 seconds
and applies to individual network operations, not the entire run.

Apply performs a fresh batch preflight, not a replay of the prior preview. Before
each write it compares a fresh full snapshot with that preflight. If the approved
scope depends on a specific old label, verify it again in that run's output/log;
the CSV is a desired-state request, not a saved precondition contract.

After an `updated` result, inspect the `postcheck` collection and verify the phone
or expansion module display. Confirm that the other BLFs, regular speed dials,
and pickup behavior remain intact. AXL read-back verifies stored configuration;
this script does not apply/restart/reset phones or establish display behavior.
Do not broaden the CSV until that first-device check meets your expectations.

## Subsequent batches

After the first-phone check, create `phones.csv` with the approved device list.
Preview the whole list, then apply using a separate log file:

```sh
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --csv phones.csv --ca-file ca.pem --log batch-preview.jsonl
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --csv phones.csv --ca-file ca.pem --log batch-apply.jsonl --apply
```

Use a new log filename on every run. A later preview with a third filename can
check that targets are `already_ok`. Label comparisons are case-sensitive, so
`Alex Mcdonald` and `Alex McDonald` require an update. Already-correct labels do
not receive a write.

## Output and log

The console keeps per-phone and per-target status concise:

```text
SEP020000000001: update_needed (3 BLFs retained)
  index 8: update_needed; 'Old label' -> 'New label'
SEP020000000001: updated (3 BLFs verified; other speed-dial collections unchanged)
```

The first line describes the planned payload, not a completed write. `already_ok`
means no label update is needed. `rejected` blocks the entire batch before any
writes. `stopped`, `uncertain`, and `verification_failed` halt remaining writes.
Read-back verification is mandatory; the previous `--verify` option is unnecessary
and has been removed. `--password` and `--axl-version` were also removed in favor
of the hidden password prompt and read-only negotiation. The explicit
`--insecure` TLS override is described above.

Every run creates a new JSONL log, including dry runs. Use `--log` (alias
`--report`) to choose the path; otherwise a timestamped file is created in the
current directory. Each record is flushed and fsynced. Existing files are never
overwritten. File creation requests owner-only permissions on POSIX; Windows
access depends on the directory's ACL. Logs contain real device and destination
information, so keep the folder private.

Records include:

- `start`, `discovery`, `toolkit`: target server and schema context.
- `toolkit_local`, `toolkit_download_started`, `toolkit_downloaded`: local reuse or
  download provenance, accepted version, archive hash/size, and cached path.
- `precheck`: raw serialized BLFs plus normalized full collection, phone UUID,
  regular speed dials, and directed call-park data.
- `update_needed` / `already_ok`: each selected index's old/new label and the full
  expected collection.
- `prewrite_check`: the second complete snapshot used to detect concurrent edits.
- `write_intent`: complete previous snapshot and expected BLFs, flushed before
  attempting updatePhone.
- `postcheck`: complete returned snapshot, including a mismatching collection.
- `updated`: full comparison passed. `postcheck_already_ok` records a fresh
  no-change check during apply.
- `verification_failed`: expected and actual state when read-back differs.
- `uncertain`: transport/response/interrupt failure around the write or read-back.
- `complete`, `dry_run_complete`, or `stopped`: completed or halted processing.

No credentials or arbitrary server fault bodies are written to the log. Unknown
exceptions are represented by their class name to avoid leaking response data.
A malformed response that cannot be parsed into a valid snapshot may yield only
an error class/reason, not a usable postcheck.

## Recovery and limits

Treat an unmatched `write_intent`, a truncated log, or an `uncertain` result as a
possibly completed write. Re-read CUCM before rerunning. If verification fails,
the bad postcheck is recorded, so the before/after evidence can be inspected.
A failed logging operation halts processing; after a write, that can leave an
unmatched write_intent. Earlier verified updates remain if a later phone fails.

The precheck collection provides recovery evidence; it is not a standalone
restore tool. Restoring requires a reviewed full-collection update through an
appropriate CUCM procedure. Do not replay stale data over another administrator's
changes. There is no automatic rollback.

Full-collection read/modify/write has a race window: another administrator can
change the phone between the final read and the write. Rechecks reduce that risk
but do not create an atomic transaction or lock. Coordinate the change window.
The script cannot promise zero data loss under server faults or concurrent edits;
it is designed to avoid intentional omission, preserve evidence, and detect
unexpected results before continuing.

Exit status: 0 successful dry run or completed apply; 1 rejected batch or stopped
apply/verification; 2 setup/local failure; 130 interrupt outside the write/read-back
block. An interrupt inside that block is uncertain with status 1. Earlier changes
may exist in a stopped apply run.

## Offline verification for maintainers

From the repository root, using an interpreter with requests and zeep:

```sh
python -m unittest discover -s scripts/cucm-blf-label/tests -v
```

The tests include full collection preservation, multiple edits per phone, real
Zeep serialization for synthetic 14.0/15.0 schemas, typed response conversion,
server-advertised schema negotiation, missing-entry read-back, concurrent edits,
CSV conflicts, logging/transport failures, and first-run toolkit download,
selection, caching, and unsafe-archive rejection. These do not replace qualification
with the actual Cisco toolkit and the first test phone.

References:

- [Cisco Community: full BLF replacement behavior](https://community.cisco.com/t5/management/configure-key-expansion-module-using-axl/td-p/3910575)
- [Cisco Community: BLF destination schema alternatives](https://community.cisco.com/t5/management/xbusylampfield-specifies-minoccurs-1-which-contradicts/td-p/3576658)
- [Cisco AXL Developer Guide](https://developer.cisco.com/docs/axl/axl-developer-guide/)
