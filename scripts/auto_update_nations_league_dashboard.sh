#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=false
SKIP_PUSH=false
FORCE_REBUILD=false
SIMULATIONS="${XGELO_NL_SIMULATIONS:-100000}"
WORKERS="${XGELO_NL_WORKERS:-4}"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-push) SKIP_PUSH=true ;;
    --force-rebuild) FORCE_REBUILD=true ;;
    --simulations=*) SIMULATIONS="${arg#*=}" ;;
    *) echo "Unsupported option: $arg" >&2; exit 2 ;;
  esac
done

[[ "$SIMULATIONS" =~ ^[1-9][0-9]*$ ]] || {
  echo "--simulations must be a positive integer." >&2
  exit 2
}
[[ "$WORKERS" =~ ^[1-9][0-9]*$ ]] || {
  echo "XGELO_NL_WORKERS must be a positive integer." >&2
  exit 2
}

if [[ "$DRY_RUN" != true && "$SIMULATIONS" -lt 100000 ]]; then
  echo "Public Nations League updates require at least 100000 simulations; lower counts are dry-run only." >&2
  exit 2
fi

R_SCRIPT="${XGELO_RSCRIPT:-}"
if [[ -z "$R_SCRIPT" ]]; then
  for candidate in /opt/homebrew/opt/r/bin/Rscript /opt/homebrew/bin/Rscript /usr/local/bin/Rscript; do
    if [[ -x "$candidate" ]]; then R_SCRIPT="$candidate"; break; fi
  done
fi
[[ -x "$R_SCRIPT" ]] || { echo "Missing absolute Rscript: $R_SCRIPT" >&2; exit 1; }

# Atomic mkdir prevents overlapping scheduled/manual rebuilds. Never remove a
# lock owned by another process; stale locks require explicit operator review.
LOCK_DIR="$ROOT_DIR/.nations-league-update.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Nations League updater already running (or stale lock): $LOCK_DIR" >&2
  exit 1
fi
cleanup() { rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf '%s\n' "$$" > "$LOCK_DIR/pid"
export XGELO_RSCRIPT="$R_SCRIPT"

EDITION_ID="uefa_nations_league_2026_27"
BUNDLE_ID="nl-2026-27-official-uefa-v2"
CAPTURE_ARGS=(
  --official-uefa-nations-league
  --edition-id "$EDITION_ID"
  --operator automation
  --operator-action "nightly official UEFA Nations League refresh"
  --validation-passed true
)

probe_output="$("$R_SCRIPT" --vanilla scripts/acquire_uefa_snapshot.R "${CAPTURE_ARGS[@]}" --dry-run 2>&1)" || {
  printf '%s\n' "$probe_output" >&2
  echo "Nightly Nations League source probe failed; incumbent publication was left in place." >&2
  exit 1
}
printf '%s\n' "$probe_output"
candidate_hash="$(printf '%s\n' "$probe_output" | sed -n 's/.*source_bundle_sha256=\([0-9a-fA-F]\{64\}\).*/\1/p' | tail -n 1)"
candidate_content_signature="$(printf '%s\n' "$probe_output" | sed -n 's/.*accepted_content_signature=\([0-9a-fA-F]\{64\}\).*/\1/p' | tail -n 1)"
[[ "$candidate_hash" =~ ^[0-9a-fA-F]{64}$ && "$candidate_content_signature" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo "Nightly Nations League source probe did not emit valid source hashes." >&2
  exit 1
}

current_content_signature="$("$R_SCRIPT" --vanilla -e 'source("R/competition/source_contracts.R"); required <- phase13_source_required_resource_types(); tables <- setNames(lapply(required, function(type) utils::read.csv(file.path("data/competition/accepted/uefa_nations_league_2026_27", paste0(type, ".csv")), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")), required); hashes <- vapply(required, function(type) { table <- tables[[type]]; rows <- if ("row_sha256" %in% names(table)) sort(as.character(table$row_sha256)) else character(); phase13_source_sha256(paste(rows, collapse = "\n")) }, character(1)); cat(phase13_source_sha256(paste(paste(required, hashes, sep = "="), collapse = "\n")))')"
if [[ "$candidate_content_signature" == "$current_content_signature" && "$FORCE_REBUILD" != true ]]; then
  echo "No Nations League source change detected; no publication or commit is needed."
  exit 0
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Nations League source changed: content $current_content_signature -> $candidate_content_signature (bundle $candidate_hash)"
  echo "--dry-run requested; downstream rebuild and publication were skipped."
  exit 0
fi

