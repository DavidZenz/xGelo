#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AUTO_PUSH="${XGELO_AUTO_PUSH:-true}"
AUTO_FORCE="${XGELO_AUTO_FORCE:-false}"
MATCH_SIMS="${XGELO_MATCH_SIMS:-100000}"
TOURNAMENT_SIMS="${XGELO_TOURNAMENT_SIMS:-100000}"
DASHBOARD_WORKERS="${XGELO_DASHBOARD_WORKERS:-4}"
OUTPUT_DIR="${XGELO_OUTPUT_DIR:-outputs/dashboard_100k}"
PAGES_DIR="${XGELO_PAGES_DIR:-docs/wc2026}"
ELORATINGS_CHANGED="false"
ESPN_CHANGED="false"

download_if_changed() {
  local url="$1"
  local path="$2"
  local tmp

  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp)"
  curl -L --fail -sS -o "$tmp" "$url"

  if [[ ! -f "$path" ]] || ! cmp -s "$tmp" "$path"; then
    mv "$tmp" "$path"
    return 0
  fi

  rm -f "$tmp"
  return 1
}

if [[ ! -f "data/raw/transfermarkt/transfermarkt-datasets.duckdb" ]]; then
  echo "Missing local Transfermarkt snapshot: data/raw/transfermarkt/transfermarkt-datasets.duckdb" >&2
  exit 1
fi

if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
  echo "Refusing to auto-update with existing tracked changes. Commit or stash them first." >&2
  exit 1
fi

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git fetch --quiet
  LOCAL_HEAD="$(git rev-parse @)"
  UPSTREAM_HEAD="$(git rev-parse '@{u}')"
  if [[ "$LOCAL_HEAD" != "$UPSTREAM_HEAD" ]]; then
    echo "Refusing to auto-update because local branch is not aligned with upstream." >&2
    echo "Local:    $LOCAL_HEAD" >&2
    echo "Upstream: $UPSTREAM_HEAD" >&2
    exit 1
  fi
fi

echo "Downloading upstream martj42 data..."
curl -L --fail -o data/raw/martj42/results.csv \
  https://raw.githubusercontent.com/martj42/international_results/master/results.csv
curl -L --fail -o data/raw/martj42/shootouts.csv \
  https://raw.githubusercontent.com/martj42/international_results/master/shootouts.csv
curl -L --fail -o data/raw/martj42/goalscorers.csv \
  https://raw.githubusercontent.com/martj42/international_results/master/goalscorers.csv

echo "Downloading EloRatings fallback data..."
if download_if_changed "https://www.eloratings.net/latest.tsv" "data/raw/eloratings/latest.tsv"; then
  ELORATINGS_CHANGED="true"
fi
if download_if_changed "https://www.eloratings.net/en.teams.tsv" "data/raw/eloratings/en.teams.tsv"; then
  ELORATINGS_CHANGED="true"
fi

echo "Downloading ESPN scoreboard fallback data..."
ESPN_DATES="$(Rscript --vanilla -e 'cat(format(seq.Date(Sys.Date() - 2L, Sys.Date() + 1L, by = "day"), "%Y%m%d"), sep = "\n")')"
while IFS= read -r ESPN_DATE; do
  if [[ -n "$ESPN_DATE" ]] &&
    download_if_changed "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=${ESPN_DATE}" "data/raw/espn/scoreboard_${ESPN_DATE}.json"; then
    ESPN_CHANGED="true"
  fi
done <<< "$ESPN_DATES"

if [[ "$AUTO_FORCE" != "true" ]] &&
  git diff --quiet --exit-code -- data/raw/martj42 &&
  [[ "$ELORATINGS_CHANGED" != "true" ]] &&
  [[ "$ESPN_CHANGED" != "true" ]]; then
  echo "No upstream martj42, EloRatings, or ESPN fallback data changes detected. Nothing to rebuild."
  exit 0
fi

DEFAULT_FEATURE_CUTOFF="$(Rscript --vanilla -e 'cat(as.character(Sys.Date() - 1L))')"
DEFAULT_ACTUAL_CUTOFF="$(Rscript --vanilla -e 'cat(as.character(Sys.Date()))')"
export XGELO_FEATURE_CUTOFF_DATE="${XGELO_FEATURE_CUTOFF_DATE:-$DEFAULT_FEATURE_CUTOFF}"
export XGELO_MODEL_TRAINING_CUTOFF_DATE="${XGELO_MODEL_TRAINING_CUTOFF_DATE:-$DEFAULT_ACTUAL_CUTOFF}"
export XGELO_ACTUAL_RESULTS_CUTOFF_DATE="${XGELO_ACTUAL_RESULTS_CUTOFF_DATE:-$DEFAULT_ACTUAL_CUTOFF}"
export XGELO_MATCH_SIMS="$MATCH_SIMS"
export XGELO_TOURNAMENT_SIMS="$TOURNAMENT_SIMS"
export XGELO_DASHBOARD_WORKERS="$DASHBOARD_WORKERS"
export XGELO_OUTPUT_DIR="$OUTPUT_DIR"
export XGELO_PAGES_DIR="$PAGES_DIR"

echo "Rebuilding processed data and hybrid forecast artifacts..."
Rscript --vanilla -e '
source("_targets.R")
refresh_targets <- c(
  "elo_matches", "elo_result", "elo_ratings_file", "rolling_form_file",
  "transfermarkt_squad_strength_file", "transfermarkt_value_audit_file",
  "hybrid_goal_training_features_file", "home_goal_model_hybrid",
  "away_goal_model_hybrid", "xg_feature_usage_audit_file",
  "worldcup_forecast_features_file", "euro2024_benchmark"
)
targets::tar_invalidate(tidyselect::any_of(refresh_targets))
targets::tar_make(names = tidyselect::any_of(refresh_targets), callr_function = NULL)
'

echo "Building publication dashboard..."
Rscript --vanilla scripts/update_worldcup_dashboard.R

echo "Running tests..."
Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'

git add -u
git add data/processed/eloratings_score_fallback_audit.csv 2>/dev/null || true
git add data/processed/espn_score_fallback_audit.csv 2>/dev/null || true
git add data/processed/verified_score_fallback_audit.csv 2>/dev/null || true
if git diff --cached --quiet --exit-code; then
  echo "No tracked output changes after rebuild. Nothing to commit."
  exit 0
fi

COMMIT_DATE="$(Rscript --vanilla -e 'cat(as.character(Sys.Date()))')"
git commit -m "Auto-update WC2026 dashboard ${COMMIT_DATE}"

if [[ "$AUTO_PUSH" == "true" ]]; then
  git push
else
  echo "XGELO_AUTO_PUSH=false; commit created but not pushed."
fi
