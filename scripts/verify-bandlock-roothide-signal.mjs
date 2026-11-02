import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const root = 'tweaks/BandLock/build/BandLock-1.0-RootHide/';
const read = path => readFileSync(root + path, 'utf8');
const core = read('daemon/BLTelephonyCore.m');
const main = read('daemon/main.m');
const scan = read('daemon/BLRHSignalScan.m');
const scanHeader = read('daemon/BLRHSignalScan.h');
const prerm = read('layout/DEBIAN/prerm');
const app = read('app/BLControlViewController.m');
const manager = read('app/BLTelephonyManager.m');
const control = read('control');

assert.match(control, /^Package: com\.gokuencinar\.bandlock$/m);
assert.match(control, /^Version: 1\.6\.0~rhui6$/m);
assert.match(control, /^Architecture: iphoneos-arm64e$/m);
assert.match(read('Makefile'), /THEOS_PACKAGE_SCHEME = roothide/);
assert.match(main, /#import <roothide\.h>/);
assert.match(main, /jbroot\(@"\/tmp\/com\.gokuencinar\.bandlockd\.sock"\)/);
assert.match(manager, /BLRootHidePhysicalRootFromEnvironment/);
assert.match(manager, /signalProbeWithCompletion:/);
assert.match(app, /Consultar intensidad \(RootHide\)/);
assert.match(app, /signalProbeTapped:/);
assert.match(app, /signalScanStartTapped:/);
assert.match(app, /signalScanCancelTapped:/);
assert.match(app, /Observar bandas LTE \(sin desconectar\)/);
assert.match(app, /signalObserveTapped:/);
assert.match(manager, /startPassiveSignalObservationWithCompletion:/);
assert.match(main, /scan_observe_start/);
assert.match(scanHeader, /startPassiveObservationWithManager:/);
const passiveStart = scan.indexOf('- (NSDictionary *)startPassiveObservationWithManager:');
const passiveEnd = scan.indexOf('- (NSDictionary *)cancel {', passiveStart);
assert.ok(passiveStart > 0 && passiveEnd > passiveStart, 'Passive observation must be isolated');
const passive = scan.slice(passiveStart, passiveEnd);
assert.match(passive, /\[manager queryCoreTelephonyForPassiveObservation\]/);
assert.doesNotMatch(passive, /\[manager queryCoreTelephony\]/,
  'Passive sampling must avoid the slow RAT getter');
assert.match(passive, /@autoreleasepool/);
assert.match(passive, /observation_cancelled/);
assert.match(passive, /observation_stopped/);
assert.match(passive, /self\.scanState\[@"success"\] = @\(!stop \|\| cancelled\)/);
assert.match(passive, /BLScanSingleActiveLine\(query\)/);
assert.match(passive, /BLScanSubscriptionUUID\(query\)/);
assert.match(passive, /@"source"\] isEqualToString:@"typed"/);
assert.match(passive, /sample < 12/);
assert.match(passive, /rows\.count >= 2/);
assert.match(passive, /@"read_only": @YES/);
assert.doesNotMatch(passive, /writeLTEBands|writeNRBands|BLScanWriteJournal|setRatSelection|setActiveBandInfo/,
  'Passive mode must never mutate radio selection or write recovery journal');
