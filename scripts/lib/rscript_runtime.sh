#!/usr/bin/env bash
# Shared executable discovery for non-WC jobs. Source this file; no startup
# profiles, credentials or environment contents are printed by discovery.

xgelo_rscript_fallbacks() {
  printf '%s\n' /opt/homebrew/opt/r/bin/Rscript /usr/local/opt/r/bin/Rscript \
    /Library/Frameworks/R.framework/Resources/bin/Rscript /usr/bin/Rscript
}

xgelo_probe_rscript() {
  local candidate="$1" version
  [[ -f "$candidate" && -x "$candidate" ]] || return 1
  version="$("$candidate" --version 2>&1)" || return 1
  [[ "$version" == Rscript*version* || "$version" == *'R scripting front-end version'* ]] || return 1
  XGELO_RSCRIPT_VERSION="${version%%$'\n'*}"
}

xgelo_resolve_rscript() {
  local requested="${XGELO_RSCRIPT:-}" candidate discovered
  if [[ -n "$requested" ]]; then
    candidate="$requested"
    if [[ "$requested" != */* ]]; then candidate="$(command -v "$requested" 2>/dev/null || true)"; fi
    if ! xgelo_probe_rscript "$candidate"; then
      printf 'Invalid XGELO_RSCRIPT: %s (must resolve to an executable Rscript that passes --version).\n' "$requested" >&2
      return 1
    fi
    R_SCRIPT="$candidate"
  else
    R_SCRIPT=""
    discovered="$(command -v Rscript 2>/dev/null || true)"
    if [[ -n "$discovered" ]] && xgelo_probe_rscript "$discovered"; then R_SCRIPT="$discovered"; fi
    if [[ -z "$R_SCRIPT" ]]; then
      while IFS= read -r candidate; do
        if xgelo_probe_rscript "$candidate"; then R_SCRIPT="$candidate"; break; fi
      done < <(xgelo_rscript_fallbacks)
    fi
    if [[ -z "$R_SCRIPT" ]]; then
      printf 'Rscript discovery failed. Set XGELO_RSCRIPT to a working executable. Checked PATH and standard R/Homebrew installations.\n' >&2
      return 1
    fi
  fi
  export R_SCRIPT XGELO_RSCRIPT_VERSION
  printf 'XGELO_RUNTIME executable=%s version=%s\n' "$R_SCRIPT" "$XGELO_RSCRIPT_VERSION" >&2
}
