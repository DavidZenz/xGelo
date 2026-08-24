---
phase: 16-euro-qualifying-activation-and-play-off-rules
verified: 2026-08-24T17:24:55Z
status: human_needed
score: 20/20 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 17/20
  gaps_closed:
    - "Scheduled activation now rejects empty official status resources and requires accepted edition and lifecycle evidence."
    - "Qualification simulation now fails closed for NULL or unvalidated activation and emits zero probability rows."
    - "Outcomes publication now restores the incumbent byte-for-byte after post-promotion read-back failure."
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "The dashboard visibly presents source confidence beside the pre-draw status summary."
    addressed_in: "Phase 17"
    evidence: "Phase 17 success criterion 3 requires refresh status, source confidence, model release, warnings, and replayable simulation metadata on every published dashboard."
human_verification:
  - test: "Inspect the first official post-draw EURO bundle before active publication."
    expected: "The accepted manifest, source revisions, raw snapshot metadata, group and fixture identities, confirmed kickoffs, host/Nations League ledger statuses, draw-condition lineage, and blocked reasons match the official UEFA bundle; no candidate-only rows are visible."
    why_human: "The current accepted state is intentionally pre_draw and the first real post-draw external source bundle is not available to static tests."
---

# Phase 16: EURO Qualifying Activation and Play-off Rules Verification Report

**Phase Goal:** Users can see a truthful EURO 2028 qualifying dashboard before the draw and the full official qualification logic once UEFA publishes the draw and schedule.
**Verified:** 2026-08-24T17:24:55Z
**Status:** HUMAN_NEEDED
**Re-verification:** Yes, after gap remediation

## Verdict

**PASS:** All 20 roadmap and prior-verification must-haves are now verified in the live code, including fresh targeted probes for all three former blockers.

**CONCERNS:** The recorded repository baseline remains non-green by design. Source confidence is present in the Phase 16 CLI/payload contract, while its final dashboard presentation is explicitly deferred to Phase 17. The first real official post-draw source bundle still requires the human inspection listed below.

**BLOCKERS:** None found.

