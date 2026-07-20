---
phase: 09
slug: rolling-tournament-benchmark-harness
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-20
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `testthat` 3.3.2 |
| **Config file** | None; repository tests source modules directly from `tests/testthat/` |
| **Quick run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R"); testthat::test_file("tests/testthat/test_benchmark_scoring.R"); testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated runtime** | Quick suite under 60 seconds; full historical benchmark excluded from per-task sampling |

---

## Sampling Rate

- **After every task commit:** Run the task's focused `test_benchmark_*.R` file and any directly affected incumbent test.
- **After every plan wave:** Run all `test_benchmark_*.R` files plus `test_transfermarkt_benchmark.R`, `test_worldcup_scoring.R`, and `test_worldcup_retrospective.R`.
- **Before `$gsd-verify-work`:** Run the full `tests/testthat` suite, load `targets::tar_manifest()`, and compare hashes from two deterministic benchmark runs.
- **Max feedback latency:** 60 seconds for task-level synthetic tests.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 0 | BENCH-01 | T-09-01 | Canonical fold registry contains exactly the sealed 12 editions and expected fixture keys | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_registry.R")'` | ❌ W0 | ⬜ pending |
| 09-01-02 | 01 | 0 | BENCH-03 | T-09-02 | Benchmark joins use stable team IDs with complete FIFA-code coverage | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_registry.R")'` | ❌ W0 | ⬜ pending |
| 09-01-03 | 01 | 1 | BENCH-01, BENCH-02 | T-09-01, T-09-03 | Boundaries are date-complete and development paths reject WC2026 labels before model invocation | adversarial unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_cutoffs.R"); testthat::test_file("tests/testthat/test_benchmark_seal.R")'` | ❌ W0 | ⬜ pending |
| 09-01-04 | 01 | 1 | BENCH-01 | T-09-04 | Registry and protocol checksums are stable across ordering and reruns | property | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_registry.R")'` | ❌ W0 | ⬜ pending |
| 09-02-01 | 02 | 2 | BENCH-03 | T-09-05 | Every adapter emits complete, finite, normalized score grids and reconciling markets | contract | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R")'` | ❌ W0 | ⬜ pending |
| 09-02-02 | 02 | 2 | BENCH-04 | T-09-06 | Uniform and expanding-rate controls are coherent distributions using prior-only evidence | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R")'` | ❌ W0 | ⬜ pending |
| 09-02-03 | 02 | 2 | BENCH-04 | T-09-07 | Elo, open NB, and rich NB adapters share fixture keys, cutoffs, seeds, and fail on missing coverage | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_baselines.R")'` | ❌ W0 | ⬜ pending |
| 09-02-04 | 02 | 2 | BENCH-03, BENCH-04 | T-09-08 | Format adapters conserve stage probability mass and use the common random-number ledger | property | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_contracts.R")'` | ❌ W0 | ⬜ pending |
| 09-03-01 | 03 | 3 | BENCH-05 | T-09-09 | Proper scores and fixed-bin calibration match hand-calculated fixtures | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_scoring.R")'` | ❌ W0 | ⬜ pending |
| 09-03-02 | 03 | 3 | BENCH-05 | T-09-10 | Headline metrics weight tournaments equally and paired uncertainty resamples tournaments | unit + property | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_scoring.R")'` | ❌ W0 | ⬜ pending |
| 09-03-03 | 03 | 3 | BENCH-05 | T-09-11 | Promotion thresholds, breadth rules, and vetoes are pure, ordered, and boundary-exact | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` | ❌ W0 | ⬜ pending |
| 09-03-04 | 03 | 3 | BENCH-05 | T-09-12 | Self-comparisons return exact zero deltas and weaker controls retain the incumbent | regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_promotion.R")'` | ❌ W0 | ⬜ pending |
| 09-04-01 | 04 | 4 | BENCH-01–05 | T-09-13 | `targets` branches preserve registered dependencies and load without execution | pipeline | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R"); targets::tar_manifest()'` | ❌ W0 | ⬜ pending |
| 09-04-02 | 04 | 4 | BENCH-02, BENCH-05 | T-09-14 | Cache-only runner performs no network access and reproduces content hashes | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R")'` | ❌ W0 | ⬜ pending |
| 09-04-03 | 04 | 4 | BENCH-01–05 | T-09-15 | Full sealed bundle covers every registered fixture/panel and validates all manifests | acceptance | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_benchmark_pipeline.R")'` | ❌ W0 | ⬜ pending |
| 09-04-04 | 04 | 4 | BENCH-05 | T-09-16 | Phase 08 scoring and dashboard behavior remain unchanged | regression | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_transfermarkt_benchmark.R"); testthat::test_file("tests/testthat/test_worldcup_scoring.R"); testthat::test_file("tests/testthat/test_worldcup_retrospective.R")'` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `data/benchmark/phase09/*.csv` and source notes — canonical editions, fixtures, statuses, regulation scores, identities, formats, routes, panels, models, features, and seeds.
- [ ] `tests/testthat/helper_benchmark.R` — synthetic histories, format fixtures, adapter stubs, and fixed distributions.
- [ ] `tests/testthat/test_benchmark_registry.R`
- [ ] `tests/testthat/test_benchmark_cutoffs.R`
- [ ] `tests/testthat/test_benchmark_seal.R`
- [ ] `tests/testthat/test_benchmark_contracts.R`
- [ ] `tests/testthat/test_benchmark_baselines.R`
- [ ] `tests/testthat/test_benchmark_scoring.R`
- [ ] `tests/testthat/test_benchmark_promotion.R`
- [ ] `tests/testthat/test_benchmark_pipeline.R`

No framework installation is needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Source-attribution review for historical stage, status, and regulation-time corrections | BENCH-01, BENCH-03 | Provenance quality cannot be fully inferred from row shape | Review every curated correction against its cited source before freezing registry checksums. |
| Pre-WC2026 seal sign-off | BENCH-02, BENCH-05 | The freeze is a governance event as well as a software assertion | Confirm the committed protocol, candidate registry, panel registry, seeds, thresholds, and checksums before any WC2026 result is opened. |

---

## Validation Sign-Off

- [x] All planned tasks have an automated verify command or Wave 0 dependency.
- [x] Sampling continuity: no three consecutive tasks lack automated verification.
- [x] Wave 0 covers all missing test references.
- [x] No watch-mode flags.
- [x] Task-level feedback latency target is under 60 seconds.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** approved 2026-07-20 for planning; execution remains gated on Wave 0 completion.
