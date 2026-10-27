# CL then NL CPU implementation — 2026-10-27

Both competitions passed the full 1k → 10k → 100k performance gates on the
final frozen source. NL's 100k run took 5,144.1 seconds (85.7 minutes), including
candidate validation, with 5.31 GiB peak combined RSS. CL's fixture 100k took
1,073.0 seconds (17.9 minutes), with 0.64 GiB peak combined RSS. Exact reference
compatibility checks pass, and dashboards and accepted artifacts are unchanged.
All benchmark processes have exited. No public promotion occurred.

Implementation commits, in order: `ca9119a` (CL first), `08d5a35` (NL numeric
paths/counters and bounded traces), `fa7969a` (NL canonical/typed rows and
compressed statistics), and `8e36a58` (guarded numeric transition selection).

## Changes

CL prepares canonical framing for iteration seeds and Article 18 rule traces,
and creates explicitly typed ranking/trace rows. Corrected football algorithm
`ucl-conditional-league-v5` and all authority/uncertainty policies are unchanged.

NL prepares integer team/fixture indexes, shares numeric match contributions
between group standings and Article 19 arithmetic, and handles distinct-point
and two-team ties directly. Complex ties and unsupported evidence use the
existing reducers. Prepared private knockout helpers reuse fixed topology,
official fixture indexes and legal draw traversal, construct typed rows, and
resolve unambiguous scores directly. Extra time, penalties, missing evidence
and unsupported cases retain the authoritative reducers.

Chunk counters update vectors and histograms immediately, allocating one
representative row per distinct key. They convert to the existing merge shape
once per chunk. Ranking captures are reused, immutable metadata is prepared
once, and mean records are constructed in one frame while retaining original
observation order and R mean semantics.

Storage v2 separates exact-mean records from football rows, records hash-bound
schema exemplars, and selects only the requested streams for decoding. Every
read checks all payload hashes against bounded buffers; full candidate
validation checks reconstructed schemas, coverage and trailing records.
Materializers preserve logical field order, attributes and NULLs. Chunk
formats are bound to their manifests, including the no-sidecar case, and
unknown formats fail explicitly. Genuine v1 stores remain readable; incompatible
resume fails. Storage metadata stays outside football artifact identities.

Canonical hashing now writes sorted gzip runs of at most 4,096 encoded rows
per field and merges at most 32 streams at once. The original hex sort keys,
base64 row payloads, header and record separators are preserved. A standard
library Python helper verifies compressed checksums, ordering, row counts and
key/payload agreement while hashing incrementally; no complete plaintext sort
input, sorted copy or canonical copy is retained. Bounded last-column caches
skip repeated metadata normalization/encoding. The helper's bytes are bound
into repository/checkpoint identity. Streaming NL hashing requires `python3`
on PATH; ordinary in-memory library calls keep their existing return shape.

## Compatibility evidence

- CL: all 64 saved samples, full rankings, rule traces, hashes and caller RNG
  match the frozen reference. The initial CL regression gate passed 578
  assertions before NL integration.
- Accepted NL: complete returned objects, hashes and all candidate CSV bytes
  match reference `6c13de0` at seeds 7, 31 and 15017, count 7, one/three workers,
  and uneven chunk sizes 2/3. An interrupted accepted run resumed with three
  workers also matches exactly. Accepted source/model inputs were revalidated.
- A separate accepted three-iteration comparison matches the earlier saved
  legacy reference and candidate bytes.
- First-cycle focused storage checks passed 81 assertions, including format downgrade,
  corruption, missing/overlapping/trailing records, selective decoding and
  exact canonical hashes under Unicode, schema changes and multiple merge
  passes. The streaming suite passed 44 assertions; the Python merge helper
  passed five first-cycle tests with instrumented fan-in and failure coverage.
- The 32-iteration kernel profile is diagnostic only: it includes cold caches,
  profiler instrumentation and concurrent test activity. It is not a scale
  certificate or an overall speed estimate. See `cpu-implementation/`.

## Final frozen scale certification

Source snapshot:
`9bac1d4f6f8c84b4f8d18ba7c11b51c311c63a8da858eec5745cb9680f11e404`.
Implementation identity:
`32cd661dd3aa7eb22d195bf45ac1f56355592a47fcd5a70b4d02c9675f1a0762`.

