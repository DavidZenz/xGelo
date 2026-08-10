---
phase: 11-hybrid-ml-and-contextual-priors
verified: 2026-08-10T07:42:00Z
status: passed
score: 16/16 must-haves verified under the accepted eligibility-outcome contract
behavior_unverified: 0
overrides_applied: 0
gaps: []
deferred: []
human_verification: []
---

# Phase 11: Hybrid ML and Contextual Priors Verification Report

**Phase Goal:** Determine whether nonlinear, tournament-context, xG, and structural information add stable value beyond the strongest statistical benchmark.

**Verified:** 2026-08-10T07:42:00Z  
**Status:** passed  
**Re-verification:** Yes — after plans 11-08 and 11-09, explicit developer approval, and the corrected immutable audit amendment

## Goal Achievement

The implementation and boundary contracts are wired. Under the explicitly
approved outcome amendment, the durable research result is interpreted as an
eligibility determination rather than a performance conclusion: the base RF is
the only active challenger, while optional families are correctly prevented
from entering the leaderboard when admissible historical evidence is absent.
The amendment is separately hash-bound to the local audit inputs and preserves
the historical performance bundle as the only performance record.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | SC1 / Plan 11-02: an open RF runs through registry, features, fit/predict, NB distribution, panel scoring, and evidence. | ✓ VERIFIED | Fresh bundle validation accepted 1,260 base-RF predictions across the two tracks; focused RF tests passed. |
| 2 | Plan 11-02: RF ability inputs are independent fold-local dynamic attack/defence and Elo evidence, not a direct 1X2 classifier. | ✓ VERIFIED | `hybrid_rf.R`, model/feature manifests, and the RF focused suite establish separate home/away goal fits and dynamic/Elo feature evidence. |
| 3 | Plan 11-02/11-07: RF execution is gated by the registered local `ranger` runtime. | ✓ VERIFIED | Fresh process preflight returned `valid=TRUE`, `ranger=0.18.0`, project-local library, and offline replay. |
| 4 | Plan 11-07: the official archive, repository metadata, dependencies, and installed package content are checksum-backed. | ✓ VERIFIED | Fresh preflight accepted the recorded index, metadata, archive, dependency-inventory, and installed-content SHA-256 identities. |
| 5 | Plan 11-07: RF execution fails closed when the verified runtime cannot be proven. | ✓ VERIFIED | `require_hybrid_environment(..., offline=TRUE)` is wired before fitting and the focused RF/target tests pass. |
| 6 | SC2 / Plan 11-03: host, neutral, rest, travel, and stage are named, point-in-time, provenance/missingness-tracked context features. | ✓ VERIFIED | Context builder, feature contract, centroid parents, chronology validation, and focused context behavior checks pass. |
| 7 | Plan 11-03: full-context and drop-one ablations provide incremental context-value evidence without changing the 630-fixture denominator. | ✓ VERIFIED (bounded) | The six context variants are registered and the synthetic runner path scores them; the canonical route audit records 542/630 open and 527/609 rich, so strict common-panel eligibility fails closed and no unsupported context comparison is published. |
| 8 | SC3 / Plan 11-04: xG coverage is measured point in time and xG activation is fail closed. | ✓ VERIFIED | The manifest records coverage 0, forecast coverage 0, variance 0, incomplete provenance, `inactive`, and `no_score_gate_failed`; the xG focused suite passes. |
| 9 | SC4 / Plan 11-04: structural information affects sparse-team means only through vintage-safe continuous evidence-weighted shrinkage. | ✓ VERIFIED | Frozen OWID/Maddison plus WPP inputs, manifest/checksum validators, effective-count weighting, shrinkage diagnostics, and the structural focused suite/local smoke pass. The current snapshot covers all 72 panel codes, including POR and PRK; the candidate is inactive because its 2024-07-15 publication date is after the historical fold cutoffs. |
| 10 | SC5 / Plan 11-05: open, enriched squad, and external market modes are separately labelled, licensed, and panel-bound. | ✓ VERIFIED | The three-row mode registry and mode tests preserve open/default, feature-rich derived-only, and external-reference boundaries; the manual market snapshot is absent and remains inactive. |
| 11 | Plan 11-05: only open data can compete for later open-default promotion. | ✓ VERIFIED | Mode promotion boundaries and target tests exclude enriched/external modes from open comparisons; all shortlist rows are `open_default` and `phase12_decision_authority=FALSE`. |
| 12 | Plan 11-06: the durable bundle has exact 630 open, 609 rich, G=40, checksums, mode labels, and sealed research flags. | ✓ VERIFIED | Independent fresh-process checks accepted the bundle; see the integrity section below. |
| 13 | Plan 11-06: the shortlist is evidence for Phase 12, not a promotion/release decision. | ✓ VERIFIED | Shortlist rows are non-exclusive research evidence with `phase12_decision_authority=FALSE`; no Phase 12 target authority is wired. |
| 14 | Plan 11-01: every later Phase 11 production area has a focused automated contract. | ✓ VERIFIED | Focused Phase 11 files and the complete test suite pass with 2,337 expectations, zero failures, zero warnings, and zero skips. |
| 15 | Phase 11's durable evidence determines stable value for every information family named in the goal. | ✓ VERIFIED (bounded outcome) | The accepted amendment explicitly records that only the base RF has canonical score rows and that inactive optional families are not performance evidence. The bundle therefore makes no unsupported stable-value claim; any future value estimate requires a new admissible-input rerun under a separate plan. |
| 16 | Phase 11 remains sealed, network-free, research-only, and does not grant Phase 12 authority. | ✓ VERIFIED | Fresh bundle and target checks report `wc2026_sealed=TRUE`, `network_free=TRUE`, `research_only=TRUE`, `protected_paths_clean=TRUE`, and `phase12_decision_authority=FALSE`. |

