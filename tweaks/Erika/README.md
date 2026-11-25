# Erika Reborn 2.0.3

Erika Reborn is GokuEn's maintained fork of [Paisseon's original Erika](https://github.com/Paisseon/Erika) for Sileo.

It updates the Sileo package integration, adds RootHide support, and lets users choose from versions found in Erika's online archive rather than only APT history. The previous build's version selector was verified on an iPhone 11 Pro running RootHide, but this does not establish universal compatibility for every iOS version or jailbreak.

- **Package ID:** `emt.paisseon.erika`
- **Version:** `2.0.3`
- **Source:** https://github.com/Gokuencinar/Erika-Reborn
- **License:** GNU AGPLv3 (upstream)
- **Credits:** Paisseon (original creator), GokuEn (fork updates, RootHide compatibility, archive version selector)

For the archive-download limitation and technical prerequisites, see the [source repository README](https://github.com/Gokuencinar/Erika-Reborn#compatibility-and-limitations).

## Downloads in 2.0.3

The interface is entirely in English. The **Download** button saves public APT packages directly inside Erika, verifying HTTPS, SHA-256 and Debian structure; no URL is displayed or opened in Safari. Flat and distribution-style APT repositories are supported. Versions found only in Erika's Chomikuj archive remain visible but are not offered for direct download when the provider requires authentication, payment or reCAPTCHA. Erika does not bypass the provider's access restrictions.
