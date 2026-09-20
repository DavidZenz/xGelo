# Phase 19: Independent Club Forecast Authority - Pattern Map

**Mapped:** 2026-09-20  
**Files classified:** 21 implementation, protocol, output, orchestration, and test seams  
**Analogs found:** 18 / 21 (three club-specific authority contracts are intentionally new)

## Scope and governing constraint

Phase 19 may copy mechanics from the national-team benchmark and release system, but it must not reuse national evidence, selectors, model objects, feature registries, or publication authority. The only production training entry point is the Phase 18 accepted club-history pointer. At the time of mapping, `data/club/history_current.json` is `blocked` and has no accepted generation, so production training, promotion, release publication, and selector advancement must fail closed.

Deterministic synthetic fixtures may exercise model, evaluation, and release mechanics only when every artifact is tagged `fixture`. Fixture execution must use temporary/test roots and can never create or modify `outputs/releases/club/approved_release.csv` or any production release generation.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `R/club/model_contract.R` | utility / domain guard | transform + file-I/O | `R/club/history_contract.R`; `R/release/release_contract.R` | role-match |
| `R/club/rating.R` | model / state machine | event-driven batch | `R/forecast/dynamic_goal_ability.R`; math only from `R/elo/runner.R` | role-match |
| `R/club/goal_model.R` | model / predictor | batch transform | `R/benchmark/baselines.R`; `R/forecast/penalized_poisson.R` | role-match |
| `R/club/evaluation_protocol.R` | config / immutable registry | file-I/O + transform | `R/evaluation/promotion.R`; `R/benchmark/registry.R` | role-match |
| `R/club/evaluation.R` | service | batch transform | `R/evaluation/benchmark_scores.R`; `R/evaluation/proper_scores.R` | exact mechanics, adapted grouping |
| `R/club/release.R` | provider / authority | file-I/O + request-response | `R/release/release_bundle.R`; `R/release/release_contract.R`; `R/release/release_install.R` | exact mechanics, new domain |
| `scripts/run_phase19_club_evaluation.R` | controller | batch + file-I/O | Phase 10 benchmark target/script flow in `_targets.R` | role-match |
| `scripts/verify_phase19_contracts.R` | test runner | batch + subprocess | `scripts/verify_phase18_contracts.R` | exact |
| `data/club/model_protocol/feature_contract.csv` | config registry | file-I/O | Phase 10 feature panel registry | role-match |
| `data/club/model_protocol/candidates.csv` | config registry | file-I/O | Phase 10 challenger registry | role-match |
| `data/club/model_protocol/baselines.csv` | config registry | file-I/O | Phase 9 baseline registry | role-match |
| `data/club/model_protocol/folds.csv` | config registry | file-I/O | benchmark boundaries plus tournament registry | partial; league holdouts are new |
| `data/club/model_protocol/gates.csv` | config registry | file-I/O | Phase 10 promotion rules | role-match |
| `data/club/model_protocol/seeds.csv` | config registry | file-I/O | Phase 10 seed registry | exact |
| `outputs/benchmarks/club/<run_id>/*` | durable evidence | batch + file-I/O | `outputs/benchmarks/rolling_tournaments/*` | role-match |
| `outputs/releases/club/<release_id>/*` | immutable release | file-I/O | `outputs/releases/<national-release-id>/*` | role-match, separate root |
| `outputs/releases/club/approved_release.csv` | selector | request-response + file-I/O | national approved-release selector validated by `R/release/release_contract.R` | exact shape concept, new schema |
| `_targets.R` | orchestration config | DAG / batch | Phase 9/10 benchmark and Phase 12/14 release targets | exact orchestration style |
| `tests/testthat/test_phase19_{model_contract,rating,goal_model,evaluation}.R` | tests | batch | `test_benchmark_cutoffs.R`; `test_statistical_dynamic_state.R`; Phase 9/10 score tests | role-match |
| `tests/testthat/test_phase19_release.R` | tests | file-I/O + adversarial | `test_phase12_release.R`; `test_phase14_calibration_release.R` | exact mechanics, new domain |
| `tests/testthat/test_phase19_adversarial_regression.R` | adversarial tests | mutation + file-I/O | `test_phase18_adversarial_regression.R` | exact |

