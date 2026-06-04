# Phase 1: Data Ingestion & Infrastructure — Research

---
*Phase: 01-data-ingestion* | *Status: Research Complete* | *Date: 2026-06-03*

---

## Overview

Research findings for ingesting martj42 and StatsBomb data, normalizing team names, and establishing caching/validation infrastructure.

---

## 1. GitHub API Access Patterns

### martj42/international_results

**Repository**: https://github.com/martj42/international_results

**Structure**:
```
international_results/
├── aggr/
│   ├── in_90min.csv           # Matches with half-time/full-time scores
│   ├── results.csv            # Core results: date, home, away, score, tournament
│   └── shootouts.csv          # Penalty shootout results
├── by_country/             # Results split by country
└── by_tournament/          # Results split by tournament
```

**Download Pattern (Raw CSV)**:
```r
# Direct raw URL download - NO API needed
results_url <- "https://raw.githubusercontent.com/martj42/international_results/master/aggr/results.csv"
aggr_url <- "https://raw.githubusercontent.com/martj42/international_results/master/aggr/in_90min.csv"

download.file(results_url, destfile = "data/raw/martj42/results.csv", mode = "wb")
download.file(aggr_url, destfile = "data/raw/martj42/in_90min.csv", mode = "wb")
```

**Recommendation**: Use raw GitHub URLs. No authentication required. Rate limits: 60 requests/hour for unauthenticated (sufficient for this use case).

---

### StatsBomb Open Data

**Repository**: https://github.com/statsbomb/open-data

**Structure**:
```
data/
├── competitions.json
├── events/
│   ├── 9250.json       # Premier League 2023-24 events
│   └── ...
├── lineups/
│   ├── 92502.json      # Match lineups
│   └── ...
└── matches/
    └── {season_id}/
        └── {match_id}.json
```

**Competition IDs for Domestic Leagues**:
| League | Competition ID | Notes |
|--------|----------------|-------|
| Premier League | 2 | EPL |
| Bundesliga | 7 | Germany |
| Serie A | 11 | Italy |
| La Liga | 12 | Spain |
| Ligue 1 | 13 | France |
| Primeira Liga | 29 | Portugal |
| Eredivisie | 30 | Netherlands |

**Exclusion Rule**: Skip competition IDs for international tournaments (World Cup, Euros, etc.). Filter by competition name: exclude any containing "World Cup", "UEFA European Championship", "Confederations Cup".

**Download Pattern**:
```r
# Get competition metadata first
comp_url <- "https://raw.githubusercontent.com/statsbomb/open-data/master/data/competitions.json"
comp_data <- jsonlite::fromJSON(comp_url)

# Filter to domestic leagues (exclude international)
domestic_comps <- comp_data[!grepl("World Cup|UEFA European|Confederations Cup", 
                                  comp_data$competition_name, ignore.case = TRUE), ]
domestic_comp_ids <- domestic_comps$competition_id

# Download all events for domestic competitions
library(httr2)
library(jsonlite)

base_url <- "https://raw.githubusercontent.com/statsbomb/open-data/master/data"

for (comp_id in domestic_comp_ids) {
  events_url <- sprintf("%s/events/%d.json", base_url, comp_id)
  lineups_url <- sprintf("%s/lineups/%d.json", base_url, comp_id)

  # Rate limiting: 1 request every 2 seconds
  Sys.sleep(2)

  tryCatch({
    events <- jsonlite::fromJSON(events_url)
    jsonlite::write_json(events, sprintf("data/raw/statsbomb/events/%d.json", comp_id))
  }, error = function(e) warning(sprintf("Failed to download events for comp %d: %s", comp_id, e$message)))

  tryCatch({
    lineups <- jsonlite::fromJSON(lineups_url)
    jsonlite::write_json(lineups, sprintf("data/raw/statsbomb/lineups/%d.json", comp_id))
  }, error = function(e) warning(sprintf("Failed to download lineups for comp %d: %s", comp_id, e$message)))
}
```

**API Considerations**:
- Unauthenticated: 60 requests/hour
- Authenticated (PAT): 5,000 requests/hour
- **Recommendation**: Use raw URLs with rate limiting (2s delay between requests). No PAT needed for initial ingestion.

---

## 2. Downloading Large JSON Files in R

### Best Practices

**Problem**: StatsBomb event files are large (5-50MB each). Memory and timeout issues possible.

**Solutions**:

#### A. Standard Approach (Recommended)
```r
# jsonlite handles most StatsBomb files efficiently
library(jsonlite)

# For a single competition file (all matches in one season)
events <- fromJSON("https://raw.githubusercontent.com/statsbomb/open-data/master/data/events/9250.json")

# Write to disk
write_json(events, "data/raw/statsbomb/events/9250.json")
```

