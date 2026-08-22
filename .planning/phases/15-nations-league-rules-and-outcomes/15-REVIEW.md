---
phase: 15-nations-league-rules-and-outcomes
reviewed: 2026-08-22T12:23:55Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - R/competition/uefa_nations_league_rules.R
  - R/competition/uefa_nations_league_adapter.R
  - R/competition/uefa_nations_league_simulation.R
  - R/competition/uefa_nations_league_outcomes.R
  - scripts/build_nations_league_outcomes.R
  - scripts/build_uefa_nations_league_outcomes.R
  - tests/testthat/test_phase15_nations_league.R
  - outputs/competition/uefa_nations_league_2026_27/outcomes/competition_topology.csv
  - outputs/competition/uefa_nations_league_2026_27/outcomes/outcomes_manifest.csv
findings:
  critical: 6
  warning: 3
  info: 0
  total: 9
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-22T12:23:55Z  
**Depth:** standard  
**Files Reviewed:** 9  
**Status:** issues_found

## Summary

The Phase 15 implementation has several correctness and lineage defects despite the focused test file passing. The highest-risk issues are that replay verification does not compare the actual artifact tables, the durable topology reports one team per group, completed-result admission permits canonical fixture identity replacement, and partial C/D eligibility can produce contradictory playoff rows. The state-manifest reader also trusts its stored self-hash instead of recomputing it, weakening the parent-state integrity boundary.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: Replay verification compares missing artifact keys

**Classification:** BLOCKER  
**File:** `scripts/build_nations_league_outcomes.R:366-374`

**Issue:** `phase15_nl_compare_replays()` iterates inventory names such as `outcomes/competition_topology.csv`, removes the `outcomes/` prefix, and then indexes `first_candidate$artifacts[[artifact_name]]`. Candidates are keyed with the prefixed inventory names, so these lookups return `NULL`. `phase15_nl_csv_bytes(NULL)` produces the same empty serialization for both candidates, meaning the advertised nine-file byte/hash replay check does not compare the artifacts at all. The explicit field checks later in the function cannot replace the required complete artifact comparison.

**Fix:** Use the inventory key unchanged:

```r
for (artifact in expected) {
  first_bytes <- phase15_nl_csv_bytes(first_candidate$artifacts[[artifact]])
  second_bytes <- phase15_nl_csv_bytes(second_candidate$artifacts[[artifact]])
  ...
}
```

Add a regression test that changes a non-explicitly-compared column in one artifact and requires replay verification to fail.

#### CR-02: Durable topology records the wrong group cardinality

**Classification:** BLOCKER  
**File:** `R/competition/uefa_nations_league_outcomes.R:585-595`

**Issue:** `groups` is one row per group, but `nrow(group)` is written into `competition_topology.team_count`. The generated durable output therefore reports `team_count = 1` for four-team groups (and also for the three-team League D groups), while the same rows report 12 or 6 fixtures. This is already present in `outputs/competition/uefa_nations_league_2026_27/outcomes/competition_topology.csv:2`, and downstream topology consumers will receive false group cardinalities.

**Fix:** Derive the count from the topology team table, keyed by the same group field, and assert the expected 4/3 cardinalities before writing the row. Do not use the group metadata row count as a team count.

#### CR-03: Completed-result admission can overwrite canonical fixture identity

**Classification:** BLOCKER  
**File:** `R/competition/uefa_nations_league_simulation.R:815-833`

**Issue:** After checking only that a result fixture ID exists in the canonical table, the function copies every overlapping result field into the canonical row. A result with a known fixture ID but different `home_team_id`, `away_team_id`, `group_id`, stage, or other identity fields is accepted and replaces the canonical identity. The function then forces the edition/source status fields, so the resulting simulation can use scores attached to the wrong teams while appearing admitted and lineage-bound.

**Fix:** Define immutable identity fields and compare them to the canonical row before merging. Reject any mismatch, and only merge explicitly admitted score/status/evidence fields. Also validate the result edition and source bundle rather than overwriting them after admission.

#### CR-04: Partial C/D eligibility leaves contradictory playoff outcomes

**Classification:** BLOCKER  
**File:** `R/competition/uefa_nations_league_rules.R:2115-2121`

