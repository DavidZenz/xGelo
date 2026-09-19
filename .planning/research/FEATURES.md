# Feature Research

**Domain:** Men's UEFA Champions League forecast dashboard
**Researched:** 2026-09-19
**Confidence:** MEDIUM

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes / testable behavior |
|---------|--------------|------------|---------------------------|
| Edition- and stage-aware competition header | Users must know which season and stage they are viewing | LOW | Show edition, stage, last successful refresh, source status, and model release. A stale or failed refresh keeps the last known-good edition visible with an explicit warning. Reuses the existing competition-state and provenance UI. |
| 36-team league-phase table | The current UCL no longer has eight groups | MEDIUM | Rank all 36 clubs in one table; each club has eight league-phase fixtures against eight different opponents, four home and four away. Never label it a group stage or synthesize missing opponents. |
| Qualification-band treatment | Position has three distinct meanings | LOW | Visually and textually distinguish ranks 1-8 (round of 16), 9-24 (knockout play-off), and 25-36 (eliminated, with no Europa League transfer). Boundaries must remain understandable without color alone. |
| Exact, edition-versioned tie-breaks | One place can change a club's path materially | HIGH | For the completed league phase apply, in order: goal difference, goals scored, away goals, wins, away wins, opponents' collective points, opponents' collective goal difference, opponents' collective goals, lower disciplinary points, then club coefficient. During matchdays 1-7, use only the first five and show residual ties as equal/alphabetical. If required disciplinary or coefficient inputs are unavailable at matchday 8, fail closed instead of inventing a unique rank. |
| Club schedule, fixtures, and results | In an incomplete round robin, a club's own opponent set matters as much as the table | MEDIUM | Show every club's eight league-phase opponents, home/away designation, matchday, kickoff, status, and score. Support club, matchday, and status filters. Postponed, cancelled, suspended, and unresolved records remain distinct. Reuses normalized fixture/result components after adding club identities and UCL stages. |
| Current match forecasts | This is a forecast dashboard, not only a table mirror | HIGH | For every future fixture covered by the promoted club model, publish home/draw/away probabilities, expected goals, likely scorelines, model release, and feature cutoff. Probabilities sum to one within tolerance. Completed matches never retain an active forecast card, while the immutable pre-kickoff forecast remains available for audit. |
| League-phase outcome probabilities | Fans primarily need to know whether a club will advance and by which route | HIGH | For each club publish mutually exclusive probabilities for top 8, ranks 9-24, and ranks 25-36; they sum to one. Also publish rank distribution or expected finish so identical band probabilities are not misleading. Simulations condition on all accepted completed results and never alter them. |
| Knockout play-off path | The new format constrains possible opponents by league rank | HIGH | Encode 9/10 vs 23/24, 11/12 vs 21/22, 13/14 vs 19/20, and 15/16 vs 17/18. Before the draw, show possible opponents and probabilities; after an accepted draw, replace possibilities with the observed tie. Seeded sides play the second leg at home in principle, with any official scheduling exception treated as data, not overwritten by the rule engine. |
| Round-of-16 and fixed bracket view | League rank defines the route to the final | HIGH | Show the bracket as unknown, partially known, or confirmed. Pair top-eight rank pairs (1/2, 3/4, 5/6, 7/8) with the corresponding play-off winners; once the bracket draw is accepted, preserve that path through the final. Same-association and league-phase rematches are allowed. |
| Two-leg and final tie handling | Aggregate ties cannot be simulated like ordinary league matches | MEDIUM | Aggregate both legs; if level after the second leg, model extra time and penalties under a documented contract. There is no away-goals tie-break. The final is a one-match neutral-site event with extra time/penalties as needed. |
| Ranking-based later-round leg order | Higher league-phase finishes retain sporting value deep into the knockouts | MEDIUM | Read the rule from the edition contract. Under the 2025/26 rule, ranks 1-4 receive the second leg at home in the quarter-finals and ranks 1-2 in the semi-finals if they advance; an eliminator inherits that seeded position. Official stadium/city scheduling exceptions override the default and remain visible in provenance. |
| Tournament progression probabilities | Users expect more than qualification from a UCL forecast | HIGH | Once paths can be represented, show reach-play-off, reach-R16, reach-QF, reach-SF, reach-final, and champion probabilities. Stage probabilities must be monotone for each club and reconcile with league-phase bands. |
| Freshness, provenance, and unavailable states | Automated public data is delayed and incomplete | MEDIUM | Display fetched-at, source-as-of, provider, rules edition, model release, and last-known-good status. Null API fields remain null. Current xG, injuries, lineups, cards, and advanced match statistics show `Unavailable from accepted source` unless an approved source contract exists. Reuses existing lineage and truthful-empty-state components. |
| Responsive, accessible publication | The dashboard is public and static | MEDIUM | All core information works without hover, color-only meaning, or live API access from the browser. The published bundle is complete, self-contained, and atomically promoted through the generalized edition registry. |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes / testable behavior |
|---------|-------------------|------------|---------------------------|
| Independently validated club forecast authority | Separates xGelo from standings sites and prevents false transfer of the national-team model | HIGH | Every UCL probability points to a club-specific promoted release and validation scorecard. If promotion gates fail, the dashboard may publish factual state but must withhold forecast authority. |
| Qualification pressure and cut-line distributions | Makes the unfamiliar 36-team race interpretable | MEDIUM | Show simulated points/rank thresholds for top 8 and top 24, plus each club's margin to those cut lines. Label these as distributions, never as deterministic points requirements. |
| Remaining schedule-strength view | Explains why clubs on equal points can have very different prospects | MEDIUM | Derive remaining opponent strength and venue mix only from frozen model inputs. Show the component contribution or a plain-language schedule label with methodology and cutoff. |
| Rank-to-path probability map | Connects league-phase position to future bracket difficulty | HIGH | Before draws, show probability-weighted possible opponents and path branches; after draws, collapse only the resolved uncertainty. Never present an undrawn pairing as confirmed. |
| Reproducible what-if scenarios | Lets users explore how a result changes the table and qualification odds | HIGH | A scenario alters only explicitly selected future results, reruns the same rule engine with a visible scenario label and seed, and never overwrites the official published baseline. Best added after baseline simulations are stable. |
| Forecast change ledger | Makes automatic refreshes accountable | MEDIUM | Preserve pre-kickoff forecasts and show material probability changes with the exact state/model revision that caused them. Reuses the existing forecast ledger and run manifest. |
| Honest uncertainty and source confidence | Builds trust where open data cannot match paid feeds | MEDIUM | Distinguish model uncertainty, unresolved draw uncertainty, stale source state, and unavailable enrichment. A missing input cannot silently become a zero, default lineup, or neutral injury assumption. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time live-score and event tracker | Fans expect instant matchday updates | The accepted free source is delayed and static publishing cannot guarantee live truth; aggressive polling adds operational and contractual risk | Refresh on a documented cadence, expose source timestamps, and link users to an official live service for minute-by-minute coverage |
| Scraping UEFA pages for automated match state | UEFA is the competition authority | Public pages are not an approved machine-readable contract and can change layout or terms | Use UEFA material as versioned manual rules evidence; ingest match state from a licensed or explicitly permitted API |
| Current xG, injuries, lineups, or player projections without an accepted source | They appear to improve forecasts and engagement | Free UCL coverage does not reliably provide these fields; fabricated or scraped enrichment violates the project's core value | Publish explicit unavailable states and design optional adapters that remain inactive until legal, stable, testable sources are approved |
| Reusing the national-team forecast release | It would shorten delivery | Club schedules, team strength, transfer dynamics, home effects, and evaluation populations differ; the resulting probabilities would lack validated authority | Train and promote a separate club release through frozen rolling-origin gates |
| Trusting provider standings as the rule engine | It looks cheaper than implementing rules | Provider tables may not expose opponent aggregates, discipline, coefficient lineage, deductions, or edition-specific changes | Recompute standings from normalized results and versioned rules, then reconcile against provider/official tables |
| Simulating a full round robin | Standard league tooling assumes every club plays every other club | UCL is an incomplete round robin with a fixed eight-opponent schedule; invented fixtures corrupt rank and qualification probabilities | Simulate only the accepted official fixture list |
| Showing a single predicted final table | Easy to read | Hides large uncertainty at cut lines and encourages deterministic interpretation | Publish rank distributions and mutually exclusive qualification-band probabilities |
| Guessing the knockout bracket before draws | Users want a complete bracket immediately | Rank-pair rules constrain but do not fully determine positions; seeding and home-leg rules can be edition-specific | Show possible-opponent sets and unresolved branches, then condition on accepted draw data |
| Betting odds, tips, or expected-value recommendations | Popular adjacent use case | Expands legal, data, calibration, and responsible-use scope beyond the research dashboard | Publish calibrated football probabilities with model limitations, not wagering advice |
| Mandatory browser-side API calls | Feels more dynamic | Exposes credentials, couples availability to provider uptime/rate limits, and breaks atomic publication | Fetch server-side in the targets pipeline, validate and cache, then publish static artifacts |