**Score:** 16/16 must-haves verified under the accepted eligibility-outcome contract. The substantive WDI/Maddison interpretation review is complete by explicit developer approval.

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
| `tests/testthat/test_hybrid_*.R` | Focused contract coverage | ✓ VERIFIED | All Phase 11 focused files and the complete suite pass; 2,337 expectations, zero failures, zero warnings, and zero skips. |

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `ranger_provenance.csv` | RF fit | `require_hybrid_environment()` | WIRED | Fresh offline preflight accepted exact version and hashes before model code was loaded for fitting. |
| Model registry | RF means → NB G=40 grid → scorer | `hybrid_adapters.R` / `hybrid_runner.R` | WIRED | Base RF produced active predictions, score distributions, and scores under the common contract. |
| Fixture/history/centroids | Context contract → ablations → runner | `build_open_context_features()` and strict common-panel validation | WIRED / FAIL-CLOSED | Synthetic complete-context runner tests pass; canonical travel evidence is incomplete, so all context candidates publish no-score evidence. |
| xG audit | xG manifest → candidate evidence | D-12 gate dispatch | WIRED | Gate failure produces explicit inactive/no-score evidence and no predictions. |
| Structural snapshots/checksums | Shrinkage → structural adapter | structural manifest and sparse shrinkage | WIRED / FAIL-CLOSED | Structural smoke path passes; the current snapshot covers POR and PRK, while historical fold cutoffs precede its 2024-07-15 publication date, so the candidate publishes no-score evidence for the temporal gate. |
| Mode registry | Open/enriched/external outputs | mode-specific adapters and promotion boundaries | WIRED | Enriched is derived-only feature-rich evidence; external is absent/inactive; neither enters open comparisons. |
| Phase 09/10 parents | Phase 11 targets → durable bundle | six `benchmark_phase11_*` targets | WIRED | Target contract and fresh bundle validator pass without opening WC2026. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| Base RF predictions/distributions | two RF goal means | Fold-local dynamic ability/Elo history → ranger home/away fits | Yes | ✓ FLOWING |
| Context candidates | host/neutral/rest/travel/stage | Phase 09 fixture/history metadata and committed centroids | Not for the full open common panel: travel is missing/imputed | ⚠️ FAIL-CLOSED, NO CANONICAL SCORE |
| xG candidate | xG feature signal | Point-in-time xG/form audit | No: coverage and variance are zero | ✓ INTENTIONALLY INACTIVE |
| Structural candidate | structural prior/shrinkage | Frozen OWID/Maddison plus WPP 2000 source snapshot | Real current-cutoff signal; historical fold cutoffs predate publication | ⚠️ FAIL-CLOSED, NO CANONICAL SCORE |
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
| Complete test suite | `testthat::test_file("tests/testthat/test_hybrid_targets.R", stop_on_failure=TRUE, stop_on_warning=TRUE); testthat::test_dir("tests/testthat", stop_on_failure=TRUE, stop_on_warning=TRUE)` | 2,337 expectations, zero failures, zero warnings, zero skips | ✓ PASS |

