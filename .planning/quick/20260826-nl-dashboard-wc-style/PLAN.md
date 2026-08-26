# Quick Task: Rebuild Nations League dashboard in World Cup style

**Date:** 2026-08-26
**Status:** Completed

## Objective

Replace the generic Phase 17 Nations League section list with a World Cup-style static dashboard shell: a meaningful default groups/standings view, separate fixtures and results views, match-level forecast detail, a compact format view, and truthful unresolved/pre-draw states. Preserve the shared payload, validation, provenance, and atomic publication contracts.

## Plan

1. Extend the Phase 17 renderer with a WC-style presentation model for Nations League while retaining the existing neutral payload and safe public projections.
2. Render grouped NL tables, fixture/result cards, outcome/format surfaces, and URL-addressable client-side tabs with context-aware filters.
3. Fix the edition-level scheduled-state label and ensure empty/unresolved data is explicit rather than represented as fake rows.
4. Update regression tests for the new markup and state behavior; run the focused and full dashboard suites.
5. Regenerate the published NL/EURO routes, validate the atomic batch, commit only task-owned files, and push.

## Verification

- Phase 17 dashboard tests pass.
- NL markup contains only public fields and WC-style view controls.
- Scheduled NL state is not labeled refresh-blocked.
- Results/form surfaces do not render scheduled fixture duplicates as completed/evidence rows.
- Published batch inventory and route manifests validate.

## Completion notes

- Added a Nations League-only WC-style renderer while preserving the shared Phase 17 payload and publication contract.
- Published grouped forecast tables, Forecast/Current toggles, Fixtures and Results tabs, Outlook and Format views, and context-aware match filters.
- Scheduled match forecasts remain visible; completed Results stays empty until a final score exists.
- Aggregate rank probabilities remain explicitly unresolved while accepted xPts/xGD inputs are shown.
- Focused Phase 17 dashboard tests pass; full-suite failures are existing data/release-preflight issues outside this dashboard change.
