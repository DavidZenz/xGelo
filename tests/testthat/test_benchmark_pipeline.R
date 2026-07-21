library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
for (path in c(
  "R/evaluation/proper_scores.R", "R/benchmark/registry.R", "R/benchmark/cutoffs.R",
  "R/benchmark/contracts.R", "R/benchmark/baselines.R",
  "R/evaluation/benchmark_scores.R", "R/evaluation/promotion.R",
  "R/benchmark/runner.R"
)) source(file.path(project_root, path))

pipeline_hash <- function(value) {
  digest::digest(paste(value, collapse = "|"), algo = "sha256", serialize = FALSE)
}

pipeline_models <- function() {
  data.frame(
    model_id = c("uniform_1x2", "production_hybrid_nb"),
    panel_id = c("open_core", "feature_rich"),
    candidate_min = 1L, candidate_max = 2L, raw_tail_tolerance = 1e-6,
    registration_sha256 = c(strrep("a", 64), strrep("b", 64)),
    settings_sha256 = c(strrep("c", 64), strrep("d", 64)),
    stringsAsFactors = FALSE
  )
}

pipeline_boundaries <- function() {
  data.frame(
    edition_id = rep(c("wc2002", "euro2004"), each = 2L),
    track_id = rep(c("frozen", "updating"), 2L),
    boundary_id = c("wc2002__frozen", "wc2002__day1", "euro2004__frozen", "euro2004__day1"),
    boundary_sha256 = vapply(1:4, function(i) strrep(as.character(i), 64), character(1)),
    stringsAsFactors = FALSE
  )
}

