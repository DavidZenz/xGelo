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
| OPS-01 / user 1 | Configurable Rscript with safe discovery and diagnostics | Runtime tests; real minimal launchd environment | Verified in actual calendar sources/state: system Python3.9, resolved R4.6.2 |
| OPS-02 / user 2 | Manual and real scheduled end-to-end runs; idempotent atomic publication | Run records/logs; failure injection; public byte inventories | Manual and original real calendar publication passed; corrected NL-input run and scheduled verification remain |
| OPS-03 / user 3 | Last success/source date/errors/freshness, failed/stale alerts and recovery | Durable status, observable alert, documented retry | Status/runbook and actual automatic failure+recovery reports verified |
| NL-01 / user 4 | Fresh synchronized facts/forecasts/outlooks and truthful timestamps | Accepted source; state/outcome/payload lineage; public read-back | Local Elo replay, state/generation repair and strict publication checks installed/tested; genuine corrected full refresh pending |
| NL-02 / user 5 | Configurable production simulations backed by convergence/precision | Fixed-seed 1k/10k+ benchmarks and Monte Carlo interval output | Two genuine10k runs; public10000 with visible0.98pp95%pointwise sampling disclosure |
| NL-03 / user 6 | Independent probability/standings/outcome checks; no reliable-looking demo projections | Focused tests and publication precision gate | Independent966events/rank/KO/Wilson checks plus432current standings statistics and52future 1X2 rows passed; internal state readiness discrepancy still open |
| CL-01 / user 7 | Defensible differentiated probabilities or explicit inadequate-forecast status | Chronological Brier/log-loss/calibration evidence and UI | Diagnosed; public predictions explicitly disabled; deterministic core repair awaits exact review |
| CL-02 / user 8 | No past kickoff remains upcoming; results reconciled | Fresh accepted results, timezone/lifecycle tests and UI | Public36clubs/72results/72future; no expired upcoming or unconfirmed kickoff rows |
| CL-03 / user 9 | QA-gated qualification/winner simulations, rules/ties/probability/uncertainty checks | Genuine accepted parents; independent simulation checks; truthful absence if unfinished | Pending |
| CL-04 / user 10 | Validated public CL route and navigation/assets | Published HTTP checks; desktop/mobile screenshots | Public200; both viewports, navigation, assets and console passed |
| EURO-01 / user 11 | Truthful pre-draw placeholder; strict official structure/fixture activation gate | Readiness tests and published placeholder | Gate and public empty pre-draw page verified; actual old source timestamp retained |
| QA-01 | All named regression/integration concerns and local/public UI verification | Test reports, run logs, screenshots and URL results | Original calendar success and12new browser views verified; installed correction checks passed; new-input public verification pending |
| SCOPE-01 | Preserve WC and unrelated work; document deployment/monitoring/fallbacks | Before/after byte inventory and Git scope audit |34protected local files, WC public HTML and plist unchanged after calendar run and code installation; recheck next release |

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

20:48UTC update: the first full refresh completed its genuine10k simulation
and all966 event audits, then failed safely at cold dashboard startup. Its
private candidate was removed by the former cleanup; the preserved benchmark
summaries are not an installed outcome bundle. Runtime dependencies, failed
workspace retention, and exact-input resume/restage modes are now committed
and covered by69 passing operational tests. The durable actual benchmark is
`outputs/benchmarks/non-wc-refresh-2026-11-05/README.md`:1k296.772seconds,
10k2629.273seconds, worst95% pointwise sampling half-width0.9798pp. Explicit
PID observation gaps and immutable commit-byte/pinned-push checks are applied.

The replacement complete manual run is `20261105T204227Z-89565434`, started
20:42:27UTC. Both live sources and NL state have exited0; the1k/10k outcomes
stage is running. Its private workspace is retained on pre-install failure.
The main code and managed data/output roots remain frozen through install CAS.
No new public batch, successful complete run or successful scheduled run is
claimed. Browser HTTPS checks at20:46UTC still show NL200/8October/100draws,
EURO200/pre-draw and CL404. A separate temporary copy runs the six older CL
rules/state/simulation/CLI regression suites without changing accepted inputs.

