#!/usr/bin/env python3
"""Build a recovery BandLock DEB without reusing Linux-built injected binaries.

rhui18's Analyzer/daemon changes are kept, but components that can be loaded by
SpringBoard/Phone are copied byte-for-byte from the known-good rhui17 package.
The script refuses unknown input artifacts and validates the final provenance.
"""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import io
import json
import lzma
from pathlib import Path
import re
import tarfile


ROOT = Path(__file__).resolve().parent.parent

STABLE_SHA256 = "20f13d1060cf874cc17ddc5c00a519d8425e356f68b3779252943fd36990261d"
CANDIDATE_SHA256 = "6b3f0301609efbbf888f29537371bf8f5816cfc507570b28c5c4d3ece0c0b58f"
OUTPUT_VERSION = "1.6.0~rhui19"

STABLE_DEFAULT = ROOT / "rhui17-extracted" / "com.gokuencinar.bandlock_1.6.0~rhui17_iphoneos-arm64e.deb"
CANDIDATE_DEFAULT = ROOT / "rhui18-extracted" / "com.gokuencinar.bandlock_1.6.0~rhui18_iphoneos-arm64e.deb"
OUTPUT_DEFAULT = ROOT / "rhui19-safe-hybrid" / "com.gokuencinar.bandlock_1.6.0~rhui19_iphoneos-arm64e.deb"

CC_PREFIX = "Library/ControlCenter/Bundles/BandLockCCModule.bundle/"
SAFE_FROM_RHUI17 = {
    "Library/MobileSubstrate/DynamicLibraries/BandLockFieldBridge.dylib",
    "Library/MobileSubstrate/DynamicLibraries/BandLockFieldBridge.plist",
    "usr/bin/BandLockLauncher",
}

EXPECTED_FINAL_HASHES = {
    # Known-good native components copied from rhui17.
    "Library/ControlCenter/Bundles/BandLockCCModule.bundle/BandLockCCModule":
        "6b7d255c2cfb458a0f733dd9a2356422fc8c64b46c78a10917e76e368915fb26",
    "Library/MobileSubstrate/DynamicLibraries/BandLockFieldBridge.dylib":
        "55617f895ac7a4e357f3c98f2327a2e00e4dda2f5dd28d8e4da04de60d8ae781",
    "usr/bin/BandLockLauncher":
        "cb055af8d6da4ae0d63597d48c4e3ecba3cfbdf42285e60a6f780238ee829264",
    # rhui18 payload that contains the requested Analyzer/daemon work.
    "Applications/BandLock.app/BandLock":
        "3f90d3bad722811c013b7b705d6c690eab6b9accd0871adc0649bf1d3f51fa35",
    "usr/libexec/BandLockDaemon":
        "dd18d082e84a8843d7dfac25c1252124da28dd06e1c34e57c9af79340b08634c",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_ar(path: Path) -> dict[str, bytes]:
    blob = path.read_bytes()
    if not blob.startswith(b"!<arch>\n"):
        raise RuntimeError(f"Not a Debian/ar archive: {path}")
    result: dict[str, bytes] = {}
    pos = 8
    while pos + 60 <= len(blob):
        header = blob[pos:pos + 60]
        if header[58:60] != b"`\n":
            raise RuntimeError(f"Invalid ar member header at {pos}: {path}")
        name = header[:16].decode("ascii").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        start = pos + 60
        result[name] = blob[start:start + size]
        pos = start + size + (size & 1)
    return result


def write_ar(path: Path, members: list[tuple[str, bytes]]) -> None:
    out = bytearray(b"!<arch>\n")
    for name, data in members:
        if len(name) > 15:
            raise RuntimeError(f"ar member name too long: {name}")
        header = (
            f"{(name + '/'):16}"
            f"{0:<12}"
            f"{0:<6}"
            f"{0:<6}"
            f"{'100644':<8}"
            f"{len(data):<10}"
            "`\n"
        ).encode("ascii")
        if len(header) != 60:
            raise AssertionError("ar header must be exactly 60 bytes")
        out.extend(header)
        out.extend(data)
        if len(data) & 1:
            out.extend(b"\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


def unpack_tar(raw: bytes) -> list[tuple[tarfile.TarInfo, bytes | None]]:
    entries: list[tuple[tarfile.TarInfo, bytes | None]] = []
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tf:
        for info in tf.getmembers():
            data = tf.extractfile(info).read() if info.isfile() else None
            entries.append((copy.copy(info), data))
    return entries


def pack_tar(entries: list[tuple[tarfile.TarInfo, bytes | None]]) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.GNU_FORMAT) as tf:
        for info, data in entries:
            info = copy.copy(info)
            if info.isfile():
                if data is None:
                    raise RuntimeError(f"Missing data for {info.name}")
                info.size = len(data)
                tf.addfile(info, io.BytesIO(data))
            else:
                tf.addfile(info)
    return buf.getvalue()


def tar_map(entries: list[tuple[tarfile.TarInfo, bytes | None]]) -> dict[str, tuple[tarfile.TarInfo, bytes | None]]:
    return {info.name.lstrip("./"): (info, data) for info, data in entries}


def data_entries(deb_members: dict[str, bytes]) -> list[tuple[tarfile.TarInfo, bytes | None]]:
    if "data.tar.lzma" not in deb_members:
        raise RuntimeError("Expected data.tar.lzma")
    return unpack_tar(lzma.decompress(deb_members["data.tar.lzma"]))


def control_entries(deb_members: dict[str, bytes]) -> list[tuple[tarfile.TarInfo, bytes | None]]:
    if "control.tar.gz" not in deb_members:
        raise RuntimeError("Expected control.tar.gz")
    return unpack_tar(gzip.decompress(deb_members["control.tar.gz"]))


def replace_control_version(entries: list[tuple[tarfile.TarInfo, bytes | None]]) -> None:
    for index, (info, data) in enumerate(entries):
        if info.name.lstrip("./") != "control" or data is None:
            continue
        text = data.decode("utf-8")
        updated, count = re.subn(r"^Version: .+$", f"Version: {OUTPUT_VERSION}", text, count=1, flags=re.MULTILINE)
        if count != 1:
            raise RuntimeError("Could not update package Version field")
        entries[index] = (info, updated.encode("utf-8"))
        return
    raise RuntimeError("control file missing from control.tar.gz")


def gzip_deterministic(raw: bytes) -> bytes:
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9, mtime=0) as gz:
        gz.write(raw)
    return buf.getvalue()