pipeline_support_audit <- function(models = pipeline_models(), boundaries = pipeline_boundaries()) {
  audit <- merge(models[, "model_id", drop = FALSE], boundaries, by = NULL)
  audit <- merge(audit, data.frame(candidate_g = 1:2), by = NULL)
  audit$raw_omitted_tail <- ifelse(audit$candidate_g == 1L, 1e-3, 1e-8)
  audit$tolerance <- 1e-6
  audit$pass <- audit$raw_omitted_tail <= audit$tolerance
  audit$selected_g <- 2L
  audit <- merge(
    audit,
    models[, c("model_id", "registration_sha256", "settings_sha256")],
    by = "model_id", sort = FALSE
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

pipeline_bundle <- function(order_rows = FALSE) {
  models <- pipeline_models()
  boundaries <- pipeline_boundaries()
  keys <- merge(models[, c("model_id", "panel_id")], boundaries, by = NULL)
  keys$fixture_id <- paste0(keys$edition_id, "_fixture")
  keys$run_id <- "synthetic"
  keys$score_distribution_id <- paste(keys$model_id, keys$track_id, keys$fixture_id, sep = "__")
  keys$model_manifest_id <- paste(keys$run_id, keys$model_id, keys$boundary_id, sep = "__")
  keys$feature_coverage_id <- paste(
    keys$run_id, keys$model_id, keys$track_id, keys$fixture_id, sep = "__"
  )

  grids <- lapply(keys$score_distribution_id, function(id) {
    grid <- expand.grid(home_goals = 0:2, away_goals = 0:2)
    raw <- outer(stats::dpois(0:2, 1.1), stats::dpois(0:2, 0.8))
    grid$score_distribution_id <- id
    grid$probability <- as.vector(raw / sum(raw))
    grid$support_max_home <- 2L
    grid$support_max_away <- 2L
    grid$raw_tail_mass <- 1e-8
    grid$normalized <- TRUE
    grid[, c(
      "score_distribution_id", "home_goals", "away_goals", "probability",
      "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
    )]
  })
  distributions <- do.call(rbind, grids)

  predictions <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    market <- derive_benchmark_markets(grids[[i]])
    data.frame(
      schema_version = "1.0", run_id = keys$run_id[i], model_id = keys$model_id[i],
      panel_id = keys$panel_id[i], edition_id = keys$edition_id[i], track_id = keys$track_id[i],
      fixture_id = keys$fixture_id[i], boundary_id = keys$boundary_id[i], forecast_sequence = 1L,
      home_team_id = "home", away_team_id = "away", venue_role = "neutral",
      evidence_cutoff_exclusive = as.Date("2002-01-02"),
      result_cutoff_exclusive = as.Date("2002-01-02"),
      model_manifest_id = keys$model_manifest_id[i],
      feature_coverage_id = keys$feature_coverage_id[i], seed_id = paste0("seed_", i),
      score_distribution_id = keys$score_distribution_id[i],
      as.data.frame(market, stringsAsFactors = FALSE),
      prediction_status = "ok", failure_reason = "", stringsAsFactors = FALSE
    )
  }))

  manifests <- unique(keys[, c("run_id", "model_id", "edition_id", "track_id", "boundary_id", "model_manifest_id")])
  manifests$fit_status <- "ok"
  manifests$registration_sha256 <- models$registration_sha256[match(manifests$model_id, models$model_id)]
  manifests$settings_sha256 <- models$settings_sha256[match(manifests$model_id, models$model_id)]
  manifests$parent_hashes <- mapply(
    function(registration, settings, boundary) pipeline_hash(c(registration, settings, boundary)),
    manifests$registration_sha256, manifests$settings_sha256, manifests$boundary_id,
    USE.NAMES = FALSE
  )
  manifests$output_coverage_complete <- TRUE
  feature_contract <- data.frame(
    panel_id = c("open_core", "feature_rich"), feature_id = c("elo_difference_for_team", "xgf_ewma_diff"),
    source_id = c("elo_ratings_recursive_open", "hybrid_goal_training_features"),
    source_artifact_sha256 = c(strrep("a", 64), strrep("b", 64)),
    license_class = "open", row_sha256 = c(strrep("c", 64), strrep("d", 64)),
    stringsAsFactors = FALSE
  )
  coverage <- merge(
    predictions[, c(
      "feature_coverage_id", "run_id", "model_id", "panel_id", "edition_id",
      "track_id", "boundary_id", "fixture_id"
    )],
    feature_contract, by = "panel_id", sort = FALSE
  )
  coverage$schema_version <- "1.0"
  coverage$feature_contract_row_sha256 <- coverage$row_sha256
  coverage$value_present <- TRUE
  coverage$source_present <- TRUE
  coverage$source_date <- as.Date("2002-01-01")
  coverage$evidence_cutoff_exclusive <- as.Date("2002-01-02")
  coverage$cutoff_valid <- TRUE
  coverage$imputed <- FALSE
  coverage$imputation_reason <- ""
  coverage$active_in_fit <- TRUE
  coverage$coverage_status <- "active_observed"
  coverage$row_sha256 <- NULL
  panel_fixtures <- do.call(rbind, lapply(c("open_core", "feature_rich"), function(panel_id) {
    data.frame(
      panel_id = panel_id, edition_id = c("wc2002", "euro2004"),
      fixture_id = c("wc2002_fixture", "euro2004_fixture"), eligible = TRUE,
      point_in_time_provenance_complete = TRUE, output_coverage_required = TRUE,
      stringsAsFactors = FALSE
    )
  }))
  panel_fixtures <- rbind(panel_fixtures, data.frame(
    panel_id = "feature_rich", edition_id = "wc2002", fixture_id = "rich_ineligible",
    eligible = FALSE, point_in_time_provenance_complete = FALSE,
    output_coverage_required = FALSE, stringsAsFactors = FALSE
  ))
  stage_keys <- unique(keys[, c("model_id", "edition_id")])
  stages <- do.call(rbind, lapply(seq_len(nrow(stage_keys)), function(i) data.frame(
    run_id = "synthetic", model_id = stage_keys$model_id[i], edition_id = stage_keys$edition_id[i],
    anchor_boundary_id = paste0(stage_keys$edition_id[i], "__frozen"),
    team_id = c("home", "away"), stage_id = "champion", stage_order = 1L,
    probability = c(0.5, 0.5), n_simulations = 50000L,
    seed_id = paste0("stage_", stage_keys$edition_id[i]), format_id = "synthetic", stringsAsFactors = FALSE
  )))
  scores <- transform(
    keys[, c("run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id")],
    target = "regulation_1x2", metric = "rps", value = 0.2, covered = TRUE
  )
  summaries <- transform(
    keys[, c("run_id", "model_id", "panel_id", "track_id", "edition_id")],
    grain = "tournament", aggregation = "within_tournament", estimate = 0.2,
    n_tournaments = 1L, n_fixtures = 1L, coverage = 1
  )
  comparisons <- do.call(rbind, lapply(seq_len(nrow(models)), function(i) {
    do.call(rbind, lapply(c("frozen", "updating"), function(track_id) {
      base <- data.frame(
        challenger_id = models$model_id[i], incumbent_id = models$model_id[i],
        panel_id = models$panel_id[i], track_id = track_id, metric = "rps",
        stringsAsFactors = FALSE
      )
      rbind(
        cbind(base[rep(1L, 2L), ], data.frame(
          edition_id = c("wc2002", "euro2004"), delta = 0,
          paired_fixture_count = 1L, diagnostic = "fold",
          bootstrap_lower = 0, bootstrap_upper = 0
        )),
        cbind(base, data.frame(
          edition_id = "headline", delta = 0, paired_fixture_count = 2L,
          diagnostic = "headline", bootstrap_lower = 0, bootstrap_upper = 0
        )),
        cbind(base[rep(1L, 2L), ], data.frame(
          edition_id = c("wc2002", "euro2004"), delta = 0,
          paired_fixture_count = 2L, diagnostic = "leave_one_out",
          bootstrap_lower = NA_real_, bootstrap_upper = NA_real_
        ))
      )
    }))
  }))
  decisions <- data.frame(
    candidate_id = models$model_id, incumbent_id = c("uniform_1x2", "production_hybrid_nb"),
    panel_id = models$panel_id, output_coverage_complete = TRUE,
    promotion_eligible = c(FALSE, TRUE), decision = "retain_incumbent",
    reason_codes = "", stringsAsFactors = FALSE
  )
  run_manifest <- data.frame(
    run_id = "synthetic", protocol_version = "synthetic-v1", protocol_sha256 = strrep("e", 64),
    git_sha = strrep("f", 40), dirty_worktree = FALSE,
    sealed_data_policy = "wc2026_labels_denied", selected_g = 2L,
    prediction_contract_valid = TRUE, distribution_contract_valid = TRUE,
    manifest_contract_valid = TRUE, feature_coverage_valid = TRUE,
    panel_coverage_valid = TRUE, seed_contract_valid = TRUE,
    score_support_audit_valid = TRUE, registration_settings_stable = TRUE,
    output_coverage_reconciled = TRUE, wc2026_sealed = TRUE, network_free = TRUE,
    reproducible = TRUE, stringsAsFactors = FALSE
  )
  bundle <- list(
    model_manifests = manifests, feature_coverage = coverage,
    fixture_predictions = predictions, score_distributions = distributions,
    stage_probabilities = stages, fixture_scores = scores,
    benchmark_summaries = summaries, paired_comparisons = comparisons,
    promotion_decisions = decisions, run_manifest = run_manifest
  )
  if (order_rows) bundle <- lapply(bundle, function(x) x[rev(seq_len(nrow(x))), , drop = FALSE])
  list(
    bundle = bundle, models = models, boundaries = boundaries,
    audit = pipeline_support_audit(models, boundaries),
    panel_fixtures = panel_fixtures, feature_contract = feature_contract
  )
}

