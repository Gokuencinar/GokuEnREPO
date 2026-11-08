#!/usr/bin/env python3
"""Replace only the three app-icon PNGs inside the existing 1.0 DEBs.

The current update does not change native code or packaging metadata. This
script preserves every unrelated tar header, file, control script and binary.
"""

import argparse
import hashlib
import io
import lzma
from pathlib import Path
import tarfile

RELEASE = Path(__file__).resolve().parents[1] / "tweaks" / "AppFirewall"
PACKAGE = "com.gokuencinar.appfirewall.poc_1.0_"
BASELINES = {
    "iphoneos-arm": "8c81381ec44cfbe7005749b9a5e82033c76b9f051a4ddb0edf83f756f1919f96",
    "iphoneos-arm64": "65f87ffd5c4faf0f5c180a91f7025490ef17ca98efb762be92fd88a9e431fba2",
    "iphoneos-arm64e": "be543cd51ba2dfa9588f98392d8f0e90bfdef70252027bb1ae38b2356798e29d",
}
ICONS = ("AppIcon60.png", "AppIcon60@2x.png", "AppIcon60@3x.png")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def decode_ar(blob):
    if not blob.startswith(b"!<arch>\n"):
        raise ValueError("Invalid Debian ar archive")
    parts = []
    at = 8
    while at < len(blob):
        header = blob[at:at + 60]
        if len(header) != 60 or header[-2:] != b"`\n":
            raise ValueError("Invalid ar header")
        count = int(header[48:58].strip())
        member = blob[at + 60:at + 60 + count]
        if len(member) != count:
            raise ValueError("Truncated ar payload")
        name = header[:16].strip().rstrip(b"/").decode("ascii")
        parts.append((name, header, member))
        at += 60 + count + (count % 2)
    return parts


def encode_ar(parts):
    result = bytearray(b"!<arch>\n")
    for _, old_header, payload in parts:
        header = bytearray(old_header)
        header[48:58] = str(len(payload)).encode("ascii").ljust(10, b" ")
        result.extend(header)
        result.extend(payload)
        if len(payload) % 2:
            result.extend(b"\n")
    return bytes(result)


def replace_tar_icons(raw, icons):
    cursor = 0
    out = bytearray()
    changed = set()
    while cursor < len(raw):
        header = raw[cursor:cursor + 512]
        if len(header) != 512:
            raise ValueError("Malformed tar header")
        if not any(header):
            out.extend(raw[cursor:])
            break
        basename = header[:100].split(b"\0")[0].decode("utf-8")
        prefix = header[345:500].split(b"\0")[0].decode("utf-8")
        filename = f"{prefix}/{basename}" if prefix else basename
        old_size = int(header[124:136].strip(b" \0") or b"0", 8)
        content_start = cursor + 512
        content_end = content_start + old_size
        content = raw[content_start:content_end]
        if len(content) != old_size:
            raise ValueError("Malformed tar member")
        candidate = filename.rsplit("/", 1)[-1]
        if candidate in icons and "/AppFirewall.app/" in filename:
            if candidate in changed:
                raise ValueError("Duplicate icon member")
            content = icons[candidate]
            changed.add(candidate)
            header = bytearray(header)
            header[124:136] = f"{len(content):011o}".encode("ascii") + b"\0"
            header[148:156] = b"        "
            header[148:156] = f"{sum(header):06o}".encode("ascii") + b"\0 "
        out.extend(header)
        out.extend(content)
        out.extend(b"\0" * ((-len(content)) % 512))
        cursor = content_start + ((old_size + 511) // 512) * 512
    if changed != set(ICONS):
        raise ValueError(f"Expected three icon replacements, got {sorted(changed)}")
    return bytes(out)


def inspect_result(original, updated, icons, expected_arch):
    old_parts = {name: blob for name, _, blob in decode_ar(original)}
    new_parts = {name: blob for name, _, blob in decode_ar(updated)}
    if old_parts.keys() != new_parts.keys():
        raise ValueError("Unexpected ar member changes")
    for name in old_parts:
        if not name.startswith("data.tar."):
            if old_parts[name] != new_parts[name]:
                raise ValueError(f"Modified control or metadata: {name}")
    control = old_parts["control.tar.gz"]
    with tarfile.open(fileobj=io.BytesIO(control), mode="r:gz") as tar:
        metadata = tar.extractfile("./control").read().decode("utf-8")
    if f"Architecture: {expected_arch}" not in metadata or "Version: 1.0" not in metadata:
        raise ValueError("Package version or architecture changed")
    original_data = lzma.decompress(old_parts["data.tar.lzma"])
    updated_data = lzma.decompress(new_parts["data.tar.lzma"])
    with tarfile.open(fileobj=io.BytesIO(original_data), mode="r:") as old_tar, \
         tarfile.open(fileobj=io.BytesIO(updated_data), mode="r:") as new_tar:
        old_members = old_tar.getmembers()
        new_members = new_tar.getmembers()
        if len(old_members) != len(new_members):
            raise ValueError("Tar member count changed")
        verified = set()
        for before, after in zip(old_members, new_members):
            if (before.name, before.mode, before.uid, before.gid, before.mtime,
                before.type, before.linkname) != (
                after.name, after.mode, after.uid, after.gid, after.mtime,
                after.type, after.linkname):
                raise ValueError(f"Unexpected file metadata change: {before.name}")
            if before.isfile():
                old_bytes = old_tar.extractfile(before).read()
                new_bytes = new_tar.extractfile(after).read()
                basename = before.name.rsplit("/", 1)[-1]
                if basename in icons and "/AppFirewall.app/" in before.name:
                    if new_bytes != icons[basename]:
                        raise ValueError(f"Incorrect icon: {basename}")
                    verified.add(basename)
                elif old_bytes != new_bytes:
                    raise ValueError(f"Non-icon file changed: {before.name}")
                if "AppFirewallProbe.app" in before.name:
                    raise ValueError("Diagnostic app must not be included")
        if verified != set(ICONS):
            raise ValueError("Not all icons were checked")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    pngs = {name: (RELEASE / "assets" / name).read_bytes() for name in ICONS}
    args.output.mkdir(parents=True, exist_ok=True)
    for arch, baseline in BASELINES.items():
        filename = f"{PACKAGE}{arch}.deb"
        source = (RELEASE / "debs" / filename).read_bytes()
        if sha(source) != baseline:
            raise ValueError(f"Unexpected original DEB for {arch}; refusing to patch")
        parts = decode_ar(source)
        updated = []
        for name, header, data in parts:
            if name == "data.tar.lzma":
                contents = replace_tar_icons(lzma.decompress(data), pngs)
                data = lzma.compress(contents, format=lzma.FORMAT_ALONE, preset=9)
            updated.append((name, header, data))
        result = encode_ar(updated)
        inspect_result(source, result, pngs, arch)
        destination = args.output / filename
        destination.write_bytes(result)
        print(f"{arch} {destination.stat().st_size} bytes SHA256={sha(result)}")


if __name__ == "__main__":
    main()
