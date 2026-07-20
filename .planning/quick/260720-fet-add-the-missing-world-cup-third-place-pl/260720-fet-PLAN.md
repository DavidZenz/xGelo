---
phase: quick
plan: 260720-fet
type: execute
wave: 1
depends_on: []
files_modified:
  - R/visualization/worldcup_dashboard.R
  - tests/testthat/test_worldcup_dashboard.R
  - outputs/dashboard/worldcup_bracket_paths.csv
  - outputs/dashboard/worldcup_bracket_prematch_forecasts.csv
  - outputs/dashboard/worldcup_dashboard_data.json
  - outputs/dashboard/worldcup_forecast.html
  - outputs/dashboard/worldcup_group_probabilities.csv
  - outputs/dashboard/worldcup_match_forecasts.csv
  - outputs/dashboard/worldcup_prematch_forecasts.csv
  - outputs/dashboard/worldcup_stage_probabilities.csv
  - outputs/dashboard_100k/worldcup_bracket_paths.csv
  - outputs/dashboard_100k/worldcup_bracket_prematch_forecasts.csv
  - outputs/dashboard_100k/worldcup_current_group_tables.csv
  - outputs/dashboard_100k/worldcup_dashboard_data.json
  - outputs/dashboard_100k/worldcup_elo_evolution.csv
  - outputs/dashboard_100k/worldcup_forecast.html
  - outputs/dashboard_100k/worldcup_group_probabilities.csv
  - outputs/dashboard_100k/worldcup_match_forecasts.csv
  - outputs/dashboard_100k/worldcup_prematch_forecasts.csv
  - outputs/dashboard_100k/worldcup_stage_probabilities.csv
  - docs/wc2026/index.html
autonomous: true
requirements: [WC26-M103]
must_haves:
  truths:
    - "The knockout contract contains all 32 matches M73-M104, including M103 as the Third-place play-off between the losers of M101 and M102."
    - "M103 is simulated and conditioned on actual results without changing the M101/M102 winner route into M104 or the M104-to-Champion path."
    - "Bracket payloads and CSV exports contain 33 rows including the Champion display row, with M103 carrying the correct stage, entrants, forecast, and completed result state."
    - "The dashboard displays M103 in a non-overlapping medal-match lane with keyboard/click forecast details and loser-branch links distinct from the champion path."
  artifacts:
    - path: "R/visualization/worldcup_dashboard.R"
      provides: "M103 loser-slot resolution, simulation, path export, actual-result conditioning, and interactive bracket rendering"
      contains: "M103"
    - path: "tests/testthat/test_worldcup_dashboard.R"
      provides: "Regression coverage for the complete match tree, loser routing, invariant champion path, exports, and dashboard template"
      contains: "Third-place play-off"
    - path: "outputs/dashboard/worldcup_bracket_paths.csv"
      provides: "Current published 33-row bracket export containing the settled M103 result"
      contains: "M103"
    - path: "outputs/dashboard_100k/worldcup_dashboard_data.json"
      provides: "Canonical 100k dashboard payload containing M103"
      contains: "Third-place play-off"
    - path: "docs/wc2026/index.html"
      provides: "Published dashboard with the interactive M103 card"
      contains: "M103"
  key_links:
    - from: "worldcup_bracket_template()"
      to: "simulate_knockout_bracket_once() and simulate_group_stage_dashboard()"
      via: "Loser M101/Loser M102 slot parsing backed by stored match losers"
      pattern: "Loser M[0-9]+"
    - from: "build_bracket_paths()"
      to: "M104 and M103"
      via: "next_match_id remains the winner edge while loser_next_match_id represents the third-place edge"
      pattern: "loser_next_match_id"
    - from: "build_worldcup_dashboard_data()"
      to: "worldcup_bracket_paths.csv and worldcup_dashboard_data.json"
      via: "the 33-row bracket_paths data frame is serialized unchanged"
      pattern: "write.csv\\(bracket_paths"
    - from: "dashboard_html_template()"
      to: "M103 bracket card and loser connectors"
      via: "outcome-aware link rendering and the standard bracket inspector interaction handlers"
      pattern: "Third-place play-off"
---

<objective>
Restore the omitted World Cup match M103 across the knockout graph, tournament simulation, actual-result conditioning, exports, and published dashboard.

Purpose: The current implementation jumps from the two semifinals directly to M104 and therefore drops the official third-place match, its France-England result, and its branch of the knockout tree.
Output: A complete 32-match knockout model plus Champion display row, tested loser routing, and regenerated current/100k dashboard artifacts.
</objective>