pipeline_promotion_protocol <- local({
  cached <- NULL
  function() {
    if (is.null(cached)) {
      cached <<- load_promotion_protocol(
        file.path(project_root, "data/benchmark/phase09/promotion_protocol.json")
      )
      cached$development_editions <<- c("wc2002", "euro2004")
      cached$incumbents$open_core <<- "uniform_1x2"
      cached$optional_data_gate$open_companion$incumbent_id <<- "uniform_1x2"
      cached$panels$open_core$fixture_count <<- 2L
      cached$optional_data_gate$open_companion$fixture_count <<- 2L
    }
    cached
  }
})

pipeline_promotion_sources <- function() {
  x <- pipeline_bundle()
  protocol <- pipeline_promotion_protocol()
  metrics <- data.frame(
    metric = c("rps", "brier", "log_loss", "calibration_error"),
    aggregation = c(
      "equal_tournament", "equal_tournament", "equal_tournament",
      "fixed_equal_tournament_bins"
    ),
    stringsAsFactors = FALSE
  )
  summaries <- do.call(rbind, lapply(seq_len(nrow(x$models)), function(i) {
    data.frame(
      run_id = "synthetic", model_id = x$models$model_id[i],
      panel_id = x$models$panel_id[i], track_id = "updating",
      target = "regulation_1x2", metric = metrics$metric,
      grain = "headline", aggregation = metrics$aggregation,
      edition_id = "headline", estimate = c(0.2, 0.45, 0.65, 0.03),
      n_tournaments = 2L, n_fixtures = 2L,
      coverage_numerator = 2L, coverage_denominator = 2L, coverage = 1,
      stringsAsFactors = FALSE
    )
  }))
  coverage <- benchmark_runner_output_coverage(
    x$bundle$fixture_predictions, x$panel_fixtures, x$models,
    data.frame(panel_id = c("open_core", "feature_rich"), coverage_floor = 0.8)
  )
  manifest <- x$bundle$run_manifest
  manifest$protocol_version <- protocol$protocol_version
  manifest$protocol_sha256 <- protocol$protocol_sha256
  list(
    x = x, protocol = protocol, summaries = summaries, coverage = coverage,
    comparisons = x$bundle$paired_comparisons, run_manifest = manifest
  )
}

