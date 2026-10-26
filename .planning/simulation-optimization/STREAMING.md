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
