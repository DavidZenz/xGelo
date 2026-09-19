# Pitfalls Research

**Domain:** Open-data UEFA Champions League forecasting and static dashboard publication
**Researched:** 2026-09-19
**Confidence:** MEDIUM

## Recommended Prevention Phases

The roadmapper should preserve these ownership boundaries even if it assigns different phase numbers:

1. **Source and identity contract** — lawful current-state ingestion, historical backfill, canonical club identities, score/status semantics, provenance, and freshness.
2. **Club model and promotion gate** — club-specific ratings and goal model, temporal evaluation, calibration, release lineage, and explicit unavailable enrichment.
3. **Rules and tournament simulation** — 36-team league table, tie-breaks, rank-dependent draw paths, two-leg ties, extra time, penalties, and deterministic simulation.
4. **Dashboard registry and publication** — N-edition registry, UCL adapter, typed unavailable states, output envelope, rendering, and atomic multi-edition publication.
5. **Automated refresh and release hardening** — rate-aware scheduling, secret handling, retries, stale-state behavior, monitoring, recovery, and end-to-end acceptance.

## Critical Pitfalls

### Pitfall 1: Automating an authoritative-looking but prohibited source

**What goes wrong:**
The updater scrapes UEFA pages because they are official. The resulting dashboard may be factually good but operationally and legally non-viable. A later page-layout change or enforcement action can stop the release pipeline entirely.

**Why it happens:**
Authority is confused with permission. UEFA is the correct authority for regulations, but its platform terms prohibit systematic collection and automated scraping. Public visibility is not a machine-use licence.

**How to avoid:**
Use a machine-readable provider with terms that permit the intended automated application for current fixtures, results, and tables. Treat UEFA regulations as manually reviewed, versioned rule inputs. Record source URL, retrieved time, licence/terms snapshot, raw hash, adapter version, and acceptance decision. Make a source-term review a release gate, not a documentation afterthought.

**Warning signs:**
- HTML selectors, undocumented UEFA endpoints, or browser automation appear in the scheduled updater.
- The source registry says “public” instead of recording permitted use and attribution.
- Raw UEFA page bodies are committed or redistributed.
- No owner or date exists for the source-terms decision.

**Phase to address:**
Source and identity contract; re-check in automated refresh and release hardening.

---

### Pitfall 2: Treating football-data.org as unconditional open data

**What goes wrong:**
The application works in development but violates subscription conditions, leaks the API token, omits attribution, exceeds the free rate, or cannot lawfully retain/display provider data after cancellation. Delayed free-tier scores are presented as live.

**Why it happens:**
“Free tier” is mistaken for CC0. The service requires an account, visible attribution, confidential credentials, fair use, and application-scoped access; it disclaims availability and accuracy. Its published terms also constrain continued display after cancellation.

**How to avoid:**
Store the token only in the scheduler environment or a local secret store; never in Git, static payloads, logs, or route manifests. Add visible attribution. Implement a bulk-endpoint request budget below 10 calls/minute, cache accepted responses, and test 429/5xx/null/empty responses. Record subscription state and a provider-exit plan. Label free-tier state as delayed, not live.

**Warning signs:**
- `X-Auth-Token` appears in source, fixtures, logs, snapshots, or generated HTML.
- One request is issued per team or fixture.
- The UI says “live” while using the delayed free plan.
- The publication has no “Football data provided by…” credit.
- Historical retention rights are assumed but not recorded.

**Phase to address:**
Source and identity contract for acceptance; automated refresh and release hardening for enforcement.

---

### Pitfall 3: Reusing the national-team model as club forecast authority

**What goes wrong:**
The dashboard produces plausible probabilities with systematically wrong uncertainty and calibration. International-team Elo, match cadence, neutral-site effects, and goal processes do not represent clubs playing domestic and European schedules.

**Why it happens:**
The existing pipeline already has a validated model and compatible-looking team-strength fields, so adapting IDs is deceptively easy. Club football adds cross-league strength, promotion/relegation, transfers, dense schedules, and much faster ability drift.

**How to avoid:**
Create a separate club identity namespace, club match history, rating state, feature contract, model manifest, validation folds, promotion rule, and approved-release selector. Include domestic matches when estimating strength across leagues, but evaluate UCL forecasts separately. Benchmark against simple club-Elo and competition-aware count models. Do not allow a national-team release ID through the UCL adapter.