<execution_context>
@/Users/davidzenz/.codex/gsd-core/workflows/execute-plan.md
@/Users/davidzenz/.codex/gsd-core/templates/summary.md
</execution_context>

<context>
@AGENTS.md
@R/visualization/worldcup_dashboard.R
@tests/testthat/test_worldcup_dashboard.R
@scripts/update_worldcup_dashboard.R
@data/processed/elo_matches.csv

<interfaces>
- `worldcup_bracket_template(include_champion)` is the authoritative knockout contract and supplies `round`, `match_id`, `slot1_label`, and `slot2_label` to both simulation paths and bracket-path construction.
- `resolve_simulated_bracket_slot()` and the local optimized `parse_bracket_slot()`/`resolve_slot()` pair currently understand prior-match winners only; M103 requires symmetric prior-match loser lookup.
- `build_bracket_paths()` exports `next_match_id` as the winner/champion edge used by `mark_projected_champion_path()` and the browser link renderer. Preserve that contract and add a separate loser edge.
- `attach_worldcup_bracket_actual_results()` reads canonical World Cup results by unordered team pair. The repository contains France 4-6 England on 2026-07-18, which must settle M103 after the actual semifinal losers are resolved.
- `build_worldcup_dashboard_data()` writes the same `bracket_paths` frame to JSON and `worldcup_bracket_paths.csv`; `dashboard_html_template()` consumes that frame for match lists, team routes, grid placement, links, hover state, and the forecast inspector.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add loser-fed M103 without disturbing the title route</name>
  <files>R/visualization/worldcup_dashboard.R, tests/testthat/test_worldcup_dashboard.R</files>
  <behavior>
    - Template: `include_champion = FALSE` yields 32 matches and M103 is `Third-place play-off`, `Loser M101` versus `Loser M102`; M104 remains `Winner M101` versus `Winner M102`.
    - Dynamic simulation: each completed match stores both winner and loser, M103 receives the two semifinal losers, and 32 knockout routes are evaluated.
    - Optimized simulation: M103 is evaluated but does not increment finalist or champion counts; seeded M104/champion selection is performed before the independent M103 draw so the new consolation match cannot perturb the existing title-path random stream.
    - Actual conditioning: completed M101/M102 results determine M103 entrants, a completed M103 result fixes its winner, and those loser/result edges never replace the semifinal winners entering M104.
  </behavior>
  <action>Add M103 to `worldcup_bracket_template()` after M104 in computation order and before the optional Champion display row, using the exact round label `Third-place play-off` and slot labels `Loser M101`/`Loser M102`. Extend `resolve_simulated_bracket_slot()`, `simulate_knockout_bracket_once()`, the optimized `parse_bracket_slot()`/`resolve_slot()` path in `simulate_group_stage_dashboard()`, and `resolve_bracket_slot()`/`build_bracket_paths()` to store and resolve the non-winning team from a prior match. Derive losers after any actual-result override so completed semifinal outcomes feed M103 correctly. Keep M104 computation ahead of M103, retain `next_match_id = M104` for M101/M102 and `M104 -> Champion`, and add `loser_next_match_id = M103` for M101/M102 only; M103 has no continuation and must remain outside `mark_projected_champion_path()`. Map the third-place round to semifinal reach probability for contextual team-stage display, but use its own match route for win probability and never update final/champion counters from M103. Write focused regressions first for row/ID counts, exact labels, recorded loser entrants, 32 route calls, serial/parallel determinism, unchanged finalist/title totals, actual semifinal-to-M103 conditioning, settled M103 winner, and the invariant winner route through M104.</action>
  <verify>
    <automated>rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_dashboard.R", reporter = "summary")'</automated>
  </verify>
  <done>The model has all 32 knockout matches, M103 consumes only the semifinal losers, actual outcomes can settle it, and every existing winner/champion invariant still terminates through M104.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Export and render the third-place branch as an interactive medal match</name>
  <files>R/visualization/worldcup_dashboard.R, tests/testthat/test_worldcup_dashboard.R</files>
  <behavior>
    - Data/export: `bracket_paths` and a fresh pre-tournament prematch archive each contain 33 rows including Champion, and M103 retains `Third-place play-off` in JSON/CSV.
    - Layout: M103 shares the medal-match column with M104 but occupies an explicit separate lane, so neither card nor their source links overlap.
    - Links: semifinal winner edges still lead to M104/champion highlighting, while distinct loser edges lead to the matching M103 slots.
    - Interaction/copy: M103 opens through click and keyboard controls, uses the existing score/route inspector, and describes its projected/completed team as winning third place rather than advancing toward the title.
  </behavior>
  <action>Carry `loser_next_match_id` through the bracket-path JSON/CSV schema and update `dashboard_html_template()` to render M103 in the knockout-match list, team route, and bracket. Give `Third-place play-off` the medal-match column used by `Final`, allocate M103 a deterministic row below the title final, and increase the grid row capacity so the cards cannot overlap. Extend link drawing with an outcome marker: existing `next_match_id` links represent winners, while `loser_next_match_id` links target the appropriate `data-source-match-id` slot in M103 and derive the losing semifinalist for labels, hover highlighting, and decided-state styling. Keep projected-champion highlighting restricted to winner links. Reuse the existing card/inspector click, Enter, Space, hover, and focus handlers, but make M103-specific labels say `Most likely wins third place`, `Projected third-place winner`/`Projected fourth place`, and, once settled, that the actual winner won third place. Add regression assertions for 33 exported rows, exact stage/slot labels, both edge types, no M103 continuation, unchanged M104/Champion links, emitted layout/link/interaction hooks, and the completed France 4-6 England M103 state.</action>
  <verify>
    <automated>rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_dashboard.R", reporter = "summary")'</automated>
  </verify>
  <done>Fresh payloads expose one M103 row with correct forecasts/results, and the dashboard presents a distinct, fully inspectable third-place branch without treating it as part of the champion route.</done>
