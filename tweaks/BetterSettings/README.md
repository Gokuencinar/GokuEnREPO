# Better Settings

Better Settings organizes installed tweaks in iOS Settings, with a modified PreferenceLoader dependency.

## 1.0.1 / PreferenceLoader 2.3.3+zbetter2

- Show the Better Settings icon beside its entry in the **Tweaks** list. The custom PreferenceLoader now resolves and displays the icons provided by grouped tweak entries.
- Show the GokuEnREPO credits avatar on the **ⓘ Information** screen, beside the existing Better Settings logo and author credits.
- Better Settings requires the updated PreferenceLoader automatically when installed or upgraded through Sileo.

## Packages

All packages are stored together in [`debs/`](debs/), following the repository's standard layout:

- Dopamine rootless (`iphoneos-arm64`): `com.gokuencinar.bettersettings_1.0.1_iphoneos-arm64.deb` and `preferenceloader_2.3.3+zbetter2_iphoneos-arm64.deb`.
- Experimental RootHide 3 (`iphoneos-arm64e`), built with `roothide/theos`:
  - `com.gokuencinar.bettersettings_1.0.1_iphoneos-arm64e.deb`
  - `preferenceloader_2.3.3+zbetter2_iphoneos-arm64e.deb`

The architecture `iphoneos-arm64e` is the RootHide Debian package scheme; the build uses both arm64 and arm64e code slices. The original Dopamine rootless packages are retained in the same `debs` directory.

Earlier RootHide build verification: https://github.com/Gokuencinar/GokuEnREPO/actions/runs/40153982247

**Experimental:** Compilation and packaging passed, but physical operation on a RootHide 3 device is not yet verified. Do not install this on Dopamine rootless.
