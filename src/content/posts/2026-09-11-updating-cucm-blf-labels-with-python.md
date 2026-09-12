---
title: "Updating CUCM BLF Labels With Python Without Dropping the Other BLFs"
date: 2026-09-11T12:00:00-04:00
description: "A CSV-driven BLF label updater with full-collection preservation, preview mode, automatic AXL toolkit setup, and per-phone verification."
categories:
  - Cisco
  - Automation
tags:
  - cucm
  - axl
  - python
  - blf
  - csv
draft: false
---

The request was small: update the Busy Lamp Field (BLF) Speed Dial label for one extension across a list of phones. Some phones still showed an old role-based label. Others already had the person's name but needed its capitalization corrected.

The destination was staying the same. The job was to make the label consistent wherever that extension appeared on the approved devices.

Doing that once through CUCM Administration is straightforward. Doing it repeatedly means finding each phone, locating the right BLF, checking the destination and partition, editing the label, and keeping track of what has been completed. I wanted a repeatable process for the next request too.<!--more-->

## The Manual Work We Wanted to Replace

This followed the same practical idea as the [phone-list auto-answer script](/2026/09/11/updating-cucm-auto-answer-from-a-phone-list-with-python.html): let an explicit input list define the scope and make the repeated checks consistent.

The BLF index varied between phones. The same destination could be at index 6 on one phone and index 30 on another. Copying a button number across the list would not identify the right entry reliably.

| Step | Manual workflow | Script workflow |
| --- | --- | --- |
| Select the phone | Find and open each device. | Read the approved device name from CSV. |
| Find the BLF | Locate the destination and partition among its buttons. | Match the existing DN and partition, rejecting missing or ambiguous matches. |
| Decide whether to edit | Compare the current label with the requested spelling. | Report `update_needed` or `already_ok`, including capitalization differences. |
| Make the change | Edit and save the selected label. | With `--apply`, submit the complete BLF collection with only the selected label changed. |
| Check the result | Reopen configuration and compare it with the previous state. | Read back the complete collection and compare the other speed-dial collections too. |
| Record the work | Maintain notes and capture before/after details. | Write per-phone snapshots and results to a JSONL log. |

There is still operator work: prepare the right list, review the preview, and check the phone's behavior. The script makes the repetitive configuration work and recordkeeping consistent. I did not measure a manual baseline or elapsed run time, so there is no time-saved percentage attached to this comparison.

## The Important Trap: BLFs Are a Replacement Collection

