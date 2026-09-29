# BetterWiFi RH

BetterWiFi RH adds extra Wi-Fi information and tools directly to the Wi-Fi section in iOS Settings.

## Features

- Extended information for the connected network
- Live signal monitor
- Signal history graph
- 2.4 GHz and 5 GHz channel analyzer
- Classic and advanced network filters
- Wi-Fi diagnostic tools
- Shuffle / PreferenceLoader integration
- English and Spanish interface
- No dedicated background daemon

## Compatibility

Version **1.0** is available in three builds:

- **RootHide:** iOS 16.x — `iphoneos-arm64e`
- **Dopamine rootless:** iOS 15–18 — `iphoneos-arm64`
- **Rootful:** iOS 15–17 — `iphoneos-arm`

Package IDs are split by jailbreak environment so Sileo cannot confuse RootHide, Dopamine and rootful builds. The legacy package ID is no longer published in the APT index; users coming from 0.3.14/0.3.15 should install the matching variant once, and Sileo will remove the legacy package through Conflicts/Replaces metadata. Compatibility outside the setups I have personally tested may vary, so feedback is welcome.

## Install

Add GokuEnREPO to your package manager:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Then search for **BetterWiFi RH**.

[Changelog](CHANGELOG.md) · [Buy Me a Coffee](https://buymeacoffee.com/GokuEn)