CL9 dynamic future matchups, projected final standings, neutral/ET/penalty
mechanics and independent mass/replay checks are committed as `bcaafa0`.
The exact consolidated policy review remains pending; current venue-only
release and missing genuine knockout draw authority keep tournament outputs
disabled. The full production writer and observed-knockout integration remain
unverified. This implementation does not complete CL-03 or authorize weaker
model gates. The corrected evaluation and source/history approvals above are
unchanged.

21:01UTC update: the replacement run's1k comparison completed in371.122seconds,
966resolved events and0unavailable, with four workers. Its10k simulation is
running; actual controller/worker process inspection confirms active computation.
This timing includes simultaneous independent CL tests and is not substituted
for the earlier isolated benchmark. No production outcome or deployment is
claimed yet.

The six older CL regression files completed in a separate snapshot. Five files
(31cases) passed without failures, errors, warnings or skips. The63-case main
file had two assertions fail in one case because it assumed the actual project
still had no accepted history. That specific missing-history case now supplies
its explicit existing resolver-error seam; all10assertions passed in a fresh
focused run with protected bytes unchanged. A fresh complete main-file rerun
after the correction remains separate from this focused evidence. Original
and corrected reports are under `logs/competition-refresh/cl-regression-*` and
`cl-missing-history-isolation.log`.

The separate genuine isolated CL resolver trace found a runtime defect rather
than an invalid protocol JSON: native R4.6.2 `iconv` occasionally produces a
different normalized value for an identical reviewed accented Czech club name,
causing the accepted-history identity semantic audit to fail. A deterministic
repair is being evaluated privately against every accepted alias/review key;
no accepted identity/history/fold hash, core model code or gate has been changed.
The immutable release code identity includes `R/club/identity.R`, so a core fix
cannot be hidden behind a process-only override or reuse a stale model release.

EURO's advertised future draw date was rechecked against current official UEFA
material; see `euro-draw-readiness-2026-11-05.md`. No source timestamp or accepted
group/fixture generation was changed. The hourly app health monitor is verified
ACTIVE, with its prior failed-runs-only notification preference and read-only
scope preserved. Configuration is not proof of notification delivery or a
successful launchd refresh.

21:09UTC update: the app's actual completed monitoring turn was inspected via
the first-party compact thread snapshot. It correctly reported the first
refresh's `dashboard_stage` failure, the exact missing-path error, absence of a
verified public success and an actionable runbook retry. The observed turn/message
identity is in `health-monitor-observation-2026-11-05.json`. This proves the
automatic in-chat health report; OS push-notification delivery is not asserted.

The new independent Python audit of the current1k files passed all966 event
counts/probabilities,966Wilson interval rows,54team rank-mass and54group/position
rank-mass checks; maximum numeric disagreement5.56e-16. The current1k event and
interval CSV bytes exactly match the first run's retained numeric files, despite
the distinct source captures/cutoffs. This is a numeric-output comparison, not
an assertion of identical parents or successful publication. Evidence:
`logs/competition-refresh/nl-1000-independent-current.json` and
`nl-1000-paired-current.json`; inspectable calculation:
`audit_nl_precision.py`. The1000 count remains preview-only.

Before-release HTTPS hashes/statuses are saved in
`logs/competition-refresh/public-before-release.json`. The public WC HTML hash
matches the protected local WC HTML hash; this read-only baseline will be
compared after the non-WC deployment. Current public states remain NL200,
EURO200 and CL404; nothing new has been deployed.

