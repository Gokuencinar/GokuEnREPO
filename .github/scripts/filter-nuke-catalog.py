#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


TARGET_PACKAGE = "com.gokuencinar.nukewireless"


def fields_for(stanza: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in stanza.splitlines():
        if ":" not in line or line.startswith((" ", "\t")):
            continue
        key, value = line.split(":", 1)
        fields[key] = value.strip()
    return fields


def newer(left: str, right: str) -> bool:
    result = subprocess.run(
        ["dpkg", "--compare-versions", left, "gt", right],
        check=False,
    )
    return result.returncode == 0


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "Packages")
    stanzas = [s for s in path.read_text().strip().split("\n\n") if s.strip()]
    parsed = [fields_for(stanza) for stanza in stanzas]

    best_index = None
    best_version = None
    for index, fields in enumerate(parsed):
        if fields.get("Package") != TARGET_PACKAGE:
            continue
        version = fields.get("Version")
        if not version:
            continue
        if best_version is None or newer(version, best_version):
            best_index = index
            best_version = version

    output = []
    for index, (stanza, fields) in enumerate(zip(stanzas, parsed)):
        if fields.get("Package") == TARGET_PACKAGE and index != best_index:
            continue
        output.append(stanza)

    path.write_text("\n\n".join(output) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