**Warning signs:**
- A UCL payload references the current national-team `approved_release.csv`.
- Home advantage, decay, or draw parameters are copied without club backtests.
- Clubs share canonical IDs with national associations.
- Aggregate accuracy is reported without UCL calibration or proper scores.

**Phase to address:**
Club model and promotion gate.

---

### Pitfall 4: Cross-league training data that is internally consistent but incomparable

**What goes wrong:**
A model overrates clubs from data-rich or high-scoring leagues, underrates promoted or infrequently observed clubs, and learns provider/league artifacts rather than transferable strength. Duplicate European matches or inconsistent score semantics silently distort ratings.

**Why it happens:**
Domestic sources differ in season boundaries, club names, competition levels, match status, neutral/home designation, and coverage. Simply row-binding them creates false comparability. European matches can appear in both a domestic/global result source and the UCL source.

**How to avoid:**
Define one canonical match schema with source-native IDs, canonical club/competition/season IDs, UTC kickoff, regulation score, extra-time score, shootout result, venue role, match status, and immutable row provenance. Deduplicate on source lineage plus canonical match identity. Calibrate league-strength priors using cross-league European matches. Define cold-start behavior for promoted/new clubs and uncertainty widening. Reject seasons with incomplete coverage rather than treating missing matches as losses or inactivity.

**Warning signs:**
- The same tie appears twice with slightly different dates or club spellings.
- Penalty shootout goals enter regulation goal totals.
- Rating jumps correlate with provider or season boundaries.
- New entrants receive an arbitrary global-average rating with ordinary uncertainty.
- Coverage counts vary sharply without a failed completeness gate.

**Phase to address:**
Source and identity contract, with statistical checks in the club model phase.

---

### Pitfall 5: Leakage through season-level, table-level, or same-day information

**What goes wrong:**
Backtests look excellent but use data not known at prediction time: final-season coefficients, post-match standings, later squad values, full-season normalization, or outcomes from another match on the same timestamp/day.

**Why it happens:**
Club datasets are commonly distributed as completed-season tables. The league-phase simulator also needs current standings, which makes it easy to feed a post-match table into a pre-match feature row.

**How to avoid:**
Build every assessment row from an explicit `information_cutoff_utc`. Recompute ratings and rolling features strictly before each kickoff. Version coefficients by their published effective date. Separate observed competition state from simulated future state. For simultaneous final-matchday fixtures, freeze every pre-match feature before incorporating any result from that kickoff window. Assert maximum source-event time per feature row.

**Warning signs:**
- Feature code joins on season without an `available_at` or cutoff field.
- Backtest predictions change when future rows are removed.
- Matchday 8 forecasts depend on another Matchday 8 result with the same kickoff.
- A current standings table is used as a model feature without reconstruction.

**Phase to address:**
Club model and promotion gate; repeat as a simulation integration test.

---

### Pitfall 6: Implementing a generic points sort instead of the league-phase ranking rules

**What goes wrong:**
The table and qualification probabilities are wrong at the boundaries for ranks 8/9 and 24/25. Interim table ordering is incorrectly reused as final ordering, or final criteria are applied in the wrong order.

**Why it happens:**
The first five criteria are familiar, while completed-league ranking also depends on the collective records of each club's eight opponents, disciplinary points, and club coefficient. The interim Matchday 1–7 display rules differ from the completed league-phase rules.

**How to avoid:**
Implement an edition-versioned ranking engine that returns both rank and the decisive criterion. Test every criterion in order, including opponent-points, opponent-goal-difference, opponent-goals, disciplinary points, and coefficient. Keep separate `interim_display_rank` and `final_competition_rank` functions. Use adversarial fixtures where each criterion alone decides the order.

**Warning signs:**
- Ranking code is a single `arrange(desc(points), desc(goal_difference), desc(goals_for))`.
- No opponent-aggregate fields exist.
- No test distinguishes Matchday 7 from completed Matchday 8.
- The table cannot explain why two equal-points clubs are ordered.

**Phase to address:**
Rules and tournament simulation.

---

### Pitfall 7: Silently skipping tie-break inputs unavailable on the free feed

**What goes wrong:**
The simulation jumps from opponent aggregates to club coefficient because disciplinary points are missing, presenting exact position probabilities that do not implement UEFA's order. Current displayed standings can also disagree with the provider's official ordering.

