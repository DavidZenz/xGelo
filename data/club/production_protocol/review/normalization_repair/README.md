# Technical repair evidence bound by this pending review

The same 407 raw approved names still resolve to the same 343 club IDs. All
16,277 match identities, clubs, dates, scores and assessed labels remain exact;
all 26 folds and 104 role memberships remain exact. The club registry and fold
registry are distinct objects: a7eece... and 3c6146..., respectively. Full named
parents are recorded in [replacement fold evidence](evidence/replacement_fold_summary.json).

- [42 changed derived registry aliases](evidence/exact42_alias_delta.csv)
- [39 changed computed historical lookup spellings](evidence/exact39_derived_lookup_delta.csv)
- [All 407 raw identity decisions preserved](evidence/all407_identity_preservation.csv)
- [All 104 role sets preserved](evidence/all104_role_preservation.csv)
- [Independent candidate semantic audit](evidence/candidate_corpus_validation.json)
- [Full portable real-reader replay](evidence/portable_reader_verification.json)
- [First-operation cold workloads](evidence/independent_variant_summary.json)
- [Proposed core patch](patches/identity-normalization-v3.patch)
- [Exact authority gates](APPROVAL_GATES.md)
- [Runtime and deferred deployment](RUNBOOK.md)

The complete portable package is retained under
`.planning/operations/cl-normalization-repair-2026-11-05`. Its live verification
scripts use repo/package-relative paths; proof_code holds inspection snapshots
of those same scripts. No main installation, new owner decision or model fit
has occurred. The pending review neither approves CL9 tournament modelling
assumptions nor promises a passing Elo calibration result.
