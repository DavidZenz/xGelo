# Football Forecasting Features: Elo + xG for WCQ-UEFA

## Feature Categories

| Category | Definition | Priority |
|----------|------------|----------|
| Table Stakes | Users expect it; absence causes immediate rejection | Must have for MVP |
| Differentiators | Unique value that beats competitors | Build after MVP |
| Anti-features | Deliberately excluded; misaligned with project goals | Never build |

---

## 📊 Table Stakes

### Core Forecasting
```r
# Output format users expect
data.frame(
  fixture = c("England vs Italy"),
  home_win_p = c(0.45),
  draw_p = c(0.28),
  away_win_p = c(0.27),
  expected_goals_home = c(1.8),
  expected_goals_away = c(1.4)
)
```

| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **Win/Draw/Loss probabilities** | Low | Elo + xG integration | Non-negotiable; core output |
| **Expected goals (xG) per team** | Low | xG model | Per-match, pre-match |
| **Elo ratings per team** | Medium | martj42 dataset | Historical team strength |
| **Poisson goal distribution** | Medium | Elo, xG | Standard football model |
| **Pre-match predictions only** | Low | None | No live/in-play needed |

### Data Coverage
| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **UEFA WCQ fixtures coverage** | Medium | UEFA/FIFA pages | All qualifiers |
| **Team name normalization** | Medium | DATA-02 | Turkey/Türkiye, etc. |
| **Historical results** | Medium | martj42 | All intl matches |
| **Basic match metadata** | Low | None | Date, venue, competition |

### Model Quality
| Feature | Complexity | Dependencies | Notes |
|---------|------------|--------------|-------|
| **AUC ≥ 0.75 for xG model** | High | XG-01 to XG-06 | Validated baseline |
| **Calibrated probabilities** | Medium | FORECAST-05 | Predicted % matches observed |
| **Model interpretability** | Medium | Logistic regression | No black boxes |
| **Reproducible results** | Medium | PIPELINE-01 | Same input = same output |

---

## 🎯 Differentiators

### Hybrid Model Advantages
```r
# xGelo's unique value prop
elo_adjusted_xg <- function(team_elo, opponent_elo, xg) {
  # Elo adjustment factor for xG scaling
  elo_diff <- team_elo - opponent_elo
  adjustment <- exp(elo_diff / 400)  # ~1.5x per 200 Elo points
  adjusted_xg <- xg * adjustment
  return(adjusted_xg)
}
```

| Feature | Complexity | Dependencies | Competitive Edge |
|---------|------------|--------------|------------------|
| **Elo + xG hybrid architecture** | High | ELO-01, XG-04 | Most models use one or the other |
| **Free/open-data only** | Medium | DATA-01, DATA-03 | No paid feeds required |
| **WCQ-UEFA specialization** | Medium | Data filtering | Better than generic models |
| **Home advantage tuning** | Medium | ELO-03 | 60-point adjustment |
| **Monte Carlo simulation (50k scenarios)** | Medium | FORECAST-03 | <10 seconds target |

### Advanced Metrics
| Feature | Complexity | Dependencies | Competitive Edge |
|---------|------------|--------------|------------------|
| **Team-match xG metrics** | Medium | INTEGR-01 | xGF, xGA, xGD per game |
| **Rolling form (EWMA 6-12 matches)** | Medium | INTEGR-02 | Recent performance weighting |
| **Backtested performance** | High | TEST-03 | AUC, calibration plots |
| **Feature attribution** | Medium | Logistic regression | Explain why model predicts X |

### Transparency & Trust
| Feature | Complexity | Dependencies | Competitive Edge |
|---------|------------|--------------|------------------|
| **Open source code** | Low | None | Builds community trust |
| **Data provenance tracking** | Medium | PIPELINE-02 | Every output traceable to source |
| **Incremental updates** | Medium | targets | Only reprocess changed data |
| **Schema validation** | Medium | PIPELINE-03 | Data quality guarantees |

