#!/usr/bin/env python3
"""Generate BandLock country spectrum references from the MCC-MNC.org bulk export.

Inputs: networks.csv and countries.csv from https://mcc-mnc.org/downloads/
Output: app/Resources/country-spectrum.json

The snapshot is a reference of frequencies reported by network records. It is
not proof that a frequency is currently on-air at every location in a country.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from pathlib import Path


def classify(token: str):
    parts = token.split()
    if len(parts) < 2 or not parts[-1].isdigit():
        return None
    mhz = int(parts[-1])
    if token.startswith("GSM "):
        return "2G", mhz
    if token.startswith("UMTS ") or token.startswith("UMTS-TDD "):
        return "3G", mhz
    if token.startswith("LTE ") or token.startswith("TD-LTE "):
        return "4G", mhz
    if token.startswith("5G ") or token.startswith("NR "):
        return "5G", mhz
    return None


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: update-bandlock-country-spectrum.py networks.csv countries.csv output.json", file=sys.stderr)
        return 2
    src, country_src, out = map(Path, sys.argv[1:])
    countries = defaultdict(lambda: {"name": None, "2G": set(), "3G": set(), "4G": set(), "5G": set()})
    # Seed all ISO markets, including the few that currently have no network
    # rows. If a source has duplicate ISO entries, prefer the one with the
    # larger network inventory (e.g. Georgia over the Abkhazia alias).
    seeded = {}
    with country_src.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            iso = (row.get("iso") or "").strip().upper()
            if len(iso) != 2:
                continue
            count = int((row.get("network_count") or "0").strip() or 0)
            previous = seeded.get(iso)
            if previous is None or count > previous[0]:
                seeded[iso] = (count, (row.get("country") or iso).strip())
    for iso, (_, name) in seeded.items():
        countries[iso]["name"] = name

    with src.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            iso = (row.get("iso") or "").strip().upper()
            if len(iso) != 2:
                continue
            country = countries[iso]
            if not country["name"]:
                country["name"] = (row.get("country") or iso).strip()
            for raw in (row.get("frequency_bands") or "").split(","):
                item = classify(raw.strip())
                if item:
                    generation, mhz = item
                    country[generation].add(mhz)

    payload = {
        "version": 1,
        "last_updated": "2026-10-21",
        "source": {
            "name": "MCC-MNC.org networks bulk export",
            "url": "https://mcc-mnc.org/downloads/",
            "license": "Free for commercial and non-commercial use; attribution requested",
            "note": "Aggregated frequencies from network records; blank means unknown, not unsupported",
        },
        "countries": [],
    }
    for iso in sorted(countries):
        row = countries[iso]
        payload["countries"].append({
            "iso2": iso,
            "name": row["name"] or iso,
            "frequencies_mhz": {g: sorted(row[g]) for g in ("2G", "3G", "4G", "5G")},
        })
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(payload['countries'])} countries to {out}")
    for generation in ("2G", "3G", "4G", "5G"):
        print(generation, sum(bool(c["frequencies_mhz"][generation]) for c in payload["countries"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
