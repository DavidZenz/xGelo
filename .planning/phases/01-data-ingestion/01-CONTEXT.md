# Phase 1: Data Ingestion & Infrastructure — CONTEXT

---
*Phase*: 1
*Name*: Data Ingestion & Infrastructure  
*Project*: xGelo — Free Elo + xG Forecasting for UEFA World Cup Qualifiers  
*Last Updated*: 2026-06-03
*Status*: Decisions locked, ready for planning

---

## Phase Goal

Ingest all open data sources, establish canonical team naming, set up caching and validation infrastructure to enable xG model training and Elo rating computation.

---

## Decisions

### Data Source Decisions

#### martj42 Source
- **Decision**: Use **GitHub** (`martj42/international_results`) as primary source
- **Rationale**: Direct access, no API key needed, always current from source
- **Implication**: No Kaggle dependency, simpler setup, but respect GitHub rate limits
- **URL**: https://github.com/martj42/international_results

#### StatsBomb Data Selection
- **Decision**: Ingest **all available domestic league seasons** from StatsBomb Open Data
- **Rationale**: Maximize data volume for xG model training while avoiding contamination
- **Critical constraint**: **Explicitly exclude** all international tournaments (World Cup, Euros, Nations League, Qualifiers)
- **Leagues to include**: EPL, La Liga, Bundesliga, Serie A, Ligue 1, Primeira Liga, Eredivisie (all available)
- **Filter rule**: Only use competitions where `competition.competition_name` does NOT contain "World Cup", "Euros", "Qualifiers", "Nations League"

### Team Name Mapping
- **Decision**: Use **manual CSV** (`team_name_map.csv`) for canonical team name mapping
- **Rationale**: Explicit control, easier to audit and maintain
- **Format**: 
  ```csv
  source_name,canonical_name,fifa_code
  Germany,Germany,GER
  Turkey,Türkiye,TUR
  Macedonia,North Macedonia,MKD
  Czech Republic,Czechia,CZE
  ```
- **Primary key**: `fifa_code` where available, fallback to `canonical_name`
- **Sources to map**: martj42, StatsBomb, WCQ fixtures (FotMob/UEFA)

### Caching & Infrastructure

#### Cache Directory Structure
- **Decision**: Organize by **source** (`data/raw/{source}/`)
- **Structure**:
  ```
  data/raw/
  ├── martj42/
  │   ├── results.csv
  │   ├── shootouts.csv
  │   └── goalscorers.csv
  └── statsbomb/
      ├── competitions.json
      ├── events/
      │   └── {competition_id}_{season_id}.json
      └── lineups/
          └── {competition_id}_{season_id}.json
  ```

#### File Versioning
- **Decision**: **Git-only** — rely on git commit history for versioning
- **Rationale**: Keeps filenames clean, version tracking via git is sufficient
- **File naming**: Simple names (`results.csv`, `events.json`) without timestamps or hashes
- **Implication**: Data updates = new git commit, easy to track changes

#### Schema Validation
- **Decision**: Use **`pointblank` package** for schema validation
- **Rationale**: Declarative, R-native, integrates well with tidyverse workflow
- **Implementation**: Validation runs automatically after each ingest target
- **On failure**: Pipeline stops with clear error message
- **Validation scope**: All ingested data (martj42 CSV, StatsBomb JSON)

---

## Canonical References

| Reference | Type | Location | Purpose |
|-----------|------|----------|---------|
| PROJECT.md | Project context | .planning/PROJECT.md | Vision, constraints, decisions |
| REQUIREMENTS.md | Requirements | .planning/REQUIREMENTS.md | DATA-01 to DATA-04, PIPELINE-02, PIPELINE-03 |
| ROADMAP.md | Roadmap | .planning/ROADMAP.md | Phase structure, success criteria |
| STACK.md | Stack | .planning/research/STACK.md | R package specifications |
| PITFALLS.md | Pitfalls | .planning/research/PITFALLS.md | Critical mistakes to avoid |

