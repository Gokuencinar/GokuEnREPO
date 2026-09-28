from pathlib import Path
import plistlib

p = Path("BetterWiFi-RH/Tweak.xm")
s = p.read_text()

def rep(old, new, count=1):
    global s
    if old not in s:
        raise SystemExit("missing patch anchor:\n" + old[:180])
    s = s.replace(old, new, count)

rep(
'''static void (*BWRHMWSchedule)(BWRHMWManagerRef, CFRunLoopRef, CFStringRef) = NULL;
''',
'''static void (*BWRHMWSchedule)(BWRHMWManagerRef, CFRunLoopRef, CFStringRef) = NULL;
static void (*BWRHMWUnschedule)(BWRHMWManagerRef) = NULL;
'''
)

rep(
'''static int (*BWRHMWScanAsync)(BWRHMWDeviceRef, CFDictionaryRef, BWRHMWScanCallback, const void *) = NULL;
''',
'''static int (*BWRHMWScanAsync)(BWRHMWDeviceRef, CFDictionaryRef, BWRHMWScanCallback, const void *) = NULL;
static void (*BWRHMWScanCancel)(BWRHMWDeviceRef) = NULL;
'''
)

rep(
'''        BWRHMWSchedule = (void (*)(BWRHMWManagerRef, CFRunLoopRef, CFStringRef))dlsym(BWRHMWHandle, "WiFiManagerClientScheduleWithRunLoop");
''',
'''        BWRHMWSchedule = (void (*)(BWRHMWManagerRef, CFRunLoopRef, CFStringRef))dlsym(BWRHMWHandle, "WiFiManagerClientScheduleWithRunLoop");
        BWRHMWUnschedule = (void (*)(BWRHMWManagerRef))dlsym(BWRHMWHandle, "WiFiManagerClientUnscheduleFromRunLoop");
'''
)

rep(
'''        BWRHMWScanAsync = (int (*)(BWRHMWDeviceRef, CFDictionaryRef, BWRHMWScanCallback, const void *))dlsym(BWRHMWHandle, "WiFiDeviceClientScanAsync");
''',
'''        BWRHMWScanAsync = (int (*)(BWRHMWDeviceRef, CFDictionaryRef, BWRHMWScanCallback, const void *))dlsym(BWRHMWHandle, "WiFiDeviceClientScanAsync");
        BWRHMWScanCancel = (void (*)(BWRHMWDeviceRef))dlsym(BWRHMWHandle, "WiFiDeviceClientScanCancel");
'''
)

rep(
'''    if (BWRHMWDevice && BWRHMWRegisterLQM && (!BWRHMWLQMRegistered || BWRHMWLQMDevice != BWRHMWDevice)) {
        BWRHMWRegisterLQM(BWRHMWDevice, BWRHMWLQMCallbackFunction, NULL);
        BWRHMWLQMRegistered = YES;
        BWRHMWLQMDevice = BWRHMWDevice;
    }
    return BWRHMWDevice != NULL;
}
''',
'''    return BWRHMWDevice != NULL;
}
'''
)

