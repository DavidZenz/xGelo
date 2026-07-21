library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/registry.R"))
contracts_path <- file.path(project_root, "R/benchmark/contracts.R")
if (file.exists(contracts_path)) source(contracts_path)

contract_grid <- function(id = "dist_1", support_max = 2L) {
  grid <- expand.grid(home_goals = 0:support_max, away_goals = 0:support_max)
  raw <- outer(
    stats::dpois(0:support_max, lambda = 1.1),
    stats::dpois(0:support_max, lambda = 0.8)
  )
  raw_tail <- 1 - sum(raw)
  grid$score_distribution_id <- id
  grid$probability <- as.vector(raw / sum(raw))
  grid$support_max_home <- support_max
  grid$support_max_away <- support_max
  grid$raw_tail_mass <- raw_tail
  grid$normalized <- TRUE
  grid[, c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )]
}

contract_fixture <- function() {
  data.frame(
    edition_id = "wc2002", fixture_id = "wc2002_001",
    boundary_id = "wc2002__2002-05-31", home_team_id = "team_fra",
    away_team_id = "team_sen", venue_role = "neutral",
    actual_completion_date = as.Date("2002-05-31"), stringsAsFactors = FALSE
  )
}

contract_seed_registry <- function() {
  seeds <- data.frame(
    schema_version = "1.0", seed_id = "seed_fixture_1",
    purpose = "fixture_prediction", edition_id = "wc2002",
    boundary_id = "wc2002__2002-05-31", fixture_id = "wc2002_001",
    seed = 101L, model_independent = TRUE, seed_key_sha256 = "",
    stringsAsFactors = FALSE
  )
  seeds$seed_key_sha256 <- benchmark_seed_key_sha256(seeds)
  seeds
}

contract_prediction <- function(grid = contract_grid()) {
  market <- derive_benchmark_markets(grid)
  data.frame(
    schema_version = "1.0", run_id = "run_1", model_id = "elo_goal_nb",
    panel_id = "open_core", edition_id = "wc2002", track_id = "updating",
    fixture_id = "wc2002_001", boundary_id = "wc2002__2002-05-31",
    forecast_sequence = 1L, home_team_id = "team_fra", away_team_id = "team_sen",
    venue_role = "neutral", evidence_cutoff_exclusive = as.Date("2002-05-31"),
    result_cutoff_exclusive = as.Date("2002-05-31"), model_manifest_id = "manifest_1",
    feature_coverage_id = "coverage_1", seed_id = "seed_fixture_1",
    score_distribution_id = unique(grid$score_distribution_id),
    p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
    expected_home_goals = market$expected_home_goals,
    expected_away_goals = market$expected_away_goals,
    p_over_2_5 = market$p_over_2_5, p_under_2_5 = market$p_under_2_5,
    p_btts = market$p_btts, modal_home_goals = market$modal_home_goals,
    modal_away_goals = market$modal_away_goals,
    modal_score_probability = market$modal_score_probability,
    prediction_status = "ok", failure_reason = "", stringsAsFactors = FALSE
  )
}

testthat::test_that("benchmark distributions require the complete sealed rectangle", {
  grid <- contract_grid()
  validated <- validate_benchmark_score_distributions(
    grid, expected_distribution_ids = "dist_1", support_max = 2L,
    raw_tail_tolerance = 0.2
  )
  testthat::expect_equal(nrow(validated), 9L)

  missing_cell <- grid[-1, ]
  testthat::expect_error(
    validate_benchmark_score_distributions(
      missing_cell, "dist_1", support_max = 2L, raw_tail_tolerance = 0.2
    ),
    "complete 0:G"
  )
  unknown_cell <- rbind(grid, transform(grid[1, ], home_goals = 3L))
  testthat::expect_error(
    validate_benchmark_score_distributions(
      unknown_cell, "dist_1", support_max = 2L, raw_tail_tolerance = 0.2
    ),
    "complete 0:G"
  )
  bad_tail <- transform(grid, raw_tail_mass = 0.25)
  testthat::expect_error(
    validate_benchmark_score_distributions(
      bad_tail, "dist_1", support_max = 2L, raw_tail_tolerance = 0.2
    ),
    "raw omitted tail"
  )
})

testthat::test_that("proper score validation remains backward compatible and can enforce support", {
  legacy <- data.frame(
    home_goals = c(0L, 1L), away_goals = c(0L, 0L), probability = c(0.4, 0.6)
  )
  testthat::expect_silent(validate_scoreline_distribution(legacy))
  testthat::expect_error(
    validate_scoreline_distribution(
      legacy, support_max = 1L, require_full_rectangle = TRUE,
      raw_tail_mass = 0, tail_tolerance = 1e-10
    ),
    "complete 0:G"
  )
})

