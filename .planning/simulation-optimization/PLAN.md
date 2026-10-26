# Simulation optimization audit and implementation

User authorized stopping the 100k job and deeply auditing/optimizing NL and CL,
using the World Cup implementation as a reference. Existing dashboard branch is
reused; public outputs, rules, model authority and World Cup source stay intact.

1. Stop the persistent job, confirm workers exit, preserve the old simulator as
   an executable parity oracle and record small-run profiles/timings.
2. Audit WC's precomputed lookup/numeric-counter/chunk approach against NL and
   CL. Separate fixed boundary validation from per-sample work and identify
   retained output requirements before removing any data.
3. Implement bounded deterministic batching with parent progress reporting,
   caller RNG preservation, checked worker failures and serial fallback. Wire
   CL worker controls through its real coordinator/CLI.
4. Optimize measured NL hot paths using run-local, immutable prepared inputs,
   indexed lookups and sampling plans. Preserve ordering, RNG draw sequence,
   rules, tie-breaks, unresolved status, hashes and all required output rows.
5. Compare complete original/new outputs at fixed seeds across serial/parallel
   and batch sizes. Exercise unavailable, malformed, draw and cutoff cases.
   Profile/timestamp accepted NL and fixture-only CL runs, then run the existing
   national and CL regression suites. No new 23-hour job before evidence.
6. Document measured gains, remaining bottlenecks and limits; commit verified
   implementation and audit. Invalidate all old full-scale performance receipts.

Production CL remains gated by genuine accepted club/model authority. Synthetic
fixture measurements are mechanics evidence only. Avoid replacing football
rules with simpler World Cup rules to obtain a speedup.

## Execution status

- [x] Stop the long run and confirm every original worker exited.
- [x] Compare WC/NL/CL implementation and record CPU profiles.
- [x] Implement prepared samplers, numeric NL standings, persistent CL/NL workers,
  compact transient state, progress counts and runtime controls.
- [x] Exact old/new complete output parity: accepted NL 3/100 simulations and
  synthetic CL 6/50 simulations; serial/parallel/reporting invariance.
- [x] First accepted NL 1k candidate validated; 2.5x faster, lower parent heap.
- [x] Complete resource-instrumented repeat and remaining regression gates.
- [x] Save audit, tests and implementation after checks pass.

No 100k certification or deployment is part of this completion claim.
