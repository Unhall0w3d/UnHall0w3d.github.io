"""Offline tests against synthetic legacy records."""
import io
import json
from pathlib import Path
import unittest

from journal_summary import summarize

FIXTURES = Path(__file__).with_name("fixtures")
TARGET = {"device": "TEST-A", "extension": "101", "partition": ""}


def auto(*rows, mode="APPLY", fragment=b""):
    start = {"event": "START", "mode": mode}
    payload = b"".join(json.dumps(row).encode() + b"\n" for row in (start, *rows))
    return summarize(io.BytesIO(payload + fragment), "auto-answer")


class JournalSummaryTests(unittest.TestCase):
    def test_earlier_verified_update_does_not_clear_later_intent(self):
        with (FIXTURES / "auto-aborted.jsonl").open("rb") as journal:
            result = summarize(journal, "auto-answer")
        self.assertEqual(result["recorded_verified_updates"], 1)
        self.assertTrue(result["unmatched_intent"])
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")

    def test_blf_postcheck_does_not_verify_mismatch_or_leak_details(self):
        with (FIXTURES / "blf-mismatch.jsonl").open("rb") as journal:
            result = summarize(journal, "blf-label")
        self.assertFalse(result["unmatched_intent"])
        self.assertEqual(result["recorded_unverified_outcome"], "VERIFICATION_FAILED")
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
        self.assertEqual(result["recorded_verified_updates"], 0)
        for private in ("SYNTHETIC_PII_MARKER", "TEST-A", "synthetic.invalid"):
            self.assertNotIn(private, json.dumps(result))

    def test_noop_is_not_an_update(self):
        result = auto({"event": "ALREADY_OK", "target": TARGET},
                      {"event": "COMPLETE", "verified_updates": 0})
        self.assertEqual(result["recorded_verified_updates"], 0)
        self.assertEqual(result["disposition"], "COMPLETE")

    def test_wrong_target_cannot_resolve_intent_even_with_same_device(self):
        result = auto({"event": "WRITE_INTENT", "target": TARGET},
                      {"event": "UPDATED", "target": TARGET | {"partition": "TEST"}},
                      {"event": "UPDATED", "target": TARGET})
        self.assertEqual(result["first_invalid_record"], 3)
        self.assertTrue(result["unmatched_intent"])
        self.assertEqual(result["recorded_verified_updates"], 0)

    def test_truncation_and_unknown_event_stop_pairing(self):
        for fragment in (b'{"event":"UPDATED"}', b'{"event":"NEW_DISCOVERY"}\n',
                         b'{"event":"UPDATED","event":"UPDATED"}\n', b"\xff\n"):
            with self.subTest(fragment=fragment):
                result = auto({"event": "WRITE_INTENT", "target": TARGET}, fragment=fragment)
                self.assertTrue(result["unmatched_intent"])
                self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")

    def test_uncertain_record_is_not_reconciliation(self):
        result = auto({"event": "WRITE_INTENT", "target": TARGET},
                      {"event": "UNCERTAIN", "target": TARGET},
                      {"event": "COMPLETE"})
        self.assertFalse(result["unmatched_intent"])
        self.assertEqual(result["recorded_unverified_outcome"], "UNCERTAIN")
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")

    def test_blf_verified_readback_counts_only_after_updated(self):
        with (FIXTURES / "blf-mismatch.jsonl").open("rb") as journal:
            rows = list(journal)
        updated = b'{"event":"updated","device":"TEST-A"}\n'
        complete = b'{"event":"complete","updated":1,"already_ok":0}\n'
        result = summarize(rows[:-1] + [updated, complete], "blf-label")
        self.assertEqual(result["recorded_verified_updates"], 1)
        self.assertEqual(result["disposition"], "COMPLETE")
        result = summarize(rows[:-2] + [updated, complete], "blf-label")
        self.assertEqual(result["recorded_verified_updates"], 0)
        self.assertTrue(result["unmatched_intent"])

    def test_inconsistent_complete_does_not_clear_missing_evidence(self):
        result = auto({"event": "COMPLETE", "verified_updates": 1})
        self.assertEqual(result["recorded_verified_updates"], 0)
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")

    def test_blf_postcheck_without_updated_leaves_intent(self):
        with (FIXTURES / "blf-mismatch.jsonl").open("rb") as journal:
            rows = list(journal)
        result = summarize(rows[:-1], "blf-label")
        self.assertTrue(result["unmatched_intent"])
        self.assertEqual(result["disposition"], "RECONCILE_REQUIRED")
        self.assertEqual(result["recorded_verified_updates"], 0)

    def test_legacy_selection_and_mode_are_checked(self):
        with (FIXTURES / "blf-mismatch.jsonl").open("rb") as journal:
            result = summarize(journal, "auto-answer")
        self.assertEqual(result["disposition"], "INCOMPLETE_EVIDENCE")
        self.assertEqual(result["first_invalid_record"], 1)
        result = auto({"event": "WRITE_INTENT", "target": TARGET}, mode="DRY_RUN")
        self.assertEqual(result["disposition"], "INCOMPLETE_EVIDENCE")

    def test_dry_run_and_clean_stop_are_distinct(self):
        result = auto({"event": "DRY_RUN_COMPLETE"}, mode="DRY_RUN")
        self.assertEqual(result["disposition"], "DRY_RUN_COMPLETE")
        result = auto({"event": "STOPPED", "verified_updates": 99})
        self.assertEqual(result["disposition"], "STOPPED")
        self.assertEqual(result["recorded_verified_updates"], 0)


if __name__ == "__main__":
    unittest.main()
