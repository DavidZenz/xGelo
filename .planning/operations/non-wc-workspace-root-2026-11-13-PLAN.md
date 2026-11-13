# Repair nested non-WC refresh workspace resolution

## Diagnosis

Scheduled run `20261113T021322Z-66f9fd6b` fails in
`phase14_refresh_nl_repin_stage_capture()`. The private source bundle is
`9d7f67a9…`, but `phase13_source_find_project_root()` climbs through the
workspace to the operator checkout's `.git` and compares it with `82f10a52…`.
The failure began after durable workspaces moved beneath `logs/`.

## Plan

1. Make the Nations League dependency root resolvers stop at the nearest
   complete xGelo code root (`R/competition` and `scripts`), including a
   private root without `.git`. Preserve existing Git and fixture fallbacks.
2. Add nested parent/child regression coverage with different source hashes;
   validate repinning against child bytes and retain integrity rejection.
3. Reproduce the old failure and validate the repaired dry run against the
   retained source snapshot, without editing that snapshot or public artifacts.
4. Run the focused R and controller regression suites. Then retry the normal
   guarded non-WC controller, following through to independent public read-back.
   Preserve operator edits, World Cup data/pages/services and release authority.

## Acceptance

- Private root discovery never substitutes parent source or rules data.
- Hash/registry/raw-content validation remains mandatory.
- The real retained source passes state validation with repaired code.
- A fresh production attempt installs only after all existing gates and records
  success only after verified HTTPS publication; failures retain incumbents.

## Verification so far

- Before the repair, the new nested-root regression reproduced the parent-root
  leak and source-hash error. After the repair, both cases / 32 assertions pass.
- Existing NL state hash reporting and invalid-candidate no-write checks pass.
- All 40 controller refresh/recovery regression cases pass.
- A read-only state dry run using repaired code and the exact retained
  `20261113T021322Z-66f9fd6b` source validates hash `9d7f67a9…` and candidate
  state `c69c6575…`; the old code fails in the repin validator on the same source.
- The older Phase 13 suites expose live-fixture schema drift and missing fixture
  registries. The same failures reproduce with all six changed source files
  restored from HEAD in `/private/tmp/xgelo-root-baseline-k_94z5yp`; the repair
  does not claim those legacy suites pass.
- Recorded 86 protected WC/global/release/LaunchAgent file hashes before the
  production retry in `logs/competition-refresh/workspace-root-repair-20261113-protected-before.json`.

## Production recovery — complete

Normal guarded run `20261113T093821Z-0455ecf2` completed successfully at
2026-11-13T10:29:05Z (11:29 Vienna). State now binds the private source hash
`26a9c33f…`; its local Elo evidence includes 112 completed results, with 44
upcoming fixture forecasts. The genuine source cutoff is 09:38:30 UTC and
latest completed-result evidence is 12 November 21:41:05 UTC.

The 1,000/10,000-draw passes took 230.597/2130.443 seconds. Both resolve all
966 events, with probability bounds, rank/group mass, knockout participant mass
and nested paths passing. The selected count meets the existing pointwise
sampling-precision policy. No model, approval, simulation or hash gate was relaxed.

All candidate authority/schema gates passed. The isolated publisher committed
only the scoped competition dashboard batch as
`522e32fdc085586fb70120585605ce7e5d8cb7d0`; all 14 HTTPS files matched the
validated inventory at 10:29:05 UTC. Health observation at 10:29:41 UTC is
`healthy`, publication `verified`, problems empty, controller terminal.

All 86 protected WC/global/release/LaunchAgent files remain byte-identical,
with no extra files in those inventories. Both scheduler plists are unchanged.
Evidence is under `logs/competition-refresh/workspace-root-repair-20261113-*`
and `logs/competition-refresh/benchmarks/20261113T093821Z-0455ecf2/`.

Repair commit `7598061` is pushed to `codex/fix-non-wc-workspace-root`.
The older failed runs remain recorded as failures. The recurring monitor stays
read-only; the normal daily 03:00 local launchd job uses the repaired runtime.