**Issue:** The C/D cancellation rule is global: if any due participant qualifies for the Euro 2028 playoffs, the C/D playoff is cancelled and the four affected teams are retained. `make_pairs()` can mark only one pair cancelled, while another remains `contested`. The post-processing removes only rows already marked `cd_playoff_status == "cancelled"`, then appends the four retention rows. A mixed eligibility input therefore emits a contested C/D playoff plus suppressed retention rows for the same transition. A direct boundary case with only interim rank 45 qualifying produced exactly this contradictory output.

**Fix:** Resolve the global C/D cancellation once, then remove all `stage_id == "c_d_playoff"` selection rows whenever cancellation is required before appending the four retention rows. Add a test for one qualifying candidate pair and one non-qualifying pair.

#### CR-05: Phase 14 state-manifest self-integrity is trusted, not recomputed

**Classification:** BLOCKER  
**File:** `R/competition/uefa_nations_league_outcomes.R:467-495`

**Issue:** `phase15_nl_read_phase14_state_bundle()` accepts the stored `manifest_sha256` as the expected hash for the manifest itself and checks only that the self row repeats that stored value. It never computes the canonical self-hash from the manifest, despite defining `phase15_nl_state_manifest_seed_hash()` for that purpose. It also does not verify the manifest row hashes. A tampered manifest can therefore preserve its old self-hash fields while changing manifest metadata or row-hash content and still pass this reader, weakening the state parent used by outcomes and replay.

**Fix:** Recompute the canonical manifest seed/self hash with the self fields blanked, compare it to `manifest_sha256`, validate every manifest row hash against the corresponding artifact, and only then use the state bundle as a parent.

#### CR-06: Ranking admission fails open when evidence and status fields are absent

**Classification:** BLOCKER  
**File:** `R/competition/uefa_nations_league_rules.R:943-960`

**Issue:** `uefa_nl_rank_prepare_matches()` defaults missing `counts_for_standings` and missing `match_status` to `TRUE`. It also performs the evidence timestamp and state-cutoff checks only when an evidence column happens to be present. A caller can therefore provide score-bearing rows without Phase 14 completion status or accepted completion evidence and have them count in standings. This bypasses the documented fail-closed data-lineage/cutoff boundary.

**Fix:** Require the status, standings-count, and accepted evidence fields for any row eligible to contribute to standings. Treat absent or invalid fields as blocked input, and require a valid cutoff comparison rather than skipping it when the evidence column is absent.

### Warnings

#### WR-01: Stage-capture registry validation checks only two fields

**Classification:** WARNING  
**File:** `R/competition/uefa_nations_league_adapter.R:794-805`

**Issue:** The reader narrows the registry to the required columns but compares only `manifest_sha256` and `row_sha256` with the companion manifest. Registry fields such as capture/raw paths, status, row count, raw hash, capture hash, and source URL can be changed without rejection. The returned registry row is then exposed as lineage, so the durable registry is not actually bound to the capture it claims to describe.

**Fix:** Validate the registry row's canonical row hash and compare every registry contract field with the manifest and registered paths, or validate the registry as its own signed/canonical artifact before returning it.

#### WR-02: Completed stage-capture timestamps are only checked for presence

**Classification:** WARNING  
**File:** `R/competition/uefa_nations_league_adapter.R:695-700`

**Issue:** Completed rows must have a nonempty `completed_at_utc`, but the value is never parsed or checked as a valid UTC timestamp. An arbitrary string is accepted, hashed, and persisted into the official capture and downstream outcomes, making the completion chronology non-auditable.

**Fix:** Parse `completed_at_utc` with the same timestamp validation used for scheduled/retrieved fields and reject invalid or non-UTC values before calculating row hashes.

#### WR-03: Stage-capture lineage publishes a nonexistent accepted path

**Classification:** WARNING  
**File:** `scripts/build_nations_league_outcomes.R:282-303`

**Issue:** `phase15_nl_stage_capture_lineage()` reads `stage_capture$paths$accepted_relative_path`, but the adapter's registered path is named `capture_relative_path`. The resulting `accepted_path` is `NULL` in the candidate lineage even though the capture is accepted and persisted. This leaves the published lineage contract incomplete and can break consumers that use the advertised accepted-path field.

**Fix:** Use `capture_relative_path` consistently, or rename the field in the path contract and update all readers, writers, and tests together. Assert that every published lineage path is nonempty and points to the registered artifact.

---

_Reviewed: 2026-08-22T12:23:55Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
