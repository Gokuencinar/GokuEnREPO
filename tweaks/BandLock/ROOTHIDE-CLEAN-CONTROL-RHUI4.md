# BandLock 1.6.0~rhui4 — clean Control UI

This experimental build fixes two problems reproduced on iPhone 11 Pro iOS 18.7.1:

- The long two-line serving-band header truncated on narrow iPhone screens.
  The hero now uses separate small **Network** and **Band** captions with
  single-line, scaling values.
- The pending LTE bands listing consumed most of the Control screen.
  It now displays only the count (e.g., `29 bandas`); the exact bands are
  still available through Edit bands and Network details.

Removed duplicated BandLock Global title, footer version label, redundant
descriptive subtitles and verbose normal-state warning. A short
`Solo lectura · iOS 18` remains, alongside the original runtime restrictions
in the daemon. Expanded diagnostic warnings remain available; dangerous
operations are still blocked in this iOS 18 preview.

LTE/NR/country/Control Center selection retains the checkmark-only implementation
restored in rhui3, per the earlier crash fix `c2efb10`.

This is not a public Sileo release; distribute only via experimental CI artifacts.
