# xGelo Data Inventory

*Project: xGelo - Free Elo + xG Forecasting for UEFA World Cup Qualifiers*
*Last Updated: 2026-06-03*
*Status: Phase 1 - Data Ingestion*

---

## Overview

This document catalogs all data sources used in the xGelo project, including their licenses, access methods, coverage, and usage rules. Data is categorized as **Open** (free to use and redistribute) or **Restricted** (cannot be systematically accessed or redistributed).

---

## Data Sources

### Open Data Sources (Unrestricted Use)

#### 1. martj42 International Football Results

| Field | Value |
|-------|-------|
| **Name** | martj42/international_results |
| **Type** | Match results, shootouts, goal scorers |
| **Source URL** | https://github.com/martj42/international_results |
| **Access Method** | GitHub raw file downloads |
| **License** | MIT (implied from GitHub public repo) |
| **Coverage Years** | 1872 - 2025 |
| **Coverage Scope** | All men's international football matches |
| **Update Frequency** | As new matches are played |

**Key Files:**
- `results.csv` - Match results (~49,369 rows)
- `goalscorers.csv` - Goal scorers (~47,602 rows)
- `shootouts.csv` - Penalty shootout results (~678 rows)

**Key Fields:**
- `date` - Match date (YYYY-MM-DD)
- `home_team` - Home team name
- `away_team` - Away team name
- `home_score` - Home team goals
- `away_score` - Away team goals
- `tournament` - Competition name
- `city` - Match city
- `country` - Match country
- `neutral` - Neutral venue flag

**Pros:**
- Comprehensive historical coverage (1872-present)
- Simple CSV format
- No API key required
- Actively maintained

**Cons:**
- No shot-level data
- Team names may vary over time (requires normalization)
- No xG or advanced metrics

**Usage Rules:**
- ✅ Free to download and use
- ✅ Can be redistributed
- ✅ Can be cached locally
- ⚠️ Respect GitHub rate limits (60 requests/hour unauthenticated)

---

#### 2. StatsBomb Open Data

| Field | Value |
|-------|-------|
| **Name** | StatsBomb Open Data |
| **Type** | Event-level data, line-ups, 360 data |
| **Source URL** | https://github.com/statsbomb/open-data |
| **Access Method** | GitHub raw file downloads |
| **License** | Creative Commons Attribution-NonCommercial-ShareAlike 4.0 |
| **Coverage Years** | Varies by competition (World Cups: 1958-2022, Domestic leagues: ~2015-present) |
| **Coverage Scope** | Selected FIFA tournaments, domestic leagues, and women's competitions |
| **Update Frequency** | As new data becomes available |

**Key Files:**
- `competitions.json` - Competition metadata
- `events/{match_id}.json` - Match event data
- `lineups/{match_id}.json` - Match lineup data

**Key Fields (Events):**
- `id` - Event ID
- `index` - Event sequence number
- `period` - Match period (1-4 for regular time, 5+ for extra time)
- `timestamp` - Event timestamp
- `minute` - Match minute
- `second` - Match second
- `type` - Event type (Shot, Pass, Goal Keeper, etc.)
- `possession_team` - Team in possession
- `location` - X,Y coordinates (for shots)
- `shot` - Shot-specific data (outcome, body part, technique, etc.)

**Key Fields (Lineups):**
- `team` - Team name
- `player` - Player name and ID
- `position` - Player position
- `jersey_number` - Shirt number

**Pros:**
- Rich event-level data with coordinates
- Includes xG-relevant features (shot location, body part, etc.)
- Standardized format across competitions
- Open license for non-commercial use

**Cons:**
- Does NOT include WCQ-UEFA (our target competition)
- Large file sizes (each match is ~1-3MB JSON)
- NC license restricts commercial use
- No direct API (must download from GitHub)

**Usage Rules:**
- ✅ Free to download and use for non-commercial purposes
- ❌ Cannot be used for commercial purposes without license
- ✅ Can be cached locally
- ⚠️ Respect GitHub rate limits
- ⚠️ Cannot redistribute modified data under different license

**Filtered for xGelo:**
- Only domestic league data included (no World Cup, Euros, etc.)
- Target leagues: Premier League, La Liga, Bundesliga, Serie A, Ligue 1, etc.

---

### Restricted Data Sources (Manual Cache Only)

#### 3. Team Name Mapping (Internal)

