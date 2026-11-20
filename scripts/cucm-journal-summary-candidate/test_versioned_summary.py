"""Version boundaries and evidence handling, using fictional records only."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from journal_summary import AUTO_SCHEMA, human_summary, main, summarize

TARGET = {"device": "PRIVATE_DEVICE", "extension": "PRIVATE_DN", "partition": "PRIVATE_PARTITION"}


def record(event, **fields):
    return {"journal_schema": AUTO_SCHEMA, "schema_version": 1, "event": event, **fields}


def start(mode="APPLY"):
    return record("START", mode=mode, axl_version="15.0", target_count=1)


def discovery(schema="15.0"):
    return record("DISCOVERY", accepted_axl_version=schema, cucm_version=schema + ".1")


def encode(rows):
    return b"".join(json.dumps(row).encode() + b"\n" for row in rows)


def report(*rows):
    return summarize(io.BytesIO(encode(rows)), "auto-answer")


class VersionedSummaryTests(unittest.TestCase):
    def test_supported_preview_and_clean_apply(self):
        for schema in ("14.0", "15.0"):
            result = report(start("DRY_RUN"), discovery(schema), record("DRY_RUN_COMPLETE"))
            self.assertEqual(result["disposition"], "DRY_RUN_COMPLETE")
            self.assertEqual(result["source_schema_version"], 1)
            self.assertEqual(result["accepted_axl_version"], schema)
        result = report(start(), discovery(), record("WRITE_INTENT", target=TARGET),
                        record("UPDATED", target=TARGET), record("COMPLETE", verified_updates=1))
        self.assertEqual(result["disposition"], "COMPLETE")
        self.assertEqual(result["recorded_verified_updates"], 1)

    def test_unknown_or_mixed_format_never_succeeds(self):
        for fields in ({"schema_version": 2}, {"schema_version": True},
                       {"schema_version": "1"}, {"journal_schema": "other"}):
            result = report(start() | fields, discovery(), record("COMPLETE", verified_updates=0))
            self.assertEqual(result["first_invalid_record"], 1)
            self.assertEqual(result["disposition"], "INCOMPLETE_EVIDENCE")
        for row in ({"event": "COMPLETE", "verified_updates": 0},
                    record("COMPLETE", verified_updates=0) | {"schema_version": 2}):
            result = report(start(), discovery(), row)
            self.assertEqual(result["first_invalid_record"], 3)
            self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
        result = report({"event": "START", "mode": "APPLY"}, discovery())
        self.assertEqual(result["first_invalid_record"], 2)

    def test_unversioned_discovery_is_not_assumed_supported(self):
        result = report({"event": "START", "mode": "DRY_RUN"},
                        {"event": "DISCOVERY", "accepted_axl_version": "14.0"},
                        {"event": "DRY_RUN_COMPLETE"})
        self.assertEqual(result["disposition"], "INCOMPLETE_EVIDENCE")
        self.assertEqual(result["first_invalid_record"], 2)

    def test_discovery_required_exactly_once_before_activity(self):
        for rows in (
            [start(), record("COMPLETE", verified_updates=0)],
            [start(), discovery(), discovery(), record("COMPLETE", verified_updates=0)],
            [start(), record("READY", target=TARGET), discovery()],
            [start(), discovery(), record("READY", target=TARGET), discovery()],
        ):
            with self.subTest(rows=rows):
                result = report(*rows)
                self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
                self.assertIsNotNone(result["first_invalid_record"])

    def test_invalid_discovery_metadata_is_handled_without_echo(self):
        for bad in ({"accepted_axl_version": []}, {"accepted_axl_version": "16.0"},
                    {"cucm_version": "PRIVATE_RELEASE"}, {"cucm_version": None},
                    {"cucm_version": "14.0.1"}):
            result = report(start(), discovery() | bad)
            self.assertEqual(result["first_invalid_record"], 2)
            self.assertNotIn("PRIVATE_RELEASE", json.dumps(result))

    def test_14_apply_only_permits_clean_refusal(self):
        result = report(start(), discovery("14.0"), record("STOPPED"))
        self.assertEqual(result["disposition"], "STOPPED")
        for event in ("READY", "WRITE_INTENT", "COMPLETE"):
            result = report(start(), discovery("14.0"), record(event, target=TARGET, verified_updates=0))
            self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
            self.assertEqual(result["first_invalid_record"], 3)

    def test_startup_stop_is_valid_but_incomplete_start_is_not_success(self):
        result = report(start(), record("STOPPED", reason="PRIVATE_REASON"))
        self.assertEqual(result["disposition"], "STOPPED")
        self.assertIsNone(result["accepted_axl_version"])
        self.assertEqual(report(start())["disposition"], "RECONCILE_REQUIRED")
        self.assertEqual(report(start("DRY_RUN"))["disposition"], "INCOMPLETE_EVIDENCE")

    def test_earlier_success_does_not_clear_later_uncertainty(self):
        later = TARGET | {"extension": "PRIVATE_OTHER"}
        for ending in ([], [record("UNCERTAIN", target=later)]):
            result = report(start(), discovery(), record("WRITE_INTENT", target=TARGET),
                            record("UPDATED", target=TARGET), record("WRITE_INTENT", target=later), *ending)
            self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
            self.assertEqual(result["recorded_verified_updates"], 1)
            self.assertEqual(result["unmatched_intent"], not ending)

    def test_framing_and_duplicate_keys_still_reject_versioned_evidence(self):
        before = encode([start(), discovery(), record("WRITE_INTENT", target=TARGET)])
        for tail in (encode([record("UPDATED", target=TARGET)]).rstrip(b"\n"), b"\xff\n",
                     b'{"event":"UPDATED","event":"UPDATED"}\n'):
            result = summarize(io.BytesIO(before + tail), "auto-answer")
            self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
            self.assertTrue(result["unmatched_intent"])
            self.assertEqual(result["first_invalid_record"], 4)

    def test_stop_with_open_intent_is_uncertain_not_clean_stop(self):
        result = report(start(), discovery(), record("WRITE_INTENT", target=TARGET), record("STOPPED"))
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
        self.assertTrue(result["unmatched_intent"])

    def test_human_and_json_do_not_expose_private_fields(self):
        result = report(start() | {"publisher": "PRIVATE_HOST"}, discovery(),
                        record("WRITE_INTENT", target=TARGET),
                        record("UNCERTAIN", target=TARGET, reason="PRIVATE_REASON"))
        output = human_summary(result) + json.dumps(result)
        self.assertNotIn("PRIVATE_", output)
        self.assertIn("Reconcile against CUCM", output)
        self.assertIn("Recorded verified updates: 0", output)

    def test_cli_outputs_exit_codes_and_file_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "journal.jsonl"
            for rows, expected in (([start("DRY_RUN"), discovery(), record("DRY_RUN_COMPLETE")], 0),
                                   ([start(), record("STOPPED")], 1),
                                   ([start(), discovery(), record("WRITE_INTENT", target=TARGET)], 1)):
                raw = encode(rows)
                path.write_bytes(raw)
                for fmt in ("json", "text"):
                    stdout = io.StringIO()
                    with contextlib.redirect_stdout(stdout):
                        status = main(["--tool", "auto-answer", "--format", fmt, str(path)])
                    self.assertEqual(status, expected)
                    self.assertEqual(path.read_bytes(), raw)
                    self.assertNotIn("PRIVATE_", stdout.getvalue())
                    if fmt == "json":
                        self.assertEqual(json.loads(stdout.getvalue())["source_schema_version"], 1)
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                main(["--tool", "auto-answer", str(path.with_name("missing.jsonl"))])
            self.assertEqual(error.exception.code, 2)

    def test_entrypoint_runs_offline(self):
        result = subprocess.run([sys.executable, "-B", str(Path(__file__).with_name("journal_summary.py")),
                                 "--tool", "blf-label", str(Path(__file__).with_name("fixtures") / "blf-mismatch.jsonl")],
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["disposition"], "RECONCILE_REQUIRED")


if __name__ == "__main__":
    unittest.main()