test_that("the cache-only bundle writer creates and validates every durable artifact", {
  x <- pipeline_bundle()
  out <- tempfile("benchmark-bundle-")
  additional <- benchmark_runner_additional_input_specs(
    file.path(project_root, "data/benchmark/phase09")
  )
  result <- write_rolling_benchmark_bundle(
    x$bundle, out, score_support_audit = x$audit,
    model_registry = x$models, boundary_inventory = x$boundaries,
    additional_inputs = additional, panel_fixtures = x$panel_fixtures,
    feature_contract = x$feature_contract
  )
  expect_true(all(file.exists(unname(benchmark_output_paths(out)))))
  validated <- validate_rolling_benchmark_bundle(
    out, score_support_audit = x$audit, model_registry = x$models,
    boundary_inventory = x$boundaries, additional_inputs = additional,
    panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
  )
  expect_true(validated$valid)
  expect_true(validated$score_support_audit_valid)
  expect_true(validated$registration_settings_stable)
  expect_true(validated$output_coverage_reconciled)
  expect_equal(result$artifact_count, 11L)
  expect_true(all(names(additional) %in% result$checksum_manifest$artifact))
})

test_that("default bundle parents use the canonical registry normalization", {
  defaults <- formals(validate_rolling_benchmark_bundle)
  expect_null(defaults$score_support_audit)
  expect_null(defaults$model_registry)
  inputs <- benchmark_runner_load_inputs(
    file.path(project_root, "data/benchmark/phase09")
  )
  expect_identical(unique(inputs$model_registry$schema_version), "1.0")
})

