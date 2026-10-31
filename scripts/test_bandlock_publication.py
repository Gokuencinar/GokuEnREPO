"""Regression checks preventing experimental BandLock versions in Sileo."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from scripts.bandlock_publication import PUBLIC_PACKAGE_IDS, public_versions, publishable


class BandLockPublicationTest(unittest.TestCase):
    def test_stable_versions_remain_public(self):
        for package in PUBLIC_PACKAGE_IDS:
            for version in ("1.5", "1.4", "0.6.35"):
                self.assertTrue(publishable(package, version), (package, version))

    def test_experimental_versions_never_enter_sileo(self):
        for package in PUBLIC_PACKAGE_IDS:
            for version in (
                "1.5.1~rhscan6", "1.5.1~rhscan7", "1.6.0~rhui1",
                "1.5.1~rhsigdiag1", "1.6.0~beta1", "1.6.0", "1.7",
            ):
                self.assertFalse(publishable(package, version), (package, version))

    def test_new_bandlock_package_names_are_not_implicitly_approved(self):
        self.assertFalse(publishable("com.gokuencinar.bandlock.experimental", "1.5"))

    def test_untouched_unrelated_tweaks(self):
        self.assertTrue(publishable("com.gokuencinar.bettersettings", "1.6.0~test1"))

    def test_real_packages_are_all_approved(self):
        index = Path(__file__).resolve().parent.parent / "Packages"
        if not index.exists():
            self.skipTest("No generated APT index found")
        data = index.read_text(encoding="utf-8")
        for paragraph in data.split("\n\n"):
            fields = {}
            for line in paragraph.splitlines():
                if ": " in line:
                    name, value = line.split(": ", 1)
                    fields[name] = value
            package = fields.get("Package", "")
            if package.startswith("com.gokuencinar.bandlock"):
                self.assertTrue(publishable(package, fields.get("Version", "")))

    def test_manifest_is_explicit(self):
        self.assertIn("1.5", public_versions())
        self.assertNotIn("1.6.0", public_versions())

    def test_real_index_postprocessor_filters_accidental_test_debs(self):
        """Run the actual index post-processing code on synthetic entries."""
        root = Path(__file__).resolve().parent.parent
        shell_script = (root / "scripts/rebuild-packages.sh").read_text(encoding="utf-8")
        postprocessor = shell_script.split("python3 - <<'PY'\n", 1)[1].split("\nPY", 1)[0]
        entries = [
            "Package: com.gokuencinar.bandlock\nVersion: 1.5\nArchitecture: iphoneos-arm64e\nFilename: tweaks/BandLock/debs/public.deb",
            "Package: com.gokuencinar.bandlock\nVersion: 1.6.0~rhui1\nArchitecture: iphoneos-arm64e\nFilename: tweaks/BandLock/debs/test.deb",
            "Package: com.gokuencinar.bandlock.dopamine\nVersion: 1.5.1~rhscan7\nArchitecture: iphoneos-arm64\nFilename: tweaks/BandLock/debs/test2.deb",
            "Package: com.gokuencinar.bettersettings\nVersion: 0.5\nArchitecture: iphoneos-arm64e\nFilename: tweaks/BetterSettings/debs/other.deb",
        ]
        with tempfile.TemporaryDirectory() as working:
            index = Path(working) / "Packages"
            index.write_text("\n\n".join(entries) + "\n", encoding="utf-8")
            env = dict(os.environ, PYTHONPATH=str(root))
            run = subprocess.run(
                [sys.executable, "-B", "-c", postprocessor],
                cwd=working, env=env, text=True, capture_output=True,
                check=True,
            )
            published = index.read_text(encoding="utf-8")
            self.assertIn("Version: 1.5", published)
            self.assertIn("com.gokuencinar.bettersettings", published)
            self.assertNotIn("rhui1", published)
            self.assertNotIn("rhscan7", published)
            self.assertIn("Skipping unpublished BandLock", run.stderr)


if __name__ == "__main__":
    unittest.main()