## Explicit Current-Data Gaps

| Gap | Launch treatment | Requirement consequence |
|-----|------------------|-------------------------|
| Live scores and events | Not promised; delayed periodic refresh with source timestamp | No `live` badge unless the source contract proves freshness semantics |
| Current-match xG and advanced statistics | Explicitly unavailable | Do not render zero-valued xG or infer it from the score |
| Injuries, suspensions, and confirmed lineups | Explicitly unavailable | Exclude from model claims and list among limitations |
| Disciplinary totals required for the ninth final tie-break | Fail closed if exact rank depends on them | Permit tied/unresolved final rank and block affected bracket simulation until accepted data arrives |
| Current UEFA club coefficient required for the tenth final tie-break | Versioned manual or permitted structured input; otherwise fail closed | Record coefficient edition and as-of date in provenance |
| Historical depth for club-model training | Separate historical-source contract required; current-season API data is insufficient | Forecast publication depends on the club-model phase, not merely current-state ingestion |
| Official draw/bracket state | Versioned manual bundle or approved structured source | Pre-draw states show possibilities; post-draw states require an accepted draw artifact |

## Feature Dependencies

```text
[Permitted current-state source + club identity registry]
    ├──requires──> [Normalized UCL fixture/result contract]
    │                  ├──requires──> [Versioned standings/tie-break engine]
    │                  │                  └──enables──> [Qualification bands + cut-line state]
    │                  └──requires──> [Accepted draw/bracket state]
    │                                     └──enables──> [Knockout path]
    └──feeds──> [Static dashboard adapter + N-edition publisher]

[Historical club data + frozen evaluation protocol]
    └──requires──> [Promoted club model release]
                       ├──enables──> [Match forecasts]
                       └──enables──> [League/tournament simulations]
                                          └──enhances──> [What-if scenarios]

[Unavailable enrichment] ──conflicts──> [xG/injury/lineup claims]
[Unresolved final tie-break] ──blocks──> [Unique rank and affected bracket simulation]
```

