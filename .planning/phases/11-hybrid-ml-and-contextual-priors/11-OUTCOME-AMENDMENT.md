---
phase: 11-hybrid-ml-and-contextual-priors
artifact: outcome-amendment
status: accepted
decision: accept-inactivity-with-review-pending
decision_basis: project-auto-mode-recommended-option
updated: 2026-08-10T06:45:08Z
---

# Phase 11 Outcome Amendment

## Decision

Phase 11 accepts the current optional-family result as an eligibility-gated
research finding: the open RF challenger is the only candidate with canonical
score rows, while the context, xG, and structural candidates remain registered
but inactive because the repository does not contain admissible evidence for the
exact historical common panels. This decision was recorded by the configured
GSD auto-mode using the plan's recommended option,
`accept-inactivity-with-review-pending`.

This is not a performance conclusion. Inactive candidates have not been shown
to be equal to, better than, or worse than the active RF or statistical
baselines. No score rows are fabricated, imputed, substituted from another
vintage, or inferred from an unavailable source.

## Local Evidence Audit

All checks below were read-only and used committed local files only.

| Evidence | Result | Interpretation |
|---|---:|---|
| Frozen `open_core` panel | 630 eligible fixtures | Required open denominator is intact. |
| Frozen `feature_rich` panel | 609 eligible fixtures | Rich companion denominator is intact. |
| Registered score support | `G=40` | The sealed 0:40 support is unchanged. |
| Phase 11 candidate registry | 9 candidates | One base RF plus six context variants, one xG-gated variant, and one structural variant. |
| Candidate evidence | 1 active; 8 inactive | Only the base RF contributes canonical score rows. |
| Base RF score rows | 1,260 | 630 fixtures for each independently estimated home/away goal model. |
| Bundle flags | `reproducible=TRUE`, `wc2026_sealed=TRUE`, `network_free=TRUE`, `research_only=TRUE`, `phase12_decision_authority=FALSE` | The bundle remains a research artifact and cannot promote a model. |
| Bundle parent graph | 20 parents | The optional-family evidence remains attached to the frozen Phase 9/10 and Phase 11 inputs. |

### Context and travel eligibility

The local route audit used `data/benchmark/phase09/fixtures.csv`,
`data/processed/elo_matches.csv`, the checked team map, and the committed WGS84
country-proxy registry at `data/benchmark/phase11/country_centroids.csv`.
It normalized local country labels using the repository's explicit aliases and
counted a route only when the current venue country and both teams' latest prior
venue/host countries had committed centroid coverage.

- `542/630` open-panel fixtures had both prior routes centroid-covered.
- `527/609` rich-panel fixtures had both prior routes centroid-covered.
- The centroid registry contains 21 country rows, not the complete country
  universe needed by the strict `630/630` and `609/609` common-panel gates.
- The strict context contract therefore remains fail-closed for
  `travel_km`; the six context candidates publish no canonical score rows.
- No geocoding, silent imputation, venue substitution, or network collection
  was used to fill the missing routes.

These counts are eligibility evidence only. They are not a context-model
performance estimate.

### Structural-prior eligibility

The exact panel team ISO3 universe is the following 72-code set:

```text
ALB, ALG, ANG, ARG, AUS, AUT, BEL, BIH, BRA, BUL, CAN, CHI, CHN, CIV, CMR,
COL, CRC, CRO, CZE, DEN, ECU, EGY, ENG, ESP, FIN, FRA, GEO, GER, GHA, GRE,
HON, HUN, IRL, IRN, ISL, ITA, JPN, KOR, KSA, LVA, MAR, MEX, MKD, NED, NGA,
NIR, NZL, PAN, PAR, PER, POL, POR, PRK, QAT, ROU, RSA, RUS, SCO, SEN, SRB,
SUI, SVK, SVN, SWE, TOG, TRI, TUN, TUR, UKR, URU, USA, WAL
```

The current committed OWID/Maddison plus WPP snapshot contains 144 rows,
covering the same 72 codes, with two indicator rows per code. It includes both
`POR` and `PRK`. Its registered vintage is
`owid_maddison2023_wpp2024_2000_v1`, and its source/publication date is
`2024-07-15`.

