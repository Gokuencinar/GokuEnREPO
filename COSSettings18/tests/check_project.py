"""Offline package-contract checks; no iPhone connection is required."""
from pathlib import Path
from collections import Counter
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]


def load_plist(path: Path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


for relative in (
    "COSSettings18.plist",
    "prefs/Resources/Root.plist",
    "prefs/Resources/Info.plist",
    "layout/Library/PreferenceLoader/Preferences/COSSettings18Prefs.plist",
):
    assert isinstance(load_plist(ROOT / relative), dict), relative

filter_bundles = load_plist(ROOT / "COSSettings18.plist")["Filter"]["Bundles"]
assert filter_bundles == ["com.apple.Preferences"], filter_bundles

pane = load_plist(ROOT / "prefs/Resources/Root.plist")
entries = [item for item in pane["items"] if item.get("key")]
counts = Counter(item["key"] for item in entries)
assert counts and all(count == 1 for count in counts.values()), counts
assert all("default" in item for item in entries)

impl = (ROOT / "Tweak.xm").read_text(encoding="utf-8")
pref_impl = (ROOT / "prefs/COSRootListController.m").read_text(encoding="utf-8")
for key in counts:
    assert f'@"{key}"' in impl, f"Preference {key} has no runtime consumer"

assert '@"pl_bundle"' in impl
assert "if (!tweakIndexes.count) return original;" in impl
assert "endIndex <= headerIndex + 1" in impl
assert "COS_SETTINGS18_GROUP" in impl
assert '%hook PSGGeneralController' in impl
assert "COSIsRootController(controller)" in impl
assert 'COSBoolean(@"enabled", NO)' in impl
assert 'COSBoolean(@"appearanceEnabled", NO)' in impl
assert 'com.gokuencinar.cossettings18' in pref_impl

control = (ROOT / "control").read_text(encoding="utf-8")
makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
assert re.search(r"^export ARCHS := arm64e$", makefile, re.M)
assert re.search(r"^Architecture: iphoneos-arm64$", control, re.M)
assert re.search(r"^Package: com\.gokuencinar\.cossettings18$", control, re.M)
print(f"PASS: {len(entries)} preference keys, 4 XML plists, rootless metadata, scoped hooks")
