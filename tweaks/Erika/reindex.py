"""Add Erika Reborn 2.0.1's audited .deb metadata to GokuEnREPO's APT index.

Run from any directory with Python 3. This preserves all unrelated Packages
stanzas and regenerates Packages.gz with reproducible gzip metadata.
"""

from __future__ import annotations

import gzip
import hashlib
import io
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PKG = "emt.paisseon.erika"
VERSION = "2.0.1"
ARCHES = ("iphoneos-arm64e", "iphoneos-arm64")
DEPICTION = "https://gokuencinar.github.io/GokuEnREPO/tweaks/Erika/depiction.html"


def control_from_deb(deb: Path) -> str:
    content = deb.read_bytes()
    if not content.startswith(b"!<arch>\n"):
        raise ValueError(f"Not a Debian ar package: {deb.name}")
    pos = 8
    while pos + 60 <= len(content):
        header = content[pos : pos + 60]
        if header[58:60] != b"`\n":
            raise ValueError(f"Invalid ar member header in {deb.name}")
        member = header[:16].decode("ascii").strip().rstrip("/")
        length = int(header[48:58].decode("ascii").strip())
        blob = content[pos + 60 : pos + 60 + length]
        if len(blob) != length:
            raise ValueError(f"Incomplete ar member in {deb.name}")
        if member.startswith("control.tar"):
            if member.endswith(".zst"):
                # RootHidePatcher emits zstd-compressed Debian control archives.
                # Windows' built-in bsdtar and modern libarchive support this.
                with tempfile.TemporaryDirectory() as temp_dir:
                    archive = Path(temp_dir) / member
                    archive.write_bytes(blob)
                    result = subprocess.run(
                        ["tar", "-xOf", str(archive), "./control"],
                        check=True,
                        capture_output=True,
                    )
                    return result.stdout.decode("utf-8")
            with tarfile.open(fileobj=io.BytesIO(blob), mode="r:*") as bundle:
                for item in bundle.getmembers():
                    if item.name.lstrip("./") == "control":
                        fh = bundle.extractfile(item)
                        if fh is None:
                            break
                        return fh.read().decode("utf-8")
        pos += 60 + length + (length % 2)
    raise ValueError(f"Package control metadata missing in {deb.name}")


def field_value(control: str, name: str) -> str:
    match = re.search(rf"(?m)^{re.escape(name)}: (.+)$", control)
    if match is None:
        raise ValueError(f"Missing control field {name}")
    return match.group(1).rstrip("\r")


def create_entry(arch: str) -> str:
    relative = f"tweaks/Erika/debs/{PKG}_{VERSION}_{arch}.deb"
    deb = ROOT / relative
    if not deb.is_file():
        raise FileNotFoundError(deb)
    control = control_from_deb(deb).strip()
    for field, expected in (("Package", PKG), ("Version", VERSION), ("Architecture", arch), ("Name", "Erika Reborn")):
        got = field_value(control, field)
        if got != expected:
            raise ValueError(f"{deb.name}: {field}: {got!r} != {expected!r}")
    if "iOS 18," in field_value(control, "Description"):
        raise ValueError("Description unexpectedly tied to iOS 18")
    data = deb.read_bytes()
    fields = [
        control,
        "Priority: optional",
        f"Filename: {relative}",
        f"Size: {len(data)}",
        f"MD5sum: {hashlib.md5(data).hexdigest()}",
        f"SHA1: {hashlib.sha1(data).hexdigest()}",
        f"SHA256: {hashlib.sha256(data).hexdigest()}",
        f"Depiction: {DEPICTION}",
    ]
    return "\n".join(fields)


def main() -> None:
    package_entries = [create_entry(arch) for arch in ARCHES]
    index = ROOT / "Packages"
    current = index.read_bytes().decode("utf-8")
    blocks = re.split(r"\r?\n\r?\n", current.strip())
    preserved = []
    removed = 0
    for block in blocks:
        if block.startswith(f"Package: {PKG}\n") or block.startswith(f"Package: {PKG}\r\n"):
            removed += 1
        elif block.strip():
            preserved.append(block.replace("\r\n", "\n"))
    output = ("\n\n".join(preserved + package_entries) + "\n").encode("utf-8")
    index.write_bytes(output)
    (ROOT / "Packages.gz").write_bytes(gzip.compress(output, compresslevel=9, mtime=0))
    assert gzip.decompress((ROOT / "Packages.gz").read_bytes()) == output
    assert output.count(f"Package: {PKG}\n".encode()) == len(ARCHES)
    print(f"Reindexed Erika Reborn {VERSION} ({', '.join(ARCHES)})")
    print(f"Preserved {len(preserved)} other stanzas; replaced {removed}; total {len(preserved)+len(ARCHES)}")


if __name__ == "__main__":
    main()