def should_restore_from_rhui17(name: str) -> bool:
    canonical = name.lstrip("./")
    return canonical.startswith(CC_PREFIX) or canonical in SAFE_FROM_RHUI17


def build(stable: Path, candidate: Path, output: Path) -> dict[str, object]:
    stable_sha = sha256_file(stable)
    candidate_sha = sha256_file(candidate)
    if stable_sha != STABLE_SHA256:
        raise RuntimeError(f"Unexpected rhui17 SHA256: {stable_sha}")
    if candidate_sha != CANDIDATE_SHA256:
        raise RuntimeError(f"Unexpected rhui18 SHA256: {candidate_sha}")

    stable_ar = read_ar(stable)
    candidate_ar = read_ar(candidate)
    stable_data_entries = data_entries(stable_ar)
    candidate_data_entries = data_entries(candidate_ar)
    stable_data = tar_map(stable_data_entries)

    replaced: list[str] = []
    final_entries: list[tuple[tarfile.TarInfo, bytes | None]] = []
    for info, data in candidate_data_entries:
        canonical = info.name.lstrip("./")
        if should_restore_from_rhui17(canonical):
            stable_entry = stable_data.get(canonical)
            if stable_entry is None:
                raise RuntimeError(f"rhui17 safe component missing: {canonical}")
            stable_info, stable_bytes = stable_entry
            final_entries.append((copy.copy(stable_info), stable_bytes))
            replaced.append(canonical)
        else:
            final_entries.append((info, data))

    control = control_entries(candidate_ar)
    replace_control_version(control)

    control_raw = pack_tar(control)
    data_raw = pack_tar(final_entries)
    control_gz = gzip_deterministic(control_raw)
    data_lzma = lzma.compress(data_raw, format=lzma.FORMAT_ALONE, preset=9)
    write_ar(output, [
        ("debian-binary", b"2.0\n"),
        ("control.tar.gz", control_gz),
        ("data.tar.lzma", data_lzma),
    ])

    result_ar = read_ar(output)
    result_control = tar_map(control_entries(result_ar))
    result_data = tar_map(data_entries(result_ar))
    control_text = result_control["control"][1].decode("utf-8")
    if f"Version: {OUTPUT_VERSION}" not in control_text:
        raise RuntimeError("Output control version validation failed")
    if "Architecture: iphoneos-arm64e" not in control_text:
        raise RuntimeError("Output architecture validation failed")

    critical: dict[str, str] = {}
    for name, expected in EXPECTED_FINAL_HASHES.items():
        entry = result_data.get(name)
        if entry is None or entry[1] is None:
            raise RuntimeError(f"Critical output file missing: {name}")
        digest = sha256_bytes(entry[1])
        critical[name] = digest
        if digest != expected:
            raise RuntimeError(f"Critical hash mismatch for {name}: {digest}")

    final_sha = sha256_file(output)
    manifest = {
        "package": "com.gokuencinar.bandlock",
        "version": OUTPUT_VERSION,
        "architecture": "iphoneos-arm64e",
        "stable_input": {"path": str(stable), "sha256": stable_sha},
        "candidate_input": {"path": str(candidate), "sha256": candidate_sha},
        "output": {"path": str(output), "sha256": final_sha, "bytes": output.stat().st_size},
        "restored_from_rhui17": sorted(replaced),
        "critical_hashes": critical,
    }
    manifest_path = output.with_suffix(output.suffix + ".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stable", type=Path, default=STABLE_DEFAULT)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE_DEFAULT)
    parser.add_argument("--output", type=Path, default=OUTPUT_DEFAULT)
    args = parser.parse_args()
    manifest = build(args.stable, args.candidate, args.output)
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
