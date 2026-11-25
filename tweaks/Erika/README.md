# Erika Reborn 2.0.1

Erika Reborn is GokuEn's maintained fork of [Paisseon's original Erika](https://github.com/Paisseon/Erika) for Sileo.

It updates the Sileo package integration, adds RootHide support, and lets users choose from versions found in Erika's online archive rather than only APT history. The previous build's version selector was verified on an iPhone 11 Pro running RootHide, but this does not establish universal compatibility for every iOS version or jailbreak.

- **Package ID:** `emt.paisseon.erika`
- **Version:** `2.0.1`
- **Source:** https://github.com/Gokuencinar/Erika-Reborn
- **License:** GNU AGPLv3 (upstream)
- **Credits:** Paisseon (original creator), GokuEn (fork updates, RootHide compatibility, archive version selector)

For the archive-download limitation and technical prerequisites, see the [source repository README](https://github.com/Gokuencinar/Erika-Reborn#compatibility-and-limitations).

## Downloads in 2.0.1

The interface is in English. When a selected version is still available in a public APT source, Erika Reborn downloads its `.deb` and checks the repository SHA-256. For archive-only releases, the user may open the file on Chomikuj and follow its own authorized download flow, then provide a direct HTTPS link. Erika does not bypass authentication or licensing requirements.
