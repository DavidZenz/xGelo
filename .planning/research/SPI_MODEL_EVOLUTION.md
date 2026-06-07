# SPI-Inspired Model Evolution Notes

*Captured: 2026-06-07*

## Why This Matters

FiveThirtyEight's Soccer Power Index (SPI) is a useful reference design for evolving xGelo beyond a simple Elo plus goal-model forecast. SPI is not just an xG table and not just an Elo-style result rating. It is a forward-looking offensive and defensive team strength system that uses underlying match performance to update ratings.

The important idea for xGelo: use xG and related performance signals to update team attacking and defensive strength, rather than relying only on wins, draws, losses, and raw goals.

## SPI Concepts Worth Borrowing

| Concept | SPI Approach | xGelo Translation |
|---------|--------------|-------------------|
| Offensive strength | Goals a team would be expected to score against an average team on neutral ground | Estimate team attack strength from lagged xGF, opponent strength, and scoring model residuals |
| Defensive strength | Goals a team would be expected to concede against an average team on neutral ground | Estimate team defense strength from lagged xGA, opponent strength, and conceded-goal residuals |
| Overall rating | Expected share of available points implied by offensive and defensive ratings | Derive an overall team score from simulated W/D/L against an average neutral opponent |
| Underlying performance update | Adjust ratings after matches based on performance, not only results | Update attack/defense ratings from adjusted goals, shot xG, and non-shot or sequence proxies |
| Match forecast | Convert projected team goals into score probabilities and W/D/L probabilities | Feed attack/defense ratings into the existing Negative Binomial scoreline simulator |

## FiveThirtyEight Inputs

FiveThirtyEight's public methodology describes three post-match performance signals in the modern club model:

1. **Adjusted goals**
   - Raw goals adjusted for context such as red cards, game state, and late goals when already leading.
   - Purpose: keep real goals in the update while reducing scoreline noise.

2. **Shot-based xG**
   - Sum of shot probabilities.
   - Shot probability used distance, angle, body part, and a player adjustment.
   - Purpose: capture chance quality better than goals alone.

3. **Non-shot xG**
   - Estimate of goal threat from actions around the opponent goal before a shot occurs.
   - Public examples include passes, interceptions, take-ons, and tackles near goal.
   - Purpose: credit dangerous possession that may not end in a shot.

The SPI data exports also expose projected scores, win/draw/loss probabilities, SPI ratings, offensive ratings, defensive ratings, xG, non-shot xG, and adjusted scores.

## What We Can Implement With Current xGelo Data

### Near-Term: SPI-Lite

Build team attack and defense ratings as lagged, opponent-adjusted form measures:

- Attack signal:
  - lagged xGF
  - lagged goals for
  - opponent defensive Elo or rating
  - venue adjustment

- Defense signal:
  - lagged xGA
  - lagged goals against
  - opponent attacking Elo or rating
  - venue adjustment

- Forecast:
  - use attack and defense ratings to predict expected home and away goals
  - keep the existing Negative Binomial simulator for scorelines
  - evaluate with Brier score, log loss, calibration, and ranked probability score

This is feasible with existing `team_match_xg`, `rolling_form`, Elo ratings, and match results.

### Medium-Term: True Attack/Defense Rating System

Instead of using only rolling averages, maintain dynamic team ratings:

1. Start each team with attack and defense priors from Elo or historical averages.
2. Before each match, project goals from:
   - home attack vs away defense
   - away attack vs home defense
   - home advantage
   - rest/travel/context if available
3. After each match, update attack and defense ratings from a blended performance score:
   - adjusted goals
   - shot xG
   - non-shot or sequence xG proxy
4. Weight updates by opponent strength, recency, and match importance.

This would move xGelo closer to SPI's core idea: team strength changes when a team performs better or worse than expected, even if the final result is misleading.

### Longer-Term: Non-Shot xG Proxy

StatsBomb Open Data may allow a lightweight non-shot threat proxy:

- passes received in the box
- carries or dribbles into the box
- pressures, interceptions, or recoveries in the attacking third
- set-piece entries
- event sequences ending near goal

This does not need to exactly reproduce FiveThirtyEight's non-shot xG. A simple, calibrated "pre-shot threat" feature would already improve the model's view of teams that create dangerous possessions without always shooting.

## Important Design Constraints

- Keep all rolling and rating updates strictly pre-match to avoid temporal leakage.
- Train and validate with rolling-origin splits, not random splits.
- Compare against current baselines:
  - Elo only
  - Elo plus rolling xG form
  - SPI-lite attack/defense ratings
  - dynamic attack/defense ratings
- Keep the public dashboard wording clear:
  - W/D/L probabilities are outcome sums.
  - Top exact scoreline is a single modal bucket.
  - Rounded expected score is not a modal scoreline.

## Sources To Revisit

- FiveThirtyEight club soccer methodology:
  - https://fivethirtyeight.com/methodology/how-our-club-soccer-predictions-work/
- FiveThirtyEight soccer SPI data README:
  - https://github.com/fivethirtyeight/data/tree/master/soccer-spi
- ESPN SPI explainer:
  - https://www.espn.com/soccer/story/_/id/37367780/soccer-power-index-explained

## Open Questions

1. Should xGelo keep Elo as the main strength backbone and use xG only as covariates, or replace Elo with dynamic attack/defense ratings?
2. Can we derive a useful non-shot threat proxy from the open StatsBomb event subset without paid data?
3. Should international-team ratings include player or squad-value priors, or is that outside the open-data promise?
4. How much do SPI-style xG updates improve calibration against the current forecast model?

