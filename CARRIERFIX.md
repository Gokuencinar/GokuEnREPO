# CarrierFix

CarrierFix is an experimental Cricket Wireless / AT&T aio SMS/IMS repair utility for **jailbroken iOS 16**.

## Supported packages

- **Dopamine/rootless (final test package):** iOS 16.x.
- **RootHide (device-validation package):** iOS 16.x, used to validate the same shared repair core on the developer test device.

Both packages compile the exact same `CFCarrierManager` and UI from `build/CarrierFix-shared`.

## iOS 16 carrier discovery

CarrierFix does not assume `/private/var/mobile/Library/Preferences/com.apple.carrier.plist` exists. On iOS 16 it enumerates the real Carrier Bundles preference links:

- `/private/var/mobile/Library/Carrier Bundles/Library/Preferences/com.apple.carrier_1.plist`
- `com.apple.carrier_2.plist` / operator equivalents when present
- `/rootfs/var/mobile/...` equivalents under RootHide

It resolves the symlink to the actual writable file in `Carrier Bundles/Overlay`, prefers a Cricket profile if one is present, and otherwise uses the first non-default readable carrier for diagnostics.

## APN compatibility

CarrierFix accepts both iOS 16 flat `apns` arrays and newer grouped `configuration` arrays. It requires an existing `ims` APN and will never synthesize IMS from scratch on an unknown profile.

## Safety

Before Apply is enabled CarrierFix:

- verifies Cricket / ATT_aio metadata;
- verifies the carrier overlay is writable;
- verifies an existing IMS + APN schema it understands;
- saves a per-overlay byte-for-byte backup;
- performs a restore-file preflight;
- refuses to restore a backup to a different overlay path.

Apply modifies only SMS/IMS compatibility keys and the existing IMS APN. Every write is read back byte-for-byte and then semantically validated. If verification fails, CarrierFix restores the original automatically.

CarrierFix installs no MobileSubstrate hook or LaunchDaemon, does not modify `/System/Library/Carrier Bundles`, and does not run `killall`, `ldrestart`, `sbreload` or an automatic reboot.

CarrierFix does **not** backport RCS. Its target is normal SMS/IMS operation on Cricket on iOS 16.

Version 0.3.0 remains private until it is tested on a real Cricket line exhibiting the SMS problem.