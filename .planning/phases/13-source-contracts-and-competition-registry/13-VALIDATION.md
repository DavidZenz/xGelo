---
phase: 13
slug: source-contracts-and-competition-registry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-13
---

# Phase 13 - Validation Strategy

> Per-phase validation contract for the source snapshot and competition registry contracts.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | none - source-style tests in `tests/testthat/` |
| **Focused run command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` |
| **Refresh/registry focused command** | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` |
| **Full suite command** | `Rscript --vanilla -e 'testthat::test_dir("tests/testthat")'` |
| **Estimated focused runtime** | under 60 seconds |
| **Estimated full-suite runtime** | long-running final gate; prior Phase 13 execution was approximately 352 seconds |

## Sampling Rate

- **After every task commit:** Run only the focused Phase 13 source, registry, or refresh tests named by that task.
- **After each non-final wave:** Use the task-level focused commands; do not run the repository-wide suite as an intermediate wave gate.
- **Final post-Wave-10 gate / before `/gsd:verify-work`:** Plan 13-08 completes in Wave 9; Plan 13-06 is Wave 10 and depends on Plan 13-08. Only after the Wave 10 Plan 13-06 tasks run the full `testthat::test_dir("tests/testthat")` suite, the final post-Wave-10 operational exercises (one official live structured replay, one complete reviewed-fallback replay, and one invalid replacement), and the final human backstop.
- **Max focused feedback latency:** 60 seconds. The approximately 352-second repository-wide suite is reserved for the final post-Wave-10 phase gate.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-02 / T-13-03 / T-13-04 | Tracer proves a compact structured fixture becomes an accepted bundle, normalized team row, and edition registry row with linked provenance. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-01-02 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-03 / T-13-04 / T-13-05 | Edge/prohibition tests cover missing resources, null provenance, ordering, encoding, ambiguity, mixed fallback, pre_draw truthfulness, and raw-store tracking. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-02-01 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-02-01 / T-13-02-03 / T-13-02-04 | Five-class schema/provenance validation rejects incomplete, unsafe, non-structured, or mixed candidates. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-02-02 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-02-02 / T-13-02-03 | Explicit status URL and derived status paths both retain source_artifact_id lineage and all provenance fields; absent status evidence fails closed. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-07-01 | 07 | 3 | DATA-01, DATA-02 | T-13-07-01 / T-13-07-02 | Bounded capture requires four mandatory HTTPS structured URLs and accepts optional explicit status or validated derived status. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-07-02 | 07 | 3 | DATA-02, DATA-04 | T-13-07-02 / T-13-07-03 / T-13-07-04 | Raw bytes are ignored and exact-verified; compact source registries retain parser/provenance/fallback/lineage metadata plus canonical_content_sha256 values. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-09-01 | 09 | 4 | DATA-01, DATA-02, DATA-04 | T-13-09-01 / T-13-09-02 | Candidate promotion is atomic, five-class complete, and prior-output retaining. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-09-02 | 09 | 4 | DATA-01, DATA-02, DATA-04 | T-13-09-01 / T-13-09-03 | Nations League source-shaped handoff manifest/tables match seed source-registry hashes, preserve explicit/derived status lineage, contain no tracked raw bodies, and hand final canonical/hash-graph sealing to Plan 13-04-03. | integration | `Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id uefa_nations_league_2026_27 --output-root data/competition/accepted --registry-root data/competition/registries --dry-run` | yes - existing script/fixtures | pending |
| 13-10-01 | 10 | 5 | DATA-01, DATA-02, DATA-04 | T-13-10-01 / T-13-10-02 | EURO pre_draw handoff manifest, fixtures, and results are schema-complete, provenance-linked, seed-hash-backed, and empty where structures are unavailable; final canonical/hash-graph sealing belongs to Plan 13-04-03. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-10-02 | 10 | 5 | DATA-01, DATA-02, DATA-04 | T-13-10-01 / T-13-10-03 | EURO groups/standings remain empty and seed-hash-backed while status explicitly records pre_draw with source_artifact_id lineage; Plan 13-04-03 refreshes shared registry/manifests and derived hashes. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-03-01 | 03 | 6 | DATA-03 | T-13-10 / T-13-11 | Stable team identity and warning-bearing normalized-name fallback preserve display names, aliases, IDs, and order-stable hashes. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-03-02 | 03 | 6 | COMP-01 | T-13-12 / T-13-13 / T-13-14 | Both edition rows enforce lifecycle, blocked overlay, pinned release, source/output slots, explicit EURO pre_draw, and no fabricated structures. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R"); source("R/competition/edition_registry.R"); regs <- load_competition_edition_registries("data/competition/registries"); validate_competition_edition_registries(regs)'` | yes - created in Plan 13-01 | pending |
| 13-04-01 | 04 | 7 | DATA-01, DATA-02, DATA-03 | T-13-04-01 / T-13-04-02 / T-13-04-04 | Production acquisition routes accepted fixtures through stable identity normalization and preserves optional/derived status provenance. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-04-02 | 04 | 7 | DATA-03 | T-13-04-02 | Accepted results join exactly to normalized fixtures, preserve source status/valid scores/names, carry both artifact links, and distinguish score-only edits from identity/edition changes. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing files | pending |
| 13-04-03 | 04 | 7 | DATA-01, DATA-02, DATA-03, DATA-04 | T-13-04-01 / T-13-04-02 / T-13-04-03 / T-13-04-04 | Normalized publication atomically refreshes both editions, source_artifacts.csv, source_bundles.csv, both accepted manifests, canonical_content_sha256, all derived bundle/manifest hashes, and staged unchanged tables; complete target rollback and append/reorder/score-only/identity regressions pass. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing files | pending |
| 13-05-01 | 05 | 8 | DATA-01, DATA-02, DATA-03, COMP-01 | T-13-05-01 / T-13-05-02 | Post-normalization production loading succeeds for both editions and validates accepted directories, all five resources, manifest/registry IDs, canonical content hashes, raw hashes, normalized identity/provenance, and EURO pre_draw; the dependent Wave 10 Plan 13-06 row owns blocked refresh-batch/history linkage. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R"); source("R/competition/source_contracts.R"); source("R/competition/team_identity.R"); source("R/competition/edition_registry.R"); regs <- load_competition_edition_registries("data/competition/registries"); stopifnot(identical(sort(as.character(regs$edition_id)), sort(c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")))); stopifnot(all(c("home_team_id", "away_team_id", "edition_id") %in% names(regs$accepted_snapshots[["uefa_nations_league_2026_27"]]$fixtures))); stopifnot(all(c("home_team_id", "away_team_id", "edition_id") %in% names(regs$accepted_snapshots[["uefa_nations_league_2026_27"]]$results)))'` | yes - existing file | pending |
| 13-05-02 | 05 | 8 | DATA-03 | T-13-05-03 | Default identity loading requires adjacent source-bundle provenance and rejects forged foreign keys even after row-hash recomputation. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing file | pending |
| 13-06-01 | 06 | 10 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-02 / T-13-06-03 | Failed refresh stages and cross-validates competition_editions.csv, registry-side blocked_refresh.json, and append-only status_history.csv, marks the edition blocked with blocked_refresh_batch_id and the refresh batch status=blocked with the same refresh_batch_id, preserves source/accepted artifacts, and rolls back all three registry artifacts on injected sidecar-write failure. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - created in Plan 13-06-01 | pending |
| 13-06-02 | 06 | 10 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-04 / T-13-06-05 | Blocked recovery requires explicit operator action/validation, preserves the immutable registry-side failed batch status=blocked, matching edition blocked_refresh_batch_id, block-time history, and uses a distinct refresh_batch_id for later accepted refresh; final post-Wave-10 human checks also replay official live structured, complete reviewed-fallback, and invalid replacement candidates. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-06-01 | pending |
| 13-08-01 | 08 | 9 | DATA-03 | T-13-08-01 / T-13-08-02 | Historical rows require explicit edition lookup, preserve source fields, and resolve stable identity without using scores or future rows. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - created in Plan 13-08-01 | pending |
| 13-08-02 | 08 | 9 | DATA-03 | T-13-08-02 / T-13-08-03 | Future-row append/reorder/perturbation and score-only regressions preserve IDs/editions; identity/edition changes fail closed. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-08-01 | pending |
| 13-08-03 | 08 | 9 | DATA-03 | T-13-08-01 / T-13-08-02 / T-13-08-03 / T-13-08-04 | The unchanged `preprocess_martj42()` output reaches the named targets loader, which validates source identity and explicit edition coverage before atomically writing the durable normalized historical artifact with source IDs, display names, stable team IDs, edition IDs, provenance, and row hashes. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-08-03 | pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - bundle/artifact schema, required five resources, explicit/derived status, hashes, structured fixture replay, and fallback-mixing rejection.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - identity mapping, lifecycle transitions, blocked recovery, pre_draw EURO row, pinned release invariants, accepted result joins, and historical safety.
- [ ] `tests/fixtures/phase13/uefa_nations_league_sample.json` - compact structured Nations League sample used by bounded capture and accepted publication.
- [ ] `tests/fixtures/phase13/euro2028_predraw_sample.json` - schema-complete EURO pre_draw resource metadata.
- [ ] `tests/fixtures/phase13/reviewed_fallback_bundle.json` - complete reviewed fallback bundle fixture.
- [ ] `tests/fixtures/phase13/team_identity_aliases.csv` - identity fallback, encoding, and ambiguity cases. Exact raw captures remain local-only.

