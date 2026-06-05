# xGelo Requirements Specification

---
*Project: xGelo - Free Elo + xG Forecasting for UEFA World Cup Qualifiers*
*Version: 1.0*
*Status: **Complete** - All v1 requirements delivered
*Last Updated: 2026-06-05
---

## Traceability

| Requirement ID | Phase | Status | Validation | File |
|---------------|-------|--------|------------|------|
| DATA-01 | 1 | ✅ Complete | Validated | `R/data_ingest/martj42.R` |
| DATA-02 | 1 | ✅ Complete | Validated | `R/data_ingest/team_names.R`, `data/raw/team_name_map.csv` |
| DATA-03 | 1 | ✅ Complete | Validated | `R/data_ingest/statsbomb.R` |
| DATA-04 | 1 | ✅ Complete | Validated | `DATA-INVENTORY.md` |
| XG-01 | 2 | ✅ Complete | Validated | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-02 | 2 | ✅ Complete | Validated | `R/xg/features.R`, `tests/testthat/test_xg_features.R` |
| XG-03 | 2 | ✅ Complete | Validated | `R/xg/features.R` |
| XG-04 | 2 | ✅ Complete | Validated | `R/xg/model.R`, `models/xg_model.rds` |
| XG-05 | 2 | ✅ Complete | Validated | `R/xg/calibration.R`, `outputs/visualizations/xg_calibration.png` |
| XG-06 | 2 | ✅ Complete | Validated | `R/xg/backtest.R`, `outputs/model_performance/xg_backtest.csv` |
| ELO-01 | 3 | ✅ Complete | Validated | `R/elo/runner.R` |
| ELO-02 | 3 | ✅ Complete | Validated | `R/elo/runner.R`, `data/processed/elo_ratings.csv` |
| ELO-03 | 3 | ✅ Complete | Validated | `R/elo/runner.R` |
| ELO-04 | 3 | ✅ Complete | Validated | `R/elo/tuning.R` |
| INTEGR-01 | 4 | ✅ Complete | Validated | `R/integration/team_match_xg.R`, `data/processed/team_match_xg.csv` |
| INTEGR-02 | 4 | ✅ Complete | Validated | `R/integration/rolling_form.R`, `data/processed/rolling_form.csv` |
| FORECAST-01 | 5 | ✅ Complete | Validated | `R/forecast/poisson.R`, `models/home_goal_model.rds` |
| FORECAST-02 | 5 | ✅ Complete | Validated | `R/forecast/poisson.R`, `models/away_goal_model.rds` |
| FORECAST-03 | 5 | ✅ Complete | Validated | `R/forecast/monte_carlo.R` |
| FORECAST-04 | 5 | ✅ Complete | Validated | `R/forecast/output.R`, `outputs/forecasts/` |
| FORECAST-05 | 5 | ✅ Complete | Validated | `R/forecast/calibration.R`, `outputs/visualizations/forecast_calibration.png` |
| PIPELINE-01 | 6 | ✅ Complete | Validated | `_targets.R`, `outputs/pipeline_dag.png` |
| PIPELINE-02 | 1 | ✅ Complete | Validated | `.gitignore`, `DATA-INVENTORY.md` |
| PIPELINE-03 | 1 | ✅ Complete | Validated | `R/pipeline/validation.R` |
| TEST-01 | 6 | ✅ Complete | Validated | `tests/testthat/test_xg_features.R` |
| TEST-02 | 6 | ✅ Complete | Validated | `tests/testthat/test_elo.R` |
| TEST-03 | 6 | ✅ Complete | Validated | `tests/testthat/test_pipeline.R` |
| VIS-01 | 7 | ✅ Complete | Validated | `R/visualization/auc.R`, `outputs/visualizations/auc_comparison.png` |
| VIS-02 | 7 | ✅ Complete | Validated | `R/visualization/calibration.R`, `outputs/visualizations/` |
| DOC-01 | 7 | ✅ Complete | Validated | `notebooks/model_performance.Rmd`, `outputs/notebooks/model_performance.html` |
| DOC-02 | 7 | ✅ Complete | Validated | `SETUP.md`, `RUNBOOK.md`, `MODEL-CARD.md` |

**Summary**: 31/31 requirements complete (100%)

---

> **📦 Archived**: See [v1.0 Requirements Archive](.planning/milestones/v1.0-REQUIREMENTS.md) for complete v1 specification.

---

## v2 Requirements (Deferred)

For next milestone (v2.0), see the archived v1 requirements for reference. New v2 requirements will be defined using `/gsd:new-milestone` workflow.

### Planned v2 Enhancements
- Mixed-effects xG model
- Sequence-aware models
- Hybrid WCQ data layer
- Group stage simulation
- CI/CD pipeline

---

*This file will be replaced with fresh v2 requirements. Current v1 requirements are archived at `.planning/milestones/v1.0-REQUIREMENTS.md`
