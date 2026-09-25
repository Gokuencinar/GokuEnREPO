# BandLock 0.6.0 Global App

BandLock 0.6.0 moves the public tweak out of the iOS Settings app and into a dedicated UIKit application installed on the Home Screen.

## Interface

- **Control** tab: modem status, serving LTE band, network mode, pending selection, apply/restore actions and Field Test access.
- **Countries** tab: searchable worldwide LTE reference list. Each country shows its reference LTE bands and which of those are also supported by the current iPhone modem.
- Country profiles never write to the modem automatically. **Prepare compatible bands** only creates a pending selection; the user must review it and explicitly tap **Apply selection** in Control.

## Safety model

- The modem remains the source of truth for device-supported LTE bands.
- Band writes are rejected if the supported-band set changed since the selection was prepared.
- Empty selections and SDL-only selections are rejected.
- Current active bands are saved before a write so they can be restored.
- CommCenter read-back verification and the single automatic retry from 0.5.0 are retained.
- Opening the app does not modify modem settings.

## Country data

- Bundled offline snapshot: `app/Resources/countries.json`.
- 160 countries and territories are listed; 156 currently have LTE band data in the snapshot.
- Country data is reference information only and can vary by carrier, region, roaming agreement and time.
- The app always intersects country bands with the LTE bands reported as supported by the actual iPhone before preparing a selection.

## RootHide packaging

- Debian package: `com.gokuencinar.bandlock`
- App bundle: `com.gokuencinar.bandlock.app`
- RootHide application installed under `/Applications/BandLock.app` through the package scheme.
- No PreferenceLoader dependency and no Settings PreferenceBundle in 0.6.0.
- RootHide platform/no-sandbox entitlements are included for the standalone process.

BandLock 0.6.0 continues to target LTE/4G band control only; it does not claim 5G NR band locking.
