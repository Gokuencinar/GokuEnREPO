"""Ensure Sileo sees exactly one clean AppFirewall 1.0 entry per bootstrap."""

from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parent.parent
PACKAGE = "com.gokuencinar.appfirewall.poc"
DESCRIPTION = "Control Wi-Fi and cellular data access for each app individually without having to turn off your device's connection. Compatible with iOS 15 through iOS 18. Other versions later than iOS 18 may not function correctly."
ARCH_NAMES = {
    "iphoneos-arm64": "Dopamine / Rootless",
    "iphoneos-arm64e": "RootHide",
    "iphoneos-arm": "Rootful",
}


class AppFirewallPublicationTests(unittest.TestCase):
    def test_all_variants_are_present_and_clean(self):
        index = (ROOT / "Packages").read_text(encoding="utf-8")
        entries = []
        for paragraph in index.strip().split("\n\n"):
            fields = {}
            for line in paragraph.splitlines():
                if ": " in line and not line.startswith(" "):
                    key, value = line.split(": ", 1)
                    fields[key] = value
            if fields.get("Package") == PACKAGE:
                entries.append(fields)
        self.assertEqual(len(entries), 3)
        self.assertEqual({e["Architecture"] for e in entries}, set(ARCH_NAMES))
        for entry in entries:
            with self.subTest(architecture=entry["Architecture"]):
                arch = entry["Architecture"]
                self.assertEqual(entry["Version"], "1.0")
                self.assertEqual(entry["Name"], f"AppFirewall ({ARCH_NAMES[arch]})")
                self.assertEqual(entry["Description"], DESCRIPTION)
                path = Path(entry["Filename"])
                self.assertEqual(path.name, f"{PACKAGE}_1.0_{arch}.deb")
                self.assertTrue((ROOT / path).is_file())
                self.assertGreater(int(entry["Size"]), 100000)
                self.assertIn("/tweaks/AppFirewall/depiction.html", entry["Depiction"])
                self.assertIn("/tweaks/AppFirewall/depiction.json", entry["SileoDepiction"])
                self.assertIn("/tweaks/AppFirewall/assets/icon-wifi-corrected.png", entry["Icon"])

    def test_depictions_match_package_description(self):
        base = ROOT / "tweaks" / "AppFirewall"
        native = json.loads((base / "depiction.json").read_text(encoding="utf-8"))
        self.assertEqual(native["tabs"][0]["views"][0]["markdown"], DESCRIPTION)
        html = (base / "depiction.html").read_text(encoding="utf-8")
        self.assertIn(DESCRIPTION, html)
        self.assertIn('src="assets/icon-wifi-corrected.png"', html)
        for forbidden in ("probado", "dispositivos", "firmware", "test devices", "NECP"):
            self.assertNotIn(forbidden.casefold(), html.casefold())


if __name__ == "__main__":
    unittest.main()
