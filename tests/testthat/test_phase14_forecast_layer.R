library(testthat)

phase14_forecast_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

source(file.path(
  phase14_forecast_test_project_root,
  "R/evaluation/proper_scores.R"
))
source(file.path(
  phase14_forecast_test_project_root,
  "R/benchmark/contracts.R"
))

phase14_forecast_fixture_path <- file.path(
  phase14_forecast_test_project_root,
  "tests/fixtures/phase14/forecast_fixture.csv"
)

phase14_forecast_cases <- function() {
  utils::read.csv(
    phase14_forecast_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

phase14_forecast_eligible_case <- function() {
  cases <- phase14_forecast_cases()
  cases[cases$case_id == "eligible-scheduled", , drop = FALSE]
}

phase14_forecast_fixture_grid <- function(row) {
  support <- seq.int(row$score_support_min[[1L]], row$score_support_max[[1L]])
  home_probability <- stats::dnbinom(
    support,
    size = row$grid_home_theta[[1L]],
    mu = row$grid_home_mean[[1L]]
  )
  away_probability <- stats::dnbinom(
    support,
    size = row$grid_away_theta[[1L]],
    mu = row$grid_away_mean[[1L]]
  )
  raw <- outer(home_probability, away_probability)
  grid <- expand.grid(home_goals = support, away_goals = support)
  grid$score_distribution_id <- row$score_distribution_id[[1L]]
  grid$probability <- as.vector(raw / sum(raw))
  grid$support_max_home <- row$score_support_max[[1L]]
  grid$support_max_away <- row$score_support_max[[1L]]
  grid$raw_tail_mass <- max(
    0,
    1 - sum(home_probability) * sum(away_probability)
  )
  grid$normalized <- TRUE
  grid[, c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )]
}

phase14_temperature_calibrate <- function(probabilities, temperature) {
  logits <- log(probabilities) / temperature
  calibrated <- exp(logits - max(logits))
  calibrated / sum(calibrated)
}

phase14_order_scorelines <- function(grid) {
  grid[order(
    -grid$probability,
    grid$home_goals + grid$away_goals,
    grid$home_goals,
    grid$away_goals
  ), , drop = FALSE]
}

phase14_first_cdf_support <- function(grid, goal_column, threshold) {
  support <- seq.int(0L, max(grid[[goal_column]]))
  marginal <- vapply(
    support,
    function(goal) sum(grid$probability[grid[[goal_column]] == goal]),
    numeric(1)
  )
  support[which(cumsum(marginal) >= threshold)[[1L]]]
}

phase14_fixture_batch_contract <- function(fixtures, lifecycle_state) {
  if (is.null(fixtures)) {
    stop("fixture input must not be null", call. = FALSE)
  }
  if (!is.data.frame(fixtures)) {
    stop("fixture input must be a data frame", call. = FALSE)
  }
  if (!nrow(fixtures)) {
    if (!identical(lifecycle_state, "pre_draw")) {
      stop("zero fixtures require explicit pre_draw lifecycle", call. = FALSE)
    }
    return(list(
      fixture_count = 0L,
      status_row_count = 0L,
      forecast_count = 0L,
      grid_count = 0L
    ))
  }
  if (identical(lifecycle_state, "pre_draw")) {
    stop("pre_draw lifecycle cannot fabricate fixtures", call. = FALSE)
  }
  available <- fixtures$forecast_status == "available"
  list(
    fixture_count = nrow(fixtures),
    status_row_count = nrow(fixtures),
    forecast_count = sum(available),
    grid_count = length(unique(stats::na.omit(
      fixtures$score_distribution_id[available]
    )))
  )
}

production_path <- file.path(
  phase14_forecast_test_project_root,
  "R/competition/forecast_layer.R"
)
if (file.exists(production_path)) source(production_path, local = .GlobalEnv)

test_that("forecast lineage hashes empty data-frame schemas", {
  empty_schema <- data.frame(stringsAsFactors = FALSE)
  first_hash <- phase14_forecast_hash_data(empty_schema)

  expect_type(first_hash, "character")
  expect_length(first_hash, 1L)
  expect_identical(first_hash, phase14_forecast_hash_data(empty_schema))
})

test_that("official upcoming source status is forecast eligible", {
  fixture <- data.frame(
    edition_id = "uefa_nations_league_2026_27",
    fixture_id = "nl-upcoming-regression",
    home_team_id = "team-a",
    away_team_id = "team-b",
    source_status = "UPCOMING",
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = "2026-11-12T19:45:00Z",
    stringsAsFactors = FALSE
  )

  expect_identical(
    phase14_forecast_eligibility(fixture, 1L, "uefa_nations_league_2026_27"),
    "eligible"
  )
})

test_that("inactive national-team xG lineage exposes unavailable reason", {
  enriched <- phase14_forecast_batch_enrich_features(
    feature_result = list(
      model_form = data.frame(
        availability_reason = "no_accepted_national_team_xg_source",
        stringsAsFactors = FALSE
      ),
      xg_evidence_status = "inactive_optional_unavailable"
    ),
    manifest = list(
      active_predictors = "elo_diff",
      dropped_predictors_with_reason = "xg_missing",
      manifest_sha256 = "manifest"
    ),
    resolved_release = list(model_data_cutoff = "2026-06-10"),
    adapted_matches = data.frame(
      feature_cutoff_utc = "2026-11-12T19:44:59Z",
      stringsAsFactors = FALSE
    )
  )

  expect_match(enriched$national_team_xg_availability_reason, "inactive_optional_unavailable")
})

test_that("forecast fixture freezes the complete eligibility and suppression enum", {
  cases <- phase14_forecast_cases()
  required <- c(
    "case_id", "edition_id", "edition_lifecycle_state", "fixture_id",
    "home_team_id", "away_team_id", "match_status", "kickoff_utc",
    "kickoff_confirmed", "identity_status", "feature_evidence_status",
    "release_calibration_status", "forecast_status", "suppression_reason",
    "expected_fixture_count", "expected_status_row_count",
    "expected_forecast_count", "expected_grid_count", "model_release_id",
    "release_manifest_sha256", "model_id", "model_sha256", "calibrator_id",
    "calibrator_sha256", "model_data_cutoff", "feature_cutoff_utc",
    "latest_evidence_at_utc", "raw_probability_view",
    "primary_probability_view", "grid_home_mean", "grid_home_theta",
    "grid_away_mean", "grid_away_theta", "calibration_temperature",
    "p_home_raw", "p_draw_raw", "p_away_raw", "p_home", "p_draw", "p_away",
    "expected_home_goals", "expected_away_goals", "modal_home_goals",
    "modal_away_goals", "modal_score_probability", "score_distribution_id",
    "score_support_min", "score_support_max", "score_cell_count",
    "raw_tail_mass", "top10_scoreline_mass", "top10_omitted_mass",
    "entropy_nats", "max_outcome_probability", "home_goals_p10",
    "home_goals_p90", "away_goals_p10", "away_goals_p90",
    "uncertainty_status", "calculation_method", "seed_status",
    "simulation_count_status", "monte_carlo_seed", "monte_carlo_count",
    "source_bundle_id", "accepted_state_sha256", "edition_registry_revision",
    "edition_registry_row_sha256", "ruleset_version",
    "team_identity_registry_sha256", "contributing_form_sha256",
    "contributing_history_sha256", "generated_at_utc"
  )

  expect_named(cases, required)
  expect_equal(anyDuplicated(cases$case_id), 0L)
  expect_equal(nrow(cases), 7L)
  expect_setequal(
    cases$suppression_reason,
    c(
      "none", "pre_draw", "kickoff_unconfirmed", "identity_unresolved",
      "feature_evidence_unavailable", "release_not_calibrated",
      "status_ineligible"
    )
  )
  expect_setequal(cases$forecast_status, c("available", "suppressed"))
  expect_true(all(cases$model_data_cutoff == "2026-06-10"))

  available <- cases[cases$forecast_status == "available", , drop = FALSE]
  suppressed <- cases[cases$forecast_status == "suppressed", , drop = FALSE]
  expect_equal(nrow(available), 1L)
  expect_identical(available$suppression_reason, "none")
  expect_identical(available$release_calibration_status, "fitted")
  expect_identical(available$primary_probability_view, "calibrated_1x2")
  expect_true(all(is.na(suppressed$p_home)))
  expect_true(all(is.na(suppressed$score_distribution_id)))
  expect_true(all(suppressed$uncertainty_status == "unavailable"))

  raw_release <- cases[
    cases$suppression_reason == "release_not_calibrated",
    ,
    drop = FALSE
  ]
  expect_identical(raw_release$release_calibration_status, "raw_fallback")
  expect_identical(raw_release$primary_probability_view, "raw_1x2")
  expect_identical(raw_release$forecast_status, "suppressed")
})

test_that("forecast fixture rejects null and only permits empty explicit pre_draw input", {
  cases <- phase14_forecast_cases()
  empty <- cases[FALSE, , drop = FALSE]
  expect_error(
    phase14_fixture_batch_contract(NULL, "pre_draw"),
    "must not be null"
  )
  expect_error(
    phase14_fixture_batch_contract(empty, "scheduled"),
    "explicit pre_draw"
  )
  expect_identical(
    phase14_fixture_batch_contract(empty, "pre_draw"),
    list(
      fixture_count = 0L,
      status_row_count = 0L,
      forecast_count = 0L,
      grid_count = 0L
    )
  )

  eligible <- phase14_forecast_eligible_case()
  actual <- phase14_fixture_batch_contract(eligible, "scheduled")
  expect_identical(actual$fixture_count, 1L)
  expect_identical(actual$status_row_count, 1L)
  expect_identical(actual$forecast_count, 1L)
  expect_identical(actual$grid_count, 1L)
  expect_identical(
    unname(unlist(actual)),
    unname(as.integer(eligible[1, c(
      "expected_fixture_count", "expected_status_row_count",
      "expected_forecast_count", "expected_grid_count"
    )]))
  )
})

test_that("G=40 support is inclusive, complete, and rejects -1 or 41", {
  row <- phase14_forecast_eligible_case()
  grid <- phase14_forecast_fixture_grid(row)

  expect_equal(nrow(grid), 41L * 41L)
  expect_equal(nrow(grid), row$score_cell_count)
  expect_identical(range(grid$home_goals), c(0L, 40L))
  expect_identical(range(grid$away_goals), c(0L, 40L))
  expect_silent(validate_benchmark_score_distributions(
    grid,
    expected_distribution_ids = row$score_distribution_id,
    support_max = 40L,
    tolerance = 1e-10,
    raw_tail_tolerance = 1e-10
  ))

  below <- grid
  below$home_goals[[1L]] <- -1L
  expect_error(
    validate_benchmark_score_distributions(
      below, row$score_distribution_id, 40L,
      tolerance = 1e-10, raw_tail_tolerance = 1e-10
    ),
    "non-negative|complete"
  )
  above <- grid
  above$away_goals[[nrow(above)]] <- 41L
  expect_error(
    validate_benchmark_score_distributions(
      above, row$score_distribution_id, 40L,
      tolerance = 1e-10, raw_tail_tolerance = 1e-10
    ),
    "complete"
  )
})

test_that("probability mass uses the exact 1e-10 tolerance", {
  row <- phase14_forecast_eligible_case()
  grid <- phase14_forecast_fixture_grid(row)
  score <- grid[, c("home_goals", "away_goals", "probability")]

  within <- score
  within$probability[[1L]] <- within$probability[[1L]] + 0.5e-10
  expect_silent(validate_scoreline_distribution(
    within,
    tolerance = 1e-10,
    support_max = 40L,
    require_full_rectangle = TRUE,
    raw_tail_mass = row$raw_tail_mass,
    tail_tolerance = 1e-10
  ))

  outside <- score
  outside$probability[[1L]] <- outside$probability[[1L]] + 2e-10
  expect_error(
    validate_scoreline_distribution(
      outside,
      tolerance = 1e-10,
      support_max = 40L,
      require_full_rectangle = TRUE,
      raw_tail_mass = row$raw_tail_mass,
      tail_tolerance = 1e-10
    ),
    "sum to one"
  )
})

test_that("equal-probability scorelines stay distinct and use deterministic adjacency", {
  tied <- data.frame(
    home_goals = c(1L, 0L, 2L, 0L),
    away_goals = c(0L, 1L, 0L, 2L),
    probability = c(0.25, 0.25, 0.25, 0.25)
  )
  ordered <- phase14_order_scorelines(tied)

  expect_equal(nrow(ordered), 4L)
  expect_equal(anyDuplicated(paste(ordered$home_goals, ordered$away_goals)), 0L)
  expect_identical(
    paste(ordered$home_goals, ordered$away_goals, sep = "-"),
    c("0-1", "1-0", "0-2", "2-0")
  )
  expect_true(all(ordered$probability == 0.25))
})

test_that("raw and calibrated simplices remain separate from score-grid derivations", {
  row <- phase14_forecast_eligible_case()
  grid <- phase14_forecast_fixture_grid(row)
  grid_before <- grid
  market <- derive_benchmark_markets(grid, tolerance = 1e-10)
  raw <- unname(unlist(market[c("p_home", "p_draw", "p_away")]))
  calibrated <- phase14_temperature_calibrate(
    raw,
    row$calibration_temperature[[1L]]
  )

  expect_equal(raw, unname(as.numeric(row[1, c(
    "p_home_raw", "p_draw_raw", "p_away_raw"
  )])), tolerance = 1e-12)
  expect_equal(calibrated, unname(as.numeric(row[1, c(
    "p_home", "p_draw", "p_away"
  )])), tolerance = 1e-12)
  expect_equal(sum(raw), 1, tolerance = 1e-10)
  expect_equal(sum(calibrated), 1, tolerance = 1e-10)
  expect_false(isTRUE(all.equal(raw, calibrated, tolerance = 1e-12)))
  expect_identical(grid, grid_before)

  expect_equal(
    market$expected_home_goals,
    row$expected_home_goals,
    tolerance = 1e-12
  )
  expect_equal(
    market$expected_away_goals,
    row$expected_away_goals,
    tolerance = 1e-12
  )
  expect_identical(market$modal_home_goals, as.integer(row$modal_home_goals))
  expect_identical(market$modal_away_goals, as.integer(row$modal_away_goals))
  expect_equal(
    market$modal_score_probability,
    row$modal_score_probability,
    tolerance = 1e-12
  )
})

test_that("top-10, natural entropy, and first-CDF intervals are exact", {
  row <- phase14_forecast_eligible_case()
  grid <- phase14_forecast_fixture_grid(row)
  ordered <- phase14_order_scorelines(grid)
  top10 <- ordered[seq_len(10L), , drop = FALSE]
  consumer <- as.numeric(row[1, c("p_home", "p_draw", "p_away")])
  entropy <- -sum(consumer * log(consumer))
  entropy_bits <- -sum(consumer * log2(consumer))

  expect_identical(
    paste(top10$home_goals, top10$away_goals, sep = "-"),
    c("1-0", "0-0", "1-1", "2-0", "0-1", "2-1", "3-0", "1-2", "0-2", "3-1")
  )
  expect_equal(sum(top10$probability), row$top10_scoreline_mass, tolerance = 1e-12)
  expect_equal(1 - sum(top10$probability), row$top10_omitted_mass, tolerance = 1e-12)
  expect_equal(entropy, row$entropy_nats, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(entropy_bits, row$entropy_nats, tolerance = 1e-12)))
  expect_equal(max(consumer), row$max_outcome_probability, tolerance = 1e-12)
  expect_identical(
    phase14_first_cdf_support(grid, "home_goals", 0.10),
    as.integer(row$home_goals_p10)
  )
  expect_identical(
    phase14_first_cdf_support(grid, "home_goals", 0.90),
    as.integer(row$home_goals_p90)
  )
  expect_identical(
    phase14_first_cdf_support(grid, "away_goals", 0.10),
    as.integer(row$away_goals_p10)
  )
  expect_identical(
    phase14_first_cdf_support(grid, "away_goals", 0.90),
    as.integer(row$away_goals_p90)
  )
})

