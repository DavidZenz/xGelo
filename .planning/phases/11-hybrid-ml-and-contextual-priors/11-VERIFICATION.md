---
phase: 11-hybrid-ml-and-contextual-priors
verified: 2026-08-09T13:13:29Z
status: gaps_found
score: 13/16 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The Phase 11 durable evidence determines whether context, xG, and structural information add stable value beyond the strongest statistical benchmark."
    status: failed
    reason: "Only the base RF has score rows and paired comparisons. Six context candidates, the xG-gated candidate, and the structural candidate are explicitly inactive with zero score rows, so their value is not empirically determined by the canonical bundle."
    artifacts:
      - path: "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/candidate_evidence.csv"
        issue: "Only phase11_rf_dynamic_elo_open is active; all optional candidate score_row_count values are zero."
      - path: "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/all_baseline_paired_comparisons.csv"
        issue: "All 448 data rows contain only phase11_rf_dynamic_elo_open as the candidate."
      - path: "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/hybrid_shortlist.csv"
        issue: "All three shortlist slots select the base RF; none is evidence for an optional information family."
    missing:
      - "Either produce valid point-in-time inputs and rerun the bounded Phase 11 comparisons for the optional candidates, or explicitly amend the phase outcome contract to say that the current result is an eligibility/inactivity determination rather than a stable-value determination."
deferred:
  - truth: "The context test's expected candidate list matches the merged Phase 11 registry."
    addressed_in: "Phase 12 candidate-set freeze (or immediate maintenance before that freeze)"
    evidence: "The current registry has nine candidates, while Phase 12 success criterion 2 freezes and checksums the candidate implementations and feature sets before opening 2026 results."
human_verification:
  - test: "Review the committed World Bank WDI indicator mapping and transformation notes against the selected HGR-inspired structural-prior rationale."
    expected: "The two indicators, 2000 vintage, log/z transformation, and sparse-team shrinkage use are substantively faithful to the intended structural-prior design."
    why_human: "Schema, hashes, vintages, and automated shrinkage tests cannot establish the literature/domain interpretation."
---

# Phase 11: Hybrid ML and Contextual Priors Verification Report

**Phase Goal:** Determine whether nonlinear, tournament-context, xG, and structural information add stable value beyond the strongest statistical benchmark.

**Verified:** 2026-08-09T13:13:29Z  
**Status:** gaps_found  
**Re-verification:** No — initial verification

## Goal Achievement

