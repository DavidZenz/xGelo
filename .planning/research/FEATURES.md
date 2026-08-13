# Project Research: UEFA Dashboard Features

## Table stakes

### Competition overview

- Dedicated Nations League and EURO 2028 qualifying entry points.
- Clear edition, refresh timestamp, source status, and competition-state banner.
- A truthful pre-draw or incomplete-data state instead of invented groups or fixtures.

### Groups and standings

- Competition-specific league/group navigation.
- Current standings with played, wins, draws, losses, goals, goal difference, points, and official rank.
- Completed, scheduled, postponed, and unresolved match states.
- Official tie-break ordering and an explanation when a tie-break affects rank.

### Fixtures and results

- Chronological fixture list with local kickoff time, venue, home/away status, source status, and matchday.
- Result display for completed matches and forecast display for open matches.
- Filters for group/league, team, matchday, and status.

### Form

- Competition-specific recent form.
- Separate all-international form using the shared match history.
- Explicit window, cutoff date, and match inclusion rules.
- No leakage from matches after the forecast timestamp.

### Match forecasts

- Calibrated home/draw/away probabilities.
- Expected goals, most likely score, scoreline distribution, and uncertainty metadata.
- Model version, feature cutoff, and release identity visible in the data credits or match detail.

### Projected outcomes

- Simulated remaining fixtures using the frozen release and competition rules.
- Projected standings and per-team probabilities for the relevant competition outcomes.
- Scenario summaries that explain what changes a team's qualification, promotion, relegation, or play-off status.

## Competition-specific behavior

### 2026/27 Nations League

- Four leagues: A, B, C, and D.
- League-phase group tables and matchdays.
- League A quarter-final and finals-path probabilities.
- Direct promotion/relegation probabilities.
- A/B and B/C two-legged play-off probabilities, plus conditional C/D handling.
- Overall ranking output that accounts for different group sizes and UEFA's exclusion of fourth-placed results when comparing top-three teams.

### UEFA EURO 2028 qualifying

- Twelve qualifying groups of four or five teams after the official draw.
- Direct qualification probability for group winners and the eight best runners-up.
- Host-reserved-place state for England, Republic of Ireland, Scotland, and Wales.
- Nations League-linked play-off eligibility and path probabilities.
- Variable play-off topology: two, three, or four final-tournament places depending on host places used.
- Pre-draw mode that shows the competition, rules, dates, and model readiness without presenting nonexistent groups.

## Differentiators

- One shared team profile that lets users compare a team's competition form with all-international form without merging the two competition standings.
- Competition pressure labels derived from the current state, such as direct qualification, play-off bubble, promotion race, or relegation danger.
- Reproducible simulation seed and compact run manifest behind every published projection.
- Source confidence and fallback badges so users can distinguish official snapshot data from audited manual fallback data.
- Data credits collapsed at the bottom of the dashboard, consistent with the existing WC26 design direction.

## Explicit non-features

- No live event tracker, lineup/injury feed, or betting product.
- No automatic use of restricted shot providers as a required dashboard source.
- No display of EURO qualifying groups before UEFA publishes the draw.

## Sources

- [2026/27 Nations League overview, groups, and dates](https://www.uefa.com/uefanationsleague/news/0298-1d6ef1acfaef-b54fcf1da859-1000--2026-27-uefa-nations-league-all-you-need-to-know/)
- [2026/27 Nations League fixtures](https://www.uefa.com/uefanationsleague/news/02a2-1fea18abbcbc-456e846509e7-1000--2026-27-uefa-nations-league-all-the-league-phase-fixtures/)
- [EURO 2028 qualification system](https://www.uefa.com/euro2028/news/0299-1dcf3fef69a9-41405d004b47-1000--qualification-system-for-uefa-euro-2028-approved/)
- [EURO 2028 qualifying draw date](https://www.uefa.com/euro2028/news/029f-1f2ff991e87b-345fffcd69c3-1000--uefa-euro-2028-qualifying-draw-to-take-place-in-belfast/)
