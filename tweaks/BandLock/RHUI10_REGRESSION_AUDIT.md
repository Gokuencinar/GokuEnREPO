# BandLock RootHide regression audit — 2026-11-02

Baseline: commit c520ff7 (BandLock 1.5). Installed candidate before investigation: commit 4e35d8a (1.6 rhui9). Test device: iPhone12,3, iOS 18.7.1 RootHide.

## Evidence, read-only

- jb-p1lot confirmed a connected, paired, jailbroken device.
- dpkg reported 1.6.0~rhui9. Launchctl reported the BandLock daemon running (PID 4404; active jetsam limit 6 MB).
- The on-device BandLock-daemon.log recorded repeated user RAT requests, including multiple requests handled by PID 4404. This verifies socket requests reach the daemon.
- The log records response byte counts but not the returned error payload. The exact method producing NSPOSIXErrorDomain Code=35 is **not confirmed**. CoreTelephony could return it from a getter or setter. Code 35 is temporary unavailability (EAGAIN), not proof of a read-only filesystem.
- No modem-changing commands were executed during this audit because the user cannot physically test until tomorrow.

## Differences and changes

1. In 1.5 RAT selection used the private setter on explicit user action. In rhui9, an additional iOS18 prerequisite demanded a trustworthy prior RAT readback. The old device regularly reports Unknown. Rhui10 removes this unsupported prerequisite while preserving scan/recovery exclusion.
2. In rhui9, additional full CoreTelephony queries and synchronous RAT-mask getter preceded the setter. Rhui10 uses a focused context-only query before the same setter. No band-info or RAT getter is required to obtain its context.
3. Rhui9 made up to three full post-set queries and could report a false failure when readback stayed unknown. Rhui10 treats a successful callback as an *accepted request*, with verification still pending. It neither asserts a confirmed network mode nor repeats the active write.
4. Rhui10 handles POSIX EAGAIN/35 during passive getBandInfo readback with at most three read-only calls (180 ms gaps); it does not automatically repeat RAT writes. Persistent errors show a clear explanation instead of raw NSError text.
   Passive signal observation may continue without band-info metadata when legacy/typed cell measurements exist. Actual LTE/NR band-write preparation continues to require band metadata.
5. Rhui9 showed Red when the mode was unknown. Rhui10 shows Auto as the initial/fallback glyph, without claiming this represents a confirmed modem state.
6. Rhui9 used one combined passive 2G-5G observation. Rhui10 offers four independently selected observations: 2G GSM/EDGE, 3G UMTS/HSPA, 4G LTE, and 5G NR. Each response is filtered to the requested, genuinely observed serving RAT.
7. Device logs showed recurring scan_status IPC approximately every three seconds, even after observation ended. The app had not invalidated its polling timer when scan state became idle. Rhui10 stops the timer when neither scanning nor recovering.

## Limitations

Passive observation never forces a band or RAT change and cannot measure technology not currently in service. The 5G option is displayed but disabled on the LTE-only iPhone 11 Pro. Active LTE/NR band writes remain blocked on unverified iOS18 devices; no recovery-journal semantics were changed.

Source tests and CI prove source consistency and compilation, not successful changes to physical cellular selection.

## Next-day test plan

1. Verify the Control Center defaults to Auto, never Red or question mark.
2. With coverage and no ongoing call, test Auto and LTE switching and record any exact error message and timestamp. Do not force an unavailable 2G/3G mode.
3. Confirm separate 2G, 3G, 4G and 5G diagnostics; the 5G option should be disabled on this device.
4. Run only the passive LTE observation, check measured metrics, and confirm stopping does not alter the network.
5. If EAGAIN returns, collect redacted client/daemon logs by timestamp to distinguish a read-only getter failure from the setter callback.
