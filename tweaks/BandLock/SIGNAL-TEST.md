# BandLock 1.5 signal test 1 (Dopamine only)

This is an **experimental, device-untested diagnostic**. It is not a
BandLock 1.5 public update and must never be published to the APT repo.

## Test scope

- The **Read signal** button only reads CoreTelephony information. No
  network configuration is changed. Missing metrics are displayed as
  unavailable rather than inferred.
- The **Measure band signal (TEST)** button is explicitly opt-in, and
  runs *only when an LTE serving cell with a valid RSRP/RSSI reading
  and reported serving band is available*. It tests at most two bands:
  the serving band and another modem-supported, non-SDL LTE band.
  It requires **LTE / 4G only mode** to have been selected manually
  before starting. It does not scan 5G SA/NSA bands, change the RAT,
  or modify NR bands.
- The daemon persists the original LTE selection in a dedicated,
  write-ahead recovery journal with fsync **before** changing anything.
  It restores the original allowed LTE bands on normal completion,
  cancellation, exception or daemon restart. Failed recovery is
  reported and locks out further modem-changing actions. Use
  **Recover original bands** to retry.
- No raw tower, SIM, location, or subscription identifiers are exported.
  Unknown values are deliberately left blank. Measurements rely on
  undocumented CoreTelephony keys and have **not been validated on
  iOS 17 hardware**.

## Tester precautions

1. Back up settings and keep a second phone available. Do **not** test
   during calls, while relying on mobile data, or in an emergency.
   Service and emergency calling **may be lost**. Use a single active
   cellular line; dual-SIM recovery is unvalidated.
2. Install the Dopamine-only `1.5.1~sigtest1` .deb via Sileo/Filza.
   **This upgrades/replaces the installed stable Dopamine package**;
   it cannot coexist under the same package ID. The public repo
   remains at BandLock 1.5.
3. Start with **Read signal (no interruption)**. If no real LTE serving
   RSRP/RSSI is available, do **not** run the active scan.
4. With **LTE / 4G only** network mode, tap **Measure band signal
   (TEST)**, read the outage warning, and confirm. You can tap
   **Cancel scan and restore**; cancellation may be delayed while a
   private CoreTelephony call completes. Wait for **complete** and
   confirm the original allowed LTE bands and normal service.
5. If the screen says `recovery_required`, choose **Recover original
   bands**. If that cannot restore service, stop experimenting and
   use known recovery steps for the device/jailbreak or restore the
   original saved band configuration. A daemon restart may trigger a
   recovery attempt, but radio restoration is not guaranteed.
6. Send sanitized screenshots of the results, along with iPhone
   model, iOS version, jailbreak, active LTE band, and whether the
   original configuration was restored. Do not share SIM identifiers.

**Never replace or downgrade the package while a scan is active or
`recovery_required` is shown.** First wait for successful restoration,
and verify normal coverage and original allowed bands. Only then install
the regular **1.5** package to return to the stable version. Because
the test version is `1.5.1~sigtest1`, a package manager may require an
explicit downgrade.