# Never start a public-scale rebuild until this exact implementation has a
# completed 100k (or larger) validated benchmark. No silent sample fallback.
SCALE_EVIDENCE="${XGELO_NL_SCALE_EVIDENCE:-$ROOT_DIR/outputs/benchmarks/nations_league_scale/measurement-100000.csv}"
"$R_SCRIPT" --vanilla -e 'e <- new.env(parent = globalenv()); sys.source("scripts/refresh_competition_dashboards.R", e); a <- commandArgs(trailingOnly = TRUE); e$phase17_validate_scale_evidence(a[[1L]], as.numeric(a[[2L]]), as.numeric(a[[3L]]))' -- "$SCALE_EVIDENCE" "$SIMULATIONS" "$WORKERS"

managed_path() {
  case "$1" in
    R/competition/state_bundle.R|\
    R/competition/uefa_nations_league_adapter.R|\
    R/competition/uefa_nations_league_rules.R|\
    R/competition/uefa_nations_league_simulation.R|\
    data/competition/accepted/uefa_nations_league_2026_27/*|\
    data/competition/registries/competition_editions.csv|\
    data/competition/registries/refresh_batches/uefa_nations_league_2026_27/*|\
    data/competition/registries/source_artifacts.csv|\
    data/competition/registries/source_bundles.csv|\
    data/competition/registries/stage_captures.csv|\
    docs/competitions/*|\
    outputs/competition/uefa_nations_league_2026_27/*|\
    scripts/acquire_uefa_snapshot.R|\
    scripts/refresh_nations_league_state.R|\
    scripts/auto_update_nations_league_dashboard.sh)
      return 0
      ;;
    *) return 1 ;;
  esac
}

dirty_managed_paths=""
while IFS= read -r status_line; do
  path="$(printf '%s' "$status_line" | cut -c4-)"
  if [[ "$path" == *" -> "* ]]; then path="$(printf '%s' "$path" | sed 's/.* -> //')"; fi
  if managed_path "$path"; then dirty_managed_paths="$dirty_managed_paths$path"$'\n'; fi
done < <(git status --porcelain=v1 --untracked-files=all)
if [[ -n "$dirty_managed_paths" ]]; then
  echo "Refusing nightly publication because managed paths are dirty:" >&2
  printf '%s' "$dirty_managed_paths" >&2
  exit 1
fi
git fetch --quiet
[[ "$(git rev-parse @)" == "$(git rev-parse '@{u}')" ]] || {
  echo "Refusing nightly publication because the branch is not upstream-aligned." >&2
  exit 1
}

"$R_SCRIPT" --vanilla scripts/acquire_uefa_snapshot.R "${CAPTURE_ARGS[@]}" --publish-accepted
"$R_SCRIPT" --vanilla scripts/refresh_nations_league_state.R --edition-id "$EDITION_ID"
"$R_SCRIPT" --vanilla scripts/build_nations_league_outcomes.R \
  --edition-id "$EDITION_ID" --simulations "$SIMULATIONS" --workers "$WORKERS" --seed 15017 --write

# Run the SAME source, probability, replay, browser, regression, envelope and
# atomic promotion gates as the release coordinator. This wrapper owns Git only.
"$R_SCRIPT" --vanilla -e 'e <- new.env(parent = globalenv()); sys.source("scripts/refresh_competition_dashboards.R", e); e$phase17_refresh_main(external_git_owner = TRUE, now = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))'

git add -- \
  R/competition/state_bundle.R \
  R/competition/uefa_nations_league_adapter.R \
  R/competition/uefa_nations_league_rules.R \
  R/competition/uefa_nations_league_simulation.R \
  data/competition/accepted/uefa_nations_league_2026_27 \
  data/competition/registries/competition_editions.csv \
  data/competition/registries/refresh_batches/uefa_nations_league_2026_27/status_history.csv \
  data/competition/registries/source_artifacts.csv \
  data/competition/registries/source_bundles.csv \
  data/competition/registries/stage_captures.csv \
  docs/competitions \
  outputs/competition/uefa_nations_league_2026_27 \
  scripts/acquire_uefa_snapshot.R \
  scripts/refresh_nations_league_state.R \
  scripts/auto_update_nations_league_dashboard.sh

# Refuse unrelated pre-staged files rather than including them in this commit.
while IFS= read -r staged_path; do
  if ! managed_path "$staged_path"; then
    echo "Refusing commit of path outside nightly allowlist: $staged_path" >&2
    exit 1
  fi
done < <(git diff --cached --name-only)
git diff --cached --check
git commit -m "Refresh UEFA Nations League dashboard"
if [[ "$SKIP_PUSH" == true ]]; then
  echo "--skip-push requested; commit retained locally."
  exit 0
fi
git push