**Why it happens:**
The free current-state tier provides fixtures, delayed scores, and tables, while bookings/cards are a deeper-data feature. Future disciplinary points are unknown even if current cards are available. Ties reaching this criterion are uncommon, so the defect hides in ordinary tests.

**How to avoid:**
Make tie-break evidence part of the rules contract. For observed state, preserve the provider's accepted position and compare it with locally reproducible criteria. For future simulations, either (a) add a permitted disciplinary source and a validated card model, or (b) return interval/ambiguous rank outcomes for unresolved samples and visibly label the approximation. Never silently reorder by a later criterion. Track the fraction of simulations reaching an unsupported resolver and block release above a declared tolerance.

**Warning signs:**
- Missing disciplinary values are coerced to zero.
- Coefficient decides a tie without a recorded disciplinary comparison.
- Qualification probabilities always sum cleanly but no unresolved mass is reported.
- An “exact UEFA rules” claim exists without card provenance.

**Phase to address:**
Rules and tournament simulation, with truthful status rendering in dashboard publication.

---

### Pitfall 8: Simulating the knockout phase as independent random draws

**What goes wrong:**
Teams receive impossible opponents, the wrong bracket side, or the wrong second-leg home status. Quarter-final and semi-final paths are re-randomized even though they follow positions fixed by prior draws.

**Why it happens:**
Legacy tournament simulators often use a generic “sample any opponent each round” abstraction. The current UCL uses rank-paired seeded/unseeded play-off slots and a bracket whose later paths and match order inherit earlier draw positions.

**How to avoid:**
Represent draw slots and bracket paths as data, not branching conditionals. Separate “draw not yet observed” from “draw observed and frozen.” Generate only assignments permitted by the edition's rules and constraints, persist the realized draw seed/state, then propagate winners through immutable paths. Validate against a published completed draw and exhaustively assert that no illegal pairing is generated.

**Warning signs:**
- A generic knockout helper accepts only a vector of qualified teams.
- Round-of-16 opponents are sampled from all survivors.
- Later-round fixtures change after a refresh despite no new draw.
- Second-leg venue order is inferred from team strength instead of bracket position/ranking rules.

**Phase to address:**
Rules and tournament simulation.

---

### Pitfall 9: Conflating regulation results, aggregate ties, extra time, and shootouts

**What goes wrong:**
Shootout kicks inflate goal-model training, away-goals logic reappears, a two-leg tie advances the wrong club, or a postponed/abandoned match is counted as complete.

**Why it happens:**
Many feeds expose a single “final score,” while forecasting, standings, and tie resolution need different score concepts. Older Champions League history also contains away-goals regimes that do not apply to current editions.

**How to avoid:**
Store regulation, extra-time, aggregate, and shootout values separately with explicit status and ruleset version. Train the match goal model on the declared regulation-time target. Resolve current two-leg ties on aggregate goals, then extra time and penalties under current rules. Treat scheduled, postponed, suspended, abandoned, awarded, and completed states distinctly. Include historical-regime flags when using old ties.

**Warning signs:**
- One pair of `home_goals`/`away_goals` columns serves training, display, and advancement.
- A shootout score such as 5–4 appears in the goal distribution.
- Any current rule mentions away goals.
- Status is inferred solely from non-null scores.

**Phase to address:**
Source and identity contract for schema; rules and simulation for resolution.

---

### Pitfall 10: Claiming historical validation for a format with almost no historical seasons

**What goes wrong:**
Tournament-level calibration appears precise even though the 36-team, eight-match league phase began only recently. Pre-reform group stages are treated as directly comparable evidence for rank and qualification probabilities.

**Why it happens:**
Historical match results are plentiful, but historical examples of the new tournament structure are not. Match-model evidence is incorrectly conflated with end-to-end competition-format evidence.

**How to avoid:**
Separate three validation claims: match probability quality (many temporal club matches), rules-engine correctness (fixtures and adversarial tests), and end-to-end format calibration (few real seasons, high uncertainty). Use pre-reform UCL only for match-model evaluation, not direct 36-team qualification calibration. Replay all available new-format seasons and supplement with synthetic property tests; publish wide uncertainty and do not tune to the current season's realized table.

**Warning signs:**
- “Years of Champions League backtests” is reported for top-8/top-24 probabilities.
- Group-stage qualification is pooled with league-phase qualification.
- The same new-format season is used to tune and assess simulation choices.
- No distinction exists between model validation and rules validation.

**Phase to address:**
Club model and promotion gate for match evidence; rules and simulation for format evidence.

