# Why NL missed the time target, and how NL/CL can improve

Audit date: 2026-10-26. Reference commit: `e1b8f80`.

**CL has a measured optimization opportunity: a private prototype ran its
sampling/ranking kernel 3.06× faster while preserving the checked complete
rankings, Article 18 trace rows and hashes. NL needs a larger change through its
ranking and path engine: small reuse changes showed no reliable gain, and row
construction changes improved the checked kernel by only 1.20×.**

These are bounded diagnostic experiments, not new 100k certificates. Production
simulator code, accepted inputs, WC source and published dashboard bytes remain
unchanged. Existing measured receipts retain their code identities. No long run
is active.

## 1. What failed, and why the previous pass was insufficient

NL's remaining shortfall is simulation runtime. Its accepted 10k candidate
validated in 1,953.940 seconds; the conservative 100k gate projected 23,499.8
seconds (6.53 hours), so the 100k run was correctly withheld. Memory was below
the agreed limit. The published dashboard was retained.

The previous pass solved bounded memory, deterministic parallel execution,
checkpoint recovery and exact public-output compatibility. It introduced
numeric standings arithmetic and prepared sampling, but **left the general
dataframe ranking/path engine inside every NL iteration**. The WC-style
representation change therefore stopped before several of the costly parts.
The memory/execution work did not by itself complete the CPU optimization.

At the measured scale, qualifying conservatively for two hours needs roughly
3.26× greater overall throughput. A 20% kernel gain is useful but insufficient.
The 20% preflight margin is included in the 6.53-hour projection; that projection
must not be compared as an observed wall time with CL's observed 48.46 minutes.

The saved NL 10k log reaches worker aggregation at 1,614.816 seconds, while the
simulator call takes 1,938.011 seconds. The remaining approximately 323 seconds
include preparation outside the executor timer and serial aggregation/hashing.
Candidate validation adds 11.557 seconds. The time problem spans both the
worker kernel and the work after it.

## 2. Parallelization is already present

Both simulators fork four persistent workers. Fixed 256-iteration chunks are
assigned round-robin to disjoint worker queues; each worker processes its own
queue. At 100k, 391 chunks divide as 98/98/98/97. `batch_size` controls temporary
progress counters; it does not determine worker count. These mechanisms are in
`R/common/simulation_execution.R:192`, `:230-269`.

More workers may improve throughput, but their effect must be measured on this
host. They do not remove repeated parsing, dataframe construction or serial
aggregation. Work stealing could reduce the tail of uneven chunk workloads;
there is no evidence that tail scheduling explains NL's several-hour gap.

The parent also scans unfinished chunk/counter paths every 100 ms and scans
again when reporting progress (`simulation_execution.R:213-219`, `:279-290`).
An O(workers) current-chunk protocol would reduce this bookkeeping. It is a
secondary improvement; no speedup is claimed for it here. This internal
resource/progress mechanism is separate from the user's 30-minute status
polling preference.

## 3. Why the WC timing comparison is limited

| Work | WC dashboard | NL | Current CL benchmark |
|---|---|---|---|
| Prepared numeric group indexes | Yes | Partial | Yes, standings arithmetic |
| Per-iteration ranking | Numeric helper | General Article 15/19 engine | General Article 18 engine |
| Knockout work | Precomputed pairwise advancement probabilities | Match scores, legal draws, two legs, ET/penalties and transitions | League iteration; legal paths/events handled once afterward |
| Full per-iteration audit histories | No | Yes | Sampling and rank records |
| Output accumulation | Numeric counters | Generic sufficient-statistic buckets | Rank counters |

WC prepares numeric indexes/CDFs at `R/visualization/worldcup_dashboard.R:1660-1687`,
uses numeric ranking at `:1804-1839`, and samples knockout advancement from a
prepared pairwise matrix at `:1716-1730`, `:1977-1979`. Its default route estimator
is analytic (`:1114`, `:1361-1389`). Workers return counters (`:1997-2011`).

NL executes league state, EURO priority, legal knockout draws, quarterfinals,
semifinals, final/third place and promotion/relegation playoffs inside every
iteration (`uefa_nations_league_simulation.R:1809-1924`). CL's iteration returns
league sampling/rank rows (`uefa_champions_league_simulation.R:864-867`), with
legal path/stage work afterward (`:882-895`). These are different workloads.