The critical issue was how `updatePhone` handles `busyLampFields`. Sending only the BLF being edited can remove the other entries. A [Cisco Community report](https://community.cisco.com/t5/management/configure-key-expansion-module-using-axl/td-p/3910575) describes that exact outcome and the solution of reading and returning the complete collection.

That determined the script's workflow:

1. Call `getPhone` and capture all existing BLFs.
2. Find the requested destination and partition.
3. Change only the matching entry's `label`.
4. Send the entire BLF collection through `updatePhone`.
5. Read the phone again and compare the returned configuration with the expected result.

For a phone with 34 BLFs, changing one label still means returning 34 BLFs. The update contains the phone UUID and `busyLampFields`; it does not resubmit the phone's whole configuration.

The implementation also preserves the target's `asciiLabel`, unrelated labels, indexes, destinations, and supported BLF pickup features. Ordinary speed dials and BLF directed call parks are omitted from the update and compared before and after. A count alone would miss a wrong label or destination, so verification compares the collection's contents too.

## From a Small Script to a Repeatable Procedure

We reviewed the existing script around that preservation requirement, added explicit target validation, and made preview mode the default. All listed phones must pass preflight before any write begins.

Immediately before each update, the script reads the phone again and checks for changes since preflight. It then flushes a `write_intent` record to disk before attempting the write. Afterward, an `updated` result requires a successful read-back comparison. Missing BLFs or unexpected changes stop the remaining writes.

Connection setup needed attention too. The script makes a read-only `getCCMVersion` request to establish an accepted AXL schema. It starts with 14.0 and only tries an advertised supported alternative after an explicit version mismatch. The CUCM software release and accepted schema are recorded separately: a CUCM 15 server accepting AXL 14.0 uses the 14.0 toolkit for that run.

If the matching toolkit is missing locally, first-run setup downloads it from the same publisher using the entered credentials and TLS settings. It validates the ZIP, stages only WSDL/XSD files, checks the selected schema with Zeep, and caches it beside the script. Later runs reuse that cache. An explicit `--wsdl` path remains available when automatic download cannot work. Cisco describes the toolkit and schema versioning in its [AXL Developer Guide](https://developer.cisco.com/docs/axl/axl-developer-guide/).

## The CSV and First Run

The normal input has four columns. These are fictional values, not an extract from the operational phone list:

```csv
device,destination,partition,new_label
SEP020000000001,4001,EXAMPLE_PT,Alex McDonald
SEP020000000002,4001,EXAMPLE_PT,Alex McDonald
SEP020000000003,4001,EXAMPLE_PT,Alex McDonald
```

Use the configured `SEP` device name, the BLF's destination DN, its route partition, and the exact desired label. A blank partition explicitly means an unpartitioned DN. Preserve leading zeros in directory numbers. Headers are case-insensitive, but the requested label's capitalization matters.

If a destination and partition occur more than once on a phone, use the optional `buttonindex` column with `--match-index`. The script will not guess which duplicate to edit. The README includes that example.

Install Python 3.10+ with `requests` and `zeep` in your chosen environment. Start with one phone in `one-phone.csv` and run a preview:

```sh
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --ca-file ca.pem --csv one-phone.csv --log phone-preview.jsonl
```

The password is prompted with hidden input. Review the selected index, old and new labels, and full collection in the log. To apply, use a new log filename and add `--apply`:

```sh
python blf-label-update.py --cucm cucm-pub.example.com --username axluser --ca-file ca.pem --csv one-phone.csv --log phone-apply.jsonl --apply
```

Omit `--ca-file` if the normal trust store already trusts the publisher. An explicit `--insecure` option can replace it when needed; this disables certificate and hostname verification for both AXL and toolkit download. The script prints one warning and records the choice. Repeated urllib3 insecure-request warnings are suppressed only for those requests; other warnings and connection errors remain visible.

Every run creates a fresh log and refuses to overwrite an existing one. After the first-device checks, use the larger approved CSV with separate preview and apply logs.

## Testing Results

Testing completed successfully on **CUCM 14 (14.0.1.16900(4))**, using AXL **14.0**, with both single-phone and multiple-phone CSV files.

The script also has 43 passing offline tests covering collection preservation, serialization, schema negotiation, toolkit setup, invalid inputs, concurrent edits, failed read-back, and logging failures. CUCM 15 paths have synthetic-schema coverage, but this exercise did not establish a live CUCM 15 result.

## Where This Fits—and Its Limits

| Condition | Behavior |
| --- | --- |
| Existing DN-based BLF on an explicitly listed SEP phone | Intended target; match by destination and partition. |
| Correct label already present | Report `already_ok` without writing. |
| Several requested BLF edits on one phone | Combine them into one full-collection update. |
| Missing or ambiguous target, conflicting CSV, unsupported fields | Reject instead of guessing or dropping data. |
| Free-form `blfDest` entry | Preserve it, but do not select it for editing through this DN/partition input. |
| BLF addition, deletion, destination change, or ASCII-label change | Outside this script's scope. |
| Toolkit download requires a separate browser/SSO flow | Stop setup; supply the toolkit manually with `--wsdl`. |
| Another administrator changes the phone during the run | Rechecks detect changes up to the final read; there is still a race before the write. |
| A write times out or read-back fails | Stop remaining writes and reconcile CUCM with the log before rerunning. |

The batch is not a single transaction. Earlier successful changes remain if a later phone fails. There is no automatic rollback, and the precheck snapshots are recovery evidence rather than a standalone restore tool. An unmatched `write_intent`, an `uncertain` result, or a truncated log requires investigation before retrying.

Coordinate changes with other administrators and check the endpoint afterward. The script does not apply configuration, restart, or reset phones. Keep real CSVs and logs private: they contain device identities, destinations, and configuration details.

## Review and Download

The collapsible previews load the same files offered for download. The README includes installation, first-phone and batch examples, schema setup, status meanings, and recovery guidance.

<details class="code-preview" data-code-preview="/assets/downloads/cucm-blf-label/blf-label-update.py">
  <summary>
    <span>Review the Python script</span>
    <small>PYTHON // CUCM BLF LABELS</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the Python script.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/cucm-blf-label/README.md">
  <summary>
    <span>Review the README and usage examples</span>
    <small>MARKDOWN // SETUP AND OPERATION</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the usage guide.</code></pre>
</details>

- <a href="/assets/downloads/cucm-blf-label/blf-label-update.py" download>Download blf-label-update.py</a>
- <a href="/assets/downloads/cucm-blf-label/README.md" download>Download the README</a>
- <a href="/assets/downloads/cucm-blf-label/phones.example.csv" download>Download the fictional CSV example</a>

The next label-change request can start with a new approved list and the same preview, update, and verification procedure. That was the reason for making the script: turn repeated navigation and bookkeeping into a process we can inspect and use again.