---

### Pitfall 11: Extending a two-edition publisher with a third hard-coded branch

**What goes wrong:**
UCL publishes successfully in isolation but breaks the atomic batch envelope, route manifests, recovery path, or the two existing dashboards. Every future competition requires another copy of conditionals and fixed file lists.

**Why it happens:**
The current implementation has phase-specific helpers and explicit Nations League/EURO lists. Adding one more `if (edition_id == ...)` is faster locally than generalizing the registry, but preserves the structural limit.

**How to avoid:**
Make edition registry rows drive adapters, routes, expected artifacts, lifecycle states, credits, and validation. Define atomic publication policy explicitly: either all registered production editions advance together, or independent batches carry clear per-edition generation IDs and a coherent global index. Property-test 0/1/N editions, stable route order, rollback, and preservation of incumbent bytes after any candidate failure.

**Warning signs:**
- New symbols are named `phase18_editions()` but still return a literal vector.
- Publication validation expects exactly two route manifests or ten files.
- UCL uses a separate script that bypasses the existing batch manifest.
- A failed UCL refresh prevents serving the last valid Nations League/EURO release.

**Phase to address:**
Dashboard registry and publication.

---

### Pitfall 12: Publishing partial or stale state as a successful refresh

**What goes wrong:**
An API timeout yields a half-new dashboard: some results are updated, standings are old, forecasts use a different cutoff, or an empty response overwrites the last accepted bundle. The scheduler then commits the inconsistency.

**Why it happens:**
Providers legitimately return nulls and empty lists, free-tier scores are delayed, and retries may succeed for only some endpoints. File-by-file writes expose intermediate state.

**How to avoid:**
Stage a complete candidate bundle with one retrieval window, validate referential integrity and state invariants, recompute forecasts against that exact accepted cutoff, render all routes, read them back, and promote atomically. Treat null/empty as data requiring semantic validation, not automatic success. On failure, keep last-known-good public bytes and publish a failed-refresh log outside the public payload. Enforce a maximum acceptable source age by lifecycle state.

**Warning signs:**
- Accepted files are overwritten before validation completes.
- Results and table payloads have different retrieval IDs.
- A zero-row response passes because the HTTP status was 200.
- `last_refresh_at` advances when the source bundle hash did not.
- Scheduler exit code is zero after falling back silently.

**Phase to address:**
Automated refresh and release hardening, building on dashboard publication transactions.

---

### Pitfall 13: Fabricating unavailable xG, injuries, lineups, or false precision

**What goes wrong:**
The UCL page implies current xG/squad intelligence that the accepted free sources cannot support, or substitutes stale historical event data without disclosure. Users over-trust three-decimal probabilities whose largest uncertainties are omitted.

**Why it happens:**
The national-team dashboard has xG lineage and the static section contract expects rich content. StatsBomb Open Data is excellent but its UCL coverage is selective and historical, not a current full-season feed.

**How to avoid:**
Use typed `unavailable` sections with a concrete reason and required source capability. Keep historical event data limited to separately validated training/research roles. Show model version, cutoff, source freshness, missing enrichment, and simulation uncertainty. Do not impute injuries/lineups as “no absences.”

**Warning signs:**
- Missing fields become zero or “full squad.”
- StatsBomb branding appears on current UCL metrics without match-level lineage.
- The page has an xG chart but no current xG source ID.
- Qualification probabilities are shown more precisely than Monte Carlo error supports.

