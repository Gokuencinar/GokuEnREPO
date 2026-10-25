"""Add Better Settings packages to the repository index without touching other entries."""
from __future__ import annotations

import gzip
import hashlib
import io
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE_DIR = ROOT / "tweaks" / "BetterSettings" / "debs"
DESCRIPTION = "A convenient way to organize your tweaks, just like Shuffle did on earlier versions of iOS."
ICON = "https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/tweaks/BetterSettings/assets/icon.png"
DEPICTION = "https://gokuencinar.github.io/GokuEnREPO/tweaks/BetterSettings/depiction.html"


def ar_members(data: bytes) -> dict[str, bytes]:
    assert data.startswith(b"!<arch>\n"), "Invalid Debian ar archive"
    offset = 8
    result: dict[str, bytes] = {}
    while offset < len(data):
        header = data[offset : offset + 60]
        assert len(header) == 60 and header[-2:] == b"`\n", "Malformed archive member"
        name = header[:16].decode("ascii").strip().rstrip("/")
        length = int(header[48:58])
        offset += 60
        result[name] = data[offset : offset + length]
        offset += length + length % 2
    return result


def control_fields(package: Path) -> list[str]:
    blob = package.read_bytes()
    members = ar_members(blob)
    control_name = next(name for name in members if name.startswith("control.tar"))
    with tarfile.open(fileobj=io.BytesIO(members[control_name]), mode="r:*") as archive:
        control = next(item for item in archive if item.name.lstrip("./") == "control")
        raw = archive.extractfile(control).read().decode("utf-8").strip()
    fields = [line for line in raw.splitlines() if line.strip()]
    if package.name.startswith("com.gokuencinar.bettersettings_"):
        fields = [line for line in fields if not line.startswith("Description:")]
        fields.append("Description: " + DESCRIPTION)
        fields.append("Icon: " + ICON)
        fields.append("Depiction: " + DEPICTION)
    elif package.name.startswith("preferenceloader_"):
        fields = [line for line in fields if not line.startswith("Description:")]
    fields += [
        "Filename: " + package.relative_to(ROOT).as_posix(),
        "Size: " + str(len(blob)),
        "MD5sum: " + hashlib.md5(blob).hexdigest(),
        "SHA256: " + hashlib.sha256(blob).hexdigest(),
    ]
    return fields


index_path = ROOT / "Packages"
raw = index_path.read_text(encoding="utf-8").strip()
stanzas = [] if not raw else raw.split("\n\n")
stanzas = [
    stanza
    for stanza in stanzas
    if not any(line.startswith("Package: " + name) for name in
               ("com.gokuencinar.bettersettings", "com.gokuencinar.cossettings18", "preferenceloader")
               for line in stanza.splitlines())
]
stanzas += ["\n".join(control_fields(package)) for package in sorted(PACKAGE_DIR.glob("*.deb"))]
result = "\n\n".join(stanzas) + "\n"
index_path.write_text(result, encoding="utf-8", newline="\n")
with (ROOT / "Packages.gz").open("wb") as stream:
    with gzip.GzipFile(filename="", mode="wb", compresslevel=9, mtime=0, fileobj=stream) as gz:
        gz.write(result.encode("utf-8"))
print("Updated Packages / Packages.gz with", len(list(PACKAGE_DIR.glob("*.deb"))), "Better Settings packages")
