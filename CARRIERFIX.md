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

Version 0.3.0 remains the iOS 16 private validation build. The isolated iOS 17 validation package is `0.4.0~ios17test1` and should remain a test build until its diagnostics and Apply/Restore flow are verified on a real Cricket line exhibiting the SMS problem.
