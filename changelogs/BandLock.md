# BandLock Changelog

This changelog documents the public BandLock releases currently distributed through **GokuEnREPO**.

> **About BandLock**  
> BandLock is an iOS jailbreak app for inspecting and selecting LTE/4G and supported 5G NR bands, controlling radio access mode, and viewing worldwide band references. BandLock 1.1 is distributed in separate builds for **RootHide**, **Dopamine rootless**, and **classic rootful** jailbreaks.

> **Compatibility**  
> iOS 16.x. RootHide uses `iphoneos-arm64e`; Dopamine rootless uses `iphoneos-arm64`; Rootful uses `iphoneos-arm` with arm64 binaries and classic filesystem paths.

---

## 1.1 — Control Center network selector

### Added
- Added a compact **1×1 Control Center module** for quick radio-mode changes.
- Added an action-sheet selector for **Automatic, 3G / UMTS, 4G / LTE and 5G**. 5G is disabled on devices/lines that do not report 5G support.
- Added immediate visual-state refresh so the Control Center tile reflects the selected mode without closing and reopening Control Center.

### Changed
- Control Center Auto/3G/4G changes now use the direct CoreTelephony RAT-selection path instead of waiting for the app daemon's synchronous subscription-context lookup and read-back cycle.
- Status verification is deferred after a Control Center change so modem handovers, especially through 3G, do not block later selections.
- Rapid mode changes are accepted without waiting for the previous 3G transition to settle.
- Package installation no longer performs an automatic SpringBoard reload, avoiding interrupted Sileo installs.

### Validation
- RootHide 1.1 was physically validated on an iPhone XS running iOS 16.3.x, including repeated **Auto → 4G → 3G → Auto/4G** transitions and immediate Control Center colour updates.
- RootHide, Dopamine and Rootful packages compile successfully in GitHub Actions.

### Packages
- **BandLock (RootHide)** — `com.gokuencinar.bandlock` — `iphoneos-arm64e`
- **BandLock (Dopamine)** — `com.gokuencinar.bandlock.dopamine` — `iphoneos-arm64`
- **BandLock (Rootful)** — `com.gokuencinar.bandlock.rootful` — `iphoneos-arm`

---

## 1.0 — RootHide, Dopamine & Rootful

### Added
- Added **5G Auto / 5G On / 5G Only** network-mode controls. The selector is visible immediately when BandLock opens; **5G Only** requests NR Standalone (SA).
- Added independent 5G NR supported, active and pending band state using `nXX` notation.
- Added a dedicated 5G NR band editor, apply/restore actions, read-back verification and preservation of LTE/other RAT entries when changing NR bands.
- Extended the offline 160-country catalogue with 5G NR reference data. The bundled snapshot contains explicit NR data for 99 countries/territories and includes Spain n1/n3/n28/n78/n258.
- Added 5G NR frequency/duplex metadata for the NR bands present in the country dataset.
- Added persistence for pending LTE and NR selections so a refresh or app restart does not silently discard a prepared selection.
- Moved the language selector to the top-right of the **BandLock** screen and display the currently selected language beside the globe icon.

### Changed
- **Refresh status** no longer resets prepared LTE/NR selections.
- Applying LTE clears only the LTE pending state; applying NR clears only the NR pending state.
- The **Result** row starts empty and is populated only after the user explicitly taps **Refresh status**.
- Country preparation and management now handle LTE and NR intersections independently and never auto-apply modem changes.
- Version promoted from the 0.6.x development line to **1.0** for the public release.

### Validation
- RootHide, Dopamine and Rootful packages compile successfully in GitHub Actions.
- RootHide 1.0 regression-tested on an iPhone XS: installation, app launch and `BandLockDaemon` operation verified.
- 5G mode and NR-band writes depend on private CoreTelephony behavior and require compatible 5G hardware/carrier support; community validation across iPhone generations is encouraged.

### Packages
- **BandLock (RootHide)** — `com.gokuencinar.bandlock` — `iphoneos-arm64e`
- **BandLock (Dopamine)** — `com.gokuencinar.bandlock.dopamine` — `iphoneos-arm64`
- **BandLock (Rootful)** — `com.gokuencinar.bandlock.rootful` — `iphoneos-arm`

---

## 0.6.35 — RootHide & Dopamine

