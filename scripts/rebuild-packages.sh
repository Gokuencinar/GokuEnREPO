#!/usr/bin/env bash
set -euo pipefail

: > Packages
# Only publish packages from each tweak's dedicated debs/ directory.
for package_dir in tweaks/*/debs; do
  [ -d "$package_dir" ] || continue
  dpkg-scanpackages -m "$package_dir" /dev/null >> Packages
done

python3 - <<'PY'
from pathlib import Path

path = Path("Packages")
blocks = path.read_text().strip().split("\n\n")

for i, block in enumerate(blocks):
    lines = block.splitlines()
    fields = {}
    for line in lines:
        if ": " in line:
            k, v = line.split(": ", 1)
            fields[k] = v

    if fields.get("Package") != "com.betterwifirh.tweak" or fields.get("Version") not in {"0.3.12", "0.3.13", "0.3.14"}:
        continue

    arch = fields.get("Architecture")
    variants = {
        "iphoneos-arm64e": (
            "BetterWiFi RH (RootHide)",
            "Advanced Wi-Fi tools for iOS 16 RootHide with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
        ),
        "iphoneos-arm64": (
            "BetterWiFi RH (Dopamine)",
            "Advanced Wi-Fi tools for iOS 15-18 Dopamine rootless with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
        ),
        "iphoneos-arm": (
            "BetterWiFi RH (Rootful)",
            "Advanced Wi-Fi tools for iOS 15-17 rootful jailbreaks with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
        ),
    }
    if arch not in variants:
        continue

    name, description = variants[arch]
    rewritten = []
    seen = set()
    for line in lines:
        if ": " not in line:
            rewritten.append(line)
            continue
        key, _ = line.split(": ", 1)
        if key == "Name":
            line = f"Name: {name}"
        elif key == "Description":
            line = f"Description: {description}"
        rewritten.append(line)
        seen.add(key)

    if "Homepage" not in seen:
        rewritten.append("Homepage: https://github.com/Gokuencinar/GokuEnREPO/tree/main/tweaks/BetterWiFi-RH")
    if "Depiction" not in seen:
        rewritten.append("Depiction: https://gokuencinar.github.io/GokuEnREPO/tweaks/BetterWiFi-RH/depiction.html")

    blocks[i] = "\n".join(rewritten)

path.write_text("\n\n".join(blocks) + "\n")
PY

gzip -9 -c Packages > Packages.gz
