# BandLock RootHide 1.5.1~rhsigdiag1

Experimental **RootHide only**, iOS 15–17. Not an official release
and not a Dopamine/rootless build. The package ID is
`com.gokuencinar.bandlock` and the architecture is `iphoneos-arm64e`.

## Why this build exists

The previous Dopamine signal test reported `LTE B20 serving RSRQ 0.0 dB`
without RSRP/RSSI. Zero legacy RSRQ is not credible evidence of a valid
measurement and cannot authorize an active scan. The old test was also
the wrong jailbreak variant for this device.

This RootHide diagnostic uses the current data subscription's
`CTServiceDescriptor` and `getSignalStrengthMeasurements:error:`
to try typed RSRP, RSRQ, RSSI and SNR, falling back to the legacy
`kCTCellMonitor*` keys if typed data is absent. No cell/SIM identifiers,
raw CT dictionaries or subscriber UUIDs are logged/exported.
Zero placeholder power/RSRQ is not shown as valid signal.

**Active band scanning is disabled.** The control titled
`Medir señal de bandas (diagnóstico)` explains this limitation rather
than changing modem settings. Read-only discovery is required before
a RootHide active scanner can safely be designed and tested.

## Tester

1. Confirm that any previous Dopamine signal scan has completed and
   restored the original bands, with no recovery journal pending.
   Do not replace a package during recovery.
2. Install `com.gokuencinar.bandlock_1.5.1~rhsigdiag1_iphoneos-arm64e.deb`
   into the **RootHide jailbreak environment**, not into standard
   Dopamine or a non-jailbroken root filesystem. It is an upgrade of
   stable RootHide BandLock and is not side-by-side installable.
3. Open BandLock, select **Consultar intensidad (RootHide)**.
   The diagnostic does **not** interrupt cellular service.
4. Return screenshots/text of the `API:` status, the
   `legacy RSRP/RSRQ/RSSI/SNR:` statuses and the sanitized measurement
   list, plus iPhone model/iOS/RootHide version. Never share ICCID,
   IMEI, phone numbers or a raw modem dump.
5. If values are missing, don't force a band switch. The next
   experiment should target the appropriate private API or actual
   diagnostic source rather than treating placeholder zero as signal.

To return to stable BandLock, install the official RootHide 1.5 package
after any experimental diagnostics are complete.
