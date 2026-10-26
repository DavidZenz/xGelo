# NL/CL second performance audit — 2026-10-26

Scope: explain the unmet NL two-hour target and CL's remaining 48-minute cost,
then measure plausible improvements without changing football behavior or
published artifacts. Existing scale receipts remain bound to their measured code.

1. Reconcile certified wall times with simulation/aggregation/validation phases
   and WC's actual workload. Distinguish correctness/memory work from CPU work.
2. Inspect NL, CL and shared executor independently; use bounded serial kernel
   profiles and component timings on accepted NL inputs / fixture-only CL inputs.
3. Measure repeated immutable parsing, score-grid normalization, seed encoding,
   dataframe construction, ranking and trace costs. Assess worker utilization
   and chunk scheduling using short controlled probes rather than another 100k run.
4. Prototype selected optimizations only in private audit environments. Compare
   full returned objects and RNG state with the current reference, and record
   measured speedups separately from unmeasured recommendations.
5. Save reproducible evidence, prioritize implementation work with compatibility
   and certification gates, update maintenance state and commit the audit.

No new scale certification, source/model acquisition, publication or promotion
is included. No production simulator code is changed by an audit-only prototype.
The user's 30-minute polling preference remains in force for any running jobs.

Status: complete. Source inspection, fresh kernel/component profiles and bounded
exact-parity prototypes are recorded in `DEEP-AUDIT.md`. CL's prepared frames/row
prototype achieved 3.06× kernel throughput; NL's scalar-row probe achieved 1.20×,
while simple preparation memoization showed no reliable gain. Hoisting NL
metadata improved the checked canonical-hash phase by 1.70×. Production code
and published artifacts are unchanged; no new scale certificate is claimed.