test_that("analytic uncertainty and D-20 lineage are complete and exact", {
  row <- phase14_forecast_eligible_case()
  hash_fields <- c(
    "release_manifest_sha256", "model_sha256", "calibrator_sha256",
    "accepted_state_sha256", "edition_registry_row_sha256",
    "team_identity_registry_sha256", "contributing_form_sha256",
    "contributing_history_sha256"
  )
  lineage_fields <- c(
    "edition_id", "fixture_id", "kickoff_utc", "source_bundle_id",
    "edition_registry_revision", "ruleset_version", "model_release_id",
    "model_id", "calibrator_id", "model_data_cutoff", "feature_cutoff_utc",
    "latest_evidence_at_utc", "score_support_max", "calculation_method",
    "seed_status", "simulation_count_status", "generated_at_utc"
  )

  expect_true(all(!is.na(row[lineage_fields])))
  expect_true(all(vapply(row[hash_fields], function(value) {
    grepl("^[0-9a-f]{64}$", value)
  }, logical(1))))
  expect_identical(row$model_data_cutoff, "2026-06-10")
  expect_identical(row$feature_cutoff_utc, "2026-09-05T18:44:59Z")
  expect_identical(row$calculation_method, "analytic_negative_binomial")
  expect_identical(row$seed_status, "not_applicable")
  expect_identical(row$simulation_count_status, "not_applicable")
  expect_true(is.na(row$monte_carlo_seed))
  expect_true(is.na(row$monte_carlo_count))
  expect_identical(row$uncertainty_status, "available")
})

