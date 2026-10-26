# Active dashboard implementation — 2026-10-26

## Result

Source implementation is complete for the active Nations League and EURO
qualifying views. Production release is **blocked**, not passed. World Cup and
Phase 21 migration are excluded. Changes were developed in the isolated branch
`codex/active-dashboard-improvements` at `/private/tmp/xgelo-active-dashboards`.

## Implemented

- One truthful Nations League match filter toolbar, deduplicated upcoming versus
  completed match lists, chronological date controls, explicit UTC kickoffs and
  52/52 remaining-fixture coverage for the incumbent accepted snapshot.
- Shared native Follow team selection, cross-tab highlights, filtered matches,
  a Groups-only group selector, keyboard tab navigation and scoped hidden states.
- Qualification/elimination badges require explicit accepted status; Monte Carlo
  extremes no longer establish mathematical certainty.
- EURO pre-draw waiting page, with the expected milestone taken from accepted
  metadata and full lineage retained in details and the unchanged payload.
- Compact legal-draw details, readable tree labels and stage-event probabilities.
  Independent slot projections are explicitly distinguished from one joint
  bracket, because the incumbent data can place the same team in alternate slots.
- Exclusive updater lock, force rebuild, working R runtime discovery, a 100k
  public minimum, and a simulator-hash-bound successful benchmark receipt
  prerequisite. Missing evidence blocks rebuilds before accepted-data mutation.
- Nightly publication shares the real coordinator gates; no browser bypass is
  used in production. Regression commands are unfiltered, fail on zero assertions,
  and provide the R runtime to nested CLI tests.
- A real Safari WebDriver runner verifies viewport dimensions and exercises the
  staged UI; candidate failures retain the incumbent public batch.

## Verification

Focused suites pass:

| Suite | Assertions | Result |
|---|---:|---|
| Active dashboard improvements | 72 | Pass |
| Nations League dashboard revision | 197 | Pass |
| Phase 21 publication compatibility | 46 | Pass |
| Dashboard release safety | 43 | Pass |
| Simulation scale primitives | 10 | Pass |

The full Phase 17 dashboard suite also passes, with its existing isolated Git
upstream warning. Phase 13 publication hashes, manifests, transaction, integration
and refresh-failure suites, plus Phase 15 and Phase 16, pass. Broad gates exposed
old test-fixture drift: four test helpers were corrected for canonical
`source_status` and the current incumbent lifecycle. No production rule,
registry or model changes were made to satisfy these tests.

An independent renderer review found and reproduced two regressions before
release: idless legacy fixtures collided, and live generic scores were treated
as final. Both are fixed and regression-tested. Legacy accepted final scores
without a terminal-status field also override stale scheduled fixture state.

Bash/Python/R syntax, emitted JavaScript syntax and `git diff --check` pass.
The staged two-route envelope satisfies its existing inventory/hash/size gates.
Both staged payload JSON files are byte-identical to the incumbent files.
`docs/wc2026` matches baseline-worldcup.json byte-for-byte.

The in-app browser at verified **1280x720** confirms correct two-match Austria
filtering, selected-team persistence, keyboard tab changes, a clean EURO waiting
state, tree disclosures and no captured JavaScript errors or page-wide desktop
overflow. Screenshots are saved at:

`/Users/davidzenz/.codex/visualizations/2026/10/26/01a1773c-2849-7c81-b46e-bfe586c7d35d/dashboard-implementation/`

## Outstanding release gates

1. **Full-scale benchmark:** 1,000 accepted simulations validated in 819.192s,
   with 31.088s candidate validation and approximately 1.918GB peak parent R heap
   (worker RSS excluded). The approximately 23-hour 100k duration is an estimate,
   not a passing run. Neither 10k nor 100k was executed. See SCALE.md and its CSVs.
2. **Formal browser acceptance:** the real Safari launch approval request was
   cancelled, so it produced no acceptance evidence. The in-app browser ignored
   a requested mobile resize and still reported 1280x720; this was rejected as
   mobile evidence. Required 1440x900/390x844 acceptance remains unverified.

No live promotion, public HTML modification or deployment was performed. Do not
enable publication by lowering the sample count or bypassing the browser gate.
RUNBOOK.md contains the exact remaining certification and recovery procedure.

## Environment notes

R was found at `/opt/homebrew/opt/r/bin/Rscript` after the conventional binaries
were absent. The isolated checkout needed existing ignored source evidence and
the genuine approved model copied from the original checkout. Raw source bytes
were checked against their accepted hashes; normal release validation verified
the model. These local assets are not included in the implementation commit.
The original checkout's pre-existing modifications were preserved.
