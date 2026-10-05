# EURO 2028 Nations League priority outlook verification

Implementation date: 5 October 2026. Scope: active Nations League dashboard, independent Article 16 priority policy, joint per-iteration queue, optional dashboard payload, ten-file outcome inventory with explicit nine-file compatibility.

## Automated checks

- Priority policy/calculation/renderer contract: 8 cases, 58 expectations passed. Covers interim rather than final ranks; complete queue permutations; 14 group winners and 13 priority winners; correlated simulation aggregation; type-1 empirical percentiles; metric-specific availability without renormalization; D winner selection without requiring non-winners' ranks; zero/sub-0.1%/missing formatting; unrounded sorting; policy-bound publication identity.
- Nations League simulation replay and unavailable inputs: 31 expectations passed, including missing score grids, unavailable completed results, known group/interim evidence with unresolved knockout results, RNG preservation and worker parity.
- Dashboard regression suite: 28 cases, 216 expectations passed. Existing missing-upstream warning; no failures/errors.
- Existing revised Nations League rules/group/outlook coverage: 11 cases, 197 expectations passed.
- State bundle production inventory: 22 expectations passed with the module isolated from global scalar helper collisions.
- CLI foreign/conflicting modes: 7 expectations passed with the R executable on PATH.
- Atomic publisher rollback/hash/inventory checks: 12 expectations passed.
- Production CLI acceptance reached 183 passing expectations, then exposed legacy outcome writer round-trip failure. Fixed the writer to preserve the recognized incumbent inventory; explicit old-bundle write/read-back now passes with unchanged manifest content hashes.
- Approved input two-iteration replay: serial and two-worker builds produced identical CSV bytes and hashes for every outcome artifact.
- `git diff --check` passes.

## Browser checks so far

Codex in-app browser, legacy artifact preview: direct `#euro-2028` navigation; 54 accepted teams and flags; 216 reasoned unavailable cells; League D filter returns six teams; Germany search returns one; unmatched search displays the empty-results message. Independent match views still contain 156 fixtures and 70 results. Keyboard tab activation works.

At 390 × 844, document width remains 390px, the table panel is 360px, and its 828px content stays in the horizontal scroller. Team cells are sticky and keyboard ArrowRight scrolls the focusable panel.

## Publication status

Pending final production rebuild, populated desktop/mobile inspection, manifest/hash checks and atomic promotion/read-back. The incumbent publication has not been promoted by this work.

## Cutoff issue requiring a decision

The existing `uefa_nl_sim_prepare_iteration_matches()` compares completion evidence with `as.POSIXct(cutoff_utc, tz = "UTC")`. With its RFC3339 cutoff, this R version interprets the value as midnight, omitting ten accepted results on 2 October. The production input has 70 completed results; only 60 are counted in those iterations. Its inferred simulation cutoff is `2026-10-02T20:39:55.914999Z`, while the accepted source cutoff is `2026-10-03T01:00:32Z`.

The new queue correctly treats missing group inputs as unavailable. Correcting the underlying cutoff changes the existing Nations League probabilities, conflicting with the requested unchanged forecasts. User choice requested: fix and rebuild forecasts, or preserve existing forecasts and expose affected priority aggregates as unavailable. No publication decision has been assumed.

The pinned Safari-version gate has not been run; browser checks above use the Codex in-app browser. UCL and unrelated GSD milestone state are unchanged.
