#!/usr/bin/env python3
"""Offline summary of recorded CUCM updater evidence; never contacts CUCM."""
import argparse
import json
from pathlib import Path
import re

VERSION = "0.2.0-rc1"
AUTO_SCHEMA = "noc-thoughts.cucm-auto-answer"

COMMON = "START ALREADY_OK REJECTED STOPPED DRY_RUN_COMPLETE WRITE_INTENT UPDATED UNCERTAIN COMPLETE"
EVENTS = {
    "auto-answer": dict((e, e) for e in (COMMON + " READY").split()),
    "blf-label": {e.lower(): e for e in (
        COMMON + " PRECHECK PREWRITE_CHECK POSTCHECK POSTCHECK_ALREADY_OK"
        " VERIFICATION_FAILED DISCOVERY TOOLKIT TOOLKIT_LOCAL"
        " TOOLKIT_DOWNLOAD_STARTED TOOLKIT_DOWNLOADED"
    ).split()} | {"update_needed": "READY"},
}
TERMINAL = {"COMPLETE", "DRY_RUN_COMPLETE", "STOPPED", "UNCERTAIN", "VERIFICATION_FAILED"}
WRITE_EVENTS = {"WRITE_INTENT", "UPDATED", "UNCERTAIN", "VERIFICATION_FAILED", "COMPLETE"}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def identity(tool, row):
    if tool == "blf-label":
        key = (row.get("device"),)
    else:
        target = row.get("target")
        if not isinstance(target, dict):
            raise ValueError("missing target")
        key = tuple(target.get(k) for k in ("device", "extension", "partition"))
    if not all(isinstance(part, str) for part in key) or not key[0]:
        raise ValueError("invalid target identity")
    return key


def summarize(lines, tool):
    verified = 0
    pending = None
    postcheck = False
    attempted = set()
    unverified = None
    terminal = None
    mode = None
    issue_line = None
    source_version = None
    accepted_schema = None
    discovery_seen = False
    activity_seen = False
    for number, raw in enumerate(lines, 1):
        try:
            # Both original writers terminate each record with LF. A syntactically
            # complete JSON object without LF is still an incomplete legacy record.
            if terminal or not raw.endswith(b"\n"):
                raise ValueError("record after terminal event or missing newline")
            row = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
            if not isinstance(row, dict):
                raise ValueError("unknown input schema")
            # Versioned producers label every record, so concatenated or mixed
            # formats cannot silently inherit the first record's interpretation.
            if number == 1:
                if "schema_version" not in row and "journal_schema" not in row:
                    source_version = 0
                elif (tool == "auto-answer" and row.get("journal_schema") == AUTO_SCHEMA
                      and type(row.get("schema_version")) is int and row["schema_version"] == 1):
                    source_version = 1
                else:
                    raise ValueError("unknown input schema")
            if source_version == 0:
                if "schema_version" in row or "journal_schema" in row:
                    raise ValueError("mixed input schemas")
            elif (row.get("journal_schema") != AUTO_SCHEMA
                  or type(row.get("schema_version")) is not int or row["schema_version"] != 1):
                raise ValueError("mixed input schemas")
            legacy = row.get("event")
            event = EVENTS[tool].get(legacy) if isinstance(legacy, str) else None
            if source_version == 1 and legacy == "DISCOVERY":
                event = "DISCOVERY"
            if event is None:
                raise ValueError("unknown event")
            if number == 1:
                if event != "START":
                    raise ValueError("missing start")
                value = row.get("mode")
                modes = {"APPLY": "apply", "DRY_RUN": "dry_run"} if tool == "auto-answer" else {
                    "apply": "apply", "dry_run": "dry_run"
                }
                if not isinstance(value, str) or value not in modes:
                    raise ValueError("unknown mode")
                mode = modes[value]
                if source_version == 1 and (row.get("axl_version") != "15.0"
                        or type(row.get("target_count")) is not int or row["target_count"] < 1):
                    raise ValueError("invalid start metadata")
                continue
            if (event == "START" or (event in WRITE_EVENTS and mode != "apply")
                    or (event == "DRY_RUN_COMPLETE" and mode != "dry_run")):
                raise ValueError("event inconsistent with run")
            if source_version == 1:
                if event == "DISCOVERY":
                    schema = row.get("accepted_axl_version")
                    release = row.get("cucm_version")
                    if (discovery_seen or activity_seen or not isinstance(schema, str)
                            or schema not in {"14.0", "15.0"}
                            or not isinstance(release, str)
                            or not re.fullmatch(r"(?:14|15)\.\d+(?:\.\d+)*(?:-\d+|\(\d+\))?", release)
                            or (schema == "15.0" and release.startswith("14."))):
                        raise ValueError("invalid or misplaced discovery")
                    accepted_schema = schema
                    discovery_seen = True
                    continue
                if event != "STOPPED" and (not discovery_seen
                        or (mode == "apply" and accepted_schema != "15.0")):
                    raise ValueError("activity without an allowed discovered schema")
                activity_seen = True
            if event == "WRITE_INTENT":
                if pending is not None:
                    raise ValueError("overlapping intent")
                pending = identity(tool, row)
                if pending in attempted:
                    raise ValueError("repeated intent")
                attempted.add(pending)
                postcheck = False
            elif event in {"UPDATED", "UNCERTAIN", "VERIFICATION_FAILED"}:
                if pending is None or identity(tool, row) != pending:
                    raise ValueError("outcome cannot be paired")
                if tool == "blf-label" and (event != "UNCERTAIN") != postcheck:
                    raise ValueError("outcome inconsistent with BLF read-back")
                if event == "UPDATED":
                    verified += 1
                else:
                    unverified = event
                pending = None
            elif pending is not None:
                if event != "POSTCHECK" or postcheck or identity(tool, row) != pending:
                    raise ValueError("intent interrupted by unexpected event")
                postcheck = True
            elif event == "POSTCHECK":
                raise ValueError("postcheck without intent")
            if event == "COMPLETE":
                count_field = "updated" if tool == "blf-label" else "verified_updates"
                claimed = row.get(count_field)
                if type(claimed) is not int or claimed != verified:
                    raise ValueError("terminal count disagrees with paired evidence")
            if event in TERMINAL:
                terminal = event
        except (ValueError, RecursionError):
            # Stop pairing at the first bad record. Later rows cannot restore
            # trust in the sequence. Never copy raw journal data into the summary.
            issue_line = number
            break

    if unverified or pending is not None or (mode == "apply" and (issue_line or not terminal)):
        disposition = "RECONCILE_REQUIRED"
    elif issue_line or not terminal:
        disposition = "INCOMPLETE_EVIDENCE"
    else:
        disposition = terminal
    return {
        "summary_version": 1,
        "source_tool": tool,
        "source_schema_version": source_version,
        "accepted_axl_version": accepted_schema,
        "mode": mode,
        "disposition": disposition,
        "recorded_terminal_event": terminal,
        "recorded_verified_updates": verified,
        "unmatched_intent": pending is not None,
        "recorded_unverified_outcome": unverified,
        "first_invalid_record": issue_line,
    }


