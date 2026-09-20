# Roadmap: xGelo v4.0 UEFA Champions League Forecast Dashboard

**Active milestone:** v4.0 - UEFA Champions League Forecast Dashboard
**Status:** Planned
**Created:** 2026-09-19
**Granularity:** Standard

## Milestone Objective

Publish a trustworthy, automatically refreshed UEFA Champions League dashboard from lawful current-state data, an independently validated club-football forecast release, editioned competition rules, and the existing static dashboard engine generalized to an atomic N-edition publisher.

## Phases

- [ ] **Phase 18: Club and UCL Source Contracts** - Establish lawful current-state acquisition, stable club identity, and a pinned historical training corpus.
- [ ] **Phase 19: Independent Club Forecast Authority** - Promote a reproducible club-only rating and goal-model release through frozen evaluation gates.
- [ ] **Phase 20: UCL Rules, State, and Tournament Outcomes** - Deliver official league-phase ranking, legal knockout paths, and deterministic competition probabilities.
- [ ] **Phase 21: N-Edition Dashboard and Atomic Publication** - Add the UCL to the shared dashboard through a registry-derived, rollback-safe three-edition transaction.
- [ ] **Phase 22: Automated Refresh and Release Hardening** - Prove scheduled operation, failure containment, deterministic performance, and public release acceptance.

## Phase Details

### Phase 18: Club and UCL Source Contracts

**Goal**: Operators can acquire and audit lawful Champions League current and historical data through stable club identities without risking credentials or accepted state.
**Depends on**: Nothing (first v4.0 phase)
**Requirements**: UCLSRC-01, UCLSRC-02, UCLSRC-03, UCLSRC-04, CLUBID-01, CLUBHIST-01
**Success Criteria** (what must be TRUE):

1. An operator can run a live-key acceptance check that records the provider's permitted use, attribution, retention, quota, schema, completeness, and freshness verdict before automation is enabled.
2. An operator can ingest current UCL fixtures, results, standings, clubs, and lifecycle metadata into edition-scoped artifacts whose provenance and content hashes are visible while credentials remain absent from Git and generated outputs.
3. Failed, empty, stale, or incomplete retrievals leave the last accepted bundle unchanged and expose a machine-readable blocked-refresh reason.
4. Every current and historical club record resolves through a stable, validity-aware identity contract that rejects ambiguous aliases and national-team identities.
5. The historical club corpus is pinned and auditable for licensing, point-in-time availability, coverage, duplicates, and regulation/extra-time/shootout score semantics before model training can consume it.

**Plans:** 3/6 plans executed

Plans:
**Wave 1**

- [x] 18-01-PLAN.md — Define owner review, lifecycle expectations, and the bounded atomic first-acceptance probe.
- [x] 18-02-PLAN.md — Establish validity-aware club identity plus one reviewed current/history bootstrap with durable unresolved evidence.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 18-03-PLAN.md — Validate the fixed four-endpoint UCL window and integrate the bounded first-acceptance probe with reviewed club identity.
- [ ] 18-05-PLAN.md — Pin, identity-review, normalize, audit, and conditionally accept the historical club corpus.

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 18-06-PLAN.md — Seal canonical UCL candidates with complete provenance hashes and discriminated provider/manual/fixture authority.

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 18-04-PLAN.md — Recompute promotion authority, preserve technical last-known-good state, and execute reviewed provider-exit retain or withdraw transactions.

### Phase 19: Independent Club Forecast Authority

**Goal**: Forecast consumers can use an immutable, independently validated club-football release that cannot be confused with national-team authority.
**Depends on**: Phase 18
**Requirements**: CLUBMOD-01, CLUBMOD-02, CLUBMOD-03, CLUBMOD-04, CLUBMOD-05
**Success Criteria** (what must be TRUE):

1. Club fixtures receive forecasts only from club-only rating and goal models trained without national-team features, releases, or selectors.
2. Analysts can reproduce frozen rolling-origin and cross-league evaluations whose information-cutoff and same-kickoff checks demonstrate that future evidence was not used.
3. A club candidate becomes approved only when its recorded proper scores, calibration, coverage, and reproducibility pass predeclared gates against documented baselines.
4. Consumers can resolve one immutable, model-card-backed club release, while cross-domain attempts to use club and national-team releases are rejected in both directions.
5. Current xG, injury, lineup, suspension, and player inputs appear as typed unavailable evidence unless a separate lawful source contract has been accepted.

**Plans**: TBD

### Phase 20: UCL Rules, State, and Tournament Outcomes

**Goal**: Users can inspect a rules-correct Champions League state and replayable probabilities from the league phase through the final.
**Depends on**: Phase 19
**Requirements**: UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01, UCLOUT-02, UCLOUT-03, UCLOUT-04, UCLOUT-05, UCLOUT-06
**Success Criteria** (what must be TRUE):