testthat::test_that("all markets and modal forecasts reconcile to the joint distribution", {
  grid <- contract_grid()
  predictions <- contract_prediction(grid)
  validated <- validate_benchmark_predictions(
    predictions, contract_fixture(), grid, contract_seed_registry(),
    support_max = 2L, tolerance = 1e-10, raw_tail_tolerance = 0.2
  )
  testthat::expect_equal(nrow(validated), 1L)

  tampered <- predictions
  tampered$p_draw <- tampered$p_draw + 1e-4
  testthat::expect_error(
    validate_benchmark_predictions(
      tampered, contract_fixture(), grid, contract_seed_registry(),
      support_max = 2L, tolerance = 1e-10, raw_tail_tolerance = 0.2
    ),
    "reconcile"
  )
  testthat::expect_true(all(benchmark_prediction_columns() %in% names(predictions)))
})

testthat::test_that("neutral score grids are symmetric under team swap", {
  grid <- contract_grid()
  swapped <- grid
  swapped$home_goals <- grid$away_goals
  swapped$away_goals <- grid$home_goals
  first <- derive_benchmark_markets(grid)
  second <- derive_benchmark_markets(swapped)
  testthat::expect_equal(first$p_home, second$p_away, tolerance = 1e-12)
  testthat::expect_equal(first$p_away, second$p_home, tolerance = 1e-12)
  testthat::expect_equal(first$p_draw, second$p_draw, tolerance = 1e-12)
  testthat::expect_equal(first$expected_home_goals, second$expected_away_goals, tolerance = 1e-12)
})

testthat::test_that("prediction coverage rejects missing rows and unknown seeds", {
  prediction <- contract_prediction()
  panel <- data.frame(
    panel_id = "open_core", fixture_id = "wc2002_001", eligible = TRUE,
    output_coverage_required = TRUE, stringsAsFactors = FALSE
  )
  testthat::expect_silent(validate_panel_prediction_coverage(prediction, panel, "elo_goal_nb"))
  testthat::expect_error(
    validate_panel_prediction_coverage(prediction[FALSE, ], panel, "elo_goal_nb"),
    "missing required fixture"
  )
  unknown <- prediction
  unknown$seed_id <- "not_registered"
  testthat::expect_error(
    validate_benchmark_predictions(
      unknown, contract_fixture(), contract_grid(), contract_seed_registry(),
      support_max = 2L, raw_tail_tolerance = 0.2
    ),
    "unregistered seed"
  )
})

testthat::test_that("frozen panel selectors enforce exact declared fixture sets", {
  panel_fixtures <- read.csv(
    file.path(project_root, "data/benchmark/phase09/panel_fixtures.csv"),
    stringsAsFactors = FALSE
  )
  open_ids <- benchmark_panel_fixture_ids(panel_fixtures, "open_core")
  rich_ids <- benchmark_panel_fixture_ids(panel_fixtures, "feature_rich")

  testthat::expect_length(open_ids, 630L)
  testthat::expect_length(rich_ids, 609L)
  testthat::expect_identical(open_ids, sort(unique(open_ids)))
  testthat::expect_identical(rich_ids, sort(unique(rich_ids)))
  testthat::expect_setequal(
    unique(panel_fixtures$edition_id[panel_fixtures$fixture_id %in% rich_ids]),
    unique(panel_fixtures$edition_id)
  )

  duplicate <- rbind(panel_fixtures, panel_fixtures[1, , drop = FALSE])
  testthat::expect_error(
    benchmark_panel_fixture_ids(duplicate, "feature_rich"),
    "duplicate declarations"
  )
  testthat::expect_error(
    benchmark_panel_fixture_ids(panel_fixtures, "not_registered"),
    "registered panel"
  )
})

