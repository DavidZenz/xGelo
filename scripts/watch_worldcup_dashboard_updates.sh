#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INTERVAL_SECONDS="${XGELO_UPDATE_INTERVAL_SECONDS:-3600}"
LOG_FILE="${XGELO_UPDATE_LOG:-logs/auto-update-loop.log}"
MAX_RUNS="${XGELO_UPDATE_MAX_RUNS:-0}"
LOCK_DIR="${XGELO_UPDATE_LOCK_DIR:-logs/dashboard-update-watcher.lock}"

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SECONDS" -lt 60 ]]; then
  echo "XGELO_UPDATE_INTERVAL_SECONDS must be an integer >= 60." >&2
  exit 1
fi

if ! [[ "$MAX_RUNS" =~ ^[0-9]+$ ]]; then
  echo "XGELO_UPDATE_MAX_RUNS must be a non-negative integer." >&2
  exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Dashboard update watcher already appears to be running: ${LOCK_DIR}" >&2
  echo "If this is a stale lock, remove it after confirming no watcher is active." >&2
  exit 1
fi

stop_requested=false
cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT
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
echo "Set XGELO_UPDATE_LOCK_DIR to change the single-watcher lock path."
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