1. Users can inspect all 36 clubs in a recomputed league-phase table, see top-8, ranks 9-24, and ranks 25-36 bands, and trace each resolved tie to the decisive editioned criterion or an explicit unresolved state.
2. Users can inspect every club's accepted eight-opponent schedule with matchday, venue, kickoff, status, score, and immutable pre-kickoff forecast when the approved club release covers the fixture.
3. Users can see mutually exclusive top-8, play-off, and eliminated probabilities together with rank and cut-line distributions conditioned on accepted completed results.
4. Knockout projections use only legal rank-constrained and accepted draw-conditioned paths, correctly resolving two legs, aggregate scores, extra time, penalties, leg order, no away-goals rule, and the neutral final.
5. Each club's stage probabilities reconcile and remain monotone through champion, and rerunning identical source, rules, model, and seed inputs produces byte-equivalent outcome artifacts.

**Plans**: TBD

### Phase 21: N-Edition Dashboard and Atomic Publication

**Goal**: Users can browse the Champions League beside existing UEFA editions while operators publish every enabled edition as one validated atomic batch.
**Depends on**: Phase 20
**Requirements**: UCLDASH-01, UCLDASH-02, UCLDASH-03, UCLPUB-01, UCLPUB-02
**Success Criteria** (what must be TRUE):

1. Users can browse responsive UCL views for standings, fixtures, results, club form, match forecasts, rank distributions, qualification bands, knockout paths, and progression probabilities through the shared dashboard engine.
2. The UCL page visibly identifies source freshness and delay, rules version, model release and cutoff, simulation seed, batch identity, attribution, and whether last-known-good state is being shown.
3. Missing enrichment, unresolved ties or draws, and blocked or stale state render explicitly without zero-filled values, hidden omission, or fabricated certainty.
4. Operators can enable zero, one, or many competition editions whose routes, adapters, artifact inventory, output limits, and credits are derived from the edition registry rather than hard-coded branches.
5. Nations League, EURO, and UCL can pass one staged validation and atomic promotion/read-back transaction, while any candidate failure preserves the incumbent editions byte-for-byte.

**Plans**: TBD
**UI hint**: yes

### Phase 22: Automated Refresh and Release Hardening

**Goal**: The public three-edition dashboard refreshes on schedule and remains truthful, deterministic, and recoverable under provider and pipeline failures.
**Depends on**: Phase 21
**Requirements**: UCLOPS-01, UCLOPS-02, UCLOPS-03, UCLOPS-04
**Success Criteria** (what must be TRUE):

1. Scheduled refreshes stay within provider quotas and freshness policy, reuse caches, apply bounded retry/backoff, prevent overlapping runs, and keep credentials out of logs and artifacts.
2. Retrieval, model, rules, simulation, rendering, promotion, or read-back failures leave every incumbent public edition byte unchanged and produce an actionable private diagnostic.
3. Operators can demonstrate last-known-good behavior for rate limits, server errors, null, empty, stale, postponed, no-network, concurrent-run, and provider-exit scenarios.
4. Release acceptance demonstrates deterministic simulation performance, compact publication outputs, responsive browser behavior, accessibility checks, recovery runbooks, and one successful end-to-end three-edition refresh.

**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 18. Club and UCL Source Contracts | 3/6 | In Progress|  |
| 19. Independent Club Forecast Authority | 0/TBD | Not started | - |
| 20. UCL Rules, State, and Tournament Outcomes | 0/TBD | Not started | - |
| 21. N-Edition Dashboard and Atomic Publication | 0/TBD | Not started | - |
| 22. Automated Refresh and Release Hardening | 0/TBD | Not started | - |

## Requirement Coverage

| Phase | Requirements | Count |
|-------|--------------|-------|
| 18 | UCLSRC-01, UCLSRC-02, UCLSRC-03, UCLSRC-04, CLUBID-01, CLUBHIST-01 | 6 |
| 19 | CLUBMOD-01, CLUBMOD-02, CLUBMOD-03, CLUBMOD-04, CLUBMOD-05 | 5 |
| 20 | UCLRULE-01, UCLRULE-02, UCLRULE-03, UCLOUT-01, UCLOUT-02, UCLOUT-03, UCLOUT-04, UCLOUT-05, UCLOUT-06 | 9 |
| 21 | UCLDASH-01, UCLDASH-02, UCLDASH-03, UCLPUB-01, UCLPUB-02 | 5 |
| 22 | UCLOPS-01, UCLOPS-02, UCLOPS-03, UCLOPS-04 | 4 |
| **Total** | **All active v4.0 requirements mapped exactly once** | **29** |

---
*Roadmap created: 2026-09-19*