### Dependency Notes

- **The standings engine requires normalized fixtures/results and editioned rules:** the API's table is a reconciliation target, not the authoritative implementation.
- **League-phase simulations require the exact accepted eight-opponent schedule:** ratings alone cannot generate valid standings.
- **Forecast features require a promoted club model:** factual UCL publication can proceed earlier, but forecast cards and advancement probabilities cannot borrow national-team authority.
- **Knockout simulations require a rules-complete tie model and draw state:** pre-draw simulations sample only legal rank-constrained branches; post-draw simulations condition on the official bracket.
- **Public launch requires the N-edition publication contract:** UCL must not be appended outside the existing atomic manifest, rollback, and read-back validation boundary.

## MVP Definition

### Launch With (v4.0)

- [ ] Permitted, cached current-state ingestion with club identities, source timestamps, last-known-good fallback, and validation.
- [ ] Correct 36-team table, matchday behavior, qualification bands, full tie-break sequence, and truthful unresolved ranks.
- [ ] Fixtures/results views for all eight league-phase matchdays and accepted knockout rounds.
- [ ] Separately validated club match model with immutable pre-kickoff forecasts and explicit promotion status.
- [ ] Conditioned league-phase simulation with top-8, play-off, elimination, rank, and cut-line distributions.
- [ ] Rank-constrained play-off and round-of-16 path logic, accepted draw conditioning, two-leg resolution, and champion probabilities.
- [ ] Static UCL dashboard published through the generalized atomic registry with provenance, freshness, and unavailable-data states.

### Add After Validation (v4.x)

- [ ] What-if result simulator — add after deterministic baseline simulations and browser performance are verified.
- [ ] Remaining schedule-strength and forecast-change explanations — add after users can inspect underlying inputs and cutoffs.
- [ ] Optional advanced-data adapter — activate only after a lawful source contract and independent incremental-value test.
- [ ] Qualifying-round forecast coverage — add only after the league-phase product is stable and qualifying-path rules/data are scoped separately.

### Future Consideration (v5+)