21:11UTC update: the actual non-WC LaunchAgent was installed/reloaded successfully
for03:00 local time, using the same repaired controller with `--scheduled`,
10000simulations and four workers. Runtime probe selected the actual R4.6.2
executable at `/opt/homebrew/opt/r/bin/Rscript`. Direct `launchctl print`
confirms the new definition is loaded and has zero runs. The existing manual
refresh is separate and continues unchanged. A loaded definition is not a
successful scheduled-run claim. After manual release QA, add the near-term
calendar occurrence, verify its complete run/read-back and restore this ordinary
calendar definition. Disk and loaded-definition evidence:
`logs/competition-refresh/scheduler-installed.json`.

The separate WC LaunchAgent's SHA remains exactly
`cfc5436ed4f07ac09da2014f9b8625785fa09b3c64d673cac3f18098d842e8e5`.

22:59UTC acceptance audit: the current public/manual14-file batch and actual
calendar-run progress are consolidated in `non-wc-release-acceptance-2026-11-05.md`.
This supersedes the earlier historical observations of CL404 and no deployment.
The real calendar job remains live; its1k comparison completed257.066seconds
and its four10k workers are computing. No scheduled success is inferred yet.

The final independent artifact inspection found an additional NL readiness
discrepancy. The durable state flags all11 artifacts invalid because104 completed
matches legitimately suppress forecasts; its failure reason incorrectly chooses
`none` from an available row. Durable factual/form tables are empty, whereas the
dashboard recomputes actual standings from accepted results. Generation fields
inherit June/blank dates, and the legacy payload invents25August as projection
generation. All52 forecasts still cite19July as latest Elo evidence. These
issues are being traced and repaired in isolation; the live main transaction
remains frozen. Full NL-01 acceptance is reopened, rather than treating current
structural validators as sufficient proof. Do not alter global/WC Elo or releases.

The new independent Python factual audit passed104 actual results,52 unique
future forecast rows,432current standings statistics across54teams/14groups,
rank permutations, accepted release identifiers, strict prior evidence and
both raw/calibrated1X2 probability sums (maximum error1.9984e-15). It explicitly
does not certify predictor freshness, model quality, tie ordering or production
authority. Tool: `audit_nl_factual_forecasts.py`; evidence:
`logs/competition-refresh/nl-factual-forecast-manual-independent.json`.

6November00:29UTC: original actual calendar run succeeded and published commit
4a5cea993b63…; all14 HTTPS bytes, Pages, launchd exit0 and12 new desktop/mobile
views verified. Ordinary03:00 Vienna calendar restored;34 protected files and WC
public/plist bytes unchanged. The audited NL repair and CL current-roster scope
fix are installed in commits9948648/29eb45e. Installed121 R assertions and87 actual
Python3.9 operational tests pass. Read-only CL replacement preflight remains valid;
owner answer remains pending. Next: genuine corrected source/state/1k+10k/outcomes,
local QA, public release and another real scheduled run. Old numerical outcomes
cannot be rebound to new local Elo input hashes. Full goal remains active.

2026-11-06T01:20:21Z corrected-input followthrough: genuine run20261106T002720Z-43260883
completed fresh accepted sources, valid state and1k/10k simulations in243.194/
2115.445seconds. All966events resolved; independent rank/stage/count/Wilson
checks pass. Worst95%pointwise half-width0.979794pp; nested1k→10k maximum
change4.33pp, mean0.4354pp, p951.9575pp (descriptive, no model/simultaneous
convergence bound). Compared to the old genuine10k,486events changed, max10.12pp.
The valid10-artifact outcomes stage completed. Staging then failed safely because
nl_elo_validate_projection incorrectly required a state_manifest_sha256 column
in the durable outcome manifest, whose real schema uses aligned parent links.
Public/accepted main data was preserved and the full workspace retained.
The repair checks all seven actual state-dependent artifact edges, simulation
state hash, source and true clocks; tests now use the actual10-row schema and
blank-cell readback. A direct read-only check of the real retained outcome
bundle passes. Resume that exact failed run through the guarded controller;
do not change probabilities or rerun/rebind the simulation.