rep(
'''static void BWRHMWRegisterLQMForAirport(id airportController) {
    BWRHMWDeviceRef device = BWRHMWDeviceForAirport(airportController);
    if (device && BWRHMWRegisterLQM && (!BWRHMWLQMRegistered || BWRHMWLQMDevice != device)) {
        BWRHMWRegisterLQM(device, BWRHMWLQMCallbackFunction, NULL);
        BWRHMWLQMRegistered = YES;
        BWRHMWLQMDevice = device;
    }
}
''',
'''static void BWRHMWUnregisterLQM(void) {
    if (BWRHMWLQMRegistered && BWRHMWLQMDevice && BWRHMWRegisterLQM) {
        BWRHMWRegisterLQM(BWRHMWLQMDevice, NULL, NULL);
    }
    BWRHMWLQMRegistered = NO;
    BWRHMWLQMDevice = NULL;
}

static void BWRHMWRegisterLQMForAirport(id airportController) {
    BWRHMWDeviceRef device = BWRHMWDeviceForAirport(airportController);
    if (!device || !BWRHMWRegisterLQM) return;
    if (BWRHMWLQMRegistered && BWRHMWLQMDevice == device) return;
    BWRHMWUnregisterLQM();
    BWRHMWRegisterLQM(device, BWRHMWLQMCallbackFunction, NULL);
    BWRHMWLQMRegistered = YES;
    BWRHMWLQMDevice = device;
}

static BWRHMWDeviceRef BWRHMWExistingDeviceForAirport(id airportController) {
    BWRHMWResolveSymbols();
    id wfInterface = BWRHWFInterfaceForAirport(airportController);
    SEL deviceSel = NSSelectorFromString(@"device");
    if (wfInterface && [wfInterface respondsToSelector:deviceSel]) {
        BWRHMWDeviceRef device = ((BWRHMWDeviceRef (*)(id, SEL))objc_msgSend)(wfInterface, deviceSel);
        if (device) return device;
    }
    return BWRHMWDevice;
}

static void BWRHMWCancelScanForAirport(id airportController) {
    BWRHMWDeviceRef device = BWRHMWExistingDeviceForAirport(airportController);
    if (device && BWRHMWScanCancel) BWRHMWScanCancel(device);
}

static void BWRHMWReleaseFallbackClientIfIdle(void) {
    if (BWRHMWActiveMonitor || BWRHMWActiveAnalyzer) return;
    BWRHMWUnregisterLQM();
    if (BWRHMWDevice) {
        CFRelease(BWRHMWDevice);
        BWRHMWDevice = NULL;
    }
    if (BWRHMWManager) {
        if (BWRHMWUnschedule) BWRHMWUnschedule(BWRHMWManager);
        CFRelease(BWRHMWManager);
        BWRHMWManager = NULL;
    }
}
'''
)

rep(
'''@property (nonatomic) NSUInteger monitorGeneration;
@property (nonatomic) NSUInteger sampleCount;
''',
'''@property (nonatomic, strong) dispatch_source_t sampleTimer;
@property (nonatomic) NSUInteger sampleCount;
'''
)

start = s.find('- (void)scheduleNextSampleForGeneration:(NSUInteger)generation {')
end = s.find('- (void)viewDidAppear:(BOOL)animated {', start)
if start < 0 or end < 0:
    raise SystemExit("monitor lifecycle block not found")

monitor_block = '''- (void)startMonitoring {
    [self stopMonitoring];
    BWRHMWActiveMonitor = self;
    BWRHMWRegisterLQMForAirport(self.airportController);
    [self sampleSignal];

    NSTimeInterval interval = BWRHBool(@"efficientMode", YES) ? 3.0 : 1.0;
    uint64_t intervalNS = (uint64_t)(interval * NSEC_PER_SEC);
    uint64_t leewayNS = (uint64_t)(0.25 * NSEC_PER_SEC);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    self.sampleTimer = timer;
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, intervalNS), intervalNS, leewayNS);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.view.window || self.sampleTimer != timer) return;
        [self sampleSignal];
    });
    dispatch_resume(timer);
}

- (void)stopMonitoring {
    dispatch_source_t timer = self.sampleTimer;
    self.sampleTimer = nil;
    if (timer) dispatch_source_cancel(timer);
    if (BWRHMWActiveMonitor == self) BWRHMWActiveMonitor = nil;
    BWRHMWUnregisterLQM();
    BWRHMWReleaseFallbackClientIfIdle();
}

'''
s = s[:start] + monitor_block + s[end:]

rep(
'''@property (nonatomic, copy) NSString *scanSource;
- (instancetype)initWithAirportController:(UIViewController *)airport currentNetwork:(id)network;
''',
'''@property (nonatomic, copy) NSString *scanSource;
@property (nonatomic) BOOL analyzerVisible;
@property (nonatomic) NSUInteger scanGeneration;
- (instancetype)initWithAirportController:(UIViewController *)airport currentNetwork:(id)network;
'''
)

rep(
'''    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshScan)];
    self.networks = BWRHLatestScanNetworks(self.airportController);
    [self rebuildRows];
    [self refreshScan];
}
''',
'''    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshScan)];
    self.networks = BWRHLatestScanNetworks(self.airportController);
    [self rebuildRows];
}
'''
)

