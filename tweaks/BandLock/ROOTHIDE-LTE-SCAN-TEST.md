# BandLock 1.5.1~rhscan7 — RootHide LTE signal test

**Experimental. The active scan is not hardware-validated and can disrupt service.**
This builds com.gokuencinar.bandlock for RootHide, iphoneos-arm64e.
It must not be published as a stable release and must not be installed
automatically during development. Replaces the previous RootHide signal
diagnostic package (same package identifier).

## Why the scan is restricted

The iPhone XS returned real LTE B3 RSRP -121 dBm and SNR -5.5 dB
through the typed CoreTelephony API. That proves signal reading works
on the device but not that a band-changing scan or restoration works.
This version therefore requires a fresh typed RSRP at least -115 dBm
to start; at the previously observed -121 dBm it refuses to
disconnect. Do not weaken this guard.

Other preflight gates:

- User first manually selects LTE/4G-only. No automatic RAT/NR changes.
- Exactly one visible active cellular service; a stable subscription
  identifier must be available. The saved journal contains only a
  SHA-256 fingerprint, never the raw subscription identifier.
- Serving LTE band and actual RSRP must be available twice for the same
  subscription; supported LTE bands and original LTE selection must
  remain consistent. A fallback/no-service cannot count as a measurement.
- The scan tests at most two LTE bands: the serving band and one
  other supported non-SDL LTE band. Not all supported bands are
  guaranteed to be available from the serving cell/operator.

Before each write, the daemon saves the original allowed LTE mask,
known-good supported mask, mode, context fingerprint and scan state
to a 0700/0600 recovery journal inside the RootHide jbroot.
It writes and syncs the file and parent directory before the first
change. On finish/cancel/error or daemon relaunch, it attempts to
restore and verifies exact allowed-band readback. Its start/cancel/
status/recover commands are serialized. The journal blocks other
BandLock modem changes until restoration has been verified.
Package removal or upgrades with the journal present are rejected
by DEBIAN/prerm, to avoid removing the only recovery daemon.

An independent daemon timeout restarts the daemon if the scan remains
blocked for 115s; RootHide launchd normally restarts it and replays
pending recovery. This is best-effort protection, not a guarantee
against CoreTelephony, CommCenter, system crash, unavailable SIM, or
other radio failures.

## Before any physical test

1. Use a spare device/line and have another phone available. Do not
   run this during a call, while relying on mobile data or emergency
   connectivity. Even emergency calling can be interrupted.
2. Back up original band settings and ensure RootHide is responsive.
3. Ensure one SIM/line, LTE-only mode, reliable reception and RSRP at
   least -115 dBm. If the guard rejects the scan, stop. Do not disable it.
4. Tap Medir señal de bandas (2 LTE, PRUEBA), read and accept the
   service-outage warning. Press Cancelar barrido y restaurar to stop.
5. Wait for phase complete; compare the final allowed bands and
   normal coverage against the original settings. Any row without a
   real serving typed RSRP must show no_measurement.
6. If recovery_required, do not uninstall or upgrade the package.
   Press Recuperar bandas originales and wait for verification.
   If unsuccessful, follow the known device recovery procedure.
7. Return sanitized results with tested bands, RSRP/SNR, outage
   duration and the confirmation of restored band settings. Never
   share IMSI, IMEI, cell identifiers or subscription UUIDs.

## RAT mode verification (rhscan4)

In the first physical test of rhscan3, typed LTE serving readings
remained available, but the old 2-second asynchronous RAT selection
callback became unavailable during the B20 scan. The scanner stopped
with an inaccurate report of an external network-mode change, then
restored the original allowed LTE band selection.

rhscan4 first queries getRatSelectionMask:error: synchronously for a
descriptor created from the SAME current data subscription context.
It uses getRatSelection:completion: only as a legacy fallback. A
genuinely reported non-LTE selection aborts and restores immediately.
An unknown/unavailable mode is now reported as mode_unverified, with
bounded read-only retries. NO subsequent modem band write is allowed
until LTE-only mode is explicitly verified. Observed LTE service or
real RSRP alone cannot authorize another band write.

No software can guarantee restoration of cellular service on every
modem, operating-system version, or network. RootHide 1.5 public release
is unchanged.

## Passive LTE observation (rhscan6)

Physical rhscan5 telemetry proved **both** public and private RAT selection
reads return explicit_unknown, with a diagnostic mask byte of 0, while
LTE registration, typed signal and the single active data subscription
remain healthy. It is **not safe** to infer LTE-only selection or disable
the protective RAT preflight based on signal readings alone.

Therefore the separate button **Observar bandas LTE (sin desconectar)**
starts read-only samples of the modem's naturally serving LTE cell.
The daemon collects at most two *distinct* naturally serving LTE
bands over 12 bounded observations at 2-second spacing. Each record
must have a typed serving LTE band and physical power. It does not
force a band, change RAT, write LTE/NR masks or create a recovery
journal. If only one LTE band serves throughout, **one** observation
is the correct result, not invented data for an unobserved band.
The shared Cancel button stops the passive observation.

rhscan6 was physically verified on iPhone XS with one naturally observed
LTE B3 (typed RSRP -123 dBm, SNR -8 dB), unchanged allowed bands and no
recovery journal. The later B20 serving status was outside the sample
window and does NOT constitute a measured second band.

rhscan7 improves the **passive** implementation without relaxing active
scan protections: it skips redundant RAT-selection calls that returned
Unknown and could delay each sample, releases temporary CoreTelephony
objects between samples, keeps typed signal values separate from legacy
metrics, and distinguishes successful completion from interruption or
cancellation. These changes require fresh on-device validation; do not
assume the previous rhscan6 physical test validates rhscan7.

The original disruptive two-band scan remains separately labeled,
strictly requires explicit LTE-only mode verification and can refuse
to start on this iPhone until the system provides trustworthy data.

## Read-only RAT selection investigation (rhscan5)

The rhscan4 hardware result reported mode_read_status=ok while a
simultaneous status query gave mode_code=unknown. These fields are not
equivalent: CoreTelephony can successfully return an explicit Unknown
selection. rhscan5 recognizes only exact known selection constants;
unrecognized, missing and explicit-Unknown selections NEVER authorize
band writes. The existing scan still requires LTE-only mode confirmation.

The scan_line_diagnostic IPC command now returns privacy-filtered
rat_sync_kind, rat_async_kind, rat_read_status, rat_selection_kind and
other *categories*, plus a numeric mask byte solely as a diagnostic.
These report no raw subscription/SIM/cell identifiers. Mask bit
semantics are not validated for this device and cannot be used to
bypass LTE-only authorization. After installing, query this diagnostic
via the daemon before attempting any further disruptive scan.