- [ ] Additional UEFA club competitions — reuse the registry only after competition-specific schedule and bracket rules are implemented.
- [ ] Player availability model — defer until reproducible historical and current lineup/injury evidence exists.
- [ ] Near-live publication — defer until source SLA, hosting, cost, and operational monitoring justify a different product promise.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Permitted source, freshness, and provenance | HIGH | MEDIUM | P1 |
| 36-team standings and tie-break engine | HIGH | HIGH | P1 |
| Qualification bands and league-phase probabilities | HIGH | HIGH | P1 |
| Club-specific forecast authority | HIGH | HIGH | P1 |
| Knockout path and champion probabilities | HIGH | HIGH | P1 |
| N-edition atomic publication | HIGH | MEDIUM | P1 |
| Cut-line and rank distributions | HIGH | MEDIUM | P1 |
| Schedule-strength explanation | MEDIUM | MEDIUM | P2 |
| Forecast change ledger | MEDIUM | MEDIUM | P2 |
| What-if simulator | MEDIUM | HIGH | P2 |
| Qualifying-round coverage | LOW | HIGH | P3 |
| Player availability enrichment | MEDIUM | HIGH | P3 |
| Live event tracking | LOW for this product | HIGH | Excluded |

**Priority key:**

- P1: Must have for the milestone launch
- P2: Add after the factual and probabilistic baseline is validated
- P3: Defer to a later milestone

## Competitor Feature Analysis

| Feature | Official UEFA app | Opta Analyst | xGelo approach |
|---------|-------------------|---------------|----------------|
| Fixtures and table | Live-oriented official coverage | Actual/expected/predicted table and fixtures | Delayed, validated static state with explicit source timestamps |
| Qualification explanation | Live bracket and result simulator | Supercomputer probabilities and projected points | Qualification-band, rank, and cut-line distributions tied to an open, auditable release |
| Knockout path | Official bracket and draws | Tournament progression projections | Editioned rule engine with unresolved/confirmed draw states and legal path sampling |
| Model transparency | Not the primary purpose | High-level model explanation; underlying paid data | Release lineage, frozen evaluation gates, feature cutoff, seed, and retained pre-kickoff forecasts |
| Advanced/live data | Rich official match coverage | Opta statistics and power rankings | Explicitly unavailable unless an approved source is added; no fabricated parity |

## Sources

- [UEFA: league-phase standings and final tie-break criteria](https://www.uefa.com/uefachampionsleague/news/0291-1bd88ae04870-e1e038c319e3-1000--champions-league-league-phase-standings-how-teams-level-on-/) — official, current 2026/27 guidance; MEDIUM confidence after cross-check.
- [UEFA: post-2024 competition format](https://www.uefa.com/news-media/news/0268-12157d69ce2d-9f011c70f6fa-1000--how-clubs-qualify-for-europe/) — official format and qualification bands; MEDIUM confidence after cross-check.
- [UEFA: 2025/26 knockout play-off draw procedure](https://www.uefa.com/uefachampionsleague/news/029a-1de997d047d3-6764f63d69c6-1000--uefa-/) — official rank-pair mapping; MEDIUM confidence after cross-check.
- [UEFA: round-of-16 and bracket draw procedure](https://www.uefa.com/uefachampionsleague/news/02a2-1ffe3d954170-60c0b7443c85-1000--uefa-champions-league-round-of-16-quarter-final-and-semi/) — official path behavior; MEDIUM confidence after cross-check.
- [UEFA: 2025/26 teams, format, dates, and ranking-based home-leg advantages](https://www.uefa.com/uefachampionsleague/news/0296-1d21e9bdf7e4-808a7511165c-1000/) — official edition behavior; MEDIUM confidence after cross-check.
- [UEFA Champions League app feature summary](https://www.uefa.com/uefachampionsleague/app/) — official user-feature baseline; MEDIUM confidence.
- [football-data.org coverage](https://www.football-data.org/coverage) and [API policies](https://docs.football-data.org/general/v4/policies.html) — official UCL free-tier coverage and rate-limit/null semantics; MEDIUM confidence after cross-check.
- [football-data.org API reference](https://www.football-data.org/documentation/api) — official match, team, and current-season standings resources; MEDIUM confidence.
- [Opta Analyst UCL projections](https://theanalyst.com/articles/uefa-champions-league-predictions-opta-supercomputer-league-phase-projections-final-two-matchdays) and [competition page](https://theanalyst.com/competition/uefa-champions-league) — competitor feature baseline; LOW confidence for implementation facts, used only for product comparison.

---
*Feature research for: UEFA Champions League Forecast Dashboard*
*Researched: 2026-09-19*
