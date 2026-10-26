# Nations League scale evidence

Date: 2026-10-26. Production 100,000 enablement is **not validated**.

## Inputs and execution

- Executable: `/opt/homebrew/opt/r/bin/Rscript --vanilla`.
- Accepted source: `nl-2026-27-official-uefa-v2`.
- State manifest: `3089fdfdd8e073991c23e62812bd28e324b3c118e6a3ac6d141d44691c3f4c8a`.
- Immutable accepted assets were read from `/Users/davidzenz/R/xGelo`; no source/state/output/publication files there were changed.
- Seed 15017, four workers. The same read-only cached accepted inputs and knockout handoff are reused across scales.
- Knockout forecast preparation: 192.839 seconds; 1,264 ordered model pairs expanded into 2,368 stage contexts. Cached locally outside the repository.
- Runner: `scripts/benchmark_nations_league_scale.R ROOT COUNT CACHE_DIR [WORKERS]`. It validates an outcomes candidate and writes only measurement/artifact-size CSVs. No publication path or durable outcomes write is invoked.

## Measurements

| Simulations | Workers | Simulation seconds | Candidate validation seconds | Raw returned object bytes | Durable artifact bytes |
|---:|---:|---:|---:|---:|---:|
| 10 | 4 | 18.521 | 1.711 | 1,510,376 | 1,065,422 |
| 10 (clean repeat) | 4 | 20.889 | 1.913 | 1,510,376 | 1,065,422 |
| 100 | 4 | 83.022 | 5.522 | 4,366,888 | 2,419,420 |
| 1,000 | 4 | 819.192 | 31.088 | 18,033,576 | 4,817,087 |
| 3 (profile only) | 1 | 19.472 | 1.404 | 986,864 | 711,162 |

The 100-run candidate was validated before an instrumentation error at process exit caused by editing the benchmark script while the process was running. These timings are diagnostic evidence, not a successful full release check. The clean-script 10-run repeat and 1,000 run both exited zero and validated all candidate artifacts. The 10-run repeat retained identical raw object and artifact sizes and recorded parent R heap 864,546,728 bytes. The 1,000 run recorded parent R heap 1,917,904,048 bytes. **10,000 and 100,000 have not been run.**

## Feasibility and limitations

The measured 10-to-100 marginal cost is approximately 0.717 wall seconds per simulation on four workers. Linear extrapolation places 100,000 near 20 hours before candidate materialization. This is an estimate, not a completed benchmark. The simulator retains per-iteration capture tables and stage records, so peak transient memory is larger than the final returned object.

The completed 1,000 run took 13.65 minutes for simulation plus 31.09 seconds for candidate creation/validation. A proportional 100,000 estimate is roughly 22.8 hours; 10,000 approximately 2.3 hours. Those longer scales were withheld after the measured feasibility gate. This work provides the repeatable runner and evidence rather than treating an unexecuted production scale as passing.

`Rprof` on three serial iterations found 8.58 CPU seconds in simulation iterations, including 3.34 seconds constructing sampled league state, 3.00 seconds constructing forecast match rows, and 1.50 seconds validating score grids (overlapping call totals). Fixed score canonicalization took 5.92 seconds and input hashing 2.40 seconds. No single inexpensive invariant cache can remove the dominant sampled work. A broad streaming/vectorization rewrite needs its own full output-parity gate before changing production behavior; it has not been introduced opportunistically.

System peak RSS is unavailable in the restricted environment: `/usr/bin/time -l` fails reading `kern.clockrate`, and process inspection is denied. The runner reports peak **parent R heap bytes** from `gc()` as a lower-bound diagnostic, explicitly excluding child-process RSS and non-R memory. The profiled serial pilot recorded 864,557,960 bytes by that measure.

Ten dedicated scale assertions passed: iteration-seed replay prefix, fixed 100,000th seed, caller RNG preservation, chunk and four-worker sample equality, unresolved/empty NA aggregation, worker clamping, and acceptance of the 100,000 count. These verify deterministic sampling primitives, not an unexecuted 100,000 tournament run.

**Release decision:** retain the incumbent dashboard and block the 100,000 policy switch until a full-scale candidate validates. Never publish a lower-count substitute as meeting the 100,000 requirement.
