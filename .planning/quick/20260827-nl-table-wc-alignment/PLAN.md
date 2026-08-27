# Quick Task: Align Nations League Tables with WC behavior

## Objective

Make the Nations League group tables use the same Forecast/Current table structure and interaction pattern as the World Cup dashboard.

## Tasks

- [x] Compare the WC forecast/current table contract and identify the missing NL behavior.
- [x] Render separate forecast and current standings tables per group, with WC-compatible columns and toggles.
- [x] Add focused renderer assertions, regenerate the accepted public route, and validate the live page.
- [x] Commit and push the implementation and generated route artifacts.

## Verification

- Focused `test_phase17_dashboards.R` passes (including completed-result aggregation coverage).
- Generated route validates against the Phase 17 publication contract.
- Published Nations League page exposes separate forecast/current tables and preserves scheduled-results semantics.
