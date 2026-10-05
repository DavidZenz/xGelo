# EURO 2028 Nations League priority outlook verification

Completed 5 October 2026. Scope: active Nations League dashboard, independent Article 16 priority policy, joint per-iteration queue, optional dashboard payload, ten-file outcome inventory with explicit nine-file compatibility.

## Authorized cutoff correction

The user requested “fix cutoff and rebuild”. The simulator previously parsed an RFC3339 cutoff as midnight and omitted ten accepted results on 2 October. It now parses full UTC time, including fractional seconds, and production builds pass the accepted source cutoff `2026-10-03T01:00:32Z`. All 70 completed results count; the remaining 86 matches remain scheduled. Shared standings timestamp parsing now preserves the same boundary.

The corrected rebuild retains `phase14-open-nb-incumbent-calibrated-v1`, seed 15017, and 1,000 simulations. Approved source/state/model inputs and the precomputed model handoff were unchanged. Fixture forecast probabilities and expected goals are exactly equal to the incumbent, and all fixture forecast and topology row hashes match; their published files remain unchanged. Aggregate standings, rankings, stage slots, transitions and team paths changed as authorized. The cutoff is hashed in simulation inputs; the rebuilt outcome manifest is bound to the new dashboard batch identity.

## Automated verification

Five rerun suites passed 1,166 expectations with no failures or errors:

- Priority/cutoff/renderer contract: 9 cases, 65 expectations. Includes interim rather than final ranks, complete permutations, 14 group winners and 13 priority winners, correlated aggregation, empirical percentiles, metric-specific missing-input propagation without renormalization, D winner selection, zero/sub-0.1%/missing formatting, unrounded sorting, full fractional-second cutoff boundaries, policy and outcome-bound batch identity.
- Nations League outcomes and production CLI: 41 cases, 630 expectations. Includes legal draws, deterministic worker replay, unavailable score grids/results, explicit legacy compatibility, fresh production dry-run/replay and immutable accepted inputs.
- Dashboard regression: 28 cases, 216 expectations. One existing missing-Git-upstream warning; no failures.
- Shared standings: 13 cases, 236 expectations. A test compared CSV row names rather than registry values; its comparison now resets row names while still checking ordered values.
- Existing cutoff suite: 5 cases, 19 expectations.

Approved-input two-iteration builds with one and two workers produced identical CSV bytes and hashes for every artifact. The final build used eight workers. Production output has 54 complete queue rows; group-winning probabilities sum to 14, winner-priority probabilities to 13, and expected queue positions to 1,485. Title, quarter-final and Finals probabilities sum to 1, 8 and 4 respectively.

Additional adversarial contract checks passed: current inventory requires the queue; recognized legacy inventory remains readable; mismatched queue policy hashes, manifest policy parent hashes and out-of-range ranks fail validation. Injected outcome read-back failure restores incumbent hashes. `git diff --check` passes.

## Browser verification

Codex in-app browser, populated dashboard:

- Direct `#euro-2028` navigation selects the tab. All 54 teams display resolved metrics and flags. Seven genuine-zero probability cells remain visible. The leading order is Portugal, Spain, France, Switzerland and Austria, matching unrounded means.
- League D returns six rows; Germany search returns one with its original average queue position of 13.7. Unmatched search shows the empty-results message; clearing restores all 54 rows.
- Enter opens Portugal’s accessible range disclosure, showing a 10–90% range of 1–3. Probability cells and league badges have minimum computed contrast 6.54:1.
- At 1440 × 900, the table is aligned with no document overflow. At 390 × 844, document width is 390px, the panel is 360px, and its 828px content remains within its focusable horizontal scroller. Keyboard ArrowRight moves the panel by 40px; the team column stays sticky.
- Separate Fixtures and Results views still show 156 and 70 matches. Keyboard section navigation works. The EURO qualifying link opens the companion’s unchanged `pre_draw` state.

Desktop and mobile screenshots are saved in the task visualization directory. The pinned Safari-version gate was not run; these responsive checks use the Codex in-app browser.

## Publication

Validated the rebuilt ten-artifact outcome bundle, wrote it atomically, and validated read-back. Staged both existing dashboard routes, checked exact inventory and file limits, inspected the preview, copied the validated candidate into the publication filesystem parent, and promoted under the existing batch lock with read-back validation.

- Batch: `phase17-fde29c8f279d24294ca5cd58`
- Accepted cutoff: `2026-10-03T01:00:32Z`
- Nations League HTML SHA-256: `ebef3765ba0fd289d2718defcc240944765ecb2e05015662ace24537e2bd9415`
- Published HTML hash equals the inspected preview hash.

Local publication is complete. No live push or remote deployment was requested. UCL, unrelated GSD milestone state, and unrelated working-tree changes are preserved.
