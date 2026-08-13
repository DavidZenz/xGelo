# Project Research Summary

## Key Findings

### Competition rules are the main new complexity

The 2026/27 Nations League is not a single group tournament. It has Leagues A-D, group-size differences, overall ranking rules, promotion/relegation, two-legged League A/B and B/C play-offs, conditional League C/D play-offs, League A quarter-finals, and a single-leg finals tournament. The rules need a dedicated stateful simulator.

EURO 2028 qualifying has 12 groups of four or five teams. The 12 group winners and eight best runners-up qualify directly. Two host places are reserved, and the remaining places are determined through a variable play-off structure that also draws from the 2026/27 Nations League ranking. This creates a cross-competition dependency.

### EURO has a known pre-draw period

UEFA has announced that the EURO 2028 qualifying draw will take place on 6 December 2026. The dashboard should launch before the draw in a truthful `pre_draw` state, then activate group fixtures and qualification simulation once the official draw/schedule snapshot is available.

### Official UEFA data is authoritative but operationally volatile

UEFA provides official fixtures/results, standings, groups, and regulations pages. The public pages inspected do not promise a stable developer API. The safest design is an adapter with raw snapshot retention, schema/hash validation, low request volume, and audited manual fallbacks.

### The WC26 dashboard is a strong reusable base

The current R/static HTML dashboard already supports model release metadata, calibrated probabilities, score distributions, forecast features, simulation, static publication, tests, and hourly `launchd` automation. The new milestone should generalize those pieces rather than create a second frontend stack.

## Implications for Roadmap

1. Freeze shared source, team identity, competition registry, and payload schemas first.
2. Implement generic standings, form, forecast, and simulation interfaces before competition-specific rules.
3. Build the Nations League path first because its groups and league-phase fixtures are already published.
4. Build the EURO rules and pre-draw shell next, with explicit activation after the December draw.
5. Add cross-competition Nations League-to-EURO play-off eligibility only after both rulesets have independent tests.
6. Finish with shared dashboard rendering, hourly atomic refresh, browser smoke tests, and release acceptance.

## Recommended MVP Boundary

The first usable release should include:

- a live Nations League dashboard with groups, standings, form, fixtures, forecasts, and projected promotion/relegation/knockout outcomes;
- a EURO 2028 qualifying dashboard in `pre_draw` mode with official dates, rules, participating host context, shared team/model profiles, and a clear activation status;
- a refresh command and launchd job that can publish both bundles without partial updates;
- compact, auditable output manifests and visible collapsed data credits.

Full EURO group standings, fixture forecasts, and qualification simulations become active as soon as the official draw and fixture snapshot exists.

## Watch Outs

- Never infer standings from a generic points sort when UEFA tie-breaks or cross-group rankings apply.
- Never show fabricated EURO groups before the draw.
- Never merge the two competitions' state, even when model inputs are shared.
- Never publish a new bundle if only one competition passed validation.
- Never commit large score-distribution CSVs to Git history.

## Sources

- [2026/27 UEFA Nations League overview](https://www.uefa.com/uefanationsleague/news/0298-1d6ef1acfaef-b54fcf1da859-1000--2026-27-uefa-nations-league-all-you-need-to-know/)
- [2026/27 UEFA Nations League fixtures](https://www.uefa.com/uefanationsleague/news/02a2-1fea18abbcbc-456e846509e7-1000--2026-27-uefa-nations-league-all-the-league-phase-fixtures/)
- [Nations League regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27-Online)
- [EURO 2028 qualification system](https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/)
- [EURO 2028 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online)
- [EURO 2028 qualifying draw date](https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/)
- [Open international results mirror](https://github.com/openfootball/internationals)