### Added
- The **Info** tab now shows a dedicated **Current Version** row, read dynamically from `CFBundleShortVersionString`.
- Added a **Buy Me a Coffee** row to the Info tab for supporting development:  
  https://buymeacoffee.com/gokuen
- Package metadata now includes public links to documentation, the web depiction, and the BandLock icon hosted in GokuEnREPO.

### Changed
- The installed variant (**RootHide** or **Dopamine**) and the app version are now displayed separately for a clearer Info screen.
- The daemon architecture, LTE/4G controls, country profiles, Field Test integration, localization system, and write verification logic remain unchanged from 0.6.34.

### Packages
- **BandLock (RootHide)** — `com.gokuencinar.bandlock` — `iphoneos-arm64e`
- **BandLock (Dopamine)** — `com.gokuencinar.bandlock.dopamine` — `iphoneos-arm64`

---

## 0.6.34 — RootHide & Dopamine

### Added
- BandLock is now distributed as **two independent packages** with the same interface and feature set:
  - **BandLock (RootHide)** — `com.gokuencinar.bandlock` — `iphoneos-arm64e`
  - **BandLock (Dopamine)** — `com.gokuencinar.bandlock.dopamine` — `iphoneos-arm64`
- Both packages declare conflicts with each other to prevent installing the wrong jailbreak variant.
- The Dopamine build now uses standard Theos rootless packaging, `/var/jb` paths, and the socket `/tmp/com.gokuencinar.bandlockd.dopamine.sock`.
- The Dopamine build no longer imports `roothide.h`, calls `jbroot()`, or links against `libroothide`.
- Added **Manage frequencies for <country>** after preparing a country profile. The editor is restricted to:
  `country bands ∩ iPhone-supported bands`
  and only updates the pending selection.
- Added a new **Info** tab with:
  - Credits
  - Installed version
  - Update checking
  - Release notes
  - GokuEnREPO link
  - Frequency glossary
  - In-app language selector
- Added integrated credits with avatar and the name **Gokuencinar · GokuEn**.
- Added built-in languages:
  - Spanish
  - English
  - French
  - German
  - Traditional Chinese
  - Simplified Chinese / Mandarin
  - Japanese
- Added a glossary covering LTE/4G, FDD, TDD, SDL, APT 700, AWS, PCS, WCS, CBRS, LAA, CDMA, UMTS/HSPA, GSM/EDGE, RAT, and 5G NR.
- Field Test keeps the validated bridge based on `DialerController +launchFieldTestIfNeeded:`, with `TPPhonePad` as a fallback, without placing the service code as a normal phone call.

### Fixed
- Cleaned up affected UTF-8 strings to prevent mojibake such as `Ã`, `Â`, and similar encoding artifacts in the glossary and other screens.
- The credits avatar now loads from an explicit bundle path using `imageWithContentsOfFile`.
- Installation now closes only BandLock, preventing an outdated in-memory app instance from surviving an update to bundled resources or UI.

### Validation
- **RootHide 0.6.34**
  - CI build and signing completed successfully.
  - Physical installation validated on an iPhone XS running iOS 16.3.1.
  - `BandLockDaemon` remained running with `runs=1`, without unexpected exits.
  - LTE/status reads were confirmed working.
- **Dopamine 0.6.34**
  - Full arm64 + arm64e build completed successfully.
  - Signing and entitlements validated.
  - CI confirmed rootless `/var/jb` layout and absence of `libroothide`.
  - Full physical validation still requires a device running standard Dopamine.

---

## 0.6.3 — Global App

### Changed
- Completely removed the `posix_spawn` architecture introduced in 0.6.2 after confirming that tapping **Refresh Status** could still terminate the app while launching a helper from the UIKit process.
- Removed the embedded `BandLockHelper` from `BandLock.app`.
- Added **`BandLockDaemon`** as a standalone LaunchDaemon installed at:
  `/usr/libexec/BandLockDaemon`
- Registered the daemon through:
  `/Library/LaunchDaemons/com.gokuencinar.bandlockd.plist`
- The daemon is supervised by `launchd`.
- The app and daemon now communicate through a local Unix socket using JSON.
- The UI no longer creates helper processes.
- The RootHide socket is located inside jbroot at:
  `/tmp/com.gokuencinar.bandlockd.sock`
  with `0600` permissions.
- Added `SO_NOSIGPIPE` and client-side timeouts so a daemon failure does not terminate the graphical app.
- CoreTelephony, CommCenter, and Field Test operations remain isolated inside the privileged process rather than `BandLock.app`.