testthat::test_that("rich-panel projection excludes 21 audit-visible rows and validates strictly", {
  panel_fixtures <- read.csv(
    file.path(project_root, "data/benchmark/phase09/panel_fixtures.csv"),
    stringsAsFactors = FALSE
  )
  fixture_ids <- benchmark_panel_fixture_ids(panel_fixtures, "open_core")
  predictions <- data.frame(
    model_id = "production_hybrid_nb", panel_id = "feature_rich",
    fixture_id = fixture_ids, prediction_status = "ok",
    stringsAsFactors = FALSE
  )
  selected <- select_benchmark_panel_predictions(
    predictions, panel_fixtures, "production_hybrid_nb", "feature_rich"
  )

  testthat::expect_equal(nrow(selected), 609L)
  testthat::expect_equal(attr(selected, "excluded_fixture_count"), 21L)
  testthat::expect_equal(attr(selected, "declared_fixture_count"), 609L)
  testthat::expect_silent(validate_panel_prediction_coverage(
    selected, panel_fixtures, "production_hybrid_nb", "feature_rich"
  ))

  missing <- selected[-1, , drop = FALSE]
  testthat::expect_error(
    validate_panel_prediction_coverage(
      missing, panel_fixtures, "production_hybrid_nb", "feature_rich"
    ),
    "exact declared fixture set"
  )
  duplicate <- rbind(selected, selected[1, , drop = FALSE])
  testthat::expect_error(
    validate_panel_prediction_coverage(
      duplicate, panel_fixtures, "production_hybrid_nb", "feature_rich"
    ),
    "duplicate fixture"
  )
  extra <- rbind(selected, predictions[!predictions$fixture_id %in% selected$fixture_id, ][1, ])
  testthat::expect_error(
    validate_panel_prediction_coverage(
      extra, panel_fixtures, "production_hybrid_nb", "feature_rich"
    ),
    "exact declared fixture set"
  )
  wrong_panel <- selected
  wrong_panel$panel_id[1] <- "open_core"
  testthat::expect_error(
    validate_panel_prediction_coverage(
      wrong_panel, panel_fixtures, "production_hybrid_nb", "feature_rich"
    ),
    "one model and panel identity"
  )
  incomplete <- selected
  incomplete$prediction_status[1] <- "failed"
  testthat::expect_error(
    validate_panel_prediction_coverage(
      incomplete, panel_fixtures, "production_hybrid_nb", "feature_rich"
    ),
    "incomplete"
  )
})

testthat::test_that("manifests and feature coverage enforce point-in-time provenance", {
  manifest <- data.frame(
    model_manifest_id = "manifest_1", run_id = "run_1", model_id = "elo_goal_nb",
    edition_id = "wc2002", track_id = "updating", boundary_id = "wc2002__2002-05-31",
    fit_status = "ok", fit_row_count = 100L, fit_min_date = as.Date("1990-01-01"),
    fit_max_date = as.Date("2002-05-30"), max_result_date = as.Date("2002-05-30"),
    max_feature_source_date = as.Date("2002-05-30"), evidence_cutoff_exclusive = as.Date("2002-05-31"),
    active_predictors = "elo_diff|venue_role", dropped_predictors_with_reason = "",
    model_family = "negative_binomial", convergence_status = "converged",
    fallback_status = "none", adapter_version = "1.0", code_version = "abc123",
    r_version = as.character(getRversion()), package_versions = "MASS=7.3",
    registration_sha256 = strrep("a", 64), settings_sha256 = strrep("b", 64),
    parent_hashes = strrep("c", 64), stringsAsFactors = FALSE
  )
  testthat::expect_silent(validate_model_manifests(manifest))
  leaked <- manifest
  leaked$max_feature_source_date <- leaked$evidence_cutoff_exclusive
  testthat::expect_error(validate_model_manifests(leaked), "strictly before")

  feature <- data.frame(
    schema_version = "1.0", feature_coverage_id = "coverage_1", run_id = "run_1",
    model_id = "elo_goal_nb", panel_id = "open_core", edition_id = "wc2002",
    track_id = "updating",
    boundary_id = "wc2002__2002-05-31", fixture_id = "wc2002_001",
    feature_id = c("elo_diff", "venue_role"), source_id = "elo_ratings_recursive_open",
    source_artifact_sha256 = strrep("d", 64),
    feature_contract_row_sha256 = c(strrep("e", 64), strrep("f", 64)),
    value_present = TRUE,
    source_present = TRUE, source_date = as.Date("2002-05-30"),
    evidence_cutoff_exclusive = as.Date("2002-05-31"), cutoff_valid = TRUE,
    imputed = FALSE, imputation_reason = "", active_in_fit = TRUE,
    coverage_status = "complete", license_class = "open", stringsAsFactors = FALSE
  )
  expected <- expand.grid(
    model_id = "elo_goal_nb", boundary_id = "wc2002__2002-05-31",
    fixture_id = "wc2002_001", feature_id = c("elo_diff", "venue_role"),
    stringsAsFactors = FALSE
  )
  testthat::expect_silent(validate_feature_coverage(feature, expected))
  invalid <- feature
  invalid$cutoff_valid[1] <- FALSE
  testthat::expect_error(validate_feature_coverage(invalid, expected), "cutoff")
})

