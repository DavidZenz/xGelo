# PITFALLS: Football Forecasting (Elo + xG) for WCQ-UEFA

---

## 🚨 Data Pipeline Pitfalls

### 1. Training-Prediction Data Contamination
**Problem:** StatsBomb Open Data includes World Cups and Euros but **not WCQ-UEFA**. Using WCQ shots from StatsBomb for training xG, then applying to WCQ prediction, creates circular validation. International tournaments (World Cup, Euros) have different dynamics than qualifiers.

**Warning Signs:**
- xG model test AUC > 0.85 (likely leaking international tournament data)
- Feature importance shows competition_type as top predictor
- Backtest performance drops sharply when excluding tournament data

**Prevention:**
- Train xG model **only** on domestic league data from StatsBomb
- Explicitly filter out `competition.competition_name` containing "World Cup", "Euros", "Qualifiers", "Nations League"
- Maintain separate data lineages: `statsbomb_leagues/` vs `wcq_cache/`

**Phase:** DATA-01, DATA-03

---

### 2. Team Name Inconsistency Across Sources
**Problem:** martj42 uses "Germany", StatsBomb uses "Germany" but also "Turkey" vs "Türkiye", "Macedonia" vs "North Macedonia", "Czech Republic" vs "Czechia", "Russia" vs historical "USSR"/"CIS". WCQ groups often include teams with multiple historical identities.

**Warning Signs:**
- Elo ratings exist for 200 teams but xG data only maps to 150
- Missing matches in merged datasets
- Sudden rating jumps for teams (indicator of split identity)

**Prevention:**
- Build canonical mapping table before any merge: `team_name_map.csv`
- Use fuzzy matching with manual override for known aliases
- Store `team_id` (FIFA code) as primary key, not name strings
- Validate: every team in WCQ fixtures must have Elo history and xG data availability flag

**Phase:** DATA-02

---

### 3. Ignoring Match Context in xG Model
**Problem:** xG models trained on league data assume standard conditions. International football has: neutral venues (no home advantage), extreme weather, artificial pitches, different referee standards.

**Warning Signs:**
- xG values for away teams in WCQ systematically lower than league baselines
- Calibration plots show underestimation of goals in cold-weather venues
- Model performs worse for Northern European away matches

**Prevention:**
- Include `venue_type` (home/away/neutral) and `surface` (grass/artificial) as xG features
- Add `temperature` or `weather_condition` if available from FIFA match reports
- Separate calibration for neutral-venue matches
- Flag: WCQ matches with venue != either team's FIFA-registered home venues

**Phase:** XG-03, XG-04

---

## ⚖️ Elo Rating Pitfalls

### 6. Infrequent Matches Causing Stale Ratings
**Problem:** National teams play 8-12 matches/year vs 38+ for clubs. Elo ratings decay slowly. A team's rating may reflect 2022 form in 2024. WCQ groups have 8-10 matches over 2+ years.

**Warning Signs:**
- Teams with long winless streaks still have high Elo
- Rating changes < 5 points after dramatic result (e.g., San Marino beating someone)
- Old matches have disproportionate weight

**Prevention:**
- Increase k-factor for infrequent teams (k=40 for teams playing <15 matches/year, k=20 for active teams)
- Implement rating decay: multiply by 0.995^(days_since_last_match/365)
- Weight recent matches exponentially (EWMA on match outcomes for rating calculation)
- Separate "current form" from "base rating" (two-component Elo)

**Phase:** ELO-02, ELO-04

---

### 7. Home Advantage Miscalibration in Qualifiers
**Problem:** Standard Elo uses 60-100 point home advantage. But WCQ has true neutral venues, empty stadiums, reverse home advantage in hostile environments, and groups where stronger team plays away first.

**Warning Signs:**
- Home win percentage in WCQ predictions > 55% (actual: ~48% in WCQ-UEFA)
- Draw frequency predictions < 25% (actual: ~28% in qualifiers)
- Systematic error: home teams overrated in away-heavy groups

**Prevention:**
- Set home advantage to **40 points** for WCQ (not 60)
- Flag neutral venues: stadium not in either team's FIFA-registered home venues
- Add `is_neutral` boolean, set home advantage = 0 for neutrals
- Validate home advantage parameter via rolling-origin on historical WCQ data

**Phase:** ELO-03, FORECAST-05

---

## 🎯 Forecasting Model Pitfalls

### 9. Poisson Assumption Violations
**Problem:** Football goals follow **overdispersed** Poisson (variance > mean). Standard Poisson underestimates probability of 0 and 4+ goals. WCQ-UEFA: 0-0 draws are common (12% of matches), 4+ goal matches rare (8%).

**Warning Signs:**
- Predicted 0-0 probability consistently < 10%
- Predicted 4+ goal probability > 5% for typical matches
- Calibration plot shows U-shaped pattern (overconfident in middle)

**Prevention:**
- Use **Negative Binomial** distribution, not Poisson
- Or use **Poisson with random effects** (team-specific attack/defense strength)
- Add dispersion parameter estimation in training
- Validate: predicted 0-0 frequency should match ~12%, 4+ goals ~8%

**Phase:** FORECAST-01, FORECAST-02

---

### 10. Ignoring Draw Probability Calibration
**Problem:** Football's three-outcome nature means draw probability must be explicitly calibrated. Standard win probability models (logistic regression) don't handle draws natively. WCQ-UEFA draw rate: ~28% (vs ~25% in leagues).

