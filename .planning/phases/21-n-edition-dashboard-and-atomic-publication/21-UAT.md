---
phase: 21-n-edition-dashboard-and-atomic-publication
status: human_needed
---

# Phase 21 Human UAT Boundary

These checks are required once an accepted production UCL source/model/draw bundle exists.  They are deliberately separate from the mechanical contract tests.

1. Open the staged/public route `/competitions/champions-league/` and confirm the header shows the real edition name, source freshness/delay, ruleset version, model/calibrator release, feature/information cutoff, simulation seed/count, batch/run identity, attribution, and last-known-good state.
2. Confirm the twelve section links are present: Overview, Structure, Standings, Fixtures, Results, Form, Match forecasts, Rank distributions, Qualification bands, Knockout paths, Progression probabilities, and Projected outcomes.
3. Confirm unresolved Article 18 rank intervals and unresolved draw/path states show their status and reason, with no zero-filled probability or invented fixture rows.
4. Resize to the Phase 17 viewport contract (1440x900 and 390x844).  Confirm horizontal table scrolling, keyboard focus outlines, readable status badges, and reduced-motion behavior.
5. Inspect `champions-league/payload.json`, `route-manifest.json`, and `current.json`; verify their batch identity and payload/HTML hashes match the displayed batch manifest.
6. Inspect the three-edition batch (Nations League, EURO, Champions League).  Inject a provider, hash, or read-back failure in a supervised dry run and confirm every incumbent public byte remains unchanged.

Until accepted authority is available, the expected result is a truthful blocked/unavailable UCL route and no production forecast rows.
