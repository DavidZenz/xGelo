# WC-style streaming implementation — 2026-10-26

The bounded streaming implementation and regression checks are complete. CL v5 passed staged fixture checks through 100,000 iterations in **48.46 minutes**, including preparation and candidate validation, with **0.600 GiB** peak combined RSS. Accepted NL candidates passed at 1k and 10k with exact reference compatibility; its 100k check was **withheld** because measured runtime conservatively projects **6.53 hours**. NL's two-hour full-scale performance goal remains unmet.

Implementation commits: `9a19a04` (separate CL cutoff correction), `3ebd15f` (streaming execution/reducers/integration), and `26d2c50` (CL missing-forecast uncertainty correction, algorithm v5). Baseline: `16f81f2`. No benchmark is active. No public promotion occurred.

## Execution and compatibility

- Persistent workers produce fixed 256-iteration chunks, reducing iterations immediately and writing complete compressed traces plus compact statistics to private directories. At most one chunk per worker is active; the parent merges bounded statistics. Atomic rename commits a chunk only after iteration coverage, fingerprints and SHA-256 checks pass. Partial chunks have no authority.
- Resume binds accepted inputs, forecasts, model/rules, cutoff, seed, requested count, algorithm, implementation dependencies and relevant R/RNG environment. Worker count can change; chunk size cannot. A run lock prevents concurrent overlap. Corrupt, overlapping or mismatched chunks fail explicitly; incomplete chunks are recomputed.
- Temporary completed counters are distinct from committed coverage. Preparation, simulation, aggregation and validation are reported separately, with elapsed time and estimated remaining time. Runtime supervision accounts for resumed active time, owns only its subprocess group, and preserves checkpoints on failure.
- NL reducers preserve first-observed rows, deterministic order, conditional points/goal difference, suppression/reason precedence, NA behavior, modal bracket pairs and exact type-1 EURO queue percentiles. Private prepared numeric/indexed helpers retain existing reducers for complex ties and missing evidence.
- Exact R means require a disk pass: only one bounded scalar series (at most 100k values, about 0.8 MB) is materialized. This preserves one-bit floating-point differences found on accepted inputs without collecting full histories. Mean spooling groups each bounded chunk once.
- Ordered readers preserve all detailed traces. Explicit legacy-materialization helpers reconstruct complete in-memory results. Outcome builders consume tagged streaming summaries and verify trace access; inaccessible traces fail explicitly. Canonical trace hashes use the original encoding with bounded external sorting.
- Existing library calls retain their memory return shape by default. Dashboard builders and benchmarks request streaming, default to four workers and expose execution mode, run directory, resume and chunk-size controls. Storage/checkpoint metadata remains outside public football identities.

## CL correctness and authority

The corrected ranker combines cutoff-eligible accepted results with a separate eligible sampled overlay. Accepted scores, evidence timestamps, fixtures, training inputs and forecast ledgers remain unchanged. Sampled projections contribute appearances, points and goals; the same counted-match set supplies standings arithmetic and Article 18 criteria.

A missing-forecast probe exposed a partial-season uncertainty gap after the initial cutoff fix: one required unsampled future fixture still allowed 27 resolved league-band rows. Version v5 keeps known numerical metrics but leaves all league ranks/bands unresolved whenever any required fixture has neither a cutoff-eligible accepted result nor an eligible sampled projection. Required fixtures include unfinished league rows even when their current `counts_for_standings` flag is false. The reproduced probe now emits zero resolved league-band rows. Completed rows explicitly excluded from standings retain that exclusion policy.

Unavailable forecasts, unresolved ties and missing draw/knockout evidence remain explicit. CL checks use synthetic fixtures and remain `production_eligible=FALSE` / `production_certified=false`. The production CLI still reports `production_human_needed`, with unchanged selectors and incumbent state. This maintenance does not complete the production authority or publication phases.

## Verification

- National gate: all 17 commands passed, comprising EURO replay and 16 unfiltered suites.
- Fresh CL v5 regression: 530 assertions across six suites, with no failures, warnings or skips.
- Focused streaming: 44 assertions, covering exact full-object parity, alternate seeds, serial/parallel execution, recovery with a different worker count, corrupt/missing/extra chunks, manifest tampering, worker/sink failures, unavailable forecasts and exact UTF-8/control-character canonical framing.
- Accepted NL baseline comparison: all returned tables, metadata, canonical hashes and candidate CSV bytes are identical after legacy materialization, including after the CL-only v5 change.
- Release safety: 49 assertions, including implementation identity, measured time/RSS limits and measurement-hash rejection.
- Python watchdog: four tests, including cumulative resume time, exhausted/unfinalized attempt rejection, disk measurement and orphan-worker cleanup after parent exit.
- Final verification rechecked receipt-to-CSV hashes, frozen source identity, input/algorithm lineage across all three CL scales, candidate validation, full committed coverage, chunk inventory, resource bounds, worker cleanup and protected tracked paths.