testthat::test_that("bundle feature keys are rebuilt from registrations and fail closed", {
  predictions <- data.frame(
    feature_coverage_id = "coverage_1", model_id = "elo_goal_nb",
    panel_id = "open_core", edition_id = "wc2002", track_id = "updating",
    boundary_id = "wc2002__day1", fixture_id = "wc2002_001",
    stringsAsFactors = FALSE
  )
  models <- data.frame(
    model_id = "elo_goal_nb", panel_id = "open_core", stringsAsFactors = FALSE
  )
  contract <- data.frame(
    panel_id = "open_core", feature_id = c("elo_difference_for_team", "venue_advantage_for_team"),
    source_id = c("elo_ratings_recursive_open", "fixture_registry"),
    source_artifact_sha256 = c(strrep("a", 64), strrep("b", 64)),
    license_class = c("open", "open"), row_sha256 = c(strrep("c", 64), strrep("d", 64)),
    stringsAsFactors = FALSE
  )
  expected <- benchmark_expected_feature_coverage_keys(predictions, models, contract)
  testthat::expect_equal(nrow(expected), 2L)
  testthat::expect_setequal(expected$feature_id, contract$feature_id)

  coverage <- transform(
    expected,
    schema_version = "1.0", feature_coverage_id = "coverage_1", run_id = "run_1",
    value_present = TRUE, source_present = c(TRUE, FALSE),
    source_date = as.Date(c("2002-05-30", NA)),
    evidence_cutoff_exclusive = as.Date("2002-05-31"), cutoff_valid = TRUE,
    imputed = FALSE, imputation_reason = "", active_in_fit = TRUE,
    coverage_status = c("active_observed", "derived_fixture")
  )
  testthat::expect_true(validate_benchmark_feature_evidence(
    predictions, coverage, models, contract
  ))

  aggregate <- data.frame(
    model_id = "elo_goal_nb", panel_id = "open_core", edition_id = "wc2002",
    output_coverage_complete = TRUE, provenance_complete = TRUE,
    promotion_eligible = TRUE, stringsAsFactors = FALSE
  )
  testthat::expect_error(
    validate_benchmark_feature_evidence(predictions, aggregate, models, contract),
    "missing columns"
  )
  corruptions <- list(
    dangling = transform(predictions, feature_coverage_id = "missing_group"),
    orphan = transform(coverage, feature_coverage_id = "orphan_group"),
    missing_key = coverage[-1, ],
    extra_key = rbind(coverage, transform(coverage[1, ], feature_id = "unknown_feature")),
    observed_zero = transform(coverage, value_present = FALSE, imputed = FALSE),
    fabricated_date = transform(coverage, source_present = FALSE),
    provenance = transform(coverage, source_artifact_sha256 = strrep("f", 64)),
    license = transform(coverage, license_class = "restricted"),
    contract_hash = transform(coverage, feature_contract_row_sha256 = strrep("0", 64))
  )
  for (name in names(corruptions)) {
    prediction_rows <- if (name == "dangling") corruptions[[name]] else predictions
    coverage_rows <- if (name == "dangling") coverage else corruptions[[name]]
    testthat::expect_error(
      validate_benchmark_feature_evidence(prediction_rows, coverage_rows, models, contract),
      info = name
    )
  }
})

support_inventory <- function() {
  data.frame(
    edition_id = c("wc2002", "wc2002"), track_id = c("frozen", "updating"),
    boundary_id = c("wc2002__frozen", "wc2002__2002-05-31"),
    boundary_sha256 = c(strrep("1", 64), strrep("2", 64)), stringsAsFactors = FALSE
  )
}

support_models <- function() {
  data.frame(
    model_id = c("uniform_1x2", "elo_goal_nb"), candidate_min = 8L,
    candidate_max = 10L, raw_tail_tolerance = 1e-10,
    registration_sha256 = c(strrep("a", 64), strrep("b", 64)),
    settings_sha256 = c(strrep("c", 64), strrep("d", 64)), stringsAsFactors = FALSE
  )
}

