#!/usr/bin/env python3
"""Reject BandLock native binaries that lack the RootHide arm64e ABI-v2 slice."""

from __future__ import annotations

import argparse
from pathlib import Path
import struct


FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64_ALL = 0x00000000
CPU_SUBTYPE_ARM64E_ABI_V2 = 0x80000002


def fat_architectures(path: Path) -> list[tuple[int, int]]:
    blob = path.read_bytes()
    if len(blob) < 8:
        raise RuntimeError(f"{path}: file too small")

    magic, count = struct.unpack_from(">II", blob, 0)
    if magic not in (FAT_MAGIC, FAT_MAGIC_64):
        raise RuntimeError(f"{path}: expected a universal Mach-O, magic=0x{magic:08x}")

    stride = 20 if magic == FAT_MAGIC else 32
    architectures: list[tuple[int, int]] = []
    for index in range(count):
        offset = 8 + index * stride
        if offset + stride > len(blob):
            raise RuntimeError(f"{path}: truncated FAT architecture table")
        cputype, cpusubtype = struct.unpack_from(">II", blob, offset)
        architectures.append((cputype, cpusubtype))
    return architectures


def verify(path: Path) -> None:
    archs = fat_architectures(path)
    arm64_subtypes = [subtype for cputype, subtype in archs if cputype == CPU_TYPE_ARM64]
    if CPU_SUBTYPE_ARM64_ALL not in arm64_subtypes:
        raise RuntimeError(f"{path}: missing normal arm64 slice (subtype 0x00000000)")
    if CPU_SUBTYPE_ARM64E_ABI_V2 not in arm64_subtypes:
        rendered = ", ".join(f"0x{x:08x}" for x in arm64_subtypes) or "none"
        raise RuntimeError(
            f"{path}: missing RootHide arm64e ABI-v2 subtype 0x80000002; found {rendered}"
        )
    print(f"PASS {path}: arm64 subtypes " + ", ".join(f"0x{x:08x}" for x in arm64_subtypes))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    for path in args.paths:
        verify(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