assert.match(app, /signalScanRecoverTapped:/);
assert.match(core, /descriptorWithSubscriptionContext:/);
assert.match(core, /getSignalStrengthMeasurements:error:/);
assert.match(core, /getRatSelectionMask:error:/);
assert.match(core, /getRatSelection:completion:/);
assert.match(core, /static NSString \*BLRHRatSelectionKind\(id selection\)/);
assert.match(core, /isEqualToString:@"kCTRegistrationRATSelectionUnknown"/);
assert.match(core, /@"explicit_unknown"/);
assert.match(core, /@"selection_kind": callbackKind/);
assert.match(core, /@"sync_kind": syncKind/);
assert.match(core, /@"ratSyncStatus"/);
assert.match(core, /@"ratAsyncStatus"/);
assert.match(core, /@"ratSelectionKind"/);
assert.match(core, /queryCoreTelephonyForPassiveObservation \{/);
assert.match(core, /return \[self queryCoreTelephonyWithRatSelection:NO\]/);
assert.match(core, /return \[self queryCoreTelephonyWithRatSelection:YES\]/);
assert.match(core, /NSDictionary \*ratSelection = includeRatSelection\s*\? \[self readRatSelectionFromClient:client context:context\]/);
const typedSource = core.slice(core.indexOf('if (typed) {'), core.indexOf('NSMutableArray *available ='));
assert.match(typedSource, /NSMutableDictionary \*typedServing/);
assert.match(typedSource, /\[items insertObject:typedServing atIndex:0\]/);
assert.doesNotMatch(typedSource, /serving\[@"(?:rsrp|rsrq|rssi|snr)"\]\s*=/,
  'Typed signal must not relabel leftover legacy metrics as typed');
assert.match(core, /strcmp\(maskSignature\.methodReturnType, "C"\)/);
assert.match(core, /@\[@"lte", @"automatic"/);
assert.doesNotMatch(core.slice(core.indexOf('- (NSDictionary *)snapshotFromQuery:'), core.indexOf('- (void)consumeSnapshotOnMain:')),
  /\[selection rangeOfString:@"LTE"/, 'Never infer LTE-only from arbitrary strings containing LTE');
assert.match(core, /@"mask_sync"/);
assert.match(core, /@"async_fallback"/);
assert.match(core, /@"timeout"/);
assert.match(core, /@"ratReadStatus"/);
assert.match(core, /@"ratReadSource"/);
assert.match(core, /BLRHSignalNumber/);
assert.match(core, /rejectZero && value == 0\.0/);
for (const metric of ['rsrp', 'rsrq', 'rssi', 'snr']) {
  assert.match(core, new RegExp('BLRHMetric\\(typed, @"' + metric + '"'));
  assert.match(app, new RegExp('@"' + metric + '"'));
}
assert.match(main, /\[command isEqualToString:@"signal_probe"\]/);
assert.match(main, /\[manager signalProbeFromQuery:\[manager queryCoreTelephonyForPassiveObservation\]\]/,
  'The monitor must use a read-only signal query that does not wait on unknown RAT selection');
assert.match(main, /\[command isEqualToString:@"scan_start"\]/);
for (const action of ['scan_start','scan_status','scan_cancel','scan_recover','scan_line_diagnostic']) {
  assert.match(main, new RegExp('@"' + action + '"'));
}
assert.match(main, /isRecovering/);
assert.match(main, /hasPendingRecovery/);
assert.match(main, /requestRecoveryWithManager:/);
assert.match(scanHeader, /isRecovering/);
assert.match(read('daemon/Makefile'), /BLRHSignalScan\.m/);
assert.match(scan, /BLScanMaxBands = 2/);
assert.match(scan, /@"initial_supported_lte"/);
assert.match(scan, /jbroot\(@"\/var\/mobile/);
assert.match(scan, /CC_SHA256/);
assert.match(scan, /BLScanSingleActiveLine/);
assert.match(scan, /BLRHWritableQuery/);
assert.match(scan, /@"rat_sync_kind"/);
assert.match(scan, /@"rat_async_kind"/);
assert.match(scan, /@"rat_selection_kind"/);
assert.match(scan, /@"rat_mask_byte_diagnostic_only"/);
assert.match(scan, /NSSet \*allow = \[NSSet setWithArray:/);
assert.match(scan, /if \(!failure && candidates.count < 2\)/);
assert.match(scan, /if \(!failure && \(!servingBand/);
assert.match(scan, /query = BLRHWritableQuery\(manager, query, subscription, mode, &stopReason\)/);
assert.match(scan, /if \(!query\) \{/);
assert.match(scan, /\[self shouldStop\]/);
assert.match(scan, /A different network mode was explicitly reported/);
assert.match(scan, /LTE-only mode could not be verified/);
assert.match(scan, /@"mode_unverified"/);
assert.match(scan, /@"mode_read_status"/);
assert.match(scan, /!\[readbackMode isEqualToString:mode\]/);
assert.match(scan, /if \(\[readbackMode isEqualToString:@"unknown"\]\)/);
assert.doesNotMatch(scan, /Network mode changed externally/, "Unknown RAT mode should not be called an external change");
const writeCall = scan.indexOf('writeLTEBands:@[band]');
const modeGate = scan.lastIndexOf('BLRHWritableQuery(manager, query, subscription, mode, &stopReason)', writeCall);
assert.ok(writeCall > modeGate && modeGate > 0,
  'Every per-band CoreTelephony write must follow an explicit LTE-mode gate');
assert.match(scan, /getActiveContexts:/);
assert.match(scan, /getSubscriptionInfoWithError:/);
assert.match(scan, /active_context_count/);
assert.match(scan, /provider_inventory_count/);
assert.match(scan, /data_service_in_rat/);
assert.match(scan, /BLRHActiveLineCheck/);
assert.match(scan, /NSInvocation invocationWithMethodSignature/);
assert.match(scan, /active_context_matches_data_slot/);
assert.match(scan, /getActiveContexts:/);
assert.doesNotMatch(scan.slice(scan.indexOf('static BOOL BLScanSingleActiveLine'), scan.indexOf('static NSDictionary *BLRHLineDiagnostics')),
  /providers count|serviceSubscriberCellularProviders/, 'Provisioned carrier plans must NOT count as active lines');
assert.match(scan, /scan_gate_current/);
assert.match(scan, /\[self isRunning\] \|\| \[self isRecovering\] \|\| \[self hasPendingRecovery\]/);
assert.match(scan, /@"typed"/);
assert.match(scan, /servingRSRP\.doubleValue < -115\.0/);
assert.match(scan, /original LTE bands|Restoring original LTE bands/i);
assert.match(scan, /if \(!BLScanWriteJournal\(journal\)\)/);
assert.match(scan, /if \(!BLScanWriteJournal\(step\)\)/);
assert.match(scan, /BLScanClearJournal/);
assert.match(scan, /BLScanMatches\(\[manager activeLTEFromQuery:/);
assert.match(scan, /_exit\(75\)/);
assert.match(prerm, /signal-scan-recovery\.plist/);
assert.match(prerm, /exit 1/);
assert.match(prerm, /command -v jbroot/);
assert.doesNotMatch(core, /\[.*setActiveBandInfo.*\]/);
const start = core.indexOf('- (NSDictionary *)signalProbeFromQuery:');
const end = core.indexOf('- (BOOL)openFieldTestWithError:', start);
assert.ok(start !== -1 && end > start, 'Signal probe must exist');
const probe = core.slice(start, end);
assert.doesNotMatch(probe, /setActiveBandInfo|writeLTEBands|writeNRBands|setRatSelection/);
assert.doesNotMatch(probe, /@"(uuid|slotID|cellId|PCI|MCC|MNC|TAC|EARFCN|NRARFCN)"/);
console.log('RootHide experimental two-band scan regression checks: PASS');

// UI analyzer should never include a radio-modifying client action or private identifiers.
const analyzer = read('app/BLAnalyzerViewController.m');
const delegate = read('app/BLAppDelegate.m');
assert.match(read('app/Makefile'), /BLAnalyzerViewController\.m/);
assert.match(delegate, /BLAnalyzerViewController/);
assert.match(delegate, /@\[controlNav, analyzerNav, countriesNav, infoNav\]/);
assert.match(analyzer, /signalProbeWithCompletion:/);
assert.match(analyzer, /scheduledTimerWithTimeInterval:12/);
assert.match(analyzer, /BLAnalyzerMaxSamples = 300/);
assert.match(analyzer, /@"source"\] isEqual:@"typed"/);
assert.match(analyzer, /@"rat"\] isEqual:@"LTE"/);
assert.match(analyzer, /@"role"\] isEqual:@"serving"/);
assert.match(analyzer, /viewWillDisappear:/);
assert.match(analyzer, /stopMonitoring/);
assert.match(analyzer, /removeObjectForKey:BLAnalyzerHistoryKey/);
assert.match(analyzer, /NSJSONSerialization/);
assert.doesNotMatch(analyzer, /\b(?:writeLTEBands|writeNRBands|startSignalScan|startPassiveSignalObservation|setNetworkMode|applyPendingBands|scan_start|scan_recover|setRatSelectionSync)\b|@"(?:imsi|imei|cellId|subscriptionUUID)"/i,
  'Analyzer may only request typed passive signal, never mutate the modem or store private cell IDs');
assert.match(control, /firmware \(<= 18\.99\)/,
  'Experimental preview must explicitly recognize firmware 18.7.1');
assert.match(main, /operatingSystemVersion\.majorVersion >= 18/);
assert.match(main, /@\[@"rat", @"apply", @"apply_nr", @"scan_start"\] containsObject:command/,
  'iOS18 preview must block every direct modem selection writer and active scan');
console.log('RootHide LTE 1.6 analyzer UI and read-only data gates: PASS');

// Prevent regression to the crash-prone switch UI removed in c2efb10 (2026-09-28).
for (const file of [
  'app/BLBandPickerViewController.m',
  'app/BLNRBandPickerViewController.m',
  'app/BLCountryBandsViewController.m',
  'app/BLInfoViewController.m',
]) {
  const source = read(file);
  assert.doesNotMatch(source, /\bUISwitch\b|\bbandSwitchChanged\b|\bccToggleChanged\b/,
    `${file} must never reintroduce the old UISwitch handlers`);
  assert.match(source, /UITableViewCellAccessoryCheckmark/);
  assert.match(source, /didSelectRowAtIndexPath:/);
}
assert.match(app, /@interface BLControlDisclosure : UIView/);
for (const title of ['Modo de red', 'Detalles de red', 'Restauración y seguridad', 'Diagnóstico avanzado']) {
  assert.ok(app.includes('disclosure:BLT(@"' + title + '"'), title + ' must be collapsible');
}
assert.match(app, /openAnalyzerTapped:/);
assert.match(app, /self\.applyLTEButton\.hidden = readOnly18/);
assert.match(app, /self\.signalStartButton\.hidden = readOnly18/);
assert.match(main, /@\[@"rat", @"apply", @"apply_nr", @"scan_start"\] containsObject:command/);
console.log('BandLock compact Control and historical no-switch regression: PASS');

// rhui4: the hero must not truncate a long heading on narrow iPhones.
assert.match(app, /BLT\(@"BANDA", @"BAND"\)/);
assert.match(app, /item\.adjustsFontSizeToFitWidth = YES/);
assert.doesNotMatch(app, /BANDA CONECTADA\\n%@|SERVING BAND\\n%@/);
assert.doesNotMatch(app, /ESTACIÓN DE CONTROL|BandLock Global %@/, 'Avoid duplicate headings/version labels');
// The entire list must remain available only inside the editor / network details,
// never in the always-visible pending bands card.
assert.match(app, /self\.pendingValue\.text = pendingCount/);
assert.match(app, /self\.manager\.pendingBands\.count/);
assert.doesNotMatch(app, /self\.pendingValue\.text = BLBandList\(/);
assert.match(app, /detail\.hidden = subtitle\.length == 0/);
assert.match(app, /Solo lectura · iOS 18/);
assert.match(app, /self\.applyLTEButton\.hidden = readOnly18/);
console.log('BandLock rhui4 concise UI and truncated header regression: PASS');

// rhui5 removes verbose text-only UI, not the privacy/persistence restrictions.
assert.doesNotMatch(analyzer, /Solo se guardan fecha|Only time, band and valid|Observa\. Compara\. Entiende\.|Observe\. Compare\. Understand\./);
assert.doesNotMatch(analyzer, /Gráfica de muestras válidas|Graph of valid samples|CoreTelephony · Tipado · Lectura pasiva/);
assert.doesNotMatch(analyzer, /Mediciones LTE pasivas · Sin modificar|Passive LTE measurements · No band/);
assert.match(analyzer, /strongSelf\.statusLabel\.hidden = YES/);
assert.match(analyzer, /self\.statusLabel\.hidden = NO/);
assert.match(analyzer, /BLAnalyzerHistoryKey/);
assert.match(analyzer, /BLAnalyzerMetric\(typed\[metric\], metric\)/);
assert.match(analyzer, /\[self stopMonitoring\]/);
const countries = read('app/BLCountriesViewController.m');
assert.match(countries, /LTE: %lu · 5G: %lu/);
assert.doesNotMatch(countries, /Las bandas reales dependen del operador|Actual bands vary by carrier/);
for (const file of ['app/BLBandPickerViewController.m','app/BLNRBandPickerViewController.m','app/BLCountryBandsViewController.m']) {
  const picker = read(file);
  assert.doesNotMatch(picker, /cell\.detailTextLabel\.text = \[NSString stringWithFormat/);
  assert.match(picker, /UITableViewCellAccessoryCheckmark/);
}
const info = read('app/BLInfoViewController.m');
assert.doesNotMatch(info, /Auto always remains visible|Off: one 5G option is shown/);
console.log('BandLock rhui5 minimal UI, read-only and no-switch regressions: PASS');

// rhui6: a band metadata dictionary cannot upgrade a physical LTE-only modem.
// The hardware veto must apply at daemon, app and CC, even for persisted intents.
const hw = readFileSync('tweaks/BandLock/build/BLHardwareCapabilities.h', 'utf8');
const cc = readFileSync('tweaks/BandLock/build/BandLock-1.0-Dopamine/ccmodule/Module.m', 'utf8');
assert.match(hw, /sysctlbyname\("hw\.machine"/);
assert.match(hw, /sscanf\(model, "iPhone%d,%d"/);
assert.match(hw, /major > 0 && major < 13/);
const isLTEOnlyModel = model => {
  const match = /^iPhone(\d+),(\d+)$/.exec(model);
  return match !== null && +match[1] > 0 && +match[1] < 13;
};
for (const device of ['iPhone10,3','iPhone11,2','iPhone12,3','iPhone12,8']) {
  assert.equal(isLTEOnlyModel(device), true, `${device} must not expose 5G`);
}
for (const device of ['iPhone13,2','iPhone14,6','iPhone17,3']) {
  assert.equal(isLTEOnlyModel(device), false, `${device} may support 5G if CoreTelephony confirms it`);
}
assert.match(core, /BOOL supports5G = !BLDeviceIsKnownLTEOnly\(\)/);
assert.match(core, /if \(!BLDeviceIsKnownLTEOnly\(\) && \[client respondsToSelector:supports5GSelector\]\)/);
assert.match(core, /if \(!supports5G\) \{ supportedNR = @\[\]; activeNR = @\[\]; \}/);
assert.match(manager, /self\.supports5G = !BLDeviceIsKnownLTEOnly\(\)/);
assert.match(info, /section == 0\) return BLDeviceIsKnownLTEOnly\(\) \? 3 : 4/);
assert.match(info, /section == 1\) return BLDeviceIsKnownLTEOnly\(\) \? 0 : 1/);
assert.match(info, /Toca cada fila para marcar o desmarcar/);
assert.match(info, /UITableViewCellAccessoryCheckmark/);
assert.match(cc, /BLDeviceIsKnownLTEOnly\(\)/);
assert.match(cc, /A saved\s*\n\s*\/\/ intent from an older build is not a modem readback/);
assert.doesNotMatch(cc, /_CTServerConnectionSetRATSelection|bl_setRATDirect|BLCTServerConnectionCreateFn/,
  'CC must never have a direct CoreTelephony RAT setter');
assert.match(cc, /if \(\[NSProcessInfo processInfo\]\.operatingSystemVersion\.majorVersion >= 18\) return;/);
assert.match(cc, /if \(\[NSProcessInfo processInfo\]\.operatingSystemVersion\.majorVersion >= 18\) \{[\s\S]*?Solo lectura/);
assert.match(cc, /self\.statusRefreshNotBefore = CFAbsoluteTimeGetCurrent\(\) \+ 20\.0/);
assert.match(cc, /\.tv_sec = \[NSProcessInfo processInfo\]\.operatingSystemVersion\.majorVersion >= 18 \? 3 : 30/);
assert.match(main, /@\[@"rat", @"apply", @"apply_nr", @"scan_start"\] containsObject:command/);
const statusHandler = main.slice(main.indexOf('if ([command isEqualToString:@"status"])'),
                                 main.indexOf('if ([command isEqualToString:@"rat"])'));
assert.match(statusHandler, /operatingSystemVersion\.majorVersion >= 18/);
assert.match(statusHandler, /\[manager queryCoreTelephonyForPassiveObservation\]/,
  'iOS18 status must not call unreliable RAT getters from the CC module');
console.log('BandLock rhui6 hardware 5G, CC UI and iOS18 read-only protections: PASS');
