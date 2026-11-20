# CUCM primary-line speakerphone auto-answer — 0.2.0-rc4 candidate

A CSV-driven Python utility for setting speakerphone auto-answer on explicitly
selected phones. Save this README beside `auto-answer-update.py`. This is a separate testing
candidate; the existing operational script and published downloads are preserved.

The operator supplies specific phones because model, extension-prefix, and device
pool filters do not describe the requested group. The script checks **configured
line index 1**, then changes that directory number's `autoAnswer` through AXL.
It does not change a device-specific line-appearance setting, follow a logged-in
Extension Mobility profile, configure intercom, or reset/apply phones.

## Requirements and version discovery

- Python 3.10+ and requests. No Zeep dependency or Cisco toolkit is required.
- Reachability to the publisher HTTPS AXL endpoint on TCP 8443.
- An AXL-authorized account with read/SQL-query permissions and, for apply,
  update permissions appropriate to the approved work.
- Verified TLS using the Requests trust configuration or an explicit PEM CA
  bundle through --ca-file. An explicit bundle takes precedence over Requests'
  CA environment variables. Explicit --insecure disables certificate and hostname
  verification for that run and prints a warning. It cannot be combined with
  --ca-file. HTTPS remains in use, but server identity is not verified.

The candidate first sends getCCMVersion using AXL 15.0. Only an HTTP 599 response
with a recognized supported-version advertisement including 14.0 or 14.x permits
one read-only fallback probe using AXL 14.0. It validates the SOAP envelope,
response namespace and release value before accepting the schema. Authentication,
TLS, redirects, unexpected faults and unknown versions stop discovery; they do
not cause version guessing. Later requests use the accepted schema without
renegotiation or automatic retries. Software release and accepted AXL schema are
reported separately. This narrow response matcher needs environment qualification;
it is not a claim that every CUCM release uses the same discovery response.

AXL 14.0 is PREVIEW-ONLY. --apply stops immediately after discovery, before phone
preflight or any WRITE_INTENT. The update method independently refuses AXL 14.0.
There is no override. AXL 15.0 permits explicit apply with the existing safeguards.
Supporting discovery does not qualify all CUCM releases, SUs or phone models.
The direct SQL appearance query also needs qualification against the exact release.

On CUCM 15.0.1.15900(150) with AXL 15.0, rc4 changed Line 1 on a single
Cisco IP Communicator from Off to Auto Answer with Speakerphone. Readback
verified the change, and a fresh preview returned ALREADY_OK. An inbound
Baresip call rang and CIPC answered on speakerphone. A reverse call also
connected. The lab check covered call setup and auto-answer. Audio quality
and two-way speech were outside its scope.

## Changes from the operational original

- Bounded AXL discovery and explicit 14.0 preview-only enforcement.
- Clearer transport diagnostics, strict SOAP response validation and CA precedence.
- Runnable candidate CLI, --version, and versioned journals with discovery metadata.
- Companion offline summary support; no changes to DN mutation scope or CSV format.
- Existing exclusive durable reports, exact UUID checks, single-appearance rule,
  all-target preflight, immediate rechecks, read-back and no write retries retained.

## Input

CSV requires exactly `Device,Extension,Partition` (case-insensitive headers;
column order may vary). Device and extension are mandatory. An empty Partition
field explicitly means an unpartitioned DN. Preserve leading zeros in extensions
when saving CSV from a spreadsheet. Use actual CUCM partition names, not a UI
placeholder such as `<None>`.

Use the configured CUCM device name, including case. This candidate accepts
CSF plus an alphanumeric suffix, BOT/TCT/TAB plus uppercase letters, digits,
period, underscore or hyphen, and CIPC plus letters, digits, period, underscore
or hyphen (for example CIPCLAB01). These conventions have a 15-character
total limit. Explicit ATA plus 12 hex digits allows preview of the configured
adapter record. A batch containing an ATA is preview-only because analog
speakerphone operation is unqualified. Enter the actual port record from CUCM.

Device also accepts `SEP` followed by 12 hex digits, a bare MAC, or consistently
colon-separated, hyphen-separated, or dotted MAC notation. Duplicate devices and
duplicate DN/partition identities are rejected. Malformed values are rejected,
not repaired by deleting arbitrary characters.

`devlist.example.csv` contains two fictional devices plus a header. Copy it to
`devlist.csv` and replace every example value with your approved target list.
The sample follows the parser's required format; it is not an export of a live
device inventory.

## Run

Use your existing Python environment if it already has `requests`. Otherwise,
create a virtual environment (POSIX example):

```sh
python3 -m venv .venv
.venv/bin/python -m pip install requests
```

On Windows, use `py -3 -m venv .venv` and
`.venv\Scripts\python.exe -m pip install requests`. Use that interpreter in
place of `python` below, or activate the environment first.

From the folder containing the script and your CSV, using a trusted CA bundle
where needed:

```sh
python auto-answer-update.py devlist.csv --publisher cucm-pub.example.com --ca-file /path/to/ca.pem --report preview.jsonl
python auto-answer-update.py devlist.csv --publisher cucm-pub.example.com --ca-file /path/to/ca.pem --apply --report apply-001.jsonl
```

The first command is read-only. Review its output before invoking the second.
`--apply` is the explicit write authorization for that run; it performs a fresh
preflight, rather than consuming or claiming to reproduce the earlier preview.
Use a controlled change window to limit concurrent administrative changes.

Username and password are prompted. `--username` or `CUCM_AXL_USERNAME` may supply
the username. `CUCM_AXL_PASSWORD` is supported for an existing secure process
environment; the script never persists it. Prefer the hidden password prompt for
interactive runs. There is no password argument or saved credential file.

