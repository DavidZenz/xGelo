# WC-style streaming implementation — 2026-10-26

Baseline: `16f81f2`. CL correctness committed separately as `9a19a04`.

## Implementation

- CL v4 standings combine cutoff-eligible actual results with an explicitly identified sampled overlay; no accepted timestamps or source rows change. The same counted rows supply ranking criteria.
- Persistent workers produce 256-iteration chunks with complete compressed traces and compact reducer statistics. Atomic chunk rename is the commit marker after IDs, fingerprint and SHA-256 checks. Partial chunks have no authority.
- Resume binds complete accepted input and model/rules hashes, code dependencies, R/RNG environment, requested count and chunk size. Worker count is operational and can change. A run lock prevents overlap.
- NL reducers preserve first-observed ranking rows, conditional statistics, suppression/reason precedence, modal bracket choices and type-1 EURO queue percentiles. Exact R means require a disk pass: only one <=100k scalar series is materialized (<=0.8 MB), never complete histories. This avoids one-bit regrouping changes found on the accepted snapshot.
- Full legacy materialization is explicit. Outcome builders use compact summaries and verify trace access; no silent empty-frame fallback is permitted. Canonical trace hashes retain the existing framing and sort order with bounded external sort.
- Private NL ranking helpers hash normalized columns without per-row dataframe allocation, reuse rules hashes and indexed standings templates, and preserve original reducers for complex/missing-evidence cases.
- Resource supervision covers preparation through candidate validation, owns/kills only its subprocess group, and records combined RSS once per second. Its 100k preflight uses a 20% margin on measured fixed-plus-marginal total time, half physical RAM, matching input/code lineage and sufficient disk.

## Verification in progress

- Accepted NL 3-run baseline comparison: every returned table, metadata field, canonical hash and candidate CSV byte is identical after legacy materialization.
- Focused streaming tests cover serial/parallel/recovery/alternate workers, corrupt/missing/extra chunks, manifest tampering, sink failures, exact UTF-8/control-character canonical hashes, alternate NL seeds and unavailable forecasts, and corrected CL full-object parity.
- Production CL CLI remains `production_human_needed` with unchanged selectors and incumbent state.
- Scale results will be recorded below after fresh process checks. No publication occurs.

## Current verification

- National gate completed all 17 commands: EURO replay and 16 unfiltered suites.
- Streaming suite: 38 assertions including exact canonical framing, recovery, full object parity and alternate seeds/suppression. Release-safety suite: 49 assertions including implementation, time, RSS and measurement-hash rejection.
- Four Python watchdog tests pass, including cumulative active-time accounting, exhausted/unfinalized attempt rejection, disk measurement and cleanup of an orphan worker after parent exit.
- Accepted NL baseline comparison passes after the final vectorized hash/grouped-mean optimization; every table/hash and every candidate CSV byte is identical.
- World Cup publication SHA-256 remains `bc540c9d1014095e5d10b2ddc06b73d105c13cd8db7efee6c46bf2d6e86f56b7`; no public/accepted competition files changed.
- Pilot discovery: exact mean spooling had a repeated per-key scan. The final implementation groups each bounded chunk once and encodes unique canonical-column values once per frame. Both preserve exact reference parity.

Scale supervisor code now includes source freezing across stages, actual peak private disk usage, cumulative active time across resumed attempts, measured process-tree RSS including the supervisor, and strict refusal to certify an unfinalized hard-crash attempt. Interrupted exploratory pilot directories remain private diagnostics under `/private/tmp/xgelo-wc-style-scale*`; their old code-bound receipts do not certify the final implementation. The final staged run uses `/private/tmp/xgelo-wc-style-certification`.

The complete fresh CL regression run passed all 530 assertions across six suites, with no failures, warnings or skips. A post-optimization accepted NL 30-run serial profile sampled 38.14 CPU seconds: the iteration kernel used 23.18 seconds, league-state construction 8.16 seconds inclusive, and knockout pair resolution 7.90 seconds inclusive. Dataframe subsetting remained about 25% inclusive and timestamp parsing about 5.9% self time. These overlap and include small-run fixed setup; they are diagnostic attribution, not full-scale wall-time predictions.

