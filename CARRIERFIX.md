# CarrierFix

CarrierFix is an experimental Cricket Wireless / AT&T aio SMS/IMS repair utility for **jailbroken iOS 16 and iOS 17**.

## Supported packages

- **Dopamine/rootless (final test package):** iOS 16.x.
- **RootHide (device-validation package):** iOS 16.x, used to validate the same shared repair core on the developer test device.
- **Dopamine 3/rootless (iOS 17 validation package):** iOS 17.x. This package uses a separate package ID and app bundle so the iOS 17 experiment does not replace the iOS 16 package identity while the carrier schema is validated on a real Cricket line.

All packages compile the exact same `CFCarrierManager` and UI from `build/CarrierFix-shared`.

## iOS 16/17 carrier discovery

CarrierFix does not assume `/private/var/mobile/Library/Preferences/com.apple.carrier.plist` exists. It enumerates the real Carrier Bundles preference links. The iOS 17 build also discovers additional `com.apple.carrier_*` / `com.apple.operator_*` entries used by extra SIM/eSIM lines while the iOS 16 discovery order stays unchanged:

- `/private/var/mobile/Library/Carrier Bundles/Library/Preferences/com.apple.carrier_1.plist`
- `com.apple.carrier_2.plist` / operator equivalents when present
- additional numbered carrier/operator preference links when present
- `/rootfs/var/mobile/...` equivalents under RootHide

It resolves the symlink to the actual writable file in `Carrier Bundles/Overlay`, prefers a Cricket profile if one is present, and otherwise uses the first non-default readable carrier for diagnostics.

## APN compatibility

CarrierFix accepts both the flat `apns` arrays seen on iOS 16 and grouped `configuration` arrays. It requires an existing `ims` APN and will never synthesize IMS from scratch on an unknown profile. On iOS 17, Apply is enabled only for the grouped ATT_aio IMS shape observed in the Cricket 31.1 and 58.1 carrier families; other layouts stay diagnostic-only.

## Safety

Before Apply is enabled CarrierFix:

- verifies Cricket / ATT_aio metadata;
- verifies the carrier overlay is writable;
- verifies an existing IMS + APN schema it understands;
- saves a per-overlay byte-for-byte backup;
- performs a restore-file preflight;
- isolates iOS 17 backups from iOS 16 backups;
- refuses to restore a backup to a different overlay path or iOS major version;
- refuses a stale restore if the active overlay changed after CarrierFix created its patched snapshot.

Apply modifies only SMS/IMS compatibility keys. The iOS 16 path retains its existing IMS APN normalization; the iOS 17 path leaves APN fields untouched and only validates that an IMS APN already exists. Every write is read back byte-for-byte and then semantically validated. If verification fails, CarrierFix verifies whether the original backup was successfully restored and reports a rollback failure explicitly.

CarrierFix installs no MobileSubstrate hook or LaunchDaemon, does not modify `/System/Library/Carrier Bundles`, and does not run `killall`, `ldrestart`, `sbreload` or an automatic reboot.

CarrierFix does **not** backport RCS. Its target is normal SMS/IMS operation on Cricket. On iOS 17, messages to Android are still SMS/MMS rather than iPhone RCS.

Version 0.3.0 remains the iOS 16 private validation build. The isolated iOS 17 validation package is `0.4.0~ios17test4` and should remain a test build until its diagnostics and Apply/Restore flow are verified on a real Cricket line exhibiting the SMS problem. Test 2 added explicit Refresh feedback and file/folder permissions. Test 3 introduced an **export-only** Cricket carrier update preparation button to the iOS 17 app. Test 4 adds share-time hash checks, protected staging in cache, and discards snapshots after aborted preparation. iOS 16 is unchanged.

## Official Cricket carrier update preparation (test4)

- On the known Cricket iPhone 15 Pro Max (`iPhone16,2`) with iOS 17.x, **Prepare official Cricket update** creates a private, read-back-verified snapshot of the active Cricket overlay and downloads Apple's original `ATT_aio_US_iPhone.ipcc` version 58.1 over HTTPS.
- It verifies the downloaded package against the pinned SHA-384 `55CED9623258B24B76670A5CA19CB5F53D4B23F7B7389E1257AAD8BED5BA981CB1241342B6740945F675FBB7BD0B29B5` before storing it. A failed check leaves the active carrier unchanged.
- Separate share actions export the unmodified Apple `.ipcc` or the user's original reference snapshot. Both are **re-verified at export time** against the original pinned/in-memory SHA-384. The original snapshot may contain private operator configuration: **save it privately**, not in chats or public issue reports. Snapshots are held in the mobile user's protected cache (0700 folder, 0600 files and iOS complete file protection); a jailbreak process with the same UID may still access them, and the OS may purge cache contents. The snapshot is deliberately called a *reference*, not a proven restorable backup. A factory/system restore of the overlay is not provided.
- The app **does not install** the `.ipcc`, change the active overlay, invoke private baseband APIs, change SIM/eSIM state, bypass Apple's carrier update eligibility, or initiate an iOS update.
- Apple's current OTA catalog lists Cricket 58.1 for **iOS 17.5 or newer**; the reported user is on iOS 17.1. That compatibility gate is explicitly shown in the UI. Do **not** use an unsupported carrier version or try to force-load it simply because the file was exported. The official Apple iOS-carrier version compatibility decision must be respected.
- On a compatible iOS version, updates can be offered via **Settings → General → About**; an independently verified Apple-supported desktop carrier-update flow may be possible when the installed Apple device software accepts the official IPCC. CarrierFix cannot promise or perform that external installation.

Read `build/CarrierFix-0.4-iOS17-Dopamine/CRICKET-56-TO-58-SAFETY.md` for the compatibility report, remaining data needed from the user's phone, and restore precautions.