test_that("bundle validation rejects missing rows and corrupted parent hashes", {
  x <- pipeline_bundle()
  out <- tempfile("benchmark-corrupt-")
  write_rolling_benchmark_bundle(
    x$bundle, out, x$audit, x$models, x$boundaries,
    panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
  )
  paths <- benchmark_output_paths(out)

  predictions <- read.csv(paths[["fixture_predictions"]], stringsAsFactors = FALSE)
  write.csv(predictions[-1, ], paths[["fixture_predictions"]], row.names = FALSE)
  expect_error(
    validate_rolling_benchmark_bundle(
      out, x$audit, x$models, x$boundaries,
      panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
    ),
    "checksum|prediction|missing"
  )

  out <- tempfile("benchmark-parent-")
  write_rolling_benchmark_bundle(
    x$bundle, out, x$audit, x$models, x$boundaries,
    panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
  )
  bad <- x$audit
  bad$parent_hashes[1] <- strrep("0", 64)
  bad$row_hash <- benchmark_row_sha256(bad, "row_hash")
  expect_error(
    validate_rolling_benchmark_bundle(
      out, bad, x$models, x$boundaries,
      panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
    ),
    "parent hash"
  )
})

test_that("canonical content hashes ignore output roots, timestamps, and branch ordering", {
  first <- pipeline_bundle()
  second <- pipeline_bundle(order_rows = TRUE)
  a <- write_rolling_benchmark_bundle(
    first$bundle, tempfile("benchmark-a-"), first$audit, first$models, first$boundaries,
    panel_fixtures = first$panel_fixtures, feature_contract = first$feature_contract
  )
  b <- write_rolling_benchmark_bundle(
    second$bundle, tempfile("benchmark-b-"), second$audit, second$models, second$boundaries,
    panel_fixtures = second$panel_fixtures, feature_contract = second$feature_contract
  )
  expect_identical(a$content_sha256, b$content_sha256)
})

test_that("fixture scoring uses one distribution index instead of repeated full-grid scans", {
  code <- readLines(file.path(project_root, "R/evaluation/benchmark_scores.R"), warn = FALSE)
  expect_true(any(grepl("distribution_index <- split", code, fixed = TRUE)))
  expect_false(any(grepl(
    "distributions$score_distribution_id == prediction$score_distribution_id",
    code, fixed = TRUE
  )))
})

test_that("WC2026 labels are rejected before the runner invokes an adapter", {
  called <- 0L
  adapter <- function(...) { called <<- called + 1L; stop("adapter should not run") }
  history <- data.frame(
    edition_id = "wc2026", fixture_id = "wc2026_001",
    actual_completion_date = as.Date("2026-06-11"), home_score = 2L, away_score = 0L
  )
  expect_error(
    run_rolling_tournament_benchmark(
      history = history, adapter_runner = adapter,
      registry_dir = file.path(project_root, "data/benchmark/phase09"),
      output_dir = tempfile("sealed-")
    ),
    "wc2026|sealed"
  )
  expect_identical(called, 0L)
})

test_that("runner and sourced benchmark modules contain no network or refresh calls", {
  files <- c(
    "R/benchmark/runner.R", "R/benchmark/registry.R", "R/benchmark/cutoffs.R",
    "R/benchmark/weights.R", "R/benchmark/contracts.R", "R/benchmark/baselines.R",
    "R/forecast/tournament_formats.R", "R/evaluation/benchmark_scores.R",
    "R/evaluation/promotion.R"
  )
  code <- paste(unlist(lapply(file.path(project_root, files), readLines, warn = FALSE)), collapse = "\n")
  forbidden <- c("httr::", "httr2::", "curl::", "download.file", "url(", "socketConnection", "scrape", "refresh")
  expect_false(any(vapply(forbidden, grepl, logical(1), x = code, fixed = TRUE)))
})

