# BandLock 1.0 Global App — Dopamine rootless

This is the **Dopamine rootless** build of BandLock 1.0. It uses normal rootless `/var/jb` packaging and direct shared `/tmp` IPC; it does not link or call RootHide/libroothide.

### 1.0 5G modes and NR band control

- Adds **5G Auto / 5G On / 5G Only** to Control and keeps the selector visible from app launch. 5G Only requests NR Standalone (SA) and warns that service can be lost where SA is unavailable.
- Reads 5G NR supported and active bands from `CTBandInfo`, keeps an independent pending NR selection, and applies NR changes with modem read-back verification while preserving LTE and unknown RAT entries.
- Adds a dedicated 5G NR band editor using `nXX` notation, frequency/duplex metadata and restore actions.
- Extends the 160-country offline catalogue with `nr_bands`; countries with explicit current 5G data show reference nXX bands and their intersection with the actual iPhone modem.
- Country preparation now prepares LTE and NR intersections separately. Nothing is applied automatically.

### 0.6.35 Info polish and support link

- Adds an explicit **Current version / Versión actual** row in the Info tab, read dynamically from `CFBundleShortVersionString`.
- Adds a dedicated **Buy Me a Coffee** row that opens `https://buymeacoffee.com/gokuen`.
- Keeps the modem, country manager, languages, Field Test and daemon behavior from 0.6.34 unchanged.

### 0.6.34 country frequency manager, Info and languages

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
- The UIKit client and daemon communicate through the shared rootless socket `/tmp/com.gokuencinar.bandlockd.dopamine.sock`; no RootHide path translation is used.
- The Dopamine build does not import `roothide.h`, call `jbroot()` or link `libroothide`.
- CommCenter/CoreTelephony entitlements remain restricted to `BandLockDaemon` exactly as in the validated RootHide architecture.
- A raw C breadcrumb logger writes `/var/mobile/Documents/BandLock-client.log` with `open/write/fsync` around every refresh stage: socket creation, connect, write, read, JSON parsing, main-queue dispatch and UI completion.
- `SIGPIPE` is ignored process-wide and Objective-C exceptions in the background IPC and main completion paths are caught and recorded so recoverable client failures do not terminate the app.
- Refresh now disables immediately once an IPC request is marked busy, preventing a second tap from entering the synchronous busy path during an in-flight request.
- Package scripts clean stale RootHide/Dopamine BandLock socket names before starting the Dopamine daemon.

## Interface

- **Control** tab: modem status, serving band, LTE/5G network modes, independent LTE and 5G NR selections, apply/restore actions and Field Test access.
- **Countries** tab: searchable worldwide LTE + 5G NR reference list. Each country shows reference bands and which are also reported as supported by the current iPhone modem.
- Country profiles never write to the modem automatically. **Prepare compatible bands** only creates a pending selection; the user must review it and explicitly tap **Apply selection** in Control.
- UI-only actions never invoke CoreTelephony implicitly. If the modem has not been read yet, the app asks the user to use **Refresh status** explicitly.

## Safety model

- The modem remains the source of truth for device-supported LTE and 5G NR bands.
- Band writes are rejected if the supported-band set changed since the selection was prepared.
- Empty selections and SDL-only selections are rejected.
- Current active bands are saved before a write so they can be restored.
- CommCenter read-back verification and the single automatic retry from 0.5.0 are retained.
- CoreTelephony, CommCenter and Field Test private APIs run only inside `BandLockDaemon`, a separate LaunchDaemon supervised by `launchd`. The UIKit app never spawns it directly.
- Opening the app does not modify modem settings.

## Country data

- Bundled offline snapshot: `app/Resources/countries.json`.
- 160 countries and territories are listed; 156 have LTE data and 99 currently have explicit 5G NR band data in the bundled snapshot.
- 5G NR country references are sourced from the current WorldTimeZone.com 5G frequency table and stored offline with the snapshot date and source URL.
- Country data is reference information only and can vary by carrier, region, roaming agreement and time.
- The app always intersects country LTE/NR bands with the corresponding bands reported by the actual iPhone before preparing selections.

## Dopamine rootless packaging

- Debian package: `com.gokuencinar.bandlock.dopamine`
- App bundle: `com.gokuencinar.bandlock.app`
- Rootless application installed under `/var/jb/Applications/BandLock.app` by the Theos rootless package scheme.
- Privileged daemon installed as `/var/jb/usr/libexec/BandLockDaemon`, with `/var/jb/Library/LaunchDaemons/com.gokuencinar.bandlockd.dopamine.plist`, and signed separately with the CommCenter entitlements.
- The package depends on `mobilesubstrate`/ElleKit compatibility so the Field Test bridge can inject into MobilePhone.
- The UI app keeps only the platform/no-sandbox permissions needed for local IPC; CommCenter entitlements are restricted to the daemon binary.

BandLock 1.0 adds 5G NR mode and band-control paths while keeping the 5G mode selector visible on all supported iOS 16 devices. Actual 5G/NR writes still depend on modem, carrier and device support and should be validated on each hardware generation.
