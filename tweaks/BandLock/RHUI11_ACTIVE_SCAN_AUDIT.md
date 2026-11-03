# BandLock RootHide rhui11 — RAT selection and technology band sweep

Date: 2026-11-03

Baseline: 1.6.0~rhui10 at commit 825e0802c8cd550d607e0a47e0e0a0961254559d.
Target device: iPhone12,3 / iOS 18.7.1 / RootHide.

## User-observed regressions

- The Control Center selection returned visually to Auto after selecting another RAT.
- A 4G diagnostic only showed the current serving LTE band (B20), because rhui10 deliberately used a passive serving-cell observation.
- The requested behavior is now technology-directed: choosing 2G/3G/4G/5G may temporarily change RAT, sweep the bands the modem exposes for that RAT, and restore the previous BandLock mode.

## Control Center correction

On iOS 18 the private RAT getter can return Unknown even after the setter callback succeeds.
Rhui10 translated this unverified response back to automatic, which erased the user's visible selection.

Rhui11 separates requested/pending mode, last confirmed mode when a trustworthy getter exists, and the initial visual Auto fallback when neither exists.

An accepted setter callback with verification_pending keeps the requested mode visible without claiming modem confirmation.

## Technology-directed scan

The diagnostic buttons now request the chosen RAT first. A scan only continues after a real serving-cell measurement of the requested technology is observed.

Before changing RAT, BandLock requires a network mode explicitly accepted by BandLock in the previous five minutes. It then writes a durable recovery journal containing that return intent, a hashed subscription identity and—when CTBandInfo is safely available—the complete supported/active band configuration captured before the RAT change.

The exhaustive path takes candidates from the modem's live supportedBands dictionary, excludes LTE SDL-only candidates, permits one band at a time, requires active-band readback before accepting measurements, records only real serving/neighbor cell metrics, marks unavailable bands without inventing values, restores the original active-band mask, and finally re-submits the previous BandLock network mode.

If a RAT exposes signal/cell data but no writable band inventory, BandLock falls back to a directed serving/neighbor observation and explicitly treats it as non-exhaustive.

## Important limitations

- A successful private setter callback is not proof that the baseband applied a RAT change. Rhui11 waits for an actual serving cell of the requested RAT before beginning the band sweep.
- 2G/3G band-by-band scanning is enabled only if this iOS/modem exposes a matching GSM/GERAN or UTRAN/UMTS/WCDMA CTBandInfo group. It is not synthesized from LTE data.
- 5G is rejected on known LTE-only hardware such as iPhone 11 Pro.
- A band can be modem-supported but unavailable from the current carrier/location. Such a step may legitimately produce no_signal.
- The scan can temporarily interrupt calls and mobile data. It must not be treated as a background passive diagnostic.

## Recovery invariant

No band write is attempted until the complete original band configuration is durably journaled. A version-3 journal is cleared only after the full active-band configuration matches the pre-scan snapshot, the previous BandLock mode request is accepted, and cellular registration converges again. If restoration cannot be established, the journal remains and the UI exposes recovery-required state.

## Validation status

Source regression checks and CI compilation validate the implementation, not real modem behavior. Hardware validation is still required for RAT application, per-band readback, measurements, cancellation and restoration.
