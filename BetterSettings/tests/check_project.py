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
    "BetterSettings.plist",
    "prefs/Resources/Root.plist",
    "prefs/Resources/Info.plist",
    "layout/Library/PreferenceLoader/Preferences/BetterSettingsPrefs.plist",
):
    assert isinstance(load_plist(ROOT / relative), dict), relative

filter_bundles = load_plist(ROOT / "BetterSettings.plist")["Filter"]["Bundles"]
assert filter_bundles == ["com.apple.Preferences"], filter_bundles

pane = load_plist(ROOT / "prefs/Resources/Root.plist")
entry = load_plist(ROOT / "layout/Library/PreferenceLoader/Preferences/BetterSettingsPrefs.plist")["entry"]
assert entry["icon"] == "icon.png" and entry["hasIcon"] is True
assert (ROOT / "prefs/Resources/icon.png").is_file()
assert (ROOT / "prefs/Resources/CreditsAvatar.jpg").is_file()
assert 'pathForResource:@"CreditsAvatar"' in (ROOT / "prefs/BetterRootListController.m").read_text(encoding="utf-8")
entries = [item for item in pane["items"] if item.get("key")]
counts = Counter(item["key"] for item in entries)
assert counts and all(count == 1 for count in counts.values()), counts
assert all("default" in item for item in entries)

impl = (ROOT / "Tweak.xm").read_text(encoding="utf-8")
pref_impl = (ROOT / "prefs/BetterRootListController.m").read_text(encoding="utf-8")
for key in counts:
    assert f'@"{key}"' in impl, f"Preference {key} has no runtime consumer"

assert '@"pl_bundle"' in impl
assert "if (!tweakIndexes.count)" in impl
assert "endIndex <= headerIndex + 1" in impl
assert "BS_SETTINGS18_GROUP" in impl
assert 'objc_getClass("PSGGeneralController")' in impl
assert '%init(SettingsHost, PrefsListController = host)' in impl
assert "BSIsRootController(controller)" in impl
assert 'BSBoolean(@"enabled", NO)' in impl
assert 'BSBoolean(@"appearanceEnabled", NO)' in impl
assert 'com.gokuencinar.bettersettings' in pref_impl

control = (ROOT / "control").read_text(encoding="utf-8")
makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
assert re.search(r"^export ARCHS := arm64e$", makefile, re.M)
assert re.search(r"^Architecture: iphoneos-arm64$", control, re.M)
assert re.search(r"^Package: com\.gokuencinar\.bettersettings$", control, re.M)
assert re.search(r"^Version: 1\.0\.1$", control, re.M)
assert "preferenceloader (>= 2.3.3+zbetter2)" in control
print(f"PASS: {len(entries)} preference keys, 4 XML plists, rootless metadata, scoped hooks")