## Pattern Assignments

### `R/club/model_contract.R` (utility/domain guard, transform + file-I/O)

**Primary analog:** `R/club/history_contract.R:821-946`

Use the Phase 18 reader as the only production evidence gateway. Its current-pointer flow validates the descriptor, validates the referenced immutable generation, binds manifest hashes, and independently revalidates an accepted corpus:

```r
phase18_read_club_history_current <- function(current_path, generations_root = dirname(current_path)) {
  pointer <- phase18_history_read_pointer_file(current_path)
  audit_root <- file.path(generations_root, pointer$audit_generation_id)
  audit_generation <- phase18_history_validate_generation(audit_root)
  ...
  if (nzchar(pointer$accepted_generation_id)) {
    accepted_generation <- phase18_history_validate_generation(accepted_root)
    accepted_corpus <- phase18_validate_club_history_corpus(file.path(accepted_root, "accepted"))
    if (!isTRUE(accepted_corpus$accepted_for_training) || ...) stop(...)
  }
}
```

The new contract should expose one result with explicit `authority_mode` (`production` or `fixture`), `model_domain = "club"`, corpus/generation hashes, cutoff, feature availability, and rejection reasons. Production mode requires `acceptance_state == "accepted"`, a non-empty accepted generation, and independent validation. It must not treat the audit corpus, a blocked pointer, a raw CSV path, or a fixture table as production evidence.

**Feature-availability pattern:** use a typed registry, not inferred columns. Rows for `current_xg`, `injury`, `lineup`, `suspension`, and `player` must be present with `status = "unavailable"`, `reason = "no_accepted_source_contract"`, blank source identifiers, `NA` values, and `active = FALSE`. Do not zero-impute or silently drop these rows.

**Hash pattern:** `R/common/phase18_canonical_hash.R:1-180`.

```r
phase18_hash_sequence_v2 <- function(values, domain, names, types) {
  phase18_v2_hash(phase18_v2_sequence_bytes(values, domain, names, types))
}

phase18_hash_row_v2 <- function(data, exclude = character(), schema_tag) {
  ... # ordered names, explicit types, missingness, and schema tag are framed
}
```

All new Phase 19 row/table/manifest hashes should use canonical-v2 domain-separated frames. Do not copy the older `paste(..., collapse = "|")` hashes still present in Phase 9 helpers.

---

### `R/club/rating.R` (model/state machine, event-driven batch)

**Primary analog:** `R/forecast/dynamic_goal_ability.R:46-75,167-332,342-390`.

Copy the state lifecycle: initialize a registered entity state, predict a complete kickoff batch from one immutable pre-batch snapshot, then apply completed results only after all batch predictions are materialized. The key sequence is:

```r
# conceptual sequence copied from replay_dynamic_goal_ability()
batch_predictions <- predict_batch_without_mutation(state, fixtures_at_boundary)
state <- update_state_after_batch(state, completed_results_at_boundary)
```

`tests/testthat/test_statistical_dynamic_state.R:61-100` is the invariant to reproduce: reordering matches inside a batch is byte-identical, and a result affects only later kickoff batches.

**Math-only analog:** `R/elo/runner.R:19-83` provides expected-score and rating-update equations. Do not copy its storage contract: it is keyed by national FIFA/team aliases and updates sequentially, which is unsafe for simultaneous club fixtures. Phase 19 state must use Phase 18 `club_id`, preserve competition/league context declared by protocol, and batch by exact `kickoff_utc` when available. Date-only history must use a conservative date batch: no row from that date may train another row on the same date.

**Required provenance per prediction:** state/corpus hash, exclusive cutoff, rating parameters, registered club IDs, input row count, and batch key. Unknown club IDs fail closed unless the frozen protocol explicitly defines a cold-start rule.

---

### `R/club/goal_model.R` (model/predictor, batch transform)

**Primary analog:** `R/benchmark/baselines.R:17-116,129-205,230-359`.

Copy these mechanics:

