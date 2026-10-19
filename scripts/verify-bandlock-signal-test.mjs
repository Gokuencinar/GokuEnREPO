import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const root = 'tweaks/BandLock/build/BandLock-1.0-Dopamine/';
const read = p => readFileSync(root + p, 'utf8');
const scan = read('daemon/BLSignalScan.m');
const core = read('daemon/BLTelephonyCore.m');
const daemon = read('daemon/main.m');
const app = read('app/BLControlViewController.m');
const control = read('control');
const journal = [
  /signal-scan-recovery\.plist/,
  /O_WRONLY \| O_CREAT \| O_EXCL, 0600/,
  /fsync\(fd\)/,
  /rename\(temp\.fileSystemRepresentation, BLScanJournal\.fileSystemRepresentation\)/,
  /fsync\(directory\)/,
  /BLScanClearJournal/,
  /BLScanMatches\(\[manager activeLTEFromQuery:/,
  /\[self restoreJournalWithManager:manager\]/,
  /if \(!BLScanWriteJournal\(journal\)\)/,
  /if \(!BLScanWriteJournal\(step\)\)/,
];
for (const rule of journal) assert.match(scan, rule, `Missing crash-recovery guarantee: ${rule}`);
assert.match(scan, /BLScanMaxBands = 2/, 'First hardware trial must be bounded to 2 LTE bands');
assert.match(scan, /servingPower/, 'No active scan without proven LTE signal metrics');
assert.match(scan, /BLGDuplexForBand/, 'Exclude SDL-only LTE');
assert.match(scan, /cancelRequested/, 'Cancel must be acknowledged');
assert.match(daemon, /scan_start/);
assert.match(daemon, /scan_status/);
assert.match(daemon, /scan_cancel/);
assert.match(daemon, /scan_recover/);
assert.match(daemon, /\[scan hasPendingRecovery\]/, 'All modem writes must be gated on recovery');
assert.match(daemon, /#if BL_SIGNAL_SCAN_TEST && !BL_VARIANT_ROOTFUL/, 'Rootful must not enable scanner');
assert.match(core, /signalMeasurementsFromCellInfo:/, 'Read-only signal parser is required');
for (const key of ['rsrp', 'rsrq', 'rssi', 'sinr']) assert.match(core, new RegExp('@"' + key + '"'));
for (const denied of ['CellId', 'MCC', 'MNC', 'PCI', 'TAC', 'EARFCN']) {
  assert.ok(!core.slice(core.indexOf('static NSDictionary *BLSignalMeasurementFromLegacyRow'), core.indexOf('@interface BLTelephonyManager ()')).includes('@"' + denied + '"'),
    'Signal parser must not export subscriber/cell IDs: ' + denied);
}
assert.match(app, /Medir señal de bandas/);
assert.match(app, /Posible pérdida de servicio/);
assert.match(app, /signalCancelTapped:/);
assert.match(control, /^Version: 1\.5\.1~sigtest1$/m);
console.log('BandLock signal scan static regression checks: PASS');
