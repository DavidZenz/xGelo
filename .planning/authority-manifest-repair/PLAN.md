# CL authority manifest repair — 2026-10-27

Scope: UCLSRC-01 maintenance, authorized by the request to repair the provider
review/manifest mismatch. Published dashboards must remain byte-identical.
This does not authorize a live probe, source acquisition, model promotion or
dashboard publication.

1. Reproduce the selected generation's `review_sha256` rejection and snapshot
   published files, protected football artifacts and the approved review bytes.
2. Restore the historical generation's original pending review exactly from
   Git before `9b06e48`. Verify that its original manifest/pointer validate
   without changing their hashes or evidence timestamps.
3. Preserve the genuine September 25 approved review unchanged in a new
   immutable generation. Build a new manifest with the existing not-run
   machine/schema/edition evidence and a truthful current decision timestamp.
   Validate and install it with `phase18_publish_acceptance_generation()` and
   its atomic pointer writer. Automation must remain disabled with
   `missing_credential`; no network or credential access is needed.
4. Update the outdated pending-review assertion and add regressions for a
   coherent approved/no-key generation, valid historical generations, manifest
   binding/timestamp order and strict rejection of altered review evidence.
   Production authority readers and validators remain unchanged.
5. Run the complete official eight-file Phase 18 fresh-process gate, then the
   affected Phase 19 production-authority and CL authority/simulation suites.
   Verify no checks mutate durable evidence or published bytes. Simulation
   code and accepted NL/CL-fixture benchmark inputs stay unchanged, so existing
   performance certificates remain historical evidence of the same source.
6. Save repair provenance and checks, update maintenance state and commit only
   the authority repair, regressions and documentation. Keep all production
   source/model gates fail-closed and do not advance milestone completion.

Use the existing working branch `codex/active-dashboard-improvements` in
`/private/tmp/xgelo-active-dashboards`; preserve the user's original checkout.
If any long-running check is needed, inspect progress at most every 30 minutes
as requested. No large simulation run is part of this repair.

Completed: the authority repair, full Phase 18 gate, all seven CL suites and
the Phase 19 domain-contract suite pass (16 fresh-process scopes, 248 tests,
1,544 assertions). Three fixture pipeline cases also pass. The extended
Phase 19 targets case is blocked by missing `glmnet`/`ranger`, reproduced with
the pre-repair code/data; see `SUMMARY.md` and `evidence/index.json`. Runtime
source, published files and football benchmark inputs are unchanged. No
unconditional full-pipeline or production-authority claim is made.