The implementation and boundary contracts are present and mostly wired, but the durable research result does not answer the full value-add question. The base RF is the only active challenger; optional families are correctly prevented from entering the leaderboard when their evidence is unavailable.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | SC1 / Plan 11-02: an open RF runs through registry, features, fit/predict, NB distribution, panel scoring, and evidence. | ✓ VERIFIED | Fresh bundle validation accepted 1,260 base-RF predictions across the two tracks; focused RF tests passed. |
| 2 | Plan 11-02: RF ability inputs are independent fold-local dynamic attack/defence and Elo evidence, not a direct 1X2 classifier. | ✓ VERIFIED | `hybrid_rf.R`, model/feature manifests, and the RF focused suite establish separate home/away goal fits and dynamic/Elo feature evidence. |
| 3 | Plan 11-02/11-07: RF execution is gated by the registered local `ranger` runtime. | ✓ VERIFIED | Fresh process preflight returned `valid=TRUE`, `ranger=0.18.0`, project-local library, and offline replay. |
| 4 | Plan 11-07: the official archive, repository metadata, dependencies, and installed package content are checksum-backed. | ✓ VERIFIED | Fresh preflight accepted the recorded index, metadata, archive, dependency-inventory, and installed-content SHA-256 identities. |
| 5 | Plan 11-07: RF execution fails closed when the verified runtime cannot be proven. | ✓ VERIFIED | `require_hybrid_environment(..., offline=TRUE)` is wired before fitting and the focused RF/target tests pass. |
| 6 | SC2 / Plan 11-03: host, neutral, rest, travel, and stage are named, point-in-time, provenance/missingness-tracked context features. | ✓ VERIFIED | Context builder, feature contract, centroid parents, chronology validation, and focused context behavior checks pass. |
| 7 | Plan 11-03: full-context and drop-one ablations provide incremental context-value evidence without changing the 630-fixture denominator. | ✗ FAILED | The six context variants are registered and the synthetic runner path scores them, but canonical `candidate_evidence.csv` marks all six inactive for missing/imputed `travel_km`; no durable context comparison exists. |
| 8 | SC3 / Plan 11-04: xG coverage is measured point in time and xG activation is fail closed. | ✓ VERIFIED | The manifest records coverage 0, forecast coverage 0, variance 0, incomplete provenance, `inactive`, and `no_score_gate_failed`; the xG focused suite passes. |
| 9 | SC4 / Plan 11-04: structural information affects sparse-team means only through vintage-safe continuous evidence-weighted shrinkage. | ✓ VERIFIED | Frozen WDI snapshots, manifest/checksum validators, effective-count weighting, shrinkage diagnostics, and the structural focused suite/local smoke pass. The full-panel candidate is explicitly inactive because PRK is absent from the snapshot. |
| 10 | SC5 / Plan 11-05: open, enriched squad, and external market modes are separately labelled, licensed, and panel-bound. | ✓ VERIFIED | The three-row mode registry and mode tests preserve open/default, feature-rich derived-only, and external-reference boundaries; the manual market snapshot is absent and remains inactive. |
| 11 | Plan 11-05: only open data can compete for later open-default promotion. | ✓ VERIFIED | Mode promotion boundaries and target tests exclude enriched/external modes from open comparisons; all shortlist rows are `open_default` and `phase12_decision_authority=FALSE`. |
| 12 | Plan 11-06: the durable bundle has exact 630 open, 609 rich, G=40, checksums, mode labels, and sealed research flags. | ✓ VERIFIED | Independent fresh-process checks accepted the bundle; see the integrity section below. |
| 13 | Plan 11-06: the shortlist is evidence for Phase 12, not a promotion/release decision. | ✓ VERIFIED | Shortlist rows are non-exclusive research evidence with `phase12_decision_authority=FALSE`; no Phase 12 target authority is wired. |
| 14 | Plan 11-01: every later Phase 11 production area has a focused automated contract. | ⚠️ UNCERTAIN | RF, xG, structural, modes, and target focused files pass; the full suite reports exactly two stale candidate-set failures in `test_hybrid_context_features.R:77-78`. |
| 15 | Phase 11's durable evidence determines stable value for every information family named in the goal. | ✗ FAILED | The only candidate comparison is base RF versus the statistical baselines. Its updating proper score is `0.2094707705` versus `0.2024737234` for `elo_goal_nb` (delta `+0.0069970471`); there is no corresponding context/xG/structural value estimate. |
| 16 | Phase 11 remains sealed, network-free, research-only, and does not grant Phase 12 authority. | ✓ VERIFIED | Fresh bundle and target checks report `wc2026_sealed=TRUE`, `network_free=TRUE`, `research_only=TRUE`, `protected_paths_clean=TRUE`, and `phase12_decision_authority=FALSE`. |