test_that("rich eligibility is derived from observed adapter output coverage", {
  panel <- data.frame(
    panel_id = "feature_rich", edition_id = c("wc2002", "wc2002"),
    fixture_id = c("f1", "f2"), eligible = TRUE,
    point_in_time_provenance_complete = TRUE, output_coverage_required = TRUE
  )
  predictions <- data.frame(
    model_id = "production_hybrid_nb", panel_id = "feature_rich",
    fixture_id = "f1", prediction_status = "ok"
  )
  observed <- benchmark_output_coverage(predictions, panel, "production_hybrid_nb", 0.8)
  expect_false(observed$output_coverage_complete)
  expect_false(observed$promotion_eligible)
})

test_that("runtime fixture evidence at the exclusive cutoff is imputed", {
  rows <- data.frame(
    evidence_cutoff_exclusive = as.Date("2004-06-12"), elo_diff = 25,
    elo_diff__value_present = TRUE, elo_diff__source_present = TRUE,
    elo_diff__source_date = as.Date("2004-06-12"), elo_diff__imputed = FALSE,
    elo_diff__imputation_reason = "", stringsAsFactors = FALSE
  )
  contract <- data.frame(
    feature_id = c("elo_difference_for_team", "venue_advantage_for_team"),
    stringsAsFactors = FALSE
  )
  checked <- benchmark_runner_apply_feature_cutoff(rows, contract)
  expect_equal(checked$elo_diff, 0)
  expect_false(checked$elo_diff__value_present)
  expect_false(checked$elo_diff__source_present)
  expect_true(is.na(checked$elo_diff__source_date))
  expect_true(checked$elo_diff__imputed)
  expect_identical(
    checked$elo_diff__imputation_reason,
    "not_available_before_evidence_cutoff"
  )
})

test_that("runner binds feature-level adapter evidence and rejects aggregate substitutes", {
  x <- pipeline_bundle()
  result <- benchmark_runner_feature_coverage(
    list(list(feature_coverage = x$bundle$feature_coverage)),
    x$bundle$fixture_predictions, x$models, x$feature_contract
  )
  expect_equal(nrow(result), nrow(x$bundle$feature_coverage))
  expect_setequal(unique(result$feature_coverage_id), x$bundle$fixture_predictions$feature_coverage_id)

  aggregate <- data.frame(
    model_id = x$models$model_id, panel_id = x$models$panel_id,
    edition_id = "wc2002", output_coverage_complete = TRUE,
    provenance_complete = TRUE, promotion_eligible = TRUE
  )
  expect_error(
    benchmark_runner_feature_coverage(
      list(list(feature_coverage = aggregate)), x$bundle$fixture_predictions,
      x$models, x$feature_contract
    ),
    "missing columns"
  )
})

test_that("bundle validation rejects rich contamination and denominator drift", {
  x <- pipeline_bundle()
  contaminated <- x$bundle
  bad_score <- contaminated$fixture_scores[contaminated$fixture_scores$model_id == "production_hybrid_nb", ][1, ]
  bad_score$fixture_id <- "rich_ineligible"
  contaminated$fixture_scores <- rbind(contaminated$fixture_scores, bad_score)
  expect_error(
    benchmark_runner_validate_bundle_data(
      contaminated, x$audit, x$models, x$boundaries,
      panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
    ),
    "panel|fixture|ineligible"
  )

  denominator <- x$bundle
  row <- denominator$paired_comparisons$panel_id == "feature_rich" &
    denominator$paired_comparisons$diagnostic == "headline"
  denominator$paired_comparisons$paired_fixture_count[row] <- 3L
  expect_error(
    benchmark_runner_validate_bundle_data(
      denominator, x$audit, x$models, x$boundaries,
      panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
    ),
    "denominator|paired"
  )
})

