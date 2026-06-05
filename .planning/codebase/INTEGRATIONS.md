# External Integrations

**Analysis Date:** 2026-06-05

## APIs & External Services

**Open Data Sources:**
- martj42 International Football Results - historical international match results for Elo ratings
  - SDK/Client: local CSV files read with base R `read.csv()` in `R/elo/preprocess.R`; source documented as GitHub raw downloads in `DATA-INVENTORY.md` and `SETUP.md`
  - Auth: none
  - Local paths: `data/raw/martj42/results.csv`, `data/raw/martj42/goalscorers.csv`, `data/raw/martj42/shootouts.csv`
- StatsBomb Open Data - event JSON and lineup JSON for xG model training and team-match xG metrics
  - SDK/Client: local JSON files read with `jsonlite::fromJSON()` in `R/xg/data_prep.R` and `R/integration/team_match_xg.R`; source documented as GitHub raw downloads in `DATA-INVENTORY.md` and `SETUP.md`
  - Auth: none
  - Local paths: `data/raw/statsbomb/competitions.json`, `data/raw/statsbomb/events/*.json`, `data/raw/statsbomb/lineups/*.json`
- Internal team name mapping - canonical team names and FIFA codes for cross-source joins
  - SDK/Client: local CSV read with base R `read.csv()` in `R/elo/preprocess.R`
  - Auth: none
  - Local path: `data/raw/team_name_map.csv`

**Restricted/Public Web Sources:**
- FotMob - documented as restricted WCQ shot/xG source requiring manual cache only
  - SDK/Client: no implemented client in current `R/` source
  - Auth: none detected
  - Local cache path: `data/raw/wcq_cache/`, ignored by `.gitignore`
- UEFA/FIFA public pages - documented source for WCQ fixtures and line-ups
  - SDK/Client: no implemented client in current `R/` source
  - Auth: none detected
- FBref, Transfermarkt, Understat, and worldfootballR - discussed in `open_data_elo_xg_wcq_research_memo.md`; no implemented dependency or client in current `R/` source

**Package/Tooling Services:**
- CRAN - package installation source documented in `SETUP.md`
  - SDK/Client: base R `install.packages()`
  - Auth: none
- Posit/RStudio - optional IDE download documented in `SETUP.md`
  - SDK/Client: not applicable
  - Auth: none

## Data Storage

**Databases:**
- Not detected.
  - Connection: not applicable
  - Client: not applicable

**File Storage:**
- Local filesystem only.
- Raw data: `data/raw/martj42/`, `data/raw/statsbomb/`, and `data/raw/team_name_map.csv`
- Processed data: `data/processed/`
- Model artifacts: `models/*.rds`
- Forecast outputs: `outputs/forecasts/*.csv`
- Visualization outputs: `outputs/visualizations/*.png`
- Notebook outputs: `outputs/notebooks/`

**Caching:**
- Local cache directory `data/cache/` is used by `_targets.R` for `martj42.rds` and `statsbomb.rds`.
- Manual restricted-source cache directory `data/raw/wcq_cache/` is documented in `DATA-INVENTORY.md` and ignored by `.gitignore`.
- `targets` manages pipeline state through its standard `_targets/` store when `targets::tar_make()` runs; no committed `_targets/` directory is present.

## Authentication & Identity

**Auth Provider:**
- None.
  - Implementation: no login, OAuth, API key, token, or identity provider code detected in `R/`, `_targets.R`, `SETUP.md`, or `RUNBOOK.md`.

## Monitoring & Observability

**Error Tracking:**
- None.

**Logs:**
- Console output through `message()`, `cat()`, `warning()`, and `stop()` in files such as `R/xg/data_prep.R`, `R/integration/team_match_xg.R`, `R/pipeline/validation.R`, and `R/forecast/output.R`.
- Validation results are printed by `run_validation_checks()` in `R/pipeline/validation.R`.

## CI/CD & Deployment

**Hosting:**
- Not detected.

**CI Pipeline:**
- None detected.
- No GitHub Actions, Makefile, package build config, Dockerfile, or deployment config is present in the inspected file inventory.

## Environment Configuration

**Required env vars:**
- None detected.

**Secrets location:**
- Not applicable.
- No `.env`, `.Renviron`, or credential files are present at the inspected project depth.
- Source rules require `data/raw/wcq_cache/` and `data/cache/` to remain local via `.gitignore`.

## Webhooks & Callbacks

**Incoming:**
- None.

**Outgoing:**
- None.
- Current R code uses local files; no `httr2`, `curl`, `download.file()`, `GET()`, `POST()`, or webhook call sites are detected in `R/` or `_targets.R`.

---

*Integration audit: 2026-06-05*
