---
schema_version: 1
open_count: 13
waived_count: 0
fixed_count: 0
total_count: 13
last_updated: 2026-08-16T17:44:31.640Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 12 | stub | tests/testthat/test_phase12_calibration.R |  | Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs | open |  | 2026-08-11T08:21:16.018Z |  |
| 2 | 12 | stub | tests/testthat/test_phase12_freeze.R |  | Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs | open |  | 2026-08-11T08:21:16.171Z |  |
| 3 | 12 | stub | tests/testthat/test_phase12_final_evaluation.R |  | Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs | open |  | 2026-08-11T08:21:16.344Z |  |
| 4 | 12 | stub | tests/testthat/test_phase12_promotion.R |  | Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs | open |  | 2026-08-11T08:21:16.516Z |  |
| 5 | 12 | stub | tests/testthat/test_phase12_release.R |  | Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs | open |  | 2026-08-11T08:21:16.688Z |  |
| 6 | 12 | deviation | R/visualization/worldcup_dashboard.R | 1053 | Removed an accidentally misplaced raw-argument guard from make_knockout_route_estimator; retained the guard at the exported dashboard boundary. | open |  | 2026-08-12T19:57:11.399Z |  |
| 7 | 12 | deviation | R/release/release_bundle.R | 304 | Established probability_view=derived_1x2 calibrator identity is normalized to calibrated_1x2. | open |  | 2026-08-13T08:12:48.019Z |  |
| 8 | 12 | deviation | R/visualization/worldcup_dashboard.R | 396 | Raw forecast control arguments are stripped before simulate_fixture forwarding. | open |  | 2026-08-13T08:13:04.168Z |  |
| 9 | 14 | skipped-test | tests/testthat/test_phase14_match_state.R | 132 | Canonical match API assertions await phase14_build_canonical_matches in Plan 14-13 | open |  | 2026-08-16T17:44:30.816Z |  |
| 10 | 14 | skipped-test | tests/testthat/test_phase14_standings.R | 162 | Standings reducer assertions await phase14_compute_standings in Plan 14-14 | open |  | 2026-08-16T17:44:31.025Z |  |
| 11 | 14 | skipped-test | tests/testthat/test_phase14_form.R | 161 | Display-form assertions await phase14_build_display_form in Plan 14-15 | open |  | 2026-08-16T17:44:31.228Z |  |
| 12 | 14 | skipped-test | tests/testthat/test_phase14_form.R | 184 | Model-form assertions await phase14_build_model_form in Plan 14-15 | open |  | 2026-08-16T17:44:31.435Z |  |
| 13 | 14 | skipped-test | tests/testthat/test_phase14_cutoffs.R | 122 | Cutoff-validator assertions await phase14_assert_form_cutoffs in Plan 14-15 | open |  | 2026-08-16T17:44:31.640Z |  |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "12",
    "file": "tests/testthat/test_phase12_calibration.R",
    "line": null,
    "description": "Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T08:21:16.018Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "stub",
    "phase": "12",
    "file": "tests/testthat/test_phase12_freeze.R",
    "line": null,
    "description": "Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T08:21:16.171Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "stub",
    "phase": "12",
    "file": "tests/testthat/test_phase12_final_evaluation.R",
    "line": null,
    "description": "Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T08:21:16.344Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "stub",
    "phase": "12",
    "file": "tests/testthat/test_phase12_promotion.R",
    "line": null,
    "description": "Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T08:21:16.516Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "stub",
    "phase": "12",
    "file": "tests/testthat/test_phase12_release.R",
    "line": null,
    "description": "Intentional Wave 0 RED contract scaffold awaits its downstream Phase 12 production APIs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-11T08:21:16.688Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "12",
    "file": "R/visualization/worldcup_dashboard.R",
    "line": 1053,
    "description": "Removed an accidentally misplaced raw-argument guard from make_knockout_route_estimator; retained the guard at the exported dashboard boundary.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T19:57:11.399Z",
    "resolved_at": null
  },
  {
    "id": 7,
    "kind": "deviation",
    "phase": "12",
    "file": "R/release/release_bundle.R",
    "line": 304,
    "description": "Established probability_view=derived_1x2 calibrator identity is normalized to calibrated_1x2.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-13T08:12:48.019Z",
    "resolved_at": null
  },
  {
    "id": 8,
    "kind": "deviation",
    "phase": "12",
    "file": "R/visualization/worldcup_dashboard.R",
    "line": 396,
    "description": "Raw forecast control arguments are stripped before simulate_fixture forwarding.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-13T08:13:04.168Z",
    "resolved_at": null
  },
  {
    "id": 9,
    "kind": "skipped-test",
    "phase": "14",
    "file": "tests/testthat/test_phase14_match_state.R",
    "line": 132,
    "description": "Canonical match API assertions await phase14_build_canonical_matches in Plan 14-13",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T17:44:30.816Z",
    "resolved_at": null
  },
  {
    "id": 10,
    "kind": "skipped-test",
    "phase": "14",
    "file": "tests/testthat/test_phase14_standings.R",
    "line": 162,
    "description": "Standings reducer assertions await phase14_compute_standings in Plan 14-14",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T17:44:31.025Z",
    "resolved_at": null
  },
  {
    "id": 11,
    "kind": "skipped-test",
    "phase": "14",
    "file": "tests/testthat/test_phase14_form.R",
    "line": 161,
    "description": "Display-form assertions await phase14_build_display_form in Plan 14-15",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T17:44:31.228Z",
    "resolved_at": null
  },
  {
    "id": 12,
    "kind": "skipped-test",
    "phase": "14",
    "file": "tests/testthat/test_phase14_form.R",
    "line": 184,
    "description": "Model-form assertions await phase14_build_model_form in Plan 14-15",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T17:44:31.435Z",
    "resolved_at": null
  },
  {
    "id": 13,
    "kind": "skipped-test",
    "phase": "14",
    "file": "tests/testthat/test_phase14_cutoffs.R",
    "line": 122,
    "description": "Cutoff-validator assertions await phase14_assert_form_cutoffs in Plan 14-15",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-16T17:44:31.640Z",
    "resolved_at": null
  }
]
````