test_that("production forecast API enforces the frozen Wave 0 contract", {
  skip_if_not(exists("phase14_build_fixture_forecasts"))

  cases <- phase14_forecast_cases()
  result <- phase14_build_fixture_forecasts(cases)
  expect_type(result, "list")
  expect_true(all(c(
    "forecasts", "score_distributions", "fixture_status"
  ) %in% names(result)))
  expect_equal(
    nrow(result$forecasts),
    sum(cases$expected_forecast_count)
  )
  expect_equal(
    length(unique(result$score_distributions$score_distribution_id)),
    sum(cases$expected_grid_count)
  )
  expect_setequal(
    result$fixture_status$suppression_reason,
    cases$suppression_reason[cases$expected_status_row_count == 1L]
  )
})

phase14_forecast_tracer_registry <- function() {
  utils::read.csv(
    file.path(phase14_forecast_test_project_root, "data/competition/registries/team_identity.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
}

phase14_forecast_tracer_match <- function(edition_id = "uefa_nations_league_2026_27") {
  data.frame(
    edition_id = edition_id,
    match_id = "uefa_nations_league_2026_27-nl-2026-0001",
    fixture_id = "uefa_nations_league_2026_27-nl-2026-0001",
    home_team_id = "team_aut",
    away_team_id = "team_deu",
    scheduled_at_utc = "2026-09-05T18:45:00Z",
    kickoff_utc = "2026-09-05T18:45:00Z",
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = "2026-09-05T18:45:00Z",
    feature_cutoff_utc = "2026-09-05T18:44:59Z",
    match_status = "scheduled",
    source_status = "scheduled",
    venue = "home",
    home_score = NA_real_,
    away_score = NA_real_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_forecast_tracer_release_inputs <- function() {
  list(
    selector_path = file.path(phase14_forecast_test_project_root, "outputs/releases/approved_release.csv"),
    trusted_release_root = file.path(phase14_forecast_test_project_root, "outputs/releases"),
    model_manifest_path = file.path(
      phase14_forecast_test_project_root,
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv"
    ),
    elo_ratings = utils::read.csv(
      file.path(phase14_forecast_test_project_root, "data/processed/elo_ratings.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    ),
    national_team_xg_registry = file.path(
      phase14_forecast_test_project_root,
      "data/competition/registries/national_team_xg_sources.csv"
    )
  )
}

test_that("permanent Austria/Germany tracer adapts the canonical fixture and preserves strict lineage", {
  inputs <- phase14_forecast_tracer_release_inputs()
  matches <- phase14_forecast_tracer_match()
  registry <- phase14_forecast_tracer_registry()

  adapted <- phase14_adapt_matches_for_forecast(
    canonical_matches = matches,
    team_registry = registry,
    feature_cutoff_utc = matches$feature_cutoff_utc
  )

  expect_named(
    adapted,
    c(
      "edition_id", "match_id", "fixture_id", "home_team_id", "away_team_id",
      "date", "home_team_canonical", "away_team_canonical", "home_score",
      "away_score", "venue", "kickoff_utc", "feature_cutoff_utc",
      "kickoff_confirmed"
    ),
    ignore.order = FALSE
  )
  expect_identical(adapted$date, as.Date("2026-09-05"))
  expect_identical(adapted$home_team_canonical, "Austria")
  expect_identical(adapted$away_team_canonical, "Germany")
  expect_identical(adapted$match_id, matches$match_id)
  expect_identical(adapted$venue, "home")
  expect_true(is.na(adapted$home_score) && is.na(adapted$away_score))
  expect_identical(adapted$kickoff_utc, "2026-09-05T18:45:00Z")
  expect_identical(adapted$feature_cutoff_utc, "2026-09-05T18:44:59Z")

  resolved <- phase14_resolve_approved_release(
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$trusted_release_root
  )
  features <- phase14_build_release_features(
    adapted_matches = adapted,
    resolved_release = resolved,
    elo_ratings = inputs$elo_ratings,
    national_team_xg_registry = inputs$national_team_xg_registry,
    model_manifest_path = inputs$model_manifest_path
  )

  expect_identical(features$active_predictors, "elo_diff")
  expect_true(all(grepl("xg|form", features$dropped_predictors_with_reason)))
  expect_true(isTRUE(features$feature_table$elo_diff__value_present[[1L]]))
  expect_true(is.finite(features$feature_table$elo_diff[[1L]]))
  expect_identical(features$feature_evidence_status, "available")
  expect_identical(features$xg_evidence_status, "inactive_optional_unavailable")
  expect_true(all(is.na(features$feature_table[1L, c(
    "xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff"
  )])))
  expect_false(any(grepl("rolling_form|club|xg", features$feature_evidence_source)))

  result <- phase14_build_fixture_forecasts(
    canonical_matches = matches,
    team_registry = registry,
    resolved_release = resolved,
    elo_ratings = inputs$elo_ratings,
    national_team_xg_registry = inputs$national_team_xg_registry,
    model_manifest_path = inputs$model_manifest_path
  )
  expect_equal(nrow(result$forecasts), 1L)
  expect_equal(nrow(result$score_distributions), 41L * 41L)
  expect_identical(result$fixture_status$forecast_status, "available")
  expect_identical(result$fixture_status$suppression_reason, "none")
  expect_identical(result$forecasts$score_support_max, 40L)
  expect_identical(result$forecasts$primary_probability_view, "calibrated_1x2")
  expect_equal(sum(unlist(result$forecasts[1L, c("p_home", "p_draw", "p_away")])), 1, tolerance = 1e-12)
  expect_true(all(is.finite(unlist(result$forecasts[1L, c(
    "expected_home_goals", "expected_away_goals", "modal_score_probability",
    "entropy_nats", "top10_scoreline_mass", "top10_omitted_mass"
  )]))))
  expect_true(all(result$score_distributions$home_goals %in% 0:40))
  expect_true(all(result$score_distributions$away_goals %in% 0:40))
  expect_true(result$forecasts$feature_cutoff_utc[[1L]] < result$forecasts$kickoff_utc[[1L]])
  expect_true(result$forecasts$latest_evidence_at_utc[[1L]] < result$forecasts$feature_cutoff_utc[[1L]])
  expect_true(grepl("^[0-9a-f]{64}$", result$forecasts$release_manifest_sha256[[1L]]))
})

test_that("active xG release suppresses the same fixture while club form is rejected", {
  inputs <- phase14_forecast_tracer_release_inputs()
  matches <- phase14_forecast_tracer_match()
  registry <- phase14_forecast_tracer_registry()
  manifest <- utils::read.csv(
    inputs$model_manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  manifest <- manifest[manifest$model_id == "open_nb_incumbent", , drop = FALSE]
  manifest <- manifest[1L, , drop = FALSE]
  manifest$active_predictors <- "elo_diff|xgf_ewma_diff|xga_ewma_diff|xgd_ewma_diff"
  manifest$dropped_predictors_with_reason <- "form_index_diff|inactive_optional"
  attr(manifest, "immutable_manifest_sha256") <- digest::digest(
    paste(capture.output(utils::write.csv(manifest, stdout(), row.names = FALSE)), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )

  suppressed <- phase14_build_fixture_forecasts(
    canonical_matches = matches,
    team_registry = registry,
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$trusted_release_root,
    elo_ratings = inputs$elo_ratings,
    national_team_xg_registry = inputs$national_team_xg_registry,
    model_manifest = manifest
  )
  expect_identical(suppressed$fixture_status$forecast_status, "suppressed")
  expect_identical(suppressed$fixture_status$suppression_reason, "feature_evidence_unavailable")
  expect_equal(nrow(suppressed$forecasts), 0L)
  expect_equal(nrow(suppressed$score_distributions), 0L)

  expect_error(
    phase14_build_release_features(
      adapted_matches = phase14_adapt_matches_for_forecast(
        matches, registry, matches$feature_cutoff_utc
      ),
      selector_path = inputs$selector_path,
      trusted_release_root = inputs$trusted_release_root,
      elo_ratings = inputs$elo_ratings,
      national_team_xg_history = utils::read.csv(
        file.path(phase14_forecast_test_project_root, "data/processed/rolling_form.csv"),
        stringsAsFactors = FALSE,
        check.names = FALSE,
        na.strings = ""
      ),
      model_manifest = manifest
    ),
    "club rolling_form|national-team xG|stable national match_id"
  )
})

phase14_forecast_batch_fixture <- function() {
  base <- phase14_forecast_tracer_match()
  unconfirmed <- base
  unconfirmed$fixture_id <- "uefa_nations_league_2026_27-nl-2026-0002"
  unconfirmed$match_id <- unconfirmed$fixture_id
  unconfirmed$kickoff_confirmed <- FALSE
  unconfirmed$confirmed_kickoff_at_utc <- NA_character_
  unconfirmed$kickoff_utc <- NA_character_
  unconfirmed$feature_cutoff_utc <- NA_character_

  unresolved <- base
  unresolved$fixture_id <- "uefa_nations_league_2026_27-nl-2026-0003"
  unresolved$match_id <- unresolved$fixture_id
  unresolved$away_team_id <- NA_character_

  ineligible <- base
  ineligible$fixture_id <- "uefa_nations_league_2026_27-nl-2026-0004"
  ineligible$match_id <- ineligible$fixture_id
  ineligible$match_status <- "postponed"
  ineligible$source_status <- "postponed"

  rbind(base, unconfirmed, unresolved, ineligible)
}

test_that("production forecast batches retain every fixture and compact local outputs", {
  inputs <- phase14_forecast_tracer_release_inputs()
  result <- phase14_build_fixture_forecasts(
    canonical_matches = phase14_forecast_batch_fixture(),
    team_registry = phase14_forecast_tracer_registry(),
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$trusted_release_root,
    elo_ratings = inputs$elo_ratings,
    national_team_xg_registry = inputs$national_team_xg_registry,
    model_manifest_path = inputs$model_manifest_path,
    generated_at_utc = "2026-08-17T00:00:00Z"
  )

  expect_true(all(c(
    "forecasts", "score_distributions", "forecast_top10", "fixture_status"
  ) %in% names(result)))
  expected_ids <- phase14_forecast_batch_fixture()$fixture_id
  expect_identical(as.character(result$fixture_status$fixture_id), expected_ids)
  expect_identical(
    sort(unique(c(result$forecasts$fixture_id, result$fixture_status$fixture_id))),
    sort(expected_ids)
  )
  expect_equal(nrow(result$forecasts), 1L)
  expect_equal(nrow(result$score_distributions), 41L * 41L)
  expect_equal(nrow(result$forecast_top10), 10L)
  expect_identical(result$forecasts$score_support_max, 40L)
  expect_identical(result$forecast_top10$rank, seq_len(10L))
  expect_true(all(result$fixture_status$model_data_cutoff == "2026-06-10"))
  expect_true(all(result$fixture_status$active_predictors == "elo_diff"))
  expect_true(all(grepl("^form_index_diff|xg", result$fixture_status$dropped_predictors_with_reason)))
  expect_true(all(result$fixture_status$generated_at_utc == "2026-08-17T00:00:00Z"))
  expect_identical(
    as.character(result$fixture_status$suppression_reason),
    c("none", "kickoff_unconfirmed", "identity_unresolved", "status_ineligible")
  )
  expect_true(all(grepl("^[0-9a-f]{64}$", result$fixture_status$row_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", result$forecasts$row_sha256)))
})

test_that("batch forecast resolves release, features, and prediction exactly once", {
  inputs <- phase14_forecast_tracer_release_inputs()
  matches <- phase14_forecast_tracer_match()
  second <- matches
  second$fixture_id <- "uefa_nations_league_2026_27-nl-2026-0002"
  second$match_id <- second$fixture_id
  calls <- new.env(parent = emptyenv())
  calls$resolve <- 0L
  calls$features <- 0L
  calls$predict <- 0L

  resolver <- function(selector_path, trusted_release_root) {
    calls$resolve <- calls$resolve + 1L
    phase14_resolve_approved_release(selector_path, trusted_release_root)
  }
  feature_builder <- function(...) {
    calls$features <- calls$features + 1L
    phase14_build_release_features(...)
  }
  predictor <- function(...) {
    calls$predict <- calls$predict + 1L
    predict_registered_baseline(...)
  }

  result <- phase14_build_fixture_forecasts(
    canonical_matches = rbind(matches, second),
    team_registry = phase14_forecast_tracer_registry(),
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$trusted_release_root,
    elo_ratings = inputs$elo_ratings,
    national_team_xg_registry = inputs$national_team_xg_registry,
    model_manifest_path = inputs$model_manifest_path,
    resolve_release_fn = resolver,
    build_features_fn = feature_builder,
    predict_fn = predictor,
    generated_at_utc = "2026-08-17T00:00:00Z"
  )

  expect_equal(calls$resolve, 1L)
  expect_equal(calls$features, 1L)
  expect_equal(calls$predict, 1L)
  expect_equal(nrow(result$forecasts), 2L)
  expect_equal(length(unique(result$forecasts$score_distribution_id)), 2L)
})