rep(
'''- (void)refreshScan {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    BWRHMWActiveAnalyzer = self;
    self.mobileWiFiScanSucceeded = NO;
    self.mobileWiFiScanError = 0;
    self.scanSource = @"MobileWiFi pendiente";
    if (BWRHMWStartScanForAirport(self.airportController)) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.navigationItem.rightBarButtonItem.enabled) return;
            self.scanSource = @"WiFiKit fallback (timeout)";
            BWRHRequestFreshScan(self.airportController);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.networks = BWRHLatestScanNetworks(self.airportController);
                [self rebuildRows];
                [self.tableView reloadData];
                self.navigationItem.rightBarButtonItem.enabled = YES;
            });
        });
        return;
    }

    self.scanSource = @"WiFiKit fallback (MobileWiFi no disponible)";
    BWRHRequestFreshScan(self.airportController);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.networks = BWRHLatestScanNetworks(weakSelf.airportController);
        [weakSelf rebuildRows];
        [weakSelf.tableView reloadData];
        weakSelf.navigationItem.rightBarButtonItem.enabled = YES;
    });
}
''',
'''- (void)refreshScan {
    if (!self.analyzerVisible && self.view.window == nil) return;
    self.scanGeneration += 1;
    NSUInteger generation = self.scanGeneration;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    BWRHMWActiveAnalyzer = self;
    self.mobileWiFiScanSucceeded = NO;
    self.mobileWiFiScanError = 0;
    self.scanSource = @"MobileWiFi pendiente";
    if (BWRHMWStartScanForAirport(self.airportController)) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.analyzerVisible || self.scanGeneration != generation || self.navigationItem.rightBarButtonItem.enabled) return;
            self.scanSource = @"WiFiKit fallback (timeout)";
            BWRHRequestFreshScan(self.airportController);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self.analyzerVisible || self.scanGeneration != generation) return;
                self.networks = BWRHLatestScanNetworks(self.airportController);
                [self rebuildRows];
                [self.tableView reloadData];
                self.navigationItem.rightBarButtonItem.enabled = YES;
            });
        });
        return;
    }

    self.scanSource = @"WiFiKit fallback (MobileWiFi no disponible)";
    BWRHRequestFreshScan(self.airportController);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.analyzerVisible || self.scanGeneration != generation) return;
        self.networks = BWRHLatestScanNetworks(self.airportController);
        [self rebuildRows];
        [self.tableView reloadData];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    });
}
'''
)

rep(
'''- (void)bwrh_applyMobileWiFiScanResults:(NSArray *)results error:(NSInteger)error {
    self.mobileWiFiScanError = error;
''',
'''- (void)bwrh_applyMobileWiFiScanResults:(NSArray *)results error:(NSInteger)error {
    if (!self.analyzerVisible || BWRHMWActiveAnalyzer != self) return;
    self.mobileWiFiScanError = error;
'''
)

rep(
'''- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    BWRHMWActiveAnalyzer = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (BWRHMWActiveAnalyzer == self) BWRHMWActiveAnalyzer = nil;
}
''',
'''- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.analyzerVisible = YES;
    BWRHMWActiveAnalyzer = self;
    if ([self.scanSource isEqualToString:@"Inicial"]) [self refreshScan];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.analyzerVisible = NO;
    self.scanGeneration += 1;
    BWRHMWCancelScanForAirport(self.airportController);
    self.navigationItem.rightBarButtonItem.enabled = YES;
    if (BWRHMWActiveAnalyzer == self) BWRHMWActiveAnalyzer = nil;
    BWRHMWReleaseFallbackClientIfIdle();
}

- (void)dealloc {
    BWRHMWCancelScanForAirport(self.airportController);
    if (BWRHMWActiveAnalyzer == self) BWRHMWActiveAnalyzer = nil;
    BWRHMWReleaseFallbackClientIfIdle();
}
'''
)

p.write_text(s)

control = Path("BetterWiFi-RH/control")
control_text = control.read_text().replace("Version: 0.3.6", "Version: 0.3.7")
if "Version: 0.3.7" not in control_text:
    raise SystemExit("control version patch failed")
control.write_text(control_text)

info_path = Path("BetterWiFi-RH/prefs/Resources/Info.plist")
info = plistlib.loads(info_path.read_bytes())
info["CFBundleShortVersionString"] = "0.3.7"
info["CFBundleVersion"] = "10"
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

print("BetterWiFi RH 0.3.7 low-power lifecycle patch applied")