The transferable WC technique is prepared numeric computation and direct
counters. Copying WC's random tie fallback or Bernoulli advancement semantics
would break NL/CL rules or the required sampled-result compatibility.

## 4. NL findings from a fresh kernel-only probe

Accepted inputs and the accepted cached forecast handoff were reused. Sixteen
iterations were instrumented after run preparation. Every iteration performed:

| Operation | Calls per iteration | At 100k, if unchanged |
|---|---:|---:|
| Group rule preflight | 28 | 2.8 million |
| Match preparation for ranking | 42 | 4.2 million |
| Ranking UTC parser | 84 | 8.4 million |
| Stage pair resolution | 16 | 1.6 million |
| Full score-distribution normalization | 0 | Done during preparation |

There are 14 groups. The prepared reducer invokes preflight, `rank_group`
invokes it again, and Article 19 prepares the group matches a third time
(`uefa_nations_league_simulation.R:2419-2426`;
`uefa_nations_league_rules.R:1249`, `:1463`). Preparation repeatedly copies rows,
converts scores/statuses/booleans and parses evidence/cutoff timestamps
(`rules.R:1013-1097`).

In this instrumented profile, league-state construction used 2.895 of 7.655
sampled kernel CPU seconds (about 38%), and stage-pair resolution used 2.735
seconds (about 36%). These inclusive figures overlap nested helpers and must
not be added to their child percentages. The profile also contains about 0.55
seconds of timing/instrumentation work outside the kernel. It is not a claim
about all full-scale CPU shares.

The earlier 30-run whole-call profile included fixed preparation. Its
score-normalization percentage should not be treated as a recurring worker
cost: the new probe and source inspection confirm normalization is already
outside the iteration. New knockout sampler plans still have cold-cache costs;
those are distinct from steady-state work.

### Repeated arithmetic and discarded work

- The prepared group arithmetic still scans string team IDs for each team
  (`simulation.R:2392-2402`), rather than using prepared home/away positions.
  Group ranking reconstructs match metrics as per-team dataframes
  (`rules.R:1104-1121`, `:1255`), and H2H criteria calculate subset metrics again
  (`:1266-1269`).
- Article 19 prepares matches again, scans each team's fixtures, excludes
  fourth-team results where required, constructs rows and joins match IDs
  (`rules.R:1458-1501`). Its membership choices can be selected from prepared
  fixture masks after the group order is known.
- Universal snapshot hashes at `simulation.R:2408-2418` are immediately
  replaced by final ranking hashes (`rules.R:1156-1163`). The intermediate
  hashes can be omitted privately; final ranking hashes are public data and
  must remain exact.
- Stage topology, official pair decoding, tie IDs and QF legal permutations
  are rebuilt repeatedly (`simulation.R:1316-1317`, `:1203-1248`, `:572-584`).
  They can be prepared once with the original traversal order.
- Ranking/path capture creates repeated dataframe representations. Reducers
  bind group standings, then exact-mean tracing binds them again
  (`uefa_nations_league_streaming.R:11-16`, `:174-190`). Path capture scans
  resolution tables per team (`simulation.R:1709-1802`).

### What the NL experiments actually achieved

Two interleaved repeats used the same eight warmed iterations; full iteration
objects were compared exactly before timing.

| Private experiment | Mean reference | Mean prototype | Result |
|---|---:|---:|---|
| Omit overwritten hashes; memoize prepared matches/timestamps with full-input cache keys | 4.0735 s | 4.0390 s | No reliable gain |
| Same experiment with prepared group lookup keys | 4.0175 s | 3.9595 s | No reliable gain |
| Construct scalar rows directly in the private runtime | 4.0325 s | 3.3480 s | 1.20× kernel throughput |

The reuse prototype did reduce match preparations from 42 to 14 and calls to
the original ranking UTC parser from 84 to 16 in the checked iteration.
Nevertheless, general preflight/ranking/path processing and lookup overhead
remained. Counting fewer helper calls was not enough to establish a meaningful
overall speedup.

The counter artifact counts calls to instrumented original helpers. The
prototype bypasses the original build wrapper when using its replacement;
that wrapper's zero count does not mean league-state construction disappeared.

