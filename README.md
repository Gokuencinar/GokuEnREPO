# GokuEnREPO

Public APT repository for **iOS 16 jailbreak tweaks**, focused on **Dopamine** and **RootHide**.

## 📲 Add GokuEnREPO

Repository URL:

`https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/`

<table>
<tr>
<td align="center" width="25%">
<a href="https://gokuencinar.github.io/GokuEnREPO/add/sileo.html"><img src="https://getsileo.app/img/icon.png" width="56" height="56" alt="Sileo"></a><br>
<strong><a href="https://gokuencinar.github.io/GokuEnREPO/add/sileo.html">Add to Sileo</a></strong>
</td>
<td align="center" width="25%">
<a href="https://gokuencinar.github.io/GokuEnREPO/add/cydia.html"><img src="assets/package-managers/cydia.svg" width="56" height="56" alt="Cydia"></a><br>
<strong><a href="https://gokuencinar.github.io/GokuEnREPO/add/cydia.html">Add to Cydia</a></strong>
</td>
<td align="center" width="25%">
<a href="https://gokuencinar.github.io/GokuEnREPO/add/zebra.html"><img src="https://getzbra.com/assets/zeeb.svg" width="56" height="56" alt="Zebra"></a><br>
<strong><a href="https://gokuencinar.github.io/GokuEnREPO/add/zebra.html">Add to Zebra</a></strong>
</td>
<td align="center" width="25%">
<a href="https://gokuencinar.github.io/GokuEnREPO/add/installer.html"><img src="assets/package-managers/installer.svg" width="56" height="56" alt="Installer 5"></a><br>
<strong><a href="https://gokuencinar.github.io/GokuEnREPO/add/installer.html">Add to Installer 5</a></strong>
</td>
</tr>
</table>

> If your browser does not open the package manager automatically, copy the repository URL above and add it manually as a source.

## 📦 Available tweaks

### 📡 BandLock Global — LTE/4G + 5G NR Band Control

Standalone jailbreak app for manually controlling LTE/4G and supported 5G NR modem selections on iOS 16. It includes network modes, independent LTE/NR pending selections, Field Test access and an offline catalogue covering 160 countries and territories.

- **RootHide build:** `com.gokuencinar.bandlock` — `iphoneos-arm64e`
- **Dopamine rootless build:** `com.gokuencinar.bandlock.dopamine` — `iphoneos-arm64`
- **Rootful build:** `com.gokuencinar.bandlock.rootful` — `iphoneos-arm`
- Country profiles never modify the modem automatically; compatible bands are prepared for review before applying.
- Languages: English, Spanish, French, German, Traditional Chinese, Simplified Chinese/Mandarin and Japanese.

➡️ **[BandLock details](tweaks/BandLock/README.md)** · **[Changelog](tweaks/BandLock/CHANGELOG.md)**

### 📶 BetterWiFi RH — Wi-Fi Tools

RootHide-compatible Wi-Fi enhancement tweak that expands the information and diagnostic tools available in iOS Settings.

- Extended information about the connected Wi-Fi network.
- Live signal monitor and signal history.
- 2.4 GHz / 5 GHz channel analyzer.
- Network filters and diagnostic tools.
- Shuffle / PreferenceLoader integration.
- Manual language selector: Automatic, Spanish or English.
- No dedicated resident daemon.

➡️ **[BetterWiFi RH details](tweaks/BetterWiFi-RH/README.md)** · **[Changelog](tweaks/BetterWiFi-RH/CHANGELOG.md)**

### Nuke Wireless — In Development

Nuke Wireless is currently in development. Public package releases are unavailable.

➡️ **[Nuke Wireless details](tweaks/Nuke-Wireless/README.md)**

## Repository layout

Project-specific files live under [`tweaks/`](tweaks/):

- `tweaks/BandLock/` — source snapshots, packages, diagnostics, documentation and depiction.
- `tweaks/BetterWiFi-RH/` — package, documentation and depiction.
- `tweaks/Nuke-Wireless/` — documentation and depiction while the project is in development.

The APT entry points (`Release`, `Packages`, `Packages.gz` and repository icons) intentionally stay at the repository root so existing package-manager source URLs keep working unchanged.

## Current packages

| Package | Version | Architecture |
| --- | --- | --- |
| BandLock (RootHide) | 1.4 | `iphoneos-arm64e` |
| BandLock (Dopamine) | 1.4 | `iphoneos-arm64` |
| BandLock (Rootful) | 1.4 | `iphoneos-arm` |
| BetterWiFi RH | 0.3.11 | `iphoneos-arm64e` |

The `Packages` and `Packages.gz` indexes are automatically regenerated when a package inside `tweaks/*/debs/` changes.

## Compatibility

**iOS 16.x · RootHide · Dopamine rootless · Rootful · Sileo / Cydia / Zebra / Installer 5**

## ❤️ Support development

If you enjoy my tweaks and would like to support their continued development, bug fixes and future projects:

☕ **[Buy Me a Coffee](https://buymeacoffee.com/GokuEn)**

Any support is greatly appreciated. Thank you! ❤️

---

**Developer:** Gokuencinar · GokuEn
