# Validation — 1.0.0

Tested on 2026-10-25 with an iPhone 11 Pro, iOS 18.7.1 (22H31), experimental RootHide Dopamine 3.0.12 / RootHide 28 and RootHidePatcher 2.1.4-1+debug.

## Converter output

The corrected converter was run on separate copies of the original rootless Watusi 1.3.28 and Regram 6.5 DEBs, using Patcher's bundled cctools and AutoPatches mode. Both complete conversions finished with exit code 0.

An independent Python Mach-O parser checked all architecture slices of the generated payloads:

- Watusi: 6 Mach-O files, including its SpringBoard helpers, WSVendor, Control Center module and FLEX framework.
- Regram: 9 Mach-O files, including its bundled FFmpeg frameworks.
- Final RPATH lists equal the first-occurrence-preserving deduplication of the rewritten original lists.
- No duplicate final LC_RPATH entries remain.
- Actual load dependencies no longer use `/var/jb/` paths. Existing install-name/string warnings emitted by upstream Patcher are not suppressed by this fix.
- Every CodeDirectory code-page hash in every converted payload signature was verified.
- Each Mach-O copy under pkgmirror remains byte-identical to its original input.

The per-file results, signature page counts and converted DEB hashes are in [converted-validation.json](converted-validation.json). The paid tweak binaries and DEBs used as fixtures are not distributed here.

## Installer and removal on the physical device

1. Installed `com.gokuencinar.roothidepatcherfix` 1.0.0 through dpkg; its status became `install ok installed` and the helper reported `active`.
2. Verified the patched converter SHA256 against `src/manifest` and the original backup against the known upstream SHA256.
3. Removed the package; the upstream converter checksum was restored exactly and the managed helper link disappeared.
4. Reinstalled the same DEB; the fix returned to `active`.
5. Activated the declared dpkg file trigger and processed it; the fix reapplied successfully and remained `active`.

The original application's executable, package version and cctools were not replaced. No respring was required. Existing Watusi/Regram installations and their app data were not reinstalled as part of these converter tests.

## Regression tests

`tests/test_rpaths.py` covers thin 32/64-bit Mach-O, both byte orders, universal files with different paths in their architecture slices, FAT64, first-occurrence order, payload preservation, repeated application, clean inputs and malformed files. The input is never modified directly; failed parses do not emit partial output.

During development, the AWK results on real fixture binaries were also compared byte for byte with independent C and Python implementations. An initial standalone native helper was rejected by the device's code-signing checks and discarded; it is not included in this package. The released implementation uses the bootstrap's existing binary-safe AWK.

This verifies the converter fix, package lifecycle and tested output files. It is not a claim that every converted tweak or every feature of Watusi/Regram is compatible with all RootHide jailbreaks.

## Published artifact

```text
com.gokuencinar.roothidepatcherfix_1.0.0_iphoneos-arm64e.deb
SHA256 dc2c33f73c6cebf3d5b51e47540d7709c85aa9b75f3104258d86b943e6ca08b6
```
