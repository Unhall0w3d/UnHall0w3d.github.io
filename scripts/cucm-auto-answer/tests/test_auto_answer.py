import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[1] / "auto-answer-update.py"
spec = importlib.util.spec_from_file_location("auto_answer", SOURCE)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

UID = "00112233-4455-6677-8899-aabbccddeeff"
T = m.Target("SEP020000000001", "001234", "LAB_PT", 2)
OFF = m.Snapshot(UID, "Auto Answer Off", ((T.device, 1),))
ON = m.Snapshot(UID, m.DESIRED, OFF.appearances)


class Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)

    def csv(self, text):
        path = self.directory / "input.csv"
        path.write_text(text, encoding="utf-8")
        return m.load_csv(path)

    def test_device_formats(self):
        for raw in ("SEP020000000001", "020000000001", "02:00:00:00:00:01",
                    "02-00-00-00-00-01", "0200.0000.0001"):
            self.assertEqual(m.normalize_device(raw), T.device)
        for raw in ("ZZ020000000001", "SEP02:00:00:00:00:01", "0200/0000/0001",
                    "02:00-00:00:00:01", "020000000001junk"):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                m.normalize_device(raw)

    def test_csv_preserves_leading_zeros_and_empty_partition(self):
        targets = self.csv("\ufeffDevice,Extension,Partition\n020000000001,001234,\n")
        self.assertEqual(targets[0].extension, "001234")
        self.assertEqual(targets[0].partition, "")

    def test_csv_rejects_bad_rows_and_duplicates(self):
        for text in (
            "Device,Extension,Partition,Partition\n",
            "Device,Extension,Partition\n020000000001,1234\n",
            "Device,Extension,Partition\n020000000001,1234,PT,extra\n",
            "Device,Extension,Partition\n020000000001,,PT\n",
            "Device,Extension,Partition\n020000000001,1234,PT\n020000000001,4567,PT\n",
            "Device,Extension,Partition\n020000000001,1234,PT\n020000000002,1234,PT\n",
            'Device,Extension,Partition\n020000000001,"12\n34",PT\n',
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.csv(text)

    def test_publisher_rejects_url_and_authority_injection(self):
        for raw in ("https://cucm.example", "name@cucm.example", "cucm.example/path",
                    "cucm.example:8443", "cucm.example?x=1", ""):
            with self.subTest(raw=raw), self.assertRaises(m.argparse.ArgumentTypeError):
                m.publisher_host(raw)
        self.assertEqual(m.publisher_host("2001:db8::1"), "[2001:db8::1]")

    def client(self):
        client = m.AXLClient("cucm.example", "fictional", "fictional")
        self.addCleanup(client.close)
        return client

    def test_get_line_requires_setting_identity_and_uuid(self):
        client = self.client()
        for inner in (
            f'<line uuid="{UID}"><pattern>001234</pattern><routePartitionName>LAB_PT</routePartitionName></line>',
            f'<line uuid="{UID}"><pattern>001234</pattern><routePartitionName>LAB_PT</routePartitionName><autoAnswer>unexpected</autoAnswer></line>',
            '<line><pattern>001234</pattern><routePartitionName>LAB_PT</routePartitionName><autoAnswer>Auto Answer Off</autoAnswer></line>',
            f'<line uuid="{UID}"><pattern>other</pattern><routePartitionName>LAB_PT</routePartitionName><autoAnswer>Auto Answer Off</autoAnswer></line>',
        ):
            client._post = Mock(return_value=m.ET.fromstring(f"<return>{inner}</return>"))
            with self.subTest(inner=inner), self.assertRaises(m.AXLException):
                client.line(T)

    def test_soap_transport_envelope_and_redirects(self):
        client = self.client()
        response = Mock(status_code=200, content=(
            f'<s:Envelope xmlns:s="{m.SOAP_NS}" xmlns:a="{m.AXL_NS}">'
            f'<s:Body><a:updateLineResponse><return>{{{UID.upper()}}}</return>'
            '</a:updateLineResponse></s:Body></s:Envelope>').encode())
        client.session.post = Mock(return_value=response)
        client.update(UID)
        kwargs = client.session.post.call_args.kwargs
        self.assertFalse(kwargs["allow_redirects"])
        self.assertTrue(client.session.verify)
        self.assertIn(f"<uuid>{UID}</uuid>".encode(), kwargs["data"])
        for status, content in ((302, b""), (500, b"secret response"),
                                (200, b"<return/>"), (200, b"invalid")):
            response.status_code, response.content = status, content
            with self.assertRaises(m.AXLException) as raised:
                client.update(UID)
            self.assertNotIn("secret response", str(raised.exception))

    def test_shared_or_wrong_appearance_rejected(self):
        client = self.client()
        client.phone_line1 = Mock()
        client.line = Mock(return_value=(UID, "Auto Answer Off"))
        for appearances in ((), ((T.device, 2),), ((T.device, 1), ("SEP020000000002", 1))):
            client.appearances = Mock(return_value=appearances)
            with self.subTest(appearances=appearances), self.assertRaises(m.AXLException):
                client.inspect(T)

    def test_complete_mocked_soap_apply_unpartitioned_dn(self):
        target = m.Target(T.device, T.extension, "", 2)
        client = self.client()
        state = {"auto": "Auto Answer Off"}
        operations = []
        def server(url, **kwargs):
            envelope = m.ET.fromstring(kwargs["data"])
            request = envelope.find(f"{{{m.SOAP_NS}}}Body")[0]
            operation = m.local(request.tag)
            operations.append(operation)
            if operation == "getPhone":
                payload = (f"<phone><name>{T.device}</name><lines><line><index>1</index>"
                           f"<dirn><pattern>{T.extension}</pattern><routePartitionName/>"
                           "</dirn></line></lines></phone>")
            elif operation == "getLine":
                self.assertEqual(m.value(request, "routePartitionName", empty=True), "")
                payload = (f'<line uuid="{{{UID}}}"><pattern>{T.extension}</pattern>'
                           f'<routePartitionName/><autoAnswer>{state["auto"]}</autoAnswer></line>')
            elif operation == "executeSQLQuery":
                sql = m.value(request, "sql")
                self.assertIn(f"m.fknumplan='{UID}'", sql)
                self.assertNotIn("rp.name", sql)
                payload = f"<row><device>{T.device}</device><lineindex>1</lineindex></row>"
            elif operation == "updateLine":
                self.assertEqual(m.value(request, "uuid"), UID)
                self.assertEqual(m.value(request, "autoAnswer"), m.DESIRED)
                state["auto"] = m.DESIRED
                payload = UID
            else:
                self.fail(f"Unexpected operation: {operation}")
            return Mock(status_code=200, content=(
                f'<s:Envelope xmlns:s="{m.SOAP_NS}" xmlns:a="{m.AXL_NS}"><s:Body>'
                f'<a:{operation}Response><return>{payload}</return></a:{operation}Response>'
                '</s:Body></s:Envelope>').encode())
        client.session.post = Mock(side_effect=server)
        code, records = self.execute(client, [target])
        self.assertEqual(code, 0)
        self.assertEqual(operations, ["getPhone", "getLine", "executeSQLQuery"] * 2
                         + ["updateLine", "getPhone", "getLine", "executeSQLQuery"])
        self.assertEqual(records[-1]["event"], "COMPLETE")

    def test_transport_timeout_does_not_echo_sensitive_exception(self):
        client = self.client()
        client.session.post = Mock(side_effect=m.requests.Timeout("secret request details"))
        with self.assertRaises(m.AXLException) as raised:
            client.update(UID)
        self.assertNotIn("secret", str(raised.exception))
        self.assertEqual(client.session.post.call_count, 1)

    def execute(self, client, targets=None, apply=True):
        journal = m.Journal(self.directory / "audit.jsonl")
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                code = m.run(client, targets or [T], apply, journal, 0)
        finally:
            journal.close()
        records = [json.loads(line) for line in (self.directory / "audit.jsonl").read_text().splitlines()]
        return code, records

    def test_dry_run_never_writes(self):
        client = Mock(inspect=Mock(return_value=OFF))
        code, _ = self.execute(client, apply=False)
        self.assertEqual(code, 0)
        client.update.assert_not_called()

    def test_any_preflight_failure_blocks_entire_batch(self):
        other = m.Target("SEP020000000002", "5678", "LAB_PT", 3)
        client = Mock(inspect=Mock(side_effect=[OFF, m.AXLException("mismatch")]))
        code, _ = self.execute(client, [T, other])
        self.assertEqual(code, 1)
        client.update.assert_not_called()

    def test_drift_blocks_write(self):
        client = Mock(inspect=Mock(side_effect=[OFF, ON]))
        code, records = self.execute(client)
        self.assertEqual(code, 1)
        client.update.assert_not_called()
        self.assertEqual(records[-1]["event"], "STOPPED")

    def test_already_ok_rechecked_without_write(self):
        client = Mock(inspect=Mock(return_value=ON))
        code, _ = self.execute(client)
        self.assertEqual(code, 0)
        self.assertEqual(client.inspect.call_count, 2)
        client.update.assert_not_called()

    def test_success_has_durable_intent_before_write(self):
        client = Mock(inspect=Mock(side_effect=[OFF, OFF, ON]))
        def assert_intent(_):
            records = [json.loads(line) for line in (self.directory / "audit.jsonl").read_text().splitlines()]
            self.assertEqual(records[-1]["event"], "WRITE_INTENT")
            self.assertEqual(records[-1]["before"]["auto_answer"], "Auto Answer Off")
        client.update.side_effect = assert_intent
        code, records = self.execute(client)
        self.assertEqual(code, 0)
        self.assertEqual([r["event"] for r in records], ["READY", "WRITE_INTENT", "UPDATED", "COMPLETE"])

    def test_timeout_stops_remaining_writes_as_uncertain(self):
        other = m.Target("SEP020000000002", "5678", "LAB_PT", 3)
        client = Mock(inspect=Mock(return_value=OFF), update=Mock(side_effect=m.AXLException("timeout")))
        code, records = self.execute(client, [T, other])
        self.assertEqual(code, 1)
        self.assertEqual(client.update.call_count, 1)
        self.assertEqual(records[-1]["event"], "UNCERTAIN")

    def test_failed_readback_is_uncertain(self):
        client = Mock(inspect=Mock(side_effect=[OFF, OFF, OFF]))
        code, records = self.execute(client)
        self.assertEqual(code, 1)
        self.assertEqual(records[-1]["event"], "UNCERTAIN")

    def test_journal_error_prevents_write(self):
        client = Mock(inspect=Mock(return_value=OFF))
        journal = Mock()
        def fail(event, **fields):
            if event == "WRITE_INTENT":
                raise OSError("disk full")
        journal.write.side_effect = fail
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
            m.run(client, [T], True, journal, 0)
        client.update.assert_not_called()

    def test_journal_failure_after_write_leaves_unmatched_intent(self):
        client = Mock(inspect=Mock(side_effect=[OFF, OFF, ON]))
        journal = m.Journal(self.directory / "audit.jsonl")
        original = journal.write
        def fail(event, **fields):
            if event == "UPDATED":
                raise OSError("disk full")
            original(event, **fields)
        journal.write = fail
        try:
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
                m.run(client, [T], True, journal, 0)
        finally:
            journal.close()
        records = [json.loads(line) for line in (self.directory / "audit.jsonl").read_text().splitlines()]
        self.assertEqual(records[-1]["event"], "WRITE_INTENT")
        client.update.assert_called_once()

    def test_journal_never_overwrites(self):
        path = self.directory / "existing.jsonl"
        path.write_text("keep")
        with self.assertRaises(FileExistsError):
            m.Journal(path)
        self.assertEqual(path.read_text(), "keep")

    def test_cli_rejects_bad_controls_before_credentials(self):
        for extra in (["--apply"], ["--timeout", "0"], ["--delay", "nan"],
                      ["--delay", "-1"], ["--insecure"], ["--allow-shared"]):
            with self.subTest(extra=extra), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                m.main(["unused.csv", "--publisher", "cucm.example", *extra])


if __name__ == "__main__":
    unittest.main()