**Score:** 13/16 must-haves verified. The two failed truths share the optional-candidate evidence gap; the one uncertain truth is the documented stale test expectation.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `R/forecast/hybrid_rf.R`, `R/benchmark/hybrid_protocol.R`, `R/benchmark/hybrid_adapters.R`, `R/benchmark/hybrid_runner.R` | RF, registry, adapter, and bundle implementation | ✓ VERIFIED | Substantive implementations are loaded by fresh processes and exercised by focused tests. |
| `R/forecast/context_features.R` and Phase 11 centroid/feature registries | Point-in-time context evidence and ablations | ✓ VERIFIED | Required five-feature contract, centroid and metadata parents, strict common-panel rejection, and six ablation rows exist. |
| `R/forecast/structural_prior.R` and structural source manifests | Vintage-safe structural prior and continuous shrinkage | ✓ VERIFIED | WDI 2000 snapshot, metadata, checksums, prior manifest, and shrinkage implementation exist and validate. |
| `R/forecast/external_market.R` and mode/manual-market registries | Separate fail-closed external reference mode | ✓ VERIFIED | Local-only validator and header-only absent snapshot manifest exist; no live collection path is used. |
| `data/benchmark/phase11/ranger_provenance.csv`, retained archive, local library | Exact offline RF runtime | ✓ VERIFIED | Fresh preflight accepted ranger 0.18.0 and all recorded identities. |
| `_targets.R` Phase 11 chain | Downstream registry → prediction → score → comparison → bundle chain | ✓ VERIFIED | `test_hybrid_targets.R` passes and statically verifies no dashboard, retrospective, promotion, release, or final-selection authority in the Phase 11 chain. |
| `outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/` | Durable research-only evidence bundle | ✓ VERIFIED | All required CSV/report artifacts exist and independently pass validation and hash checks. |
| `tests/testthat/test_hybrid_*.R` | Focused contract coverage | ⚠️ PRESENT WITH DEFERRED DEBT | All Phase 11 focused files run; only the two known stale registry assertions fail in the full suite. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `ranger_provenance.csv` | RF fit | `require_hybrid_environment()` | WIRED | Fresh offline preflight accepted exact version and hashes before model code was loaded for fitting. |
| Model registry | RF means → NB G=40 grid → scorer | `hybrid_adapters.R` / `hybrid_runner.R` | WIRED | Base RF produced active predictions, score distributions, and scores under the common contract. |
| Fixture/history/centroids | Context contract → ablations → runner | `build_open_context_features()` and strict common-panel validation | WIRED / FAIL-CLOSED | Synthetic complete-context runner tests pass; canonical travel evidence is incomplete, so all context candidates publish no-score evidence. |
| xG audit | xG manifest → candidate evidence | D-12 gate dispatch | WIRED | Gate failure produces explicit inactive/no-score evidence and no predictions. |
| Structural snapshots/checksums | Shrinkage → structural adapter | structural manifest and sparse shrinkage | WIRED / FAIL-CLOSED | Structural smoke path passes; canonical full panel stops at missing PRK and publishes no-score evidence. |
| Mode registry | Open/enriched/external outputs | mode-specific adapters and promotion boundaries | WIRED | Enriched is derived-only feature-rich evidence; external is absent/inactive; neither enters open comparisons. |
| Phase 09/10 parents | Phase 11 targets → durable bundle | six `benchmark_phase11_*` targets | WIRED | Target contract and fresh bundle validator pass without opening WC2026. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Base RF predictions/distributions | two RF goal means | Fold-local dynamic ability/Elo history → ranger home/away fits | Yes | ✓ FLOWING |
| Context candidates | host/neutral/rest/travel/stage | Phase 09 fixture/history metadata and committed centroids | Not for the full open common panel: travel is missing/imputed | ⚠️ FAIL-CLOSED, NO CANONICAL SCORE |
| xG candidate | xG feature signal | Point-in-time xG/form audit | No: coverage and variance are zero | ✓ INTENTIONALLY INACTIVE |
| Structural candidate | structural prior/shrinkage | Frozen WDI 2000 source snapshot | Partially: snapshot is real, but PRK is missing for the panel | ⚠️ FAIL-CLOSED, NO CANONICAL SCORE |
| Enriched squad mode | derived squad aggregate | Local processed aggregate | Yes, but feature-rich and non-promotional only | ✓ SEPARATE MODE |
| External market mode | manual 1X2 reference | Optional local snapshot | No snapshot present | ✓ INTENTIONALLY INACTIVE |

## Durable Bundle Integrity

Independent fresh-process checks (not SUMMARY claims) produced:

