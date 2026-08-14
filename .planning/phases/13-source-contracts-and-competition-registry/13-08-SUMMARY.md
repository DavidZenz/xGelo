---
phase: 13-source-contracts-and-competition-registry
plan: "08"
subsystem: historical-data-contracts
tags: [R, martj42, source-contracts, stable-identities, provenance, targets]

# Dependency graph
requires:
  - phase: 13-05
    provides: Phase 13 team identity registry and visible fallback-resolution conventions
  - phase: 13-12
    provides: staged CSV source-contract writing and hash helpers
provides:
  - Explicit non-score martj42 source-match IDs carried through preprocessing
  - Complete 337-row historical identity map and 49,520-row edition lookup
  - Durable hash-validated normalized martj42 historical artifact
  - Targets seam downstream of the existing elo_matches target
affects: [Phase 14, DATA-03, historical preprocessing, competition identity]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Stable source IDs are validated before score fallback or derived Elo fields are added.
    - Unique non-score projections use deterministic IDs; duplicate projections require explicit reviewed contract IDs.
    - Production maps and normalized artifacts are regenerated and compared before staged publication.

key-files:
  created:
    - data/raw/martj42/results_source_contract.csv
    - data/competition/registries/martj42_identity_map.csv
    - data/competition/registries/martj42_edition_lookup.csv
    - data/processed/martj42_historical_normalized.csv
  modified:
    - R/elo/preprocess.R
    - R/competition/team_identity.R
    - _targets.R
    - data/processed/elo_matches.csv
    - data/raw/team_name_map.csv
    - tests/fixtures/phase13/martj42_history_sample.csv
    - tests/testthat/test_phase13_competition_registry.R

key-decisions:
  - "Use the user-selected option 1: introduce an explicit source-contract source_match_id before preprocessing rather than disambiguating the legacy team/date key with scores or row order."
  - "Use SHA-256 of the canonical non-score source projection for 49,518 unique projections and two explicit reviewed IDs for the genuine duplicate Tahiti/New Caledonia projection."
  - "Merge the current Phase 13 registry with the legacy historical map, with current stable IDs taking precedence and explicit aliases for China, Canton Ticino, and Rouet-Provence."
  - "Assign the complete open history through the explicit martj42_historical_v1 edition lookup; edition membership is never inferred from scores, dates, row order, or tournament text."

patterns-established:
  - "Preprocessing identity gate: source_match_id and source_match_id_method must be present, unique, safe, and validated before any score fallback."
  - "Artifact integrity gate: committed map and lookup are regenerated from the complete input and compared before normalized output replacement."

requirements-completed: [DATA-03]

coverage:
  - id: D1
    description: "Preprocessing retains and validates stable non-score source-match IDs, including explicit reviewed IDs for the duplicate historical projection."
    requirement: DATA-03
    verification:
      - kind: unit
        ref: "tests/testthat/test_phase13_competition_registry.R#martj42 preprocessing requires stable non-score source match IDs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Complete martj42 history has a one-to-one identity map, edition lookup, and normalized artifact with stable IDs, provenance, and row hashes."
    requirement: DATA-03
    verification:
      - kind: integration
        ref: "Rscript --vanilla -e 'testthat::test_file(\"tests/testthat/test_phase13_competition_registry.R\")'"
        status: pass
      - kind: other
        ref: "artifact validation: 49,520 rows, 45 columns, unique source_match_id, and all row hashes valid"
        status: pass
    human_judgment: false
  - id: D3
    description: "The targets graph exposes the normalized history as a file target downstream of elo_matches and the production loader."
    verification:
      - kind: integration
        ref: "targets::tar_manifest(script=\"_targets.R\") plus static target/artifact check"
        status: pass
    human_judgment: false

# Metrics
duration: 36m
completed: 2026-08-14
status: complete
---

# Phase 13 Plan 08: Source Contracts and Competition Registry Summary

**Stable non-score martj42 source IDs now flow through preprocessing into a 49,520-row, hash-validated normalized history.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-08-14T19:25:00Z
- **Completed:** 2026-08-14T20:01:00Z
- **Tasks:** 3/3 (Tasks 1 and 2 were already committed before continuation)
- **Files modified:** 11 in the Task 3 commit

## Accomplishments

- Added a source-contract preprocessing gate that carries 49,520 unique source_match_id values: 49,518 deterministic non-score IDs plus two explicit reviewed IDs for the duplicated Tahiti/New Caledonia source projection.
- Generated and validated the complete 337-row identity map, one-to-one 49,520-row edition lookup, and durable normalized historical artifact with source IDs, display names, stable team IDs, explicit edition IDs, provenance, and round-tripping row hashes.
- Wired martj42_historical_normalized_file into _targets.R immediately downstream of elo_matches, with focused regressions for score/reorder safety, duplicate identity handling, production artifacts, and target declaration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the explicit historical result normalization seam** - 35fc869 (feat)
2. **Task 2: Prove future-row and score-only normalization invariants** - 85c02ce (test)
3. **Task 3: Wire martj42 normalization into the production target and durable artifact** - a29a718 (feat)