No 12-hour benchmark was rerun.

## Probe Execution

No Phase 11 probe path was declared in the plans/summaries or present under `scripts/*/tests/probe-*.sh`; probe execution is not applicable.

## Requirements Coverage

| Requirement | Source plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| HYBRID-01 | 11-01, 11-02, 11-06, 11-07 | Benchmark a Groll-style RF with independently estimated team ability | SATISFIED | Active base RF path, exact G=40 bundle, dynamic/Elo evidence, and fresh ranger preflight. |
| HYBRID-02 | 11-01, 11-03, 11-06 | Evaluate named open-data tournament context features | SATISFIED (capability) | Context builder, provenance, ablations, strict rejection, and synthetic common-runner scoring pass; canonical value comparison is unavailable because travel is incomplete. |
| HYBRID-03 | 11-01, 11-04, 11-06 | Report xG coverage and activate only after the declared gate passes | SATISFIED | Current manifest reports zero coverage/variance and publishes inactive/no-score evidence. |
| HYBRID-04 | 11-01, 11-04, 11-06 | Evaluate socio-economic structural priors for sparse evidence | SATISFIED (capability) | Frozen OWID/Maddison plus WPP inputs, checksum/vintage validators, continuous shrinkage tests, and local structural smoke pass; canonical candidate is inactive because the snapshot publication date follows the historical fold cutoffs, not because POR or PRK is absent. |
| HYBRID-05 | 11-01, 11-05, 11-06 | Keep squad and bookmaker information in labelled enriched/external modes | SATISFIED | Mode registry, derived-only squad adapter, local-only manual-market validator, absent external snapshot, and promotion exclusions pass. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No unreferenced `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or implementation-placeholder markers found in Phase 11 implementation/contract files. | None | The intentional “zero placeholder” xG test/comment describes fail-closed semantics and is not a stub. |

## Human Verification Required

The structural-prior substantive mapping was reviewed and accepted for
research use. Automated checks still enforce chronology, hashes, schema, and
numerical weighting; activation remains fail-closed until historical
pre-cutoff vintages are available.

The external-market legal review is not applicable to this checkout because the optional manual snapshot is absent; the mode remains inactive.

## Gaps Summary

The Phase 11 engineering boundary is real: the RF path runs, the bundle is
checksum/parent-graph valid, exact denominators and G=40 are preserved, and
optional evidence fails closed without opening WC2026 or granting Phase 12
authority. The explicit developer decision and the separate hash-bound audit
amendment resolve the prior execution gaps.

Only the base RF is compared against the statistical benchmark, and it is
worse than `elo_goal_nb` on the recorded open updating proper score. Context,
xG, and structural candidates have no canonical score rows because their
declared evidence gates fail. This is intentionally reported as an
eligibility finding, not as evidence for or against their predictive value.

Before any structural candidate activation, a human must review the WDI/
Maddison indicator mapping and HGR-inspired rationale. Phase 12 may later
assemble admissible historical inputs and run a separately checksum-linked
performance rerun, but it must not treat this amendment as a promotion result
or open the WC2026 holdout automatically.

---

_Verified: 2026-08-10T07:42:00Z_  
_Verifier: Codex goal-backward re-verification after explicit developer approval_
