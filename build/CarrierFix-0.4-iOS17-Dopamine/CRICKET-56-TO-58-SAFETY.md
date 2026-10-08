# Cricket 56.0 -> 58.1 compatibility review (iOS 17.1)

**Status: blocked; no carrier update or device-side patch approved.**

Reported target: iPhone 15 Pro Max (`iPhone16,2`), iOS 17.1, eSIM Cricket
56.0, MCC/MNC 310150. Incoming SMS works. Some outgoing plain SMS messages
appear sent, but never reach AT&T, TextNow and TextFree destinations.

## Source investigated

- Official Apple-signed `ATT_aio_US_iPhone.ipcc`, build **58.1**, published
  2024-05-13, Apple OTA release gate **iOS 17.5 or later**.
- Source URL: https://updates.cdn-apple.com/20240513/carrierbundles/032-23478/E247835C-8950-4A31-A430-A6DB27A40158/ATT_aio_US_iPhone.ipcc
- Apple SHA-384 (verified against downloaded ZIP on 2026-10-08):
  `55CED9623258B24B76670A5CA19CB5F53D4B23F7B7389E1257AAD8BED5BA981CB1241342B6740945F675FBB7BD0B29B5`.
- Target bundle directory: `Payload/ATT_aio_US.bundle/`. Includes
  signatures, `carrier.plist`, and the `overrides_D83_D84_D37_D38`
  plist/modem configuration used for the iPhone 15 family.
- Read-only verification from PowerShell:
  `powershell -NoProfile -ExecutionPolicy Bypass -File ./Inspect-Cricket58.1.ps1 -IOSVersion 17.1 -DeviceModel iPhone16,2`.
  The script downloads and verifies the original, checks required ZIP entries,
  then deletes its own temporary download. It **does not** touch a phone.

## SMS/IMS comparison available from the existing diagnostic

| Setting | Active Cricket 56.0 overlay | Apple Cricket 58.1 |
| --- | --- | --- |
| `SupportsImsCapability` | YES | enabled |
| `IMSConfig.Signaling.ForcedFeatureTags` | `voice,sms` | `voice,sms` |
| `SMSSettings.TransportFallback` | `0` | false |
| `IMSConfig.SMS.SMSBundleToVoice` | `0` | false |
| `IMSConfig.SMS.allowCSFBInVolteMode` | `0` | false |
| `IMSConfig.SMS.enableInNonVoLTEMode` | absent | false |

**Not a full diff:** the active iPhone's overlay was not exported, and its
other keys, default country settings, baseband policy and active IMS state
have not been examined. The absence of `enableInNonVoLTEMode` is not evidence
that setting it to false repairs intermittent outgoing SMS delivery.

## Safety gate before any future change

1. Obtain the *current exact* overlay and original carrier package from that
   device and compare against candidate bundle, including its device-specific
   modem override, on a **read-only** basis. Protect private identifiers.
2. Verify Apple signature/original checksum, device match, and the actual
   iOS compatibility rule. **58.1 fails the iOS 17.1 gate.**
3. Obtain a device-safe backup and independently verified, feasible restore
   path before touching a carrier bundle; CarrierFix currently reports that
   the overlay **and its folder are not writable**, and no verified backup
   exists. Do not bypass this guard with `chmod`, direct filesystem copy, or
   a root helper.
4. Do not patch modem/`.der.pri`, force a carrier-version string, or load an
   unofficial/modified IPCC. If a signed, Apple-approved compatible update is
   offered via Finder/iTunes or Settings, prefer that system mechanism, and
   verify that installation will not trigger an iOS update.
5. Record at least two reproducible outgoing-SMS failures (timestamp,
   destination carrier/type, recipient confirms non-delivery) and ask Cricket
   to inspect message routing/provisioning before attributing causation to
   carrier bundle 56.0.

Further sources:

- https://carrierexplode.com/ios/carriers/ATT_aio_US/58.1
- https://carrierexplode.com/ios/carriers/ATT_aio_US/58.1/settings
- https://support.apple.com/en-us/109324

**Conclusion:** This research does not provide a safely installable carrier
upgrade for iOS 17.1. Keep the existing Cricket 56.0 profile untouched.
