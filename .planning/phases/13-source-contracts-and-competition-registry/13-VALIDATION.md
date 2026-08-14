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
- **Final Wave 9 / before `/gsd:verify-work`:** Run the full `testthat::test_dir("tests/testthat")` suite, deterministic replay of one official candidate and one reviewed fallback candidate, and the final human backstop.
- **Max focused feedback latency:** 60 seconds. The approximately 352-second repository-wide suite is reserved for the final Wave 9/phase gate.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-02 / T-13-03 / T-13-04 | Tracer proves a compact structured fixture becomes an accepted bundle, normalized team row, and edition registry row with linked provenance. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-01-02 | 01 | 1 | DATA-01, DATA-02, DATA-03, DATA-04, COMP-01 | T-13-01 / T-13-03 / T-13-04 / T-13-05 | Edge/prohibition tests cover missing resources, null provenance, ordering, encoding, ambiguity, mixed fallback, pre_draw truthfulness, and raw-store tracking. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-02-01 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-02-01 / T-13-02-03 / T-13-02-04 | Five-class schema/provenance validation rejects incomplete, unsafe, non-structured, or mixed candidates. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-02-02 | 02 | 2 | DATA-01, DATA-02, DATA-04 | T-13-02-02 / T-13-02-03 | Explicit status URL and derived status paths both retain source_artifact_id lineage and all provenance fields; absent status evidence fails closed. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-07-01 | 07 | 3 | DATA-01, DATA-02 | T-13-07-01 / T-13-07-02 | Bounded capture requires four mandatory HTTPS structured URLs and accepts optional explicit status or validated derived status. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-07-02 | 07 | 3 | DATA-02, DATA-04 | T-13-07-02 / T-13-07-03 / T-13-07-04 | Raw bytes are ignored and exact-verified; compact source registries retain parser/provenance/fallback/lineage metadata. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-09-01 | 09 | 4 | DATA-01, DATA-02, DATA-04 | T-13-09-01 / T-13-09-02 | Candidate promotion is atomic, five-class complete, and prior-output retaining. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-09-02 | 09 | 4 | DATA-01, DATA-02, DATA-04 | T-13-09-01 / T-13-09-03 | Nations League manifest/tables match source registries, preserve explicit/derived status lineage, and contain no tracked raw bodies. | integration | `Rscript --vanilla scripts/acquire_uefa_snapshot.R --fixture-dir tests/fixtures/phase13 --edition-id uefa_nations_league_2026_27 --output-root data/competition/accepted --registry-root data/competition/registries --dry-run` | yes - existing script/fixtures | pending |
| 13-10-01 | 10 | 5 | DATA-01, DATA-02, DATA-04 | T-13-10-01 / T-13-10-02 | EURO pre_draw manifest, fixtures, and results are schema-complete, provenance-linked, and empty where structures are unavailable. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-10-02 | 10 | 5 | DATA-01, DATA-02, DATA-04 | T-13-10-01 / T-13-10-03 | EURO groups/standings remain empty and status explicitly records pre_draw with source_artifact_id lineage. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-03-01 | 03 | 6 | DATA-03 | T-13-10 / T-13-11 | Stable team identity and warning-bearing normalized-name fallback preserve display names, aliases, IDs, and order-stable hashes. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-01 | pending |
| 13-03-02 | 03 | 6 | COMP-01 | T-13-12 / T-13-13 / T-13-14 | Both edition rows enforce lifecycle, blocked overlay, pinned release, source/output slots, explicit EURO pre_draw, and no fabricated structures. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R"); source("R/competition/edition_registry.R"); regs <- load_competition_edition_registries("data/competition/registries"); validate_competition_edition_registries(regs)'` | yes - created in Plan 13-01 | pending |
| 13-04-01 | 04 | 7 | DATA-01, DATA-02, DATA-03 | T-13-04-01 / T-13-04-02 / T-13-04-04 | Production acquisition routes accepted fixtures through stable identity normalization and preserves optional/derived status provenance. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-04-02 | 04 | 7 | DATA-03 | T-13-04-02 | Accepted results join exactly to normalized fixtures, preserve source status/valid scores/names, carry both artifact links, and distinguish score-only edits from identity/edition changes. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing files | pending |
| 13-04-03 | 04 | 7 | DATA-02, DATA-03 | T-13-04-01 / T-13-04-03 / T-13-04-04 | Accepted fixture/result artifacts have exact normalized schemas, stable hashes, source IDs, display names, edition/artifact links, and no tracked raw bytes. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_source_contracts.R")'` | yes - existing file | pending |
| 13-05-01 | 05 | 8 | DATA-01, DATA-02, DATA-03, COMP-01 | T-13-05-01 / T-13-05-02 | Production edition loading validates accepted directories, all five resources, manifest/registry IDs, canonical content hashes, raw hashes, EURO pre_draw, and blocked refresh-batch linkage. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing file | pending |
| 13-05-02 | 05 | 8 | DATA-03 | T-13-05-03 | Default identity loading requires adjacent source-bundle provenance and rejects forged foreign keys even after row-hash recomputation. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - existing file | pending |
| 13-06-01 | 06 | 9 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-02 / T-13-06-03 | Failed refresh stages/validates competition_editions.csv, marks the edition blocked with blocked_refresh_batch_id, marks the refresh batch status=blocked with the same refresh_batch_id, preserves source/accepted artifacts, and writes matching blocked_refresh.json metadata. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - created in Plan 13-06-01 | pending |
| 13-06-02 | 06 | 9 | DATA-02, DATA-04, COMP-01 | T-13-06-01 / T-13-06-04 / T-13-06-05 | Blocked recovery requires explicit operator action/validation, preserves the failed batch status=blocked and matching edition blocked_refresh_batch_id, and uses a distinct refresh_batch_id for later accepted refresh. | integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_refresh_failure.R"); testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-06-01 | pending |
| 13-08-01 | 08 | 9 | DATA-03 | T-13-08-01 / T-13-08-02 | Historical rows require explicit edition lookup, preserve source fields, and resolve stable identity without using scores or future rows. | unit/integration | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | no - created in Plan 13-08-01 | pending |
| 13-08-02 | 08 | 9 | DATA-03 | T-13-08-02 / T-13-08-03 | Future-row append/reorder/perturbation and score-only regressions preserve IDs/editions; identity/edition changes fail closed. | unit | `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_phase13_competition_registry.R")'` | yes - created in Plan 13-08-01 | pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - bundle/artifact schema, required five resources, explicit/derived status, hashes, structured fixture replay, and fallback-mixing rejection.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - identity mapping, lifecycle transitions, blocked recovery, pre_draw EURO row, pinned release invariants, accepted result joins, and historical safety.
- [ ] `tests/fixtures/phase13/uefa_nations_league_sample.json` - compact structured Nations League sample used by bounded capture and accepted publication.
- [ ] `tests/fixtures/phase13/euro2028_predraw_sample.json` - schema-complete EURO pre_draw resource metadata.
- [ ] `tests/fixtures/phase13/reviewed_fallback_bundle.json` - complete reviewed fallback bundle fixture.
- [ ] `tests/fixtures/phase13/team_identity_aliases.csv` - identity fallback, encoding, and ambiguity cases. Exact raw captures remain local-only.

