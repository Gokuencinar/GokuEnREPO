from pathlib import Path
import plistlib

p = Path("BetterWiFi-RH/Tweak.xm")
s = p.read_text()

def replace_once(old, new):
    global s
    if old not in s:
        raise SystemExit("missing anchor:\n" + old[:240])
    s = s.replace(old, new, 1)

replace_once(
'''static NSArray *BWRHSnapshotNetworks(void) {
    @synchronized (BWRHPrefsDomain) {
        return [BWRHLastNetworks copy] ?: @[];
    }
}

static void BWRHStoreNetworkSnapshot(NSArray *networks) {
    if (![networks isKindOfClass:[NSArray class]]) return;
    @synchronized (BWRHPrefsDomain) {
        BWRHLastNetworks = [networks copy];
    }
}
''',
'''static BOOL BWRHIsNativeWiFiKitSnapshotObject(id network) {
    if (!network) return NO;
    NSString *className = NSStringFromClass([network class]);
    if ([className isEqualToString:@"BWRHMobileWiFiNetwork"]) return NO;
    return YES;
}

static NSArray *BWRHSnapshotNetworks(void) {
    @synchronized (BWRHPrefsDomain) {
        NSArray *snapshot = [BWRHLastNetworks copy] ?: @[];
        NSMutableArray *safe = [NSMutableArray arrayWithCapacity:snapshot.count];
        for (id network in snapshot) {
            if (BWRHIsNativeWiFiKitSnapshotObject(network)) [safe addObject:network];
        }
        return safe;
    }
}

static void BWRHStoreNetworkSnapshot(NSArray *networks) {
    if (![networks isKindOfClass:[NSArray class]]) return;
    NSMutableArray *safe = [NSMutableArray arrayWithCapacity:networks.count];
    for (id network in networks) {
        if (BWRHIsNativeWiFiKitSnapshotObject(network)) [safe addObject:network];
    }
    @synchronized (BWRHPrefsDomain) {
        BWRHLastNetworks = [safe copy];
    }
}
'''
)

replace_once(
'''@implementation BWRHMobileWiFiNetwork
- (NSString *)title { return self.ssid ?: @""; }
- (BOOL)isSecure { return self.secure; }
@end
''',
'''@implementation BWRHMobileWiFiNetwork
- (NSString *)title { return self.ssid ?: @""; }
- (BOOL)isSecure { return self.secure; }

// Defensive WiFiKit compatibility only. MobileWiFi analyzer records should never
// be inserted into WFAirportViewController's native network set, but answering
// these KVC-backed flags prevents WiFiKitUI predicates from aborting if one
// accidentally crosses that boundary.
- (BOOL)isKnown { return NO; }
- (BOOL)isInstantHotspot { return NO; }
- (BOOL)isAdhoc { return NO; }
- (BOOL)isUnconfiguredAccessory { return NO; }
- (BOOL)isPopular { return NO; }
@end
'''
)

replace_once(
'''    if (results.count) {
        self.scanSource = @"MobileWiFi directo";
        self.networks = results;
        BWRHStoreNetworkSnapshot(results);
    } else {
''',
'''    if (results.count) {
        self.scanSource = @"MobileWiFi directo";
        self.networks = results;
    } else {
'''
)

p.write_text(s)

control = Path("BetterWiFi-RH/control")
ct = control.read_text().replace("Version: 0.3.7", "Version: 0.3.8")
if "Version: 0.3.8" not in ct:
    raise SystemExit("control version patch failed")
control.write_text(ct)

info_path = Path("BetterWiFi-RH/prefs/Resources/Info.plist")
info = plistlib.loads(info_path.read_bytes())
info["CFBundleShortVersionString"] = "0.3.8"
info["CFBundleVersion"] = "11"
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

print("BetterWiFi RH 0.3.8 snapshot isolation patch applied")
