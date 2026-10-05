# Nations League online merge

User authorized merging and publishing online on 5 October 2026. Default/deployment branch is `master`; `.github/workflows/deploy-pages.yml` publishes `docs` after pushes there.

- [x] Fetch and compare branches. Preserve newer accepted refresh `26753e0`, including 86 completed matches and original cutoff `2026-10-05T06:30:34Z` (superseded by the validated fresh capture below).
- [x] Resolve registry/generated-output conflicts while retaining revised rules and the EURO priority feature. Preserve unrelated local changes.
- [x] Rebuild state and 1,000 outcomes using the approved model, seed 15017 and accepted cutoff. Check worker replay, complete queue and probability conservation.
- [x] Validate and atomically publish the combined dashboard.
- [ ] Commit the prepared merge and push `master` without force.
- [ ] Confirm GitHub Pages deployment success and verify online content/hash, EURO tab and accepted result count.

Source recovery: the newer master capture referenced raw SHA-256 `95c1e88a...`, which was absent locally. Restored the last genuinely hash-verifiable local predecessor and used the normal validated UEFA acceptance pipeline to accept a fresh capture at `2026-10-05T08:29:50Z`. Fixture and result comparison proves every football value in all 156 master rows is preserved (86 completed); raw evidence is not relabelled or bypassed. Master refresh history and merge parent are retained.

Rebuild verification: 1,000 simulations, seed 15017, eight workers; one/two-worker replay identical. All 54 queues resolved; group-winner and priority totals 14 and 13, expected positions total 1,485; champion / quarter-final / Finals totals 1 / 8 / 4. Atomic outcome read-back passed. All 32 forecast and priority metric columns exactly match the validated rebuild from master’s original 86-result capture; fresh acceptance changes source lineage/cutoff only.

Publication preflight: EURO priority, richer Nations League tables, and shared dashboard suites pass 65 + 197 + 216 = 478 expectations, with zero failures/errors and one existing fixture Git-upstream warning. New batch `phase17-4369b1ed55723354348633f1`; Nations League HTML SHA-256 `38fc1b73aba1cd1aa77da90270eb00ecd8349b057263359e043f5742f6e503f3`. Atomic two-route promotion and manifest read-back passed. Browser confirms 54 complete EURO rows, 86 Results and 156 Fixtures. At 390px, the document remains 390px wide and the focusable 360px table panel contains 828px of content with sticky team cells.

The remaining post-commit remote checks are recorded in the task response and deployment logs.
