# BandLock 1.6.0~rhui1 — RootHide LTE Analyzer UI preview

**Experimental branch only:** `bandlock-1.5-roothide-signal-test`; do not publish as a stable package.

## New UI

- Control: gradient hero summarizing current network and serving band, rounded cards and clearer hierarchy. Existing LTE/5G controls, restoration and security warnings are left intact.
- Analyzer: separate fourth tab with a dark technical dashboard, read-only typed LTE serving RSRP/RSRQ/RSSI/SNR when available, last-band RSRP trace, and per-observed-band arithmetic mean with sample counts. **Cross-band means are descriptive historical observations, not controlled comparisons of RF performance**; samples may be taken at different places and times.
- Manual single-sample reading; optional 12-second monitor that ends when leaving the page. No continuous background daemon polling.
- Local history bounded to 300 measurements, limited to timestamp, band and four valid signal metrics. Explicit delete and share controls. No SIM IDs, cell IDs, raw subscription identifiers, or coordinates are persisted.
- A failed or absent typed signal value is shown as unavailable, not zero. Only a typed serving LTE row is accepted.

## Radio safety and performance

- Analyzer invokes only `signal_probe`. It never calls LTE/NR band setters, RAT setters or an active/passive scan. The daemon serves `signal_probe` using `queryCoreTelephonyForPassiveObservation` so the broken RAT-selection getter cannot delay read-only signal samples.
- Active band scan remains in the original UI, gated by LTE-only verification, subscriber consistency, RSRP checks and recovery journal. Never weaken or use this in routine tests.
- Nothing here establishes 5G NR signal support. Existing 5G controls are preserved unchanged.
- Keep `firmware <= 17.0` in this experimental package. The **new user device is an iPhone 11 Pro**, reported elsewhere as iOS **18.7.1 RootHide**, but actual iOS, architecture and bridge state must be verified live before any future compatibility work. **Do not install this build on iOS 18**.
- The `jb-p1lot` client currently discovers a paired Bonjour entry `Iphone-11-Pro.local` but `device_status` reports `bridgeError: unavailable`. Reachability of SSH and TCP 5912 on `192.168.1.116` does not prove the bridge is authorized or healthy. Never pair a fresh identity without explicit confirmation.

## Acceptance checklist

1. Regression script and clean experimental macOS CI build pass.
2. Old LTE/5G control screens and Control Center module still compile.
3. No jailbreak device installation until OS/package compatibility is established and a recovery journal is ruled out.
4. On compatible hardware, verify Analyzer displays only real typed LTE signal and no fabricated bands, and that history/purge/export works.
5. Re-read allowed LTE masks before and after any on-device read-only test, check daemon, and confirm no recovery journal.