### Installation & Recovery
- `postinst` unloads any previous service instance, removes stale sockets, registers the LaunchDaemon, and performs a `kickstart`.
- `postrm` unloads the service and removes the socket.
- `BandLockDaemon` runs as `mobile`, while `launchd` is responsible for restarting it after unexpected termination.

### Validation
- GitHub Actions builds and signs the app and daemon separately for RootHide.
- CI verifies that CommCenter entitlements are absent from the main app and present only in `BandLockDaemon`.
- The final `.deb` was inspected to confirm:
  - `BandLock.app`
  - `usr/libexec/BandLockDaemon`
  - LaunchDaemon plist
  - Executable maintenance scripts

---

## 0.6.2 — Global App

### Changed
- Private **CoreTelephony**, **CommCenter**, and **Field Test** calls no longer run inside the BandLock UIKit process.
- Added `BandLockHelper`, a standalone executable bundled inside `BandLock.app`.
- The main app uses `posix_spawn` and JSON to communicate with the helper.
- If the helper fails, receives a signal, or returns invalid data, the UI can report the error instead of terminating.
- CommCenter entitlements are now restricted to the helper; the main app binary no longer contains them.
- **Edit Bands** no longer triggers an implicit modem read when no snapshot is available.
- **Prepare Compatible Bands** no longer performs automatic CoreTelephony calls from the Countries screen; the user must explicitly refresh status from Control.
- Pending selections and country profiles remain local until the user taps **Apply**.

### Validation
- GitHub Actions builds `BandLock` and `BandLockHelper` separately for RootHide.
- CI verifies with `ldid -e` that the main app does **not** contain `com.apple.CommCenter.fine-grained`, while the helper contains:
  - `spi`
  - `preferences-write`
  - `com.apple.CoreTelephony.CommCenterHelper.allow`
- The final `.deb` contains both executables with `0755` permissions, plus executable `postinst` and `postrm` scripts.

---

## 0.6.1 — Global App

### Fixed
- **Refresh Status** now includes the required private CoreTelephony entitlements to prevent `NSPOSIXErrorDomain Code=13 (Permission denied)` from the standalone app.
- Added relevant `com.apple.CommCenter.fine-grained` permissions:
  - `spi`
  - `identity`
  - `phone`
  - `carrier-settings`
  - `preferences-write`
  - `developer-settings`
- Added access to `CommCenterHelper`.
- Pending selections are no longer written directly to `/var/mobile/Library/Preferences`.
- Persistent app state now uses `NSUserDefaults`.
- Modem capabilities remain in memory only and are re-read on every launch.
- **Edit Bands** no longer uses the shared persistence/notification path that could crash when toggling bands.
- **Prepare Compatible Bands** no longer uses that path either and now includes Objective-C exception protection.
- The manual selector now validates the row index before mutating the selection.
- Recoverable preparation/selection exceptions are now displayed as alerts instead of terminating the app.

### Validation
- GitHub Actions successfully builds the RootHide 0.6.1 app.
- CI verifies with `ldid -e` that the signed binary contains `com.apple.CommCenter.fine-grained` and the `spi` value.
- The generated package contains only `BandLock.app`, its resources, and install/uninstall scripts. The old Settings PreferenceBundle is no longer reinstalled.

---

## 0.6.0 — Global App

### Added
- BandLock moved from a Settings PreferenceBundle to a **standalone UIKit application** available from the Home Screen.
- Added two main tabs:
  - **Control**
  - **Countries**
- Added an offline catalogue of **160 countries and territories**. The initial snapshot includes LTE reference bands for 156 of them.
- Added country search and localized country names based on the iPhone language/region.
- Added a country detail view with:
  - LTE bands
  - Frequency
  - FDD/TDD/SDL classification
  - Compatibility indicator for the current iPhone modem
- Added **Prepare Compatible Bands**, which computes:
  `country bands ∩ iPhone-supported bands`
- Added a custom BandLock SpringBoard icon.
- Added `uicache` install/uninstall scripts so the app is registered correctly.

### Safety & Behavior
- Choosing a country **never applies changes automatically**; it only prepares a pending selection.
- Before any write, BandLock re-queries `supportedBands` and cancels the operation if modem compatibility has changed.
- Empty selections and SDL-only selections are rejected.
- Previous-selection storage, read-back verification, and the single CommCenter retry remain in place.
- Opening BandLock does not modify the modem.

