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
  keys$fixture_id <- paste(keys$edition_id, keys$track_id, sep = "__")
  keys$run_id <- "synthetic"
  keys$score_distribution_id <- paste(keys$model_id, keys$fixture_id, sep = "__")
  keys$model_manifest_id <- paste(keys$run_id, keys$model_id, keys$boundary_id, sep = "__")
  keys$feature_coverage_id <- paste(keys$run_id, keys$model_id, keys$fixture_id, sep = "__")

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
  coverage <- transform(
    unique(keys[, c("model_id", "panel_id", "edition_id")]),
    required_fixture_count = 1L, observed_fixture_count = 1L,
    output_coverage = 1, output_coverage_complete = TRUE,
    provenance_complete = TRUE, promotion_eligible = TRUE
  )
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
  comparisons <- data.frame(
    challenger_id = "uniform_1x2", incumbent_id = "uniform_1x2", panel_id = "open_core",
    track_id = "updating", metric = "rps", edition_id = c("wc2002", "euro2004"),
    delta = 0, bootstrap_lower = 0, bootstrap_upper = 0, stringsAsFactors = FALSE
  )
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
  list(bundle = bundle, models = models, boundaries = boundaries, audit = pipeline_support_audit(models, boundaries))
}

test_that("the cache-only bundle writer creates and validates every durable artifact", {
  x <- pipeline_bundle()
  out <- tempfile("benchmark-bundle-")
  result <- write_rolling_benchmark_bundle(
    x$bundle, out, score_support_audit = x$audit,
    model_registry = x$models, boundary_inventory = x$boundaries
  )
  expect_true(all(file.exists(unname(benchmark_output_paths(out)))))
  validated <- validate_rolling_benchmark_bundle(
    out, score_support_audit = x$audit, model_registry = x$models,
    boundary_inventory = x$boundaries
  )
  expect_true(validated$valid)
  expect_true(validated$score_support_audit_valid)
  expect_true(validated$registration_settings_stable)
  expect_true(validated$output_coverage_reconciled)
  expect_equal(result$artifact_count, 11L)
})

test_that("bundle validation rejects missing rows and corrupted parent hashes", {
  x <- pipeline_bundle()
  out <- tempfile("benchmark-corrupt-")
  write_rolling_benchmark_bundle(x$bundle, out, x$audit, x$models, x$boundaries)
  paths <- benchmark_output_paths(out)

  predictions <- read.csv(paths[["fixture_predictions"]], stringsAsFactors = FALSE)
  write.csv(predictions[-1, ], paths[["fixture_predictions"]], row.names = FALSE)
  expect_error(
    validate_rolling_benchmark_bundle(out, x$audit, x$models, x$boundaries),
    "checksum|prediction|missing"
  )

  out <- tempfile("benchmark-parent-")
  write_rolling_benchmark_bundle(x$bundle, out, x$audit, x$models, x$boundaries)
  bad <- x$audit
  bad$parent_hashes[1] <- strrep("0", 64)
  bad$row_hash <- benchmark_row_sha256(bad, "row_hash")
  expect_error(
    validate_rolling_benchmark_bundle(out, bad, x$models, x$boundaries),
    "parent hash"
  )
})

test_that("canonical content hashes ignore output roots, timestamps, and branch ordering", {
  first <- pipeline_bundle()
  second <- pipeline_bundle(order_rows = TRUE)
  a <- write_rolling_benchmark_bundle(first$bundle, tempfile("benchmark-a-"), first$audit, first$models, first$boundaries)
  b <- write_rolling_benchmark_bundle(second$bundle, tempfile("benchmark-b-"), second$audit, second$models, second$boundaries)
  expect_identical(a$content_sha256, b$content_sha256)
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
