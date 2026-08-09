---
status: diagnosed
trigger: "Find the root cause of UAT gap G-11-22: the Phase 11 durable bundle marks phase11_structural_sparse_prior_open inactive with reason \"Structural prior snapshot is missing team ISO3: POR\" even though the committed OWID/Maddison snapshot contains POR and PRK. Diagnose only; do not edit production code, commit, restart targets, or run the long benchmark."
created: 2026-08-09T00:00:00+02:00
updated: 2026-08-09T22:42:00+02:00
---

## Current Focus

bug_class: bohrbug
hypothesis: "The structural candidate is correctly failing closed for historical folds because the single registered snapshot was published on 2024-07-15, but compute_structural_prior_signal() reports the resulting post-publication exclusion as a missing ISO3 membership error."
test: "Run the structural signal directly for POR at the manifest cutoff 2026-06-05 and for a historical cutoff before 2024-07-15; compare filtered row availability and exact errors."
expecting: "The source contains POR, POR resolves at 2026-06-05, and a historical cutoff before 2024-07-15 fails with the current generic missing-ISO3 message."
next_action: "Return the confirmed root-cause report; no further repository action is required in diagnose-only mode."

reasoning_checkpoint:
  hypothesis: "The single registered structural snapshot is published 2024-07-15, so all historical Phase 11 fold cutoffs before that date have no admissible structural rows; the signal function then misclassifies the filtered-empty result as missing POR."
  confirming_evidence:
    - "Direct load at cutoff 2026-06-05 returns 144 rows/72 ISO3 teams, including two POR and two PRK rows."
    - "Direct compute succeeds for POR/PRK at 2026-06-05 and 2024-07-16, but fails at 2024-06-13 with exactly 'Structural prior snapshot is missing team ISO3: POR'."
    - "The 12 durable structural model-manifest cutoffs are all earlier than 2024-07-15."
  falsification_test: "A historical cutoff before 2024-07-15 would return an eligible POR row, or the raw snapshot would lack POR, would disprove this mechanism; neither occurs."
  fix_rationale: "Keep the temporal filter and candidate-local no-score result, but classify raw-team absence separately from a team whose rows are present only after the cutoff; provide a temporally valid historical snapshot or exclude the current-only vintage from historical scoring."
  blind_spots: "No long benchmark or fresh-process full bundle rebuild was run; the diagnosis relies on direct signal reproduction and existing durable parent hashes."
  candidate_causes:
    - "data: the only registered OWID/Maddison snapshot has source_date 2024-07-15, after every historical structural fold cutoff"
    - "code: compute_structural_prior_signal() checks team presence only after temporal filtering and emits the same message for empty eligible rows"
    - "config/contract: the manifest is validated against the current 2026-06-05 cutoff, while historical boundary eligibility is deferred until per-boundary execution"
  and_gate: "Yes for the reported misleading missing-POR reason (post-publication data plus undifferentiated error handling); no for inactive/no-score itself, which follows correctly from the post-publication data alone."

## Symptoms

expected: "The durable bundle should classify phase11_structural_sparse_prior_open consistently with the committed OWID/Maddison snapshot and the requested cutoff; POR should not be reported as missing when it is present in the source."
actual: "The Phase 11 durable bundle marks phase11_structural_sparse_prior_open inactive with reason \"Structural prior snapshot is missing team ISO3: POR\". The current committed snapshot loads successfully with 72 teams/144 rows including POR and PRK; compute_structural_prior_signal() succeeds at cutoff 2026-06-05 but fails for historical cutoffs because source_date is 2024."
errors: "Structural prior snapshot is missing team ISO3: POR"
reproduction: "Inspect the Phase 11 durable bundle evidence and call the structural-prior computation against the committed snapshot at cutoff 2026-06-05 and historical cutoffs before the snapshot publication date."
started: "Reported as UAT gap G-11-22 in Phase 11 verification."

## Eliminated

- hypothesis: "POR is absent from the committed structural snapshot or cannot be loaded because of a checksum/metadata problem."
  evidence: "The snapshot has 144 rows across 72 ISO3 keys, includes POR (rows 104-105) and PRK (rows 106-107), and the manifest/checksum chain resolves to the current OWID vintage."
  timestamp: 2026-08-09T15:04:00+02:00

## Evidence

- timestamp: 2026-08-09T22:41:12+02:00
  checked: "Phase-0 debug knowledge lookup"
  found: "No .planning/debug/knowledge-base.md exists, and no MemPalace tool is available."
  implication: "There is no prior-session pattern to use as a hypothesis candidate; continue from direct repository evidence."

