#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INTERVAL_SECONDS="${XGELO_UPDATE_INTERVAL_SECONDS:-3600}"
LOG_FILE="${XGELO_UPDATE_LOG:-logs/auto-update-loop.log}"
MAX_RUNS="${XGELO_UPDATE_MAX_RUNS:-0}"

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SECONDS" -lt 60 ]]; then
  echo "XGELO_UPDATE_INTERVAL_SECONDS must be an integer >= 60." >&2
  exit 1
fi

if ! [[ "$MAX_RUNS" =~ ^[0-9]+$ ]]; then
  echo "XGELO_UPDATE_MAX_RUNS must be a non-negative integer." >&2
  exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

stop_requested=false
trap 'stop_requested=true' INT TERM

run_update() {
  local started_at
  local exit_code

  started_at="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "[$started_at] Starting dashboard auto-update. Log: $LOG_FILE"
  {
    echo
    echo "===== ${started_at} dashboard auto-update ====="
    scripts/auto_update_worldcup_dashboard.sh
  } >> "$LOG_FILE" 2>&1
  exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Dashboard auto-update finished."
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] Dashboard auto-update failed with exit code ${exit_code}; continuing loop." >&2
  fi
}

echo "Watching for dashboard data updates every ${INTERVAL_SECONDS}s."
echo "Set XGELO_UPDATE_INTERVAL_SECONDS to change the interval."
echo "Set XGELO_UPDATE_LOG to change the log path."
echo "Set XGELO_UPDATE_MAX_RUNS to stop after a fixed number of checks; 0 means unlimited."
echo "Press Ctrl-C to stop."

run_count=0
while [[ "$stop_requested" == "false" ]]; do
  run_update
  run_count=$((run_count + 1))

  if [[ "$stop_requested" == "true" ]]; then
    break
  fi

  if [[ "$MAX_RUNS" -gt 0 && "$run_count" -ge "$MAX_RUNS" ]]; then
    break
  fi

  echo "Sleeping for ${INTERVAL_SECONDS}s."
  sleep "$INTERVAL_SECONDS" || break
done

echo "Dashboard update watcher stopped."