**Phase to address:**
Club model and promotion gate for feature policy; dashboard registry and publication for user-visible states.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-code the current 36 clubs | Fast prototype | Breaks at qualifiers, replacements, and next edition; invalid identity lineage | Throwaway local sketch only |
| Reuse national-team Elo/model objects | Immediate probabilities | Invalid authority and misleading calibration | Never for public forecasts |
| Use provider table position as the simulation ranking function | Avoids tie-break work | Cannot rank hypothetical futures; provider may use undisclosed corrections | Display-only observed state with provenance |
| Skip disciplinary tie-breaks and use coefficient | Easy deterministic ordering | Rules-inaccurate exact probabilities | Only if unresolved mass is retained and visibly disclosed, never silently |
| Treat OpenFootball as the live authority | CC0 and easy ingestion | Community lag or incomplete current state can stale the dashboard | Historical backfill with completeness gates |
| Put API response JSON in Git | Easy reproducibility | Credential/data-rights risk and repository bloat | Only transformed, permitted, minimal accepted artifacts; raw bytes remain ignored/local |
| Add `else if (ucl)` throughout Phase 17 code | Low local diff | N-edition generalization never occurs | Never in the production publisher |
| Tune to one new-format UCL season | Better retrospective fit | Severe overfit and false tournament calibration | Never as promotion evidence |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| football-data.org | Per-fixture polling, token in repository, 200/empty treated as success | Bulk competition calls, secret environment variable, request budget, semantic completeness gates, visible attribution |
| UEFA regulations | Scheduled scraping of official pages | Manually acquire/review a rules artifact, record edition/effective date/hash, encode and test rules locally |
| UEFA standings | Assume displayed order can be reproduced from points/GD alone | Preserve accepted observed rank and separately implement complete final-ranking criteria |
| OpenFootball | Assume CC0 implies complete/current/authoritative | Use as historical backfill, pin commit/hash, compare counts and overlaps against a second source |
| StatsBomb Open Data | Treat selected historical UCL events as current coverage | Use only enumerated competition/season files with match-level lineage and required attribution |
| Existing competition registry | Reuse national-team IDs or lifecycle assumptions | Add club-specific identity namespace and edition-driven adapter/route metadata |
| Existing publication batch | Append a UCL copy step after promotion | Stage, validate, read back, and atomically promote the entire declared release envelope |
| Static renderer | Insert source team names/reasons directly into HTML | Escape all external strings; constrain URLs and route slugs to validated registry values |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Per-team/per-fixture API fan-out | 429 responses, long refreshes, inconsistent retrieval windows | Use competition-level endpoints, conditional/local cache, retry with backoff and jitter | Free tier allows 10 calls/min; a 36-team fan-out already exceeds it |
| Row-wise R tournament simulation | Refresh time grows nonlinearly; scheduler overlaps | Vectorize goal draws, preallocate arrays, batch simulations, profile ranking, use deterministic independent RNG streams if parallel | 50k simulations × league phase plus knockouts and repeated 36-row sorting |
| Recomputing model fit on every score refresh | Slow refresh and accidental model drift | Separate immutable approved model releases from current-state scoring | Any matchday automation window |
| Materializing every simulated score/path | Huge RAM, Git artifacts, slow JSON | Aggregate counts online; retain compact diagnostics and sampled audit traces | Millions of simulated match rows |
| Full standings resort after every simulated fixture | CPU dominated by repeated sorts | Update state in arrays; rank only at required output checkpoints | 36 teams × 8 matches × tens of thousands of runs |
| Unbounded historical joins | Duplicate rows and memory spikes | Partition by season/source, select columns early, assert key cardinality | Multi-league, multi-season domestic history |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing the football-data.org API token | Unauthorized use, account cancellation, history cleanup | Environment/local secret store; secret scanning test; redact request headers from logs |
| Trusting provider strings in generated HTML | Stored script/markup injection through club, venue, or status text | Escape all external values and allowlist URL schemes/route slugs |
| Deriving file paths from source IDs | Path traversal or overwrite outside staging root | Resolve against registry-owned slugs and assert normalized path remains under staging root |
| Publishing raw source payloads/logs | Terms breach, accidental credentials, unnecessary data redistribution | Publish normalized minimal facts and hashes; keep raw responses ignored and access-controlled |
| Executing content from remote “rules” or data files | Supply-chain/code-execution risk | Parse as inert data; pin hashes/commits; never source/eval downloaded content |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Calling delayed scores “live” | Users infer freshness that does not exist | Show `source_as_of`, `accepted_at`, delay class, and stale warning |
| Mixing current table with projected table | Users cannot tell observation from model | Separate views and labels; never replace official/current rank with expected rank |
| Hiding unresolved tie-break mass | Exact-looking probabilities are rules-inaccurate | Display approximation/unresolved percentage and confidence note |
| Empty xG/injury/lineup panels | Looks broken or silently complete | Typed unavailable state explaining the missing licensed source |
| Showing only champion probability | Conceals the main league-phase decisions | Include top-8, top-24, eliminated, next-round, and champion probabilities |
| Over-precise percentages | Suggests certainty unsupported by model/data/Monte Carlo | Round appropriately and expose simulation count/model cutoff |
| Ranking changes without explanation | Dashboard appears inconsistent | Store and show decisive tie-break criterion where non-obvious |
| Stale successful-looking dashboard | Users cannot distinguish outage from no change | Preserve last valid data but add prominent freshness/status metadata |