- timestamp: 2026-08-09T22:41:12+02:00
  checked: "UAT, state, structural source, manifest, adapter, and durable evidence lineage"
  found: "UAT G-11-22 says the bundle is inactive; the source/manifest use vintage owid_maddison2023_wpp2024_2000_v1 with source_date 2024-07-15; the current worktree bundle parents that manifest hash and reports POR."
  implication: "The current inactive artifact is not explained by a missing POR row. The remaining leading cause is strict point-in-time filtering at historical cutoffs, with an error taxonomy gap."

- timestamp: 2026-08-09T15:04:00+02:00
  checked: "R/forecast/structural_prior.R lines 247-249 and 304-310"
  found: "The loader rejects source information at/after its requested cutoff; the signal function independently retains only rows with source_date < cutoff and source_year < cutoff year, then line 308 raises missing team ISO3 when no filtered rows remain."
  implication: "A snapshot published after a historical fold is intentionally unavailable even when its ISO3 exists; the current error text conflates temporal ineligibility with structural absence."

- timestamp: 2026-08-09T15:04:00+02:00
  checked: "R/benchmark/hybrid_adapters.R lines 313-332, 1337-1357, and 486-518"
  found: "The adapter validates the source once at the 2026-06-05 manifest cutoff, then re-runs team signal per historical boundary; any error is converted to candidate-local inactive/no-score evidence with the raw condition message in both inactive_reason and error_reason."
  implication: "Fail-closed candidate isolation is deliberate and correct, but the durable reason inherits the low-level misleading classification."

- timestamp: 2026-08-09T22:41:12+02:00
  checked: "Bounded direct R reproduction of load_structural_prior_snapshots() and compute_structural_prior_signal()"
  found: "Loaded rows=144, teams=72, POR=2, PRK=2, source_date=2024-07-15; cutoff 2026-06-05 returned both teams; cutoff 2024-06-13 raised the reported POR error; cutoff 2024-07-16 and 2025-01-01 returned both teams."
  implication: "The failure boundary is publication-date eligibility, not ISO3 mapping or checksum loading."

- timestamp: 2026-08-09T22:41:12+02:00
  checked: "Durable structural model manifests and parent inputs"
  found: "There are 12 structural manifest rows with cutoffs 2002-05-31 through 2024-06-14, all before 2024-07-15; current worktree parent_inputs and candidate/model evidence carry the current OWID manifest hash 7a7f87... and source hashes."
  implication: "The current regenerated inactive artifact is parent-consistent; the POR wording is not a stale missing-row proof. HEAD still retains the older WDI/PRK artifact, which is an uncommitted artifact-lineage difference but not the mechanism of the current POR message."

- timestamp: 2026-08-09T22:41:12+02:00
  checked: "Phase 1.25 SBFL applicability and common bug-pattern checklist"
  found: "No per-test coverage spectrum with a failing and passing test was available for this UAT artifact; SBFL was skipped. The matching pattern is a data-shape/contract classification error after a temporal filter, not null access, async, or concurrency."
  implication: "Direct deterministic reproduction is the appropriate route; no coverage ranking is needed."

## Resolution

root_cause: "Two contributing causes: (1) data/provenance — the only registered OWID/Maddison snapshot has source_date 2024-07-15, while all 12 historical Phase 11 structural fold cutoffs are earlier, so no structural row is admissible for those folds; (2) code — compute_structural_prior_signal() applies the temporal filter before checking raw team membership and line 308 reports the empty eligible set as 'missing team ISO3: POR'. The adapter propagates that message into durable inactive evidence."
fix: "No fix applied in diagnose-only mode. Direction: retain fail-closed temporal eligibility; supply a snapshot/vintage with publication evidence before the relevant historical cutoffs or make this vintage current-only; and distinguish post-publication evidence from a genuinely absent ISO3 in the signal/adapter reason, ideally with source_date and cutoff. Add a preflight/aggregate reason for historical coverage so the candidate does not appear to fail on an arbitrary first team."
verification: "Confirmed by read-only source/manifest/hash inspection and bounded direct R calls: 144 rows/72 teams loaded; POR and PRK present; compute succeeds at 2026-06-05 and 2024-07-16, fails at 2024-06-13 with the reported message; all 12 durable structural cutoffs precede 2024-07-15. No production code, benchmark, or existing planning file was edited."
files_changed: []