test_that("canonical feature input is a checked parent and parent drift fails", {
  additional <- benchmark_runner_additional_input_specs(
    file.path(project_root, "data/benchmark/phase09"),
    file.path(project_root, "data/processed/goal_training_features_hybrid.csv")
  )
  expect_true("goal_training_features_hybrid" %in% names(additional))
  expect_identical(
    additional$goal_training_features_hybrid$canonical_content_sha256,
    benchmark_runner_file_sha256(file.path(project_root, "data/processed/goal_training_features_hybrid.csv"))
  )
  x <- pipeline_bundle()
  out <- tempfile("benchmark-parent-drift-")
  write_rolling_benchmark_bundle(
    x$bundle, out, x$audit, x$models, x$boundaries,
    additional_inputs = additional, panel_fixtures = x$panel_fixtures,
    feature_contract = x$feature_contract
  )
  drifted <- additional
  drifted$goal_training_features_hybrid$canonical_content_sha256 <- strrep("0", 64)
  expect_error(
    validate_rolling_benchmark_bundle(
      out, x$audit, x$models, x$boundaries, drifted,
      panel_fixtures = x$panel_fixtures, feature_contract = x$feature_contract
    ),
    "parent mismatch"
  )
})

test_that("canonical runner decisions invoke the frozen evaluator exactly once per model", {
  inputs <- pipeline_promotion_sources()
  original <- evaluate_promotion
  calls <- 0L
  assign("evaluate_promotion", function(candidate, protocol) {
    calls <<- calls + 1L
    original(candidate, protocol)
  }, envir = .GlobalEnv)
  on.exit(assign("evaluate_promotion", original, envir = .GlobalEnv), add = TRUE)

  decisions <- benchmark_runner_decisions(
    inputs$comparisons, inputs$coverage, inputs$x$models,
    inputs$summaries, inputs$run_manifest, inputs$protocol
  )

  expect_identical(calls, nrow(inputs$x$models))
  expect_setequal(decisions$candidate_id, inputs$x$models$model_id)
  expect_true(all(nzchar(decisions$reason_codes[decisions$decision != "eligible_for_final_holdout"])))
  expect_true(all(c("value__core_rps_delta", "pass__core_rps_effect") %in% names(decisions)))
  code <- paste(deparse(body(benchmark_runner_decisions)), collapse = "\n")
  expect_match(code, "evaluate_promotion", fixed = TRUE)
  expect_false(grepl('decision = "retain_incumbent"', code, fixed = TRUE))
})

test_that("candidate assembly preserves source precision and optional companion facts", {
  inputs <- pipeline_promotion_sources()
  candidate <- benchmark_runner_promotion_candidate(
    "production_hybrid_nb", inputs$comparisons, inputs$coverage,
    inputs$x$models, inputs$summaries, inputs$run_manifest, inputs$protocol
  )

  expect_true(candidate$uses_optional_data)
  expect_identical(candidate$rich_panel$incumbent_id, "production_hybrid_nb")
  expect_identical(candidate$open_companion$incumbent_id, "uniform_1x2")
  expect_identical(candidate$open_companion$fixture_count, 2L)
  expect_identical(candidate$core$rps_delta, 0)
  expect_identical(candidate$core$ci_upper, 0)
  expect_identical(candidate$rich_panel$coverage_observations$edition_id, c("wc2002", "euro2004"))
  expect_true(all(candidate$rich_panel$coverage_observations$output_coverage_complete))
  expect_true(all(candidate$contracts[names(promotion_contract_reason_map())] |> unlist()))
})