The scalar-row experiment is an allocation-cost probe, not a proposed generic
replacement for `data.frame()`. Production changes should use explicit typed
row constructors at profiled call sites and preserve public validators and
fallbacks. Eight accepted iterations do not establish adversarial parity.

## 5. NL aggregation still repeats invariant work

Fresh NL execution through candidate validation hashes trace/statistics files
at least seven times: writer checksum, immediate verification, parent merge,
exact-mean reader, schema pass, canonical-row pass and candidate validation
(`simulation_execution.R:251`, `:253`, `:296`, `:312`, `:395`, `:403`, `:483`;
`uefa_nations_league_outcomes.R:729`). Three passes decode the trace history.

Both canonical passes add metadata to each field of every iteration. That
helper recomputes the identical ruleset SHA (`simulation.R:1928-1937`;
`rules.R:890-893`). With three nonempty fields, this permits six ruleset hashes
per iteration. The existing private iteration memo does not cover this separate
streaming scope.

On a copied, verified 30-iteration trace, hoisting that invariant rules hash
reduced complete three-field canonical hashing from **0.654 to 0.384 seconds**,
a **1.70× phase speedup**, with all three canonical hashes identical. This was
one small, cache-warm comparison; larger external sorts need separate checks.

Prepare metadata/schema once, record the schema union in checked chunk
statistics, and combine compatible trace passes. Compact ordered double
sidecars could avoid decoding unrelated stage rows for exact means. Continue
using the original ordered R `mean()` calculation: sum/count reassociation
already caused one-bit incompatibilities in the prior work.

Repeated validation must be redesigned around the exact bytes consumed, not
disabled or cached by pathname. Corruption, replacement, overlap and missing
trace tests remain mandatory.

Even generously applying the observed 1.20× kernel factor to all worker time
and the 1.70× canonical factor to all remaining simulator time would produce
only about **1.27× overall throughput**. That generous illustration is still
far below the approximately 3.26× required. The larger numeric-engine change
is necessary before another NL 100k attempt.

## 6. CL has a stronger measured opportunity

A 64-iteration component probe on the existing fixture workload measured:

| Component | Wall time |
|---|---:|
| Sampling | 2.334 s |
| Article 18 ranking | 4.630 s |
| Rank-row materialization | 0.011 s |
| Counter reduction | 0.002 s |
| Serialize + gzip level 1 | 0.045 s |

The kernel profile attributes about 66% of sampled CPU to ranking and 33% to
sampling. Canonical hash call stacks include more than half of sampled CPU;
that includes construction/evaluation of framed payloads, not just SHA-256
computation. Every fixture seed and rule-trace scalar repeatedly rebuilds
constant frame names, types, domains and lengths.

Preparing the identical canonical framing reduced the sampled kernel by
**1.97×**. After that change, dataframe construction occupied about 42% of the
new profile. Preparing one-row trace/rank schemas as well produced:

| Same 64-iteration workload, two interleaved repeats | Mean wall |
|---|---:|
| Current reference | 6.9305 s |
| Prepared frames and row construction | 2.2625 s |
| Throughput improvement | **3.06×** |

The checks compared complete sampled graphs and rankings for 64 iterations,
including ranking attributes, Article 18 trace rows and their hashes. Forty
seed-encoding cases included missing values, UTF-8 and control characters;
caller RNG state was preserved. These results support implementation, but do
not replace the full corrected-reference, recovery and candidate-byte tests.

A simple 48.46 minutes / 3.06 calculation is about 15.8 minutes. That is a
kernel extrapolation, **not a certified end-to-end runtime**; worker scaling,
traces, preparation and candidate validation still need fresh 1k/10k checks.

### The current CL fixture is also a pathological tie workload

The scale fixture assigns every match the same two possible scores: 0–0 with
probability 0.4 and 1–0 with probability 0.6
(`tests/testthat/test_phase20_simulation_review.R:19-26`). It cannot produce an
away goal. Points, goal difference, goals and wins therefore tie unusually
often, pushing ranking into later criteria with missing evidence.