### Changed
- The Debian package remains `com.gokuencinar.bandlock`, so 0.6.0 upgrades the public 0.5.x line.
- The standalone application bundle identifier is:
  `com.gokuencinar.bandlock.app`
- Removed the public PreferenceLoader dependency.
- The Settings PreferenceBundle is no longer installed.
- CoreTelephony logic is now separated from the UI in a common manager shared by Control and Countries.

### Country Data
- The initial country snapshot was generated from LTE deployment data available on **2026-09-26**.
- Country band data is **informational**: real deployments vary by carrier, location, roaming conditions, and date.
- The modem remains the source of truth for which bands the device can actually select.

---

## 0.5.0 — Global

### Added
- First public global release.
- The selector now uses every LTE band reported by `CTBandInfo.supportedBands` for the device modem, without a Spain-only allow-list.
- Added frequency metadata and FDD/TDD/SDL classification for known LTE bands.
- Added dynamic grouping for FDD, TDD, SDL, and other LTE bands reported by the modem.
- Added quick actions for:
  - Current active selection
  - All supported bands
  - FDD only
  - TDD only
- Introduced the independent public package identity:
  `com.gokuencinar.bandlock`
- Added dedicated PreferenceBundle, state storage, and log paths separate from the private Spain-focused edition.

### Changed
- Removed the Spain-specific public presets:
  - Orange Spain
  - All Spain Bands
  - Spain Coverage
  - B3 + B7
- The selector no longer filters to B28/B20/B8/B3/B1/B7/B38.
- The modem is now the source of truth for determining which LTE bands can be selected.
- Retained the delayed verification and single CommCenter retry introduced in 0.4.4.

### Notes
- A modem reporting support for a band does not guarantee that the current carrier deploys that band at the current location.
- Version 0.5.0 controls LTE/4G only and does not claim 5G NR band-locking support.
- Public development moved to the **0.5.0 Global** line. The Spain-focused 0.4.4 build remains a private author edition.

---

## 0.4.4

### Added
- Delayed verification after LTE band changes.
- One automatic retry when CommCenter still reports the previous configuration after a write.

### Changed
- Applying an LTE selection now waits approximately 0.8 seconds before verifying the result.
- If the first read does not match, BandLock writes the selection again and verifies once more after approximately 1 second.
- Verification now uses the modem's full LTE band set instead of only bands visible in the Spain filter.
- **Restore Automatic Mode** can now correctly verify bands hidden by the Spain-focused selector.
- The pending selection is preserved when the first write does not settle immediately.

### Fixed
- Fixed cases where **Apply LTE Selection** had to be tapped twice.
- Fixed cases where **Restore Automatic Mode** had to be tapped twice.
- Manual selections are no longer immediately replaced by stale modem state.

---

## 0.4.3

### Added
- Direct radio access mode controls:
  - **Automatic**
  - **LTE / 4G Only**
- Added a ✓ indicator to the active RAT mode.

### Changed
- Removed the generic Preferences selector introduced in 0.4.2.
- RAT changes are now triggered directly from native buttons.
- **LTE / 4G Only** still requires confirmation before modifying modem configuration.

### Fixed
- Fixed the Preferences crash when opening **Preferred Technology** in 0.4.2.

---

## 0.4.2

### Added
- First attempt at turning **Preferred Technology** into a navigable list with:
  - Automatic
  - LTE / 4G Only

### Changed
- The UI moved from the non-interactive `PSListItemCell` used in 0.4.1 to a selector based on `PSLinkListCell` / `PSListItemsController`.

### Notes
- On iOS 16.3 / RootHide this implementation was unstable and crashed when opening the selector. It was replaced entirely in 0.4.3.

---

## 0.4.1

### Added
- Added RAT control alongside LTE band locking.
- Added **Automatic** mode.
- Added **LTE / 4G Only** mode.
- Added RAT configuration reads through `getRatSelection:completion:`.
- Added RAT writes through `setRatSelection:selection:preferred:completion:`.
- Added `RAT-Selection` and `RAT-Preferred` to logs.

### Changed
- BandLock can now prevent fallback to 3G/EDGE when **LTE / 4G Only** is requested.
- After changing RAT mode, BandLock re-queries CoreTelephony to display the state actually reported by the system.

### Notes
- The first selector UI displayed the current value but did not correctly open a selection screen. Interaction was revised in 0.4.2 and fully fixed in 0.4.3.