| Field | Value |
|-------|-------|
| **Name** | xGelo Team Name Mapping |
| **Type** | Canonical team name mapping |
| **Source** | Internal (manual curation) |
| **File** | `data/raw/team_name_map.csv` |
| **License** | Project-internal |

**Key Fields:**
- `source_name` - Original team name from source
- `canonical_name` - Standardized team name
- `fifa_code` - FIFA 3-letter country code
- `alt_names` - Pipe-delimited alternative names

**Coverage:**
- All teams from martj42 dataset (336 unique names)
- 190 teams mapped to FIFA codes
- 146 historical/regional teams without FIFA codes (marked as unmapped)

**Pros:**
- Enables cross-source team matching
- Handles historical name changes (Turkey/Türkiye, Macedonia/North Macedonia, etc.)

**Usage Rules:**
- ✅ Internal use only
- ✅ Can be extended as needed

#### 4. Transfermarkt Dataset Snapshot (Optional)

| Field | Value |
|-------|-------|
| **Name** | dcaribou/transfermarkt-datasets |
| **Type** | Player metadata, dated market valuations, appearances, lineups |
| **Source URL** | https://github.com/dcaribou/transfermarkt-datasets |
| **Access Method** | Local DuckDB snapshot only |
| **License** | CC0-1.0 in upstream repository |
| **Coverage Scope** | Club and player data with dated player valuations |
| **Update Frequency** | Upstream refresh cadence varies; snapshot locally |

**xGelo Usage:**
- Optional, default-off squad-strength features
- Local file: `data/raw/transfermarkt/transfermarkt-datasets.duckdb`
- Processed output: `data/processed/transfermarkt_squad_strength.csv`

**Leakage Rules:**
- Use only player valuations with `valuation_date < match_date`
- For frozen benchmarks, use only source rows before the benchmark cutoff
- Same-day rows are treated as unavailable
- Missing pre-match values are excluded from aggregates and surfaced through
  `missing_value_share`

**Usage Rules:**
- ✅ Can be used from a local snapshot
- ✅ Snapshot metadata/checksums may be committed
- ❌ Raw DuckDB snapshots are not committed or redistributed by this repo
- ⚠️ Check upstream source terms before publishing derived datasets

---

## Data Directory Structure

```
data/
├── raw/
│   ├── martj42/
│   │   ├── results.csv
│   │   ├── goalscorers.csv
│   │   ├── shootouts.csv
│   │   └── team_name_map.csv
│   ├── statsbomb/
│   │   ├── competitions.json
│   │   ├── events/
│   │   │   └── {match_id}.json
│   │   └── lineups/
│   │       └── {match_id}.json
│   ├── wcq_cache/
│   └── cache/
└── processed/ (created in later phases)
```

---

## Git Ignore Rules

The following directories are excluded from version control:
- `data/raw/wcq_cache/` - Manual cache for WCQ data
- `data/cache/` - General cache directory

---

## Validation

All ingested data is validated using `R/pipeline/validation.R`:
- **martj42**: CSV structure, required columns, data types
- **StatsBomb**: JSON structure, event/lineup format, required fields
- **Team Mapping**: CSV structure, required columns

Validation runs automatically after each ingest and stops the pipeline on failure.

---

## Usage Summary

| Source | Open/Restricted | Use Case | Current Status |
|--------|-----------------|----------|----------------|
| martj42 | ✅ Open | Elo backbone (historical results) | ✅ Ingested |
| StatsBomb | ✅ Open (NC) | xG model training data | ✅ Sample ingested |
| Team Mapping | Internal | Cross-source team matching | ✅ Created |
| Transfermarkt snapshot | ✅ Open upstream / local optional | Squad-strength features and EURO 2024 benchmark | ⏳ Optional |
| FotMob | ⚠️ Restricted | WCQ shot data | ⏳ Not yet ingested |
| UEFA/FIFA | ✅ Open | WCQ fixtures, line-ups | ⏳ Not yet ingested |

---

## Notes

1. **StatsBomb Data**: Due to the large volume of data (1000s of match files), only a sample has been ingested during Phase 1. A full ingestion script is available but should be run in batches to respect rate limits.

2. **Team Names**: The `team_name_map.csv` includes historical teams and regions (Czechoslovakia, Yugoslavia, etc.) that no longer exist. These are preserved for historical Elo calculations.

3. **Validation**: The validation script uses basic R checks. For production use, consider reinstating pointblank for more comprehensive validation.

4. **Future Sources**: FotMob data for WCQ-UEFA will be added in later phases as manual cache files, respecting their ToS restrictions.