In the checked 64 iterations, the reference generated **58.97 criterion trace
rows per iteration**, with **84.4% of club rank rows unresolved**. This is the
required missing-evidence behavior for that fixture, not production forecast
quality. Candidate validation correctly permits explicit unresolved results.

A separate 64-score synthetic sensitivity probe reduced mean trace rows to
16.38 and had no unresolved ranks in the sampled cases; the reference kernel
took 4.010 seconds instead of 7.335 seconds in that comparison. This does not
establish production runtime or justify replacing the difficult fixture.

Keep the two-score case as an adversarial stress workload. Add broader-support
fixtures, accepted-result mixtures, complete and incomplete tie evidence, and
accepted/missing draw scenarios as a separate benchmark portfolio. Production
CL authority remains human-needed and cannot be inferred from any of them.

## 7. Recommended implementation order

1. **CL: prepared canonical encoders and explicit typed row constructors.**
   Preserve exact bytes, seeds, trace content and the public Article 18 API.
   Run the complete corrected-reference and adversarial suites; certify new
   code with fresh 1k/10k evidence before 100k. The 3.06× kernel result gives
   this work the strongest measured return.
2. **NL: hoist trace metadata/schema and remove clearly overwritten private
   hashes.** These are bounded changes with direct parity checks. Combine
   verified reads and add ordered mean sidecars only under a versioned storage
   contract with corruption/recovery tests.
3. **NL: carry prepared numeric state through Articles 15/19 and paths.**
   Prepare integer home/away/team/group indices, eligibility/evidence flags,
   H2H subset indices, possible fourth-team exclusion masks, topology and
   official stage templates. Compute metrics once. Start with distinct points
   and unambiguous regulation/aggregate winners; preserve existing reducers
   for recursive multi-team ties, missing evidence, ET and penalties.
4. **NL: feed numeric captures directly to reducers.** Preserve the first
   representative rows, exact means, histograms, modal-pair rules, ordered
   reasons, NA behavior, public hashes and candidate CSV bytes. Avoid
   reconstructing the same standings/path frames for counts and mean tracing.
5. **Measure worker counts after the kernel change.** Compare 1/2/4 and a
   modest higher count on enough chunks. Keep iteration identities fixed and
   large competition checks sequential. Improve O(workers) progress handling
   if the parent profile justifies it.

For NL, a fresh accepted-input 10k run must conservatively qualify for two
hours before starting 100k; approximately ten minutes at 10k is a useful
screening threshold with the existing margin, not a substitute for the actual
fixed/marginal-time gate. No new long run should start from an isolated
microbenchmark speedup.

## Evidence and reproduction

`deep-audit/evidence/audit-summary.json` binds the saved CSV/JSON evidence to
the unchanged source snapshot
`ea44d253cea8daf6dc80eb794d8b1738e70e831a721ba61c87570a1afdeb140f`.
The prior complete scale receipts remain in `STREAMING.md` and its linked files.

Nine audit-only R probes are in `deep-audit/probes/`. Run from the worktree
root with R 4.6.1. They write to `/private/tmp/xgelo-deep-audit` by default;
`XGELO_AUDIT_DIR` and `XGELO_AUDIT_PROBE_DIR` override those paths. For example:

```sh
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/cl-profile.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/cl-prototype.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/cl-rows-prototype.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/cl-workload.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/nl-profile.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/nl-prototype.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/nl-rows-prototype.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/nl-prototype-counts.R
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla .planning/simulation-optimization/deep-audit/probes/nl-aggregation.R
```

NL requires genuine existing model/source artifacts. `XGELO_AUDIT_NL_HANDOFF`
can select the accepted cached handoff; without it, the loader prepares the
handoff from accepted inputs. `XGELO_AUDIT_NL_TRACE` selects a complete existing
NL trace for the aggregation probe, which copies it before writing temporary
sort files. Set `XGELO_AUDIT_NL_MEMO=hashed` for the slower full-input cache-key
experiment. CL fixture probes require no production authority. Kernel probes
omit the public publication pipeline; their files are never promotion receipts.

All nine durable probes parse. Exact object/hash checks passed for the bounded
experiments above. Full national/CL regressions were not rerun for this
audit-only work because production code did not change. Timings are small-run
observations on this host, with warm selected iterations and normal background
activity; they establish priorities, not release acceptance.