The earlier UAT inactive reason, `Structural prior snapshot is missing team
ISO3: POR`, is therefore misleading. The direct structural signal reproduces
the following boundary:

- the snapshot resolves for `POR` and `PRK` at the current manifest cutoff
  `2026-06-05`;
- it also resolves after publication, for example at `2024-07-16`;
- it has no admissible rows at a historical cutoff before publication, for
  example `2024-06-13`, and the current signal function reports the filtered
  empty set as a missing-ISO3 error;
- the 12 historical structural fold cutoffs recorded in the durable model
  evidence precede `2024-07-15`.

The structural candidate is consequently inactive for the correct temporal
reason: this single vintage cannot provide point-in-time structural evidence to
the historical folds. The no-score result is retained. The misleading error
taxonomy is recorded as follow-up engineering work; it is not repaired here,
because changing production code or rebuilding the long benchmark would exceed
this closure plan.

The gap plan described the snapshot as lacking `PRK`; that description belonged
to the pre-`2cd6d37` artifact line. The current source and the diagnosis in
`.planning/debug/g11-22-structural-iso3.md` supersede that stale description.

### xG eligibility

The registered D-12 gate remains inactive from current local evidence:

- `xgf_ewma_diff` and `xga_ewma_diff` have zero non-zero observations in the
  canonical hybrid training feature table;
- source coverage and forecast coverage are zero;
- observed variance is zero; and
- the required labelled-model provenance is incomplete.

The xG candidate therefore publishes no canonical score rows. This is a gate
result, not evidence about xG predictive value.

## Locked Contracts Carried Forward

This amendment preserves the following Phase 11 decisions and boundaries:

- **D-01:** separate home and away RF goal models;
- **D-02:** registered negative-binomial marginals with sealed `G=40` support;
- **D-03:** fold-local dynamic attack/defence evidence plus Elo;
- **D-04:** identical folds, proper scores, stability evidence, and no automatic promotion;
- **D-05:** the full context bundle and each drop-one ablation remain separately registered;
- **D-06:** the frozen core remains the evaluation denominator and supplemental panels do not redefine it;
- **D-07:** open context requires strict common-panel evidence with no silent imputation;
- **D-08:** prior dates, country-proxy travel, stage metadata, and provenance remain explicit;
- **D-09:** structural inputs remain vintage-aware and cutoff-filtered;
- **D-10:** structural effects use continuous evidence-weighted shrinkage;
- **D-11:** effective-match-count weighting remains registered;
- **D-12:** xG requires coverage, variance, and complete provenance before activation;
- **D-13:** squad evidence is local derived evidence only;
- **D-14:** market references remain manually frozen and separately labelled;
- **D-15:** open, enriched, and external modes remain distinct;
- **D-16:** only open-mode-compatible evidence can enter the promotion-facing path.

The bundle remains sealed for WC2026, network-free, research-only, fail-closed,
and without Phase 12 decision authority. Phase 11 does not open the 2026
holdout, freeze a candidate, evaluate promotion, or alter production registry,
bundle, target, or test behavior as part of this amendment.

## Human Review and Phase 12 Handoff

The substantive WDI/Maddison indicator choice, FIFA-code mapping, transformation
policy, and HGR-inspired rationale remain human-owned review items. Automated
checks establish source presence, hashes, vintage metadata, chronology, panel
coverage, and numerical shrinkage behavior; they do not approve the substantive
structural interpretation.

Before any structural candidate can be activated, a later plan must provide a
checksummed historical vintage or vintages with publication evidence before the
relevant fold cutoffs, improve the inactive-reason taxonomy, and complete the
human WDI/HGR mapping review. Likewise, context activation requires complete
point-in-time route evidence, and xG activation requires a passing D-12 gate.

Only Phase 12 may freeze a candidate, open the sealed 2026 holdout, or evaluate
promotion. The Phase 11 shortlist remains non-exclusive research evidence for
that handoff; its current base-RF comparison is not a release decision.

## Verification Commands

The local audit assertions passed for the 630/609 panels, `G=40`, nine
candidates, 1,260 base-RF score rows, one active candidate, zero non-zero xG
signals, and the 542/630 and 527/609 route counts. The structural source was
also directly loaded and checked for 144 rows, 72 codes, `POR`, `PRK`, and the
`2024-07-15` source date.