Every stage ran in a fresh R 4.6.1 process, with four persistent workers and
256-iteration chunks. Large competition jobs ran sequentially. Final NL pilots
ran first; their unchanged conservative gate admitted 100k at a projected
7,117.1 seconds. Final CL 1k/10k/100k then ran sequentially, followed by NL 100k
after rechecking pilot measurement hashes, accepted inputs, source and disk
headroom. No time, memory, disk or correctness gate was relaxed.

| Competition | 1k wall | 10k wall | 100k wall | 100k peak combined RSS |
| --- | ---: | ---: | ---: | ---: |
| CL fixture | 30.0 s | 127.5 s | 1,073.0 s | 0.635 GiB |
| NL accepted | 298.0 s | 569.0 s | 5,144.1 s | 5.311 GiB |

Both 100k runs are below the 7,200-second limit and the 32 GiB memory limit
(half this machine's 64 GiB). Wall times include preparation, simulation,
aggregation, candidate validation and process overhead. The watchdog measured
the combined parent/worker/helper process tree, enforced limits automatically,
and checked disk headroom. Manual progress checks were 30 minutes apart.

| 100k phase / storage | CL fixture | NL accepted |
| --- | ---: | ---: |
| Preparation | 7.614 s | 13.660 s |
| Simulation | 968.471 s | 3,542.797 s |
| Aggregation | 5.799 s | 1,411.431 s |
| Candidate validation | 90.761 s | 174.411 s |
| Complete audit traces | 1,186,058,078 bytes | 1,876,334,542 bytes |
| Peak measured stage-directory disk use | 1,317,306,117 bytes | 2,981,589,544 bytes |

NL uses accepted bundle `nl-2026-27-official-uefa-v2`, seed 15017 and state
manifest `3089fdfdd8e073991c23e62812bd28e324b3c118e6a3ac6d141d44691c3f4c8a`.
Its first pilot prepared the forecast handoff (209.778 seconds); subsequent
fresh processes reused the identical validated handoff cache. The 100k wall
includes its own 13.660-second preparation. This certifies the accepted-input
pipeline, with no new data acquisition or model training.

CL retains corrected football algorithm `ucl-conditional-league-v5`, seed 7,
cutoff `2026-09-01T00:00:00Z` and the same synthetic graph/ledger/rules identities
across all stages. Its status remains `unresolved_draw_procedure`; unavailable
knockout forecasts and missing draw evidence remain explicit. The final 100k
is 2.71 times faster than the prior corrected v5 2,907.5-second receipt. Fixture
performance is not production source/model authority.

Each 100k run contains exactly 100,000 iterations in 391 committed chunks,
including the final 160-iteration chunk. Candidate validation completed before
the success receipt. After the benchmark processes exited, an independent
bounded pass reverified every payload checksum, manifest fingerprint, source
binding, inventory and exact iteration coverage. This extra post-run audit is
separate from the required candidate validation already included in wall time.
Complete checkpoints remain at `/private/tmp/xgelo-cpu-certification-v3/`.

The final regression gate records 3,684 passing R assertions across 33 suite
scopes, 11 Python tests and the EURO replay. After the selector change, all 22
affected national scopes ran fresh in three independent test processes;
unchanged CL/common/Python and two passing source-authority scopes were reused
explicitly after byte comparison against `fa7969a`. Full accepted parity and
interrupted resume were repeated at the final source identity. The separate
pre-existing provider-acceptance failures below remained at certification; an
unconditional all-regressions-green claim was not made. Their subsequent
authority-data repair is recorded separately below.

All 40 retained accepted 10k chunks across the three optimization cycles have
identical reconstructed traces, schemas and semantic reducer statistics. Every
payload hash was reverified against its own manifest. The private storage
changes altered compressed trace bytes. Exact public candidate CSV byte
comparisons are covered by the accepted reference/resume checks above.

Compact measurements, resource receipts, checkpoint coverage proof and the
exact staged driver are in
[`cycle-3/final-scale/index.json`](cpu-implementation/cycle-3/final-scale/index.json).
The final gate is [`final-regressions-v3.json`](cpu-implementation/final-regressions-v3.json).
No full traces, private model binaries or accepted football data are committed.

## Historical scale iterations

First-cycle frozen source `43c48ab34a0f0b78951cdf35df5d73d5f010e8362687a8c44f1a9a12134999c5`
and implementation `da6eb5327bebce1c0886c1c5b63185e9617640c71079e75af65fa1320d8d1d8b`:

| Competition | 1k total | 10k total | 100k total | Peak combined RSS |
| --- | ---: | ---: | ---: | ---: |
| CL fixture | 27.8 s | 128.2 s | 1,044.1 s | 0.637 GiB |
| NL accepted | 316.8 s | 864.4 s | Withheld | 5.027 GiB |

CL's 100k is 2.79 times faster than the prior corrected v5 receipt. NL's 10k
includes 652.5 seconds simulation, 177.6 seconds aggregation and 19.5 seconds
candidate validation. Its 10,649.8-second conservative projection fails the
7,200-second admission gate. Checkpoints and compact receipts are retained in
`cpu-implementation/cycle-1/`. These receipts describe their frozen source;
they do not certify subsequent code changes.

The second cycle prepares canonical columns once, fuses private row/table
hashing and uses guarded primitive row construction/binding. Public rule
functions and unsupported/custom-schema fallbacks remain intact. Checkpoint
statistics use level-1 gzip with manifest/commit codec binding, serialized
size/CRC metadata and full verified-buffer decoding. Historical readers remain
available. Canonical merge intermediates created by the same process retain
SHA, CRC, order and count checks while avoiding repeated key reconstruction.
All storage metadata remains outside public football identities.

The second-cycle source `5e9cea95125135a2c1fa59ee28e386bdb053a3d9cd7e69f46b651b6c6cbd4c59`
passed complete accepted parity/resume and the regression gate (3,621 R
assertions, 11 Python tests; the known authority failure remains separate).
Accepted NL 1k/10k validated in 305.5/612.5 seconds. At 10k, simulation took
418.1 seconds, aggregation 154.4 seconds and candidate validation 24.2 seconds.
Trace storage fell to 187,716,238 bytes from 990,203,833 bytes. Peak combined
RSS was 5.006 GiB. The 7,642.7-second conservative projection still withheld
100k; all checkpoints and pilot receipts are retained.

The follow-up selector replaces repeated row filtering with rank indexes and
a prepared transition plan only for the identical revised rules and a complete,
ready canonical ranking. Unknowns, missing evidence, custom schemas and legacy
rules use the original selector. The private prototype passed 63 focused
assertions and nine complete accepted iterations, with all 27 guarded selector
calls producing identical full rows, hashes, types, attributes and RNG state.
Integrated accepted parity/resume, affected regressions and all final resource
gates subsequently passed on the frozen identity recorded above.

The admission policy requires frozen R/benchmark/supervisor source bytes and
fresh 1k/10k processes before 100k. Its conservative 20% time margin must project
at most 7,200 seconds including preparation and candidate validation, observed
memory must stay below half RAM, and disk headroom must pass. The watchdog
enforces those limits automatically. Failed gates retained checkpoints. Long
jobs were checked every 30 minutes as requested.

CL scale evidence remains explicitly synthetic and production-ineligible.
Production authority and publication phases remain separate. At certification,
tracked `docs/`, `data/` and `outputs/` bytes were unchanged from `16f81f2`; WC publication SHA-256
remains `bc540c9d1014095e5d10b2ddc06b73d105c13cd8db7efee6c46bf2d6e86f56b7`.

## Authority failure at certification and subsequent repair

At certification, the expanded source-acceptance regression failed four cases with one warning:
the stored provider acceptance manifest's `review_sha256` differs from the
current owner review. Frozen `6c13de0` and the optimized modules reproduced the
same integrity error in fresh R processes using the pre-repair data. The two
modules and seven protected acceptance files matched that baseline byte for byte.

Commit `9b06e48` approved seven rows of `provider_terms_review.csv` without
updating its generation manifest or current pointer. The persisted hash exactly
matches the preceding pending review. This required an authority-data repair
through its separate workflow; optimization left those bytes intact and did
not bypass the rejection. Source-bundle and adversarial suites separately passed
72 and 60 assertions. Initial nested-R PATH failures were rerun successfully
with the configured R binary directory, and are retained in the evidence.

Those failures prevented an unconditional all-regressions-green claim at
certification. See `cpu-implementation/authority-review.json` for the unchanged
historical evidence.

The subsequent authorized [authority manifest repair](../authority-manifest-repair/SUMMARY.md)
restores the original historical review and selects a coherent new generation
containing the genuine approved review unchanged. The full Phase 18 gate now
passes 143 tests and 861 assertions. Published bytes, runtime source and
benchmark football inputs remain unchanged. The provider still records
`missing_credential` with automation disabled; production source/model and
publication gates remain separate.
