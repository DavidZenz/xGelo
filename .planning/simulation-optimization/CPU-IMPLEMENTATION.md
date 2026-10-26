# CL then NL CPU implementation — 2026-10-26

The CL optimization is committed as `ca9119a`. NL numeric ranking, prepared
knockout paths, chunk counters and trace storage are integrated. Exact
compatibility checks pass. The first frozen cycle validated CL through 100k
and NL through 10k; NL's conservative time gate withheld 100k. A second CPU and
storage cycle is undergoing verification. No public promotion is active.

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
- Focused storage checks pass 81 assertions, including format downgrade,
  corruption, missing/overlapping/trailing records, selective decoding and
  exact canonical hashes under Unicode, schema changes and multiple merge
  passes. The existing streaming suite passes 44 assertions; the Python merge
  helper passes five tests with instrumented merge fan-in and failure coverage.
- The 32-iteration kernel profile is diagnostic only: it includes cold caches,
  profiler instrumentation and concurrent test activity. It is not a scale
  certificate or an overall speed estimate. See `cpu-implementation/`.

## Scale gate

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
Integrated compatibility/regression and resource gates remain required.

After regressions, freeze all R and benchmark/supervisor source bytes and run
fresh CL then NL processes at 1k and 10k. Admit each 100k run only when the
conservative 20% time margin projects at most 7,200 seconds including preparation
and candidate validation, observed memory is below half RAM, and disk headroom
passes. The watchdog enforces those limits automatically. Failed gates retain
checkpoints. Long jobs are checked every 30 minutes as requested.

CL scale evidence remains explicitly synthetic and production-ineligible.
Production authority and publication phases remain separate. Tracked `docs/`,
`data/` and `outputs/` bytes are unchanged from `16f81f2`; WC publication SHA-256
remains `bc540c9d1014095e5d10b2ddc06b73d105c13cd8db7efee6c46bf2d6e86f56b7`.

## Pre-existing authority failure

The expanded source-acceptance regression fails four cases with one warning:
the stored provider acceptance manifest's `review_sha256` differs from the
current owner review. Both frozen `6c13de0` and current modules reproduce the
same integrity error in fresh R processes. The two modules and seven protected
acceptance files match that baseline byte for byte.

Commit `9b06e48` approved seven rows of `provider_terms_review.csv` without
updating its generation manifest or current pointer. The persisted hash exactly
matches the preceding pending review. This is an authority-data repair for its
separate workflow; optimization leaves those bytes intact and does not bypass
the production rejection. Source-bundle and adversarial suites separately pass
72 and 60 assertions. Initial nested-R PATH failures were rerun successfully
with the configured R binary directory, and are retained in the evidence.

This prevents an unconditional all-regressions-green or CL production claim.
It does not authorize or block fixture-only performance measurements, or change
the accepted national inputs. See `cpu-implementation/authority-review.json`.