#### B. Process Incrementally
```r
# Process each competition file individually
library(purrr)

comp_ids <- c(9250, 9249, 9248, 9453, 9452, 9451, 9352, 9351, 9350)

walk(comp_ids, ~ {
  url <- sprintf("https://raw.githubusercontent.com/statsbomb/open-data/master/data/events/%d.json", .x)
  dest <- sprintf("data/raw/statsbomb/events/%d.json", .x)
  
  if (!file.exists(dest)) {
    download.file(url, destfile = dest, mode = "wb")
    Sys.sleep(2)  # Rate limiting
  }
})
```

**Performance**: `jsonlite::fromJSON()` works well for files <50MB. StatsBomb competition files are typically 5-30MB.

---

## 3. Team Name Mapping: FIFA Codes

### FIFA Code Standards

**Source**: FIFA uses 3-letter codes (ISO 3166-1 alpha-3) for national teams.

**Mapping File** (`data/raw/team_name_map.csv`):

```csv
fifa_code,canonical_name,alt_names
ENG,England,"Great Britain|UK|England"
SCO,Scotland,"Scotland"
WAL,Wales,"Wales"
NIR,Northern Ireland,"N. Ireland|Northern Ireland"
IRL,Ireland,"Republic of Ireland|ROI"
GER,Germany,"West Germany|FRG|East Germany|DRG"
TUR,Turkey,"T\u001frkiye|Turkey"
CZE,Czech Republic,"Czechia|Czech Rep|Czechoslovakia"
MKD,North Macedonia,"Macedonia|FYR Macedonia"
SRB,Serbia,"Yugoslavia|Serbia & Montenegro|Serbia"
RUS,Russia,"USSR|Soviet Union|Russia"
NED,Netherlands,"Holland|Netherlands"
USA,United States,"USA|United States"
KOR,South Korea,"Korea Republic|South Korea"
IRN,Iran,"Persia|Iran"
COD,DR Congo,"Zaire|DR Congo"
```

### R Implementation

```r
# Load and normalize
team_map <- readr::read_csv("data/raw/team_name_map.csv") |>
  tidyr::separate_longer_delim(alt_names, delim = "\\|") |>
  mutate(alt_names = stringr::str_trim(alt_names)) |>
  pivot_longer(cols = c(canonical_name, alt_names), names_to = "source", values_to = "name")

# Normalize function
normalize_team_name <- function(name, mapping = team_map) {
  name_clean <- stringr::str_trim(tolower(name))
  
  match <- mapping |>
    mutate(name_lower = tolower(name)) |>
    filter(stringr::str_detect(name_lower, regex(name_clean, ignore_case = TRUE))) |>
    slice(1)
  
  if (nrow(match) == 0) {
    warning(sprintf("No match found for team: %s", name))
    return(NA_character_)
  }
  
  match$fifa_code
}
```

---

## 4. pointblank Validation Patterns

### Setup
```r
library(pointblank)
library(tidyverse)
```

### martj42 Validation

```r
validate_martj42 <- function(file_path) {
  data <- readr::read_csv(file_path, show_col_types = FALSE)
  
  agent <- create_agent(data) |>
    col_is_numeric(columns = vars(date, home_score, away_score)) |>
    col_is_character(columns = vars(home_team, away_team, tournament, city, country, neutral)) |>
    col_vals_between(left = vars(home_score, away_score), right = c(0, 20)) |>
    col_vals_regex(columns = vars(date), regex = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") |>
    col_vals_in_set(columns = vars(neutral), set = c("TRUE", "FALSE", "true", "false", NA)) |>
    col_vals_not_null(columns = vars(date, home_team, away_team, home_score, away_score)) |>
    interrogate()
  
  if (!is_interrogated(agent)) {
    stop("Validation failed: ", paste(get_report(agent)$output, collapse = "; "))
  }
  
  TRUE
}
```

### StatsBomb JSON Validation

```r
validate_statsbomb_events <- function(file_path) {
  json <- jsonlite::fromJSON(file_path, simplifyVector = FALSE)
  
  # Check top-level structure
  if (!all(c("matchId", "events") %in% names(json))) {
    stop("Missing required fields in StatsBomb events file: ", file_path)
  }
  
  # Validate events structure
  events <- json$events
  required_event_fields <- c("id", "type", "minute", "second", "timestamp", "possession", "team", "player")
  
  if (length(events) > 0 && !all(required_event_fields %in% names(events[[1]]))) {
    missing <- setdiff(required_event_fields, names(events[[1]]))
    stop("Missing required event fields: ", paste(missing, collapse = ", "))
  }
  
  TRUE
}
```

---

## 5. Cache Organization

### Directory Structure

