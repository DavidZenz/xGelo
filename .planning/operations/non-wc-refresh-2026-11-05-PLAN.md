# Non-WC dashboard reliability and publication repair

Date: 2026-11-05. Authority: the active user goal in this chat.

## Objective and scope

Repair automated refresh and public Nations League, EURO 2028 qualifying and
Champions League dashboards. Operational reliability precedes forecast feature
work. The complete user objective remains active until every requirement below
has direct current-state evidence. WC pages, WC outputs and unrelated local edits
must be preserved. Existing model/source owner approvals remain bound to their
exact inputs; failed model gates must not be weakened after seeing assessments.

## Ordered execution

1. Audit the real launchd job, environment, logs, Git/publication topology and
   executable discovery. Implement configurable, probed Rscript discovery,
   failure status, locking, atomic run records, freshness monitoring, alerts and
   retry/recovery. Test negative paths with independent temporary environments.
2. Restore Nations League source/state/outcomes and synchronized publication.
   Benchmark fixed-seed 1k/10k+ simulations, establish a precision floor from
   convergence evidence, publish Monte Carlo uncertainty and truthful timestamps.
3. Reconcile CL fixtures/results and diagnose the held-back Elo candidate using
   existing chronological diagnostics. Explicitly label/disable inadequate
   predictions. Reuse and verify existing rules/simulation implementation only
   after accepted probabilities and source/rules evidence pass QA.
4. Stage all non-WC routes together, preserve the EURO pre-draw readiness gate,
   verify desktop/mobile, validate manifests/probabilities/lifecycle, then deploy
   and read back public navigation/assets/status. Failed runs preserve valid
   incumbent pages. Publishing is authorized by the active user goal.
5. Complete a manual end-to-end run and a real scheduler-dispatched run; collect
   logs, source/generated dates, model diagnostics, precision benchmarks, URL
   checks and WC byte-preservation evidence. Audit all acceptance requirements.

## Requirement/evidence ledger

| ID | Required final behavior | Evidence required | State |
|---|---|---|---|
| OPS-01 / user 1 | Configurable Rscript with safe discovery and diagnostics | Runtime tests; real minimal launchd environment | Pending |
| OPS-02 / user 2 | Manual and real scheduled end-to-end runs; idempotent atomic publication | Run records/logs; failure injection; public byte inventories | Pending |
| OPS-03 / user 3 | Last success/source date/errors/freshness, failed/stale alerts and recovery | Durable status, observable alert, documented retry | Pending |
| NL-01 / user 4 | Fresh synchronized facts/forecasts/outlooks and truthful timestamps | Accepted source; state/outcome/payload lineage; public read-back | Pending |
| NL-02 / user 5 | Configurable production simulations backed by convergence/precision | Fixed-seed 1k/10k+ benchmarks and Monte Carlo interval output | Pending |
| NL-03 / user 6 | Independent probability/standings/outcome checks; no reliable-looking demo projections | Focused tests and publication precision gate | Pending |
| CL-01 / user 7 | Defensible differentiated probabilities or explicit inadequate-forecast status | Chronological Brier/log-loss/calibration evidence and UI | Pending |
| CL-02 / user 8 | No past kickoff remains upcoming; results reconciled | Fresh accepted results, timezone/lifecycle tests and UI | Pending |
| CL-03 / user 9 | QA-gated qualification/winner simulations, rules/ties/probability/uncertainty checks | Genuine accepted parents; independent simulation checks; truthful absence if unfinished | Pending |
| CL-04 / user 10 | Validated public CL route and navigation/assets | Published HTTP checks; desktop/mobile screenshots | Pending |
| EURO-01 / user 11 | Truthful pre-draw placeholder; strict official structure/fixture activation gate | Readiness tests and published placeholder | Pending |
| QA-01 | All named regression/integration concerns and local/public UI verification | Test reports, run logs, screenshots and URL results | Pending |
| SCOPE-01 | Preserve WC and unrelated work; document deployment/monitoring/fallbacks | Before/after byte inventory and Git scope audit | Pending |

## Parallel ownership

- Parent: runtime/discovery, coordinator/scheduler/monitoring, source acquisition,
  deployment, real manual/scheduled execution, evidence ledger and integration.
- NL worker: simulation precision/convergence and associated NL model/UI tests;
  benchmark tools. No updater, source acquisition or public file mutations.
- CL lifecycle worker: current-fixture presentation, safe CL/EURO route materialization
  and readiness, associated tests. No shared operational shell scripts or core model
  release mutations.
- CL diagnostics worker: inspect/model diagnostics and existing tournament authority
  requirements; preserve frozen evaluation membership/gates and accepted releases.

Workers must read this plan and relevant files before edits, preserve others'
changes, and report exact checks and remaining requirements. Never treat fixture
data, plan summaries or status flags as proof of production acceptance.
