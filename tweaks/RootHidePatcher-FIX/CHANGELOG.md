# Changelog

## 1.0.0 â€” 2026-10-25

- Remove duplicate final LC_RPATH commands before signing converted binaries.
- Handle each architecture independently and preserve the first search-path occurrence.
- Apply only to the recognized RootHidePatcher 2.1.4 script, with checksum checks and an original backup.
- Restore the converter on removal and preserve unrelated/custom script changes.
- Include a dpkg trigger for supported Patcher updates.
