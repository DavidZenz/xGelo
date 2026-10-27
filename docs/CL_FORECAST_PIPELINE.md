# Champions League forecast pipeline

The club pipeline uses its own identities, historical corpus, Elo ratings,
negative-binomial goal models, evaluation evidence and approved release. Every
current roster club must have historical results in the same connected ratings
component before forecasts can be enabled.

## Source preparation and review

The requested upstream season files are listed in
`data/club/history_native_file_inventory.csv`. Original Git source and license
bytes stay under ignored `data/club/local_raw/`; review packages retain their
full commit IDs, hashes, paths, parsed counts and exclusions.

`scripts/prepare_openfootball_pins.py` inspects the retained OpenFootball Git
checkouts. It follows historical renames, parses modern and legacy native syntax,
and records individual snapshot rows. Identity proposals use explicit aliases
and consistent same-fixture evidence across native versions. Proposals never
activate themselves.

`scripts/select_first_observed_club_history.R` selects each final regulation
result from its earliest successfully parsed retained matching snapshot. Corrections use the later
snapshot where the corrected result first appears. Each source has an exact,
disjoint reviewed line membership. Domestic league and UCL group/league stages
are supported; missing, awarded and knockout results remain in the exclusion
reports.

`scripts/prepare_club_history_review.R` materializes the source, identity, scope,
coverage and policy review package. The current package is under
`data/club/identity_reviews/history-2026-10-27/`. An actual owner decision must
bind its `review_manifest.json` hash before `scripts/accept_club_history_review.R`
can apply it. Missing or changed decision evidence stops activation.

After that approval, build and audit the canonical corpus:

```sh
Rscript scripts/build_club_history_corpus.R \
  --corpus-id=club-history-2026-10-27 \
  --cutoff=2026-10-27T00:00:00Z
```

The builder verifies original bytes, rechecks exact native selection, resolves
all identities and checks source, coverage, duplicate, score and temporal gates.
Only an accepted immutable generation advances the training pointer.

## Evaluation and release

```sh
Rscript scripts/prepare_club_model_review.R
```

This writes the exact pending folds and role memberships under
`data/club/production_protocol/review/`. Owner acceptance binds that package,
the source generation, code and frozen production recipe before fitting.

```sh
Rscript scripts/run_phase19_club_evaluation.R
Rscript scripts/render_ucl_live_dashboard.R
```

The controller tunes the frozen Elo grid using prior data, fits both club Elo
and venue-only negative-binomial models, fits temperature on an earlier prior
window, selects the probability view on a separate later prior window, and
scores untouched outer assessments. Transport folds exclude their held-out
league. Every result must be available before its role's exclusive cutoff.

Two separate R processes retune, refit and predict the same inventory. Checkpoints
are separate for the two executions and reusable only with identical parents,
code, recipe and seeds. Installation independently checks model fits, predictions,
evaluation summaries, final full-history refit lineage and release bytes.

The existing frozen statistical gates determine promotion. If superiority fails,
the venue incumbent can be retained only when every absolute coverage and
integrity gate passes. A failed absolute gate leaves forecasts unavailable.

## Live dashboard

The accepted release predicts only supported, unplayed fixtures after the
information cutoff. It keeps frozen model/calibration evidence separate from
the current accepted fixture source. Routine fixture updates reuse the release;
a changed roster, reviewed identity registry or historical authority requires
new validation. Completed matches never receive newly fabricated pre-match
forecasts.

The local dashboard is written to
`outputs/competition/ucl_2026_27/dashboard/index.html`. Its forecast status and
unavailable reasons are explicit. Live facts remain visible while model gates
are pending or blocked. This render command does not publish the other public
competition routes.
