#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=false
SKIP_PUSH=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-push) SKIP_PUSH=true ;;
    *) echo "Unsupported option: $arg" >&2; exit 2 ;;
  esac
done

R_SCRIPT="${XGELO_RSCRIPT:-/opt/homebrew/bin/Rscript}"
[[ -x "$R_SCRIPT" ]] || { echo "Missing absolute Rscript: $R_SCRIPT" >&2; exit 1; }

ALLOWLIST=()
while IFS= read -r path; do
  [[ -n "$path" ]] && ALLOWLIST+=("$path")
done < <("$R_SCRIPT" --vanilla scripts/refresh_competition_dashboards.R --emit-git-allowlist)
[[ "${#ALLOWLIST[@]}" -gt 0 ]] || { echo "Phase 17 Git allowlist is empty" >&2; exit 1; }

git_preflight() {
  local allow_staged="${1:-false}"
  if [[ "$allow_staged" != true && -n "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
    echo "Refusing Phase 17 publication with a dirty worktree." >&2
    return 1
  fi
  if [[ "$allow_staged" == true && -n "$(git diff --name-only)" ]]; then
    echo "Refusing Phase 17 publication with unstaged changes." >&2
    return 1
  fi
  git fetch --quiet
  local local_head upstream_head
  local_head="$(git rev-parse @)"
  upstream_head="$(git rev-parse '@{u}')"
  [[ "$local_head" == "$upstream_head" ]] || {
    echo "Refusing Phase 17 publication because local HEAD is not upstream-aligned." >&2
    echo "Local: $local_head" >&2
    echo "Upstream: $upstream_head" >&2
    return 1
  }
}

if [[ "$DRY_RUN" != true ]]; then
  git_preflight
fi

CLI_ARGS=(--fixture-root "$ROOT_DIR" --public-root "$ROOT_DIR/docs/competitions")
if [[ "$DRY_RUN" == true ]]; then
  CLI_ARGS+=(--dry-run --skip-git)
fi
"$R_SCRIPT" --vanilla scripts/refresh_competition_dashboards.R "${CLI_ARGS[@]}"

if [[ "$DRY_RUN" == true ]]; then
  exit 0
fi

git add -- "${ALLOWLIST[@]}"
STAGED=()
while IFS= read -r path; do
  [[ -n "$path" ]] && STAGED+=("$path")
done < <(git diff --cached --name-only --diff-filter=ACMRT | sort -u)
for path in "${STAGED[@]}"; do
  if ! printf '%s\n' "${ALLOWLIST[@]}" | grep -Fxq "$path"; then
    echo "Phase 17 staged path is outside the exact allowlist: $path" >&2
    exit 1
  fi
done

"$R_SCRIPT" --vanilla -e 'source("R/dashboard/payload_contract.R"); files <- commandArgs(trailingOnly = TRUE); phase17_validate_byte_limits(files); invisible(TRUE)' -- "${STAGED[@]}"
git_preflight true
[[ -z "$(git diff --cached --name-only --diff-filter=ACMRT | grep -Ev '^(R/dashboard/|scripts/|tests/testthat/test_phase17_dashboards.R$|docs/competitions/)')" ]] || {
  echo "Phase 17 staged inventory contains an unapproved path." >&2
  exit 1
}

git commit -m "Auto-update competition dashboards $(date -u +%Y-%m-%d)"
git_preflight
if [[ "$SKIP_PUSH" == true ]]; then
  echo "--skip-push requested; commit retained locally and push blocked by policy."
  exit 0
fi
if ! git push; then
  echo "Phase 17 Git push failed; no retry was attempted." >&2
  exit 1
fi
