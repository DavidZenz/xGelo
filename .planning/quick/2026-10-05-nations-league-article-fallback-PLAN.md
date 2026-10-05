# Nations League official article fallback

1. Keep the structured UEFA match endpoint as the primary source. On a bounded retrieval failure, fetch only the fixed English UEFA league-phase results article.
2. Parse all 156 match links by UEFA fixture ID. Require exact fixture coverage, valid score text, stable team identities, and no loss of completed results. Overlay only final scores and statuses on the last accepted, hash-verified UEFA match inventory.
3. Store a replayable composite capture containing the exact article and baseline response bytes. Extend raw handoff to reparse this capture and keep the existing atomic source acceptance and dashboard wrapper unchanged.
4. Add focused offline tests for success, incomplete/ambiguous article content, and no fallback on primary schema failures. Run the focused tests and the wrapper probe; publish only if the full validation and pipeline pass.

## Verification (2026-10-05)

- Focused fallback tests: 9 passed. Production Nations League contract tests: 63 passed.
- Live UEFA article: all 156 fixture IDs matched the accepted inventory; 86 results were complete.
- Live primary and forced article-fallback dry-run candidates both passed source validation. The wrapper's live primary dry run detected changed normalized content.
- The broader Phase 13 test file has pre-existing fixture setup failures because its temporary registry lacks `competition_editions.csv`; these do not exercise the article fallback.