## “Looks Done But Isn't” Checklist

- [ ] **Source acceptance:** A successful API call is not enough — verify terms, attribution, token handling, completeness, hashes, and a provider-exit plan.
- [ ] **Club identity:** Club names resolve in one season — verify renames, accents, reserve/name collisions, promoted clubs, and source-native ID changes.
- [ ] **Historical corpus:** Rows parse — verify season coverage, duplicate matches, regulation/ET/shootout semantics, and source overlap.
- [ ] **Model release:** Accuracy improved — verify temporal UCL proper scores, calibration, uncertainty, cold starts, and national-team release isolation.
- [ ] **Leakage safety:** Features have dates — verify every feature's `available_at` is before kickoff, including simultaneous Matchday 8 fixtures.
- [ ] **League table:** Normal examples sort correctly — verify each tie-break criterion independently and the interim/final distinction.
- [ ] **Tie-break completeness:** Most simulations resolve early — measure and publish unsupported/unresolved disciplinary mass.
- [ ] **Knockout simulation:** Winners advance — verify rank-pair constraints, frozen draw positions, two-leg venue order, extra time, penalties, and neutral final.
- [ ] **Format backtest:** Historical UCL was replayed — distinguish old-format match validation from scarce new-format end-to-end evidence.
- [ ] **Dashboard adapter:** UCL renders — verify all typed unavailable/stale/pre-draw/draw-known states and escaping of external strings.
- [ ] **N-edition publisher:** Three routes publish — property-test arbitrary registry sizes and byte-for-byte rollback after any route/read-back failure.
- [ ] **Automation:** Scheduled refresh ran once — test 429, 5xx, empty/null, delayed score, postponed match, dirty worktree, no-network, and concurrent-run cases.
- [ ] **Reproducibility:** Same seed reproduces totals — also verify stable RNG streams across batch size and parallel worker count.
- [ ] **Public trust:** Probabilities sum correctly — also verify source age, model/rules lineage, credits, and approximation disclosures are visible.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Prohibited source embedded in automation | HIGH | Disable updater, restore last lawful bundle, remove redistributed raw content, review history/exposure, replace adapter, re-accept lineage |
| API token exposed | MEDIUM | Revoke/rotate token, scrub generated logs/artifacts, add secret scan, rebuild from clean credential path |
| Club model promoted without valid evidence | HIGH | Freeze UCL publication at last trustworthy state, demote selector, retain results-only dashboard, rebuild club benchmark and release gate |
| Leakage discovered | HIGH | Invalidate affected backtests/releases, rebuild point-in-time features, rerun all folds, republish model card and corrected forecasts |
| Incorrect tie-break or bracket | MEDIUM | Version a corrected ruleset, replay adversarial and historical tests, regenerate outcomes, publish correction metadata without rewriting old lineage |
| Partial/stale batch promoted | MEDIUM | Restore retained previous release byte-for-byte, invalidate candidate batch ID, fix staging/validation, rerun complete envelope |
| Identity collision/duplicate matches | MEDIUM | Quarantine affected source bundle, correct registry mapping, regenerate canonical corpus and all downstream ratings/releases |
| Unsupported enrichment published | MEDIUM | Replace sections with typed unavailable state, remove claims/artifacts, audit source attribution and model features |
| Simulation too slow for schedule | LOW–MEDIUM | Keep last valid publication, profile ranking/draw loops, vectorize/batch, lower count only under a predeclared error tolerance |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Prohibited or unstable source | Source and identity contract | Terms review recorded; scheduled code contains no UEFA scraping; source adapter contract tests pass |
| Provider conditions/token/rate limit | Source and identity contract + release hardening | Secret scan clean; attribution rendered; request-budget and 429 tests pass |
| National-team model reused for clubs | Club model and promotion gate | UCL release IDs resolve only to club manifests; baseline/promotion evidence is independent |
| Cross-league incomparability and duplicate history | Source and identity contract | Coverage matrix, key-cardinality, duplicate, score-semantic, and cold-start tests pass |
| Temporal/simultaneous-match leakage | Club model and promotion gate | Point-in-time audit proves all feature availability precedes kickoff; Matchday 8 freeze test passes |
| Incomplete league-phase ranking | Rules and tournament simulation | Golden/adversarial tests exercise all criteria and interim/final modes |
| Missing disciplinary tie-break evidence | Rules and tournament simulation | Unsupported resolver rate is measured; exact mode blocks or ambiguity mass is published |
| Invalid knockout paths | Rules and tournament simulation | Exhaustive pairing invariants and completed-draw replay pass |
| Score/status semantics | Source contract + rules simulation | Regulation/ET/shootout/postponed/awarded fixtures pass fixtures and never contaminate training |
| False new-format validation | Model + rules phases | Model card separates match, rules, and end-to-end evidence; only new-format seasons support format claims |
| Third hard-coded publisher branch | Dashboard registry and publication | 0/1/N property tests and incumbent byte-preservation tests pass |
| Partial or stale refresh | Automated refresh and release hardening | Failure injection retains last-known-good bytes; freshness and bundle-coherence gates block promotion |
| Fabricated xG/injuries/lineups | Model + dashboard phases | No current metric lacks match-level source lineage; unavailable states render correctly |