```r
history <- history[!is.na(history[[date_col]]) & history[[date_col]] < as.Date(cutoff), , drop = FALSE]
...
if (inherits(fit, "benchmark_nb_error")) stop(label, " negative-binomial fit failed: ", fit$error)
if (!isTRUE(fit$converged) || !is.finite(fit$theta) || fit$theta <= 0) stop(...)
...
grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
```

Register at least simple controls and an Elo/venue negative-binomial candidate. Every candidate is registry-dispatched, uses strictly prior completed club history, records active/dropped predictors, and returns the complete `0:40 x 0:40` score grid plus derived 1X2 probabilities. Fit errors or non-convergence are durable failures; there is no silent fallback.

**Secondary analog:** `R/forecast/penalized_poisson.R:32-89,116-215,232-435` for stable design matrices, registered IDs, raw-rating rejection, convergence metadata, and explicit cold starts.

**Negative analog:** do not copy `R/forecast/poisson.R:52-102` behavior that replaces non-finite predictors with zero or falls back to Poisson. The Phase 19 feature contract decides availability; unavailable enrichments never become numeric predictors.

---

### `R/club/evaluation_protocol.R` and `data/club/model_protocol/*`

**Primary analog:** `R/evaluation/promotion.R:74-200`.

Copy checksum-backed, immutable protocol loading:

```r
required_files <- c(... registries ...)
observed_hashes <- vapply(required_files, file_sha256, character(1))
if (!identical(observed_hashes, declared_hashes)) stop("Frozen protocol checksum mismatch", call. = FALSE)
```

The club protocol must freeze before evaluation:

- candidate IDs, families, parameters, features, and domains;
- control/baseline IDs;
- chronological rolling-origin folds with exclusive cutoffs;
- leave-one-league-out folds and frozen eligibility/weighting rules;
- proper-score, calibration, coverage, convergence, reproducibility, and breadth gates;
- deterministic seeds and tie-break order;
- score support `0:40`;
- exact feature status, including typed unavailable enrichments;
- protocol version and canonical-v2 hashes.

Adapt rather than copy the national promotion registries. National constants such as twelve editions, `open_core`, World Cup/EURO grouping, `frozen`/`updating` tournament tracks, and national panel IDs are invalid club evidence.

**No close analog:** the leave-one-league-out registry and rules are new. They must state whether the held-out league is excluded from parameter fitting, hyperparameter selection, or both; define club/promoted-team eligibility; and prevent any held-out outcome from choosing the candidate or its settings.

---

### `R/club/evaluation.R` (service, batch transform)

**Cutoff analog:** `R/benchmark/cutoffs.R:27-134`.

```r
eligible <- history[!is.na(dates) & dates < cutoff, , drop = FALSE]
...
if (any(vapply(split(fixtures$boundary_id, date_keys),
  function(x) length(unique(x)) != 1L, logical(1)))) {
  stop("Same-date fixtures must share one boundary", call. = FALSE)
}
```

Use exclusive evidence boundaries and one pre-batch snapshot for every same-kickoff fixture. Preserve Phase 18 `evidence_observed_at_utc`/cutoff semantics. If only dates are available, same-date batching is the safe maximum precision.

**Scoring analogs:**

- `R/evaluation/proper_scores.R:3-190`: probability validation, Brier, ranked probability score, logarithmic score, and scoreline-grid validation.
- `R/evaluation/benchmark_scores.R:34-143`: exact fixture-level score records.
- `R/evaluation/benchmark_scores.R:201-293`: frozen calibration bins and leave-one-group-out diagnostic shape.
- `R/evaluation/benchmark_scores.R:339-398`: exact paired candidate/control rows, fold deltas, bootstrap uncertainty, breadth, and leave-one-group-out summaries.

Reuse the score functions, not the aggregation labels. Replace edition/tournament grouping with frozen club folds, seasons, competitions, and leagues. Paired comparisons must have identical fixture IDs and denominators. Missing predictions are coverage failures, not rows to discard until a favorable comparison remains.

