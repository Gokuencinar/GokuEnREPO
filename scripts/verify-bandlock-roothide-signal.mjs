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
const analyzer = read('app/BLAnalyzerViewController.m');
const captureStore = read('app/BLAnalyzerCaptureStore.m');
const capturesController = read('app/BLAnalyzerCapturesViewController.m');
const countryProfile = read('app/BLCountryProfile.m');
const countriesController = read('app/BLCountriesViewController.m');
const countryDetail = read('app/BLCountryDetailViewController.m');
const countrySpectrum = JSON.parse(read('app/Resources/country-spectrum.json'));
const metadata = read('shared/BLGBandMetadata.m');
const control = read('control');
const abiVerifier = readFileSync('scripts/verify-bandlock-arm64e-abi-v2.py', 'utf8');
const macWorkflow = readFileSync('.github/workflows/build-bandlock-roothide-signal-diagnostic.yml', 'utf8');
const linuxWorkflow = readFileSync('.github/workflows/build-bandlock-roothide-linux-diagnostic.yml', 'utf8');

assert.match(control, /^Package: com\.gokuencinar\.bandlock$/m);
assert.match(control, /^Version: 1\.6\.0~rhui24$/m);
assert.match(control, /^Architecture: iphoneos-arm64e$/m);
assert.match(abiVerifier, /CPU_SUBTYPE_ARM64E_ABI_V2 = 0x80000002/);
assert.match(macWorkflow, /verify-bandlock-arm64e-abi-v2\.py "\$cc" "\$bridge"/);
assert.match(macWorkflow, /verify-bandlock-arm64e-abi-v2\.py \\\n\s+\/tmp\/bandlock-extracted\/Library\/ControlCenter\/Bundles\/BandLockCCModule\.bundle\/BandLockCCModule \\\n\s+\/tmp\/bandlock-extracted\/Library\/MobileSubstrate\/DynamicLibraries\/BandLockFieldBridge\.dylib/);
assert.doesNotMatch(linuxWorkflow, /actions\/upload-artifact/);
assert.match(linuxWorkflow, /Do not upload or install the generated DEB/);
assert.match(read('Makefile'), /THEOS_PACKAGE_SCHEME = roothide/);
assert.match(main, /#import <roothide\.h>/);
assert.match(main, /jbroot\(@"\/tmp\/com\.gokuencinar\.bandlockd\.sock"\)/);
assert.match(manager, /BLRootHidePhysicalRootFromEnvironment/);
assert.match(manager, /signalProbeWithCompletion:/);
assert.match(analyzer, /Actualizar ahora/);
assert.match(analyzer, /signalProbeWithCompletion:/);
assert.match(analyzer, /scanTapped:/);
assert.match(analyzer, /scanCancelTapped:/);
assert.match(analyzer, /initWithItems:@\[@"Auto", @"2G", @"3G", @"4G", @"5G"\]/);
assert.doesNotMatch(app, /disclosure:BLT\(@"Diagnóstico"/);
assert.match(manager, /startPassiveSignalObservationForRAT:/);
assert.match(main, /scan_observe_start/);
assert.match(scanHeader, /startPassiveObservationWithManager:/);
const passiveStart = scan.indexOf('- (NSDictionary *)startPassiveObservationWithManager:');
const passiveEnd = scan.indexOf('- (NSDictionary *)startTechnologyScanWithManager:', passiveStart);
assert.ok(passiveStart > 0 && passiveEnd > passiveStart, 'Passive observation must be isolated');
const passive = scan.slice(passiveStart, passiveEnd);
const technologyStart = passiveEnd;
const technologyEnd = scan.indexOf('- (NSDictionary *)cancel {', technologyStart);
assert.ok(technologyStart > 0 && technologyEnd > technologyStart,
  'Technology scan must be isolated from legacy passive observation');
const technologyScan = scan.slice(technologyStart, technologyEnd);
assert.match(passive, /\[manager queryCoreTelephonyForPassiveObservation\]/);
assert.doesNotMatch(passive, /\[manager queryCoreTelephony\]/,
  'Passive sampling must avoid the slow RAT getter');
assert.match(passive, /@autoreleasepool/);
assert.match(passive, /observation_cancelled/);
assert.match(passive, /observation_stopped/);
assert.match(passive, /self\.scanState\[@"success"\] = @\(!stop \|\| cancelled\)/);
assert.doesNotMatch(passive, /BLScanSingleActiveLine\(query\)/,
  'Passive observation must work on legacy cells without writable context');
assert.match(passive, /BLScanSubscriptionUUID\(query\)/);
assert.match(passive, /@"source"\] isEqualToString:@"typed"/);
assert.match(passive, /sample < 12/);
assert.match(passive, /rows\.count < BLPassiveMaxRows/);
assert.match(passive, /@"read_only": @YES/);
assert.doesNotMatch(passive, /writeLTEBands|writeNRBands|BLScanWriteJournal|setRatSelection|setActiveBandInfo/,
  'Passive mode must never mutate radio selection or write recovery journal');
assert.match(app, /signalScanRecoverTapped:/);
assert.match(analyzer, /scanRecoverTapped:/);
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

// Analyzer owns signal measurement and the guarded technology-scan workflow,
// but it must never bypass the manager with direct modem writes or store cell IDs.
const delegate = read('app/BLAppDelegate.m');
assert.match(read('app/Makefile'), /BLAnalyzerViewController\.m/);
assert.match(delegate, /BLAnalyzerViewController/);
assert.match(delegate, /@\[controlNav, analyzerNav, countriesNav, infoNav\]/);
assert.match(analyzer, /signalProbeWithCompletion:/);
assert.match(analyzer, /scheduledTimerWithTimeInterval:6\.0/);
assert.match(analyzer, /BLAnalyzerMaxSamples = 300/);
assert.match(analyzer, /row\[@"source"\] isEqualToString:@"typed"/);
assert.match(analyzer, /\[rat isEqualToString:@"LTE"\]/);
assert.match(analyzer, /\[rat isEqualToString:@"NR"\]/);
assert.match(analyzer, /row\[@"role"\] isEqualToString:@"serving"/);
assert.match(analyzer, /viewWillDisappear:/);
assert.match(analyzer, /stopMonitoring/);
assert.match(analyzer, /removeObjectForKey:BLAnalyzerHistoryKey/);
assert.match(analyzer, /NSJSONSerialization/);
assert.match(analyzer, /startTechnologySignalScanForRAT:rat/);
assert.match(analyzer, /setNetworkModeAutomatic:/);
assert.match(analyzer, /signalScanStatusWithCompletion:/);
assert.match(analyzer, /cancelSignalScanWithCompletion:/);
assert.match(analyzer, /recoverSignalScanWithCompletion:/);
assert.doesNotMatch(analyzer, /\b(?:writeLTEBands|writeNRBands|applyPendingBands|applyBands|setRatSelectionSync)\b|@"(?:imsi|imei|subscriptionUUID)"/i,
  'Analyzer may orchestrate guarded scans, but must not directly write the modem or persist private cell IDs');
assert.match(analyzer, /BLCountryBandsForRAT/);
assert.match(analyzer, /BLCountryFrequenciesForRAT/);
assert.match(analyzer, /performWithoutAnimation/);
assert.match(scan, /\[allowed containsObject:band\]/);
assert.match(scan, /country_iso/);
assert.match(core, /kCTCellMonitorCellId/);
assert.match(core, /kCTCellMonitorPID/);
assert.doesNotMatch(core.slice(core.indexOf('static NSDictionary *BLRHLegacySignalRow'), core.indexOf('@interface BLTelephonyManager')),
  /@\"(?:IMSI|IMEI|ICCID|subscriptionUUID|subscriberIdentity)\"/i);
assert.match(control, /firmware \(<= 18\.99\)/,
  'Experimental preview must explicitly recognize firmware 18.7.1');
assert.match(main, /operatingSystemVersion\.majorVersion >= 18/);
assert.match(main, /@\[@"apply_nr", @"scan_start"\] containsObject:command/,
  'iOS18 must keep NR writes and the obsolete two-band experiment blocked');
assert.doesNotMatch(main, /No se puede verificar el modo actual en iOS 18/,
  'The old iOS18 RAT preflight must not reject changes before calling the 1.5 setter');
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
for (const title of ['Modo de red', 'Detalles de red', 'Restauración y seguridad']) {
  assert.ok(app.includes('disclosure:BLT(@"' + title + '"'), title + ' must be collapsible');
}
assert.doesNotMatch(app, /disclosure:BLT\(@"Diagnóstico"/,
  'Coverage diagnostics must live in Analyzer, not be duplicated in Control');
assert.match(app, /openAnalyzerTapped:/);
assert.match(app, /self\.applyLTEButton\.hidden = NO/);
assert.match(app, /self\.signalStartButton\.hidden = readOnly18/);
assert.match(main, /@\[@"apply_nr", @"scan_start"\] containsObject:command/);
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
assert.match(app, /Cambio de modo sujeto a verificación/);
assert.match(app, /self\.applyLTEButton\.hidden = NO/);
console.log('BandLock rhui4 concise UI and truncated header regression: PASS');

// rhui5 removes verbose text-only UI, not the privacy/persistence restrictions.
assert.doesNotMatch(analyzer, /Solo se guardan fecha|Only time, band and valid|Observa\. Compara\. Entiende\.|Observe\. Compare\. Understand\./);
assert.doesNotMatch(analyzer, /Gráfica de muestras válidas|Graph of valid samples|CoreTelephony · Tipado · Lectura pasiva/);
assert.doesNotMatch(analyzer, /Mediciones LTE pasivas · Sin modificar|Passive LTE measurements · No band/);
assert.match(analyzer, /self\.statusLabel\.hidden = YES/);
assert.match(analyzer, /self\.statusLabel\.hidden = NO/);
assert.match(analyzer, /BLAnalyzerHistoryKey/);
assert.match(analyzer, /appendMeasurement:serving source:@"live"/);
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
const countryBands = read('app/BLCountryBandsViewController.m');
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
assert.match(info, /if \(section == 0\) return 4/);
assert.match(info, /if \(section == 1\) return 1/);
assert.match(info, /unavailable5GCellWithTitle:/);
assert.match(info, /No compatible/);
assert.match(info, /BLDeviceIsKnownLTEOnly\(\) && \(indexPath.section == 1 \|\| indexPath.row == 3\)/);
assert.match(info, /Toca cada fila para marcar o desmarcar/);
assert.match(info, /UITableViewCellAccessoryCheckmark/);
assert.match(cc, /BLDeviceIsKnownLTEOnly\(\)/);
assert.match(cc, /A saved preference is not a modem readback/);
assert.doesNotMatch(cc, /_CTServerConnectionSetRATSelection|bl_setRATDirect|BLCTServerConnectionCreateFn/,
  'CC must never have a direct CoreTelephony RAT setter');
assert.doesNotMatch(main, /No se puede verificar el modo actual en iOS 18/);
assert.doesNotMatch(main, /if \(!\[allowed containsObject:previous\]\)/);
assert.match(cc, /BOOL readOnly18 = \[NSProcessInfo processInfo\]\.operatingSystemVersion\.majorVersion >= 18/);
assert.match(cc, /Se comprobará la compatibilidad/);
assert.match(cc, /\[self bl_applyMode:mode\]/);
assert.match(cc, /NSMutableArray<NSString \*> \*modes = \[NSMutableArray arrayWithObject:@"automatic"\]/);
for (const mode of ['2g','3g','lte']) {
  assert.match(cc, new RegExp('if \\(BLCCShow' + (mode === 'lte' ? 'LTE' : mode.toUpperCase()) + '\\\(\\\)\\\) \\\[modes addObject:@"' + mode + '"\\\]'));
}
assert.match(cc, /self\.statusRefreshNotBefore = CFAbsoluteTimeGetCurrent\(\) \+ 20\.0/);
assert.match(cc, /\.tv_sec = ios18 \? \(backgroundStatus \? 3 : 12\) : 30/);
assert.match(main, /@\[@"apply_nr", @"scan_start"\] containsObject:command/);
const statusHandler = main.slice(main.indexOf('if ([command isEqualToString:@"status"])'),
                                 main.indexOf('if ([command isEqualToString:@"rat"])'));
assert.match(statusHandler, /operatingSystemVersion\.majorVersion >= 18/);
assert.match(statusHandler, /\[manager queryCoreTelephonyForPassiveObservation\]/,
  'iOS18 status must not call unreliable RAT getters from the CC module');
console.log('BandLock rhui6 hardware 5G, CC UI and iOS18 read-only protections: PASS');

// rhui8: signal diagnostics are strictly passive and model-gated for NR.
assert.match(core, /BOOL supportsNR = !BLDeviceIsKnownLTEOnly\(\)/);
assert.match(core, /if \(\[legacy\[@"rat"\] isEqualToString:@"NR"\] && !supportsNR\) continue/);
assert.match(core, /@"supports_nr": @\(supportsNR\)/);
assert.match(core, /Only label typed metrics as NR when an actual serving NR row/);
assert.match(scan, /#import "\.\.\/\.\.\/BLHardwareCapabilities\.h"/);
assert.match(passive, /\(\[rat isEqualToString:@"NR"\] && !supportsNR\)/);
assert.match(passive, /band\.integerValue > \(\[rat isEqual:@"NR"\] \? 1024 : 255\)/);
assert.match(passive, /BLPassiveCellMatches\(previous, measurement\)/);
assert.match(analyzer, /@"5G"/);
assert.doesNotMatch(app, /@"API: "|@"legacy %@/);
assert.match(analyzer, /@"timestamp": @\(\[NSDate date\]\.timeIntervalSince1970\), @"rat": rat/);
assert.match(analyzer, /bandlock\.cell-signal-history\.v3/);
assert.match(main, /@"unsupported_modem_write": @YES/);
assert.doesNotMatch(main, /if \(!\[allowed containsObject:previous\]\)/);
assert.doesNotMatch(passive, /setActiveBandInfo|setRatSelection:|BLScanWriteJournal/);
assert.match(scan, /!\[journalPath hasPrefix:\[directoryPath stringByAppendingString:@"\/"\]\]/);
console.log('BandLock rhui8 NR diagnostics, concise UI, dynamic paths, guarded mode writes: PASS');

// rhui9: unknown RAT selections are not user-visible "?" or verified mode.
assert.doesNotMatch(cc, /text = @"\?"/);
assert.doesNotMatch(cc, /text = @"Red"/);
assert.match(cc, /_currentModeCode = @"automatic"/);
assert.match(cc, /_confirmedModeCode = nil/);
assert.match(cc, /if \(uncertain\) \{/);
assert.match(cc, /\[result\[@"verification_pending"\] boolValue\]/);
assert.match(main, /@"verification_pending": @YES/);
assert.doesNotMatch(main, /@"No se pudo verificar el cambio de modo"/);
assert.doesNotMatch(main, /for \(NSUInteger attempt = 0; attempt < \(isIOS18 \? 3 : 1\); attempt\+\+\)/);
assert.match(core, /static NSString \*BLRHSignalRAT\(NSString \*raw\)/);
for (const technology of ['GSM','GPRS','EDGE','WCDMA','UMTS','HSPA']) {
  assert.match(core, new RegExp('"'+technology+'"'));
}
for (const metric of ['rscp','ecno']) {
  assert.match(core, new RegExp('@"'+metric+'"'));
  assert.match(app, new RegExp('@"'+metric+'"'));
  assert.match(analyzer, new RegExp('@"'+metric+'"'));
}
assert.match(passive, /\[rat isEqualToString:targetRAT\]/);
assert.match(passive, /@"target_rat": targetRAT/);
assert.match(passive, /BLPassiveMaxRows/);
assert.doesNotMatch(passive, /writeLTEBands|writeNRBands|BLScanWriteJournal|setRatSelection|setActiveBandInfo/);
assert.match(analyzer, /@"3G"/);
assert.match(analyzer, /@"2G"/);
assert.match(analyzer, /latestBand &&/);
console.log('BandLock rhui9 nonmisleading mode state, 2G–5G passive diagnostics: PASS');

// rhui10 fixes the non-UI regression without running an active modem test.
const ratContextStart = core.indexOf('- (NSDictionary *)queryContextForRatChange');
const ratContextEnd = core.indexOf('- (NSDictionary *)queryCoreTelephonyWithRatSelection:', ratContextStart);
assert.ok(ratContextStart >= 0 && ratContextEnd > ratContextStart);
const ratContext = core.slice(ratContextStart, ratContextEnd);
assert.doesNotMatch(ratContext, /getBandInfo|readRatSelectionFromClient|getRatSelectionMask/);
const setterStart = core.indexOf('- (BOOL)setRatSelectionSync:');
const setterEnd = core.indexOf('- (void)setNetworkModeSelection:', setterStart);
assert.match(core.slice(setterStart, setterEnd), /\[self queryContextForRatChange\]/);
assert.doesNotMatch(core.slice(setterStart, setterEnd), /\[self queryCoreTelephony\]/);
assert.match(main, /RAT callback accepted; modem selection remains unverified/);
assert.doesNotMatch(main, /for \(NSUInteger attempt = 0; attempt < \(isIOS18/);
assert.match(core, /callbackError.code == EAGAIN/);
assert.match(core, /if \(!bandInfo && includeRatSelection\) return/);
assert.match(core, /@"bandInfo": bandInfo \?: NSNull\.null/);
assert.match(cc, /_currentModeCode = @"automatic"/);
assert.doesNotMatch(cc, /text = @"(?:Red|\?)"/);
assert.match(main, /\[command isEqualToString:@"scan_observe_start"\]/);
assert.match(main, /@"rat"\]/);
for (const [rat, display] of [['AUTO','Auto'], ['2G','2G'], ['3G','3G'], ['LTE','4G'], ['NR','5G']]) {
  assert.match(manager, new RegExp('@"' + rat + '"'));
  assert.match(analyzer, new RegExp('@"' + display + '"'));
}
assert.match(analyzer, /NSArray \*rats = @\[@"AUTO", @"2G", @"3G", @"LTE", @"NR"\]/);
assert.match(passive, /\[targetRAT isEqualToString:@"AUTO"\] \|\|/);
assert.match(passive, /No se ha observado señal/);
assert.match(app, /\[weakSelf\.signalTimer invalidate\]/);
assert.match(app, /if \(!weakSelf\.signalRunning && !weakSelf\.signalRecoveryRequired\)/);
assert.doesNotMatch(passive, /writeLTEBands|writeNRBands|setRatSelection|BLScanWriteJournal/);
console.log('BandLock rhui10 RAT regression isolation and independent 2G–5G read-only scans: PASS');

// rhui12: keep accepted user intent visible on iOS18 and make the four
// diagnostic buttons technology-directed. Exhaustive band writes are allowed
// only when CTBandInfo exposes a live supported/active inventory; otherwise the
// scanner falls back to real serving/neighbor observations.
assert.match(cc, /@property \(nonatomic, copy\) NSString \*pendingModeCode/);
assert.match(cc, /self\.pendingModeCode = requestedMode/);
assert.match(cc, /self\.currentModeCode = verified \? confirmed : requestedMode/);
assert.match(cc, /if \(!verified && self\.pendingModeCode\.length\)/);
assert.match(cc, /BLCCSetLastModeCode\(requestedMode\)/);
assert.match(cc, /result\[@"accepted_mode"\]/);
assert.match(cc, /normalizedAccepted/);
assert.match(main, /\[command isEqualToString:@"scan_technology_start"\]/);
assert.match(main, /BLRememberAcceptedModeCode\(mode\)/);
assert.match(main, /if \(acceptedMode\.length\) payload\[@"accepted_mode"\] = acceptedMode/);
assert.match(main, /BLRecentAcceptedModeCode\(\)/);
assert.match(core, /- \(BOOL\)setModeCodeSync:/);
for (const mapping of ['2g', '3g', 'lte', '5g-auto', '5g-on', '5g-only']) {
  assert.match(core, new RegExp('isEqualToString:@"' + mapping.replace('-', '\\-') + '"'));
}
assert.match(manager, /startTechnologySignalScanForRAT:/);
assert.match(analyzer, /startTechnologySignalScanForRAT:rat/);
assert.match(analyzer, /frecuencias de referencia/);
assert.match(technologyScan, /BLScanWriteJournal\(journal\)/);
assert.match(technologyScan, /@"version": hasBandBaseline \? @3 : @2/);
assert.match(technologyScan, /original_band_config/);
assert.match(technologyScan, /setModeCodeSync:targetMode/);
assert.match(technologyScan, /BLScanSingleActiveLine\(preflight\)/);
assert.match(technologyScan, /BLMergeObservedBand\(byBand, measurement, targetRAT, allowedFrequencies\)/);
assert.match(technologyScan, /supportedBandsForTargetRAT:targetRAT/);
assert.match(technologyScan, /activeBandsForTargetRAT:targetRAT/);
assert.match(technologyScan, /writeBands:@\[band\] forTargetRAT:targetRAT/);
assert.match(technologyScan, /readback_unverified/);
assert.match(technologyScan, /candidates\.count <= 64/);
assert.match(technologyScan, /Tiempo máximo del barrido agotado/);
assert.match(technologyScan, /BLScanHasConflictingServingRAT\(manager, writeQuery, targetRAT\)/);
assert.match(technologyScan, /!exhaustive && sample < BLTechnologyScanSamples/);
assert.match(scan, /\[saved\[@"version"\] isEqual:@3\]/);
assert.match(scan, /writeBands:originalBands\s+forTargetRAT:targetRAT/);
assert.match(scan, /BLScanBandConfigurationMatches\(manager, readback, originalConfiguration\)/);
assert.match(scan, /if \(!serviceRestored\)/);
assert.match(scan, /if \(!BLScanClearJournal\(\)\)/);
assert.match(scan, /BLDeviceIsKnownLTEOnly\(\)/);
assert.match(technologyScan, /target_frequencies_mhz/);
assert.match(technologyScan, /eligible\.count && originalBandConfiguration/);
assert.match(scan, /BLReferenceFrequencyForMeasurement/);
assert.match(scan, /allowedFrequencies containsObject:referenceFrequency/);
assert.match(scan, /No hay bandas exactas del país compatibles con el inventario del módem/);
assert.match(scan, /n >= 10562 && n <= 10838/);
assert.match(scan, /n >= 2937 && n <= 3088/);
assert.match(scan, /n >= 512 && n <= 810/);
assert.match(analyzer, /@"ARFCN"/);
assert.match(analyzer, /@"UARFCN"/);
assert.doesNotMatch(analyzer, /\[rat isEqualToString:@"LTE"\] \|\| \[rat isEqualToString:@"3G"\]/,
  '3G must never reuse LTE band metadata');
assert.doesNotMatch(countryProfile, /iso2.*ES.*2G/s,
  '2G/3G country data must not be hard-coded only for Spain');
assert.match(countryProfile, /CoreTelephony uses a private numeric namespace for GSM\/UTRAN/);
assert.match(countriesController, /BLAllCountryRecords/);
assert.ok(countrySpectrum.countries.length >= 220, 'Country spectrum should cover at least 220 markets');
const esSpectrum = countrySpectrum.countries.find(country => country.iso2 === 'ES');
assert.deepEqual(esSpectrum?.frequencies_mhz?.['2G'], [900, 1800]);
assert.deepEqual(esSpectrum?.frequencies_mhz?.['3G'], [900, 2100]);
assert.equal(countrySpectrum.source?.name, 'MCC-MNC.org networks bulk export');
assert.match(main, /band_inventory_diagnostic/);
assert.match(scan, /Sanitized CTBandInfo inventory/);
assert.match(metadata, /@10:\s+@\{@"frequency": @"AWS 1700\/2100 MHz"/);
assert.match(metadata, /@44:\s+@\{@"frequency": @"700 MHz \(703–803\)"/);
assert.match(analyzer, /setTitle:@"5G —" forSegmentAtIndex:4/);
assert.match(analyzer, /UIControlStateDisabled/);
assert.match(analyzer, /startPassiveSignalObservationForRAT:@"AUTO"/);
assert.match(analyzer, /!\[row\[@"role"\] isEqualToString:@"serving"\]/);
assert.match(analyzer, /BLAnalyzerSignalProgress/);
assert.match(analyzer, /viewWithTag:711/);
assert.match(analyzer, /viewWithTag:715/);
assert.match(analyzer, /UIColor\.systemYellowColor/);
assert.match(analyzer, /@"ARFCN"/);
assert.match(analyzer, /@"EARFCN"/);
assert.match(analyzer, /@"UARFCN"/);
assert.match(analyzer, /BLAnalyzerReferenceFrequencyForRow/);
assert.match(scan, /registrationWaits = \[targetRAT isEqualToString:@"3G"\] \? 24 : 12/);
assert.match(technologyScan, /if \(wait \+ 1 < registrationWaits\)/);
assert.match(scan, /El cambio a 3G fue aceptado/);
assert.match(passive, /Observando la red actual en Auto/);
assert.match(passive, /\[role isEqualToString:@"neighbor"\] \|\| \[role isEqualToString:@"secondary"\]/);
assert.match(passive, /@"total": @12/);
assert.match(passive, /samplesCompleted = sample \+ 1/);
assert.match(passive, /BLPassiveCellMatches/);
assert.match(passive, /BLEnrichPassiveCell/);
assert.doesNotMatch(passive, /if \(rows\.count >= BLPassiveMaxRows\) break;/,
  'Auto must keep sampling to enrich already-known cells even when the visible row cap is reached');
assert.match(passive, /autoLegacyLTEAuxiliary/);
assert.match(core, /rangeOfString:@"Secondary"/);
assert.match(core, /@"cell_type_raw"\] = type/);
assert.match(core, /@"legacy_cell_types"/);
assert.match(analyzer, /carrierAggregationSummaryForMeasurements/);
assert.match(analyzer, /SECUNDARIA LTE/);
assert.match(analyzer, /Posible CA/);
assert.match(analyzer, /Guardar Captura/);
assert.match(analyzer, /Ver capturas guardadas/);
assert.match(analyzer, /exportActions\.axis = UILayoutConstraintAxisVertical/);
assert.match(analyzer, /titleLabel\.numberOfLines = 2/);
assert.doesNotMatch(analyzer, /COMPARATIVA POR BANDA|BAND COMPARISON/);
assert.doesNotMatch(analyzer, /panelWithTitle:BLT\(@"HISTORIAL"/);
assert.match(analyzer, /Borrar mediciones/);
assert.match(app, /Cambiar país/);
assert.match(app, /Frecuencias del país/);
assert.match(app, /#import "BLCountriesViewController\.h"/);
assert.match(app, /countryValue\.text = countryName/);
assert.match(app, /ensureBandStateThen:/);
assert.match(app, /titleLabel\.numberOfLines = 2/);
assert.doesNotMatch(app, /Pulsa «Actualizar estado» antes de gestionar las frecuencias del país/);
assert.doesNotMatch(app, /Pulsa «Actualizar estado» antes de editar bandas/);
assert.match(countryDetail, /Usar este país/);
assert.match(countryDetail, /Se comprobará automáticamente/);
assert.match(countryDetail, /\[self\.manager refreshWithCompletion:/);
assert.doesNotMatch(countryDetail, /Actualizar desde Control primero|Pulsa «Actualizar estado» en Control/);
assert.match(countriesController, /BLSelectedCountryISO/);
assert.match(countriesController, /UITableViewCellAccessoryCheckmark/);
assert.match(info, /Información sobre las frecuencias/);
assert.doesNotMatch(info, /Más información sobre las frecuencias/);
assert.match(app, /backButtonTitle = BLT\(@"Atrás", @"Back"\)/);
assert.match(countryBands, /show5G = self\.manager\.supports5G && self\.availableNRBands\.count > 0/);
assert.match(countryBands, /numberOfSectionsInTableView:[\s\S]*self\.show5G \? 6 : 5/);
assert.match(countryBands, /if \(section == 0\) return self\.show5G \? 4 : 2/);
assert.match(countryBands, /return self\.show5G \? @"5G NR" : nil/);
assert.match(analyzer, /\[BLAnalyzerCaptureStore displayMode:\[self currentCaptureMode\]\]/);
assert.doesNotMatch(analyzer, /displayCaptureMode:/);
assert.match(analyzer, /UIGraphicsImageRenderer/);
assert.match(captureStore, /UIImagePNGRepresentation/);
assert.match(analyzer, /currentScanMeasurements/);
assert.match(core, /BLOperatorNameFromNetworkInfo/);
assert.match(core, /dataServiceIdentifier/);
assert.match(core, /serviceSubscriberCellularProviders/);
assert.match(core, /carrierName/);
assert.match(core, /@"operator_name"/);
assert.doesNotMatch(core, /allValues\.firstObject|providers\.allValues/,
  'Operator name must be resolved from the current data service, never the first configured SIM/eSIM');
assert.match(captureStore, /BLAnalyzerCaptureIndexKey/);
assert.match(captureStore, /BLAnalyzerCaptureDirectoryName/);
assert.match(captureStore, /NSApplicationSupportDirectory/);
assert.match(captureStore, /#import "BLCommon\.h"/);
assert.match(captureStore, /dd\/MM\/yy HH:mm:ss/);
assert.match(capturesController, /Capturas guardadas/);
assert.match(capturesController, /#import "BLCommon\.h"/);
assert.match(capturesController, /Compartir captura/);
assert.match(capturesController, /Eliminar captura/);
assert.match(capturesController, /operator_name/);
assert.match(read('app/Makefile'), /BLAnalyzerCaptureStore\.m/);
assert.match(read('app/Makefile'), /BLAnalyzerCapturesViewController\.m/);
for (const stale of [
  'captureTabsScroll', 'captureTabsStack', 'rebuildCaptureTabs', 'captureTabTapped',
  'captureViewerScroll', 'captureViewerStack', 'showCaptureAtIndex',
  'captureShareTapped', 'captureDeleteTapped'
]) {
  assert.doesNotMatch(analyzer, new RegExp(stale));
}
assert.match(analyzer, /Operador móvil/);
assert.match(captureStore, /En vivo/);
assert.doesNotMatch(analyzer, /Guardar PNG|Compartir PNG|CoreTelephony|módem|modem|diagnóstico|diagnostic/i);
assert.doesNotMatch(capturesController, /CoreTelephony|módem|modem|daemon|socket|diagnóstico|diagnostic|API/i);
assert.doesNotMatch(manager, /BandLock usa un daemon|BandLockDaemon cerró|No se pudo conectar con BandLockDaemon|La ruta del socket del daemon no es válida/i);
assert.match(manager, /BLFriendlyResultMessage/);
assert.match(manager, /BLResultForUserInterface/);
assert.match(manager, /No se pudo leer la señal/);
assert.match(manager, /Restaurando la configuración anterior/);
assert.match(delegate, /UITabBarAppearance/);
assert.match(delegate, /configureWithOpaqueBackground/);
assert.match(delegate, /scrollEdgeAppearance = tabAppearance/);
assert.match(delegate, /tabBar\.translucent = NO/);
assert.match(analyzer, /scroll\.bottomAnchor constraintEqualToAnchor:self\.view\.safeAreaLayoutGuide\.bottomAnchor/);
assert.match(capturesController, /scroll\.bottomAnchor constraintEqualToAnchor:self\.view\.safeAreaLayoutGuide\.bottomAnchor/);
assert.match(scan, /measured_frequency_unknown/);
assert.match(scan, /BLScanStatusIsMeasured/);
assert.match(scan, /psc \? @\(2000000LL \+ psc\.longLongValue\)/);
assert.match(scan, /cellID \? @\(4000000LL \+ cellID\.longLongValue\)/);
assert.match(analyzer, /MEDIDA · FREC\. DESCONOCIDA/);
assert.doesNotMatch(passive, /setModeCodeSync|writeBands:/,
  'Auto observation must stay read-only and never write RAT/bands');
console.log('BandLock rhui24 UI copy, LTE-only country frequencies and rhui23 regression gates: PASS');
console.log('BandLock rhui12 pending RAT intent and technology-directed all-band diagnostics: PASS');

// rhui12: coalesce rapid Control Center taps, and never automatically drain
// the queued mode after a failed CommCenter setter.
assert.match(cc, /@property \(nonatomic, assign\) BOOL modeWriteInFlight/);
assert.match(cc, /if \(self\.modeWriteInFlight\)\s*\{\s*self\.queuedModeCode = requestedMode;\s*return;/);
assert.match(cc, /if \(success && queued\.length && !\[queued isEqualToString:requestedMode\]\)/);
assert.match(cc, /else if \(!success && epoch != self\.stateEpoch\)/);
assert.doesNotMatch(cc, /if \(!success && queued\.length\)\s*\[self bl_applyModeThroughDaemon:/);
assert.match(core, /BLRatWriteQuietPeriod = 6\.0/);
assert.match(core, /dispatch_semaphore_wait\(gate, DISPATCH_TIME_FOREVER\)/);
assert.match(core, /callbackError\.code == EAGAIN/);

// The recovery path must restore the modified RAT, request original mode
// regardless of transient band readback, then prove both before clearing.
const recoveryStart = scan.indexOf('- (BOOL)restoreJournalWithManager:');
const recoveryEnd = scan.indexOf('- (void)recoverIfNeededWithManager:', recoveryStart);
assert.ok(recoveryStart >= 0 && recoveryEnd > recoveryStart);
const recovery = scan.slice(recoveryStart, recoveryEnd);
assert.match(recovery, /writeBands:originalBands\s+forTargetRAT:targetRAT/);
assert.doesNotMatch(recovery, /\[manager restoreBandConfiguration:/);
assert.ok(recovery.indexOf('writeBands:originalBands') < recovery.indexOf('setModeCodeSync:restoreMode'));
assert.match(recovery, /check < 60/);
assert.match(recovery, /if \(\[saved\[@"version"\] isEqual:@3\] && !bandsRestored\)/);
assert.match(recovery, /if \(!serviceRestored\)/);
assert.ok(recovery.indexOf('if (!serviceRestored)') < recovery.indexOf('if (!BLScanClearJournal())'));
assert.match(recovery, /journal cleared after positive verification/);
console.log('BandLock rhui12 RAT single-flight and staged recovery safety: PASS');

// rhui13: recovery must be able to escape a detached 3G-only state. The same
// subscription fingerprint remains mandatory, and multiple registered RATs or
// active contexts are still rejected; only the zero-registered-RAT transition
// is tolerated while the saved Auto/LTE mode is being restored.
assert.match(scan, /static BOOL BLScanRecoveryIdentityCompatible/);
assert.match(scan, /rat && rat\.count > 1/);
assert.match(scan, /activeCount > 1/);
assert.match(recovery, /!BLScanRecoveryIdentityCompatible\(identity, subscription\)/);
assert.match(recovery, /!BLScanRecoveryIdentityCompatible\(readback, subscription\)/);
assert.doesNotMatch(recovery, /if \(!BLScanSingleActiveLine\(identity\)\)/);
assert.match(recovery, /check < 60/);
assert.match(recovery, /dentro de 60 s/);
console.log('BandLock rhui13 detached-RAT recovery gate: PASS');

// rhui14: restore the 1.5 LTE selection workflow on iOS18. LTE apply keeps
// the scan/recovery exclusion and daemon-side subset/readback validation; only
// NR writes and the obsolete two-band experiment stay blocked by the iOS18 gate.
assert.match(app, /Aplicar selección/);
assert.match(app, /self\.applyLTEButton\.hidden = NO/);
assert.match(app, /self\.restoreLTEPreviousButton\.hidden = NO/);
assert.match(app, /self\.restoreLTEAllButton\.hidden = NO/);
const ios18GateStart = main.indexOf('if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18');
const ios18GateEnd = main.indexOf('if ([command isEqualToString:@"signal_probe"]', ios18GateStart);
assert.ok(ios18GateStart >= 0 && ios18GateEnd > ios18GateStart);
const ios18Gate = main.slice(ios18GateStart, ios18GateEnd);
assert.doesNotMatch(ios18Gate, /@"apply"/);
assert.match(ios18Gate, /@"apply_nr"/);
assert.match(main, /\[command isEqualToString:@"apply"\]/);
const applyStart = main.indexOf('if ([command isEqualToString:@"apply"])');
const applyEnd = main.indexOf('if ([command isEqualToString:@"apply_nr"])', applyStart);
assert.ok(applyStart >= 0 && applyEnd > applyStart);
const applyHandler = main.slice(applyStart, applyEnd);
assert.match(applyHandler, /passiveApplyQuery/);
assert.match(applyHandler, /queryCoreTelephonyForPassiveObservation/);
assert.match(applyHandler, /requestedSet/);
assert.match(applyHandler, /matches = \[requestedSet isEqualToSet:/);

// rhui14: a verified single-band mask may supply the missing band identity for
// a same-RAT typed signal sample. Prioritize the already-serving band, wait a
// longer bounded window, and make no-signal/error rows explicit instead of
// rendering bare band numbers with no explanation.
assert.match(scan, /static BOOL BLScanHasAnyMetric/);
assert.match(scan, /initialObservedBands/);
assert.match(scan, /BLSortedBands\(initialObservedBands\.allKeys\)/);
assert.match(scan, /reportedBand && !\[reportedBand isEqual:band\]/);
assert.match(scan, /band_inferred_from_active_mask/);
assert.match(scan, /sample < 8/);
assert.match(scan, /measured_pre_sweep/);
assert.match(app, /Registrada sin métrica/);
assert.match(app, /Sin señal/);
assert.match(app, /Banda no verificada/);
assert.match(app, /value\.doubleValue, dbm \? @"dBm" : @"dB"/);
assert.match(app, /BLGFrequencyForBand\(band\)/);
assert.match(metadata, /@6:\s+@\{@"frequency": @"800 MHz"/);
console.log('BandLock rhui14 scan metrics and LTE apply regression checks: PASS');

// rhui15+: NetMonitor-inspired coverage Analyzer is the single measurement UI.
// It shows live serving/neighbor rows, quality categories, band details and
// technology scans, while Control keeps only the emergency recovery action.
for (const label of ['CELDAS Y PORTADORAS', 'RED Y BARRIDO', 'EVOLUCIÓN DE SEÑAL']) {
  assert.match(analyzer, new RegExp(label));
}
for (const quality of ['Excelente', 'Buena', 'Moderada', 'Mala', 'Muy mala']) {
  assert.match(analyzer, new RegExp(quality));
}
assert.match(analyzer, /row\[@"role"\] isEqualToString:@"neighbor"/);
assert.match(analyzer, /BLGFrequencyForBand\(band\)/);
assert.match(analyzer, /BLGNRFrequencyForBand\(band\)/);
assert.match(analyzer, /BLAnalyzerLastPersistedScanID/);
assert.match(analyzer, /persistCompletedScanIfNeeded:/);
assert.match(scan, /@"scan_id": scanID/);
assert.match(scan, /self\.scanState\[@"scan_id"\] = scanID/);
assert.doesNotMatch(app, /\[self\.stackView addArrangedSubview:self\.signalSection\]/);
console.log('BandLock rhui15 unified NetMonitor-style coverage Analyzer: PASS');
