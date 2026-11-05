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

## Current evidence, 5 November

- Source/calibration foundation committed as `edbd9e9`. The v3 consumed-field
  provider contract accepted a genuine fresh probe and source: 36 clubs,
  72 completed and 72 future fixtures. Past forecasts are suppressed locally.
  Team-strength forecasts remain explicitly disabled. The corrected full
  production model evaluation is still running; no promotion is inferred.
- Runtime discovery found R4.6.2 at `/opt/homebrew/opt/r/bin/Rscript` in the
  minimal environment. The former `/opt/homebrew/bin/Rscript` path is missing.
- Operational independent tests: 34 passed. NL precision/integration:54 passed.
  NL lifecycle:17; readiness/authority:42; NL revision:197 passed. Updated legacy
  dashboard suite:213 passed, no warnings, after replacing obsolete wrapper-text
  assertions with the independent current controller/scheduler failure cases.
- Actual old-parent production1k benchmark:305.119 seconds, four workers,
  966 resolved numeric events, zero unavailable. The old-parent10k attempt was
  deliberately stopped to avoid duplication. It is not a completed10k result.
- Full fresh manual local refresh started as `20261105T192030Z-054ac634`;
  source/state/1k+10k/validation/install are one private transaction. Its log is
  `logs/competition-refresh/runs/20261105T192030Z-054ac634.log`. Publication is
  deferred for QA; this is not yet an end-to-end success or public deployment.
- Existing daily100-simulation app heartbeat was updated using the app tool:
  `refresh-uefa-nations-league-dashboard`, now **Monitor non-WC dashboards**,
  hourly, retaining its original chat and `failed_runs_only` preference. It
  inspects health and never refreshes/publishes. Production launchd still needs
  installation and a real successful calendar occurrence after manual QA.
- Public HTTP check today: NL200, EURO200, CL404. NL public metadata still
  shows8October and100simulations; EURO is pre-draw. No repaired public batch
  has been pushed yet. All34 protected artifact hashes remain unchanged.

Concrete follow-through: complete the manual run; inspect its1k/10k evidence
and all three local views; push and verify all14HTTP hashes plus desktop/mobile;
install/observe the real calendar run, restore ordinary03:00 scheduling, and
audit the complete requirement ledger. One monitoring correction is queued
after the current runtime-code CAS run: sandbox `PermissionError` on kill(pid,0)
must report a process-observation gap rather than incorrectly call a live
controller absent. Escalated observation confirms the current controller is
alive and owns its lock. Do not edit runtime code during the long manual run.

19:46UTC update: the genuine CL evaluation completed and installed retained
venue release `club-v2-626fedd0dd54b8309923855e`; candidate Elo passes23/24 gates,
with calibrationdelta0.0261580183 against0.01. Before/after metrics and exact
evidence are in `cl-model-evaluation-2026-11-05.md` and the diagnostics JSON.
All seven release artifacts pass independent byte-count/SHA checks. Cold
production R resolution completed with exit0 (session75975), returning the
exact selected club release. Direct RDS inspection verified probability views.

The fresh1k NL run took296.772seconds and passed all probability/rank/knockout
mass/nesting audits,966resolved probabilities and0unavailable. Its10k run is
live in controller97123; no10k completion or public success is claimed.

Post-freeze patches are prepared and separately tested for truthful PID
observation gaps, installed-vs-candidate state-hash logging, and immutable Git
commit-byte verification/pinned pushes. The publisher proof also exercises
actual local bare-Git rejection, dirty operator preservation and process death
after both early and final directory exchanges. These private candidates must
be applied and their final production tests rerun after97123's install CAS.
Private CL9 work continues on real future-matchup/neutral/ET/penalty support;
the existing integration alone is not completion of that requirement.
