#!/usr/bin/env python3
"""Verify declared download packages in the source tree and built site."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import zipfile

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "scripts/download-release-manifest.json"
DOWNLOADS = Path("assets/downloads")
CHECKSUMS = "SHA256SUMS.txt"
MAX_BYTES = 8 * 1024 * 1024
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")
DIGEST = re.compile(r"[0-9a-f]{64}")
VERSION = re.compile(r"[0-9]+(?:\.[0-9]+)+")


def checked_names(names):
    if any(not isinstance(name, str) or not NAME.fullmatch(name) for name in names):
        raise ValueError("unsafe manifest name")
    if len({name.casefold() for name in names}) != len(names):
        raise ValueError("duplicate or case-colliding manifest names")


def checked_paths(names):
    """Allow package subdirectories without accepting traversal or aliases."""
    for name in names:
        if not isinstance(name, str):
            raise ValueError("unsafe manifest name")
        for part in name.split("/"):
            checked_names([part])
    folded = [name.casefold() for name in names]
    if len(set(folded)) != len(folded):
        raise ValueError("duplicate or case-colliding manifest names")
    prefixes = {}
    for name in names:
        parts = name.split("/")
        for end in range(1, len(parts) + 1):
            prefix = "/".join(parts[:end])
            if prefixes.setdefault(prefix.casefold(), prefix) != prefix:
                raise ValueError("case-colliding package directories")
            if end < len(parts) and prefix.casefold() in folded:
                raise ValueError("package file/directory collision")


def package_entries(directory):
    """Include unexpected directories and symlinks without following them."""
    if not directory.is_dir():
        return set()
    return {child.relative_to(directory).as_posix() for child in directory.rglob("*")}


def expected_entries(names):
    return {str(parent) for name in names for parent in [Path(name), *Path(name).parents]
            if str(parent) != "."}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def path_at(root, relative):
    target = root
    for part in relative.parts:
        target = target / part
        if target.is_symlink():
            raise ValueError(f"symlink refused: {relative}")
    return target


def contents(path):
    meta = path.stat()
    if not stat.S_ISREG(meta.st_mode) or meta.st_size > MAX_BYTES:
        raise ValueError(f"not a small regular file: {path.name}")
    with path.open("rb") as handle:
        data = handle.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError(f"file exceeds limit: {path.name}")
    return data


def archive_spec(spec, mirrors):
    if set(spec) == {"folder", "filename"}:
        checked_names([spec["folder"], spec["filename"]])
        if not spec["filename"].endswith(".zip"):
            raise ValueError("archive filename must end in .zip")
        return spec["folder"], spec["filename"]
    if set(spec) != {"stem", "version"}:
        raise ValueError("invalid archive keys")
    checked_names([spec["stem"]])
    version = spec["version"]
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise ValueError("invalid archive version")
    if sum(name.endswith(f"-v{version}.ps1") for name in mirrors) != 1:
        raise ValueError("expected one PowerShell script named for archive version")
    folder = f'{spec["stem"]}-v{version}'
    return folder, f"{folder}-testing.zip"


def check_archive(path, folder, canonical, errors):
    expected = {f"{folder}/{name}": data for name, data in canonical.items()}
    metadata = path.stat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > MAX_BYTES:
        raise ValueError(f"not a small regular archive: {path.name}")
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) != len(expected) or {entry.orig_filename for entry in entries} != expected.keys():
            errors.append("ZIP membership mismatch (missing, extra or duplicate member)")
            return
        for entry in entries:
            want = expected[entry.filename]
            file_type = stat.S_IFMT(entry.external_attr >> 16)
            if file_type not in {0, stat.S_IFREG} or entry.file_size != len(want):
                errors.append(f"invalid ZIP member type or size: {entry.filename}")
            elif archive.read(entry) != want:
                errors.append(f"ZIP member differs from canonical: {entry.filename}")


def check_package(root, package, spec, *, draft_location=None, built=False):
    if set(spec) - {"state", "mirrors", "public_only", "archive"}:
        raise ValueError("unknown package keys")
    state, mirrors = spec["state"], spec["mirrors"]
    public_only = spec.get("public_only", {})
    if state not in {"released", "draft"}:
        raise ValueError("state must be released or draft")
    if not isinstance(mirrors, list) or not mirrors or not isinstance(public_only, dict):
        raise ValueError("invalid mirrors or public_only")
    if any(not isinstance(pin, str) or not DIGEST.fullmatch(pin) for pin in public_only.values()):
        raise ValueError("invalid public-only digest")
    checked_paths(mirrors)
    folder, zip_name = archive_spec(spec["archive"], mirrors) if "archive" in spec else (None, None)
    expected = mirrors + list(public_only) + ([CHECKSUMS, zip_name] if folder else [])
    checked_paths(expected)
    public_rel = Path("public") / DOWNLOADS / package
    built_rel = Path("dist") / DOWNLOADS / package
    errors = []
    if state == "draft" and draft_location is None:
        for relative in (public_rel, built_rel) if built else (public_rel,):
            if path_at(root, relative).exists():
                errors.append(f"draft packaging present at {relative.as_posix()}")
        return errors

    if draft_location == "release-staging":
        public_rel = Path(draft_location) / DOWNLOADS / package
    for name in expected:
        relative = public_rel / name
        try:
            output_bytes = contents(path_at(root, relative))
            if name in mirrors or (folder and name == CHECKSUMS):
                if output_bytes != contents(path_at(root, Path("scripts") / package / name)):
                    errors.append(f"{name}: output bytes differ from canonical")
            elif name in public_only and digest(output_bytes) != public_only[name]:
                errors.append(f"{name}: public-only SHA-256 pin mismatch")
            if built and output_bytes != contents(path_at(root, built_rel / name)):
                errors.append(f"{name}: built bytes differ from public")
        except FileNotFoundError as exc:
            errors.append(f"missing: {Path(exc.filename).relative_to(root)}")

    directory = path_at(root, public_rel)
    if directory.is_dir():
        extras = sorted(package_entries(directory) - expected_entries(expected))
        if extras:
            errors.append(f"unexpected public entries: {', '.join(extras)}")
    if built and path_at(root, built_rel).is_dir():
        extras = sorted(package_entries(path_at(root, built_rel)) - expected_entries(expected))
        if extras:
            errors.append(f"unexpected built entries: {', '.join(extras)}")

    if folder and not errors:
        canonical = {name: contents(path_at(root, Path("scripts") / package / name))
                     for name in mirrors + [CHECKSUMS]}
        lines = canonical[CHECKSUMS].decode("ascii").splitlines()
        expected_lines = {f"{digest(canonical[name])}  {name}" for name in mirrors}
        if len(lines) != len(expected_lines) or set(lines) != expected_lines:
            errors.append("SHA256SUMS.txt does not list each canonical payload exactly once")
        check_archive(path_at(root, public_rel / zip_name), folder, canonical, errors)
    return errors


def verify(root, manifest, *, audit_draft=None, draft_location="public", built=False):
    root = root.resolve(strict=True)
    downloads = (Path.home() / "Downloads").resolve()
    if root.is_relative_to(downloads):
        raise ValueError("Downloads is not an allowed repository root")
    if set(manifest) != {"schema", "packages"} or manifest["schema"] != 1:
        raise ValueError("unsupported manifest")
    packages = manifest["packages"]
    if not isinstance(packages, dict) or not packages:
        raise ValueError("expected nonempty package mapping")
    checked_names(list(packages))
    if audit_draft is not None:
        if draft_location not in {"public", "release-staging"} or built:
            raise ValueError("invalid draft diagnostic scope")
        config = packages.get(audit_draft)
        if not isinstance(config, dict) or config.get("state") != "draft":
            raise ValueError("draft audit requires an explicitly declared draft package")
        packages = {audit_draft: packages[audit_draft]}
    results = {}
    for package, spec in packages.items():
        try:
            location = draft_location if audit_draft is not None else None
            results[package] = check_package(root, package, spec, draft_location=location, built=built)
        except (KeyError, OSError, ValueError, TypeError, RuntimeError, zipfile.BadZipFile) as exc:
            results[package] = [str(exc)]
    return results


def unique_object(pairs):
    obj = dict(pairs)
    if len(obj) != len(pairs):
        raise ValueError("duplicate manifest key")
    return obj


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT,
                        help="checkout to inspect (defaults to this script's checkout)")
    parser.add_argument("--check-built", action="store_true", help="also verify existing dist tree")
    draft = parser.add_mutually_exclusive_group()
    draft.add_argument("--audit-public-draft", metavar="PACKAGE",
                        help="diagnose an existing draft in public; never a release check")
    draft.add_argument("--audit-staged-draft", metavar="PACKAGE",
                       help="audit a draft under release-staging, outside the public tree")
    args = parser.parse_args()
    audit = args.audit_public_draft or args.audit_staged_draft
    if audit and args.check_built:
        parser.error("draft diagnostics cannot qualify a build")
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
        location = "release-staging" if args.audit_staged_draft else "public"
        results = verify(args.root, manifest, audit_draft=audit, draft_location=location, built=args.check_built)
    except (OSError, ValueError, TypeError) as exc:
        parser.exit(2, f"Invalid check inputs: {exc}\n")
    if audit:
        print("DRAFT DIAGNOSTICS ONLY — no release approval")
    for package, errors in results.items():
        if errors:
            for error in errors:
                print(f"FAIL {package}: {error}")
        else:
            state = manifest["packages"][package]["state"]
            draft_excluded = state == "draft" and not audit
            verdict = "draft absent from checked release paths" if draft_excluded else "package parity"
            print(f"PASS {package}: {verdict}")
    return int(any(results.values()))


if __name__ == "__main__":
    raise SystemExit(main())
