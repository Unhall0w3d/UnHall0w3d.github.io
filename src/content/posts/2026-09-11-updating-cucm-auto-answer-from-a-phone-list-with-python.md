---
title: "Updating CUCM Auto Answer From a Phone List With Python"
date: 2026-09-11T08:00:00-04:00
description: "A CSV-driven Python script for checking specific CUCM phones and setting their primary directory numbers to Auto Answer with Speakerphone."
categories:
  - Cisco
  - Automation
tags:
  - cucm
  - axl
  - python
  - auto-answer
  - csv
draft: false
---

The request was straightforward: take a specific set of phones and configure their primary lines for **Auto Answer with Speakerphone**.

The phones did not conveniently fall under one device model, a common extension prefix, or a device pool that isolated the requested group. We had a list of devices. What we needed was a repeatable way to work through that list without opening each phone, checking its line, changing the setting, and repeating the same sequence until the list was finished.

It was a simple task with a tedious delivery mechanism. Those tend to make good candidates for a small script.<!--more-->

## Why Make a Script for This?

Changing one directory number through CUCM Administration is manageable. Repeating the process across an irregular list adds bookkeeping: which phone did I open, is this its primary line, is the extension correct, and did I already do this one?

There was also a reasonable chance of another request like it. I wanted the next request to start with a new input list and the same checks, rather than another round of manual navigation.

That became `auto-answer-update.py`: a Python script that reads an explicit CSV, validates each phone's configured Line 1, and can set the associated directory number to speakerphone auto-answer through AXL. The default run only checks. Writing requires `--apply`.

The useful part is that the input list carries the scope. There is no need to invent an extension-prefix rule that happens to catch today's devices and might catch something unrelated tomorrow.

## A Phone List, but a Directory Number Change

This distinction matters before running anything: the script **selects a phone by its configured Line 1, then updates the directory number**. It does not make an auto-answer change exclusive to one appearance of a shared DN.

For this utility, “primary line” means configured line index `1` returned by `getPhone`. It does not mean an end user's primary extension, the currently selected line on a handset, or the line supplied by a logged-in Extension Mobility profile.

The script requires the DN to appear only on the selected device at Line 1. If it finds another appearance, it rejects that target. A request involving shared DNs needs its own scope review; this script has no shared-line override.

