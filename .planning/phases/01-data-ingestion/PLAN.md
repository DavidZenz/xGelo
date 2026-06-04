# Phase 1: Data Ingestion & Infrastructure — PLAN

---
*Phase*: 1
*Name*: Data Ingestion & Infrastructure
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers
*Status*: Ready for Execution
*Last Updated*: 2026-06-03

---

## Phase Goal

Ingest all open data sources, establish canonical team naming, set up caching and validation infrastructure to enable xG model training and Elo rating computation.

---

## Task Breakdown

### Task 1.1: Set up cache directory structure (PIPELINE-02)
**Description**: Create directory structure for raw data caching and configure .gitignore

**Sub-tasks**:
- Create `data/raw/martj42/` directory
- Create `data/raw/statsbomb/` directory with `events/` and `lineups/` subdirectories
- Create `data/raw/team_name_map.csv` placeholder
- Create `data/raw/wcq_cache/` directory
- Create `data/cache/` directory
- Update `.gitignore` to exclude cache directories

**Dependencies**: None

**File Outputs**:
- `data/raw/martj42/`
- `data/raw/statsbomb/events/`
- `data/raw/statsbomb/lineups/`
- `data/raw/wcq_cache/`
- `data/cache/`
- `.gitignore` (updated)

**Success Criteria**:
- [ ] Directory structure matches specification in CONTEXT.md
- [ ] `.gitignore` excludes `data/raw/wcq_cache/` and `data/cache/`
- [ ] All cache directories created with proper permissions

---

### Task 1.2: Ingest martj42 international results (DATA-01)
**Description**: Download martj42 dataset from GitHub raw URLs

**Sub-tasks**:
- Download `results.csv` from GitHub raw URL
- Download `goalscorers.csv` from GitHub raw URL
- Download `shootouts.csv` from GitHub raw URL
- Save to `data/raw/martj42/`
- Rate limit: 2 seconds between requests

**Note**: `in_90min.csv` no longer exists in source; replaced with `goalscorers.csv`

**Time Estimate**: 15 minutes

**Dependencies**: Task 1.1

**File Outputs**:
- `data/raw/martj42/results.csv`
- `data/raw/martj42/goalscorers.csv`
- `data/raw/martj42/shootouts.csv`

**Success Criteria**:
- [ ] `results.csv` loaded with columns: date, home_team, away_team, home_score, away_score, tournament, city, country, neutral
- [ ] All files have expected row counts (results.csv ≥ 45,000 rows, goalscorers.csv ≥ 45,000 rows, shootouts.csv ≥ 600 rows)

---

### Task 1.3: Create team name mapping CSV (DATA-02)
**Description**: Create canonical team name mapping with FIFA codes

**Sub-tasks**:
- Research FIFA codes and historical team name variations
- Create `team_name_map.csv` with columns: fifa_code, canonical_name, alt_names (pipe-delimited)
- Include all known variations: Turkey/Türkiye, Macedonia/North Macedonia, Czech Republic/Czechia, etc.
- Add entries for all teams in martj42 dataset

**Dependencies**: Task 1.2

**Time Estimate**: 30 minutes

**File Outputs**:
- `data/raw/team_name_map.csv`

**Success Criteria**:
- [ ] CSV contains columns: fifa_code, canonical_name, alt_names
- [ ] All teams from martj42 results.csv have mapping entries
- [ ] Zero unmapped teams when tested against martj42 data

---

### Task 1.4: Ingest StatsBomb domestic league data (DATA-03)
**Description**: Download and cache StatsBomb Open Data for domestic leagues only

**Sub-tasks**:
- Download `competitions.json` from GitHub raw URL
- Filter to domestic leagues only (exclude "World Cup", "UEFA European", "Confederations Cup", "Qualifiers", "Nations League")
- For each domestic competition: download events JSON
- For each domestic competition: download lineups JSON
- Rate limit: 2 seconds between requests

**Dependencies**: Task 1.1

**File Outputs**:
- `data/raw/statsbomb/competitions.json`
- `data/raw/statsbomb/events/{competition_id}.json` (multiple files)
- `data/raw/statsbomb/lineups/{competition_id}.json` (multiple files)

**Success Criteria**:
- [ ] All available domestic league seasons (EPL, La Liga, Bundesliga, Serie A, Ligue 1, Primeira Liga, Eredivisie) downloaded
- [ ] No international tournament data included
- [ ] All JSON files parseable and contain expected structure (matchId, events, etc.)

**Time Estimate**: 60 minutes

---

### Task 1.5: Create schema validation (PIPELINE-03)
**Description**: Implement validation for all ingested data using pointblank

**Sub-tasks**:
- Create `validate_martj42()` function for CSV validation
- Create `validate_statsbomb_events()` function for JSON validation
- Create `validate_statsbomb_lineups()` function for JSON validation
- Create wrapper to run all validations automatically
- Configure pipeline to stop on validation failure

**Dependencies**: Task 1.2, Task 1.4

**Time Estimate**: 20 minutes

**File Outputs**:
- `R/pipeline/validation.R`

**Success Criteria**:
- [ ] Validation runs automatically after each ingest
- [ ] Failed validation stops pipeline with clear error message
- [ ] All validation functions return TRUE on valid data

---

### Task 1.6: Create data inventory (DATA-04)
**Description**: Document all data sources, licenses, and coverage

