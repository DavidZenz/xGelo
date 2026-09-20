# Requirements: xGelo v4.0

**Defined:** 2026-09-19
**Core Value:** Accurate, calibrated football forecasting without dependence on paid data feeds.

## v4.0 Requirements

### Source Acceptance and Club Identity

- [x] **UCLSRC-01**: The operator can run a live-key acceptance check covering API rights, attribution, retention, quota, schema, completeness, and freshness before automated UCL acquisition is enabled.
- [x] **UCLSRC-02**: The operator can ingest current UCL fixtures, results, standings, clubs, and lifecycle metadata without storing provider credentials in generated artifacts or Git.
- [x] **UCLSRC-03**: Every accepted current-state artifact records provider, retrieval time, source-as-of time, edition, schema version, and content hashes.
- [ ] **UCLSRC-04**: A failed, empty, stale, or incomplete retrieval retains the last known good accepted bundle and records a blocked refresh with a machine-readable reason.
- [x] **CLUBID-01**: Every club resolves to one stable internal identity through source IDs, validity-aware aliases, and explicit rejection of ambiguous or cross-domain matches.
- [x] **CLUBHIST-01**: Historical domestic and European club results are pinned, licensed, audited for coverage, duplication, and score semantics, and normalized with point-in-time availability for model training.

### Independent Club Forecast Authority

- [ ] **CLUBMOD-01**: The project can train club-only rating and goal models without consuming national-team features, releases, or selectors as forecast authority.
- [ ] **CLUBMOD-02**: Club-model evaluation uses frozen rolling-origin and cross-league folds with explicit information cutoffs and same-kickoff leakage tests.
- [ ] **CLUBMOD-03**: A club candidate is promoted only after passing predeclared proper-score, calibration, coverage, and reproducibility gates against documented baselines.
- [ ] **CLUBMOD-04**: The approved club release is immutable, selector-authorized, documented by a model card, and rejected by national-team consumers while national-team releases are rejected by club consumers.
- [ ] **CLUBMOD-05**: Current xG, injury, lineup, suspension, and player features remain typed unavailable unless a separately accepted lawful source contract exists.

### UCL Rules and Tournament Outcomes

- [ ] **UCLRULE-01**: Users can see a recomputed 36-club league-phase table with accessible top-8, ranks 9-24, and ranks 25-36 qualification bands.
- [ ] **UCLRULE-02**: Interim and final editioned tie-breakers execute in official order and expose the decisive criterion or an unresolved rank when required evidence is unavailable.
- [ ] **UCLRULE-03**: Users can inspect the accepted eight-opponent schedule, matchday, venue, kickoff, status, and score for every league-phase club.
- [ ] **UCLOUT-01**: Users can see immutable pre-kickoff home/draw/away, expected-goals, and likely-score forecasts only when an approved club release covers the fixture.
- [ ] **UCLOUT-02**: Users can see mutually exclusive top-8, play-off, and eliminated probabilities plus rank and cut-line distributions conditioned on accepted completed results.
- [ ] **UCLOUT-03**: Simulations represent only legal rank-constrained knockout play-off and round-of-16 paths and condition on accepted draw artifacts when available.
- [ ] **UCLOUT-04**: Knockout simulation handles two legs, aggregate scores, extra time, penalties, the absence of the away-goals rule, ranking-based leg order, and a neutral final.
- [ ] **UCLOUT-05**: Each club's progression probabilities reconcile with league-phase bands and remain monotone through play-off, round of 16, quarter-final, semi-final, final, and champion stages.
- [ ] **UCLOUT-06**: Repeated simulations with identical source, rules, model, and seed inputs reproduce byte-equivalent outcome artifacts.

### Dashboard and Atomic Publication

- [ ] **UCLDASH-01**: Users can browse UCL standings, fixtures, results, club form, match forecasts, rank distributions, qualification bands, knockout paths, and progression probabilities in the shared responsive dashboard.
- [ ] **UCLDASH-02**: The UCL page shows source freshness, delayed-data status, rules version, model release and cutoff, simulation seed, batch identity, attribution, and last-known-good status.
- [ ] **UCLDASH-03**: Missing enrichment, unresolved ties or draws, and blocked or stale states render explicitly without zero-filling, hidden omission, or fabricated certainty.
- [ ] **UCLPUB-01**: Public routes, adapters, expected artifacts, output limits, and credits are derived from an enabled-edition registry that supports zero, one, or many editions.
- [ ] **UCLPUB-02**: Nations League and EURO outputs remain compatible while UCL joins the same staged, validated, atomic promotion, read-back, and rollback transaction.

