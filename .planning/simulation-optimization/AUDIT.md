# NL / CL simulation performance audit

2026-10-26. Baseline: dashboard branch commit `39cdb1a`. Worktree:
`/private/tmp/xgelo-active-dashboards`. User requested cancellation of the 100k
benchmark; the launchd job was removed and all six original PIDs were confirmed
absent. No replacement 100k job is running.

## Why WC was faster

`R/visualization/worldcup_dashboard.R`, `simulate_group_stage_dashboard`, prepares
score distributions, cumulative probabilities, team/fixture indexes and a
knockout advancement matrix before sampling. Each worker updates numeric
points/goals vectors and compact team counters. Only worker totals are returned
and combined. The implementation is already parallel by seed chunks.

NL was also parallel: four fork workers, deterministic per-iteration seeds and
prescheduled iteration IDs. Missing parallelization did **not** explain its
23-hour estimate. Each iteration instead built rich fixture rows, reconstructed
14 universal/rules standings, reran Article 15/19 ordering, generated legal draw
and two-leg paths and retained large intermediate state objects. Aggregation
waited until every iteration returned. The accepted knockout forecast handoff
was already cached; the long simulation was not repeatedly training the model.

CL used a serial `lapply`, repeatedly prepared identical fixture eligibility,
parsed score grids, validated/hashed the complete schedule and retained each
intermediate graph. Its public result also includes per-iteration fixture
sampling records, which limits how much memory can be removed compatibly.

WC's simpler knockout advancement mechanism is **not** a replacement for NL/CL
two-leg, extra-time, penalty, ranking or draw rules. This work changes execution
and arithmetic preparation, not those rules or source/model authority.

## Measured bottlenecks

`Rprof` baseline NL accepted snapshot, 10 serial simulations: 37.764 seconds
wall time. Inclusive profile costs (overlap; do not add these percentages):

| Operation | Share of sampled CPU |
|---|---:|
| Rebuild league state | 28.8% |
| Construct forecast match rows | 24.6% |
| Data-frame subsetting | 26.2% |
| Public stage sampler | 17.8% |
| Digest/hash work | 18.2% |

Score-table canonicalization consumed about 5.7 seconds of fixed setup. It is
material for tiny tests but does not explain the per-iteration slope at 100k.
Parsing, validation and dataframe allocation recur inside the old hot path.

CL baseline six-iteration fixture profile: 7.676 seconds wall time. Canonical
framing/hash work accounts for about 46% inclusive CPU; state construction about
35%, schedule validation about 30%. Full graph hashes are not used as outputs of
each simulated iteration; immutable schedule authority can be checked once.

## Implemented changes

### Shared execution

`R/common/simulation_execution.R` forks persistent workers once rather than
restarting them at every progress interval. Workers compact each result before
retaining/returning it, so full construction state does not cross the worker
boundary. Results are restored to original iteration order. Worker failures,
missing returns and callback errors stop the run and clean up owned children.
Windows uses a serial fallback. Count, worker and progress controls are checked.

Each worker atomically reports its completed iteration count to a private
temporary directory. The parent emits real completed/total/elapsed events. These
are simulation counts, not a claim that final aggregation/candidate validation
has passed. Temporary counters are **not resumable checkpoints**.

Per-iteration seed identities, the two NL sampling calls and caller RNG state
are preserved. Scheduling, worker count and reporting interval never enter
football probabilities or output lineage hashes.

### Nations League

- A private environment per run owns prepared match eligibility, indexed/memoized
  forecast queries and lazily validated score-sampling plans. Caches cannot leak
  between runs. Public samplers still validate arbitrary supplied inputs.
- The 52 accepted remaining league fixtures are prepared once. Sampling changes
  numeric score/outcome fields in a reusable schema rather than constructing a
  wide dataframe per fixture per iteration.
- Group arithmetic uses numeric vectors and a validated schema template. The
  existing Article 15/19 reducers still decide all ranking and tie-break results.
  Redundant universal arithmetic and duplicate ranking calls are removed; row
  hashes and all externally returned tables remain equal to the reference.
- Unused complete matches, group construction snapshots, duplicate interim
  standings and transition selection objects are dropped before worker return.

### Champions League

- Fixture eligibility, suppression, cutoff decisions and score grids are
  prepared once. Seeded sampling changes scores using the original draw sequence.
- Source schedule and ledger validation remain at the public run boundary.
  A private ranker consumes only internally sampled graphs, preserving public
  Phase 14 arithmetic and Article 18 rules without rehashing the unchanged
  schedule structure for each iteration.
- Intermediate complete graphs are discarded; public fixture-sampling output is
  preserved. Serial/four-worker execution returns identical complete objects.
- Worker and reporting controls reach `ucl20_build_outcomes` and the real CLI:
  `--workers` (default 4), `--batch-size` (default 64). NL CLI reports every 32
  completed iterations per worker; the accepted benchmark also uses 32.

Both simulator and shared execution hashes are required in new full-scale NL
performance receipts. Old receipts cannot certify the changed implementation.

## Evidence and performance limits

Accepted NL pilot: original 100-run/four-worker diagnostic 83.022 seconds;
optimized pilot 46.955 seconds, candidate validation 5.732 seconds. A direct
same-process comparison then measured **90.556 seconds original versus 48.047
seconds optimized**, both with 100 simulations and four workers. The complete
returned objects are `identical`, not merely close in aggregate probabilities.
Measurements are in `nl-comparison.csv` (approximately 1.9x overall). The older 100-run
diagnostic had a process-exit instrumentation issue, so it alone is not final
release evidence.

