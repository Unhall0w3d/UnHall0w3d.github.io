# CUCM primary-line speakerphone auto-answer

A CSV-driven Python utility for setting speakerphone auto-answer on explicitly
selected phones. Save this README beside `auto-answer-update.py`.

The operator supplies specific phones because model, extension-prefix, and device
pool filters do not describe the requested group. The script checks **configured
line index 1**, then changes that directory number's `autoAnswer` through AXL.
It does not change a device-specific line-appearance setting, follow a logged-in
Extension Mobility profile, configure intercom, or reset/apply phones.

## Requirements and status

- Python 3.10 or later and `requests` (the original dependency).
- Reachability to the publisher's HTTPS AXL endpoint on TCP 8443.
- An AXL-authorized account with the required read/SQL-query permissions and,
  for apply, update permissions. Use an account appropriate to the approved work.
- A trusted server certificate, using the system trust store or `--ca-file`.
- Target schema: AXL 15.0. See the verification scope below.

On September 11, 2026, the operator reported running the revised script against
the original device set and receiving `ALREADY_OK` for every device. This is live
evidence for the read/validation path and recognition of the existing setting in
that environment. The exact CUCM release/SU and command were not recorded here.
That run did not exercise a change from another auto-answer value.

The 20 offline tests exercise local safety/control flow and fabricated SOAP
responses, including an update and read-back. A live write with this revision,
endpoint call behavior, other CUCM releases, and any apply/restart requirement
remain unverified. For a new deployment, check the target cluster's AXL toolkit,
run a dry run, then use an approved single-phone change and inbound test call.

If `requests` is not already in your chosen Python environment, install it in an
isolated virtual environment using your platform's supported Python workflow.
No additional runtime dependency has been introduced.

## Input

CSV requires exactly `Device,Extension,Partition` (case-insensitive headers;
column order may vary). Device and extension are mandatory. An empty Partition
field explicitly means an unpartitioned DN. Preserve leading zeros in extensions
when saving CSV from a spreadsheet. Use actual CUCM partition names, not a UI
placeholder such as `<None>`.

Device accepts `SEP` followed by 12 hex digits, a bare MAC, or consistently
colon-separated, hyphen-separated, or dotted MAC notation. Duplicate devices and
duplicate DN/partition identities are rejected. Malformed values are rejected,
not repaired by deleting arbitrary characters.

`devlist.example.csv` contains nine fictional devices plus a header. Copy it to
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
retried. Redirects are rejected. The old `--insecure` and `--allow-shared` options
have been removed: TLS verification is required and shared DNs are outside this
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

- `READY` / `ALREADY_OK`: initial validated state.
- `REJECTED`: preflight failed for this row; no batch writes begin.
- `WRITE_INTENT`: the write is about to be attempted; includes the previous state.
- `UPDATED`: the intended stored configuration was verified after the write.
- `UNCERTAIN`: write/verification failed or was interrupted; the write may have
  succeeded. Remaining targets are not attempted.
- `STOPPED`: pre-write validation failed; earlier changes may remain.
- `COMPLETE`: all rows processed; this is configuration verification, not a call test.

An unmatched `WRITE_INTENT`, a truncated final record, or an incomplete run must
be reconciled with CUCM before rerunning. A disk error after a write can prevent
its result being recorded; no later writes are attempted. Inspect the recorded
DN UUID, current phone assignment, appearances, and current setting. If restoring
the previous value is required, review the current state and perform that change
through the normal approved CUCM procedure. Do not blindly replay old values over
newer administrative changes. The script does not execute recovery actions.

Exit codes: `0` successful dry run or completed apply; `1` validation/drift or
uncertain-write stop; `2` local input/report/setup error; `130` interruption outside
the write/verification block. Interruption inside that block is an uncertain stop
with exit code `1`. Earlier writes can exist for any apply run that stops.

## Offline verification

```sh
python -m unittest discover -s scripts/cucm-auto-answer/tests -v
```

Run from the repository root. Tests make no CUCM connections.

References for live qualification:

- [Cisco AXL Developer Guide](https://developer.cisco.com/docs/axl/axl-developer-guide/)
- [Cisco CUCM 15 Data Dictionary](https://developer.cisco.com/docs/axl/15-cucm-data-dictionary/)
