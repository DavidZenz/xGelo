---
phase: 11-hybrid-ml-and-contextual-priors
artifact: outcome-amendment
status: accepted
decision: accept-inactivity-with-review-pending
decision_basis: explicit-developer-approval
approved_at: 2026-08-10T07:07:51Z
updated: 2026-08-10T07:07:51Z
---

# Phase 11 Outcome Amendment

## Decision

Phase 11 accepts the current optional-family result as an eligibility-gated
research finding: the open RF challenger is the only candidate with canonical
score rows, while the context, xG, and structural candidates remain registered
but inactive because the repository does not contain admissible evidence for the
exact historical common panels. This decision was recorded by explicit
developer approval in this task using the selected option,
`accept-inactivity-with-review-pending`. The approval accepts the research-only
disposition and the pending substantive review; it does not approve a model,
open the WC2026 holdout, or delegate Phase 12 promotion authority.

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

### Evidence identity and immutability

This amendment is a separate, immutable eligibility-audit artifact. It is not
a regenerated performance bundle. The accepted performance evidence remains
anchored to the historical Phase 11 bundle lineage at source commit
`2cd6d3751b23ac182be3ce36e658b8cc3a26608f` and its Git object identities:

| Historical bundle anchor | Git object |
|---|---|
| `run_manifest.csv` | `2c962e3bc6085701d6f2dcebf7438256f06496e4` |
| `selection/candidate_evidence.csv` | `d36a4bdbe860100583acc03c25ad19c636232ff9` |
| `selection/hybrid_shortlist.csv` | `4dc8e0250ec13aa9a3738026d103e1529c0d39f6` |

The local audit was replayed against the following exact SHA-256 inputs. The
three current output hashes are recorded for diagnostic traceability only:
they reflect uncommitted regenerated files and are explicitly excluded from
any new performance claim.

| Local audit file | SHA-256 |
|---|---|
| `data/benchmark/phase09/fixtures.csv` | `69dac1891ffa948d3b6ecd29949063c9dffb47bb50ced5dbf6c87bc80286c8dc` |
| `data/benchmark/phase09/panel_fixtures.csv` | `68a6b5d15127cd9829fd1a110c7598c16ec8cc3c7936492889a98ed38f5391ad` |
| `data/benchmark/phase09/teams.csv` | `703fcd6543213fdf964c8caf1dc2f3fe1dda2d75c070be80c46319bba2a8c6` |
| `data/processed/elo_matches.csv` | `4ef2d3013113e186b2f1c9d00d4cfc50a1b0b377e4bb39b098f1bc99f1b1d735` |
| `data/processed/goal_training_features_hybrid.csv` | `836a596ef2929a676962605e1724c191c872972505b19f080d8538feebb2ddf9` |
| `data/benchmark/phase11/country_centroids.csv` | `e5121ee7260bd066e6fbcc8af337ff148c1e5606ab136eda27429656ea6ce4dc` |
| `data/benchmark/phase11/country_centroids_metadata.csv` | `581dabb7730d4e54301d8c871cd734300b1eb3ef67d95a786432f1ba7ea92422` |
| `data/benchmark/phase11/structural_sources.csv` | `f8e811eff52e912063b4c30985468cf806a2ed05748b898c794b00277876495a` |
| `data/benchmark/phase11/structural_sources_metadata.csv` | `69946ab1dbb4f24760c3d3b9c9386702ac29b19dfb89dcc3a74c082bddc6214d` |
| `data/benchmark/phase11/structural_sources_checksums.csv` | `dcf94018e77955ef573c430aa509891f16ef4aa553a03e78188e0b08a7fc1d7d` |
| `data/benchmark/phase11/structural_prior_manifest.csv` | `7a7f87b16205507e303fe444ea5123875f1d9f520ad4a22666d231b8e629e210` |
| `data/benchmark/phase11/model_registry.csv` | `6d0a4545acd83b74033eb7a22d30dd2d1547ce73f6fb36fe7818f63296add201` |
| `outputs/.../run_manifest.csv` (diagnostic worktree) | `662efef90b03cc0da76459b906a9b819da3e199f62122217f14817f30c0c97be` |
| `outputs/.../selection/candidate_evidence.csv` (diagnostic worktree) | `24f8247db9358aae033aa15bfbc370355d61d1af69c117559cbbcb298f7e3671` |
| `outputs/.../selection/hybrid_shortlist.csv` (diagnostic worktree) | `3a74e5376750ab8c2df2238d8e92f103f4715ab1479a6a8e63c7d2a3f6b1fe99` |

The current diagnostic output edits are therefore not silently promoted into
the durable benchmark. The amendment itself is the accepted current audit;
the historical Git bundle remains the performance record, and any future
performance rerun must publish a new checksum-linked bundle under a separately
reviewed plan.

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

The following read-only commands are the replayable audit checks. They must be
run from the repository root and are pinned by the hashes above.