`--timeout` is a positive finite requests timeout in seconds (default 30), not a
whole-run deadline. `--delay` is a finite nonnegative delay after each verified
write (default 0.15). Requests are sequential; writes are never automatically
retried. Redirects are rejected. `--insecure` is an explicit TLS-verification opt-out; verification stays on by
default. There is no `--allow-shared` option: shared DNs are outside this
phone-specific tool's mutation scope, even if all appearances appear in the CSV.

## Validation and writes

1. Parse the entire CSV before credentials or network requests.
2. Retrieve each phone and verify its configured Line 1 DN/partition.
3. Retrieve the DN's UUID and explicit, recognized auto-answer value.
4. Query device-line appearances by DN UUID, including unpartitioned DNs without
   a partition-name join. Require exactly the selected device at line index 1.
5. If any target fails preflight, attempt no writes.
6. In apply mode, recheck each snapshot immediately before its turn. Any change
   in UUID, setting, or allowed appearance stops the batch. Already-correct rows
   are also rechecked and skipped without a write.
7. Flush a `WRITE_INTENT` containing the previous state, then update by DN UUID.
8. Re-read and verify identity, setting, and appearance; flush `UPDATED`.

These separate requests are **not an atomic transaction or a lock**. Rechecks
reduce stale-state risk but cannot eliminate changes between the last read and
the write. Earlier verified changes remain if the batch later stops. There is no
automatic rollback, write retry, or claim of whole-batch atomicity.

## Audit records and recovery

Apply requires a new `--report` path; dry-run reports are optional. The JSONL file
is created exclusively, with owner-only creation mode on POSIX, and each record
is flushed and fsynced. Use a private local directory; Windows permissions depend
on that directory's ACL. Reports contain operational identifiers and previous
settings, so keep them out of the public repository and redact before sharing.
Credentials, raw SOAP bodies, and raw server fault messages are not recorded.

Each record declares journal_schema = "noc-thoughts.cucm-auto-answer" and
schema_version = 1. START includes tool_version, requested initial axl_version,
mode and target_count. DISCOVERY records cucm_version and accepted_axl_version.
Do not interpret START's axl_version as successful discovery. The legacy reader
sample cannot consume this new format; use the separate summary candidate.

- `START`: local input accepted and report opened; connection not yet established.
- `DISCOVERY`: accepted response schema and software release recorded.
- `READY` / `ALREADY_OK`: initial validated state.
- `REJECTED`: preflight failed for this row; no batch writes begin.
- `WRITE_INTENT`: the write is about to be attempted; includes the previous state.
- `UPDATED`: the intended stored configuration was verified after the write.
- `UNCERTAIN`: write/verification failed or was interrupted; the write may have
  succeeded. Remaining targets are not attempted.
- `STOPPED`: discovery, schema gate or pre-write validation stopped the run;
  earlier changes may remain if apply had already begun.
- `COMPLETE`: all rows processed; this is configuration verification, not a call test.

An unmatched `WRITE_INTENT`, a truncated final record, or an incomplete run must
be reconciled with CUCM before rerunning. A disk error after a write can prevent
its result being recorded; no later writes are attempted. Inspect the recorded
DN UUID, current phone assignment, appearances, and current setting. If restoring
the previous value is required, review the current state and perform that change
through the normal approved CUCM procedure. Do not blindly replay old values over
newer administrative changes. The script does not execute recovery actions.

Exit codes: `0` successful dry run or completed apply; `1` validation/drift or
uncertain-write stop; `2` local input/report/setup, discovery or preview-only schema refusal; `130` interruption outside
the write/verification block. Interruption inside that block is an uncertain stop
with exit code `1`. Earlier writes can exist for any apply run that stops.

## Read the journal offline

The companion script is independent and requires only Python 3.10+. Save journal_summary.py alongside the updater and run:

```sh
python journal_summary.py --tool auto-answer --format text preview.jsonl
python journal_summary.py --tool auto-answer --format json apply-001.jsonl
```

Use a completed/preserved report copy. Summary exit 0 means recorded COMPLETE or
DRY_RUN_COMPLETE; 1 means stopped, incomplete or reconciliation required; 2 means
an input/CLI error. The reader cannot verify current CUCM state, authenticity or
recover a device. A summary is not permission to retry an uncertain write.

## Offline verification

```sh
python -m unittest discover -s scripts/cucm-auto-answer-candidate/tests -v
```

Run from the repository root. Tests make no CUCM connections. The cross-candidate
integration tests need the sibling scripts/cucm-journal-summary-candidate folder.
In the combined review bundle, both folders sit directly under the extracted root;
use -s cucm-auto-answer-candidate/tests from that root instead. The script itself
has no runtime dependency on the summary tool or the tests.

The original 20 safety tests and 11 discovery tests are retained. Additional
integration tests exercise actual main(), mocked SOAP, real local journals and
the summary reader, including write/verification interruption and fsync failure.

References for live qualification:

- [Cisco AXL Developer Guide](https://developer.cisco.com/docs/axl/axl-developer-guide/)
- [Cisco CUCM 15 Data Dictionary](https://developer.cisco.com/docs/axl/15-cucm-data-dictionary/)

## Lab preview with an untrusted certificate

```powershell
python auto-answer-update.py one-phone.csv --publisher cucm-pub.example.com --insecure --report preview-001.jsonl
```

This does not bypass authentication, schema checks, shared-DN checks or the
AXL 14.0 preview-only restriction. Use a fresh report name for each attempt.
Use a dedicated CUCM Application User with appropriate AXL roles, not the
appliance OS-admin account. The journal format and summary reader are unchanged.