**Plan metadata:** recorded in the final SDK metadata commit after state and roadmap updates.

## Files Created/Modified

- R/elo/preprocess.R - validates source-contract IDs before preprocessing and carries them into match_id.
- R/competition/team_identity.R - merges historical registry coverage, normalizes source IDs, validates production maps/lookups, and writes the durable artifact.
- _targets.R - adds the downstream martj42_historical_normalized_file file target.
- data/raw/martj42/results_source_contract.csv - full source-contract snapshot with explicit non-score identity metadata.
- data/processed/elo_matches.csv - complete preprocessed history retaining source IDs and legacy IDs for auditability.
- data/competition/registries/martj42_identity_map.csv - complete source-team identity map with provenance and hashes.
- data/competition/registries/martj42_edition_lookup.csv - explicit one-to-one match-to-edition contract.
- data/processed/martj42_historical_normalized.csv - 49,520-row normalized historical output.
- data/raw/team_name_map.csv - three historical aliases needed for complete source-token coverage.
- tests/fixtures/phase13/martj42_history_sample.csv - fixture source IDs and methods.
- tests/testthat/test_phase13_competition_registry.R - preprocessing, production artifact, and target-seam regressions.

## Decisions Made

- The selected checkpoint option makes the source-contract boundary explicit: stable IDs enter before preprocessing, while scores, row order, and score-bearing hashes are excluded from identity generation.
- The current two-team edition registry remains authoritative for its rows; the legacy map supplies historical/non-FIFA entities, and overlapping current aliases/FIFA codes are deduplicated in favor of current stable IDs.
- Every production historical row maps to martj42_historical_v1 only through the committed explicit lookup.

## Deviations from Plan

### User-authorized decision checkpoint

**1. Selected option 1: add an explicit preprocessing source-contract seam**
- **Found during:** Task 3 continuation
- **Issue:** The existing preprocessed output derived duplicate Tahiti_New Caledonia_1974-02-17 IDs for two score-conflicting rows.
- **Fix:** Added source_match_id and source_match_id_method to a full source-contract CSV, validated it before preprocessing, and retained the source ID as the production match_id.
- **Files modified:** R/elo/preprocess.R, data/raw/martj42/results_source_contract.csv, data/processed/elo_matches.csv
- **Verification:** Full source contract has 49,520 unique IDs; the duplicate non-score projection has two explicit reviewed IDs; focused suite passes.
- **Committed in:** a29a718

### Auto-fixed Issues

**2. [Rule 2 - Missing Critical] Added supplemental historical identity coverage**
- **Found during:** Task 3 production map generation
- **Issue:** The current Phase 13 registry covered only the two edition sample teams and the legacy map lacked three source spellings needed by the complete martj42 history.
- **Fix:** Merged the legacy registry with current-ID precedence and added China, Canton Ticino, and Rouet-Provence aliases.
- **Files modified:** R/competition/team_identity.R, data/raw/team_name_map.csv
- **Verification:** All 337 unique historical source team tokens resolve; production map generation and loader pass.
- **Committed in:** a29a718

**3. [Rule 1 - Bug] Made normalized boolean fields hash-stable across CSV round trips**
- **Found during:** Task 3 artifact read-back verification
- **Issue:** In-memory character booleans were re-inferred as logical values on CSV read, causing every persisted row hash to differ on recomputation.
- **Fix:** Emit neutral and is_home as logical values before normalized row hashing.
- **Files modified:** R/competition/team_identity.R, data/processed/martj42_historical_normalized.csv
- **Verification:** All 49,520 persisted row hashes recompute exactly; focused suite passes with 147 expectations.
- **Committed in:** a29a718

**Total deviations:** 3 (1 user-authorized decision, 1 Rule 2 missing-critical addition, 1 Rule 1 bug fix)
**Impact on plan:** The source-contract boundary is the selected resolution for the duplicate identity blocker; all additions are limited to complete historical identity correctness and do not alter forecasting or competition-rule behavior.

## Issues Encountered

None unresolved. Pre-existing unrelated benchmark, debug, fallback-audit, and generated-output changes remain outside the Task 3 commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 14 can consume data/processed/martj42_historical_normalized.csv through the stable source/team/edition contracts. The focused verification and target/artifact checks are complete.

---
*Phase: 13-source-contracts-and-competition-registry*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Summary file exists at the expected phase path.
- Task commits 35fc869, 85c02ce, and a29a718 are present in Git history.