CL 50-run synthetic mechanics comparison, sequentially executed with identical
inputs and complete output equality:

| Implementation | Seconds |
|---|---:|
| Original serial | 34.880 |
| Optimized serial | 11.887 |
| Optimized four workers | 6.110 |

That is approximately 2.9x from preparation alone and 5.7x overall in this small
fixture benchmark. It is **not** accepted production CL certification. Concurrent
regression activity can affect absolute timings; do not extrapolate a guaranteed
full-scale runtime from these small runs.

The accepted **1,000-simulation** NL run then completed in **323.965 seconds**
versus the original **819.192 seconds** (approximately **2.5x faster**). Its
candidate validated successfully in 37.091 seconds. Parent R peak heap decreased
from 1,917,904,048 to 1,140,361,448 bytes (approximately 41% lower); this measure
excludes worker and non-R memory. Final returned object size (18,033,576 bytes)
and durable artifact size (4,817,087 bytes) are unchanged. Measurements and
artifact inventory are preserved alongside this audit. A repeated run with
unrestricted resource instrumentation is used to obtain process RSS; the first
run's `/usr/bin/time -l` wrapper could not read `kern.clockrate` in the sandbox,
although R completed candidate validation and wrote its true measurement CSV.
The unrestricted repeat exited zero: **316.939 seconds simulation**, **36.593
seconds candidate validation**, 357.34 seconds process wall time. macOS reported
1,992,081,408 bytes maximum resident set and 1,759,234,208 bytes peak footprint;
these are the timing tool's reported measures, **not** a summed whole-worker
peak. The saved repeat receipt matches both current implementation hashes.

Original/new accepted NL outputs match exactly for the three-iteration serial
and parallel pilot, including output table ordering and hashes. The focused
optimization suite adds reference sampler/ranking comparisons, worker/reporting
invariance, RNG restoration, suppression, invalid grids and worker failure tests.

### Remaining scaling work

1. NL still spends substantial CPU in rule-aware ranking, per-iteration trace
   construction and canonical hashes. More workers alone cannot remove it.
2. Unlike WC, NL's contract returns detailed per-iteration stage slots, matches
   and resolutions; CL returns sampled fixture evidence. Their output size is
   inherently linear in simulation count. This patch removes unused copies,
   not every required trace or all linear memory growth. A 100k run may still
   exceed practical memory/runtime limits; it is not certified by this patch.
3. A true constant-memory reducer requires per-team/rank sufficient statistics
   plus streamed or separately stored detailed traces. Preserve first-observed
   ranking rows, conditional means, NA/suppression behavior, ordering and hashes;
   the existing output schema must not silently lose records.
4. Resumable execution needs checkpoints bound to all accepted input/rules/model
   hashes, implementation hashes and iteration IDs. Atomic progress counters do
   not satisfy that contract. No checkpoint resume is claimed here.
5. Rebenchmark 1k/10k and memory after this patch before authorizing another long
   certification run. Do not treat the old 23-hour extrapolation as current ETA.

## Separate CL correctness concern found by the audit

The existing synthetic CL scenario samples 144 future fixtures but counts zero
universal standings appearances. `.ucl_state_to_phase14_matches` derives their
completion evidence from future confirmed kickoff times, while Phase 14 excludes
evidence after the historical information cutoff. The original and optimized
paths both exhibit this behavior; rank rows remain explicitly unresolved.

This performance patch deliberately preserves that existing behavior instead of
silently changing forecast semantics. Before certifying CL forecasting, add a
simulation-only projected-result representation with an explicit evidence policy,
keep real accepted results immutable, and prove that varying sampled scores can
change standings while future actual results/features remain excluded. The
fixture benchmark therefore measures mechanics speed, not forecast correctness.

## Reproduction

```sh
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla scripts/benchmark_nations_league_scale.R . 1000 /private/tmp/nl-optimized-scale 4
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla scripts/benchmark_champions_league_scale.R 50 4 /private/tmp/cl-optimized-scale
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla -e 'testthat::test_file("tests/testthat/test_simulation_optimization.R")'
```

WC source and published bytes are unchanged. No publication, production model
selection, source acquisition or full-scale forecast certification occurred.

## Final verification

- The existing national publication gate completed all 15 commands: EURO replay
  and 14 required test files. The newly registered optimization suite passed
  separately; future gate executions include it as well.
- New optimization suite: **37 assertions**, no failures, errors, warnings or skips.
- CL existing suites: **496 assertions** across the five saved regression files,
  plus **34 assertions** in the simulation review suite; all pass without warnings
  or skips. The real production CLI still returns its existing typed authority
  block, accepts the new execution controls, and leaves selectors/incumbents alone.
- Complete original/new object identity holds for accepted NL 3/100 and fixture
  CL 6/50 runs. Prepared samplers, original rule reducers, alternate worker counts,
  missing discipline, late evidence, unavailable forecasts, malformed grids and
  worker failures are explicitly exercised.
- Modified R files parse; `git diff --check` passes. World Cup publication hash
  matches its original baseline. No public dashboard or accepted source was changed.

Saved JSON/CSV evidence in this directory records the completed gates and measured
pilots. Full 10k/100k acceptance remains outstanding; implementation is a measured
first optimization pass, not a claim that every remaining scalability or CL
correctness problem has been resolved.
