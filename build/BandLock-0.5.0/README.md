# BandLock 0.5.0 Global

Public global edition of BandLock for iOS 16 / Dopamine / RootHide.

## What changed

- Removes the Spain/Orange band allow-list from the public edition.
- Uses the LTE bands reported at runtime by `CTBandInfo.supportedBands` as the authoritative selectable set.
- Shows FDD, TDD and supplemental-downlink (SDL) information for known LTE bands.
- Groups the selector by duplex mode instead of by Spain-specific coverage/capacity assumptions.
- Adds generic `All supported`, `FDD only`, `TDD only` and `Current active selection` helpers.
- Keeps write verification and the single CommCenter retry introduced in 0.4.4.
- Uses a new public package ID, PreferenceBundle name, state file and log directory so it does not overwrite the private Spain-focused 0.4.4 edition.
- Does not use carrier presets or a static country database. A modem-supported band is not necessarily deployed by the current carrier or available at the current location.

## Package separation

- Private Spain edition: `com.local.bandlock` (0.4.4, kept outside the public release line).
- Public global edition: `com.gokuencinar.bandlock` (0.5.0+).

No resident daemon, no SpringBoard injection and no automatic modem writes at boot.
