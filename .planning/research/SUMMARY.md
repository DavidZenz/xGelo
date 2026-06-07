# xGelo Research Summary

## Overview
Free, open-data forecasting system combining Elo ratings with expected goals (xG) to predict UEFA World Cup Qualifiers match outcomes. Uses hybrid architecture: open-licensed training data (StatsBomb, martj42) + carefully cached target data (FotMob).

---

## Key Findings

### Stack
- **R** with **targets** (orchestration), **tidymodels** (modeling), **httr2** (HTTP)
- **martj42** for international results/Elo backbone, **StatsBomb Open Data** for xG model training
- **FotMob** as optional, manually-cached WCQ shot data layer (ToS-restricted)
- **Custom Elo implementation** (~50 LOC) for full control over k-factor, home advantage, rating decay
- **Negative Binomial** distribution recommended over Poisson for overdispersed football goals

### Features
- **Must build**: Elo ratings, minimal xG model (distance, angle, body part, play pattern), Poisson/NB goal models, Monte Carlo simulation (50K scenarios/fixture)
- **Nice-to-have**: Mixed-effects extensions, pre-shot sequence features, injury/line-up integration
- **Anti-features**: Real-time scraping (ToS), paid data feeds, live betting integration, deep learning

### Architecture
- Modular **targets** pipeline with clear separation: open training data → xG model → Elo layer → forecasting
- Three operating modes: **Open** (no WCQ shots), **Hybrid** (cached FotMob), **Experimental** (full archive)
- Local caching, file versioning, schema validation for all ingested data
- Clean layer boundaries: Data → xG → Elo → Integration → Forecast

### Pitfalls
- **Legal**: FotMob ToS prohibits automated/systematic use; FBref removed advanced xG data (Jan 2026)
- **Technical**: Team name harmonization required (Türkiye/Turkey, North Macedonia/Macedonia)
- **Operational**: Public web scrapers fragile to endpoint/HTML changes; no clean open-licensed WCQ shot source
- **Model**: Poisson distribution underestimates 0-0 draws and 4+ goal matches; need Negative Binomial
- **Evaluation**: AUC inappropriate for match-level prediction; use Brier score + calibration plots

---

## Recommendations

### Phase 1: MVP (Open Mode)
1. **Foundation**: Set up R project with renv, targets, tidymodels
2. **Data**: Ingest martj42 (results, shootouts, goal scorers) and StatsBomb Open Data (events, lineups)
3. **Team names**: Build canonical mapping table (FIFA codes as primary keys)
4. **xG Model**: 
   - Implement feature contract: distance, angle, header, open_play, competition
   - Train logistic regression with splines using tidymodels/parsnip
   - Train **only on domestic league data** (exclude World Cup, Euros, Qualifiers)
   - Target: AUC ≥ 0.75 on held-out domestic leagues
5. **Elo Layer**:
   - Custom implementation with k-factor tuning
   - Home advantage: 60 points for non-neutral, 0 for neutral venues
   - Rating decay for infrequent teams (0.995^days/365)
   - Compute from all international matches (1872-present)
6. **Integration**: Team-match xG metrics (xGF, xGA, xGD) + rolling form (EWMA 6-12)
7. **Forecast**: 
   - Negative Binomial for home/away goals (not Poisson)
   - Monte Carlo simulation: 50,000 scenarios per fixture
   - Calibrate to WCQ-UEFA draw rate (~28%)
8. **Pipeline**: targets DAG with schema validation, unit tests, caching
9. **Documentation**: Research notebook showing AUC ≥ 0.75, calibration plots

### Phase 2: Enhancements
1. **Mixed-effects xG**: Add team random effects (glmmTMB or mgcv)
2. **Pre-shot sequence**: Include 1-3 preceding events (if data available)
3. **WCQ Hybrid Mode**: Manual cache of FotMob shot data for WCQ matches
4. **Group stage simulation**: Full group table simulation, not just single matches
5. **Advanced validation**: Rolling-origin time-series CV, concept drift detection
6. **SPI-inspired rating evolution**: See `SPI_MODEL_EVOLUTION.md` for notes on offensive/defensive ratings, xG-based updates, and non-shot threat proxies.

### Phase 3: Production Readiness
1. **Performance**: Optimize Monte Carlo (target <10s per fixture)
2. **Robustness**: Retry logic, rate limiting, error handling for all HTTP requests
3. **Legal compliance**: Document all data sources, licenses, usage restrictions
4. **Distribution**: Package as installable R package with vignettes

---

## Critical Success Factors

| Factor | Success Criteria | Measurement |
|--------|------------------|-------------|
| xG Model Quality | AUC ≥ 0.75 | Backtest on held-out domestic league data |
| Elo Calibration | Rating changes reflect form | Manual review of recent matches |
| Forecast Accuracy | Draw frequency 25-30% | Compare predicted vs WCQ-UEFA historical |
| Pipeline Reproducibility | Same input = same output | Run pipeline twice, compare with waldo::compare() |
| Performance | 50K sims in <10s | Benchmark on M1/M2 Mac |
| Legal Compliance | No automated FotMob scraping | Code review, no httr2 calls to FotMob |

---

## Blockers & Risks

### High Risk
- **No open WCQ shot data**: FotMob ToS prevents automated collection; manual cache is labor-intensive
- **FBref data removal**: Advanced metrics no longer available (since Jan 2026)

### Medium Risk
- **Team name harmonization**: Requires manual mapping; political name changes complicate
- **Model drift**: Football tactics evolve; need annual retraining
- **Overdispersion**: Poisson may not capture goal variance; Negative Binomial adds complexity

### Low Risk
- **xG model performance**: Literature confirms AUC 0.75-0.79 achievable with minimal features
- **Elo ratings**: Well-understood; martj42 dataset is comprehensive
- **Pipeline orchestration**: targets is proven for analytical projects

---

## Data Sources Summary

| Source | Type | Coverage | License | Usage |
|--------|------|----------|---------|-------|
| martj42 | Match results | 1872-present | CC0/Open | ✅ Automatic, Elo backbone |
| StatsBomb Open Data | Events, lineups | Selected tournaments | CC BY-NC-SA 4.0 | ✅ Automatic, xG training (leagues only) |
| FotMob | WCQ shots, xG | 2012/13-present | Restricted | ⚠️ Manual cache only |
| UEFA/FIFA pages | Fixtures, lineups | Current | Public | ⚠️ Manual, rate-limited |
| FBref | Historical data | Varies | Restricted | ❌ Not recommended (metrics removed) |

---

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| **R language** | Existing expertise, strong data science ecosystem (tidymodels, targets) |
| **targets for orchestration** | Designed for reproducible, incremental analytical projects; actively maintained |
| **Custom Elo** | CRAN package inflexible; need home advantage customization, rating decay |
| **Logistic regression baseline** | Interpretable, fast, achieves AUC ≥ 0.75; can extend later |
| **Negative Binomial** | Football goals overdispersed; Poisson underestimates 0 and 4+ goals |
| **Manual WCQ cache** | FotMob ToS prohibits automated scraping; legal compliance required |

---

## Next Steps

1. ✅ **Completed**: Project initialization, research phase
2. 🔄 **In Progress**: REQUIREMENTS.md, ROADMAP.md, STATE.md creation
3. ⏳ **Next**: `/gsd-discuss-phase 1` to gather Phase 1 context
4. 📋 **After**: `/gsd-plan-phase 1` to create execution plan

---
*Last updated: 2026-06-03 | Research lead: GSD Analysis*
