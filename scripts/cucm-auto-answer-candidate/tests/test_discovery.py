"""Synthetic offline tests for discovery and the CLI connection boundary."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import requests

from test_auto_answer import m, UID


def soap(schema, operation, payload):
    xml = (f'<s:Envelope xmlns:s="{m.SOAP_NS}" xmlns:a="{m.AXL_BASE}{schema}">'
           f'<s:Body><a:{operation}Response><return>{payload}</return>'
           f'</a:{operation}Response></s:Body></s:Envelope>')
    return Mock(status_code=200, content=xml.encode("utf-8"))


def discovery(schema, version):
    return soap(schema, "getCCMVersion",
                f"<componentVersion><version>{version}</version></componentVersion>")


def mismatch(advertised="11.x, 12.x and 14.x"):
    return Mock(status_code=599, text=(
        f"<html><p>Incorrect axl version. Supported axl versions are {advertised}.</p></html>"
    ))


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.client = m.AXLClient("cucm.example", "fictional", "fictional")
        self.addCleanup(self.client.close)
        self.post = self.client.session.post = Mock()

    def test_15_uses_one_versioned_read(self):
        self.post.return_value = discovery("15.0", "15.0.1.10000-1")
        self.assertEqual(self.client.discover(), "15.0.1.10000-1")
        self.assertEqual(self.client.schema, "15.0")
        self.post.assert_called_once()
        self.assert_request(self.post.call_args, "15.0", "getCCMVersion")
        self.assertIn(b"<processNodeName/>", self.post.call_args.kwargs["data"])

    def test_parenthesized_build_is_metadata_not_schema_selection(self):
        for version in ("14.0.1.16900(4)", "14.0.1.16900-4"):
            with self.subTest(version=version):
                self.post.side_effect = [mismatch(), discovery("14.0", version)]
                self.assertEqual(self.client.discover(), version)
                self.assertEqual(self.client.schema, "14.0")
        for version in ("14.0.1.16900(4", "14.0.1.16900(4)x", "14.0.1.16900()", "14.0.1.16900(-4)"):
            with self.subTest(version=version):
                self.post.side_effect = [mismatch(), discovery("14.0", version)]
                with self.assertRaises(m.AXLException):
                    self.client.discover()

    def assert_request(self, call, schema, operation):
        self.assertEqual(call.args, ("https://cucm.example:8443/axl/",))
        self.assertEqual(call.kwargs["timeout"], 30)
        self.assertFalse(call.kwargs["allow_redirects"])
        self.assertEqual(call.kwargs["headers"]["SOAPAction"], f'"CUCM:DB ver={schema} {operation}"')
        self.assertIn(f'xmlns:axl="{m.AXL_BASE}{schema}"'.encode(), call.kwargs["data"])

    def test_599_fallback_is_read_only_and_pins_schema(self):
        self.post.side_effect = [
            mismatch(), discovery("14.0", "14.0.1.10000-1"),
            soap("14.0", "executeSQLQuery", ""),
        ]
        self.assertEqual(self.client.discover(), "14.0.1.10000-1")
        self.assertEqual(self.client.appearances(UID), ())
        for call, schema, operation in zip(self.post.call_args_list,
                ("15.0", "14.0", "14.0"), ("getCCMVersion", "getCCMVersion", "executeSQLQuery")):
            self.assert_request(call, schema, operation)
        with self.assertRaisesRegex(m.AXLException, "only permits apply"):
            self.client.update(UID)
        self.assertEqual(self.post.call_count, 3)

    def test_only_explicit_599_advertisement_can_fall_back(self):
        for response in [
            Mock(status_code=status, text=mismatch().text) for status in (302, 401, 403, 500, 503)
        ] + [mismatch("12.5"), mismatch("14.01"), mismatch("14.x PRIVATE_SERVER_TEXT"),
             Mock(status_code=599, text="PRIVATE_SERVER_TEXT")]:
            with self.subTest(status=response.status_code, body=response.text):
                self.post.reset_mock()
                self.post.return_value = response
                with self.assertRaises(m.AXLException) as raised:
                    self.client.discover()
                self.assertNotIn("PRIVATE_SERVER_TEXT", str(raised.exception))
                self.post.assert_called_once()

    def test_explicit_ca_path_wins_over_environment(self):
        self.client.session.verify = "/fictional/explicit-ca.pem"
        response = discovery("15.0", "15.0.1")
        with (patch.object(self.client.session, "post", requests.Session.post.__get__(self.client.session)),
              patch.object(self.client.session, "send", return_value=response) as send,
              patch.dict(m.os.environ, {"REQUESTS_CA_BUNDLE": "/fictional/environment-ca.pem"})):
            self.client.discover()
        self.assertEqual(send.call_args.kwargs["verify"], "/fictional/explicit-ca.pem")

    def test_insecure_overrides_ca_environment(self):
        client = m.AXLClient("cucm.example", "fictional", "fictional", verify=False)
        self.addCleanup(client.close)
        with (patch.object(client.session, "send", return_value=discovery("15.0", "15.0.1")) as send,
              patch.dict(m.os.environ, {"REQUESTS_CA_BUNDLE": "/fictional/environment-ca.pem"})):
            client.discover()
        self.assertIs(send.call_args.kwargs["verify"], False)
        self.assertFalse(send.call_args.kwargs["allow_redirects"])


    def test_insecure_warning_is_scoped_to_explicit_opt_out(self):
        def response(*args, **kwargs):
            m.warnings.warn("unverified", m.InsecureRequestWarning)
            m.warnings.warn("other", UserWarning)
            return discovery("15.0", "15.0.1")

        self.post.side_effect = response
        for verify in (False, True):
            self.client.session.verify = verify
            with m.warnings.catch_warnings(record=True) as seen:
                m.warnings.simplefilter("always")
                self.client.discover()
                m.warnings.warn("outside", m.InsecureRequestWarning)
            expected = ["unverified"] if verify else []
            self.assertEqual([str(w.message) for w in seen], expected + ["other", "outside"])

    def test_second_599_is_terminal(self):
        self.post.side_effect = [mismatch(), mismatch("15.x")]
        with self.assertRaises(m.AXLException):
            self.client.discover()
        self.assertEqual(self.post.call_count, 2)

    def test_success_requires_exact_soap_and_one_recognized_version(self):
        for response in (
            Mock(status_code=200, content=b"PRIVATE_SERVER_TEXT"),
            discovery("14.0", "15.0.1"), discovery("15.0", "14.0.1"),
            discovery("15.0", "16.0.1"), discovery("15.0", "15.1 PRIVATE_SERVER_TEXT"),
            soap("15.0", "getCCMVersion", "<version>15.0.1</version><version>15.0.2</version>"),
        ):
            with self.subTest(content=response.content):
                self.post.reset_mock()
                self.post.return_value = response
                with self.assertRaises(m.AXLException) as raised:
                    self.client.discover()
                self.assertNotIn("PRIVATE_SERVER_TEXT", str(raised.exception))
                self.post.assert_called_once()

    def test_tls_and_timeout_are_terminal_and_redacted(self):
        for exc, diagnostic in (
            (requests.exceptions.SSLError("PRIVATE_SERVER_TEXT"), "TLS"),
            (requests.exceptions.Timeout("PRIVATE_SERVER_TEXT"), "Timeout"),
        ):
            with self.subTest(diagnostic=diagnostic):
                self.post.reset_mock()
                self.post.side_effect = exc
                with self.assertRaisesRegex(m.AXLException, diagnostic) as raised:
                    self.client.discover()
                self.assertNotIn("PRIVATE_SERVER_TEXT", str(raised.exception))
                self.post.assert_called_once()

    def test_normal_operations_never_renegotiate(self):
        self.post.side_effect = [discovery("15.0", "15.0.1"), mismatch()]
        self.client.discover()
        with self.assertRaisesRegex(m.AXLException, "updateLine: HTTP 599"):
            self.client.update(UID)
        self.assertEqual(self.post.call_count, 2)
        self.assert_request(self.post.call_args, "15.0", "updateLine")


class CliTests(unittest.TestCase):
    def test_insecure_cli_retains_14_apply_gate(self):
        status, records, operations = self.invoke(
            [mismatch(), discovery("14.0", "14.0.1")], apply=True, insecure=True)
        self.assertEqual(status, 2)
        self.assertEqual(len(operations), 2)
        self.assertFalse(any(r["event"] == "WRITE_INTENT" for r in records))


    def invoke(self, responses, *, apply=False, insecure=False):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source = folder / "targets.csv"
            journal = folder / "report.jsonl"
            source.write_text("Device,Extension,Partition\nSEP020000000001,001234,\n", encoding="utf-8")
            args = [str(source), "--publisher", "cucm.example", "--username", "fictional",
                    "--report", str(journal)]
            if insecure:
                args += ["--insecure"]
            if apply:
                args += ["--apply", "--delay", "0"]
            output = io.StringIO()
            with (patch.object(m.requests.Session, "post", side_effect=responses) as post,
                  patch.dict(m.os.environ, {"CUCM_AXL_PASSWORD": "PRIVATE_PASSWORD"}),
                  contextlib.redirect_stdout(output), contextlib.redirect_stderr(output)):
                status = m.main(args)
            if insecure:
                self.assertIn("Server identity is not verified", output.getvalue())
                self.assertTrue(post.call_args_list)
                self.assertTrue(all(c.kwargs.get("verify") is False for c in post.call_args_list))
            records = [json.loads(line) for line in journal.read_text(encoding="utf-8").splitlines()]
            operations = [c.kwargs["headers"]["SOAPAction"] for c in post.call_args_list]
            self.assertNotIn("PRIVATE_PASSWORD", output.getvalue() + str(records))
            return status, records, operations

    def test_apply_stops_at_connection_on_14_or_auth_failure(self):
        for responses, number in (
            ([mismatch(), discovery("14.0", "14.0.1")], 2),
            ([Mock(status_code=401)], 1),
        ):
            with self.subTest(probes=number):
                status, records, operations = self.invoke(responses, apply=True)
                self.assertEqual(status, 2)
                self.assertEqual(len(operations), number)
                self.assertTrue(all("getCCMVersion" in op for op in operations))
                self.assertEqual(records[0]["event"], "START")
                self.assertEqual(records[-1]["event"], "STOPPED")
                self.assertEqual(records[-1]["stage"], "CONNECTION")
                self.assertEqual([r["event"] for r in records],
                                 ["START", "DISCOVERY", "STOPPED"] if number == 2 else ["START", "STOPPED"])

    def test_14_cli_preview_reports_schema_and_preserves_safety_reads(self):
        schema = "14.0"
        status, records, operations = self.invoke([
            mismatch(), discovery(schema, "14.0.1"),
            soap(schema, "getPhone", "<phone><name>SEP020000000001</name><lines><line><index>1</index>"
                 "<dirn><pattern>001234</pattern><routePartitionName/></dirn></line></lines></phone>"),
            soap(schema, "getLine", f'<line uuid="{UID}"><pattern>001234</pattern>'
                 "<routePartitionName/><autoAnswer>Auto Answer Off</autoAnswer></line>"),
            soap(schema, "executeSQLQuery", "<row><device>SEP020000000001</device><lineindex>1</lineindex></row>"),
        ])
        self.assertEqual(status, 0)
        self.assertEqual([r["event"] for r in records], ["START", "DISCOVERY", "READY", "DRY_RUN_COMPLETE"])
        self.assertEqual(records[0]["axl_version"], "15.0")
        self.assertEqual(records[1]["accepted_axl_version"], schema)
        self.assertEqual(records[2]["before"]["dn_uuid"], UID)
        self.assertEqual(operations[2:], [
            f'"CUCM:DB ver={schema} {op}"' for op in ("getPhone", "getLine", "executeSQLQuery")
        ])


if __name__ == "__main__":
    unittest.main()
