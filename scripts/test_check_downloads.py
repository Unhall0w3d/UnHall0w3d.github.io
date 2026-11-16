"""Synthetic fixture tests; no operational scripts are executed."""
import copy
from pathlib import Path
import stat
import tempfile
import unittest
import warnings
import zipfile

if __package__:
    from .check_downloads import digest, unique_object, verify
else:
    from check_downloads import digest, unique_object, verify


class DownloadCheckTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.payload = b"fictional DRS\n"
        self.script = "demo-v1.6.ps1"
        self.sums = f"{digest(self.payload)}  {self.script}\n".encode()
        self.archive = "Demo-v1.6-testing.zip"
        self.member = f"Demo-v1.6/{self.script}"
        self.members = [(self.member, self.payload), ("Demo-v1.6/SHA256SUMS.txt", self.sums)]
        self.manifest = {"schema": 1, "packages": {
            "published": {"state": "released", "mirrors": ["main.py"],
                          "public_only": {"sample.csv": digest(b"x\n")}},
            "candidate": {"state": "draft", "mirrors": [self.script],
                          "archive": {"stem": "Demo", "version": "1.6"}}
        }}
        self.write("scripts/published/main.py", b"source")
        self.write("public/assets/downloads/published/main.py", b"source")
        self.write("public/assets/downloads/published/sample.csv", b"x\n")

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def fixture_archive(self, members=None):
        with warnings.catch_warnings(), zipfile.ZipFile(
            self.root / "public/assets/downloads/candidate" / self.archive, "w"
        ) as archive:
            warnings.simplefilter("ignore", UserWarning)  # deliberate duplicate fixture
            for name, data in self.members if members is None else members:
                archive.writestr(name, data)

    def stage_candidate(self):
        for base in ("scripts", "public/assets/downloads"):
            self.write(f"{base}/candidate/{self.script}", self.payload)
            self.write(f"{base}/candidate/SHA256SUMS.txt", self.sums)
        self.fixture_archive()

    def check(self, **kwargs):
        return verify(self.root, self.manifest, **kwargs)

    def test_released_parity_and_draft_absence(self):
        self.assertEqual({"published": [], "candidate": []}, self.check())

    def test_missing_and_changed_mirrors(self):
        self.write("scripts/published/main.py", b"changed")
        self.assertIn("output bytes differ from canonical", self.check()["published"][0])
        (self.root / "public/assets/downloads/published/main.py").unlink()
        self.assertIn("missing:", self.check()["published"][0])

    def test_extra_and_changed_public_only(self):
        self.write("public/assets/downloads/published/sample.csv", b"y\n")
        self.write("public/assets/downloads/published/unlisted.csv", b"omit")
        self.assertIn("pin mismatch", self.check()["published"][0])
        self.assertIn("unlisted.csv", self.check()["published"][1])

    def test_draft_public_block_and_separate_parity(self):
        self.stage_candidate()
        self.assertIn("draft packaging present", self.check()["candidate"][0])
        self.assertEqual({"candidate": []}, self.check(audit_draft="candidate"))

    def test_staged_draft_audit_does_not_block_release(self):
        self.stage_candidate()
        staging = self.root / "release-staging/assets/downloads"
        staging.mkdir(parents=True)
        (self.root / "public/assets/downloads/candidate").rename(staging / "candidate")
        self.assertEqual({"candidate": []}, self.check(
            audit_draft="candidate", draft_location="release-staging"))
        self.assertEqual({"published": [], "candidate": []}, self.check())

    def test_existing_build_checks_draft_and_released_bytes(self):
        self.write("dist/assets/downloads/published/main.py", b"source")
        self.write("dist/assets/downloads/published/sample.csv", b"x\n")
        self.assertEqual({"published": [], "candidate": []}, self.check(built=True))

        self.write("dist/assets/downloads/candidate/sneak.zip", b"x")
        self.write("dist/assets/downloads/published/main.py", b"stale")
        errors = self.check(built=True)
        self.assertIn("built bytes differ", errors["published"][0])
        self.assertIn("dist/assets/downloads/candidate", errors["candidate"][0])

    def test_zip_wrong_bytes_and_wrong_inventory(self):
        self.stage_candidate()
        with self.subTest("same size drift"):
            self.fixture_archive([(self.member, b"X" * len(self.payload)), self.members[1]])
            self.assertIn("ZIP member differs", self.check(audit_draft="candidate")["candidate"][0])
        for members in [self.members + [self.members[0]], self.members[:1],
                        self.members + [("../outside", b"avoid")]]:
            with self.subTest(members=[name for name, _ in members]):
                self.fixture_archive(members)
                self.assertIn("ZIP membership mismatch", self.check(audit_draft="candidate")["candidate"][0])
                self.assertFalse((self.root / "outside").exists())

    def test_zip_special_file_refused_even_with_expected_name_and_bytes(self):
        self.stage_candidate()
        for file_type in (stat.S_IFLNK, stat.S_IFIFO):
            with self.subTest(file_type=file_type):
                member = zipfile.ZipInfo(self.member)
                member.create_system = 3
                member.external_attr = (file_type | 0o700) << 16
                self.fixture_archive([(member, self.payload), self.members[1]])
                errors = self.check(audit_draft="candidate")["candidate"]
                self.assertIn("invalid ZIP member type or size", errors[0])

    def test_wrong_digest_even_when_checksum_copies_agree(self):
        self.stage_candidate()
        bad = b"0" * 64 + b"  " + self.script.encode() + b"\n"
        for base in ("scripts", "public/assets/downloads"):
            self.write(f"{base}/candidate/SHA256SUMS.txt", bad)
        self.fixture_archive([self.members[0], (self.members[1][0], bad)])
        self.assertIn("does not list each canonical payload", self.check(audit_draft="candidate")["candidate"][0])

    def test_version_and_path_escapes_rejected(self):
        changed = copy.deepcopy(self.manifest)
        changed["packages"]["candidate"]["archive"]["version"] = "1.7"
        self.assertIn("expected one PowerShell script", verify(self.root, changed)["candidate"][0])
        changed["packages"]["published"]["mirrors"] = ["../outside"]
        self.assertIn("unsafe manifest name", verify(self.root, changed)["published"][0])
        with self.assertRaisesRegex(ValueError, "duplicate manifest key"):
            unique_object([("schema", 1), ("schema", 2)])

    def test_symlink_refused(self):
        path = self.root / "public/assets/downloads/published/main.py"
        path.unlink()
        path.symlink_to(self.root / "scripts/published/main.py")
        self.assertIn("symlink refused", self.check()["published"][0])

    def stage_nested_package(self):
        self.manifest["packages"]["candidate"] = {
            "state": "released", "mirrors": ["agents/worker.toml"],
            "archive": {"folder": "Roles", "filename": "roles.zip"},
        }
        self.script = "agents/worker.toml"
        self.archive = "roles.zip"
        self.sums = f"{digest(self.payload)}  {self.script}\n".encode()
        self.members = [("Roles/" + self.script, self.payload), ("Roles/SHA256SUMS.txt", self.sums)]
        self.stage_candidate()

    def test_nested_generic_archive_and_built_parity(self):
        self.stage_nested_package()
        self.assertEqual(self.check()["candidate"], [])
        for path in (self.root / "public").rglob("*"):
            if path.is_file():
                self.write("dist/" + str(path.relative_to(self.root / "public")), path.read_bytes())
        self.assertEqual(self.check(built=True), {"published": [], "candidate": []})
        self.write("dist/assets/downloads/candidate/agents/worker.toml", b"drift")
        self.assertIn("built bytes differ", self.check(built=True)["candidate"][0])

    def test_nested_extra_files_and_empty_directories(self):
        self.stage_nested_package()
        self.write("public/assets/downloads/candidate/agents/private.txt", b"not for release")
        (self.root / "public/assets/downloads/candidate/unused").mkdir()
        errors = "\n".join(self.check()["candidate"])
        self.assertIn("agents/private.txt", errors)
        self.assertIn("unused", errors)

    def test_nested_paths_refuse_traversal_aliases_and_collisions(self):
        for paths in [["agents/../secret"], ["/absolute"], ["agents//x"],
                      ["agents/./x"], ["agents\\x"], ["agents/x", "Agents/y"],
                      ["agents", "agents/x"], ["agents/x", "agents/X"]]:
            with self.subTest(paths=paths):
                self.manifest["packages"]["published"]["mirrors"] = paths
                self.assertTrue(self.check()["published"])

    def test_nested_symlink_directory_refused(self):
        self.stage_nested_package()
        path = self.root / "public/assets/downloads/candidate/agents"
        (path / "worker.toml").unlink()
        path.rmdir()
        path.symlink_to(self.root / "scripts/candidate/agents", target_is_directory=True)
        self.assertIn("symlink refused", self.check()["candidate"][0])

    def test_generic_archive_name_and_contents_validated(self):
        self.stage_nested_package()
        self.fixture_archive(self.members + [("Roles/agents/extra.toml", b"extra")])
        self.assertIn("ZIP membership mismatch", self.check()["candidate"][0])
        self.manifest["packages"]["candidate"]["archive"]["filename"] = "roles.txt"
        self.assertIn("must end in .zip", self.check()["candidate"][0])


if __name__ == "__main__":
    unittest.main()