The frontmatter status is `human_needed` because the Phase 16 Plan 05 deliberately requires a human inspection of the first external post-draw bundle. No implementation gap remains.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Roadmap SC1: pre-draw remains explicit through 2026-12-06 without invented groups, fixtures, standings, or probabilities. | VERIFIED | Durable read-back passed validation with `candidate_status=pre_draw`; seven structural/probability artifacts have zero rows; metadata and manifest carry `expected_draw_date=2026-12-06` and `awaiting_official_draw_and_schedule`. |
| 2 | Roadmap SC2 / COMP-03: active state is possible only from a complete official draw-and-schedule bundle. | VERIFIED | Active-after-draw, empty-status, missing-kickoff, Phase 14 gate, and lifecycle tests passed; current accepted pre-draw resources remain empty and do not activate by date. |
| 3 | Roadmap SC3 / COMP-04 and SIM-02: official ranking, host, runner-up, Nations League, and topology rules are applied. | VERIFIED | Full Phase 16 focused file passed; Article 15/23, four-host, capacity, fallback, draw-condition, single-leg, and two-leg replay tests passed. |
| 4 | Roadmap SC4 / SIM-04: unresolved, blocked, and insufficient inputs remain explicit and suppress fabricated outputs. | VERIFIED | Full focused suite and targeted null activation, invalid handoff, missing kickoff, unresolved host, and unsupported topology tests passed with empty probability paths. |
| 5 | D-01: complete official status, groups, stable teams, and schedule are required before activation. | VERIFIED | Targeted `activation|status_resource|empty|scheduled|direct_validator` test exited 0; empty `status` is rejected with an explicit status-resource error. |
| 6 | D-02: every pairing has a stable fixture ID and confirmed kickoff before forecast eligibility. | VERIFIED | Activation and simulation tests reject missing or unconfirmed kickoffs; complete active fixtures pass the confirmed-kickoff gate. |
| 7 | D-03: post-draw corrections are new complete bundles validated before replacement. | VERIFIED | Revision identity/hash tests, registry lifecycle tests, and CLI valid-revision continuity test exited 0. |
| 8 | D-04: the incumbent remains visible while an invalid candidate is isolated. | VERIFIED | No-incumbent and incumbent continuity tests exited 0; blocked CLI overlay keeps accepted rows, sets `candidate=NULL`, and emits the refresh-blocked warning. |
| 9 | D-05: host places are explicit conditional slots with covered, occupied, unused, or unresolved states. | VERIFIED | Host-slot and scenario tests passed; `phase16_euro_host_placeholder()` is a substantive typed ledger constructor, not a stub. |
| 10 | D-06: direct host qualification consumes capacity once with no double counting. | VERIFIED | Zero, one, two, and four-host allocation tests passed; exactly two covered hosts consume reserved capacity in the four-host case. |
| 11 | D-07: unresolved host guarantees remain explicit and suppress probabilities. | VERIFIED | `host_place_unresolved suppresses affected qualification eligibility` passed and the simulation returns no probability rows for unresolved host inputs. |
| 12 | D-08: host treatment is visible in the qualification ledger with lineage. | VERIFIED | Allocation and outcomes tests assert host slot, association, consumption, status, source, and ruleset fields in the main ledger contract. |
| 13 | D-09: topology comes from accepted versioned rules/draw conditions and supports every valid format. | VERIFIED | Topology tests pass for 0/1/2 reserved hosts as 8/12/8 entrants with 4/3/2 places; absent or partial draw conditions return both unresolved and unsupported status. |
| 14 | D-10: Phase 15 eligibility is accepted only from a registered interim handoff keyed by stable team ID. | VERIFIED | Targeted simulation/handoff test exited 0; the registered current final-only/blocked artifact is rejected, while valid `ranking_scope` and `ranking_stage` values require `interim_overall`. |
| 15 | D-11: best runners-up are selected after direct/host allocation using Article 23 evidence. | VERIFIED | Article 23 and allocation tests pass with groups-of-five exclusions, counted/excluded match IDs, and post-allocation runner-up ordering. |
| 16 | D-12: topology revisions are versioned, replayable, atomic, and retain the prior accepted version until validation succeeds. | VERIFIED | Targeted injected post-promotion read-back test exited 0 and compared all incumbent artifact bytes; writer code retains backup through read-back and restores it on error. |
| 17 | D-13: pre-draw status, draw date, source confidence, refresh, warnings, and empty sections are available. | VERIFIED | Activation and CLI payload tests assert status, date, refresh, source bundle, `source_confidence`, warning/reason, and typed empties. Dashboard presentation is deferred to Phase 17. |
| 18 | D-14: pre-draw sections are schema-valid and contain no projected teams or placeholder structures. | VERIFIED | Exact durable nine-file validation passed; all structural/projection/probability CSVs are header-only. Host placeholders are conditional post-rule ledger slots, not pre-draw teams or groups. |
| 19 | D-15: no fixture-level or qualification probabilities are published before draw/schedule acceptance. | VERIFIED | Current `team_path_probabilities.csv`, `qualification_ledger.csv`, and `fixture_forecast_form.csv` are zero-row; targeted `activation=NULL` simulation returned `status=suppressed` and zero probability rows. |
| 20 | D-16: visible pre-draw messaging includes awaiting-draw copy, date, refresh, source, and reason. | VERIFIED | Exact heading/body assertions passed; durable manifest warnings include the copy, `expected_draw_date=2026-12-06`, refresh timestamp, source bundle ID, and unavailability reason. |

**Score:** 20/20 truths verified. Behavior-unverified truths: 0.

### Deferred Items

| Item | Addressed In | Evidence |
|---|---|---|
| Final dashboard presentation of source confidence beside the pre-draw summary | Phase 17 | Phase 17 success criterion 3 explicitly owns refresh status, source confidence, model release, warnings, and replayable metadata. |

## Required Artifacts

