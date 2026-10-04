# Nations League dashboard implementation

Approved plan: title outlook, stacked forecast/current/fixture panels, total promotion and relegation probabilities, and the revised 15 September 2026 UEFA transition rules.

## Work
- [x] Version and pin revised rules; update transition selection, legal draws and final rank bands.
- [x] Precompute approved play-off forecasts and publish simulation-level total move probabilities.
- [x] Implement title chart, stacked group tables, compact fixtures and scoped filters.
- [x] Verify rules, probability identities, determinism, unavailable states and desktop/mobile rendering.
- [x] Regenerate state/outcomes and stage/validate/promote the local atomic dashboard publication.

## Defaults
Use the existing approved national-team release, seed and simulation count. Keep xGD and match navigation. Defer history, model retraining and the UCL renderer migration. Preserve unrelated local changes.
