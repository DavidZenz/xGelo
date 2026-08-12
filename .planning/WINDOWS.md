---
schema_version: 1
open_count: 6
waived_count: 0
fixed_count: 0
total_count: 6
last_updated: 2026-08-12T19:57:11.399Z
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
  }
]
````
