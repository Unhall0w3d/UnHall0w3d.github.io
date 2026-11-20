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
| `Device` | The configured CUCM device name, or a supported MAC address for a SEP device. |
| `Extension` | The expected directory number on configured Line 1, including any leading zeros. |
| `Partition` | The expected route partition name. An empty field explicitly means no partition. |

The download includes this fictional CSV. The second extension has a leading zero and an empty partition field.

```csv
Device,Extension,Partition
SEP020000000001,001234,LAB_PT
SEP020000000002,001235,
```

Copy the example from [Tools & Downloads](/tools.html#auto-answer), substitute your devices, and save it as `devlist.csv`. Headers are case-insensitive and may be reordered.

Use the configured name for Cisco IP Communicator (`CIPC`) or Jabber (`CSF`, `BOT`, `TCT`, or `TAB`). For a Cisco phone, enter its `SEP` name or its MAC in bare, colon-separated, hyphen-separated, or dotted form. The script normalizes a MAC to a SEP name. It also accepts an explicit `ATA` name followed by 12 hex digits for preview. If a batch includes an ATA, the whole batch is preview-only.

If you prepare the list in a spreadsheet, preserve extensions as text so leading zeros survive the export. For an unpartitioned DN, leave the last field empty: `SEP020000000001,2101,`. Do not enter a display label such as `<None>` as the partition name.

The extension and partition are checks against CUCM, not instructions to move a line. If they do not match, the script stops that target from entering the apply phase.

## Running It

The script requires Python 3.10 or later and `requests`. Use an existing Python environment with that dependency, or create an isolated environment. For example, on a POSIX system:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install requests
```

On Windows, the equivalents are `py -3 -m venv .venv` and `.venv\Scripts\python.exe -m pip install requests`. Use the virtual environment's interpreter for the commands below, or activate it first.

You also need connectivity to the CUCM publisher's AXL endpoint on HTTPS port 8443, an account permitted to perform the required AXL operations, and trusted TLS certificates. The script starts with a read-only AXL 15.0 probe. If the publisher explicitly rejects that version and advertises 14.x, the script can probe AXL 14.0. An accepted 14.0 schema permits preview only. Apply requires AXL 15.0.

Start with a dry run:

```sh
python auto-answer-update.py devlist.csv --publisher cucm-pub.example.com --report preview.jsonl
```

The script prompts for the username and password. If the server's issuer is not in your trust store, add `--ca-file /path/to/ca.pem` with the appropriate PEM CA bundle. For a lab with an untrusted certificate, `--insecure` disables certificate and hostname verification for that run and prints one startup warning. Choose one TLS option.

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

## What the Lab Phone Did

The original run checked an existing list and found every line already configured. For the rc4 write test, I started with Auto Answer Off on Line 1 of a Cisco IP Communicator. CUCM reported release `15.0.1.15900(150)` and accepted AXL `15.0`.

The apply recorded one verified change to Auto Answer with Speakerphone. I ran the preview again against the same CSV and got `ALREADY_OK`. Then I dialed the extension from Baresip. CIPC rang and answered on speakerphone without anyone clicking Answer. The reverse call connected too. The call test covered ringing and pickup. We didn’t test two-way speech.

## Read the Journal

I use the offline reader when I want to know how an apply ended or whether a write still needs investigation. Download the [CUCM journal summary script](/tools.html#journal-summary) and run it against the file you saved. It needs Python 3.10+ and works without CUCM credentials.

```sh
python journal_summary.py --tool auto-answer --format text apply-001.jsonl
python journal_summary.py --tool auto-answer --format json preview.jsonl
```

In the lab, both formats matched the raw records for all three runs. The initial preview reported zero verified updates, the apply reported one, and the repeat preview reported zero. An `ALREADY_OK` row counts as zero because the updater skipped the write. If the reader reports `RECONCILE_REQUIRED`, check the affected DN in CUCM against the original journal before another apply.

## Where It Fits—and Where It Stops

| Condition | Behavior or limitation |
| --- | --- |
| Explicit list of supported device names with matching configured Line 1 DNs | This is the intended input, regardless of whether model, prefix, or device-pool filters group them conveniently. |
| DN has exactly one appearance, on that phone at Line 1 | Eligible for an update when the batch and schema permit writes. |
| Setting is already speakerphone auto-answer | Reports `ALREADY_OK`; no update is needed. |
| DN is shared, including another appearance on the same device | Rejected. Listing all devices in the CSV does not bypass the restriction. |
| Expected DN or partition differs from CUCM | Rejected; the script does not repair assignments. |
| Target is Line 2 or later or a logged-in Extension Mobility profile | Outside this utility's supported scope. |
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

<details class="code-preview" data-code-preview="/assets/downloads/cucm-auto-answer-candidate/auto-answer-update.py">
  <summary>
    <span>Review the Python script</span>
    <small>PYTHON // CUCM AUTO ANSWER</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the Python script.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/cucm-auto-answer-candidate/README.txt">
  <summary>
    <span>Review the README and usage examples</span>
    <small>TEXT // SETUP AND OPERATION</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the usage guide.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/cucm-journal-summary-candidate/journal_summary.py">
  <summary>Review the offline journal reader</summary>
  <pre aria-live="polite"><code>Open to read journal_summary.py.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/cucm-journal-summary-candidate/README.txt">
  <summary>Review the journal reader README</summary>
  <pre aria-live="polite"><code>Open to read the journal formats and exit codes.</code></pre>
</details>

The [auto-answer entry on Tools](/tools.html#auto-answer) has the updater, README, and example CSV. The [journal reader entry](/tools.html#journal-summary) has the standalone reader and its README.