## Gap-Closure Regression Requirements

- [ ] `tests/testthat/test_phase13_source_contracts.R` - Plan 13-02 optional-status/derived-status contract, Plan 13-07 bounded capture, Plans 13-09/13-10 accepted publication, preserved provenance, and no tracked raw bytes.
- [ ] `tests/testthat/test_phase13_competition_registry.R` - Plan 13-04 accepted fixture/result identity regressions, Plan 13-05 accepted-loader/foreign-key regressions, and Plan 13-08 historical future-row/score-only safety.
- [ ] `tests/fixtures/phase13/martj42_history_sample.csv` and `tests/fixtures/phase13/martj42_history_edition_map.csv` - compact preprocess_martj42()-shaped history rows plus explicit edition lookup.
- [ ] `tests/testthat/test_phase13_refresh_failure.R` - Plan 13-06 temporary-copy regression for blocked edition state, blocked_refresh_batch_id, refresh_batch_id/status=blocked, candidate/accepted linkage, blocked_refresh.json, explicit recovery, and complete accepted-tree/source-registry snapshots.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Confirm the live official UEFA structured service paths and response shapes remain available at capture time. | DATA-01 | UEFA service paths are public but undocumented and may change independently of the parser contract. | After the final automated Wave 9 gate, run bounded capture with explicit HTTPS structured URLs for fixtures, groups, standings, and results; supply a status URL only when one is available. If it is omitted, inspect the accepted status-bearing fields and the derived status artifact's source_artifact_id links. Confirm all five classes, provenance, and prior-output retention on failure. |
| Confirm reviewed fallback and failed-refresh recovery in an isolated operational copy. | DATA-04, COMP-01 | Review approval, operator action, and current source evidence cannot be established by fixture-only automation. | As the final human backstop after Wave 9, run one reviewed fallback and one invalid replacement against temporary registry/output roots. Confirm source/retrieval/reason/operator/checksum metadata, competition_editions.csv blocked=TRUE with blocked_refresh_batch_id, blocked_refresh.json status=blocked with the matching refresh_batch_id, candidate/accepted links and matching registry revision, unchanged accepted fixtures/groups/standings/results/status/manifest files and source registries, then explicit operator-action recovery before a later accepted refresh with a new batch identity. |

## Final Human Backstop

The final human backstop is required after the Wave 9 automated checks and before Phase 13 verification sign-off. It covers live official structured capture with four mandatory URL classes plus optional status sourcing, the reviewed-fallback workflow, the durable edition-plus-refresh-batch blocked state (`blocked_refresh_batch_id` equals `blocked_refresh.json`'s `refresh_batch_id`, with `status=blocked`), and explicit recovery. Deterministic fixture replay is supporting evidence only and does not substitute for these operational checks.

## Validation Sign-Off

- [ ] All tasks have an automated verify command or a Wave 0 dependency.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing test and fixture references.
- [ ] No watch-mode flags.
- [ ] The repository-wide suite is reserved for the final Wave 9/phase gate; focused task gates remain under the feedback target.
- [ ] `nyquist_compliant: true` set in frontmatter after execution and verification.
- [ ] Approval: pending
