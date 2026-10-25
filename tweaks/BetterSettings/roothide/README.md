# Better Settings (RootHide)

Experimental RootHide 3 variants of Better Settings and its modified PreferenceLoader, built using `roothide/theos`.

- `com.gokuencinar.bettersettings_1.0.0_iphoneos-arm64e.deb`
- `preferenceloader_2.3.3+zbetter1_iphoneos-arm64e.deb`

The architecture `iphoneos-arm64e` is the RootHide Debian package scheme; the build uses both arm64 and arm64e code slices. The `iphoneos-arm64` packages in the sibling `debs` directory are the original Dopamine rootless variants and are not replaced.

CI verification: https://github.com/Gokuencinar/GokuEnREPO/actions/runs/40153982247

**Experimental:** Compilation and packaging passed, but physical operation on a RootHide 3 device is not yet verified. Do not install this on Dopamine rootless.