def human_summary(result):
    """Only render normalized fields, never journal identifiers or free text."""
    terminal = result["recorded_terminal_event"] or "none"
    mode = result["mode"] or "unknown"
    version = result["source_schema_version"]
    lines = [
        f'Disposition: {result["disposition"]}',
        f'Source: {result["source_tool"]}; journal format: {version if version is not None else "unknown"}',
        f'Mode: {mode}; accepted AXL schema: {result["accepted_axl_version"] or "not recorded"}',
        f'Recorded terminal event: {terminal}',
        f'Recorded verified updates: {result["recorded_verified_updates"]}',
        f'Unmatched write intent: {"yes" if result["unmatched_intent"] else "no"}',
        f'Recorded unverified outcome: {result["recorded_unverified_outcome"] or "none"}',
        f'First invalid record: {result["first_invalid_record"] or "none"}',
        'This summarizes recorded evidence only; it does not verify current CUCM state.',
    ]
    if result["disposition"] == "RECONCILE_REQUIRED":
        lines.append("Reconcile against CUCM before rerunning; earlier verified changes may remain.")
    elif result["disposition"] == "INCOMPLETE_EVIDENCE":
        lines.append("Evidence is incomplete or unsupported; do not treat this as a successful run.")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    parser.add_argument("--tool", choices=EVENTS, required=True)
    parser.add_argument("--format", choices=("json", "text"), default="json",
                        help="Output format (default: json, compatible with the review sample)")
    parser.add_argument("journal", type=Path, help="Existing journal; read only")
    args = parser.parse_args(argv)
    try:
        with args.journal.open("rb") as stream:
            result = summarize(stream, args.tool)
    except OSError:
        parser.exit(2, "Could not read journal.\n")
    print(json.dumps(result, sort_keys=True) if args.format == "json" else human_summary(result))
    return 0 if result["disposition"] in {"COMPLETE", "DRY_RUN_COMPLETE"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
