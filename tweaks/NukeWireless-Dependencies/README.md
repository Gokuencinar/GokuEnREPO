# NukeWireless dependencies

Original, unmodified dependency packages mirrored from **Procursus** and **RootHide Procursus**. Their original package IDs, versions, authors, maintainers, dependencies and licenses are preserved. These are third-party tools, not tools authored by NukeWireless.

Add this APT source and refresh Sileo, Zebra or your package manager:

```
https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/
```

Install the NukeWireless DEB that matches your jailbreak. Its dependencies will be selected by the package manager. Do not install DEBs for a different scheme manually.

| Scheme | Debian architecture | Original upstream suite | Payload location |
| --- | --- | --- | --- |
| RootHide | `iphoneos-arm64e` | RootHide `iphoneos-arm64e/1900` | Relocated by RootHide |
| Dopamine / conventional rootless | `iphoneos-arm64` | Procursus `iphoneos-arm64-rootless/1800` | `/var/jb` |
| Rootful on arm64 iPhones | `iphoneos-arm` | Procursus `iphoneos-arm64/1800` | `/usr`, `/Library` |

The suite names and Debian architectures are upstream bootstrap conventions. They do not establish support for an iOS version, an arm64e executable ABI, or 32-bit devices. Hosting these packages does not validate NukeWireless on untested iPhones or jailbreaks.

## Mirrored packages

| Package | RootHide | Rootless | Rootful | Upstream project / license |
| --- | --- | --- | --- | --- |
| `arpoison` | 0.7 | 0.7 | 0.7 | [ARPoison](http://www.arpoison.net/) / GPL-2.0 |
| `ldid` | 2.1.5-procursus7 | 2.1.5-procursus7 | 2.1.5-procursus7 | [Procursus ldid](https://github.com/ProcursusTeam/ldid) / AGPL-3.0 |
| `network-cmds` | 641-1 | 669 | 669 | [Apple network_cmds](https://github.com/apple-oss-distributions/network_cmds) / per-file BSD and Apple notices |
| `libnet9` | 1.2 | 1.2 | 1.2 | [libnet](https://github.com/libnet/libnet) / BSD-2-Clause |
| `libplist3` | 2.2.0+git20230130.4b50a5a | same | same | [libplist](https://github.com/libimobiledevice/libplist) / LGPL-2.1 library; accompanying source contains GPL notices |
| `libssl3` | 3.0.8 | 3.2.1 | 3.2.1 | [OpenSSL](https://github.com/openssl/openssl) / Apache-2.0 and accompanying notices |
| `libpcapa` | 1.10.1-1 | 1.10.4 | 1.10.4 | [libpcap](https://github.com/the-tcpdump-group/libpcap) / BSD-3-Clause |

These are upstream binaries, not local rebuilds. Their versions differ between schemes because their upstream repositories differ. Existing newer versions from the bootstrap's official repository should remain preferred by APT.

## Bootstrap requirements

This mirror supplies the three tools and their four non-bootstrap libraries. A working, compatible jailbreak bootstrap must already provide:

- `firmware` (the real installed iOS version).
- `libiosexec1` **1.3.1 or newer** for these library/tool versions.
- `ca-certificates` for that bootstrap's own filesystem layout.
- RootHide only: `roothide` **0.0.6 or newer**.
- The injection framework and any compatibility packages required by NukeWireless itself, such as ElleKit / a `mobilesubstrate` provider and RootHide compatibility support.

Those components are deliberately not mirrored. In particular, upstream `ca-certificates` packages use architecture `all` despite having different filesystem layouts; publishing them together in one flat repository would let APT select the wrong scheme. If a bootstrap dependency is missing or outdated, repair/update it using the jailbreak's official repository before installing NukeWireless. This mirror does not make an arbitrary bootstrap compatible or remove those prerequisites.

## Provenance and source availability

- [binary-manifest.json](binary-manifest.json) records each original download URL, package metadata, SHA-256, size, and the upstream Release/index hashes checked during retrieval.
- [source-manifest.json](source-manifest.json) records hashes and URLs for the matching project versions, pinned libplist commit, and Procursus build recipe snapshots.
- [sources](sources/) contains the corresponding project source archives and build recipes, including GPL/AGPL/LGPL sources. Procursus recipe bundles retain build scripts, metadata, patches, templates and entitlements, while excluding unrelated bundled projects and prebuilt SDK/framework binaries. Their upstream archive hash and transformation are recorded separately.
- [licenses](licenses/) contains copies of the source notices. Notices already inside the DEBs remain unchanged. Full per-file notices are also retained in the source archives.

Recipe snapshots match the package versions but are not asserted to be the original binary build commits; upstream DEBs do not publish that provenance. No source archive, installer script, tool or radio operation is executed by the verification scripts.

Verification: official upstream Release/index checksums, original DEB hashes, `dpkg-deb` metadata, matching scheme/payload paths, dependency relationships, source hashes, and the final APT index. This does not replace installation or functional testing on each supported device.

Upstreams: [Procursus](https://apt.procurs.us/), [RootHide Procursus](https://roothide.github.io/procursus/), [Procursus build system](https://github.com/ProcursusTeam/Procursus), [RootHide build system](https://github.com/roothide/Procursus-roothide).
