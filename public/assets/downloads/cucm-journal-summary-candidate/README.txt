# CUCM journal summary — 0.2.0-rc1 candidate

Read one completed/preserved updater JSONL journal and summarize its recorded
outcome. This separate, offline utility never contacts CUCM, edits the source
journal, retries writes, restores configuration or declares a device reconciled.
Python 3.10+ is required; there are no third-party runtime dependencies.

## Why a separate reader

Auto-answer changes a DN after proving its sole appearance is the selected
phone's configured Line 1. BLF label updates preserve and replace a phone's whole
BLF collection. Their mutation rules remain separate. The reader shares the
operator-facing evidence conventions without changing either write mechanism.

## Supported inputs

- --tool auto-answer: original unversioned uppercase-event journals (format 0),
  plus format 1 journals from the auto-answer candidate (rc1 through rc4).
- --tool blf-label: original unversioned lowercase-event journals (format 0),
  including toolkit/discovery records and BLF postcheck/outcome pairing.

Choose the producer explicitly; the reader does not guess from filenames or
collapse the two tools' event vocabularies into a permissive common parser.
Unversioned auto-answer DISCOVERY records from the earlier review-only prototype
are intentionally unsupported. No production producer used that prototype format.
Unknown schemas, mixed formats or unrecognized events stop interpretation.

The new auto-answer format labels EVERY record with:

  "journal_schema": "noc-thoughts.cucm-auto-answer"
  "schema_version": 1

START carries mode APPLY or DRY_RUN, initial axl_version 15.0, positive integer
target_count and tool_version. DISCOVERY carries accepted_axl_version (14.0 or
15.0) and cucm_version, once before target activity. START's initial axl_version
does not prove the server accepted that schema. Startup STOPPED before discovery
is valid. APPLY with accepted AXL 14.0 may only stop; it cannot claim target
activity or success. The producer independently enforces that restriction.

The schema version identifies the journal protocol, not the CUCM release, AXL
schema or script version. Unknown future versions require an explicit reader
update. Legacy journals retain their original behavior and have no new fields
added to their files.

## Run

From the folder containing journal_summary.py, using a preserved report:

```sh
python journal_summary.py --tool auto-answer --format text preview.jsonl
python journal_summary.py --tool auto-answer --format json apply-001.jsonl
python journal_summary.py --tool blf-label --format text blf-apply.jsonl
python journal_summary.py --version
```

JSON remains the default for compatibility with the review sample. The text
format is for quick review. Both omit device names, DNs, partitions, publisher
names, snapshots, paths and free-text journal diagnostics. This is a deliberately
small summary; preserve the private original journal for investigation.

Exit codes:
  0  Recorded COMPLETE or DRY_RUN_COMPLETE with consistent evidence sequence.
  1  STOPPED, RECONCILE_REQUIRED or INCOMPLETE_EVIDENCE; inspect the report.
  2  Invalid arguments or journal could not be opened/read.

## Interpreting the summary

COMPLETE: the producer recorded completion. recorded_verified_updates counts
only paired WRITE_INTENT -> UPDATED records. ALREADY_OK is not a new update.
A successful journal can therefore have zero verified updates.

DRY_RUN_COMPLETE: the producer recorded completion of preview. No writes were
recorded or permitted by the mode. It does not qualify a later apply.

STOPPED: a recognized stop without an open intent. Earlier paired updates may
remain; this is not rollback or whole-batch success. The count remains visible.

RECONCILE_REQUIRED: an intent is unresolved, an uncertain/failed verification was
recorded, or an apply run lacks trustworthy completion. Check actual CUCM state
against the original journal before considering another write. A recorded
UNCERTAIN outcome closes the event pair but does not resolve the device state.

INCOMPLETE_EVIDENCE: the journal is empty, truncated, unsupported or inconsistent
and a supported apply mode has not established the reconciliation disposition.
Do not infer that no writes occurred simply because the mode/schema is unknown.

The first invalid record stops all further interpretation. Later valid-looking
rows cannot restore success. Duplicate JSON keys, missing final LF, invalid UTF-8,
wrong-target outcomes, repeated/overlapping intents, events after a terminal,
mode-inconsistent writes and disagreeing COMPLETE counts are rejected.
BLF UPDATED requires its matching POSTCHECK; a postcheck alone is not success.
For auto-answer, target identity includes device, extension and partition.

JSON output has summary_version 1, source_tool, source_schema_version (0 for
legacy, 1 for the new producer, null if unknown), accepted_axl_version, mode,
disposition, recorded_terminal_event, recorded_verified_updates, unmatched_intent,
recorded_unverified_outcome and first_invalid_record (one-based or null).
The source_schema_version and accepted_axl_version fields are additive to the
earlier summary sample. They are null when the evidence does not establish them;
legacy BLF discovery metadata is not normalized into accepted_axl_version.

## Limits

This is a sequence/evidence summary, not an authenticity or configuration checker.
It does not recompute snapshot correctness, validate every producer field, detect
deleted/forged records, prove a successful fsync survived a power failure, or lock
an actively written journal. Use a completed/preserved copy, keep its original
private, and inspect actual CUCM state when reconciliation is indicated.
Huge or hostile files can exhaust local resources; use journals from your own
controlled runs, not arbitrary downloaded input. No evidence is uploaded.

## Changes and tests

- Explicit version-1 auto-answer decoder with mandatory discovery ordering,
  consistent per-record format markers and the AXL 14.0 preview restriction.
- Retained separate legacy auto-answer and BLF decoders and outcome pairing.
- Human-readable --format text output alongside the existing default JSON.
- Normalized output only; raw input and private identifiers are never echoed.
- CLI, malformed-format, truncation, partial-run and cross-producer tests.

From the repository root:

```sh
python -B -m unittest discover -s scripts/cucm-journal-summary-candidate -v
python -B -m unittest discover -s scripts/cucm-auto-answer-candidate/tests -v
```

From the extracted combined review bundle, omit scripts/ in both paths. Keep the
two candidate directories side by side for cross-candidate tests. Standalone
use of journal_summary.py does not require the auto-answer script or requests.
The automated tests use synthetic inputs. In the CUCM 15 lab, the reader
reported COMPLETE with one verified rc4 update and DRY_RUN_COMPLETE with zero
updates on the repeat preview. Text and JSON matched the three preserved lab
journals. Legacy auto-answer and BLF checks used synthetic fixtures. Auto-answer writes its journal with --report.
The BLF updater accepts --log. Pass the resulting file to this reader.
