# Non-WC dashboard refresh and recovery

This controller manages Nations League, EURO 2028 qualifying and Champions
League only. It never runs a World Cup update or stages WC files for Git.
The repair evidence and remaining acceptance work are tracked in
`.planning/operations/non-wc-refresh-2026-11-05-PLAN.md`.

## Runtime and credentials

Run commands from the project root. `XGELO_RSCRIPT` may contain an executable
path, including spaces, or a command on PATH. Invalid explicit configuration
fails with a diagnostic. Otherwise the controller probes PATH and standard R
and Homebrew installations with `--version`. It does not dump the environment.
`XGELO_PYTHON` can select the wrapper's Python executable.

```bash
bash scripts/auto_update_competition_dashboards.sh --dry-run
```

The football-data.org key stays in the ignored local `.Renviron` or process
environment. The private CL acquisition child reads that configuration; the
file is not copied into staging, logged, committed or published. Existing
provider, identity, model and owner approvals remain mandatory. A provider
failure cannot authorize a substitute source or model.

## Refresh and publication

```bash
# Complete refresh and public deployment, with independent HTTP read-back.
bash scripts/auto_update_competition_dashboards.sh

# Complete local production refresh, with public push deferred for inspection.
bash scripts/auto_update_competition_dashboards.sh --skip-push

# Retry the exact validated installed batch after a push/deployment failure.
bash scripts/auto_update_competition_dashboards.sh --publish-only

# Re-render accepted production outputs after a presentation correction.
bash scripts/auto_update_competition_dashboards.sh --restage-only --skip-push

# Resume a retained failed computation whose outcome-writing stage completed.
bash scripts/auto_update_competition_dashboards.sh --resume-failed RUN_ID --skip-push
```

The default is 10,000 simulations, four workers and seed 15017. Use
`XGELO_NL_SIMULATIONS` / `XGELO_NL_WORKERS`, or `--simulations N --workers N`,
to change production resources. Publication requires at least 9,600 draws:
the worst-case 95% pointwise Monte Carlo half-width is at most one percentage
point. These intervals describe sampling noise, not model accuracy or a
simultaneous confidence guarantee across all clubs and events. The former
100-draw output is preview precision and cannot pass the new publisher.

Each production refresh captures its genuine input/knockout handoff once,
runs a 1,000-draw comparison followed by the selected production count, audits
probability bounds/rank mass/knockout participant mass/nesting, and writes
convergence and timing evidence under `logs/competition-refresh/benchmarks/`.
The selected simulation is reused for the outcome bundle. There is no second
production Monte Carlo run within one refresh. Measured runtime depends on
the machine and simultaneous work; consult that run's report rather than
estimating completion from a small smoke test.

The controller acquires sources and builds state, outcomes and all three
routes inside a private workspace. Before installing, it checks exact public
inventory and hashes, accepted source/release/outcome authority, freshness,
probability policy and fixture lifecycle. It refuses installation when
managed inputs or runtime code changed during the build. Atomic directory
exchanges keep each incumbent directory visible until its replacement is
ready; the public three-route directory is installed last as one batch.

Approved release bytes are also checked for concurrent changes. When CL
predictions are disabled, unrelated club-release work cannot invalidate an
otherwise unchanged national-team refresh. Failed private workspaces are
retained in owner-only temporary directories; their exact paths appear in run
records. After installation, accepted data/outcomes are durable in the operator
checkout and the temporary copy is removed. Cleanup errors are recorded
separately and do not prevent valid publication.

An isolated publisher checks out current remote `master`, replaces only
`docs/competitions/`, verifies the actual Git index bytes, commits that scoped
change, and pushes without force. It then waits for all 14 public files to
match the validated hashes over HTTPS. A successful push alone is not a
verified deployment. The operator checkout and unrelated edits are preserved.

CL match predictions default to disabled while the team-strength model has
not passed calibration QA. `--cl-forecasts approved` still requires the real
approved release and all forecast gates; the flag cannot grant authority.
Tournament projections need their own connected model/rules/draw authority.
EURO remains pre-draw until accepted official structure and fixtures exist.

## Run records and monitoring

```bash
python3 scripts/check_competition_refresh.py --write-observation
```

Inspect `logs/competition-refresh/`:

