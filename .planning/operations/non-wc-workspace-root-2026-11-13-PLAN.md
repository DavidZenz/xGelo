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