## National scale evidence (unchanged NL implementation)

| Count | Simulation + aggregation | Candidate validation | Process wall | Peak combined RSS | Peak private disk | Public artifact bytes |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | 229.220 s | 5.476 s | 239.163 s | 4,113,645,568 B | 337,077,207 B | 4,817,087 |
| 10,000 | 1,938.011 s | 11.557 s | 1,953.940 s | 4,066,263,040 B | 3,587,399,592 B | 7,190,150 |

Both accepted NL candidates validated. Parent R peak heap remained about 1.006 GB at both scales, while full traces grew from 101.4 MB to 1.004 GB on disk. Combined RSS includes the supervisor and conservatively counts shared fork pages per process; the disk peak includes the cache and previously completed scale outputs in the same private directory. Measurements are sampled once per second. Some verification activity overlapped the small pilot; these are measured host results, not a guaranteed idle-host runtime.

NL 100k was **withheld**, not run: conservative projected total `23499.8 seconds` (6.53 hours) exceeds the 7,200-second gate. The memory objective passed at 10k; the two-hour full-scale time objective did not. No lower-count candidate is promoted as satisfying the 100k requirement. Further CPU work belongs in numeric/rule execution and trace preparation; adding workers alone does not solve the remaining gap.

Whole-repository identity at the NL measurement: `fb8d75cd4ce828652c8cb436ea666a6f3bf05cba8b8bbd2fefab7c405d4da03d`. Source snapshot: `52609eb7f9163608c0099fcca73f8f215a41e2a6cf279a6712abe72e229a7861`. CL checks continue sequentially under the same frozen code.

## CL scale checks in progress

CL fixture candidates validated at 1k (49.312 s total; peak combined RSS 645,529,600 B) and 10k (326.410 s total; peak combined RSS 644,595,712 B). Input, graph, ledger, rules, seed and algorithm v4 identities match across both. The resource gate admitted one 100k mechanics check, conservatively projected at about 3,937 seconds. This is synthetic fixture evidence and remains production-ineligible.

Active supervisor session: `46939`; output root `/private/tmp/xgelo-wc-style-certification`; current stage `cl/run-100000`. Code is frozen at commit `3ebd15f` after the separate CL fix `9a19a04`. Do not edit R/scripts or restart the checks: the supervisor deliberately rejects source changes. After completion, save the final CSV/resource JSON, verify no owned workers remain, update maintenance status, and commit the evidence. The supervisor is expected to exit 2 if CL passes because NL's 100k feasibility gate was correctly blocked. No public promotion is authorized by scale success.

## Additional CL availability correction (v5)

A fresh missing-forecast probe exposed an interaction with the cutoff fix: one required unsampled future fixture still allowed 27 resolved league-band rows from a partial projected season. The corrected ranker retains known points/goals and sampling records but leaves every league rank/band unresolved whenever any required fixture has neither a cutoff-eligible accepted result nor an eligible sampled projection. Required fixtures include unfinished league rows even though their current `counts_for_standings` flag is false. Completed rows explicitly excluded from standings retain their exclusion policy.

The reproduced probe now emits zero resolved league-band rows. Algorithm/run identity is v5; the interrupted v4 100k attempt is not a certificate. Existing v4 chunks/receipts are retained privately and cannot resume as v5. CL 1k/10k/100k will be rerun under `/private/tmp/xgelo-wc-style-certification-v5` after focused and regression checks. NL component hashes are unchanged (see `streaming-nl-v5-applicability.json`), and its measured 100k time-gate failure still applies; its prior whole-repository receipt is not promoted as a new global certificate.

The v5 focused suite passes 44 assertions, including explicit zero resolved probabilities with one unavailable required forecast and exact memory/streamed parity in that case. The accepted NL complete-output/candidate-byte comparison also passes after this CL-only change.