| Artifact | Status | Evidence |
|---|---|---|
| `R/competition/uefa_euro_rules.R` | VERIFIED | 2,073-line substantive rules/activation module; loaded by Phase 14 and CLI; activation, ranking, host, topology, and status-resource tests pass. |
| `R/competition/uefa_euro_simulation.R` | VERIFIED | 1,425-line seeded simulator; registered Phase 15 adapter, activation gate, calibrated sampling, suppression, and replay paths are exercised. |
| `R/competition/uefa_euro_outcomes.R` | VERIFIED | 850-line exact inventory/validator/reader/writer; staged promotion and read-back rollback are directly tested. |
| `R/competition/state_bundle.R` | VERIFIED | Phase 14 EURO gate is called before active construction and forwarded through the real batch path; authority tests pass. |
| `R/competition/edition_registry.R` and `scripts/acquire_uefa_snapshot.R` | VERIFIED | Date-only, accepted lifecycle, branch, and no-scheduled-without-accepted tests pass. |
| `scripts/build_competition_state.R` | VERIFIED | Fresh-process loader explicitly sources EURO rules before state construction; targeted fresh-process test passes. |
| `scripts/build_euro_qualifying_outcomes.R` and wrapper | VERIFIED | Registered edition-only CLI, dry-run, write boundary, replay, and wrapper tests pass. |
| `tests/testthat/test_phase16_euro_qualifying.R` | VERIFIED | Full focused file exited 0; targeted remediation probes each exited 0. |
| `outputs/competition/uefa_euro_2028_qualifying/outcomes/` | VERIFIED | Exact nine-file inventory, nine valid manifest rows, self-hashes, lineage, and pre-draw zero-row structures validated from disk. |
| `16-BASELINE.md` and `16-baseline-check.R` | VERIFIED AS RECORD | Existing baseline records child exit 1, normalized identities, SHA-256, known signature, and non-green disposition; helper code fails closed on new/unparseable failures. Full repository suite was not rerun. |

## Key Link Verification

| From | To | Via | Status | Evidence |
|---|---|---|---|---|
| Official status resource | `validate_euro_activation()` | non-empty, edition, acceptance, lifecycle, and scheduled-state checks | WIRED | `R/competition/uefa_euro_rules.R:251-287,506-514`; targeted empty-status test passed. |
| Phase 16 activation | Phase 14 state authority | `phase14_state_bundle_euro_activation_gate()` before active branch | WIRED | `R/competition/state_bundle.R:1187-1262,1292-1323`; Phase 14 fresh/pre-draw/active/reason tests passed. |
| Phase 14 batch | EURO gate | per-edition `euro_activation` forwarding into production candidate | WIRED | `R/competition/state_bundle.R:2120-2163`; Phase 14 active-after-draw and blocked-input tests passed. |
| Registered Phase 15 outcomes | EURO simulator | reader/normalizer/validator requiring `interim_overall` and stable IDs | WIRED | `R/competition/uefa_euro_simulation.R:258-505`; targeted registered-handoff test passed and current blocked artifact was rejected. |
| Activation envelope | qualification simulation | `uefa_euro_sim_activation_gate()` before any probability construction | WIRED | `R/competition/uefa_euro_simulation.R:1088-1152,1278-1284`; NULL and unvalidated probes passed with zero rows. |
| Candidate | outcomes writer/reader | exact inventory, staged rename, promoted read-back, retained backup | WIRED | `R/competition/uefa_euro_outcomes.R:795-824`; injected read-back failure restored every incumbent byte. |
| CLI | fresh-process replay | normal/reversed/repeated/fresh artifact byte/hash and lineage fingerprints | WIRED | `scripts/build_euro_qualifying_outcomes.R:988-1047,1112-1126`; CLI replay exited 0 with `replay_verified=TRUE`. |

## Data-Flow Trace

| Artifact | Source | Flow Status | Evidence |
|---|---|---|---|
| Current EURO outcomes | Registered accepted EURO manifest/resources -> CLI loader -> activation envelope -> candidate -> nine-file writer | FLOWING, intentionally empty pre-draw | Durable reader validation passed; manifest contains accepted source/rules/state lineage and zero structural rows. |
| Active EURO state path | Registered edition/resource inputs -> Phase 16 gate -> Phase 14 production candidate/batch -> Phase 14 validator | FLOWING | Targeted Phase 14 fresh, pre-draw, active-after-draw, and blocked-input tests passed. |
| Qualification probabilities | Phase 14 calibrated forecast/score authority + resolved allocation/topology + validated Phase 15 handoff | FLOWING on valid active fixtures; suppressed otherwise | Focused simulation test produced non-empty valid probabilities and confirmed RNG restoration; NULL activation and unresolved prerequisites produced zero rows. |
| Nations League eligibility | Registered Phase 15 `projected_rankings.csv` and manifest -> interim normalizer -> handoff validator | FLOWING FAIL-CLOSED | Current registered final-only/blocked rows yield `unresolved_external_eligibility` with zero projection rows; valid interim fixture passes. |