support_audit <- function() {
  inventory <- support_inventory()
  models <- support_models()
  keys <- merge(models[, "model_id", drop = FALSE], inventory[, c("edition_id", "track_id", "boundary_id")])
  audit <- merge(keys, data.frame(candidate_g = 8:10))
  audit$raw_omitted_tail <- ifelse(audit$candidate_g == 8L, 1e-6, ifelse(audit$candidate_g == 9L, 1e-9, 1e-12))
  audit$tolerance <- 1e-10
  audit$pass <- audit$raw_omitted_tail <= audit$tolerance
  audit$selected_g <- 10L
  audit <- merge(
    audit,
    merge(
      models[, c("model_id", "registration_sha256", "settings_sha256")],
      inventory,
      by = NULL
    ),
    by = c("model_id", "edition_id", "track_id", "boundary_id")
  )
  audit$parent_hashes <- benchmark_support_parent_sha256(audit)
  audit <- audit[, c(
    "model_id", "edition_id", "track_id", "boundary_id", "candidate_g",
    "raw_omitted_tail", "tolerance", "pass", "selected_g", "parent_hashes"
  )]
  audit$row_hash <- ""
  audit$row_hash <- benchmark_row_sha256(audit, "row_hash")
  audit
}

testthat::test_that("score support audit is complete, globally minimal, and canonical", {
  audit <- support_audit()
  testthat::expect_silent(validate_score_support_audit(audit, support_models(), support_inventory()))

  testthat::expect_error(
    validate_score_support_audit(audit[-1, ], support_models(), support_inventory()),
    "missing candidate"
  )
  bad_parent <- audit
  bad_parent$parent_hashes[1] <- strrep("f", 64)
  bad_parent$row_hash <- benchmark_row_sha256(bad_parent, "row_hash")
  testthat::expect_error(
    validate_score_support_audit(bad_parent, support_models(), support_inventory()),
    "parent hash"
  )
  bad_row <- audit
  bad_row$row_hash[1] <- strrep("0", 64)
  testthat::expect_error(
    validate_score_support_audit(bad_row, support_models(), support_inventory()),
    "row SHA-256"
  )
  inconsistent <- audit
  inconsistent$selected_g[1] <- 9L
  inconsistent$row_hash <- benchmark_row_sha256(inconsistent, "row_hash")
  testthat::expect_error(
    validate_score_support_audit(inconsistent, support_models(), support_inventory()),
    "single global selected G"
  )
  unknown <- audit[1, ]
  unknown$boundary_id <- "not_registered"
  unknown$row_hash <- benchmark_row_sha256(unknown, "row_hash")
  testthat::expect_error(
    validate_score_support_audit(rbind(audit, unknown), support_models(), support_inventory()),
    "unregistered audit key"
  )
})

testthat::test_that("seed identities are model independent and tamper evident", {
  seeds <- contract_seed_registry()
  testthat::expect_silent(validate_seed_registry(seeds))
  testthat::expect_false("model_id" %in% names(seeds))
  tampered <- seeds
  tampered$seed <- 102L
  testthat::expect_error(validate_seed_registry(tampered), "seed key SHA-256")
})

testthat::test_that("stage probabilities conserve mass and decline by reach stage", {
  stages <- data.frame(
    run_id = "run_1", model_id = "elo_goal_nb", edition_id = "wc2002",
    anchor_boundary_id = "wc2002__frozen", team_id = rep(c("a", "b"), each = 3),
    stage_id = rep(c("semifinal", "final", "champion"), 2),
    stage_order = rep(1:3, 2), probability = c(0.8, 0.6, 0.55, 0.7, 0.5, 0.45),
    n_simulations = 50000L, seed_id = "stage_seed", format_id = "wc32_r16",
    stringsAsFactors = FALSE
  )
  testthat::expect_silent(validate_stage_probabilities(stages))
  bad_mass <- stages
  bad_mass$probability[bad_mass$stage_id == "champion"][1] <- 0.5
  testthat::expect_error(validate_stage_probabilities(bad_mass), "champion mass")
})

testthat::test_that("run manifests require complete contract outcomes", {
  manifest <- data.frame(
    run_id = "run_1", protocol_version = "1.0", git_sha = strrep("a", 40),
    dirty_worktree = FALSE, sealed_data_policy = "wc2026_labels_denied",
    registry_sha256 = strrep("b", 64), model_registry_sha256 = strrep("c", 64),
    score_support_audit_sha256 = strrep("d", 64), seed_registry_sha256 = strrep("e", 64),
    prediction_contract_valid = TRUE, distribution_contract_valid = TRUE,
    manifest_contract_valid = TRUE, feature_coverage_valid = TRUE,
    panel_coverage_valid = TRUE, seed_contract_valid = TRUE,
    reproducible = TRUE, stringsAsFactors = FALSE
  )
  testthat::expect_silent(validate_benchmark_run_manifest(manifest))
  manifest$panel_coverage_valid <- FALSE
  testthat::expect_error(validate_benchmark_run_manifest(manifest), "contract flags")
})
