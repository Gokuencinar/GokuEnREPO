from pathlib import Path
import plistlib

root=Path("BetterWiFi-RH")

# Root.plist: replace the broken pushed list with an inline segmented control.
p=root/"prefs/Resources/Root.plist"
data=plistlib.loads(p.read_bytes())
items=data.get("items",[])
found=False
for spec in items:
    if isinstance(spec,dict) and spec.get("key")=="language":
        spec["cell"]="PSSegmentCell"
        spec["label"]="Language"
        spec["default"]=0
        spec["validValues"]=[0,1,2]
        spec["validTitles"]=["Automatic","Spanish","English"]
        spec["PostNotification"]="com.betterwifirh.preferences.changed"
        spec.pop("detail",None)
        found=True
if not found:
    raise SystemExit("language specifier not found")
p.write_bytes(plistlib.dumps(data,fmt=plistlib.FMT_XML,sort_keys=False))

# Preference controller: delay the reload until the segmented-control event is done.
p=root/"prefs/BWRHRootListController.m"
s=p.read_text()
old='''        _specifiers = nil;
        [self reloadSpecifiers];
        self.title = @"BetterWiFi RH";
'''
new='''        dispatch_async(dispatch_get_main_queue(), ^{
            self->_specifiers = nil;
            [self reloadSpecifiers];
            self.title = @"BetterWiFi RH";
        });
'''
if old not in s:
    raise SystemExit("language reload block not found")
s=s.replace(old,new,1)
p.write_text(s)

# Version bump.
p=root/"control"
s=p.read_text().replace("Version: 0.3.9","Version: 0.3.10")
if "Version: 0.3.10" not in s:
    raise SystemExit("control version bump failed")
p.write_text(s)

p=root/"prefs/Resources/Info.plist"
info=plistlib.loads(p.read_bytes())
info["CFBundleShortVersionString"]="0.3.10"
info["CFBundleVersion"]="13"
p.write_bytes(plistlib.dumps(info,fmt=plistlib.FMT_XML,sort_keys=False))

print("BetterWiFi RH 0.3.10 inline language selector patch applied")
