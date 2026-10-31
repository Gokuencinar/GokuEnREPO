"""Fail-closed allow-list for BandLock packages published in Sileo.

Package builds and GitHub Actions artifacts are intentionally unaffected.
Only approved versions of the three public BandLock package IDs may enter
the APT Packages index. New stable releases require an intentional update to
the public-versions.txt manifest on the main branch.
"""

from pathlib import Path


PUBLIC_PACKAGE_IDS = frozenset({
    "com.gokuencinar.bandlock",
    "com.gokuencinar.bandlock.dopamine",
    "com.gokuencinar.bandlock.rootful",
})

PUBLIC_VERSION_FILE = (
    Path(__file__).resolve().parent.parent / "tweaks/BandLock/public-versions.txt"
)


def public_versions():
    return frozenset(
        line.partition("#")[0].strip()
        for line in PUBLIC_VERSION_FILE.read_text(encoding="utf-8").splitlines()
        if line.partition("#")[0].strip()
    )


def publishable(package, version):
    """True except when an unapproved BandLock build would enter Sileo."""
    if not package.startswith("com.gokuencinar.bandlock"):
        return True
    return package in PUBLIC_PACKAGE_IDS and version in public_versions()
