---
phase: 14-shared-competition-state-and-forecast-layer
plan: "18"
subsystem: competition-state-forecast
tags: [R, nations-league, official-source, durable-output, atomic-promotion]

# Dependency graph
requires:
  - phase: 14-shared-competition-state-and-forecast-layer
    provides: Official UEFA source bundle, canonical identity, standings/form contracts, and approved calibrated release authority.
provides:
  - Durable eleven-artifact UEFA Nations League 2026/27 state and forecast bundle.
  - Official 156-fixture forecast coverage with G=40 score grids and compact top-10 outputs.
affects: [phase-14-completion, phase-15, phase-16, phase-17]

requirements-completed: [STATE-01, STATE-02, STATE-03, STATE-04, FORECAST-01, FORECAST-02, FORECAST-03]

coverage:
  - id: D1
    description: "Promoted the exact eleven-artifact official NL state/forecast inventory with self-hashed manifest and durable read-back."
    requirement: STATE-01
    verification:
      - kind: integration
        ref: "phase14_validate_competition_state_bundle on the promoted edition directory"
        status: pass
    human_judgment: false
  - id: D2
    description: "Preserved official fixture, group, team, status, forecast, grid, and top-10 coverage without silent drops."
    requirement: FORECAST-01
    verification:
      - kind: integration
        ref: "156 fixtures, 14 groups, 54 teams, 156 available forecasts, 1,560 top-10 rows, and 262,236 G=40 grid rows"
        status: pass
    human_judgment: false
  - id: D3
    description: "Retained approved calibrated release lineage, strict cutoff lineage, and explicit inactive national-team xG unavailability."
    requirement: FORECAST-02
    verification:
      - kind: integration
        ref: "Direct acceptance assertions over status, forecasts, top-10, manifest, model cutoff, release identity, and xG audit fields"
        status: pass
    human_judgment: false
  - id: D4
    description: "Proved staging validation, injected rollback, atomic promotion, and post-promotion durable validation."
    requirement: STATE-04
    verification:
      - kind: integration
        ref: "Disposable rollback probe plus same-filesystem directory promotion and durable validator"
        status: pass
    human_judgment: false
---

# Phase 14 Plan 18: Official Nations League State and Forecast Bundle

**The official `nl-2026-27-official-uefa-v2` Nations League 2026/27 bundle is now durable, validated, and forecast-complete.**

## Performance

- **Started:** 2026-08-21
- **Completed:** 2026-08-21
- **Tasks:** 2 complete
- **Durable output size:** approximately 3.6 MB
- **Output inventory:** exactly 11 files

## Accomplishments

- Built the official `uefa_nations_league_2026_27` candidate through the existing `phase14_build_competition_state_main` and shared state-bundle contracts.
- Promoted the accepted source bundle `nl-2026-27-official-uefa-v2` with 156 official fixtures, 14 groups, 54 teams, and 156 matching scheduled result rows.
- Preserved all 156 fixture IDs in `state/canonical_matches.csv` and `state/forecast_status.csv`; all 156 status rows are available and map exactly to 156 forecast rows, 156 score distributions, and 156 compact top-10 groups.
- Published 262,236 score-grid rows, equal to `156 * 1,681` cells for complete 0:40 by 0:40 G=40 support, and 1,560 top-10 rows, equal to 156 fixtures times 10 rows.
- Kept the official standings table pre-kickoff and schema-complete with zero rows; competition form and all-international form are schema-complete with zero rows; `state/model_form.csv` contains 54 team rows.
- Retained calibrated primary view `calibrated_1x2`, approved release `phase14-open-nb-incumbent-calibrated-v1`, active predictor `elo_diff`, and dropped xG/form predictors in status, forecasts, top-10, and manifest lineage.
- Propagated `model_data_cutoff 2026-06-10` and strict per-fixture feature cutoffs before each confirmed kickoff.
- Audited national-team xG as explicitly unavailable/NA: source `national_team_xg_sources.csv`, sample count zero, reason `inactive_optional_unavailable:no_accepted_national_team_xg_source`, and no imputed values.
- Confirmed that no production `Austria/Germany` fixture was used. Synthetic Austria/Germany xG-active suppression remains unit-test evidence only.

## Durable Artifacts

