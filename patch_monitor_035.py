from pathlib import Path

p = Path("BetterWiFi-RH/Tweak.xm")
s = p.read_text()

start_marker = "- (void)sampleSignal {"
end_marker = "- (void)viewDidAppear:(BOOL)animated {"

start = s.find(start_marker)
end = s.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit("monitor markers not found")

new_block = r'''- (void)bwrh_renderRSSI:(long long)rssi source:(NSString *)source {
    self.sampleCount += 1;
    self.lastSampleSource = source ?: @"—";
    if (rssi != LLONG_MIN) {
        [self.samples addObject:@(rssi)];
        while (self.samples.count > 60) [self.samples removeObjectAtIndex:0];
        self.valueLabel.text = [NSString stringWithFormat:@"%lld dBm", rssi];
        self.qualityLabel.text = BWRHSignalQuality(rssi);
        self.graphView.samples = [self.samples copy];
    } else {
        self.valueLabel.text = @"— dBm";
        self.qualityLabel.text = BWRHT(@"RSSI no disponible", @"RSSI unavailable");
    }

    id fallback = [self currentNetwork];
    id liveNetwork = BWRHMWCurrentNetworkRecordForAirport(self.airportController) ?: BWRHLiveScanResultForAirport(self.airportController) ?: fallback;
    NSNumber *channel = BWRHChannelNumber(liveNetwork);
    NSString *band = BWRHBandDescription(liveNetwork);
    NSString *bssid = BWRHBSSID(liveNetwork);
    NSMutableArray *meta = [NSMutableArray array];
    [meta addObject:self.lastSampleSource ?: @"—"];
    [meta addObject:[NSString stringWithFormat:BWRHT(@"muestra %lu", @"sample %lu"), (unsigned long)self.sampleCount]];
    [meta addObject:[NSString stringWithFormat:@"LQM MW %lu / WK %lu", (unsigned long)BWRHMWLQMEventCount, (unsigned long)BWRHWiFiKitLQEventCount]];
    if (band.length) [meta addObject:band];
    if (channel) [meta addObject:[NSString stringWithFormat:@"%@ %@", BWRHT(@"Canal", @"Channel"), channel]];
    if (bssid.length) [meta addObject:bssid];
    self.metaLabel.text = [meta componentsJoinedByString:@" · "];
}

- (void)bwrh_applyDriverRSSI:(long long)rssi {
    if (!self.view.window || rssi >= 0 || rssi <= -200) return;
    [self bwrh_renderRSSI:rssi source:@"MobileWiFi LQM"];
}

- (void)bwrh_applyWiFiKitLQMRSSI:(long long)rssi {
    if (!self.view.window || rssi >= 0 || rssi <= -200) return;
    [self bwrh_renderRSSI:rssi source:@"WiFiKit LQ event"];
}

- (void)sampleSignal {
    id fallback = [self currentNetwork];
    long long rssi = BWRHMWReadRSSIForAirport(self.airportController);
    BOOL mobile = (rssi != LLONG_MIN);
    if (rssi == LLONG_MIN) rssi = BWRHLiveRSSIForAirport(self.airportController, fallback);
    [self bwrh_renderRSSI:rssi source:(mobile ? @"MobileWiFi directo" : @"WiFiKit fallback")];
}

- (void)scheduleNextSampleForGeneration:(NSUInteger)generation {
    NSTimeInterval interval = BWRHBool(@"efficientMode", YES) ? 2.5 : 1.0;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.monitorGeneration != generation || !self.view.window) return;
        [self sampleSignal];
        [self scheduleNextSampleForGeneration:generation];
    });
}

- (void)startMonitoring {
    self.monitorGeneration += 1;
    BWRHMWActiveMonitor = self;
    BWRHMWRegisterLQMForAirport(self.airportController);
    NSUInteger generation = self.monitorGeneration;
    [self sampleSignal];
    [self scheduleNextSampleForGeneration:generation];
}

- (void)stopMonitoring {
    self.monitorGeneration += 1;
    if (BWRHMWActiveMonitor == self) BWRHMWActiveMonitor = nil;
}

'''

s = s[:start] + new_block + s[end:]
p.write_text(s)
