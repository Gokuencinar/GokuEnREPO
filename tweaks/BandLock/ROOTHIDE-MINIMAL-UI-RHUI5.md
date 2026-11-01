# BandLock RootHide 1.6.0~rhui5 – interface cleanup

- Removed the lengthy privacy/history description from the Analyzer screen; the
  underlying restricted local storage, validation, JSON export and stop-on-exit
  behaviour are unchanged.
- Removed the Analyzer marketing header, passive-read lecture, graph disclaimer,
  typed CoreTelephony status text and explanatory empty-history messages.
- Consolidated the signal trend, comparison and history section headings.
- Country rows show LTE / 5G band counts rather than all band numbers; details
  retain the actual list. Removed verbose directory footers.
- Band picker rows display each band's frequency and duplex once (in its title)
  instead of duplicating them in the subtitle. The checked row interaction is
  unchanged. Brief "pending until Apply" clarification retained.
- Removed explanatory Control Center footers in Settings.

**Preserved:** warning dialogs before modem-changing actions, critical SDL
 warnings, RootHide iOS18 read-only daemon gates, no-switch regression checks,
 signal journal recovery, privacy-focused data schema and app history controls.

This experimental package is distributed by GitHub Actions only, not Sileo.