The promoted directory contains exactly these paths:

- `outputs/competition/uefa_nations_league_2026_27/state/canonical_matches.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/standings.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/competition_form.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/all_international_form.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/model_form.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/forecast_status.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/forecasts.csv`
- `outputs/competition/uefa_nations_league_2026_27/state/forecast_top10.csv`
- `outputs/competition/uefa_nations_league_2026_27/audit/standings_reconciliation.csv`
- `outputs/competition/uefa_nations_league_2026_27/audit/state_manifest.csv`
- `outputs/competition/uefa_nations_league_2026_27/local/score_distributions.rds`

The manifest contains 11 rows, `validation_status = valid`, the self/manifest hash `47d1ece5a3287369233c738fa22a289ca8c6914429cdf273eb0eaf937e7a01b3`, parent hashes, release identity, predictor audit, and source-bundle lineage.

## Verification

- Focused Phase 14 forecast suite: **133 passed, 0 failed, 0 warnings, 0 skips**.
- Focused Phase 14 state-bundle suite: **162 passed, 0 failed, 0 warnings, 0 skips**.
- Candidate and durable state-bundle validator: **passed**.
- Direct official acceptance assertions: **passed** for 156 fixtures, 14 groups, 54 teams, release/cutoff lineage, calibrated view, exact status/forecast/grid/top-10 coverage, no synthetic Austria/Germany fixture, and inactive/unavailable xG.
- Replay check: **passed** with `--replay-check`; it remained dry-run and made no durable mutation.
- Match-state and standings rollback matrices: **passed**; the `COVERAGE.md` hash was unchanged.
- Atomic promotion: **passed** after staged validation; the injected-failure rollback probe restored the prior target sentinel and removed the replacement directory before the real promotion.
- Durable read-back: **passed** against the final 11-file directory.

The repository-wide Phase 13 `fixture-seed` failure remains outside the Phase 14 acceptance gate. It is not claimed as full-suite green here.

## Execution Fixes

The plan nominally prohibited new production behavior, but four Rule 1 execution blockers in existing contracts prevented the already-defined official path from running. Each was narrow, tested, and did not change model/release authority or architecture:

1. Empty zero-column data frames now hash deterministically instead of failing `order()`; this is required for valid empty form schemas.
2. Official UEFA `UPCOMING` source status is accepted as a forecast-eligible scheduled state.
3. The standalone forecast loader sources the existing proper-score validator dependency required by the registered release model.
4. The binary G=40 score grid uses deterministic R serialization for its content hash and omits discarded per-cell row-hash materialization, reducing the valid build from tens of minutes to minute-scale while retaining content and parent-hash validation.
5. Inactive national-team xG lineage explicitly includes the `unavailable/inactive` audit vocabulary required by the acceptance gate.

Commits:

- `0a48a24` - fix empty model-form schema hashing and add regression coverage.
- `4ecebc6` - accept official `UPCOMING` fixture status and add regression coverage.
- `8a7ea8b` - make the state-bundle build self-contained and optimize score-grid lineage hashing.
- `b81fb76` - label inactive xG lineage explicitly and add regression coverage.
- `a6a2c51` - publish the official eleven-file Nations League state bundle.

## Reconciliation Notes

- `14-18-DATA-CORRECTION-SUMMARY.md` remains the official-source correction record and is not the canonical Plan 14-18 completion summary; this file supersedes its `ready-for-resume` state for durable-output purposes.
- UAT `case 45` was stale when it claimed the NL bundle existed. It is superseded by the filesystem inventory, staged validator, durable validator, manifest hash, and direct 156-fixture acceptance evidence recorded above.
- Synthetic Austria/Germany fixtures remain outside production inventory and are not used to satisfy the official acceptance count.
- The pre-existing Phase 13 `fixture-seed` failure is explicitly outside the Phase 14 acceptance gate. Phase 13 source/publication behavior and release/edition registries were not modified by the durable NL promotion.
- No dashboard artifacts, external API, Phase 15/16/17 behavior, release authority, `COVERAGE.md`, or unrelated sibling output was promoted.

## Next Step

Phase 14 can now be reconciled and final verification can proceed before moving to Phase 15. Phase 15/16/17 dashboard and API work remains out of scope for this plan.