### Stretch Differentiators
| Feature | Complexity | Dependencies | Competitive Edge |
|---------|------------|--------------|------------------|
| **Mixed-effects xG model** | High | XG-06 stretch | Team random effects |
| **Sequence-aware xG** | High | StatsBomb events | Preceding events context |
| **Three operating modes** | Medium | Architecture | Open/Hybrid/Experimental |
| **Full rolling-origin validation** | High | TEST-03 | Rigorous backtesting |

---

## ❌ Anti-Features

### Out of Scope (Legal/Technical)
| Anti-feature | Reason | Alternative |
|--------------|--------|-------------|
| **Real-time/live predictions** | Manual cache only; no continuous scraping | Pre-match batch only |
| **Automated FotMob scraping** | ToS prohibits systematic use | Manual cache updates |
| **Paid data feeds (Opta, etc.)** | Project constraint: free only | StatsBomb Open Data |
| **FBref integration** | Advanced metrics removed Jan 2026 | martj42 primary |
| **Tracking data (360)** | Not available free for WCQ | Focus on event data |
| **Injury/suspension data** | No clean free source | Model without it |

### Out of Scope (Product)
| Anti-feature | Reason | Alternative |
|--------------|--------|-------------|
| **Commercial betting integration** | Not a betting product | Educational/analytical only |
| **Mobile app / web dashboard** | Focus on model, not UI | CLI/R output only |
| **Live scoring system** | Real-time excluded | Pre-match focus |
| **Full sports data API** | Scope: forecasting only | Single-purpose tool |
| **Women's football** | Scope limited to men's WCQ | Future extension possible |
| **Youth tournaments** | Focus on senior national teams | Keep scope tight |

### Out of Scope (Model Complexity)
| Anti-feature | Reason | Alternative |
|--------------|--------|-------------|
| **Black-box models** | Interpretability required | Logistic regression, Poisson |
| **Deep learning / neural nets** | Overkill for AUC ≥ 0.79 target | Simple models sufficient |
| **Bayesian hierarchies** | Complexity not justified | Frequentist sufficient |
| **Survival analysis** | Not applicable to match outcomes | Poisson for goals |
| **Time-series forecasting** | Matches are discrete events | Per-match models |

---

## Dependency Graph

```
Data Layer (DATA-01 to DATA-04)
    ├── martj42 → Elo Layer (ELO-01 to ELO-04)
    │       └── ELO-03 (home advantage) depends on team metadata
    ├── StatsBomb → xG Model (XG-01 to XG-06)
    │       └── XG-03 (feature contract) depends on coordinate calcs
    └── WCQ Cache → Integration Layer (INTEGR-01, INTEGR-02)

Elo Layer + xG Model + Integration Layer → Forecasting Layer (FORECAST-01 to FORECAST-05)

All layers → Pipeline (PIPELINE-01 to PIPELINE-03)
All outputs → Validation (TEST-01 to TEST-03, VIS-01, VIS-02)
```

---

## Complexity Matrix

| Complexity | Features |
|------------|----------|
| **Low** | Win/draw/loss probs, expected goals output, pre-match only, basic metadata, open source, data provenance, Poisson goal model |
| **Medium** | Elo ratings, xG model (AUC 0.75), team name normalization, WCQ coverage, home advantage, Monte Carlo sim, xG metrics, rolling form, backtesting, incremental updates, schema validation, interpretability, three operating modes |
| **High** | Hybrid architecture (Elo+xG), mixed-effects xG, sequence-aware xG, full rolling-origin validation, calibrated probabilities, reproducibility guarantees |

---

## Validation Checklist

- [x] Categories are clear (table stakes vs differentiators vs anti-features)
- [x] Complexity noted for each feature
- [x] Dependencies between features identified
- [x] Aligns with PROJECT.md constraints and decisions
- [x] Specific to WCQ-UEFA context
- [x] Reflects free/open-data philosophy
