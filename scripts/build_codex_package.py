#!/usr/bin/env python3
"""Build the dated Codex package from its reviewed canonical payloads.

Run explicitly after reviewing payload changes. Normal site builds validate
existing bytes rather than silently regenerating downloads.
"""
from pathlib import Path
import shutil
import stat
import zipfile

from check_downloads import contents, digest, path_at

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "codex-routing-2026-11-15"
PAYLOADS = ["AGENTS.md", "config.example.toml", "README.txt", "CHANGELOG.txt",
            *[f"agents/{role}.toml" for role in
              ("luna_focused", "luna_coding", "sol_implementation", "sol_review", "terra_visual")]]


def build():
    source = ROOT / "scripts" / PACKAGE
    output = ROOT / "public/assets/downloads" / PACKAGE
    payloads = {name: contents(path_at(ROOT, Path("scripts") / PACKAGE / name))
                for name in sorted(PAYLOADS)}
    payloads["SHA256SUMS.txt"] = "".join(
        f"{digest(data)}  {name}\n" for name, data in payloads.items()).encode("ascii")
    path_at(ROOT, Path("scripts") / PACKAGE / "SHA256SUMS.txt").write_bytes(payloads["SHA256SUMS.txt"])
    output.mkdir(parents=True, exist_ok=True)
    for name in payloads:
        target = path_at(ROOT, Path("public/assets/downloads") / PACKAGE / name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, target)
    archive_path = path_at(ROOT, Path("public/assets/downloads") / PACKAGE / f"{PACKAGE}.zip")
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(payloads.items()):
            entry = zipfile.ZipInfo(f"{PACKAGE}/{name}", (2026, 11, 15, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    print(f"Built {len(payloads)} ZIP members; SHA-256 {digest(archive_path.read_bytes())}")


if __name__ == "__main__":
    build()
