# BandLock experimental 1.6.0~rhui3 — compact Control + checkmarks

## Context

The previous Control placed too many visible controls in a long scrolling page. Historic commit `c2efb10` (2026-09-28) deliberately replaced `UISwitch` with table-row checkmarks in LTE, NR, country bands and CC settings. The original affected device and iOS version are not known with confidence.

## UI

- Visible initially: gradient network hero, **LTE Analyzer** and **Refresh** shortcuts, **My LTE Bands** card (pending bands and edit, apply only on verified supported OS versions).
- Collapsed sections: **Network details**, **Network mode**, **5G NR** (where applicable), **Tools**, **Advanced diagnostics** and **Recovery and safety**.
- The recovery panel automatically opens if a scan or recovery is active.
- iOS 18 preview keeps modem band/RAT writes and active scan disabled in the daemon; corresponding actions are hidden/disabled in the UI.
- Picker rows are `UITableViewCellAccessoryCheckmark` with single-row refresh, never `UISwitch`. Tapping a band only stages selection.

This preview is a CI artifact and must not enter public Sileo metadata.
