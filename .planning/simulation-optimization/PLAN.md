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


## Second pass — WC-style streaming (approved 2026-10-26)

1. Correct CL simulated-result cutoff handling through a separate projection overlay; version the algorithm and test counted fixtures and immutable actual inputs.
2. Add persistent bounded chunk execution (256 iterations), full disk traces, atomic checked commits, input/code/environment-bound resume and progress phases. Preserve the memory interface.
3. Add NL and CL sufficient-statistic reducers, exact NA/ordering/percentile/modal-pair behavior, ordered trace readers and explicit legacy materialization. Stream canonical trace hashes.
4. Wire streamed outcomes into real builders/validators and benchmarks without changing public schemas or WC/public bytes. Optimize indexed arithmetic and invariant hashing while preserving rule traces.
5. Differential/recovery/adversarial tests plus national/CL regressions. Benchmark 1k then 10k; allow 100k only if conservative total time <=7200 seconds, combined RSS <50% physical RAM and sufficient disk. Enforce these bounds and preserve checkpoints on failure.
6. Save actual evidence and limitations, update maintenance state and commit verified work. CL remains fixture-only without real production authority. No public promotion.

Status: implementation and regression work completed in `9a19a04`, `3ebd15f`
and `26d2c50`. CL v5 completed the staged 1k/10k/100k fixture checks; 100k
validated in 2,907.547 seconds (48.46 minutes) with peak combined RSS
644,120,576 bytes. Accepted NL 1k/10k candidates validated with exact reference
parity; its 100k run was withheld because the conservative projection is
23,499.8 seconds (6.53 hours), beyond the two-hour gate. The NL full-scale
performance goal remains unmet. No benchmark is active and no public promotion
occurred. See `STREAMING.md` and its hash-bound resource receipts.