---

## Prior Decisions Applied

From PROJECT.md:
- Language: R (non-negotiable)
- Pipeline: targets framework
- Open data only (no paid feeds)
- Reproducibility is core requirement
- Modular architecture with clear layer boundaries

From PITFALLS.md (relevant to this phase):
- **Training-prediction data contamination**: Train xG on domestic leagues only, exclude international tournaments
- **Team name inconsistency**: Use canonical mapping with FIFA codes

---

## Implementation Guidance

### martj42 Ingestion (DATA-01)
- Download from GitHub: `https://github.com/martj42/international_results`
- Files needed: `results.csv`, `shootouts.csv`, `goalscorers.csv`
- Store in: `data/raw/martj42/`
- Expected columns in results.csv: `date`, `home_team`, `away_team`, `home_score`, `away_score`, `tournament`, `city`, `country`, `neutral`

### Team Name Mapping (DATA-02)
- Create: `data/raw/team_name_map.csv`
- Columns: `source_name`, `canonical_name`, `fifa_code`
- Validate: Every team in martj42, StatsBomb, and WCQ fixtures must map to exactly one canonical name
- Test: No unmapped teams in merged datasets

### StatsBomb Ingestion (DATA-03)
- Download from GitHub: `https://github.com/statsbomb/open-data`
- Store in: `data/raw/statsbomb/`
- **Filter**: Only domestic leagues (exclude competitions with "World Cup", "Euros", "Qualifiers", "Nations League" in name)
- Files: `competitions.json`, `events/*.json`, `lineups/*.json`

### Data Inventory (DATA-04)
- Create: `DATA-INVENTORY.md`
- For each source, document: name, type, coverage years, license, access method, key fields, pros/cons, usage rules

### Cache Directory Setup (PIPELINE-02)
- Create directory structure: `data/raw/martj42/`, `data/raw/statsbomb/`
- Update `.gitignore` to exclude `data/raw/` from git tracking
- Note: WCQ cache (FotMob/UEFA) will be in `data/raw/wcq_cache/` with manual-only updates

### Schema Validation (PIPELINE-03)
- Use `pointblank` package
- Create validation rules for each source:
  - martj42: Required columns, date format, score ranges
  - StatsBomb: Required fields in JSON, valid coordinate ranges (x: 0-120, y: 0-80)
- Implement as `R/pipeline/validation.R`
- Integration: Run after each ingest target in targets pipeline

---

## Deferred Ideas

None identified during this discussion.

---

## Success Criteria (from ROADMAP.md)

- [ ] `results.csv` loaded with expected schema (date, home_team, away_team, scores, tournament, neutral)
- [ ] All team names from martj42, StatsBomb, and WCQ fixtures mapped to canonical FIFA codes
- [ ] StatsBomb events and line-ups cached locally with versioning
- [ ] `DATA-INVENTORY.md` documents all sources with license and usage rules
- [ ] Cache directories exist with proper `.gitignore` exclusions
- [ ] Schema validation runs automatically on ingest and stops pipeline on failure

---

## Notes for Downstream Agents

### For gsd-project-researcher
- **martj42**: Focus on GitHub access patterns, rate limiting, data schema
- **StatsBomb**: Research how to filter competitions, download specific leagues/seasons, handle pagination
- **Team names**: Research FIFA code standards, known historical team name variations
- **Validation**: Research `pointblank` package patterns for data validation

### For gsd-planner
- **Dependencies**: No external dependencies beyond what's in STACK.md
- **Data volume**: StatsBomb Open Data has ~3M events across covered leagues
- **Performance**: Ingest should handle multi-GB JSON files efficiently
- **Error handling**: Need retry logic for GitHub API, validation errors should halt pipeline

---
*Decisions locked: 2026-06-03 | Next: /gsd-plan-phase 1*
