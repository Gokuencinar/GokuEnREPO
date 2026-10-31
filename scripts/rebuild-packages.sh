#!/usr/bin/env bash
set -euo pipefail

: > Packages
for package_dir in tweaks/*/debs; do
  [ -d "$package_dir" ] || continue
  dpkg-scanpackages -m "$package_dir" /dev/null >> Packages
done

python3 - <<'PY'
from pathlib import Path
import sys
from scripts.bandlock_publication import publishable

path = Path("Packages")
raw = path.read_text().strip()
blocks = [] if not raw else raw.split("\n\n")
out = []

split_names = {
    "com.betterwifirh.tweak.roothide": (
        "BetterWiFi RH (RootHide)",
        "Advanced Wi-Fi tools with connected-network details, quality score, live signal history, diagnostics, and improved 2.4/5/6 GHz filtering.",
    ),
    "com.betterwifirh.tweak.dopamine": (
        "BetterWiFi RH (Dopamine)",
        "Advanced Wi-Fi tools with connected-network details, quality score, live signal history, diagnostics, and improved 2.4/5/6 GHz filtering.",
    ),
    "com.betterwifirh.tweak.rootful": (
        "BetterWiFi RH (Rootful)",
        "Advanced Wi-Fi tools with connected-network details, quality score, live signal history, diagnostics, and improved 2.4/5/6 GHz filtering.",
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

    # The release channel is an explicit allow-list. Never allow local or
    # CI experiment versions (rhscan, rhui, diagnostics, etc.) into Sileo,
    # even if their DEB was accidentally copied into tweaks/BandLock/debs.
    if not publishable(package or "", fields.get("Version", "")):
        print(f"Skipping unpublished BandLock package: {package} "
              f"{fields.get('Version', '<missing>')}", file=sys.stderr)
        continue

    if package == "com.gokuencinar.nukewireless":
        variant = {"iphoneos-arm64":"Dopamine", "iphoneos-arm64e":"RootHide", "iphoneos-arm":"Rootful"}[fields["Architecture"]]
        rewritten = [line for line in block.splitlines()
                     if not line.startswith(("Name: ", "Description: ", "Depiction: ", "SileoDepiction: ", "Homepage: ", "Icon: "))]
        rewritten.extend([
            f"Name: NukeWireless ({variant})",
            "Description: Block Wi-Fi and personal hotspot devices, scan BLE devices and send Bluetooth advertisements.",
            "Depiction: https://gokuencinar.github.io/GokuEnREPO/tweaks/NukeWireless/depiction.html",
            "SileoDepiction: https://gokuencinar.github.io/GokuEnREPO/tweaks/NukeWireless/depiction.json",
            "Homepage: https://gokuencinar.github.io/GokuEnREPO/tweaks/NukeWireless/depiction.html",
            "Icon: https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/tweaks/NukeWireless/assets/icon.png",
        ])
        block = "\n".join(rewritten)

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

    if package == "com.ps.cconandoff":
        rewritten = []
        for line in block.splitlines():
            if line.startswith("Description: "):
                line = "Description: Toggle Wi-Fi and Bluetooth On/Off from Control Center (iOS 11+, including iOS 18)."
            elif line.startswith("Depiction: "):
                line = "Depiction: https://gokuencinar.github.io/GokuEnREPO/tweaks/CC-On-Off/depiction.html"
            rewritten.append(line)
        block = "\n".join(rewritten)

    if package == "com.gokuencinar.bettersettings":
        rewritten = [line for line in block.splitlines()
                     if not line.startswith(("Icon: ", "Depiction: ", "Description: "))]
        rewritten.append("Description: A convenient way to organize your tweaks, just like Shuffle did on earlier versions of iOS.")
        rewritten.append("Icon: https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/tweaks/BetterSettings/assets/icon.png")
        rewritten.append("Depiction: https://gokuencinar.github.io/GokuEnREPO/tweaks/BetterSettings/depiction.html")
        if fields.get("Architecture") == "iphoneos-arm64e":
            rewritten = ["Name: Better Settings (RootHide)" if line.startswith("Name:") else line for line in rewritten]
        block = "\n".join(rewritten)

    if package == "preferenceloader":
        rewritten = [line for line in block.splitlines() if not line.startswith("Description:")]
        if fields.get("Architecture") == "iphoneos-arm64e":
            rewritten = ["Name: PreferenceLoader (RootHide)" if line.startswith("Name:") else line for line in rewritten]
        block = "\n".join(rewritten)

    out.append(block)

path.write_text("\n\n".join(out) + ("\n" if out else ""))
PY

gzip -9 -c Packages > Packages.gz