WC publication SHA-256 remains `bc540c9d1014095e5d10b2ddc06b73d105c13cd8db7efee6c46bf2d6e86f56b7`. No tracked `docs/`, `data/` or `outputs/` file changed from the optimization baseline. WC source and published dashboards remain unchanged.

## Accepted NL scale evidence

| Count | Simulation + aggregation | Candidate validation | Process wall | Peak combined RSS | Peak private disk | Public artifact bytes |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | 229.220 s | 5.476 s | 239.163 s | 4,113,645,568 B | 337,077,207 B | 4,817,087 |
| 10,000 | 1,938.011 s | 11.557 s | 1,953.940 s | 4,066,263,040 B | 3,587,399,592 B | 7,190,150 |

Both candidates validated. Parent R peak heap remained about 1.006 GB at both scales, while full traces grew from 101.4 MB to 1.004 GB on disk. Combined RSS conservatively counts shared fork pages per process and includes the supervisor. Disk peaks include earlier scale outputs and caches in the same private directory. Measurements are sampled once per second; some verification activity overlapped the small pilot.

The conservative 100k projection is **23,499.8 seconds**, exceeding the 7,200-second gate. Memory passed at 10k; full-scale time did not. No lower-count candidate is treated as satisfying the 100k requirement. Checkpoints are retained. Further CPU work is needed in numeric/rule execution and trace preparation; more workers alone does not resolve the measured gap.

A post-optimization accepted NL 30-run serial profile sampled 38.14 CPU seconds: the iteration kernel used 23.18 seconds; league-state construction used 8.16 seconds inclusive and knockout pair resolution 7.90 seconds inclusive. Dataframe subsetting remained about 25% inclusive and timestamp parsing about 5.9% self time. These overlap and include small-run setup; they are diagnostic attribution, not full-scale wall predictions.

NL was measured under whole-repository identity `fb8d75cd4ce828652c8cb436ea666a6f3bf05cba8b8bbd2fefab7c405d4da03d` and source snapshot `52609eb7f9163608c0099fcca73f8f215a41e2a6cf279a6712abe72e229a7861`. The later CL-only v5 change preserves the individual NL simulator/executor/reducer/candidate code hashes and accepted parity (see `streaming-nl-v5-applicability.json`). These older global receipts remain diagnostic evidence; they are not promoted as current 100k certificates.

## CL v5 staged scale evidence

| Count | Simulation + aggregation | Candidate validation | Process wall | Peak combined RSS | Trace bytes | Peak private disk |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | 35.519 s | 9.285 s | 50.402 s | 645,201,920 B | 11,928,787 B | 11,937,494 B |
| 10,000 | 313.199 s | 9.477 s | 328.204 s | 644,169,728 B | 119,168,327 B | 131,187,966 B |
| 100,000 | 2,889.782 s | 13.014 s | 2,907.547 s | 644,120,576 B | 1,191,480,594 B | 1,323,510,893 B |

All candidates validated. The final run committed exactly 100,000 iterations in 391 verified chunks, including the uneven final chunk. Supervisor exit status was 0. The complete wall time includes preparation, aggregation and validation; the run stayed below 7,200 seconds and the strict half-RAM limit of 34,359,738,368 bytes on this 64 GiB machine. The final candidate remains `unresolved_draw_procedure` and production-ineligible, as required by absent draw evidence.

All three stages share algorithm `ucl-conditional-league-v5`, seed 7, cutoff `2026-09-01T00:00:00Z`, graph/ledger/rules identities and frozen implementation:

- Implementation: `b5f48920dc8a3b91ed03bb42fd3e4c097a06b5a998cd688a093b973e538ece76`.
- Source snapshot: `ea44d253cea8daf6dc80eb794d8b1738e70e831a721ba61c87570a1afdeb140f`.
- Final measurement SHA-256: `7e1f616c4c9b95cd760c2fc54b431af6b4f74e5abcc0d67561bf38e4bdf7492a`.

Small, hash-bound receipts are committed as `streaming-cl-v5-{1000,10000,100000}.csv` and matching `.resources.json`; the final audit is `streaming-final-verification.json`. Complete traces and checkpoints remain private under `/private/tmp/xgelo-wc-style-certification-v5/cl/`. The interrupted v4 100k attempt is historical diagnostics and cannot resume or certify v5. No long run or public promotion remains active.
