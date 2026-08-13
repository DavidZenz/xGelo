# Phase 8: Existing Patterns

**Mapped:** 2026-07-20

## Ledger and Archive Analogs

- `R/visualization/worldcup_dashboard.R` lines 500-780 defines current group and
  bracket archive maps and demonstrates required probability columns. Its update
  functions overwrite open fixture rows; the Phase 8 ledger must read historical
  committed files without changing this production behavior.
- `scripts/update_worldcup_dashboard.R` records `generated_at`, snapshot path, and
  checksum metadata. Reuse the metadata vocabulary while adding commit and blob
  provenance.
- `R/pipeline/validation.R` validates required columns and probability sums. New
  ledger checks should return structured record-level failures while reserving
  `stop()` for invalid global contracts.

## Forecast and Score Analogs

- `R/forecast/monte_carlo.R` produces the canonical scoreline fields:
  `home_goals`, `away_goals`, `scoreline`, `outcome`, `count`, and `probability`.
- `R/forecast/output.R` uses fixture-level data frames with `model_version` and
  generation timestamp fields.
- `tests/testthat/test_pipeline.R` already tests probability coherence and full
  scoreline distributions; reuse its fixture style and tolerances.
- `tests/testthat/test_worldcup_dashboard.R` contains archive row factories and
  match/bracket identifiers suitable for focused ledger fixtures.

## Reporting Analogs

- `notebooks/model_performance.Rmd` is the existing reproducible HTML report
  pattern.
- `_targets.R` sources scripts explicitly and persists file outputs through
  `tar_target(..., format = "file")` style contracts.
- `R/visualization/calibration.R` provides the local ggplot conventions for
  calibration charts.

## Planned Data Flow

`Git + cached ESPN -> fixture registry + full occurrence ledger -> strict and
exploratory first/latest views -> proper scores + uncertainty -> immutable bundle
-> HTML report`

## Constraints

- Do not mutate Git history or existing dashboard archives during reconstruction.
- Do not call live ESPN, bookmaker, Transfermarkt, or FotMob services.
- Do not refit or tune a model with 2026 outcomes.
- Keep every random operation behind an explicit seed.
- Treat generated outputs as contracts and test schemas before rendering.

