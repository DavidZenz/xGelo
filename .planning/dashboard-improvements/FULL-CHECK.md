# Full release check — 2026-10-26

User requested the full check after implementation, then requested Firefox when
Safari reported remote automation disabled.

## Plan

- Run the real accepted 100,000-simulation benchmark, seed 15017, four workers,
  under `/usr/bin/time -l`; preserve its log and validation receipt.
- Execute the complete registered regression gate and staged envelope checks.
- Add an explicit Firefox option to the existing WebDriver smoke harness,
  keeping identical assertions and actual viewport verification. Record browser
  capabilities in evidence. Safari remains the default production runner;
  Firefox evidence must never be reported as a Safari gate pass.
- Run both active routes at 1440x900 and 390x844 in Firefox. Fix demonstrated
  defects and rerun affected checks. Keep public routes unchanged.

## Initial state

- Benchmark running: `/private/tmp/xgelo-full-check/scale-100000.log`.
- Complete regression gate running: `/private/tmp/xgelo-full-check/regression.log`.
- Staged envelope: passed.
- Safari: blocked before session creation, remote automation disabled.
- Firefox installed; geckodriver 0.37.1 installed for the requested checks.

No deployment or public-data mutation is authorized by this check.

## Firefox results

Firefox 158.0.1 with geckodriver 0.37.1 passes both routes at actual content
viewports **1440x900** and **390x844**. All seven Nations League tabs have one
visible panel, correct hashes and no page-wide horizontal overflow. Search,
reset, shared team persistence/clear, direct hashes and keyboard tab switching
pass. Both routes have no captured JavaScript errors, duplicate IDs or
unlabelled form inputs. Reports and screenshot hashes are recorded in
`full-check-firefox.json`.

The first complete mobile tab traversal found Format card overflow from long
provenance hashes. Hashes now wrap, cards may shrink, and the Format grid uses
one column on narrow screens. All four Firefox checks passed again after this
repair. This changes presentation only; regenerated candidate payloads remain
byte-identical and the World Cup baseline still matches.

Firefox's outer-window API initially clamped width to 500 CSS pixels. That
attempt was rejected. The harness now uses the standard BiDi
`browsingContext.setViewport` command for Firefox and verifies the resulting
`innerWidth`/`innerHeight`. Node's built-in WebSocket is needed only for this
explicit Firefox option. No personal browser profile or preferences are used.

Reproduce from the implementation checkout, substituting each route and size:

```sh
rtk proxy python3 scripts/dashboard_browser_gate.py --stage-root /private/tmp/xgelo-dashboard-candidate --path /private/tmp/xgelo-dashboard-candidate/nations-league/index.html --width 390 --height 844 --browser firefox --driver /opt/homebrew/bin/geckodriver --evidence-dir /private/tmp/xgelo-full-check/firefox
```

The production coordinator still defaults to the pinned Safari gate. These
Firefox checks are separate evidence, not a Safari pass or a publication bypass.

References: [Mozilla Firefox capabilities](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Reference/Capabilities/firefoxOptions),
[BiDi viewport command](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Reference/BiDi/Modules/browsingContext/setViewport).

## Remaining runtime check

The second complete registered regression gate (EURO replay plus all 14 required
suites) **passed after the mobile repair**. The result is preserved in
`full-check-regression.json`; the execution log confirms the post-repair run.

At the subsequent status check, the original 100,000 benchmark and its four
workers were no longer running. The original log contains no failure explanation
or completion timings, and no validated receipt exists. Its cause is unknown;
the original execution cannot be counted as passing or resumed from a checkpoint.

The requested benchmark has been restarted as a one-off persistent macOS job,
`gui/501/local.xgelo.dashboard-scale-100000`, independent of the chat's exec
session. It uses the same accepted inputs, 100,000 count, seed 15017 and four
workers. Its log confirms entry into the accepted simulation. `caffeinate -i`
prevents idle sleep for the duration. It does not automatically retry or run on
a schedule. The job definition is
`/private/tmp/xgelo-full-check/scale-100000-job.plist`.

There is still no completed receipt. The earlier approximately 23-hour estimate
is not a measured completion time or a reliable remaining-time estimate.

Current log: `/private/tmp/xgelo-full-check/scale-100000-persistent.log`.
Original interrupted log: `/private/tmp/xgelo-full-check/scale-100000.log`.
Expected validated receipt: `/private/tmp/nl-scale-certification/measurement-100000.csv`.
No public forecasts or dashboards are written by this benchmark.

At the original run's one-hour process check, parent plus four worker resident sets totalled
approximately 5 GB. This is a point-in-time reading, not a measured peak or a
progress percentage. The simulator has not been changed during this run.
