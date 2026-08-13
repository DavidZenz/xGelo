# Project Research: Shared UEFA Competition Dashboard Architecture

## Proposed data flow

```text
Official UEFA pages / exports
        + open international results
        + audited manual snapshots
                    |
                    v
        source adapters + snapshot manifests
                    |
                    v
        canonical competition registry
        teams / groups / fixtures / statuses
                    |
          +---------+---------+
          |                   |
          v                   v
   competition state      model feature view
   standings + rules      Elo/xG/form/context
          |                   |
          +---------+---------+
                    v
           match forecast layer
           calibrated 1X2 + goals
                    |
                    v
           competition simulators
           standings + paths + odds
                    |
                    v
        compact JSON payload + CSV audit files
                    |
                    v
       two dedicated static dashboards
```

## New boundaries

### Source adapters

`uefa_competition_source.R` should normalize official pages or exports into a stable internal schema. It should not calculate standings or probabilities. The adapter must record source URL, retrieval time, raw hash, parser version, and fallback status.

`open_results_source.R` should reuse the existing international-results ingestion for historical form and model inputs. Competition labels must be normalized to stable IDs such as `uefa_nations_league` and `uefa_euro_qualification`.

### Competition registry

Use one registry with one row per competition edition and explicit lifecycle state:

- `pre_draw`
- `scheduled`
- `in_progress`
- `complete`
- `blocked`

Each registry entry points to its groups, fixtures, regulations, source snapshot, ruleset, model release, and dashboard output directory.

### Rules engine

Use a ruleset interface rather than branching inside the UI:

- `validate_competition_structure()`
- `compute_standings()`
- `rank_tied_teams()`
- `enumerate_remaining_paths()`
- `simulate_competition_outcomes()`
- `format_outcome_labels()`

The Nations League ruleset must support league A-D, different group sizes, overall rankings, two-legged play-offs, League A quarter-finals, and the conditional C/D play-off. The EURO ruleset must support groups of four/five, best-runner-up ranking, hosts, and the three possible play-off topologies.

### Model boundary

The existing released model consumes a point-in-time match feature frame. The competition layer supplies only match context and the correct date/venue/team identity. Competition state affects simulation and outcome labels; it must not overwrite the historical model training contract or leak future standings into pre-match features.

### Dashboard payload

Keep the existing split between R-generated compact JSON/CSV payloads and static HTML/JavaScript. A payload should include:

- metadata and release identity;
- source and ruleset hashes;
- competition state;
- teams, groups, fixtures, standings, and form;
- match forecast rows and scoreline rows;
- projected outcome probabilities;
- warnings, fallback status, and data credits.

The renderer should be competition-agnostic. It receives a payload and a small competition display configuration; it must not reimplement rules or infer standings.

## Refresh transaction

1. Acquire candidate official snapshots into a unique staging directory.
2. Validate source schema, hashes, date ranges, team identity, and competition structure.
3. Build model features and forecasts from the latest accepted release.
4. Run deterministic simulations with a recorded seed and bounded support.
5. Validate all dashboard payloads, freshness, output coverage, and release links.
6. Atomically promote each successful competition bundle while retaining the prior bundle.
7. Commit and push changed code/manifests/compact outputs only when the repository is clean and upstream-aligned.

If one competition fails validation, do not publish a partial mixed timestamp. Keep the previous successful bundle for the failed competition and mark the batch as failed in the log.

## Build order

1. Canonical schemas, source snapshot contract, and competition registry.
2. Shared standings/form/fixture layer and source adapters.
3. Nations League rules and dashboard because its 2026/27 groups and fixtures are already published.
4. EURO qualifying rules and pre-draw dashboard state.
5. Post-draw EURO adapter, group activation, and full qualification simulation.
6. Shared dashboard polish, hourly launchd orchestration, integration tests, and release acceptance.

## Sources

- [UEFA Nations League regulations, Articles 13-19](https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27-Online)
- [UEFA EURO regulations, Articles 13-23](https://documents.uefa.com/r/Regulations-of-the-UEFA-European-Football-Championship-2026-28/Article-14-Match-system-qualifying-group-stage-Online)
- Existing implementation: `R/visualization/worldcup_dashboard.R`, `scripts/update_worldcup_dashboard.R`, and `scripts/auto_update_worldcup_dashboard.sh`