### Automated Operations and Release Acceptance

- [ ] **UCLOPS-01**: Scheduled refreshes respect provider quotas, caching, retry and backoff, non-overlap, secret redaction, and lifecycle-specific freshness limits.
- [ ] **UCLOPS-02**: A retrieval, model, rules, simulation, render, promotion, or read-back failure leaves every incumbent public edition byte unchanged.
- [ ] **UCLOPS-03**: Failure-injection tests cover rate limits, server errors, null, empty, stale, and postponed data, no network, concurrent runs, and provider exit.
- [ ] **UCLOPS-04**: Release acceptance proves deterministic performance, compact outputs, browser and accessibility behavior, recovery runbooks, and an end-to-end three-edition refresh.

## Future Requirements

### Post-v4 Enhancements

- **UCLFUT-01**: Users can run isolated what-if result scenarios without overwriting the published baseline.
- **UCLFUT-02**: Users can inspect richer schedule-strength and forecast-change explanations derived from frozen inputs.
- **UCLFUT-03**: The model can consume advanced event, lineup, injury, or suspension data after a lawful source and incremental-value test are accepted.
- **UCLFUT-04**: Users can forecast UCL qualifying rounds after their distinct data and rules contracts are implemented.
- **UCLFUT-05**: Additional UEFA club competitions can reuse the registry after competition-specific schedule, ranking, and bracket rules are implemented.
- **UCLFUT-06**: The public product can approach near-live refreshes after source SLA, hosting, cost, and monitoring requirements justify a different operating model.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Automated scraping of UEFA web pages | Current terms do not provide an accepted automated match-state contract; UEFA material is retained only as manually reviewed rules evidence. |
| Reusing the national-team forecast release for clubs | Club schedules, strength dynamics, and evaluation populations require independent model authority. |
| Unsupported current xG, injuries, lineups, suspensions, or player projections | No accepted free production source currently supports truthful automated claims. |
| Real-time event tracking | The accepted free source is delayed and the static publication system does not promise live state. |
| Browser-side authenticated API requests | This would expose credentials and bypass accepted source, validation, and atomic publication boundaries. |
| Betting odds, tips, or expected-value recommendations | The product publishes analytical probabilities, not wagering advice. |
| Invented round-robin fixtures or guessed knockout brackets | The UCL uses an accepted eight-opponent schedule and rank-constrained, draw-conditioned paths. |
| Database, application server, or new frontend framework | The existing R, targets, and static dashboard architecture is sufficient for the milestone. |

## Traceability

Each active v4.0 requirement will map to exactly one roadmap phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UCLSRC-01 | Phase 18 | Complete |
| UCLSRC-02 | Phase 18 | Complete |
| UCLSRC-03 | Phase 18 | Complete |
| UCLSRC-04 | Phase 18 | Pending |
| CLUBID-01 | Phase 18 | Complete |
| CLUBHIST-01 | Phase 18 | Complete |
| CLUBMOD-01 | Phase 19 | Pending |
| CLUBMOD-02 | Phase 19 | Pending |
| CLUBMOD-03 | Phase 19 | Pending |
| CLUBMOD-04 | Phase 19 | Pending |
| CLUBMOD-05 | Phase 19 | Pending |
| UCLRULE-01 | Phase 20 | Pending |
| UCLRULE-02 | Phase 20 | Pending |
| UCLRULE-03 | Phase 20 | Pending |
| UCLOUT-01 | Phase 20 | Pending |
| UCLOUT-02 | Phase 20 | Pending |
| UCLOUT-03 | Phase 20 | Pending |
| UCLOUT-04 | Phase 20 | Pending |
| UCLOUT-05 | Phase 20 | Pending |
| UCLOUT-06 | Phase 20 | Pending |
| UCLDASH-01 | Phase 21 | Pending |
| UCLDASH-02 | Phase 21 | Pending |
| UCLDASH-03 | Phase 21 | Pending |
| UCLPUB-01 | Phase 21 | Pending |
| UCLPUB-02 | Phase 21 | Pending |
| UCLOPS-01 | Phase 22 | Pending |
| UCLOPS-02 | Phase 22 | Pending |
| UCLOPS-03 | Phase 22 | Pending |
| UCLOPS-04 | Phase 22 | Pending |

**Coverage:**

- v4.0 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0

---
*Requirements defined: 2026-09-19*
*Last updated: 2026-09-19 after roadmap creation*
