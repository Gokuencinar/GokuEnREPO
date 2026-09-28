# CarrierFix

CarrierFix is an experimental carrier-overlay repair utility for jailbroken iOS. Version 0.2 targets Cricket Wireless / AT&T aio carrier bundles on RootHide iOS 15-17.

## What 0.1 does

- Resolves the active `/private/var/mobile/Library/Preferences/com.apple.carrier.plist` target.
- Detects Cricket using carrier name, ATT_aio path, status-bar metadata and supported SIM metadata.
- Produces a privacy-safe diagnostic without phone number, IMSI or ICCID.
- Makes a persistent byte-for-byte backup before the first change.
- Patches only messaging/IMS compatibility keys based on current Cricket carrier bundles:
  - `SupportsImsCapability = true`
  - `IMSConfig/Signaling/ForcedFeatureTags = voice,sms`
  - `IMSConfig/SMS/SMSBundleToVoice = false`
  - `IMSConfig/SMS/allowCSFBInVolteMode = false`
  - `SMSSettings/TransportFallback = false`
  - verifies/adds the `ims` APN with IMS service masks
- Verifies the written overlay before reporting success.
- Restores the original carrier plist with one button.

CarrierFix does not attempt to backport RCS. Its goal is normal carrier SMS/IMS operation on older iOS versions.

## Safety

CarrierFix does not modify `/System/Library/Carrier Bundles`. It works only on the active writable carrier plist/overlay. No automatic CommCenter kill, userspace reboot or respring is performed. After Apply or Restore, toggle Airplane Mode for around 30 seconds or reboot.

Version 0.2 is experimental and requires real Cricket device testing.