**Promotion analog:** `R/evaluation/promotion.R:212-500`. Copy ordered reason codes, a table of boolean gate values, a deterministic final decision, and retain-incumbent tie handling. Use new club thresholds and identifiers from the frozen protocol. When production authority is blocked, the only valid production decision is a stable fail-closed reason such as `no_accepted_club_history`; fixture results can be diagnostic but cannot satisfy a production promotion gate.

---

### `R/club/release.R` and `outputs/releases/club/*`

**Bundle analog:** `R/release/release_bundle.R:48-71,117-150,854-950,1167-1207`.

Copy the release topology concept and staged writer:

```r
required <- c(
  "manifest.csv", "model/model_contract.csv", "model/approved_model.rds",
  "evaluation/benchmark_report.csv", "MODEL-CARD.md",
  "LIMITATIONS.md", "REPRODUCIBILITY.md"
)

candidate <- tempfile(..., tmpdir = release_parent)
# write, read back, validate exact inventory, then rename atomically
```

The exact Phase 19 inventory should be declared once and validated recursively. A club model card must bind: `model_domain = "club"`, accepted Phase 18 generation/corpus hashes, evidence cutoff, protocol/fold/league/baseline/gate/seed hashes, score support, feature availability, validation results, limitations, model object hash, decision hash, and release manifest hash.

**Resolver/preflight analog:** `R/release/release_contract.R:17-92,152-242,290-321,378-475,477-613`.

Copy these security properties:

- trusted-root containment and no symlinks;
- safe release IDs and exact topology;
- exactly one selector row with selector self-hash;
- candidate authority recomputed from release contents;
- metadata-only preflight before `readRDS()`;
- full model identity validation after load;
- selector reread after resolution to close the TOCTOU window.

Add mandatory club-domain checks at every layer. The club resolver rejects national/international release roots, selectors, manifests, contracts, and model objects; national resolvers must likewise reject club artifacts. Compatibility of R object structure is not domain authority.

**Atomic install analog:** `R/release/release_install.R:185-216` for candidate validation, backup/rollback, atomic replacement, and readback.

**Production/fixture split:** production release functions must first resolve accepted Phase 18 authority. If blocked, they may emit an in-memory/durable blocked diagnostic but must not create a production generation or selector. A fixture release must have a separate temporary root, `authority_mode = "fixture"`, and a schema that the production resolver always rejects.

---

### `scripts/run_phase19_club_evaluation.R` (controller, batch + file-I/O)

**Analog:** Phase 9/10 benchmark chain in `_targets.R:730-958`.

The script should source only explicit common, Phase 18 club, and new Phase 19 club modules; load the frozen protocol; resolve authority; execute deterministic folds; validate the entire result; then write durable files. CLI production mode defaults to fail-closed. Fixture mode must be explicit and require a non-production output root.

Do not source or resolve `phase12_approved_release`, a national selector, `R/competition/forecast_layer.R`, or national team identity/form state. Those are evidence leaks, not conveniences.

---

### `scripts/verify_phase19_contracts.R` (test runner, batch + subprocess)

**Analog:** `scripts/verify_phase18_contracts.R:75-95,130-198`.

Copy the verification shape:

1. Hash/snapshot protected production descriptors before tests.
2. Prove blocked production fails with the exact declared reason and leaves no selector.
3. Declare an exact Phase 19 test inventory.
4. Execute tests in a fresh R subprocess.
5. Fail on warnings, skips, missing tests, or inventory drift.
6. Re-hash production files and assert no mutation.

The verification script itself must not manufacture accepted Phase 18 evidence. Test fixtures belong under test temporary roots.

---

### `_targets.R` (orchestration config, DAG/batch)

**Analog:** `_targets.R:14-98,730-1085`.

Follow existing conventions: explicit `source()` registration near other modules; immutable protocol files are `format = "file"`; benchmark/release outputs are file targets; validation targets sit between writing and downstream consumption. Add a separate `club_*` target namespace.

The dependency direction is:

```text
Phase 18 accepted history + club protocol
  -> club rating states
  -> club candidates and controls
  -> rolling-origin / leave-league-out predictions
  -> proper scores + promotion decision
  -> validated club release
  -> club selector
```

