# BandLock 0.6.33 Global App

BandLock 0.6.33 moves the public tweak out of the iOS Settings app and into a dedicated UIKit application installed on the Home Screen.

### 0.6.33 country frequency manager, Info and languages

- Keeps the validated iOS 16.3 Field Test bridge that invokes MobilePhone/TelephonyUI's own `launchFieldTestIfNeeded:` special-code branch before any normal dial request is built.
- When **Prepare compatible bands** succeeds for a country, BandLock stores only that country's ISO code. Control then exposes **Manage frequencies for <country>**.
- The country frequency manager only shows the selected country's LTE bands that are also reported as supported by the current iPhone. Switches update the pending selection only; the modem still changes exclusively after an explicit **Apply selection**.
- Adds a third bottom tab, **Info**, with credits for **Gokuencinar / GokuEn**, installed version, update checking against GokuEnREPO's APT index, in-app release notes, repository link and a frequency glossary.
- Credits now show the Windows account avatar used by Gokuencinar/GokuEn, bundled as a local circular profile image beside the name.
- Fixes UTF-8/mojibake in the frequency glossary and the remaining affected country/language UI strings so accents, punctuation and symbols render correctly.
- Adds an in-app language selector independent from the system language: Spanish, English, French, German, Traditional Chinese, Simplified Chinese / Mandarin and Japanese. Country names follow the selected app locale.
- Adds a glossary explaining LTE/4G, Bxx, MHz/GHz, FDD, TDD, SDL, APT 700, AWS, PCS, WCS, CBRS, LAA, CDMA, WCDMA/UMTS/HSPA, GSM/EDGE, RAT and NR/5G.
- Network mode IPC now also carries a semantic `mode_code`, so the UIKit app can translate Automatic/LTE-only independently of the daemon's system locale.
- No diagnostic self-test or automatic modem mutation runs when the app opens.
- The UIKit client does not call `jbroot()` when a button is pressed. It derives the physical `.jbroot-*` root once from RootHide's `CFFIXED_USER_HOME`/`HOME` environment, caches the full `/tmp/com.gokuencinar.bandlockd.sock` path and reuses it for IPC.
- The daemon continues to resolve and bind the same socket with RootHide's `jbroot()` API. This keeps the client aligned with the signed standalone probe that successfully queried the modem on the target iPhone.
- The UIKit app links `libroothide`, while CommCenter/CoreTelephony entitlements remain restricted to `BandLockDaemon`.
- A raw C breadcrumb logger writes `/var/mobile/Documents/BandLock-client.log` with `open/write/fsync` around every refresh stage: socket creation, connect, write, read, JSON parsing, main-queue dispatch and UI completion.
- `SIGPIPE` is ignored process-wide and Objective-C exceptions in the background IPC and main completion paths are caught and recorded so recoverable client failures do not terminate the app.
- Refresh now disables immediately once an IPC request is marked busy, preventing a second tap from entering the synchronous busy path during an in-flight request.
- Package scripts remove the short `/tmp/bandlockd.sock` path left by the unvalidated 0.6.14 experiment before restoring the verified long socket name.

## Interface

- **Control** tab: modem status, serving LTE band, network mode, pending selection, apply/restore actions and Field Test access.
- **Countries** tab: searchable worldwide LTE reference list. Each country shows its reference LTE bands and which of those are also supported by the current iPhone modem.
- Country profiles never write to the modem automatically. **Prepare compatible bands** only creates a pending selection; the user must review it and explicitly tap **Apply selection** in Control.
- UI-only actions never invoke CoreTelephony implicitly. If the modem has not been read yet, the app asks the user to use **Refresh status** explicitly.

## Safety model

- The modem remains the source of truth for device-supported LTE bands.
- Band writes are rejected if the supported-band set changed since the selection was prepared.
- Empty selections and SDL-only selections are rejected.
- Current active bands are saved before a write so they can be restored.
- CommCenter read-back verification and the single automatic retry from 0.5.0 are retained.
- CoreTelephony, CommCenter and Field Test private APIs run only inside `BandLockDaemon`, a separate LaunchDaemon supervised by `launchd`. The UIKit app never spawns it directly.
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
- Privileged daemon installed as `/usr/libexec/BandLockDaemon`, with `/Library/LaunchDaemons/com.gokuencinar.bandlockd.plist`, and signed separately with the CommCenter entitlements.
- No PreferenceLoader dependency and no Settings PreferenceBundle in 0.6.14.
- The UI app keeps only the platform/no-sandbox permissions needed for local IPC; CommCenter entitlements are restricted to the daemon binary.

BandLock 0.6.33 continues to target LTE/4G band control only; it does not claim 5G NR band locking.
