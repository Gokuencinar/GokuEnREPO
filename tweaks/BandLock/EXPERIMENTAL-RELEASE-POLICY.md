# BandLock — Sileo stable channel vs experimental builds

The public GokuEnREPO APT index must **never** advertise test builds as updates.

- Public BandLock IDs: `com.gokuencinar.bandlock`, `.dopamine`, `.rootful`.
- Public versions are explicitly approved in `tweaks/BandLock/public-versions.txt`.
- A `1.5.1~rhscan7`, `1.6.0~rhui1`, `~diag`, `~test`, or any other **unapproved** BandLock version is automatically omitted from `Packages` and `Packages.gz`, even if its `.deb` accidentally lands in `tweaks/BandLock/debs/`.
- Experimental builds are provided by GitHub Actions workflow artifacts or private transfer, **not** published to the APT repository. CI experimental workflows must have `contents: read`, not write, and must not push artifacts or update the `debs` directory.
- `scripts/rebuild-packages.sh` enforces the policy. `.github/workflows/reindex.yml` runs only on the `main` branch. `python3 -m unittest scripts/test_bandlock_publication.py` tests the allow-list and actual index post-processing logic.
- When intentionally promoting a new **stable** BandLock version, add its exact version to `public-versions.txt` in `main` as part of that reviewed release, publish the verified `.deb`, then rebuild APT metadata. Merely increasing the version number in an experimental branch does not publish it.

This controls the repository's advertised versions, not locally sideloaded test packages. Sileo may still show the **installed** version in its installed-packages view; the version is simply not offered to other users as an update. A later properly published stable version can replace a sideloaded test version according to Debian version ordering.
