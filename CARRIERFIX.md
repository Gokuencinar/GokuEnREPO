# CarrierFix

CarrierFix is an experimental carrier-overlay repair utility for jailbroken iOS. Version 0.2 targets Cricket Wireless / AT&T aio carrier bundles with separate RootHide, Dopamine/rootless and classic rootful packages.

## Compatibility

- **RootHide:** iOS 15.0-17.0.
- **Dopamine/rootless:** iOS 15.0-18.x where the jailbreak supports the device/firmware combination.
- **Rootful:** iOS 15.x-16.x.

The repair logic is identical in all three packages and is compiled from one shared source tree.

## What 0.2 does

- Resolves the active `/private/var/mobile/Library/Preferences/com.apple.carrier.plist` target.
- Detects Cricket using carrier name, ATT_aio path and Cricket status-bar metadata; it does not identify Cricket from a generic AT&T PLMN alone.
- Produces a privacy-safe diagnostic without phone number, IMSI or ICCID.
- Creates a per-carrier byte-for-byte backup and verifies a restore copy before enabling **Apply**.
- Refuses to restore if the active carrier overlay path changed, so a backup can never be written into another SIM/carrier profile.
- Archives an older baseline when iOS/the carrier replaces the overlay, then captures the new state before applying a new patch.
- Refuses unknown IMS/APN schemas instead of creating a complete IMS configuration from scratch.
- Patches only messaging/IMS compatibility keys based on current Cricket carrier bundles:
  - `SupportsImsCapability = true`
  - `IMSConfig/Signaling/ForcedFeatureTags = voice,sms`
  - `IMSConfig/SMS/SMSBundleToVoice = false`
  - `IMSConfig/SMS/allowCSFBInVolteMode = false`
  - `SMSSettings/TransportFallback = false`
  - requires an existing `ims` APN and preserves its layout, filling only missing protocol/switchover fields; if IMS is absent, Apply stays disabled
- Verifies the written overlay byte-for-byte and semantically before reporting success.
- Automatically restores the original if write/read-back/semantic verification fails.
- Restores the original carrier plist with one button.

CarrierFix does not attempt to backport RCS. Its goal is normal carrier SMS/IMS operation on older iOS versions.

## Safety

CarrierFix does not modify `/System/Library/Carrier Bundles`. It works only on the active writable carrier plist/overlay. No MobileSubstrate hook, launch daemon, automatic CommCenter kill, userspace reboot or respring is installed. After Apply or Restore, toggle Airplane Mode for around 30 seconds or reboot.

Version 0.2 is experimental and requires real Cricket device testing.
