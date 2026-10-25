# RootHidePatcher FIX

Fixes duplicate `LC_RPATH` entries created when RootHidePatcher 2.1.4 converts a package that already includes both `/var/jb/...` and `@loader_path/.jbroot/...` library paths.

The converter now removes repeated final paths separately in each Mach-O architecture before signing. It preserves the first occurrence, keeps the remaining search order and does not move code or data sections. Clean binaries are unchanged.

## Install

Install **RootHidePatcher FIX** from GokuEnREPO using Sileo or Zebra. Requires the RootHide bootstrap and RootHidePatcher 2.1.4 (`com.roothide.patcher`). No respring is needed. Open Patcher and convert the original rootless DEB normally.

The package changes the converter; it does not repair packages you converted previously. Reconvert those from their original DEBs. Existing installed tweaks and app data are not modified.

Only the recognized upstream script is patched. Unknown/custom scripts are preserved and installation stops. Supported Patcher updates activate a dpkg file trigger to reapply the fix; an unrecognized new script is left unchanged.

## Remove and inspect

Removing this package restores the original converter when its managed script is still installed. Backups remain in `/var/lib/roothidepatcherfix/`. Custom changes made after installation are preserved.

```sh
/bin/bash /usr/libexec/roothidepatcherfix/manage.sh status
```

## Validation

Development tests cover clean files, thin 32/64-bit Mach-O files, universal files with different paths in each architecture, byte order, malformed inputs, payload preservation and repeated application. Device evidence and the tested installation/removal cycle are recorded in [VALIDATION.md](VALIDATION.md).

The issue was reproduced using original Watusi 1.3.28 and Regram 6.5 packages. Their converted packages are not distributed here. Testing a converter output does not establish that every feature of every tweak is compatible with RootHide.

## Build and source

Run `bash build.sh` on a system with `dpkg-deb`. The package contains Bash/AWK scripts and does not require Theos or inject a dylib into other processes.

Upstream: [RootHidePatcher](https://github.com/roothide/RootHidePatcher). This is an independent compatibility fix by Gokuencinar, not an upstream RootHide release. The original application and its cctools are not redistributed. The new helpers are MIT licensed; the source patch is in `src/patch.diff`.