## Sources

Primary and current sources (MEDIUM confidence under the research provider's verified confidence classification):

- [UEFA Champions League 2026/27 regulations](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27-Online) — edition/effective date and authoritative articles 13–29.
- [UEFA explanation of league-phase ranking criteria](https://www.uefa.com/uefachampionsleague/news/0291-1bd88ae04870-e1e038c319e3-1000--champions-league-league-phase-standings-how-teams-level-on-/) — interim versus completed-league tie-break order.
- [UEFA Article 16: league-phase draw](https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-16-Draw-system-league-phase-Online) — pots, opponent counts, home/away allocation, association constraints, and UEFA adaptation power.
- [UEFA 2025/26 knockout draw explanation](https://www.uefa.com/uefachampionsleague/news/02a2-1ffe3d954170-60c0b7443c85-1000--uefa-champions-league-round-of-16-quarter-final-and-semi/) — rank-paired slots, frozen bracket paths, and leg ordering.
- [UEFA platform terms](https://www.uefa.com/termsconditions/) — systematic collection and automated scraping restrictions.
- [football-data.org free-plan pricing](https://www.football-data.org/pricing) and [coverage](https://www.football-data.org/coverage) — delayed scores/schedules, fixtures, tables, 10 calls/minute, and UCL availability.
- [football-data.org API policies](https://docs.football-data.org/general/v4/policies.html) — throttling, valid null/empty values, and UTC defaults.
- [football-data.org terms](https://www.football-data.org/about) and [FAQ](https://www.football-data.org/documentation/faq) — application scope, credential secrecy, attribution, cancellation/retention constraint, accuracy/availability disclaimer, and logo rights.
- [OpenFootball Champions League repository](https://github.com/openfootball/champions-league) — CC0 historical season folders through 2025/26 at research time.
- [StatsBomb Open Data repository](https://github.com/statsbomb/open-data) and current [`competitions.json`](https://raw.githubusercontent.com/statsbomb/open-data/master/data/competitions.json) — selected event-data structure, attribution requirements, and UCL seasons no later than 2018/19 at research time.
- [Club coefficients in the UEFA Champions League: Time for shift to an Elo-based formula](https://arxiv.org/abs/2304.09078) — evidence that domestic results and cross-league strength matter for club forecasting.
- [Ratings of European and South American Football Leagues Based on Glicko-2 with Modifications](https://arxiv.org/abs/2310.11459) — cross-league ratings, home/draw behavior, and league-transition considerations.

Project evidence:

- `.planning/PROJECT.md` — open-data-first, fail-closed, separately validated club authority, and truthful missing-data decisions.
- `R/dashboard/payload_contract.R`, `R/dashboard/production_provider.R`, and `R/dashboard/publication.R` — current two-edition assumptions that must be generalized rather than copied.

## What Might Still Be Missing

- A legal owner should review the chosen provider's current terms before public launch; this research is technical risk analysis, not legal advice.
- The exact permitted retention/display behavior for a free football-data.org account should be confirmed in writing because the published cancellation clause creates an operational exit risk.
- A source for current disciplinary points may change the recommended ambiguity strategy. Until one is accepted, exact final-rank claims should remain gated.
- The 2026/27 rules allow UEFA to adapt draw conditions for constraints. The accepted rules bundle must include any edition-specific draw-procedure notices, not only the base regulations.

---
*Pitfalls research for: xGelo v4.0 UEFA Champions League Forecast Dashboard*
*Researched: 2026-09-19*