[Cisco's AXL Developer Guide](https://developer.cisco.com/docs/axl/axl-developer-guide/) describes AXL as a provisioning and configuration API. That is the job here: inspect and update stored configuration. An inbound test call remains a separate check of what the phone actually does.

## The Input CSV

The file needs exactly three columns:

| Column | Required value |
| --- | --- |
| `Device` | The phone's `SEP` device name or a supported MAC address format. |
| `Extension` | The expected directory number on configured Line 1, including any leading zeros. |
| `Partition` | The expected route partition name. An empty field explicitly means no partition. |

Here is a fictional example, limited to ten lines including the header. These values illustrate the required format; they are not customer device identifiers or an extract from the original inventory.

```csv
Device,Extension,Partition
SEP020000000001,2101,EXAMPLE_PT
SEP020000000002,3472,EXAMPLE_PT
SEP020000000003,5083,EXAMPLE_PT
SEP020000000004,6214,EXAMPLE_PT
SEP020000000005,7355,EXAMPLE_PT
SEP020000000006,8466,EXAMPLE_PT
SEP020000000007,9027,EXAMPLE_PT
SEP020000000008,1188,EXAMPLE_PT
SEP020000000009,4639,EXAMPLE_PT
```

<a href="/assets/downloads/cucm-auto-answer/devlist.example.csv" download>Download the example CSV</a>, replace the example values with the approved devices, and save your working list as `devlist.csv`.

Headers are case-insensitive and may be reordered. Device values may use a bare 12-digit hex MAC, consistently colon-separated or hyphen-separated MAC notation, or dotted notation such as `0200.0000.0001`. The script normalizes those accepted formats to `SEP` names. It rejects malformed values, duplicate devices, and duplicate DN/partition identities.

If you prepare the list in a spreadsheet, preserve extensions as text so leading zeros survive the export. For an unpartitioned DN, leave the last field empty: `SEP020000000001,2101,`. Do not enter a display label such as `<None>` as the partition name.

The extension and partition are checks against CUCM, not instructions to move a line. If they do not match, the script stops that target from entering the apply phase.

## Running It

The script requires Python 3.10 or later and `requests`. Use an existing Python environment with that dependency, or create an isolated environment. For example, on a POSIX system:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install requests
```

On Windows, the equivalents are `py -3 -m venv .venv` and `.venv\Scripts\python.exe -m pip install requests`. Use the virtual environment's interpreter for the commands below, or activate it first.

You also need connectivity to the CUCM publisher's AXL endpoint on HTTPS port 8443, an account permitted to perform the required AXL operations, and trusted TLS certificates. The script targets AXL `15.0`; it does not automatically negotiate another schema version.

Start with a dry run:

```sh
python auto-answer-update.py devlist.csv --publisher cucm-pub.example.com --report preview.jsonl
```

The script prompts for the username and password. If the server's issuer is not in your trust store, add `--ca-file /path/to/ca.pem` with the appropriate PEM CA bundle. Certificate verification stays enabled; there is no `--insecure` option.

Review the results. `READY` means the validated DN needs a change. `ALREADY_OK` means it already has the requested setting. `REJECTED` means validation failed; if any row is rejected, the batch performs no writes.

When the proposed changes are correct and the change is authorized:

```sh
python auto-answer-update.py devlist.csv --publisher cucm-pub.example.com --apply --report apply-001.jsonl
```

Include the same `--ca-file` option if it was needed for the dry run. Apply requires a new report filename and performs a fresh validation. It does not consume the earlier preview as a saved change plan. Existing reports are never overwritten.

## What Happens Before a Write?

The script checks the entire list first. For each row, it retrieves the phone, verifies Line 1's DN and partition, reads the DN UUID and current auto-answer value, and checks its device-line appearances using a read-only AXL SQL query. Writes use `updateLine`, addressed by the validated DN UUID.

If every row passes, apply mode rechecks each target immediately before its turn. A changed UUID, setting, or disallowed appearance stops the batch. Already-correct targets do not receive an update.

Before attempting a write, the script flushes a `WRITE_INTENT` record containing the previous state to the audit file. Afterward, it reads the configuration again and records `UPDATED` only if the expected identity, setting, and appearance are verified.

This makes a rerun useful for checking existing configuration as well as making a new change. It also gives the operator a record of what was intended and what was verified.

## What the Live Run Confirmed

I ran the revised script against the same set of devices, and every device came back `ALREADY_OK`.

That was useful evidence: the revised script worked through the live read and validation path for that device set and recognized that the requested configuration was already present. Checking the list did not require going back through each phone's configuration page.

That run did not exercise a new write from another auto-answer value. The revision also has 20 passing offline tests, including mocked SOAP update/read-back, shared-line rejection, state drift, malformed input, and uncertain write outcomes. Those tests cover the script's behavior under controlled inputs; they do not replace a live write test or a call to the endpoint.

I am not attaching a time-saved figure or claiming support for every phone model. The practical gain was a repeatable list-driven check, explicit results for each target, and a process ready to use again when the next approved list arrives.

## Where It Fits—and Where It Stops

| Condition | Behavior or limitation |
| --- | --- |
| Explicit list of SEP-named phones with matching configured Line 1 DNs | This is the intended input, regardless of whether model, prefix, or device-pool filters group them conveniently. |
| DN has exactly one appearance, on that phone at Line 1 | Eligible for validation and, if needed, an update. |
| Setting is already speakerphone auto-answer | Reports `ALREADY_OK`; no update is needed. |
| DN is shared, including another appearance on the same device | Rejected. Listing all devices in the CSV does not bypass the restriction. |
| Expected DN or partition differs from CUCM | Rejected; the script does not repair assignments. |
| Target is Line 2 or later, an Extension Mobility profile, or a non-SEP device | Outside this utility's supported scope. |
| Empty partition | Supported explicitly in the input and covered by mocked tests; not separately established by the reported live run. |
| Another CUCM schema version or a different endpoint model | Requires environment-specific qualification; model-independent selection does not prove model-independent behavior. |
| Missing permissions, failed TLS validation, or unexpected API data | Stops rather than treating missing information as permission to change something. |
| Phone needs configuration application/restart or a behavior check | The script does not reset phones or place test calls. Handle those steps through the normal change procedure. |

There is also a limit to the batch behavior: **validation is all-or-nothing, but the writes are not one transaction**. If three updates complete and the fourth encounters a problem, the first three remain in place.

Rechecking immediately before a write narrows the opportunity for stale information, but it does not lock CUCM against another administrator's changes. Use an appropriate change window rather than assuming the script has exclusive access.

## If a Run Stops Midway

A timeout does not necessarily mean CUCM rejected the update. The server may have accepted it before the response was lost. The script reports an uncertain result and stops further writes instead of automatically retrying.

Review the JSONL report and reconcile the affected DN with CUCM before rerunning. An unmatched `WRITE_INTENT` or a truncated report also needs investigation. The stored previous value can help with a reviewed recovery decision, but the script does not automatically restore it over whatever is currently configured.

Keep input lists and reports private. They contain device identifiers, directory numbers, partitions, and configuration state. The downloadable examples contain fictional values; operational reports should not become attachments to a public troubleshooting comment.

## Script and Usage Guide

The previews below load the same files offered for download. The README includes setup, command examples, status meanings, exit codes, and recovery limitations.

<details class="code-preview" data-code-preview="/assets/downloads/cucm-auto-answer/auto-answer-update.py">
  <summary>
    <span>Review the Python script</span>
    <small>PYTHON // CUCM AUTO ANSWER</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the Python script.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/cucm-auto-answer/README.md">
  <summary>
    <span>Review the README and usage examples</span>
    <small>MARKDOWN // SETUP AND OPERATION</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the usage guide.</code></pre>
</details>

- <a href="/assets/downloads/cucm-auto-answer/auto-answer-update.py" download>Download auto-answer-update.py</a>
- <a href="/assets/downloads/cucm-auto-answer/README.md" download>Download the README</a>
- <a href="/assets/downloads/cucm-auto-answer/devlist.example.csv" download>Download the fictional input CSV</a>

The next request can start with an approved device list, a dry run, and a review of the results. That is the kind of repeatability I wanted from a task that was otherwise going to be a lot of the same clicks.