**Warning Signs:**
- Predicted draw probability < 20% on average
- Brier score for draws > 0.25
- Users complain "model never predicts draws"

**Prevention:**
- Use **ordered logistic** or **trichotomous regression** for win/draw/loss
- Or: model home goals ~ Poisson(λ_h), away goals ~ Poisson(λ_a), draw = P(hg=ag)
- Calibrate specifically on draw frequency: target 28% in WCQ
- Add draw adjustment factor if needed

**Phase:** FORECAST-04, FORECAST-05

---

## ⚖️ Legal & Operational Pitfalls

### 13. ToS Violation via Automated FotMob Scraping
**Problem:** FotMob ToS explicitly prohibits "systematic or automated" data collection. WCQ-UEFA requires ~200 matches × 2 teams × ~10 shots/match = 4,000 shot records. Manual collection is impractical.

**Warning Signs:**
- Scripts with `httr2::request_perform()` hitting FotMob endpoints
- Rate limiting or IP blocks from FotMob
- Large cache directories with FotMob data

**Prevention:**
- **No automated scraping of FotMob** — period
- Use **manual cache only**: researchers manually save pages they visit
- Store FotMob data in `wcq_cache/manual/` with checksum verification
- Document each cached match: date collected, source URL, collector initials
- Implement `is_manual_cache` flag in data pipeline

**Phase:** PIPELINE-02

---

### 14. Redistributing Restricted Data
**Problem:** FBref, Transfermarkt, Understat all have ToS restrictions. Even "public" data from UEFA/FIFA pages may have usage limits. Redistributing raw data violates ToS and could trigger DMCA.

**Warning Signs:**
- Raw JSON/HTML files from restricted sources in Git repo
- Data export functions that output raw source data
- Package dependencies on scraped datasets

**Prevention:**
- **Never commit raw data from restricted sources to Git**
- Store restricted data in `.gitignore`d directories only
- Only distribute **derived aggregate statistics** (team-level xG, not shot-by-shot)
- Add `LICENSE.md` to cache directory explaining restrictions
- Use `usethis::use_git_ignore()` for all cache dirs

**Phase:** PIPELINE-01

---

## 📊 Evaluation Pitfalls

### 16. Evaluating on Wrong Metric
**Problem:** AUC is good for xG (shot-level classification). But for **match forecasting**, AUC on match outcomes is misleading (only 3 possible outcomes). Use **log loss** or **Brier score** for probabilities, **calibration** for reliability.

**Warning Signs:**
- Reporting AUC for match win/draw/loss prediction
- No calibration plots in evaluation
- Brier score not computed

**Prevention:**
- xG model: AUC (shot classification), calibration plot (binned)
- Match forecast: **Brier score** (primary), log loss, calibration plot
- Group prediction: **rank probability score (RPS)** for full standings
- Always report: metric, dataset, time period, number of matches

**Phase:** XG-06, FORECAST-05

---

## 🏗️ Architecture Pitfalls

### 19. Tight Coupling Between Data and Model
**Problem:** Changing data source (e.g., switching from FotMob cache to manual entry) breaks model. xG feature calculation depends on specific StatsBomb schema.

**Warning Signs:**
- Feature engineering code embedded in model training script
- Model expects exact column names from specific data version
- No schema validation

**Prevention:**
- **Feature contract**: define exact inputs (distance, angle, body_part, play_pattern) with types and ranges
- Use `targets` pipeline with explicit dependencies: `xg_features ← statsbomb_events`
- Schema validation: `pointblank::informant()` on all ingested data
- Unit tests for feature calculation (TEST-01)

**Phase:** PIPELINE-01, TEST-01

---

### 20. Not Reproducible Due to Random Seeds
**Problem:** Monte Carlo simulations, logistic regression with splines, and Elo rating updates use randomness. Without fixed seeds, results aren't reproducible.

**Warning Signs:**
- Outputs change between runs with same input
- No `set.seed()` in scripts
- Tests fail intermittently

**Prevention:**
- `set.seed(2025)` at start of every script
- For parallel operations: use `future::plan(multisession)` with `seed = TRUE`
- Document seed values in outputs
- Validate reproducibility: run pipeline twice, compare outputs with `waldo::compare()`

**Phase:** PIPELINE-01, TEST-03

---

## 📈 Validation Checklist

| Pitfall | Detected By | Prevention Implemented | Phase |
|---------|-------------|------------------------|-------|
| Training-prediction contamination | xG test set includes intl competitions | Train on domestic leagues only | DATA-03, XG-04 |
| Team name inconsistency | Missing teams in merged data | Canonical mapping table | DATA-02 |
| Context-ignoring xG | Poor weather venue performance | Add venue/surface features | XG-03 |
| Poisson violations | 0-0 underpredicted | Negative Binomial distribution | FORECAST-01 |
| Draw calibration | Draw prob < 20% | Ordered logistic regression | FORECAST-04 |
| Overconfident estimates | No uncertainty output | Monte Carlo with intervals | FORECAST-03 |
| ToS violation | Automated FotMob scraping | Manual cache only | PIPELINE-02 |
| Data redistribution | Raw data in Git | `.gitignore` all cache | PIPELINE-01 |
| Tight coupling | Breaks on data change | Feature contract + schema validation | PIPELINE-01 |
| Non-reproducible | Results vary between runs | Fixed seeds everywhere | PIPELINE-01 |

---
*Generated: 2026-06-03 | Domain: Football Forecasting (Elo + xG) | Project: xGelo*