**Sub-tasks**:
- Document martj42 source: name, type, coverage years, license, access method, key fields, pros/cons, usage rules
- Document StatsBomb source: name, type, coverage years, license, access method, key fields, pros/cons, usage rules
- Document team name mapping source
- Mark open vs restricted sources clearly

**Dependencies**: Task 1.2, Task 1.3, Task 1.4

**Time Estimate**: 15 minutes

**File Outputs**:
- `DATA-INVENTORY.md`

**Success Criteria**:
- [ ] Each source documented with all required fields
- [ ] Open vs restricted sources clearly marked
- [ ] Usage rules for each source specified

---

## Dependency Graph

```
Task 1.1: Cache Directory Setup
    │
    ├─── Task 1.2: Ingest martj42
    │        │
    │        └─── Task 1.3: Team Name Mapping
    │
    └─── Task 1.4: Ingest StatsBomb
             │
             └─── Task 1.5: Schema Validation
                      │
                      └─── Task 1.6: Data Inventory
```

**Parallelizable Tasks**: Task 1.2 and Task 1.4 can run in parallel after Task 1.1

**Critical Path**: 1.1 → 1.2 → 1.3 and 1.1 → 1.4 → 1.5 → 1.6 (1.6 also depends on 1.2, 1.3)

---

## File Output Summary

| Task | Primary Output | Secondary Outputs |
|------|---------------|-------------------|
| 1.1 | Directory structure | `.gitignore` |
| 1.2 | `data/raw/martj42/*.csv` | - |
| 1.3 | `data/raw/team_name_map.csv` | - |
| 1.4 | `data/raw/statsbomb/**/*.json` | `data/raw/statsbomb/competitions.json` |
| 1.5 | `R/pipeline/validation.R` | - |
| 1.6 | `DATA-INVENTORY.md` | - |

---

## Success Criteria Alignment

| Requirement | Task | Success Criteria |
|-------------|------|------------------|
| DATA-01 | 1.2 | `results.csv` loaded with expected schema |
| DATA-02 | 1.3 | All team names mapped to canonical FIFA codes |
| DATA-03 | 1.4 | StatsBomb events and line-ups cached locally |
| DATA-04 | 1.6 | `DATA-INVENTORY.md` documents all sources |
| PIPELINE-02 | 1.1 | Cache directories exist with proper `.gitignore` |
| PIPELINE-03 | 1.5 | Schema validation runs automatically on ingest |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GitHub rate limit exceeded | Medium | High | 2s delay between all requests, retry with exponential backoff |
| martj42 source unavailable | Low | High | Fallback to Kaggle mirror, cache previous version |
| StatsBomb API structure change | Low | Medium | Validate JSON schema before processing, alert on drift |
| Disk space exhaustion | Low | Medium | Monitor cache size, compress JSON files |
| Network connectivity issues | Medium | Medium | Retry failed downloads, resume from checkpoint |

## Execution Notes

### Rate Limiting
- GitHub raw URLs: 60 requests/hour unauthenticated
- **Standard rate**: 2 seconds between all external requests
- Implement exponential backoff on 429/503 responses

### Parallel Execution
Tasks 1.2 (martj42 ingest) and 1.4 (StatsBomb ingest) can run concurrently after Task 1.1 completes. Use separate R sessions or future::future for parallelization.

### Rollback Strategy
- Failed downloads: retry once after 10-second wait, then skip and log
- Cache cleanup: remove partial downloads on failure
- Validation failure: stop pipeline immediately, do not proceed to dependent tasks

### Nyquist Validation
```bash
# Test commands to run after each task
Rscript -e "source('R/pipeline/validation.R'); validate_all()"
# Observability: log all downloads to data/logs/ingest.log
```

### Phase Acceptance Criteria
Phase 1 is complete when:
- All 6 tasks completed
- All success criteria met
- All validations pass
- DATA-INVENTORY.md is complete

### Validation Strategy
```r
# martj42: Use pointblank
library(pointblank)
agent <- create_agent(data) |> 
  col_is_numeric(columns = vars(date, home_score, away_score)) |> 
  col_is_character(columns = vars(home_team, away_team)) |> 
  interrogate()

# StatsBomb: Use custom validation
validate_statsbomb <- function(json) {
  if (!"events" %in% names(json)) stop("Invalid StatsBomb structure")
  TRUE
}
```

### Team Name Mapping Priority
1. Exact FIFA code match
2. Exact canonical name match
3. Fuzzy match on alt_names (pipe-delimited)

### Domestic League Filter
Exclude competitions with names containing:
- "World Cup"
- "UEFA European"
- "Confederations Cup"
- "Qualifiers"
- "Nations League"

### Error Handling
- Retry failed downloads once after 5-second wait
- Log all warnings but continue (don't stop on warnings)
- Stop on validation failures

---
*Plan locked: 2026-06-03 | Next: /gsd-execute-phase 1*

---

## PLAN SUMMARY

**PLAN CREATED** ✓

- **6 tasks** defined
- **1 dependency chain** with 2 parallelizable paths (martj42 vs StatsBomb ingestion)
- **8 file outputs** specified
- **All Phase 1 requirements covered** (DATA-01, DATA-02, DATA-03, DATA-04, PIPELINE-02, PIPELINE-03)
- **Total Time Estimate**: ~2.75 hours (15m + 30m + 60m + 20m + 15m, with parallel execution reducing wall-clock time)
- **Critical Path**: ~100 minutes (1.1 → 1.2 → 1.3 or 1.1 → 1.4 → 1.5 → 1.6)