</task>

<task type="auto">
  <name>Task 3: Regenerate and verify the tracked dashboard publication</name>
  <files>outputs/dashboard/worldcup_bracket_paths.csv, outputs/dashboard/worldcup_bracket_prematch_forecasts.csv, outputs/dashboard/worldcup_dashboard_data.json, outputs/dashboard/worldcup_forecast.html, outputs/dashboard/worldcup_group_probabilities.csv, outputs/dashboard/worldcup_match_forecasts.csv, outputs/dashboard/worldcup_prematch_forecasts.csv, outputs/dashboard/worldcup_stage_probabilities.csv, outputs/dashboard_100k/worldcup_bracket_paths.csv, outputs/dashboard_100k/worldcup_bracket_prematch_forecasts.csv, outputs/dashboard_100k/worldcup_current_group_tables.csv, outputs/dashboard_100k/worldcup_dashboard_data.json, outputs/dashboard_100k/worldcup_elo_evolution.csv, outputs/dashboard_100k/worldcup_forecast.html, outputs/dashboard_100k/worldcup_group_probabilities.csv, outputs/dashboard_100k/worldcup_match_forecasts.csv, outputs/dashboard_100k/worldcup_prematch_forecasts.csv, outputs/dashboard_100k/worldcup_stage_probabilities.csv, docs/wc2026/index.html</files>
  <action>Run `scripts/update_worldcup_dashboard.R` with `XGELO_FEATURE_CUTOFF_DATE=2026-07-19`, `XGELO_ACTUAL_RESULTS_CUTOFF_DATE=2026-07-20`, the existing 100000 match/tournament simulation defaults, current-output sync enabled, and Pages publication enabled. This must rebuild the canonical 100k payload, sync the current dashboard bundle, and publish the HTML copy. Do not synthesize a retrospective prematch forecast for the already completed M103: retain the historical archive semantics, while fresh no-results test builds cover the 33-row open-match archive case. Confirm both bracket-path exports and embedded payloads contain 33 rows, M103 is France versus England with final score 4-6 and England as winner, M101/M102 keep winner edges to M104 plus loser edges to M103, M104 still links to Champion, and all three HTML copies contain the interactive M103 data. Leave `outputs/design_audit/` and `outputs/reports/xgelo_elo_decision/` untracked and untouched.</action>
  <verify>
    <automated>rtk Rscript --vanilla -e 'for (d in c("outputs/dashboard", "outputs/dashboard_100k")) { p &lt;- read.csv(file.path(d, "worldcup_bracket_paths.csv"), stringsAsFactors = FALSE); stopifnot(nrow(p) == 33L, identical(p$round[p$match_id == "M103"], "Third-place play-off"), identical(p$slot1_label[p$match_id == "M103"], "Loser M101"), identical(p$slot2_label[p$match_id == "M103"], "Loser M102"), identical(p$slot1_display[p$match_id == "M103"], "France"), identical(p$slot2_display[p$match_id == "M103"], "England"), identical(p$actual_score[p$match_id == "M103"], "4-6"), identical(p$actual_winner[p$match_id == "M103"], "England"), all(p$next_match_id[p$match_id %in% c("M101", "M102")] == "M104"), all(p$loser_next_match_id[p$match_id %in% c("M101", "M102")] == "M103"), identical(p$next_match_id[p$match_id == "M104"], "Champion")); j &lt;- jsonlite::fromJSON(file.path(d, "worldcup_dashboard_data.json")); stopifnot(nrow(j$bracket_paths) == 33L, any(j$bracket_paths$match_id == "M103")) }; for (h in c("outputs/dashboard/worldcup_forecast.html", "outputs/dashboard_100k/worldcup_forecast.html", "docs/wc2026/index.html")) stopifnot(any(grepl("M103", readLines(h, warn = FALSE), fixed = TRUE))); testthat::test_file("tests/testthat/test_worldcup_dashboard.R", reporter = "summary")'</automated>
  </verify>
  <done>The tracked current, 100k, and Pages artifacts agree on a 33-row bracket containing the settled interactive M103, with the winner/champion route and protected untracked output trees unchanged.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Processed results CSV to knockout state | Canonical team pairs and scores decide which semifinalists feed M103 and which team won the play-off. |