No club target may depend on national benchmark states, national model artifacts, `phase12_approved_release`, Phase 14 calibration authority, or the national forecast target chain. With the current blocked Phase 18 pointer, production release/selector targets should complete as an explicit blocked result or fail with the declared contract condition; they must not synthesize success.

## Test Pattern Assignments

| Phase 19 test | Copy/adapt from | Required invariant |
|---|---|---|
| `test_phase19_model_contract.R` | Phase 18 history/identity contract tests | blocked/no accepted pointer rejects production; audit data cannot train; typed unavailable enrichments stay inactive |
| `test_phase19_rating.R` | `test_benchmark_cutoffs.R:25-57`; `test_statistical_dynamic_state.R:61-100` | same-kickoff reorder is byte-identical; current result changes only later state; club IDs only |
| `test_phase19_goal_model.R` | Phase 9 baseline tests; statistical challenger tests | strict `< cutoff`; full 1,681-cell grid for G=40; mass/derived market consistency; NB failure has no fallback |
| `test_phase19_evaluation.R` | proper-score and Phase 10 promotion tests | exact paired fixture set; frozen bins/folds/seeds; held-out leagues never tune; missing rows fail coverage |
| `test_phase19_release.R` | `test_phase12_release.R:167-343`; `test_phase14_calibration_release.R:256-352` | metadata preflight precedes RDS; exact inventory; no symlinks/path escape; hash/object/selector forgery rejected |
| `test_phase19_adversarial_regression.R` | `test_phase18_adversarial_regression.R:422-443` | interrupted generation/selector writes leave prior authority valid; fixture cannot mutate production |
| bidirectional domain tests | release tests plus UCL adapter tests | national resolver rejects club; club resolver rejects national; compatible object class does not bypass domain |
| reproducibility tests | Phase 10 seed and benchmark-output tests | reordered input/registry rows canonicalize deterministically; identical protocol + evidence yields byte-identical outputs |

## Reuse vs Separation Rules

| Concern | Reuse | Keep separate / reject |
|---|---|---|
| Hashing | Phase 18 canonical-v2 framing, typed values, table manifests | delimiter-concatenated Phase 9 hashes; untyped `digest(data.frame)` authority |
| Evidence gateway | Phase 18 accepted pointer/generation validation | audit-only corpus, blocked pointer, raw downloads, fixtures in production |
| Rating math | Elo expectation/update equations | national FIFA/team-keyed state; sequential same-batch mutation |
| Goal models | strict-cutoff controls, fail-closed NB, full score grids | national coefficients/features/models; NA-to-zero; Poisson fallback |
| Proper scores | generic Brier/RPS/log/scoreline functions | national tournament aggregation constants and labels |
| Evaluation mechanics | exact paired fixtures, frozen bins, deterministic bootstrap/tie break | twelve-edition/open-core rules and national thresholds |
| Release mechanics | staged immutable generation, exact inventory, metadata preflight, selector reread | national release root, national selector schema, national object authority |
| Orchestration | file targets and validate-before-consume edges | dependencies on national forecast/release targets |
| Consumer boundary | shared generic probability/score-grid schemas | `R/competition/forecast_layer.R` national defaults and team-form loaders |
| Documentation | model-card topology and reproducibility disclosure | global/national `MODEL-CARD.md` as club evidence |

## Shared Patterns

### Fail-closed reason vocabulary

Use stable machine-readable reason codes at contract boundaries and store them in durable decisions/manifests. Expected classes include `no_accepted_club_history`, `domain_mismatch`, `protocol_hash_mismatch`, `cutoff_violation`, `same_batch_leakage`, `coverage_gate_failed`, `reproducibility_gate_failed`, `release_inventory_mismatch`, and `selector_changed_during_resolution`. Tests should assert codes rather than unstable prose.

### Determinism

Canonicalize registry and evidence rows by declared keys using radix ordering before hashing or fitting. Seed identity belongs in the frozen protocol and artifact manifest. Derive no production seed from wall time, random temp paths, or unordered directory listings.

### Exact inventory and readback

