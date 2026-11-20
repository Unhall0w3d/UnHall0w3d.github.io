"""Exercise the runnable producer and offline consumer with fabricated SOAP only."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from test_auto_answer import m, UID
from test_discovery import discovery, mismatch, soap

READER = Path(__file__).resolve().parents[2] / "cucm-journal-summary-candidate" / "journal_summary.py"
spec = importlib.util.spec_from_file_location("candidate_journal_summary", READER)
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


def reads(schema="15.0", *, device="SEP020000000001", extension="001234", on=False):
    setting = m.DESIRED if on else "Auto Answer Off"
    dn_uuid = UID if device.endswith("1") else "10112233-4455-6677-8899-aabbccddeeff"
    return [
        soap(schema, "getPhone", f"<phone><name>{device}</name><lines><line><index>1</index>"
             f"<dirn><pattern>{extension}</pattern><routePartitionName/></dirn></line></lines></phone>"),
        soap(schema, "getLine", f'<line uuid="{dn_uuid}"><pattern>{extension}</pattern>'
             f"<routePartitionName/><autoAnswer>{setting}</autoAnswer></line>"),
        soap(schema, "executeSQLQuery", f"<row><device>{device}</device><lineindex>1</lineindex></row>"),
    ]


class IntegrationTests(unittest.TestCase):
    def invoke(self, responses, *, device="SEP020000000001", apply=False, second=False, fail_record=None, fail_sync=None):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source, report = folder / "targets.csv", folder / "journal.jsonl"
            source.write_text(f"Device,Extension,Partition\n{device},001234,\n" +
                              ("SEP020000000002,001235,\n" if second else ""), encoding="utf-8")
            args = [str(source), "--publisher", "cucm.example", "--username", "fictional",
                    "--report", str(report), "--delay", "0"] + (["--apply"] if apply else [])
            original_write = m.Journal.write
            original_sync = m.os.fsync

            def write(journal, event, **fields):
                if event == fail_record:
                    raise OSError("synthetic journal failure")
                original_write(journal, event, **fields)

            def sync(fd):
                last = json.loads(report.read_bytes().splitlines()[-1])
                if last["event"] == fail_sync:
                    raise OSError("synthetic fsync failure")
                original_sync(fd)

            output = io.StringIO()
            with (patch.object(m.requests.Session, "post", side_effect=responses) as post,
                  patch.object(m.Journal, "write", write),
                  patch.object(m.os, "fsync", sync),
                  patch.dict(m.os.environ, {"CUCM_AXL_PASSWORD": "PRIVATE_PASSWORD"}),
                  contextlib.redirect_stdout(output), contextlib.redirect_stderr(output)):
                status = m.main(args)
            raw = report.read_bytes()
            self.assertNotIn(b"PRIVATE_PASSWORD", raw)
            self.assertNotIn("PRIVATE_PASSWORD", output.getvalue())
            result = summary.summarize(io.BytesIO(raw), "auto-answer")
            rows = [json.loads(line) for line in raw.splitlines()]
            self.assertTrue(all(row["schema_version"] == 1 and
                                row["journal_schema"] == summary.AUTO_SCHEMA for row in rows))
            operations = [call.kwargs["headers"]["SOAPAction"].split()[-1].rstrip('"')
                          for call in post.call_args_list]
            return status, result, rows, operations

    def test_named_endpoint_preview(self):
        for device in ("CIPCLAB01", "CSFAlice", "BOTLAB1", "TCTLAB.A", "TABLAB_1", "ATA020000000001"):
            with self.subTest(device=device):
                status, result, _, ops = self.invoke(
                    [discovery("15.0", "15.0.1"), *reads(device=device)], device=device)
                self.assertEqual(status, 0)
                self.assertEqual(result["disposition"], "DRY_RUN_COMPLETE")
                self.assertNotIn("updateLine", ops)

    def test_14_and_15_preview_integrate_with_reader(self):
        for schema in ("14.0", "15.0"):
            with self.subTest(schema=schema):
                responses = ([mismatch()] if schema == "14.0" else [])
                responses += [discovery(schema, schema + ".1")] + reads(schema)
                status, result, rows, operations = self.invoke(responses)
                self.assertEqual(status, 0)
                self.assertEqual(result["disposition"], "DRY_RUN_COMPLETE")
                self.assertEqual(result["accepted_axl_version"], schema)
                self.assertEqual(result["recorded_verified_updates"], 0)
                self.assertNotIn("updateLine", operations)
                self.assertEqual(rows[0]["tool_version"], m.VERSION)

    def test_14_apply_refused_before_phone_reads_and_intents(self):
        status, result, rows, operations = self.invoke(
            [mismatch(), discovery("14.0", "14.0.1.16900(4)")], apply=True)
        self.assertEqual(status, 2)
        self.assertEqual(result["disposition"], "STOPPED")
        self.assertFalse(result["unmatched_intent"])
        self.assertEqual(operations, ["getCCMVersion", "getCCMVersion"])
        self.assertEqual([row["event"] for row in rows], ["START", "DISCOVERY", "STOPPED"])

    def test_startup_auth_failure_is_clean_stop_not_success(self):
        status, result, rows, operations = self.invoke([Mock(status_code=401)], apply=True)
        self.assertEqual(status, 2)
        self.assertEqual(result["disposition"], "STOPPED")
        self.assertIsNone(result["accepted_axl_version"])
        self.assertEqual([row["event"] for row in rows], ["START", "STOPPED"])
        self.assertEqual(operations, ["getCCMVersion"])

    def test_15_apply_verified_vs_already_correct(self):
        for already in (False, True):
            with self.subTest(already=already):
                responses = [discovery("15.0", "15.0.1")] + reads(on=already) * 2
                if not already:
                    responses += [soap("15.0", "updateLine", UID)] + reads(on=True)
                status, result, _, operations = self.invoke(responses, apply=True)
                self.assertEqual(status, 0)
                self.assertEqual(result["disposition"], "COMPLETE")
                self.assertEqual(result["recorded_verified_updates"], int(not already))
                self.assertEqual(operations.count("updateLine"), int(not already))

    def test_interrupted_write_and_readback_timeout_require_reconciliation(self):
        for tail in ([KeyboardInterrupt()], [soap("15.0", "updateLine", UID),
                                             m.requests.Timeout("PRIVATE_PASSWORD")]):
            with self.subTest(tail=tail):
                status, result, _, operations = self.invoke(
                    [discovery("15.0", "15.0.1")] + reads() * 2 + tail, apply=True)
                self.assertEqual(status, 1)
                self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
                self.assertEqual(result["recorded_unverified_outcome"], "UNCERTAIN")
                self.assertEqual(result["recorded_verified_updates"], 0)
                self.assertEqual(operations.count("updateLine"), 1)

    def test_later_prewrite_drift_retains_first_verified_update(self):
        other = dict(device="SEP020000000002", extension="001235")
        responses = ([discovery("15.0", "15.0.1")] + reads() + reads(**other) + reads()
                     + [soap("15.0", "updateLine", UID)] + reads(on=True) + reads(**other, on=True))
        status, result, _, operations = self.invoke(responses, apply=True, second=True)
        self.assertEqual(status, 1)
        self.assertEqual(result["disposition"], "STOPPED")
        self.assertEqual(result["recorded_verified_updates"], 1)
        self.assertFalse(result["unmatched_intent"])
        self.assertEqual(operations.count("updateLine"), 1)

    def test_report_failure_before_and_after_write_never_claims_success(self):
        for event in ("WRITE_INTENT", "UPDATED"):
            with self.subTest(event=event):
                responses = [discovery("15.0", "15.0.1")] + reads() * 2
                if event == "UPDATED":
                    responses += [soap("15.0", "updateLine", UID)] + reads(on=True)
                status, result, _, operations = self.invoke(responses, apply=True, fail_record=event)
                self.assertEqual(status, 2)
                self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
                self.assertEqual(result["unmatched_intent"], event == "UPDATED")
                self.assertEqual(operations.count("updateLine"), int(event == "UPDATED"))

    def test_fsync_failure_blocks_write_or_leaves_incomplete_apply(self):
        for event in ("WRITE_INTENT", "UPDATED"):
            with self.subTest(event=event):
                responses = [discovery("15.0", "15.0.1")] + reads() * 2
                if event == "UPDATED":
                    responses += [soap("15.0", "updateLine", UID)] + reads(on=True)
                status, result, _, operations = self.invoke(responses, apply=True, fail_sync=event)
                self.assertEqual(status, 2)
                self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
                self.assertEqual(operations.count("updateLine"), int(event == "UPDATED"))


if __name__ == "__main__":
    unittest.main()
