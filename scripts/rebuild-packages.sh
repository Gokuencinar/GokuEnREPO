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
raw = path.read_text().strip()
blocks = [] if not raw else raw.split("\n\n")
out = []

split_names = {
    "com.betterwifirh.tweak.roothide": (
        "BetterWiFi RH (RootHide)",
        "Advanced Wi-Fi tools for iOS 16/17/18 (Dopamine/RootHide/Relaxin) with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters.",
    ),
    "com.betterwifirh.tweak.dopamine": (
        "BetterWiFi RH (Dopamine)",
        "Advanced Wi-Fi tools for iOS 16/17/18 (Dopamine/RootHide/Relaxin) with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters.",
    ),
    "com.betterwifirh.tweak.rootful": (
        "BetterWiFi RH (Rootful)",
        "Advanced Wi-Fi tools for iOS 16/17/18 (Dopamine/RootHide/Relaxin) with connected-network details, live signal monitoring and history, 2.4/5 GHz channel analysis, classic/advanced filters.",
    ),
}

for block in blocks:
    lines = block.splitlines()
    fields = {}
    for line in lines:
        if ": " in line:
            k, v = line.split(": ", 1)
            fields[k] = v

    package = fields.get("Package")

    if package == "com.betterwifirh.tweak":
        continue

    if package in split_names:
        name, description = split_names[package]
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
        block = "\n".join(rewritten)

    out.append(block)

path.write_text("\n\n".join(out) + ("\n" if out else ""))
PY

gzip -9 -c Packages > Packages.gz
