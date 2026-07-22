library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_statistical_challengers.R"))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/evaluation/benchmark_scores.R"))
selection_module <- file.path(project_root, "R/evaluation/challenger_selection.R")
if (file.exists(selection_module)) source(selection_module)

selection_candidate_ids <- function() {
  c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "dynamic_goal_ability", "dynamic_goal_ability_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
    "open_nb_elo_only_ablation"
  )
}

selection_baseline_ids <- function() {
  c("uniform_1x2", "expanding_1x2", "elo_goal_nb", "open_nb_incumbent", "production_hybrid_nb")
}

require_statistical_selection_api <- function() {
  required <- c(
    "challenger_all_baseline_comparisons", "select_dependence_representative",
    "build_statistical_shortlist", "validate_statistical_shortlist"
  )
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

synthetic_selection_scores <- function() {
  registries <- synthetic_phase10_registries()
  open <- registries$panel_fixtures[
    registries$panel_fixtures$panel_id == "open_core" & registries$panel_fixtures$eligible,
    c("edition_id", "fixture_id"), drop = FALSE
  ]
  models <- c(selection_candidate_ids(), selection_baseline_ids())
  rows <- lapply(seq_along(models), function(i) {
    do.call(rbind, lapply(c("frozen", "updating"), function(track) {
      data.frame(
        model_id = models[i], edition_id = open$edition_id, fixture_id = open$fixture_id,
        track_id = track, target = "regulation_1x2", metric = "rps",
        value = 0.2 + i / 10000, covered = TRUE, stringsAsFactors = FALSE
      )
    }))
  })
  list(scores = do.call(rbind, rows), registries = registries)
}

test_that("seven candidates pair against all five baselines on exact frozen panels", {
  require_statistical_selection_api()
  x <- synthetic_selection_scores()
  comparisons <- challenger_all_baseline_comparisons(
    x$scores, x$registries$tournaments, x$registries$panel_fixtures,
    candidate_ids = selection_candidate_ids(), baseline_ids = selection_baseline_ids(),
    parent_hashes = x$registries$parent_hashes, seed = 920001L
  )
  expect_setequal(unique(comparisons$candidate_id), selection_candidate_ids())
  expect_setequal(unique(comparisons$baseline_id), selection_baseline_ids())
  expect_setequal(unique(comparisons$track_id), c("frozen", "updating"))

  folds <- comparisons[comparisons$diagnostic == "fold", , drop = FALSE]
  expect_true(all(table(folds$candidate_id, folds$baseline_id, folds$track_id) == 12L))
  expected <- ifelse(folds$baseline_id == "production_hybrid_nb", 609L, 630L)
  totals <- aggregate(folds$paired_fixture_count, folds[c("candidate_id", "baseline_id", "track_id")], sum)
  expect_identical(totals$x, ifelse(totals$baseline_id == "production_hybrid_nb", 609L, 630L))
  expect_true(all(grepl("^[0-9a-f]{64}$", comparisons$parent_hashes)))
})

test_that("dependence representative prefers Dixon-Coles under a practical tie", {
  require_statistical_selection_api()
  evidence <- data.frame(
    candidate_id = c(
      "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
      "poisson_team_ridge_elo_bivpois"
    ),
    updating_rps_delta = c(0, -0.0012, -0.0013),
    brier_veto = FALSE, log_loss_veto = FALSE, calibration_veto = FALSE,
    fold_breadth_veto = FALSE, stability_veto = FALSE,
    stringsAsFactors = FALSE
  )
  selected <- select_dependence_representative(
    evidence, meaningful_gain = -0.001, practical_tie = 0.0005
  )
  expect_identical(selected$representative_id, "poisson_team_ridge_elo_dc")
  expect_identical(selected$preferred_candidate_id, "poisson_team_ridge_elo_dc")

  evidence$updating_rps_delta[2:3] <- c(-0.0002, -0.0003)
  no_gain <- select_dependence_representative(evidence, -0.001, 0.0005)
  expect_identical(no_gain$representative_id, "poisson_team_ridge_elo_dc")
  expect_identical(no_gain$preferred_candidate_id, "poisson_team_ridge_elo")
})

test_that("shortlist is research-only, ordered, non-exclusive, and evidence-linked", {
  require_statistical_selection_api()
  evidence <- data.frame(
    candidate_id = selection_candidate_ids(),
    updating_equal_tournament_rps = seq(0.18, 0.186, length.out = 7L),
    practically_non_inferior = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE),
    complexity_rank = 1:7,
    evidence_sha256 = vapply(1:7, function(i) paste0(i, strrep("a", 63)), character(1)),
    stringsAsFactors = FALSE
  )
  shortlist <- build_statistical_shortlist(
    evidence, dependence_representative = "poisson_team_ridge_elo_dc"
  )
  expect_identical(
    shortlist$slot,
    c("best_proper_score", "simplest_non_inferior", "dependence_representative")
  )
  expect_true(validate_statistical_shortlist(shortlist))
  expect_true(all(grepl("^[0-9a-f]{64}$", shortlist$evidence_sha256)))
  forbidden <- "promotion|release|winner|final_holdout|wc2026"
  expect_false(any(grepl(forbidden, names(shortlist), ignore.case = TRUE)))
  expect_false(any(grepl(forbidden, unlist(shortlist), ignore.case = TRUE)))
})