## Gap-Closure Regression Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - Plan 13-02 optional-status/derived-status contract, Plan 13-07 bounded capture, Plans 13-09/13-10 accepted publication, preserved provenance, and no tracked raw bytes.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - Plan 13-04 accepted fixture/result identity regressions, Plan 13-05 accepted-loader/foreign-key regressions, Plan 13-08 historical future-row/score-only safety, and the production martj42 target/artifact seam with complete explicit edition lookup.
- [ ] `tests/testthat/test_phase13_source_contracts.R` and `tests/testthat/test_phase13_competition_registry.R` - Plan 13-04-03 normalized publication regression covers the complete target vector (`source_artifacts.csv`, `source_bundles.csv`, both accepted manifests, and all ten accepted resource tables), post-normalization canonical/derived hash refresh, successful publication, stale-hash rejection, and byte-for-byte rollback after an injected mid-publication failure.
- [ ] `tests/fixtures/phase13/martj42_history_sample.csv` and `tests/fixtures/phase13/martj42_history_edition_map.csv` - compact preprocess_martj42()-shaped history rows plus explicit edition lookup.
- [ ] `tests/testthat/test_phase13_refresh_failure.R` - Plan 13-06 temporary-copy regression for blocked edition state, blocked_refresh_batch_id, registry-side refresh_batch_id/status=blocked, candidate/accepted linkage, append-only status_history.csv, explicit recovery, sidecar-write rollback, and complete accepted-tree/source-registry snapshots. The task creates this file before focused verification.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm the final post-Wave-10 official live structured replay and loader success. | DATA-01, DATA-02, DATA-03 | UEFA service paths are public but undocumented and may change independently of the parser contract; the final normalized publication and loader must be checked against current structured responses. | After the final automated Wave 10 gate, run bounded capture with explicit HTTPS structured URLs for fixtures, groups, standings, and results; supply a status URL only when one is available. If it is omitted, inspect the accepted status-bearing fields and the derived status artifact's source_artifact_id links. Confirm all five classes, normalized IDs/display names, source_artifacts.csv/source_bundles.csv, both accepted manifests, every canonical/derived hash, post-normalization loader success, and no rendered HTML/PDF substitution. |
| Confirm the final reviewed-fallback replay, invalid replacement, and explicit recovery in an isolated operational copy. | DATA-04, COMP-01 | Review approval, operator action, and current source evidence cannot be established by fixture-only automation. | Only after the final automated Wave 10 Plan 13-06 gate, run both a complete reviewed fallback and an invalid replacement against temporary registry/output roots. Confirm source/retrieval/reason/operator/checksum metadata for the fallback; confirm the invalid replacement leaves normalized accepted fixtures/groups/standings/results/status/manifests and source registries unchanged, writes competition_editions.csv blocked=TRUE with blocked_refresh_batch_id, writes registry-side `data/competition/registries/refresh_batches/<edition_id>/<refresh_batch_id>/blocked_refresh.json` status=blocked with the matching refresh_batch_id, preserves append-only status_history.csv block/recovery/later-accepted events and block-time registry revision, then requires explicit operator-action recovery before a later accepted refresh with a new batch identity. |

## Final Human Backstop

The final human backstop is required only after the Wave 10 Plan 13-06 automated checks, which are ordered after Wave 9 Plan 13-08, and before Phase 13 verification sign-off. It covers the final official live structured replay with four mandatory URL classes plus optional status sourcing, successful post-normalization loader validation, the complete reviewed-fallback replay, the invalid replacement, the durable edition-plus-refresh-batch blocked state (`blocked_refresh_batch_id` equals the registry-side `blocked_refresh.json`'s `refresh_batch_id`, with `status=blocked`), append-only status history through recovery and a later distinct batch, and explicit recovery. Deterministic fixture replay is supporting evidence only and does not substitute for these operational checks.

## Validation Sign-Off

- [ ] All tasks have an automated verify command or a Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test and fixture references.
- [ ] No watch-mode flags.
- [ ] Plan 13-08 completes in Wave 9 before Plan 13-06 Wave 10; the repository-wide suite and the three-part official-live/reviewed-fallback/invalid-replacement human backstop are reserved for that final post-Wave-10 phase gate, while focused task gates remain under the feedback target.
- [ ] `nyquist_compliant: true` set in frontmatter after execution and verification.
- [ ] Approval: pending
