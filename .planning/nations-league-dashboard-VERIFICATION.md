# Nations League dashboard verification

Date: 4 October 2026. Approved scope: `.planning/nations-league-dashboard-PLAN.md`.

## Rules and forecasts

- Registry revision 10 pins `uefa-nations-league-2026-27-v3`, effective 15 September 2026. Article 16 and 19 evidence is recorded in `data/competition/rules/nl_2026_27_transition_evidence_v3.json`.
- Revised transition boundaries, all six League D promotions, absence of active C/D play-offs, and final next-edition allocations (18 A, 18 B, remaining accepted teams C) pass synthetic outcome tests. Archived v2 rules retain their historical topology.
- Approved national-team model release: `phase14-open-nb-incumbent-calibrated-v1`. The model, support limit G=40, tail tolerance 1e-10, seed 15017 and existing 1,000-simulation configuration are preserved.
- All possible ordered play-off legs receive a forecast status: A/B 512 available of 512; B/C 493 available and 19 suppressed of 512. Suppressed legs exceed the approved model's score support. Their grids are excluded, and simulations selecting them preserve affected outcomes as unavailable. None was selected in the published run; all 54 teams have complete promotion/relegation probabilities.
- Legal seeded draws, official draw precedence, lower-league first-leg home advantage, both sides of eventual promotion/relegation, League B's alternative paths, and unavailable inputs pass focused tests.
- The full production outcome rebuild validates nine artifacts. Quarter-final, Finals, final and champion probability sums are respectively 8, 4, 2 and 1. League D promotion probabilities are all 1. Rank conservation and ranges are validated on bundle read-back.
- Repeated and reversed-input replay passed without durable mutation. State and outcomes share the current v3 rules lineage and accepted source bundle `58029ec9a7fcd51e7799d750c6aab9593f410c5410d110f5262fe09a859a2ab1`.

## Dashboard

- All 16 League A teams appear in the title chart, ordered by champion probability, with alphabetical tie-breaking and unavailable rows last. Background bars use semi-final probability (the four-team Finals); foreground bars use champion probability.
- All 14 full-width group panels stack projected standings, current standings and deduplicated fixtures. Matchdays 1–6 come from the hash-verified accepted UEFA raw capture, joined by UEFA fixture ID. Dates, completed scores and scheduled times remain accepted source values.
- Projected tables keep xPts/xGD ordering. Total promotion, play-off participation and total relegation are labelled as overlapping outcomes; League A includes quarter-finals. Zero, below-0.1%, threshold rounding, unavailable and archived-artifact states pass tests.
- The accepted cutoff is `2026-10-03T01:00:32Z`; the chart states 1,000 simulations. Current standings use completed accepted results and Article 15 ordering rather than projected row order.
- Fixtures show 156 matches and Results 70. Filtering Results for Scotland shows 2; clearing restores 70. Group fixture copies do not affect either count.
- Real browser inspection at 1440×900 and 390×844 passed. Phone page width remains 390px; projected/current tables scroll within 336px regions, with sticky team columns and keyboard access. Fixtures stack into one column. Enter activates navigation, and ArrowRight scrolls the focused table.
- Probability shading meets 4.5:1 text contrast across the range; the lowest observed heat-cell contrast including current standings is 4.85:1. Active tab hover keeps white text on its dark background.
- The companion EURO route remains explicitly pre-draw. The UCL renderer is untouched.

## Tests and publication

- Revised dashboard suite: 11 tests, 197 successful expectations.
- Phase 17 dashboard suite: 28 tests, 216 successful expectations, one existing no-Git-upstream warning.
- Phase 14 forecast suite, UEFA rule-input suite and UEFA production suite passed.
- Phase 15 regression suite: all 41 cases pass, combining the full run's 40 unchanged cases with the corrected production acceptance case's successful targeted rerun. Dry-run and command-line replay preserve durable state. Read-back checks pass for 70 completed results (forecast suppression is expected) and 86 available future forecasts.
- Batch `phase17-5b61ac149845a6f151024588` validates all ten publication files, hashes, lineage, size limits and route contracts. The existing `phase17_promote_batch` atomically promoted the candidate to `docs/competitions`; read-back validates identical manifests and all content hashes. Batch size: 3,889,999 bytes.
- The published Nations League HTML matches the browser-inspected preview byte for byte. SHA-256: `7b8c114a9e436eeb052aef09dd5cf45576c7e3c4231d81546fc98e3ab5bdd122`.
- Browser verification used the Codex in-app browser. The separate pinned Safari WebDriver gate was not run because the installed Safari version differs from its pin; the production browser pin was not changed. Coordinator unit tests use an explicit capability fixture. Real desktop/mobile, keyboard, contrast and containment checks are recorded above.
- Existing publisher rollback tests cover failed promotion/read-back retaining the incumbent. Unrelated local data and UCL planning edits remain outside this change.

Screenshots are saved in `/Users/davidzenz/.codex/visualizations/2026/10/04/01a10859-3cf9-7270-a6b5-16821423d273/`: `nations-league-outlook-desktop.jpg`, `nations-league-outlook-mobile.jpg`, `nations-league-group-desktop.jpg`, and `nations-league-group-b1-desktop.jpg`.