| R bracket payload to browser renderer | Serialized winner/loser edges control path drawing, result copy, highlighting, and interaction targets. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-quick-01 | Tampering | `build_bracket_paths()` winner/loser routing | high | mitigate | Preserve `next_match_id` as the winner edge, add a separately tested `loser_next_match_id`, and assert M101/M102 feed both M104 and M103 through the correct outcomes. |
| T-quick-02 | Tampering | Seeded tournament simulation | high | mitigate | Compute/count M104 before the independent M103 draw and assert finalist/champion totals and deterministic serial/parallel outputs remain valid. |
| T-quick-03 | Spoofing | `attach_worldcup_bracket_actual_results()` pair matching | medium | mitigate | Resolve M103 entrants from actual semifinal winners/losers before matching the canonical France-England result, and regression-test score, winner, and no-continuation state. |
| T-quick-04 | Denial of service | Browser bracket layout and link graph | low | accept | The payload adds one bounded card and two bounded links; explicit row allocation and emitted-template tests prevent overlap or recursive graph traversal. |
</threat_model>

<verification>
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_dashboard.R", reporter = "summary")'` passes.
- Fresh test payloads have 32 knockout matches plus Champion, and the published current/100k payloads expose the completed M103 result.
- M101/M102 winner edges and all projected-champion-path rows still terminate through M104; M103 and loser links are never marked as champion path.
- `rtk git diff --check` passes, and `rtk git status --short` shows no changes under `outputs/design_audit/` or `outputs/reports/xgelo_elo_decision/`.
</verification>

<success_criteria>
- M103 is modeled exactly once as `Third-place play-off`, fed by `Loser M101` and `Loser M102`.
- Both simulation implementations evaluate M103 while preserving finalist and champion semantics.
- Actual results resolve France versus England, 4-6, England third-place winner, with no downstream continuation.
- Bracket JSON/CSV exports contain 33 rows including Champion and retain separate winner and loser edges from each semifinal.
- The current, 100k, and Pages dashboards show an accessible, non-overlapping, inspectable M103 branch.
- Existing untracked audit/report directories remain untouched.
</success_criteria>

<source_audit>

| Source | ID | Feature/Requirement | Task | Status | Notes |
|--------|----|---------------------|------|--------|-------|
| GOAL | — | Add M103 across knockout tree, simulations, bracket paths, dashboard, exports, and tests | 1-3 | COVERED | Core model, UI/export, and publication are each explicit. |
| REQ | WC26-M103 | Losers of both semifinals contest M103 without changing M104 champion propagation | 1-2 | COVERED | Separate loser edge and winner-path invariants are tested. |
| RESEARCH | — | No RESEARCH.md supplied for this quick task | — | N/A | Established in-repository patterns are sufficient; no dependency or external API is introduced. |
| CONTEXT | — | Include actual conditioning, row/stage assertions, bracket interaction, and preserve named untracked outputs | 1-3 | COVERED | Every supplied constraint is represented in task actions and done criteria. |
</source_audit>

<output>
Create `.planning/quick/260720-fet-add-the-missing-world-cup-third-place-pl/260720-fet-SUMMARY.md` when done.
</output>
