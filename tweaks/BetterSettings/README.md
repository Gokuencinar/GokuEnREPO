# Better Settings

Better Settings organizes installed tweaks in iOS Settings, with a modified PreferenceLoader dependency.

## Packages

All packages are stored together in [`debs/`](debs/), following the repository's standard layout:

- Dopamine rootless (`iphoneos-arm64`): `com.gokuencinar.bettersettings_1.0.0_iphoneos-arm64.deb` and `preferenceloader_2.3.3+zbetter1_iphoneos-arm64.deb`.
- Experimental RootHide 3 (`iphoneos-arm64e`), built with `roothide/theos`:

- `com.gokuencinar.bettersettings_1.0.0_iphoneos-arm64e.deb`
- `preferenceloader_2.3.3+zbetter1_iphoneos-arm64e.deb`

The architecture `iphoneos-arm64e` is the RootHide Debian package scheme; the build uses both arm64 and arm64e code slices. The original Dopamine rootless packages are retained in the same `debs` directory.

CI verification: https://github.com/Gokuencinar/GokuEnREPO/actions/runs/40153982247

**Experimental:** Compilation and packaging passed, but physical operation on a RootHide 3 device is not yet verified. Do not install this on Dopamine rootless.