---

## 0.4.0

### Added
- Added a dedicated **Select Bands** screen.
- Added a selector focused on LTE bands commonly used in Spain and supported by the device:
  - B28 · 700 MHz
  - B20 · 800 MHz
  - B8 · 900 MHz
  - B3 · 1800 MHz
  - B1 · 2100 MHz
  - B7 · 2600 MHz FDD
  - B38 · 2600 MHz TDD
- Added visual grouping for:
  - Coverage
  - General Use
  - Capacity
- Added quick profiles:
  - Orange Spain
  - All Spain Bands
  - Coverage
  - B3 + B7
- Added persistence for the pending selection when returning to the main screen.

### Changed
- Major UI redesign.
- Simplified the main screen to focus on status and actions.
- Manual band selection was moved out of the main panel.
- **Restore Automatic Mode** retains the ability to re-enable every LTE band supported by the modem, including bands hidden by the Spain-focused filter.

---

## 0.3.9

### Added
- Spain- and Orange-focused UI.
- Added a BandLock visual header.
- Added separate sections for status, profiles, bands, and actions.
- Added presets:
  - Orange Spain
  - Coverage
  - Capacity
  - B3 + B7
- Added access to `FTMInternal-4`.

### Changed
- The UI stopped showing most international or non-priority bands for Spain.
- Prioritized B28/B20/B8/B3/B1/B7.
- The Field Test button stopped attempting to open `com.apple.fieldtest` and now launches `com.apple.FTMInternal`.
- Field Test launch attempts FrontBoardServices first and falls back to LaunchServices.

---

## 0.3.8

### Added
- Added nominal frequency next to each LTE band name.
- Added the initial **Orange Spain** preset.
- Added **Select All** and **Deselect All** buttons.
- Added previous LTE selection storage.
- Added **Restore Previous Selection**.
- Added the first attempt at showing the serving-cell band through CoreTelephony.
- Added the first Field Test Mode button.

### Changed
- The UI now distinguishes more clearly between supported bands, allowed bands, and the serving band.
- Logs continue to exclude sensitive SIM/subscription context data.

### Notes
- The first Field Test launcher used `com.apple.fieldtest`; this was corrected to `com.apple.FTMInternal` in 0.3.9.

---

## 0.3.7

### Added
- First BandLock release capable of **writing** the allowed LTE band set.
- Added switches generated from LTE bands supported by the modem.
- Added writes through `setActiveBandInfo:bands:error:`.
- Added post-write verification through a new `getBandInfo:error:` read.
- Added **Restore All LTE Bands**.
- Added confirmation before applying a selection.
- Added rejection of empty LTE selections.

### Changed
- Only `kCTRegistrationRadioAccessTechnologyLTE` is modified.
- GSM, UTRAN, TDSCDMA, and other RATs remain unchanged.
- Logs no longer store the full subscription-context description.

### Validation
- Confirmed a real write and read-back of configurations such as **B3 + B7**.

---

## 0.3.6

### Added
- Added logging under:
  `/var/mobile/Library/Logs/BandLock/`
- Added `BandLock-last.txt` for easier SSH diagnostics.
- Added **Delete All Logs** with confirmation.
- Added logging of CoreTelephony query results.

### Changed
- Operation remained completely read-only.
- Log deletion is restricted to the BandLock log directory.

### Safety
- This version does not call modem band setters.

---

## 0.3.5

### Added
- First functional read-only cellular band inspector.
- Added manual CoreTelephony queries.
- Added supported and active band reads through `getBandInfo:error:`.

### Changed
- BandLock moved from a controller/UI prototype to querying real modem information.
- Queries only run after explicit user action.

### Safety
- No band writes are performed.

---

## 0.3.4

### Added
- First BandLock version retained in the public APT repository.
- Added a direct, stable RootHide PreferenceBundle.
- Added a functional Preferences controller inside Settings.
- Established the UI foundation used by later releases.

### Changed
- Abandoned the secondary/lazy loading architecture used in earlier prototypes because it had caused instability.

---

## Design Principles

The following principles are maintained across the current BandLock design:

- No SpringBoard injection.
- No automatic LTE-band writes at launch.
- Radio configuration changes always require explicit user action.
- Modem read-back is used to distinguish a requested change from a change that was actually applied.
- Privileged radio operations are isolated from the main UI process in current releases.