```
data/
├── raw/
│   ├── martj42/
│   │   ├── results.csv
│   │   ├── in_90min.csv
│   │   ├── shootouts.csv
│   │   └── README.txt
│   │
│   ├── statsbomb/
│   │   ├── competitions.json
│   │   ├── events/
│   │   │   └── {competition_id}.json
│   │   ├── lineups/
│   │   │   └── {competition_id}.json
│   │   └── README.txt
│   │
│   └── team_name_map.csv
│
├── processed/ (gitignored or rebuilt)
│   ├── martj42/
│   └── statsbomb/
│
└── cache/ (gitignored - manual only)
    └── wcq_cache/
        └── fotmob/
```

### .gitignore

```gitignore
# Manual cache (ToS-restricted sources)
data/cache/
data/raw/wcq_cache/
data/raw/fotmob/

# Large processed files (rebuildable)
data/processed/*.parquet
data/processed/*.fst

# Temp files
*.tmp
*~ 
.DS_Store
```

### Download Scripts

**R/data_ingest/martj42.R**:
```r
download_martj42 <- function(dest_dir = "data/raw/martj42") {
  fs::dir_create(dest_dir)
  
  files <- list(
    list(url = "https://raw.githubusercontent.com/martj42/international_results/master/aggr/results.csv",
         dest = file.path(dest_dir, "results.csv")),
    list(url = "https://raw.githubusercontent.com/martj42/international_results/master/aggr/in_90min.csv",
         dest = file.path(dest_dir, "in_90min.csv")),
    list(url = "https://raw.githubusercontent.com/martj42/international_results/master/aggr/shootouts.csv",
         dest = file.path(dest_dir, "shootouts.csv"))
  )
  
  for (file in files) {
    if (!file.exists(file$dest)) {
      download.file(file$url, destfile = file$dest, mode = "wb")
      Sys.sleep(1)
    }
  }
  
  # Validate
  purrr::walk(files, function(f) validate_martj42(f$dest))
}
```

**R/data_ingest/statsbomb.R**:
```r
download_statsbomb_domestic <- function(dest_dir = "data/raw/statsbomb") {
  fs::dir_create(file.path(dest_dir, "events"))
  fs::dir_create(file.path(dest_dir, "lineups"))
  
  # Get competitions
  comp_url <- "https://raw.githubusercontent.com/statsbomb/open-data/master/data/competitions.json"
  comp_data <- jsonlite::fromJSON(comp_url)
  
  # Filter to domestic leagues
  domestic_comps <- comp_data[!grepl("World Cup|UEFA European|Confederations Cup", 
                                    comp_data$competition_name, ignore.case = TRUE), ]
  
  for (comp in domestic_comps) {
    comp_id <- comp$competition_id
    
    # Download events
    events_url <- sprintf("https://raw.githubusercontent.com/statsbomb/open-data/master/data/events/%d.json", comp_id)
    events_dest <- file.path(dest_dir, "events", sprintf("%d.json", comp_id))
    if (!file.exists(events_dest)) {
      download.file(events_url, destfile = events_dest, mode = "wb")
      Sys.sleep(2)
    }
    
    # Download lineups
    lineups_url <- sprintf("https://raw.githubusercontent.com/statsbomb/open-data/master/data/lineups/%d.json", comp_id)
    lineups_dest <- file.path(dest_dir, "lineups", sprintf("%d.json", comp_id))
    if (!file.exists(lineups_dest)) {
      download.file(lineups_url, destfile = lineups_dest, mode = "wb")
      Sys.sleep(2)
    }
  }
  
  # Download competitions.json
  download.file(comp_url, destfile = file.path(dest_dir, "competitions.json"), mode = "wb")
}
```

---

## Implementation Summary

| Task | File | Function |
|------|------|----------|
| martj42 download | `R/data_ingest/martj42.R` | `download_martj42()` |
| StatsBomb download | `R/data_ingest/statsbomb.R` | `download_statsbomb_domestic()` |
| Team name mapping | `data/raw/team_name_map.csv` | `normalize_team_name()` |
| martj42 validation | `R/pipeline/validation.R` | `validate_martj42()` |
| StatsBomb validation | `R/pipeline/validation.R` | `validate_statsbomb_events()` |
| Cache directories | `.gitignore` | Exclude manual cache |
| Data inventory | `DATA-INVENTORY.md` | Document all sources |

---

## Recommendations for Planner

1. **martj42**: Direct GitHub raw URL downloads, no API needed, rate limit 60/hr
2. **StatsBomb**: Raw URL downloads with 2-second delay between requests
3. **Team names**: Manual CSV with FIFA codes + fuzzy matching fallback
4. **Validation**: pointblank for CSV, custom for JSON
5. **Cache**: Organize by source, gitignore manual caches

---
*Research complete: 2026-06-03 | Phase: 01-data-ingestion*
