# Erika Reborn 2.0.2

Erika Reborn is GokuEn's maintained fork of [Paisseon's original Erika](https://github.com/Paisseon/Erika) for Sileo.

It updates the Sileo package integration, adds RootHide support, and lets users choose from versions found in Erika's online archive rather than only APT history. The previous build's version selector was verified on an iPhone 11 Pro running RootHide, but this does not establish universal compatibility for every iOS version or jailbreak.

- **Package ID:** `emt.paisseon.erika`
- **Version:** `2.0.2`
- **Source:** https://github.com/Gokuencinar/Erika-Reborn
- **License:** GNU AGPLv3 (upstream)
- **Credits:** Paisseon (original creator), GokuEn (fork updates, RootHide compatibility, archive version selector)

For the archive-download limitation and technical prerequisites, see the [source repository README](https://github.com/Gokuencinar/Erika-Reborn#compatibility-and-limitations).

## Downloads in 2.0.2

The interface is entirely in English. Version selection now combines public APT repositories and Erika's archive; versions do not need to be present in both. APT versions download through HTTPS with SHA-256 verification and Debian archive checks. Chomikuj-only releases still use Chomikuj's authorized login/download flow (which can require reCAPTCHA) or a user-supplied direct HTTPS link. Erika does not bypass authentication or licensing requirements.