test_that("promotion decisions are finalized only after matching independent passes", {
  inputs <- pipeline_promotion_sources()
  first <- inputs$x$bundle
  second <- pipeline_bundle(order_rows = TRUE)$bundle
  for (bundle_name in c("first", "second")) {
    bundle <- get(bundle_name)
    bundle$benchmark_summaries <- inputs$summaries
    bundle$run_manifest <- inputs$run_manifest
    bundle$run_manifest$reproducible <- FALSE
    bundle$promotion_decisions <- NULL
    assign(bundle_name, bundle)
  }

  finalized <- finalize_benchmark_promotion_decisions(
    first, second, inputs$coverage, inputs$coverage,
    inputs$x$models, inputs$protocol
  )
  expect_true(finalized$first$run_manifest$reproducible)
  expect_true(finalized$second$run_manifest$reproducible)
  expect_identical(
    benchmark_runner_content_sha256(finalized$first$promotion_decisions, "promotion_decisions"),
    benchmark_runner_content_sha256(finalized$second$promotion_decisions, "promotion_decisions")
  )

  second$benchmark_summaries$estimate[1] <- second$benchmark_summaries$estimate[1] + 1e-12
  expect_error(
    finalize_benchmark_promotion_decisions(
      first, second, inputs$coverage, inputs$coverage,
      inputs$x$models, inputs$protocol
    ),
    "independent passes|reproduc"
  )
})

test_that("bundle promotion validation reconstructs decisions and rejects tampering", {
  inputs <- pipeline_promotion_sources()
  bundle <- inputs$x$bundle
  bundle$benchmark_summaries <- inputs$summaries
  bundle$run_manifest <- inputs$run_manifest
  bundle$promotion_decisions <- benchmark_runner_decisions(
    bundle$paired_comparisons, inputs$coverage, inputs$x$models,
    bundle$benchmark_summaries, bundle$run_manifest, inputs$protocol
  )
  expect_true(benchmark_runner_validate_promotion_decisions(
    bundle, inputs$coverage, inputs$x$models, inputs$protocol
  ))

  for (column in c("reason_codes", "value__core_rps_delta", "pass__core_rps_effect")) {
    tampered <- bundle
    if (column == "reason_codes") tampered$promotion_decisions[[column]][1] <- "tampered_reason"
    if (column == "value__core_rps_delta") tampered$promotion_decisions[[column]][1] <- 123
    if (column == "pass__core_rps_effect") tampered$promotion_decisions[[column]][1] <- TRUE
    expect_error(
      benchmark_runner_validate_promotion_decisions(
        tampered, inputs$coverage, inputs$x$models, inputs$protocol
      ),
      "reconstruct|tamper|evaluator"
    )
  }
})

test_that("targets exposes the isolated Phase 9 benchmark dependency chain", {
  old_dir <- setwd(project_root)
  on.exit(setwd(old_dir), add = TRUE)
  manifest <- targets::tar_manifest(fields = c("name", "command"))
  expected <- c(
    "benchmark_phase09_registry_files", "benchmark_phase09_registries",
    "benchmark_phase09_boundaries", "benchmark_phase09_predictions",
    "benchmark_phase09_stage_probabilities", "benchmark_phase09_scores",
    "benchmark_phase09_comparisons", "benchmark_phase09_bundle_files"
  )
  expect_true(all(expected %in% manifest$name))

  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  expect_match(commands[["benchmark_phase09_registries"]], "benchmark_phase09_registry_files", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_boundaries"]], "benchmark_phase09_registries", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_predictions"]], "benchmark_phase09_boundaries", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_predictions"]], "hybrid_goal_training_features_file", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_predictions"]], "validate_forecast_feature_evidence", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_predictions"]], "score_support_audit", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_stage_probabilities"]], "benchmark_phase09_predictions", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_scores"]], "benchmark_phase09_predictions", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_comparisons"]], "benchmark_phase09_scores", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_comparisons"]], "feature_coverage", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_bundle_files"]], "benchmark_phase09_comparisons", fixed = TRUE)
  expect_match(commands[["benchmark_phase09_bundle_files"]], "additional_inputs", fixed = TRUE)

  phase09_code <- paste(commands[expected], collapse = "\n")
  forbidden <- c("download", "dashboard", "worldcup_2026", "httr", "curl", "refresh")
  expect_false(any(vapply(forbidden, grepl, logical(1), x = phase09_code, fixed = TRUE)))
})