- Fresh `validate_hybrid_challenger_bundle()` acceptance: exit 0 with no validation error.
- `open=630`, `rich=609`, `G=40`, `candidate_count=9`, `track_count=2`, `parent_count=20`.
- `predictions=1,260`, `distributions=2,118,060`, `score_distribution_id` grids `1,260 × 1,681`, `scores=17,640`.
- The checksum manifest has 15 content rows plus its self-check row; all file SHA-256 values, row counts, and the self-checksum match.
- All 20 parent SHA-256 values recompute from the current files, and the recomputed parent graph is `615643978628c1864575d3adf7e9357ed29d2725ddfa4919692759ae5e84f4e2`.
- There are 448 comparison data rows (449 physical CSV lines including the header; the summary's 449 is a line-count discrepancy). All comparison candidates are the base RF.
- Manifest protection flags are `reproducible=TRUE`, `wc2026_sealed=TRUE`, `network_free=TRUE`, `research_only=TRUE`, `protected_paths_clean=TRUE`, and `phase12_decision_authority=FALSE`.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Offline RF runtime acceptance | Fresh `Rscript --vanilla` preflight of `ranger_provenance.csv` | `valid=TRUE`, ranger `0.18.0`, offline replay true | ✓ PASS |
| Durable bundle validation and integrity | Fresh `Rscript --vanilla` validator plus independent parent/checksum/count assertions | Accepted; all assertions passed | ✓ PASS |
| RF, xG, structural, and mode contracts | Four focused `test_file()` runs | All exited 0 | ✓ PASS |
| Phase 11 target contract | `testthat::test_file("tests/testthat/test_hybrid_targets.R")` | All assertions passed | ✓ PASS |
| Complete test suite | One `testthat::test_dir("tests/testthat", stop_on_failure=FALSE)` run | Exactly two failures, both `test_hybrid_context_features.R:77-78`; no other failures reported | ⚠️ WARNING |

No 12-hour benchmark was rerun.

## Probe Execution

No Phase 11 probe path was declared in the plans/summaries or present under `scripts/*/tests/probe-*.sh`; probe execution is not applicable.

## Requirements Coverage

| Requirement | Source plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| HYBRID-01 | 11-01, 11-02, 11-06, 11-07 | Benchmark a Groll-style RF with independently estimated team ability | SATISFIED | Active base RF path, exact G=40 bundle, dynamic/Elo evidence, and fresh ranger preflight. |
| HYBRID-02 | 11-01, 11-03, 11-06 | Evaluate named open-data tournament context features | SATISFIED (capability) | Context builder, provenance, ablations, strict rejection, and synthetic common-runner scoring pass; canonical value comparison is unavailable because travel is incomplete. |
| HYBRID-03 | 11-01, 11-04, 11-06 | Report xG coverage and activate only after the declared gate passes | SATISFIED | Current manifest reports zero coverage/variance and publishes inactive/no-score evidence. |
| HYBRID-04 | 11-01, 11-04, 11-06 | Evaluate socio-economic structural priors for sparse evidence | SATISFIED (capability) | Frozen WDI inputs, checksum/vintage validators, continuous shrinkage tests, and local structural smoke pass; canonical candidate is inactive for missing PRK. |
| HYBRID-05 | 11-01, 11-05, 11-06 | Keep squad and bookmaker information in labelled enriched/external modes | SATISFIED | Mode registry, derived-only squad adapter, local-only manual-market validator, absent external snapshot, and promotion exclusions pass. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No unreferenced `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or implementation-placeholder markers found in Phase 11 implementation/contract files. | None | The intentional “zero placeholder” xG test/comment describes fail-closed semantics and is not a stub. |

## Human Verification Required

1. **Structural-prior substantive mapping**

   **Test:** Review the WDI 2000 source registry, indicator definitions, transformations, and the HGR-inspired rationale.

   **Expected:** The selected indicators and continuous sparse-team shrinkage are substantively justified for the intended domain use.

   **Why human:** Automated checks prove chronology, hashes, schema, and numerical weighting, not literature/domain faithfulness.

The external-market legal review is not applicable to this checkout because the optional manual snapshot is absent; the mode remains inactive.

## Gaps Summary

The Phase 11 engineering boundary is largely real: the RF path runs, the bundle is checksum/parent-graph valid, exact denominators and G=40 are preserved, and optional evidence fails closed without opening WC2026 or granting Phase 12 authority.

The phase goal is not fully achieved by the durable evidence. Only the base RF is compared against the statistical benchmark, and it is worse than `elo_goal_nb` on the recorded open updating proper score. Context, xG, and structural candidates have no canonical score rows because their declared evidence gates fail. That is a correct safety behavior, but it leaves the value question unanswered for those families.

The two full-suite failures are a separate warning/deferred maintenance item, not evidence that the production registry is missing the xG or structural candidates: the failure asserts the obsolete seven-ID list while the merged registry correctly contains nine IDs, and the target-contract test passes. Reconcile that expectation before relying on a green full-suite gate.

**Recommended next action:** Before Phase 12 candidate freeze, either assemble valid pre-cutoff context/structural evidence and run the bounded optional-candidate comparisons, or obtain an explicit developer decision to amend the Phase 11 goal/acceptance to treat these candidates' inactivity as the final research finding. Update the stale candidate expectation and rerun the test suite as maintenance. Do not open WC2026 or infer a promotion decision from this bundle.

---

_Verified: 2026-08-09T13:13:29Z_  
_Verifier: the agent (gsd-verifier)_