## Targeted Behavioral Checks

| Check | Result |
|---|---|
| Empty official status resource in scheduled activation | PASS, exit 0, targeted test selected. |
| `uefa_euro_sim_activation_gate(NULL, ...)` and `uefa_euro_simulate_qualification(activation=NULL, ...)` | PASS, exit 0; gate invalid with `activation_missing`, simulation `suppressed`, zero probability rows. |
| Injected post-promotion read-back failure | PASS, exit 0; all incumbent artifact bytes identical after restore. |
| Full focused Phase 16 test file | PASS, exit 0. No full repository suite run. |
| CLI registered dry-run | PASS, exit 0; `validation=TRUE`, `source_validation=TRUE`, `durable_mutation=FALSE`, `forecast_status=pre_draw`. |
| CLI deterministic replay | PASS, exit 0; `replay_verified=TRUE`, exact nine-artifact replay. |
| Durable bundle read-back | PASS, exit 0; exact nine artifacts, nine manifest rows, all valid, zero structural rows. |
| Phase 14 authority and Phase 15 handoff targeted tests | PASS, exit 0 for all selected tests. |
| CLI no-incumbent, incumbent-blocked, and valid-revision continuity tests | PASS, exit 0 for all selected tests. |

## Probe Execution

No `scripts/*/tests/probe-*.sh` probes are present or declared for Phase 16. The three requested remediation probes were run as named testthat selections in fresh R processes and are recorded above.

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| COMP-03 | SATISFIED | Pre-draw output, complete-bundle activation, empty-status rejection, lifecycle persistence, Phase 14 gate, and CLI tests pass. |
| COMP-04 | SATISFIED | Article 15/23 ranking, host allocation, four-host selection, topology/draw-condition validation, versioned lineage, and rollback tests pass. |
| SIM-02 | SATISFIED | Calibrated seeded simulation, Phase 15 interim handoff, all topology branches, suppression, RNG restoration, and replay tests pass. |
| SIM-04 | SATISFIED | Pre-draw, unavailable, unresolved, unsupported, missing-kickoff, missing-handoff, and null-activation states suppress fabricated outputs. |

No Phase 16 requirement is orphaned in `REQUIREMENTS.md`; the four mapped IDs are declared in the phase plans and roadmap.

## Anti-Patterns Found

| File | Pattern | Classification |
|---|---|---|
| `R/competition/uefa_euro_rules.R:1669-1759` | `phase16_euro_host_placeholder()` and placeholder rows | INFO, intentional typed conditional host-capacity slots; not projected teams, groups, fixtures, or probabilities. |
| Phase 16 implementation and test files | No unreferenced `TBD`, `FIXME`, or `XXX` markers; no empty production handlers or static-output stubs found. | PASS |
| Current pre-draw CSVs | Header-only structural artifacts | INFO, intentional schema-valid `pre_draw` control output required by D-14/D-15. |

## Human Verification Required

### First Official Post-Draw Bundle

**Test:** Before accepting the first active output, inspect the manifest, accepted source/rules revisions, raw snapshot metadata, group and fixture identities, confirmed kickoffs, host/Nations League ledger statuses, draw-condition lineage, and blocked reasons against the official UEFA bundle.

**Expected:** The active bundle contains only accepted official groups and fixtures, every pairing has a confirmed kickoff, lineage matches the registered source/rules/model contracts, and no candidate-only or fabricated rows are visible.

**Why human:** The current accepted source is intentionally pre-draw and the first real post-draw external bundle cannot be validated by static code or synthetic fixtures alone.

## Gaps Summary

No blocker gaps remain. The prior verification's three blockers were each reproduced by the remediation tests and now pass. The full repository baseline remains explicitly non-green with the recorded known signature; it was inspected, not rerun, per the verification request.

---

_Verified: 2026-08-24T17:24:55Z_  
_Verifier: the agent (gsd-verifier)_