Both benchmark runs and releases should declare exact recursive inventories. Writers stage into a sibling candidate directory, independently validate/read back, atomically rename, validate the installed destination, and only then advance a selector. Validators reject extra files as well as missing files.

### Temporal safety

All training predicates are strictly earlier than the assessment cutoff. All fixtures sharing the same exact kickoff use one pre-kickoff snapshot. Where only a calendar date is proven, conservatively batch the entire date. Evidence observation time must not exceed the assessment cutoff even if the match completion date is earlier.

### Model card as authority evidence

The model card is generated from validated machine-readable artifacts, not hand-authored as a substitute for them. Its identifiers/hashes must agree with the model contract and release manifest.

## Fixture-backed vs Production Authority

| State | Evaluation allowed | Release allowed | Selector allowed |
|---|---|---|---|
| Phase 18 accepted, production protocol valid | yes, against accepted immutable club corpus | yes, after all gates | yes, atomic validated advancement |
| Phase 18 blocked or no accepted generation (current state) | diagnostics/block decision only | no production release | no production selector |
| Synthetic fixture mode | yes, mechanics tests only, visibly tagged `fixture` | temporary fixture bundle only | fixture-local descriptor only; production resolver rejects it |
| National evidence or national selector supplied | no | no | no; `domain_mismatch` |

## No Close Analog Found

| File/contract | Reason | Planner guidance |
|---|---|---|
| club leave-one-league-out fold registry | Existing evaluation is tournament-edition based | Specify league exclusion, promoted/relegated club handling, weighting, and hyperparameter isolation explicitly |
| bidirectional club/national domain rejection | Existing release contract assumes one national domain | Put `model_domain` in selector, manifest, model contract, model object, and resolver expected-domain argument; test both directions |
| typed unavailable enrichment registry | Existing models mainly infer active columns | Make availability a required registry with reason/source/value/active fields; absence is invalid, not equivalent to unavailable |

## Risks and Planner Guardrails

1. **Current production evidence is blocked.** A plan that expects a successful production model/release cannot complete until Phase 18 has an accepted generation. Plan deterministic fixture mechanics and explicit blocked-production verification separately.
2. **Date precision can disguise leakage.** `match_date` is not an exact kickoff. Exact kickoff batching is required when timestamps exist; otherwise use a conservative full-date batch.
3. **Fixture authority can escape into production.** Separate roots and schema tags are required; merely adding `fixture = TRUE` to an otherwise valid production manifest is insufficient.
4. **National constants are embedded in reusable-looking code.** Search adaptations for `open_core`, `world_cup`, `euro`, twelve-edition assumptions, FIFA codes, and national selector IDs.
5. **Silent model fallbacks invalidate the frozen candidate.** Non-convergence, missing predictors, or unavailable enrichments must fail the candidate/gate, not switch model family or impute zero.
6. **Coverage can be gamed by omission.** Promotion comparisons require the exact same registered fixtures; missing predictions count against coverage and cannot disappear before scoring.
7. **Release topology is an attack surface.** Reject symlinks, path traversal, extra files, forged self-hashes, mismatched R objects, selector swaps, and selectors outside the trusted club root.
8. **Compatible object structure is not authority.** A national model that implements the same predict method remains invalid for a club resolver and vice versa.
9. **Unavailable data must remain visible.** current xG, injuries, lineups, suspensions, and player features are disclosed as unavailable until a lawful accepted source contract exists; no heuristic substitute may use those labels.
10. **Byte reproducibility requires stable serialization.** CSV column order, row order, numeric formatting, timezone normalization, and RDS serialization/version must be frozen and tested.

## Metadata

**Analog search scope:** `R/club`, `R/benchmark`, `R/evaluation`, `R/release`, `R/forecast`, `R/elo`, `R/competition`, `_targets.R`, `scripts`, `tests/testthat`, Phase 18 artifacts, and milestone research.  
**Strong analogs inspected:** 15 source/runner files plus their focused tests.  
**Pattern extraction date:** 2026-09-20.  
**Planning readiness:** ready, with production success explicitly contingent on a future accepted Phase 18 history generation.