```bash
Rscript --vanilla -e 'read <- function(p) utils::read.csv(p, stringsAsFactors=FALSE, check.names=FALSE); fx <- read("data/benchmark/phase09/fixtures.csv"); pf <- read("data/benchmark/phase09/panel_fixtures.csv"); st <- read("data/benchmark/phase11/structural_sources.csv"); tr <- read("data/processed/goal_training_features_hybrid.csv"); ev <- read("outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/candidate_evidence.csv"); stopifnot(nrow(fx)==630L, sum(pf$panel_id=="open_core"&pf$eligible)==630L, sum(pf$panel_id=="feature_rich"&pf$eligible)==609L, nrow(st)==144L, length(unique(st$country_iso3))==72L, all(c("POR","PRK") %in% st$country_iso3), all(tr$xgf_ewma_diff==0), all(tr$xga_ewma_diff==0), sum(ev$score_row_count,na.rm=TRUE)==1260L, sum(ev$active_status=="active")==1L); cat("11-08 local assertions: PASS\n")'

Rscript --vanilla -e 'source("R/forecast/structural_prior.R"); vintage <- "owid_maddison2023_wpp2024_2000_v1"; s <- load_structural_prior_snapshots(registered_vintage_id=vintage, evidence_cutoff_exclusive=as.Date("2026-06-05")); x <- compute_structural_prior_signal(s, c("team_POR", "team_PRK"), as.Date("2026-06-05"), registered_vintage_id=vintage); y <- compute_structural_prior_signal(s, c("team_POR", "team_PRK"), as.Date("2024-07-16"), registered_vintage_id=vintage); stopifnot(nrow(s)==144L, length(unique(s$country_iso3))==72L, nrow(x)==2L, nrow(y)==2L); err <- tryCatch(compute_structural_prior_signal(s, c("team_POR", "team_PRK"), as.Date("2024-06-13"), registered_vintage_id=vintage), error=function(e) conditionMessage(e)); stopifnot(grepl("missing team ISO3", err, fixed=TRUE)); cat("structural cutoff audit: PASS\n")'

Rscript --vanilla -e 'source("R/forecast/context_features.R"); f <- read.csv("data/benchmark/phase09/fixtures.csv", stringsAsFactors=FALSE, check.names=FALSE); f$date <- as.Date(f$actual_completion_date); t <- read.csv("data/benchmark/phase09/teams.csv", stringsAsFactors=FALSE, check.names=FALSE); m <- read.csv("data/processed/elo_matches.csv", stringsAsFactors=FALSE, check.names=FALSE); m$date <- as.Date(m$date); ids <- setNames(t$team_id, t$canonical_name); code_to_id <- setNames(t$team_id, t$fifa_code); to_id <- function(code, name) { z <- unname(code_to_id[toupper(trimws(as.character(code)))]); miss <- is.na(z); z[miss] <- unname(ids[as.character(name)[miss]]); ifelse(is.na(z), NA_character_, as.character(z)) }; m$home_team_id <- to_id(m$home_team_fifa, m$home_team_canonical); m$away_team_id <- to_id(m$away_team_fifa, m$away_team_canonical); m$venue_country <- m$country; m$fixture_id <- m$match_id; cts <- read.csv("data/benchmark/phase11/country_centroids.csv", stringsAsFactors=FALSE, check.names=FALSE); covered <- toupper(as.character(cts$country_iso3)); norm1 <- function(x) .phase11_context_country_iso3(x); norm <- function(x) vapply(x, norm1, character(1)); latest <- function(team, d) { ix <- which((m$home_team_id == team | m$away_team_id == team) & m$date < d); if (!length(ix)) return(NA_character_); ix <- ix[order(m$date[ix], m$fixture_id[ix], method="radix")]; as.character(m$venue_country[ix[length(ix)]]) }; route_ok <- vapply(seq_len(nrow(f)), function(i) { current <- norm(f$venue_country[i]); prior <- c(latest(f$home_team_id[i], f$date[i]), latest(f$away_team_id[i], f$date[i])); all(!is.na(c(current, prior)) & norm(c(current, prior)) %in% covered) }, logical(1)); pf <- read.csv("data/benchmark/phase09/panel_fixtures.csv", stringsAsFactors=FALSE, check.names=FALSE); ids_open <- pf$fixture_id[pf$panel_id == "open_core" & pf$eligible]; ids_rich <- pf$fixture_id[pf$panel_id == "feature_rich" & pf$eligible]; cat(sprintf("route_ok_open=%d/%d route_ok_rich=%d/%d covered_centroids=%d history_rows=%d missing_team_ids=%d\n", sum(route_ok[match(ids_open, f$fixture_id)]), length(ids_open), sum(route_ok[match(ids_rich, f$fixture_id)]), length(ids_rich), length(covered), nrow(m), sum(is.na(m$home_team_id) | is.na(m$away_team_id)))); stopifnot(sum(route_ok[match(ids_open, f$fixture_id)]) == 542L, sum(route_ok[match(ids_rich, f$fixture_id)]) == 527L); cat("route audit: PASS\n")'
```

Together these checks passed for the 630/609 panels, G=40, nine candidates,
1,260 base-RF score rows, one active candidate, zero non-zero xG signals, the
542/630 and 527/609 route counts, and the 144-row/72-code structural snapshot.
