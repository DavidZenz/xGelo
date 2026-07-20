---
phase: quick
plan: 260720-evo
type: execute
wave: 1
depends_on: []
files_modified:
  - R/visualization/worldcup_dashboard.R
  - tests/testthat/test_worldcup_dashboard.R
  - outputs/dashboard/worldcup_forecast.html
  - outputs/dashboard_100k/worldcup_forecast.html
  - docs/wc2026/index.html
autonomous: true
requirements: [UI-CHAMPION-STATE]
---

<objective>
Present the completed tournament champion as a result instead of a 100% title probability.
</objective>

<tasks>

<task type="auto">
  <name>Switch title-probability card to winner result</name>
  <files>R/visualization/worldcup_dashboard.R, tests/testthat/test_worldcup_dashboard.R, outputs/dashboard/worldcup_forecast.html, outputs/dashboard_100k/worldcup_forecast.html, docs/wc2026/index.html</files>
  <action>Use the completed final's actual winner to render a "Winner" hero metric with the team name and "Tournament champion" note. Preserve the existing positive-probability title-chance list when the final is not complete. Add emitted-template regression assertions and rerender all tracked dashboard HTML copies from existing payloads.</action>
  <verify><automated>Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_worldcup_dashboard.R", reporter = "summary")'</automated></verify>
  <done>The completed current dashboard reads "Winner / Spain / Tournament champion" without showing Spain as a 100% title chance.</done>
</task>

</tasks>

<success_criteria>
- A completed final produces a result-style Winner card.
- An unfinished final retains Top title chances.
- Source, tests, and tracked HTML artifacts agree.
</success_criteria>