- `current.json`: current/latest run, phase, controller PID and child PID.
- `runs/<run-id>.json` and `.log`: UTC stages, exit status and timings.
- `last-success.json`: last completed local refresh, with publication state.
- `last-public-success.json`: last completed refresh with verified HTTP bytes.
- `validated-install.json`: exact installed-batch receipt used for push retry.
- `alert.json` and `health.json`: latest failure/local-only/health observations.
- `install-journal.json` and `backups/`: interrupted installation recovery.
- `private_workspace_path`, `workspace_retained`, `managed_inputs_before` and
  `approved_releases_before` in a run: retained-computation provenance and the
  comparisons required before resuming it.
- `benchmarks/<run-id>/`: simulation timing, convergence, probabilities and
  sampling intervals, retained even if a later rendering/publication fails.

Health fails for an unheld/reused controller PID, a mismatched lock, a run over
12 hours old, a terminal error, no recent success (48 hours), unverified public
publication, stale quantitative feeds, invalid public inventory, or inadequate
simulation count. A local-only run is not reported as a healthy public update.
Source-as-of, source-check and generation timestamps have different meanings;
unchanged results do not establish that the feed was checked recently.

The recurring app health monitor should inspect these records, compare its
previous observation and report a new failure, stale state or recovery. Its
automation id and verification evidence are recorded in the repair ledger
after installation. The app monitor requires the computer and app to be
running; the separate launchd refresh requires the logged-in Mac to be awake.

## Scheduler installation and verification

```bash
bash scripts/install_competition_dashboards.sh

# After a successful manual refresh, add a real near-term calendar occurrence.
bash scripts/install_competition_dashboards.sh --verify-in-minutes 3

launchctl print gui/$(id -u)/com.xgelo.competition-dashboards
```

The normal schedule is 03:00 local time, using the same controller as a manual
run. Installation probes R first, refuses to replace an active refresh, and
restores the previous loaded service and plist if verification fails. It only
manages `com.xgelo.competition-dashboards`; WC services are outside its scope.
After the real verification occurrence completes, reinstall without
`--verify-in-minutes` to remove that extra calendar entry. Check the new run's
`trigger=scheduled`, terminal status, log, source dates, public read-back and
launchd exit code; a loaded plist is not proof of a successful run.

## Failure recovery

1. Read the latest run JSON and its exact log. Fix the reported runtime,
   connectivity, source, model or validation problem. Do not weaken a gate or
   substitute preview projections to obtain a green status.
2. If source/build validation failed, accepted local inputs and public pages
   were never installed. Rerun the normal controller after resolving the cause.
   If outcome-writing completed and the workspace was retained, use
   `--resume-failed RUN_ID` to clone that computation with the current repaired
   runtime. It repeats full production gates, never invents source timestamps,
   and never reconstructs simulation outputs from summary probabilities.
   Recovery rejects changed accepted operator inputs/approved releases, invalid
   retained paths/ownership, stale sources and inadequate precision. The original
   failed workspace is preserved for inspection.
3. If installation was interrupted, rerun the controller. Under its exclusive
   lock, it restores an `installing` transaction from the durable backups.
   A `preparing` transaction has not swapped any roots and is left untouched,
   preserving edits made before a preparation crash. Do not delete backups
   while the journal says `installing`.
4. If the installed candidate is valid but push or deployment failed, use
   `--publish-only`. The exact install receipt, byte/schema checks and genuine
   current authority gates are repeated. An edited or now-stale candidate is
   rejected and requires a full refresh. No new Monte Carlo run is needed for
   an unchanged valid publication retry.
5. On non-fast-forward push, retry publication so the isolated publisher starts
   from the new remote head. Never force-push or reset the operator checkout.
6. For presentation-only changes to already installed accepted inputs, use
   `--restage-only`. It performs all ordinary authority, precision, freshness,
   byte, input/code comparison and installation gates without source acquisition
   or new Monte Carlo work. It is a manual retry mode and cannot be selected by
   the scheduled job.

An installation rollback restores every managed root from the same backup.
Public rollback also uses an atomic directory exchange. Errors preserve the
last-success record and create an actionable failure record. Temporary
preparation debris after an abrupt process kill may be removed only after
confirming no controller holds the refresh lock and the journal is not
`installing`.

## Focused regression checks

```bash
python3 -m unittest discover -s tests/operations -v
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_nl_simulation_precision.R")'
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_non_wc_dashboard_readiness.R")'
```

Operational tests use temporary files and independent fault cases: runtime
discovery, timeouts, locking, stale sources, hash/inventory tampering, preview
precision, expired fixtures, recovery after a real preparation-process crash,
concurrent edits, installed-before-push retries, actual Git index bytes,
scheduler rollback and failed public read-back. They do not make live provider
requests or mutate production publications.
