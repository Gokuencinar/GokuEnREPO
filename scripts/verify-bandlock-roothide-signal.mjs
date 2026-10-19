import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const root = 'tweaks/BandLock/build/BandLock-1.0-RootHide/';
const read = path => readFileSync(root + path, 'utf8');
const core = read('daemon/BLTelephonyCore.m');
const main = read('daemon/main.m');
const app = read('app/BLControlViewController.m');
const manager = read('app/BLTelephonyManager.m');
const control = read('control');

assert.match(control, /^Package: com\.gokuencinar\.bandlock$/m);
assert.match(control, /^Version: 1\.5\.1~rhsigdiag1$/m);
assert.match(control, /^Architecture: iphoneos-arm64e$/m);
assert.match(read('Makefile'), /THEOS_PACKAGE_SCHEME = roothide/);
assert.match(main, /#import <roothide\.h>/);
assert.match(main, /jbroot\(@"\/tmp\/com\.gokuencinar\.bandlockd\.sock"\)/);
assert.match(manager, /BLRootHidePhysicalRootFromEnvironment/);
assert.match(manager, /signalProbeWithCompletion:/);
assert.match(app, /Consultar intensidad \(RootHide\)/);
assert.match(app, /signalProbeTapped:/);
assert.match(app, /signalScanInfoTapped:/);
assert.match(core, /getCurrentDataServiceDescriptorSync:/);
assert.match(core, /descriptorWithSubscriptionContext:/);
assert.match(core, /getSignalStrengthMeasurements:error:/);
assert.match(core, /BLRHSignalNumber/);
assert.match(core, /rejectZero && value == 0\.0/);
for (const metric of ['rsrp', 'rsrq', 'rssi', 'snr']) {
  assert.match(core, new RegExp('BLRHMetric\\(typed, @"' + metric + '"'));
  assert.match(app, new RegExp('@"' + metric + '"'));
}
assert.match(main, /\[command isEqualToString:@"signal_probe"\]/);
assert.match(main, /\[command isEqualToString:@"scan_start"\]/);
assert.match(main, /active LTE scanning is disabled/);
assert.doesNotMatch(core, /\[.*setActiveBandInfo.*\]/);
const start = core.indexOf('- (NSDictionary *)signalProbeFromQuery:');
const end = core.indexOf('- (BOOL)openFieldTestWithError:', start);
assert.ok(start !== -1 && end > start, 'Signal probe must exist');
const probe = core.slice(start, end);
assert.doesNotMatch(probe, /setActiveBandInfo|writeLTEBands|writeNRBands|setRatSelection/);
assert.doesNotMatch(probe, /@"(uuid|slotID|cellId|PCI|MCC|MNC|TAC|EARFCN|NRARFCN)"/);
console.log('RootHide signal read-only diagnostic static regression checks: PASS');
