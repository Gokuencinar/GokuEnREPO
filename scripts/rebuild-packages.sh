#!/usr/bin/env bash
set -euo pipefail

: > Packages
for package_dir in tweaks/*/debs; do
  [ -d "$package_dir" ] || continue
  dpkg-scanpackages -m "$package_dir" /dev/null >> Packages
done

python3 - <<'PY'
from pathlib import Path

path = Path("Packages")
blocks = path.read_text().strip().split("\n\n")

legacy_versions = {"0.3.12", "0.3.13", "0.3.14"}
legacy_package = "com.betterwifirh.tweak"
new_version = "0.3.15"

legacy_variants = {
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

new_variants = {
    "com.betterwifirh.tweak.roothide": (
        "BetterWiFi RH (RootHide)",
        "Advanced Wi-Fi tools for iOS 16 RootHide with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
    ),
    "com.betterwifirh.tweak.dopamine": (
        "BetterWiFi RH (Dopamine)",
        "Advanced Wi-Fi tools for iOS 15-18 Dopamine rootless with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
    ),
    "com.betterwifirh.tweak.rootful": (
        "BetterWiFi RH (Rootful)",
        "Advanced Wi-Fi tools for iOS 15-17 rootful jailbreaks with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters, diagnostics, Shuffle integration and language selection."
    ),
}

for i, block in enumerate(blocks):
    lines = block.splitlines()
    fields = {}
    for line in lines:
        if ": " in line:
            k, v = line.split(": ", 1)
            fields[k] = v

    package = fields.get("Package")
    version = fields.get("Version")
    arch = fields.get("Architecture")

    name = None
    description = None

    if package == legacy_package and version in legacy_versions:
        if arch in legacy_variants:
            name, description = legacy_variants[arch]
    elif package in new_variants and version == new_version:
        name, description = new_variants[package]
    elif package == legacy_package and version == new_version:
        name = "BetterWiFi RH (Migration)"
        description = "Transitional package that installs the correct BetterWiFi RH variant for this jailbreak architecture."

    if not name:
        continue

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
