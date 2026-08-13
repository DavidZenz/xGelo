# Project Research: Risks for UEFA Competition Dashboards

## Competition and rules risks

### Treating the two competitions as one table

The same teams play in both competitions, but competition form, standings, qualification pressure, and progression rules are different. Keep competition ID on every fixture, result, form row, forecast, and simulation state.

### Fabricating EURO groups before the draw

UEFA has scheduled the EURO 2028 qualifying draw for 6 December 2026. Before then, the dashboard may show readiness, rules, calendar, and model context, but it must not display invented groups, fixtures, or qualification probabilities conditional on unknown groups.

### Incorrect Nations League ranking across group sizes

League D has groups of three while Leagues A-C have groups of four. UEFA excludes results against fourth-placed teams when comparing first, second, and third-placed teams across groups, but keeps all results for fourth-placed comparisons. A generic points sort is wrong.

### Incorrect play-off topology

Nations League play-offs are generally two-legged, League A quarter-finals are two-legged, and the semi-finals/final are single-leg. EURO 2028 play-offs can have two, three, or four paths/ties depending on host places. The simulator needs explicit topology objects rather than a generic knockout shortcut.

### Ignoring competition dependency

EURO play-off eligibility uses the 2026/27 Nations League rankings after removing teams already qualified or in the EURO play-offs. The EURO simulator therefore needs a Nations League state dependency and cannot run from the EURO table alone.

### Tie-break drift

UEFA tie-break rules include head-to-head points/goals, overall goal difference/goals, away goals, wins, away wins, disciplinary points, and access-list or Nations League ranking fallbacks. Store the applied criterion and an explanation for every non-obvious rank.

## Data and source risks

### Volatile official web pages

UEFA pages are authoritative but may change layout, identifiers, or embedded payload shape. Keep all parsing in an adapter, preserve raw snapshots, and fail closed when a required field disappears.

### No stable documented API guarantee

The public pages inspected for this research do not document a stable developer API. Do not hard-code undocumented calls throughout the project. Use bounded requests, a versioned adapter, manual fallback snapshots, and parser contract tests.

### Conflicting result states

A fixture can be scheduled, postponed, abandoned, completed after extra time, or decided on penalties. Preserve regulation goals, final goals, shootout status, and competition outcome separately. Do not treat a shootout winner as a regulation win in model evaluation.

### Team identity drift

UEFA display names, martj42 names, EloRatings names, and local names differ. Use stable canonical IDs and retain source display names. New teams, renamed associations, and special cases such as Türkiye/Turkey and Republic of Ireland/Ireland require explicit mapping tests.

### Venue and kickoff ambiguity

Store UTC timestamp, source-local timestamp, timezone, venue, and home/away designation. Neutral or relocated matches must not silently receive ordinary home advantage.

## Model and simulation risks

### Leakage from current standings

Standings and competition pressure are valid for simulation display, but future simulated results must not enter the pre-match model features for the same fixture in a way that uses information unavailable at that point. Use a separate simulated state from the model feature cutoff.

### Stale model release

The dashboard must show the release identity and model/data cutoff. A refresh can update fixtures without silently fitting a new model from future competition outcomes.

### Simulation instability

Large score-distribution outputs can exceed Git hosting limits, as happened in the prior milestone. Publish compact summaries, use bounded goal support, record seeds, and keep large intermediates out of Git history.

### Partial batch publication

If Nations League succeeds and EURO fails, publishing only one new timestamp creates an incoherent public release. Stage both bundles, retain previous successful outputs, and publish a batch manifest describing each state.

## Operational and legal risks

### Dirty-worktree collision

The existing auto-updater intentionally stops when tracked changes exist. Preserve that behavior and make the logs explain the exact blocker rather than overwriting local research artifacts.

### Launchd environment mismatch

`launchd` has a smaller environment than an interactive shell. Use absolute paths or a controlled shell wrapper, write stdout/stderr logs, and expose a manual one-shot command for diagnosis.

### UEFA brand and content rights

Use official data for factual competition state, provide visible data credits, and do not redistribute protected logos, images, or large raw response bodies unnecessarily. Keep the dashboard analytical and non-commercial in presentation.

### Manual fallback becoming authoritative by accident

Every fallback row needs source, retrieval date, reason, operator note, and checksum. Fallback must be visible in metadata and never silently overwrite a newer validated official snapshot.

## Prevention gates

- Source schema and raw-byte hash gate before parsing.
- Competition structure and regulation-version gate before simulation.
- Point-in-time feature and model-release gate before forecast generation.
- Freshness, output coverage, probability-sum, and deterministic replay checks before publication.
- Independent dashboard smoke test for both entry points.
- Atomic promotion and Git status/upstream checks before auto-commit/push.

## Sources

- [UEFA Nations League 2026/27 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27-Online)
- [UEFA EURO 2026-28 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online)
- [EURO 2028 qualifying draw announcement](https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/)
