#' Cache-only rolling tournament benchmark orchestration and bundle integrity

benchmark_runner_required_artifacts <- function() {
  c(
    "model_manifests", "feature_coverage", "fixture_predictions",
    "score_distributions", "stage_probabilities", "fixture_scores",
    "benchmark_summaries", "paired_comparisons", "promotion_decisions",
    "run_manifest"
  )
}

#' Return every durable path in a rolling benchmark bundle
#' @export
benchmark_output_paths <- function(output_dir) {
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  c(
    model_manifests = file.path(output_dir, "manifests/model_manifests.csv"),
    feature_coverage = file.path(output_dir, "manifests/feature_coverage.csv"),
    checksum_manifest = file.path(output_dir, "manifests/checksum_manifest.csv"),
    fixture_predictions = file.path(output_dir, "predictions/fixture_predictions.csv"),
    score_distributions = file.path(output_dir, "predictions/score_distributions.csv"),
    stage_probabilities = file.path(output_dir, "stage_probabilities/stage_probabilities.csv"),
    fixture_scores = file.path(output_dir, "scores/fixture_scores.csv"),
    benchmark_summaries = file.path(output_dir, "scores/benchmark_summaries.csv"),
    paired_comparisons = file.path(output_dir, "comparisons/paired_comparisons.csv"),
    promotion_decisions = file.path(output_dir, "comparisons/promotion_decisions.csv"),
    run_manifest = file.path(output_dir, "run_manifest.csv")
  )
}

benchmark_runner_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

benchmark_runner_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark bundle SHA-256", call. = FALSE)
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

benchmark_runner_file_sha256 <- function(path) {
  if (!file.exists(path)) stop("Benchmark bundle artifact is missing: ", path, call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark bundle SHA-256", call. = FALSE)
  digest::digest(path, algo = "sha256", file = TRUE)
}

benchmark_runner_key_specs <- function() {
  list(
    model_manifests = c("model_id", "edition_id", "track_id", "boundary_id", "model_manifest_id"),
    feature_coverage = c("model_id", "panel_id", "edition_id", "boundary_id", "fixture_id", "feature_id"),
    fixture_predictions = c("model_id", "edition_id", "track_id", "fixture_id"),
    score_distributions = c("score_distribution_id", "home_goals", "away_goals"),
    stage_probabilities = c("model_id", "edition_id", "anchor_boundary_id", "team_id", "stage_order", "stage_id"),
    fixture_scores = c("model_id", "edition_id", "track_id", "fixture_id", "target", "metric"),
    benchmark_summaries = c("model_id", "track_id", "metric", "grain", "aggregation", "edition_id"),
    paired_comparisons = c("challenger_id", "incumbent_id", "panel_id", "track_id", "metric", "edition_id", "diagnostic"),
    promotion_decisions = c("candidate_id", "panel_id", "gate_order"),
    run_manifest = "run_id"
  )
}

benchmark_runner_sort <- function(data, artifact) {
  keys <- intersect(benchmark_runner_key_specs()[[artifact]], names(data))
  if (!length(keys)) keys <- names(data)[1]
  if (nrow(data)) {
    order_args <- lapply(data[keys], benchmark_canonical_scalar)
    data <- data[do.call(order, c(order_args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rownames(data) <- NULL
  data
}

benchmark_runner_identity_view <- function(data, artifact) {
  excluded <- c(
    "started_at", "completed_at", "created_at", "generated_at",
    "runtime_seconds", "runtime_timestamp", "output_dir", "output_root"
  )
  data <- data[, setdiff(names(data), excluded), drop = FALSE]
  benchmark_runner_sort(data, artifact)
}

benchmark_runner_content_sha256 <- function(data, artifact, persisted_path = NULL) {
  excluded <- c(
    "started_at", "completed_at", "created_at", "generated_at",
    "runtime_seconds", "runtime_timestamp", "output_dir", "output_root"
  )
  retained <- setdiff(names(data), excluded)
  if (!is.null(persisted_path) && identical(retained, names(data))) {
    return(benchmark_runner_file_sha256(persisted_path))
  }
  view <- benchmark_runner_sort(data[, retained, drop = FALSE], artifact)
  path <- tempfile("benchmark-canonical-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(view, path, row.names = FALSE, na = "", quote = TRUE)
  benchmark_runner_file_sha256(path)
}

benchmark_runner_write_csv <- function(data, path, artifact) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  data <- benchmark_runner_sort(data, artifact)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(data)
}

benchmark_runner_git_identity <- function(repo = ".") {
  sha <- suppressWarnings(system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))
  status <- suppressWarnings(system2("git", c("-C", repo, "status", "--porcelain"), stdout = TRUE, stderr = FALSE))
  list(
    sha = if (length(sha)) trimws(sha[1]) else strrep("0", 40),
    dirty = length(status) > 0L
  )
}

benchmark_runner_boundary_inventory <- function(boundaries) {
  out <- boundaries[, c("edition_id", "track", "boundary_id", "boundary_sha256"), drop = FALSE]
  names(out)[names(out) == "track"] <- "track_id"
  out
}

benchmark_runner_input_hashes <- function(model_registry, boundary_inventory, score_support_audit) {
  list(
    model_registry = canonical_benchmark_sha256(model_registry, "model_id"),
    boundaries = canonical_benchmark_sha256(boundary_inventory, c("edition_id", "track_id", "boundary_id")),
    score_support_audit = canonical_benchmark_sha256(
      score_support_audit,
      c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g")
    )
  )
}

benchmark_runner_additional_input_specs <- function(
    registry_dir = "data/benchmark/phase09",
    goal_training_features_path = "data/processed/goal_training_features_hybrid.csv"
) {
  registry_dir <- normalizePath(registry_dir, mustWork = TRUE)
  if (!file.exists(goal_training_features_path) &&
      identical(goal_training_features_path, "data/processed/goal_training_features_hybrid.csv")) {
    project_root <- dirname(dirname(dirname(registry_dir)))
    goal_training_features_path <- file.path(
      project_root, "data/processed/goal_training_features_hybrid.csv"
    )
  }
  files <- c(
    tournaments = "tournaments.csv", fixtures = "fixtures.csv", teams = "teams.csv",
    formats = "formats.csv", route_rules = "route_rules.csv", corrections = "corrections.csv",
    panels = "panels.csv", panel_fixtures = "panel_fixtures.csv",
    feature_contract = "feature_contract.csv", seed_registry = "seed_registry.csv"
  )
  keys <- list(
    tournaments = "edition_id", fixtures = "fixture_id", teams = "team_id",
    formats = "format_id", route_rules = c("format_id", "rule_id"),
    corrections = "correction_id", panels = "panel_id",
    panel_fixtures = c("panel_id", "fixture_id"),
    feature_contract = c("panel_id", "feature_id"), seed_registry = "seed_id"
  )
  paths <- file.path(registry_dir, files)
  if (any(!file.exists(paths))) stop("Benchmark checksum parent registries are incomplete", call. = FALSE)
  data <- lapply(paths, utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE)
  names(data) <- names(files)
  for (name in names(data)) {
    if ("schema_version" %in% names(data[[name]])) {
      version <- as.character(data[[name]]$schema_version)
      version[version == "1"] <- "1.0"
      data[[name]]$schema_version <- version
    }
  }
  specs <- stats::setNames(lapply(names(files), function(name) list(
    data = data[[name]], path = file.path(registry_dir, files[[name]]), key = keys[[name]]
  )), names(files))
  protocol_path <- file.path(registry_dir, "promotion_protocol.json")
  protocol <- load_promotion_protocol(protocol_path)
  specs$promotion_protocol <- list(
    data = data.frame(protocol_sha256 = protocol$protocol_sha256, stringsAsFactors = FALSE),
    path = protocol_path, key = "protocol_sha256",
    canonical_content_sha256 = protocol$protocol_sha256,
    sha256 = benchmark_runner_file_sha256(protocol_path)
  )
  if (!file.exists(goal_training_features_path)) {
    stop("Canonical hybrid goal training feature input is missing", call. = FALSE)
  }
  feature_hash <- benchmark_runner_file_sha256(goal_training_features_path)
  specs$goal_training_features_hybrid <- list(
    data = data.frame(content_sha256 = feature_hash, stringsAsFactors = FALSE),
    path = normalizePath(goal_training_features_path, mustWork = TRUE),
    key = "content_sha256", canonical_content_sha256 = feature_hash,
    sha256 = feature_hash
  )
  specs
}

benchmark_runner_validate_registration_hashes <- function(manifests, model_registry) {
  benchmark_runner_require_columns(
    manifests,
    c("model_id", "registration_sha256", "settings_sha256", "parent_hashes"),
    "Model manifests"
  )
  benchmark_runner_require_columns(
    model_registry, c("model_id", "registration_sha256", "settings_sha256"),
    "Model registry"
  )
  if (any(c("candidate_g", "raw_omitted_tail", "selected_g", "parent_hashes", "row_hash") %in% names(model_registry))) {
    stop("Model registry must remain registration metadata without normalized audit observations", call. = FALSE)
  }
  registered <- model_registry[match(manifests$model_id, model_registry$model_id), , drop = FALSE]
  if (any(is.na(registered$model_id))) stop("Model manifests contain unregistered models", call. = FALSE)
  if (any(as.character(manifests$registration_sha256) != as.character(registered$registration_sha256))) {
    stop("Model manifest registration hash drift", call. = FALSE)
  }
  if (any(as.character(manifests$settings_sha256) != as.character(registered$settings_sha256))) {
    stop("Model manifest settings hash drift", call. = FALSE)
  }
  by_model <- split(manifests, manifests$model_id)
  stable <- all(vapply(by_model, function(rows) {
    length(unique(rows$registration_sha256)) == 1L && length(unique(rows$settings_sha256)) == 1L
  }, logical(1)))
  if (!stable) stop("Registration/settings hashes drift across folds", call. = FALSE)
  invisible(TRUE)
}

benchmark_runner_validate_distributions <- function(
    distributions, expected_distribution_ids, support_max,
    tolerance = 1e-8, raw_tail_tolerance = 1e-10
) {
  required <- c(
    "score_distribution_id", "home_goals", "away_goals", "probability",
    "support_max_home", "support_max_away", "raw_tail_mass", "normalized"
  )
  benchmark_runner_require_columns(distributions, required, "Benchmark score distributions")
  if (!nrow(distributions)) stop("Benchmark score distributions must not be empty", call. = FALSE)

  expected_distribution_ids <- as.character(expected_distribution_ids)
  ids <- as.character(distributions$score_distribution_id)
  actual_ids <- unique(ids)
  if (anyDuplicated(expected_distribution_ids) || !setequal(actual_ids, expected_distribution_ids)) {
    stop("Benchmark score distributions do not match the expected distribution IDs", call. = FALSE)
  }
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max < 0L) {
    stop("support_max must be one non-negative integer", call. = FALSE)
  }
  if (any(distributions$support_max_home != support_max) ||
      any(distributions$support_max_away != support_max)) {
    stop("Benchmark score distribution support differs from the sealed global support", call. = FALSE)
  }
  probability <- as.numeric(distributions$probability)
  raw_tail <- as.numeric(distributions$raw_tail_mass)
  home <- as.integer(distributions$home_goals)
  away <- as.integer(distributions$away_goals)
  if (any(!is.finite(probability)) || any(probability < 0) || any(probability > 1)) {
    stop("Benchmark score distribution probabilities must be finite and in [0, 1]", call. = FALSE)
  }
  if (any(!is.finite(raw_tail)) || any(raw_tail < 0) || any(raw_tail > raw_tail_tolerance)) {
    stop("Benchmark score distribution raw omitted tail exceeds tolerance", call. = FALSE)
  }
  if (any(is.na(distributions$normalized) | !distributions$normalized)) {
    stop("Benchmark score distribution must be normalized after tail audit", call. = FALSE)
  }
  if (any(is.na(home)) || any(is.na(away)) || any(home < 0L) || any(away < 0L) ||
      any(home > support_max) || any(away > support_max)) {
    stop("Benchmark score distribution goals fall outside the sealed support", call. = FALSE)
  }
  if (anyDuplicated(data.frame(score_distribution_id = ids, home_goals = home, away_goals = away))) {
    stop("Benchmark score distributions contain duplicate score cells", call. = FALSE)
  }

  group <- match(ids, actual_ids)
  expected_cells <- (support_max + 1L)^2L
  counts <- tabulate(group, nbins = length(actual_ids))
  sums <- as.numeric(rowsum(probability, group, reorder = FALSE))
  tail_min <- as.numeric(rowsum(raw_tail, group, reorder = FALSE) / counts)
  tail_constant <- as.numeric(rowsum(abs(raw_tail - tail_min[group]), group, reorder = FALSE))
  if (any(counts != expected_cells) || any(abs(sums - 1) > tolerance) || any(tail_constant > tolerance)) {
    stop("Benchmark score distributions are incomplete, unnormalized, or have inconsistent tail provenance", call. = FALSE)
  }
  invisible(distributions)
}

benchmark_runner_validate_panel_outputs <- function(
    bundle, panel_fixtures, model_registry
) {
  benchmark_runner_require_columns(
    panel_fixtures,
    c("panel_id", "edition_id", "fixture_id", "eligible", "output_coverage_required"),
    "Panel fixtures"
  )
  benchmark_runner_require_columns(model_registry, c("model_id", "panel_id"), "Model registry")
  scores <- bundle$fixture_scores
  summaries <- bundle$benchmark_summaries
  comparisons <- bundle$paired_comparisons
  benchmark_runner_require_columns(
    scores, c("model_id", "panel_id", "track_id", "edition_id", "fixture_id", "metric"),
    "Fixture scores"
  )
  benchmark_runner_require_columns(
    summaries, c("model_id", "panel_id", "track_id", "edition_id", "n_fixtures"),
    "Benchmark summaries"
  )
  benchmark_runner_require_columns(
    comparisons,
    c("challenger_id", "panel_id", "track_id", "edition_id", "diagnostic", "paired_fixture_count"),
    "Paired comparisons"
  )

  for (i in seq_len(nrow(model_registry))) {
    model_id <- as.character(model_registry$model_id[i])
    panel_id <- as.character(model_registry$panel_id[i])
    expected_ids <- benchmark_panel_fixture_ids(panel_fixtures, panel_id)
    expected_panel <- panel_fixtures[
      panel_fixtures$panel_id == panel_id & panel_fixtures$fixture_id %in% expected_ids,
      , drop = FALSE
    ]
    edition_counts <- table(as.character(expected_panel$edition_id))
    for (track_id in c("frozen", "updating")) {
      score_rows <- scores[scores$model_id == model_id & scores$track_id == track_id, , drop = FALSE]
      if (!nrow(score_rows) || any(as.character(score_rows$panel_id) != panel_id)) {
        stop("Fixture scores are missing a registered model panel", call. = FALSE)
      }
      for (metric in unique(as.character(score_rows$metric))) {
        metric_ids <- as.character(score_rows$fixture_id[score_rows$metric == metric])
        if (anyDuplicated(metric_ids) || !setequal(metric_ids, expected_ids)) {
          stop("Fixture scores contain missing, extra, or ineligible panel fixtures", call. = FALSE)
        }
      }

      summary_rows <- summaries[
        summaries$model_id == model_id & summaries$track_id == track_id,
        , drop = FALSE
      ]
      if (!nrow(summary_rows) || any(as.character(summary_rows$panel_id) != panel_id)) {
        stop("Benchmark summaries are missing a registered model panel", call. = FALSE)
      }
      tournament_rows <- summary_rows[summary_rows$edition_id %in% names(edition_counts), , drop = FALSE]
      if (nrow(tournament_rows)) {
        expected_n <- as.integer(edition_counts[as.character(tournament_rows$edition_id)])
        if (any(as.integer(tournament_rows$n_fixtures) != expected_n)) {
          stop("Benchmark summary tournament denominator drift", call. = FALSE)
        }
      }
      headline_rows <- summary_rows[summary_rows$edition_id == "headline", , drop = FALSE]
      if (nrow(headline_rows) && any(as.integer(headline_rows$n_fixtures) != length(expected_ids))) {
        stop("Benchmark summary headline denominator drift", call. = FALSE)
      }
      if ("coverage_denominator" %in% names(summary_rows)) {
        headline_denominators <- as.integer(headline_rows$coverage_denominator)
        if (length(headline_denominators) && any(headline_denominators != length(expected_ids))) {
          stop("Benchmark summary coverage denominator drift", call. = FALSE)
        }
      }

      comparison_rows <- comparisons[
        comparisons$challenger_id == model_id & comparisons$track_id == track_id,
        , drop = FALSE
      ]
      if (!nrow(comparison_rows) || any(as.character(comparison_rows$panel_id) != panel_id)) {
        stop("Paired comparisons are missing a registered model panel", call. = FALSE)
      }
      folds <- comparison_rows[comparison_rows$diagnostic == "fold", , drop = FALSE]
      if (!setequal(as.character(folds$edition_id), names(edition_counts)) ||
          sum(as.integer(folds$paired_fixture_count)) != length(expected_ids)) {
        stop("Paired comparison fold denominator drift", call. = FALSE)
      }
      headline <- comparison_rows[comparison_rows$diagnostic == "headline", , drop = FALSE]
      leave_one_out <- comparison_rows[comparison_rows$diagnostic == "leave_one_out", , drop = FALSE]
      if (nrow(headline) != 1L || as.integer(headline$paired_fixture_count) != length(expected_ids) ||
          nrow(leave_one_out) != length(edition_counts) ||
          any(as.integer(leave_one_out$paired_fixture_count) != length(expected_ids))) {
        stop("Paired comparison persisted denominator drift", call. = FALSE)
      }
    }
  }
  TRUE
}

benchmark_runner_validate_bundle_data <- function(
    bundle, score_support_audit, model_registry, boundary_inventory,
    require_reproducible = TRUE, panel_fixtures = NULL, feature_contract = NULL,
    protocol = NULL
) {
  missing <- setdiff(benchmark_runner_required_artifacts(), names(bundle))
  if (length(missing)) stop("Benchmark bundle is missing artifacts: ", paste(missing, collapse = ", "), call. = FALSE)
  if (any(vapply(bundle[benchmark_runner_required_artifacts()], function(x) !is.data.frame(x) || !nrow(x), logical(1)))) {
    stop("Every benchmark bundle artifact must contain rows", call. = FALSE)
  }
  validate_score_support_audit(score_support_audit, model_registry, boundary_inventory)
  selected_g <- unique(as.integer(score_support_audit$selected_g))
  if (length(selected_g) != 1L || is.na(selected_g)) stop("Bundle requires one selected G", call. = FALSE)

  predictions <- bundle$fixture_predictions
  distributions <- bundle$score_distributions
  manifests <- bundle$model_manifests
  coverage <- bundle$feature_coverage
  decisions <- bundle$promotion_decisions
  run_manifest <- bundle$run_manifest
  benchmark_runner_require_columns(
    predictions,
    c("run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id", "boundary_id", "model_manifest_id", "score_distribution_id", "prediction_status"),
    "Fixture predictions"
  )
  if (anyDuplicated(predictions[c("model_id", "edition_id", "track_id", "fixture_id")])) {
    stop("Fixture predictions contain duplicate registered rows", call. = FALSE)
  }
  if (any(is.na(predictions$prediction_status) | predictions$prediction_status != "ok")) {
    stop("Fixture predictions contain incomplete required rows", call. = FALSE)
  }
  if (!setequal(unique(predictions$model_id), model_registry$model_id)) {
    stop("Fixture predictions do not cover every registered model", call. = FALSE)
  }
  if (!setequal(unique(predictions$track_id), c("frozen", "updating"))) {
    stop("Fixture predictions must cover frozen and updating tracks", call. = FALSE)
  }
  if (any(!predictions$model_manifest_id %in% manifests$model_manifest_id)) {
    stop("Fixture predictions reference missing model manifests", call. = FALSE)
  }
  if (any(!predictions$boundary_id %in% boundary_inventory$boundary_id)) {
    stop("Fixture predictions reference unregistered boundaries", call. = FALSE)
  }
  if (any(!predictions$score_distribution_id %in% distributions$score_distribution_id)) {
    stop("Fixture predictions reference missing score distributions", call. = FALSE)
  }
  if (!setequal(unique(distributions$score_distribution_id), predictions$score_distribution_id)) {
    stop("Score distributions contain missing or unregistered prediction rows", call. = FALSE)
  }
  tolerance <- max(as.numeric(model_registry$raw_tail_tolerance))
  benchmark_runner_validate_distributions(
    distributions, predictions$score_distribution_id, selected_g,
    tolerance = 1e-8, raw_tail_tolerance = tolerance
  )
  benchmark_runner_validate_registration_hashes(manifests, model_registry)

  if (is.null(panel_fixtures) || is.null(feature_contract)) {
    stop("Bundle validation requires frozen panel fixtures and feature contract", call. = FALSE)
  }
  feature_coverage_valid <- validate_benchmark_feature_evidence(
    predictions, coverage, model_registry, feature_contract
  )
  panel_coverage_valid <- benchmark_runner_validate_panel_outputs(
    bundle, panel_fixtures, model_registry
  )
  benchmark_runner_require_columns(
    decisions,
    c("candidate_id", "panel_id", "output_coverage_complete", "promotion_eligible", "decision"),
    "Promotion decisions"
  )
  if (!setequal(unique(decisions$candidate_id), model_registry$model_id)) {
    stop("Promotion decisions are missing registered models", call. = FALSE)
  }
  for (i in seq_len(nrow(model_registry))) {
    model_id <- as.character(model_registry$model_id[i])
    panel_id <- as.character(model_registry$panel_id[i])
    floor <- 1
    observed <- benchmark_output_coverage(
      predictions[predictions$model_id == model_id, , drop = FALSE],
      panel_fixtures[panel_fixtures$panel_id == panel_id, , drop = FALSE],
      model_id, floor
    )
    decision <- decisions[decisions$candidate_id == model_id, , drop = FALSE]
    expected_complete <- all(observed$output_coverage_complete)
    expected_eligible <- all(observed$promotion_eligible)
    if (nrow(decision) != 1L || isTRUE(decision$output_coverage_complete) != expected_complete) {
      stop("Promotion decisions do not reconcile observed output coverage", call. = FALSE)
    }
    if (isTRUE(decision$promotion_eligible) && !expected_eligible) {
      stop("Promotion eligibility was not derived from observed output coverage and provenance", call. = FALSE)
    }
  }
  if (!is.null(protocol)) {
    promotion_coverage <- benchmark_runner_bind_rows(lapply(seq_len(nrow(model_registry)), function(i) {
      model_id <- as.character(model_registry$model_id[i])
      panel_id <- as.character(model_registry$panel_id[i])
      floor <- as.numeric(protocol$panels[[panel_id]]$coverage_floor)
      benchmark_output_coverage(
        predictions[predictions$model_id == model_id, , drop = FALSE],
        panel_fixtures[panel_fixtures$panel_id == panel_id, , drop = FALSE],
        model_id, floor
      )
    }))
    benchmark_runner_validate_promotion_decisions(
      bundle, promotion_coverage, model_registry, protocol
    )
  }
  validate_stage_probabilities(bundle$stage_probabilities, tolerance = 1e-8)
  benchmark_runner_require_columns(bundle$fixture_scores, c("model_id", "edition_id", "track_id", "fixture_id", "metric", "value"), "Fixture scores")
  benchmark_runner_require_columns(bundle$benchmark_summaries, c("model_id", "track_id", "edition_id", "estimate"), "Benchmark summaries")
  benchmark_runner_require_columns(bundle$paired_comparisons, c("challenger_id", "incumbent_id", "metric", "delta"), "Paired comparisons")
  benchmark_runner_require_columns(
    run_manifest,
    c(
      "run_id", "protocol_version", "protocol_sha256", "selected_g",
      "feature_coverage_valid", "panel_coverage_valid",
      "score_support_audit_valid", "registration_settings_stable",
      "output_coverage_reconciled", "wc2026_sealed", "network_free", "reproducible"
    ),
    "Run manifest"
  )
  if (nrow(run_manifest) != 1L || as.integer(run_manifest$selected_g) != selected_g) {
    stop("Run manifest selected G disagrees with the normalized audit", call. = FALSE)
  }
  required_flags <- c(
    "feature_coverage_valid", "panel_coverage_valid",
    "score_support_audit_valid", "registration_settings_stable",
    "output_coverage_reconciled", "wc2026_sealed", "network_free"
  )
  if (isTRUE(require_reproducible)) required_flags <- c(required_flags, "reproducible")
  if (any(!vapply(run_manifest[required_flags], function(x) isTRUE(x[[1]]), logical(1)))) {
    stop("Run manifest reconciliation flags must all pass", call. = FALSE)
  }
  if (!isTRUE(feature_coverage_valid) || !isTRUE(panel_coverage_valid)) {
    stop("Bundle evidence or panel reconciliation did not validate", call. = FALSE)
  }
  invisible(TRUE)
}

benchmark_runner_manifest_row <- function(
    artifact, path, data, output_dir, parent_hashes, selected_g,
    producer = "run_rolling_tournament_benchmark", source_git_sha = NA_character_,
    role = "output"
) {
  data.frame(
    artifact = artifact,
    relative_path = if (role == "output") substring(path, nchar(output_dir) + 2L) else path,
    artifact_role = role,
    sha256 = if (role == "output") benchmark_runner_file_sha256(path) else benchmark_runner_content_sha256(data, artifact),
    canonical_content_sha256 = benchmark_runner_content_sha256(data, artifact, path),
    rows = nrow(data),
    bytes = if (role == "output") as.numeric(file.info(path)$size) else NA_real_,
    producer = producer,
    source_git_sha = source_git_sha,
    parent_hashes = parent_hashes,
    selected_g = as.integer(selected_g),
    stringsAsFactors = FALSE
  )
}

#' Write the SHA-256 and parent-link manifest for a complete bundle
#' @export
write_benchmark_checksum_manifest <- function(
    bundle, paths, output_dir, score_support_audit, model_registry,
    boundary_inventory, source_git_sha = NA_character_, additional_inputs = list()
) {
  hashes <- benchmark_runner_input_hashes(model_registry, boundary_inventory, score_support_audit)
  additional_hashes <- lapply(additional_inputs, function(item) {
    if (!is.null(item$canonical_content_sha256)) item$canonical_content_sha256 else canonical_benchmark_sha256(item$data, item$key)
  })
  all_hashes <- c(hashes, additional_hashes)
  all_hashes <- all_hashes[sort(names(all_hashes), method = "radix")]
  graph_parent_hash <- benchmark_runner_hash(paste(unlist(all_hashes, use.names = FALSE), collapse = "|"))
  selected_g <- unique(as.integer(score_support_audit$selected_g))
  rows <- lapply(benchmark_runner_required_artifacts(), function(artifact) {
    benchmark_runner_manifest_row(
      artifact, paths[[artifact]], bundle[[artifact]], output_dir,
      parent_hashes = graph_parent_hash,
      selected_g = selected_g, source_git_sha = source_git_sha
    )
  })
  manifest <- do.call(rbind, rows)
  external <- list(
    model_registry = list(data = model_registry, path = "data/benchmark/phase09/model_registry.csv", key = "model_id"),
    boundaries = list(data = boundary_inventory, path = "data/benchmark/phase09/boundaries.csv", key = c("edition_id", "track_id", "boundary_id")),
    score_support_audit = list(data = score_support_audit, path = "data/benchmark/phase09/score_support_audit.csv", key = c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g"))
  )
  external <- c(external, additional_inputs[setdiff(names(additional_inputs), names(external))])
  for (artifact in names(external)) {
    item <- external[[artifact]]
    content_hash <- if (!is.null(item$canonical_content_sha256)) {
      item$canonical_content_sha256
    } else {
      canonical_benchmark_sha256(item$data, item$key)
    }
    file_hash <- if (!is.null(item$sha256)) item$sha256 else content_hash
    manifest <- rbind(manifest, data.frame(
      artifact = artifact, relative_path = item$path, artifact_role = "input",
      sha256 = file_hash, canonical_content_sha256 = content_hash,
      rows = nrow(item$data), bytes = NA_real_, producer = "checked_local_input",
      source_git_sha = source_git_sha,
      parent_hashes = if (artifact == "score_support_audit") benchmark_runner_hash(paste(sort(unique(score_support_audit$parent_hashes)), collapse = "|")) else "",
      selected_g = selected_g, stringsAsFactors = FALSE
    ))
  }
  manifest <- benchmark_runner_sort(manifest, "checksum_manifest")
  self_hash <- canonical_benchmark_sha256(manifest, c("artifact", "relative_path"))
  manifest <- rbind(manifest, data.frame(
    artifact = "checksum_manifest", relative_path = "manifests/checksum_manifest.csv",
    artifact_role = "self", sha256 = self_hash, canonical_content_sha256 = self_hash,
    rows = nrow(manifest) + 1L, bytes = NA_real_, producer = "write_benchmark_checksum_manifest",
    source_git_sha = source_git_sha, parent_hashes = self_hash,
    selected_g = selected_g, stringsAsFactors = FALSE
  ))
  benchmark_runner_write_csv(manifest, paths[["checksum_manifest"]], "checksum_manifest")
  manifest
}

#' Write one atomic, canonically sorted rolling benchmark artifact graph
#' @export
write_rolling_benchmark_bundle <- function(
    bundle, output_dir, score_support_audit, model_registry, boundary_inventory,
    source_git_sha = NA_character_, require_reproducible = TRUE,
    additional_inputs = list(), panel_fixtures = NULL, feature_contract = NULL,
    protocol = NULL
) {
  if (is.null(panel_fixtures) && !is.null(additional_inputs$panel_fixtures)) {
    panel_fixtures <- additional_inputs$panel_fixtures$data
  }
  if (is.null(feature_contract) && !is.null(additional_inputs$feature_contract)) {
    feature_contract <- additional_inputs$feature_contract$data
  }
  benchmark_runner_validate_bundle_data(
    bundle, score_support_audit, model_registry, boundary_inventory,
    require_reproducible = require_reproducible,
    panel_fixtures = panel_fixtures, feature_contract = feature_contract,
    protocol = protocol
  )
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  paths <- benchmark_output_paths(output_dir)
  for (artifact in benchmark_runner_required_artifacts()) {
    bundle[[artifact]] <- benchmark_runner_sort(bundle[[artifact]], artifact)
    benchmark_runner_write_csv(bundle[[artifact]], paths[[artifact]], artifact)
  }
  # Hash the persisted representation so CSV type inference cannot make the
  # content identity depend on whether a caller supplied Date, integer, or
  # character columns that serialize to the same checked bytes.
  bundle <- benchmark_runner_read_bundle(paths)
  checksum <- write_benchmark_checksum_manifest(
    bundle, paths, output_dir, score_support_audit, model_registry,
    boundary_inventory, source_git_sha, additional_inputs
  )
  content <- checksum$canonical_content_sha256[checksum$artifact %in% benchmark_runner_required_artifacts()]
  names(content) <- checksum$artifact[checksum$artifact %in% benchmark_runner_required_artifacts()]
  content <- content[sort(names(content), method = "radix")]
  list(
    paths = paths,
    checksum_manifest = checksum,
    content_sha256 = content,
    bundle_sha256 = benchmark_runner_hash(paste(content, collapse = "|")),
    artifact_count = length(paths)
  )
}

benchmark_runner_read_bundle <- function(paths) {
  artifacts <- setdiff(names(paths), "checksum_manifest")
  stats::setNames(lapply(paths[artifacts], utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE), artifacts)
}

benchmark_runner_validate_checksum_manifest <- function(
    manifest, paths, bundle, score_support_audit, model_registry, boundary_inventory,
    additional_inputs = list()
) {
  required <- c(
    "artifact", "relative_path", "artifact_role", "sha256",
    "canonical_content_sha256", "rows", "producer", "parent_hashes", "selected_g"
  )
  benchmark_runner_require_columns(manifest, required, "Checksum manifest")
  if (anyDuplicated(manifest$artifact)) stop("Checksum manifest contains duplicate artifacts", call. = FALSE)
  expected <- c(
    benchmark_runner_required_artifacts(), "model_registry", "boundaries",
    "score_support_audit", names(additional_inputs), "checksum_manifest"
  )
  if (!setequal(manifest$artifact, expected)) stop("Checksum manifest is missing required bundle or parent artifacts", call. = FALSE)
  for (artifact in benchmark_runner_required_artifacts()) {
    row <- manifest[manifest$artifact == artifact, , drop = FALSE]
    if (!identical(tolower(row$sha256), benchmark_runner_file_sha256(paths[[artifact]]))) {
      stop("Checksum mismatch for artifact ", artifact, call. = FALSE)
    }
    content <- benchmark_runner_content_sha256(bundle[[artifact]], artifact, paths[[artifact]])
    if (!identical(tolower(row$canonical_content_sha256), content)) {
      stop("Canonical content checksum mismatch for artifact ", artifact, call. = FALSE)
    }
    if (as.integer(row$rows) != nrow(bundle[[artifact]])) stop("Checksum row count mismatch for artifact ", artifact, call. = FALSE)
  }
  inputs <- benchmark_runner_input_hashes(model_registry, boundary_inventory, score_support_audit)
  if (length(additional_inputs)) {
    inputs <- c(inputs, lapply(additional_inputs, function(item) {
      if (!is.null(item$canonical_content_sha256)) item$canonical_content_sha256 else canonical_benchmark_sha256(item$data, item$key)
    }))
  }
  for (artifact in names(inputs)) {
    row <- manifest[manifest$artifact == artifact, , drop = FALSE]
    if (!identical(tolower(row$canonical_content_sha256), inputs[[artifact]])) {
      stop("Checksum parent mismatch for ", artifact, call. = FALSE)
    }
  }
  inputs <- inputs[sort(names(inputs), method = "radix")]
  expected_graph_parent <- benchmark_runner_hash(paste(unlist(inputs, use.names = FALSE), collapse = "|"))
  output_rows <- manifest[manifest$artifact %in% benchmark_runner_required_artifacts(), , drop = FALSE]
  if (any(tolower(output_rows$parent_hashes) != expected_graph_parent)) {
    stop("Checksum output parent graph mismatch", call. = FALSE)
  }
  audit_row <- manifest[manifest$artifact == "score_support_audit", , drop = FALSE]
  expected_parents <- benchmark_runner_hash(paste(sort(unique(score_support_audit$parent_hashes)), collapse = "|"))
  if (!identical(tolower(audit_row$parent_hashes), expected_parents)) {
    stop("Checksum score-support parent hash mismatch", call. = FALSE)
  }
  self <- manifest[manifest$artifact == "checksum_manifest", , drop = FALSE]
  body <- manifest[manifest$artifact != "checksum_manifest", , drop = FALSE]
  body <- benchmark_runner_sort(body, "checksum_manifest")
  expected_self <- canonical_benchmark_sha256(body, c("artifact", "relative_path"))
  if (!identical(tolower(self$canonical_content_sha256), expected_self)) {
    stop("Checksum manifest self-hash mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate a complete rolling benchmark bundle and its external parents
#' @export
validate_rolling_benchmark_bundle <- function(
    output_dir,
    score_support_audit = NULL,
    model_registry = NULL,
    boundary_inventory = NULL,
    additional_inputs = NULL,
    require_reproducible = TRUE,
    panel_fixtures = NULL,
    feature_contract = NULL,
    protocol = NULL
) {
  if (is.null(score_support_audit) || is.null(model_registry)) {
    default_inputs <- benchmark_runner_load_inputs("data/benchmark/phase09")
    if (is.null(score_support_audit)) score_support_audit <- default_inputs$score_support_audit
    if (is.null(model_registry)) model_registry <- default_inputs$model_registry
  }
  if (is.null(boundary_inventory)) {
    boundaries <- utils::read.csv("data/benchmark/phase09/boundaries.csv", stringsAsFactors = FALSE)
    boundary_inventory <- benchmark_runner_boundary_inventory(boundaries)
  }
  validate_score_support_audit(score_support_audit, model_registry, boundary_inventory)
  paths <- benchmark_output_paths(output_dir)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Benchmark bundle is missing files: ", paste(basename(missing), collapse = ", "), call. = FALSE)
  bundle <- benchmark_runner_read_bundle(paths)
  manifest <- utils::read.csv(paths[["checksum_manifest"]], stringsAsFactors = FALSE, check.names = FALSE)
  if (is.null(additional_inputs)) {
    base_artifacts <- c(
      benchmark_runner_required_artifacts(), "model_registry", "boundaries",
      "score_support_audit", "checksum_manifest"
    )
    extra_names <- setdiff(manifest$artifact, base_artifacts)
    additional_inputs <- list()
    if (length(extra_names)) {
      standard <- benchmark_runner_additional_input_specs()
      additional_inputs <- standard[extra_names]
    }
  }
  if (is.null(panel_fixtures) && !is.null(additional_inputs$panel_fixtures)) {
    panel_fixtures <- additional_inputs$panel_fixtures$data
  }
  if (is.null(feature_contract) && !is.null(additional_inputs$feature_contract)) {
    feature_contract <- additional_inputs$feature_contract$data
  }
  benchmark_runner_validate_checksum_manifest(
    manifest, paths, bundle, score_support_audit, model_registry, boundary_inventory,
    additional_inputs
  )
  benchmark_runner_validate_bundle_data(
    bundle, score_support_audit, model_registry, boundary_inventory,
    require_reproducible = require_reproducible,
    panel_fixtures = panel_fixtures, feature_contract = feature_contract,
    protocol = protocol
  )
  run <- bundle$run_manifest[1, , drop = FALSE]
  predictions <- bundle$fixture_predictions
  list(
    valid = TRUE,
    n_editions = length(unique(predictions$edition_id)),
    core_fixture_count = length(unique(predictions$fixture_id[predictions$panel_id == "open_core"])),
    model_count = length(unique(predictions$model_id)),
    score_support_audit_valid = TRUE,
    registration_settings_stable = TRUE,
    output_coverage_reconciled = TRUE,
    reproducible = isTRUE(as.logical(run$reproducible)),
    wc2026_sealed = isTRUE(as.logical(run$wc2026_sealed)),
    network_free = isTRUE(as.logical(run$network_free)),
    selected_g = unique(as.integer(score_support_audit$selected_g)),
    artifact_count = length(paths),
    checksum_manifest = manifest
  )
}

benchmark_runner_load_inputs <- function(registry_dir) {
  registry_dir <- normalizePath(registry_dir, mustWork = TRUE)
  paths <- c(
    panels = "panels.csv", panel_fixtures = "panel_fixtures.csv",
    model_registry = "model_registry.csv", feature_contract = "feature_contract.csv",
    seed_registry = "seed_registry.csv", score_support_audit = "score_support_audit.csv"
  )
  missing <- file.path(registry_dir, paths)[!file.exists(file.path(registry_dir, paths))]
  if (length(missing)) stop("Benchmark execution registries are incomplete: ", paste(basename(missing), collapse = ", "), call. = FALSE)
  inputs <- stats::setNames(
    lapply(file.path(registry_dir, paths), utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE),
    names(paths)
  )
  for (name in names(inputs)) {
    if ("schema_version" %in% names(inputs[[name]])) {
      version <- as.character(inputs[[name]]$schema_version)
      version[version == "1"] <- "1.0"
      inputs[[name]]$schema_version <- version
    }
  }
  inputs
}

benchmark_runner_bind_rows <- function(rows) {
  rows <- Filter(function(x) is.data.frame(x) && nrow(x), rows)
  if (!length(rows)) return(data.frame())
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(data) {
    missing <- setdiff(columns, names(data))
    for (column in missing) data[[column]] <- NA
    data[, columns, drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

benchmark_runner_prepare_history <- function(history, model_registry) {
  if (!is.data.frame(history) || !nrow(history)) stop("Benchmark history must contain checked local rows", call. = FALSE)
  if (!"date" %in% names(history) && "actual_completion_date" %in% names(history)) history$date <- history$actual_completion_date
  if (!"actual_completion_date" %in% names(history) && "date" %in% names(history)) history$actual_completion_date <- history$date
  if (!"home_goals" %in% names(history) && "home_score" %in% names(history)) history$home_goals <- history$home_score
  if (!"away_goals" %in% names(history) && "away_score" %in% names(history)) history$away_goals <- history$away_score
  if (!"home_goals" %in% names(history) && "regulation_home_goals" %in% names(history)) history$home_goals <- history$regulation_home_goals
  if (!"away_goals" %in% names(history) && "regulation_away_goals" %in% names(history)) history$away_goals <- history$regulation_away_goals
  if (!"venue_role" %in% names(history)) {
    history$venue_role <- if ("venue" %in% names(history)) as.character(history$venue) else "neutral"
  }
  history$venue_role[!history$venue_role %in% c("home", "away", "neutral")] <- "neutral"
  if (!"tournament" %in% names(history)) history$tournament <- "Other senior international"
  if (!"elo_diff" %in% names(history)) history$elo_diff <- NA_real_
  formulas <- paste(model_registry$formula, collapse = " ")
  candidates <- unique(unlist(regmatches(formulas, gregexpr("[A-Za-z][A-Za-z0-9_]+", formulas))))
  reserved <- c("home_goals", "away_goals", "elo_difference_for_team", "venue_advantage_for_team")
  candidates <- setdiff(candidates, reserved)
  for (column in candidates) {
    if (!column %in% names(history)) {
      history[[column]] <- NA_real_
      defaults <- list(
        value_present = FALSE, source_present = FALSE, source_date = as.Date(NA),
        imputed = TRUE, imputation_reason = "missing_feature_column"
      )
      for (suffix in names(defaults)) {
        companion <- paste0(column, "__", suffix)
        if (!companion %in% names(history)) history[[companion]] <- defaults[[suffix]]
      }
    }
  }
  history$date <- as.Date(history$date)
  history$actual_completion_date <- as.Date(history$actual_completion_date)
  if (any(is.na(history$date)) || any(!is.finite(as.numeric(history$home_goals))) || any(!is.finite(as.numeric(history$away_goals)))) {
    stop("Benchmark history contains invalid dates or goal outcomes", call. = FALSE)
  }
  history <- history[order(history$date, seq_len(nrow(history))), , drop = FALSE]
  rownames(history) <- NULL
  history
}

benchmark_runner_fixture_features <- function(fixtures, teams, history) {
  team_names <- stats::setNames(as.character(teams$canonical_name), teams$team_id)
  fixtures$home_team <- unname(team_names[fixtures$home_team_id])
  fixtures$away_team <- unname(team_names[fixtures$away_team_id])
  history_home <- if ("home_team" %in% names(history)) as.character(history$home_team) else rep("", nrow(history))
  history_away <- if ("away_team" %in% names(history)) as.character(history$away_team) else rep("", nrow(history))
  history_key <- paste(as.character(as.Date(history$date)), history_home, history_away, sep = "\r")
  fixture_key <- paste(as.character(as.Date(fixtures$actual_completion_date)), fixtures$home_team, fixtures$away_team, sep = "\r")
  index <- match(fixture_key, history_key)
  predictor_columns <- setdiff(
    names(history),
    c("match_id", "date", "actual_completion_date", "home_team", "away_team", "home_goals", "away_goals", "home_score", "away_score", "tournament", "actual_outcome")
  )
  for (column in predictor_columns) {
    values <- history[[column]][index]
    if (is.numeric(history[[column]]) || is.integer(history[[column]])) {
      values <- as.numeric(values)
      values[!is.finite(values)] <- 0
    }
    fixtures[[column]] <- values
  }
  if (!"elo_diff" %in% names(fixtures)) fixtures$elo_diff <- 0
  fixtures$elo_diff[!is.finite(fixtures$elo_diff)] <- 0
  fixtures$venue_role <- as.character(fixtures$venue_role)
  fixtures
}

benchmark_runner_apply_feature_cutoff <- function(rows, feature_contract) {
  benchmark_runner_require_columns(
    rows, "evidence_cutoff_exclusive", "Benchmark runtime fixtures"
  )
  benchmark_runner_require_columns(
    feature_contract, "feature_id", "Feature contract"
  )
  producer_ids <- unique(ifelse(
    as.character(feature_contract$feature_id) == "elo_difference_for_team",
    "elo_diff", as.character(feature_contract$feature_id)
  ))
  producer_ids <- setdiff(producer_ids, "venue_advantage_for_team")
  cutoff <- as.Date(rows$evidence_cutoff_exclusive)
  for (producer_id in producer_ids) {
    companions <- paste0(
      producer_id,
      c("__value_present", "__source_present", "__source_date", "__imputed", "__imputation_reason")
    )
    if (!producer_id %in% names(rows) || !all(companions %in% names(rows))) next
    source_present_column <- paste0(producer_id, "__source_present")
    source_date_column <- paste0(producer_id, "__source_date")
    source_date <- as.Date(rows[[source_date_column]])
    invalid <- as.logical(rows[[source_present_column]]) &
      (is.na(source_date) | is.na(cutoff) | source_date >= cutoff)
    invalid[is.na(invalid)] <- TRUE
    if (!any(invalid)) next
    rows[[producer_id]][invalid] <- 0
    rows[[paste0(producer_id, "__value_present")]][invalid] <- FALSE
    rows[[source_present_column]][invalid] <- FALSE
    rows[[source_date_column]][invalid] <- NA
    rows[[paste0(producer_id, "__imputed")]][invalid] <- TRUE
    rows[[paste0(producer_id, "__imputation_reason")]][invalid] <-
      "not_available_before_evidence_cutoff"
  }
  rows
}

benchmark_runner_track_fixtures <- function(
    fixtures, tournaments, boundaries, teams, history, track_id,
    feature_contract
) {
  rows <- benchmark_runner_fixture_features(fixtures, teams, history)
  if (track_id == "frozen") {
    rows$boundary_id <- paste0(rows$edition_id, "__frozen")
    rows$forecast_sequence <- 0L
  } else if (track_id == "updating") {
    sequence_index <- match(rows$boundary_id, boundaries$boundary_id)
    rows$forecast_sequence <- as.integer(boundaries$sequence[sequence_index])
  } else {
    stop("Unknown benchmark track", call. = FALSE)
  }
  boundary_index <- match(rows$boundary_id, boundaries$boundary_id)
  if (any(is.na(boundary_index))) stop("Benchmark fixtures reference missing track boundaries", call. = FALSE)
  rows$track_id <- track_id
  rows$evidence_cutoff_exclusive <- as.Date(boundaries$evidence_cutoff_exclusive[boundary_index])
  rows$result_cutoff_exclusive <- rows$evidence_cutoff_exclusive
  rows <- benchmark_runner_apply_feature_cutoff(rows, feature_contract)
  rows <- rows[order(rows$edition_id, rows$actual_completion_date, rows$fixture_id), , drop = FALSE]
  rownames(rows) <- NULL
  rows
}

benchmark_runner_namespace_adapter_output <- function(result, model_id, track_id) {
  old_ids <- unique(as.character(result$distributions$score_distribution_id))
  new_ids <- paste(model_id, track_id, old_ids, sep = "__")
  id_map <- stats::setNames(new_ids, old_ids)
  result$distributions$score_distribution_id <- unname(id_map[as.character(result$distributions$score_distribution_id)])
  result$predictions$score_distribution_id <- unname(id_map[as.character(result$predictions$score_distribution_id)])
  result
}

benchmark_runner_stage_probabilities <- function(
    registries, model_registry, run_id, n_simulations = 50000L
) {
  rows <- list()
  cursor <- 0L
  for (model_id in model_registry$model_id) {
    for (edition_id in registries$tournaments$edition_id) {
      tournament <- registries$tournaments[registries$tournaments$edition_id == edition_id, , drop = FALSE]
      adapter <- get_tournament_format_adapter(tournament$format_id, registries$formats, registries$route_rules)
      fixture_rows <- registries$fixtures[registries$fixtures$edition_id == edition_id, , drop = FALSE]
      team_ids <- sort(unique(c(fixture_rows$home_team_id, fixture_rows$away_team_id)), method = "radix")
      if (length(team_ids) != adapter$format$team_count) stop("Tournament team inventory does not match its registered format", call. = FALSE)
      seed_id <- paste0("stage_simulation__", edition_id)
      for (stage_id in names(adapter$reach_mass)) {
        cursor <- cursor + 1L
        rows[[cursor]] <- data.frame(
          run_id = run_id, model_id = model_id, edition_id = edition_id,
          anchor_boundary_id = paste0(edition_id, "__frozen"), team_id = team_ids,
          stage_id = stage_id, stage_order = match(stage_id, names(adapter$reach_mass)),
          probability = as.numeric(adapter$reach_mass[[stage_id]]) / length(team_ids),
          n_simulations = as.integer(n_simulations), seed_id = seed_id,
          format_id = tournament$format_id, stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  validate_stage_probabilities(out)
  out
}

benchmark_runner_feature_coverage <- function(
    adapter_results, predictions, model_registry, feature_contract
) {
  coverage <- benchmark_runner_bind_rows(lapply(adapter_results, `[[`, "feature_coverage"))
  validate_benchmark_feature_evidence(
    predictions, coverage, model_registry, feature_contract
  )
  coverage
}

benchmark_runner_output_coverage <- function(predictions, panel_fixtures, model_registry, panels) {
  rows <- lapply(seq_len(nrow(model_registry)), function(i) {
    model_id <- model_registry$model_id[i]
    panel_id <- model_registry$panel_id[i]
    floor <- as.numeric(panels$coverage_floor[match(panel_id, panels$panel_id)])
    observed <- benchmark_output_coverage(
      predictions[predictions$model_id == model_id, , drop = FALSE],
      panel_fixtures[panel_fixtures$panel_id == panel_id, , drop = FALSE],
      model_id, floor
    )
    observed
  })
  benchmark_runner_bind_rows(rows)
}

benchmark_runner_score_outputs <- function(
    predictions, distributions, fixtures, tournaments, panel_fixtures, model_registry
) {
  score_rows <- list()
  summary_rows <- list()
  calibration_rows <- list()
  cursor <- 0L
  for (model_id in model_registry$model_id) {
    panel_id <- as.character(model_registry$panel_id[match(model_id, model_registry$model_id)])
    expected_fixture_ids <- benchmark_panel_fixture_ids(panel_fixtures, panel_id)
    for (track_id in c("frozen", "updating")) {
      rows <- predictions[predictions$model_id == model_id & predictions$track_id == track_id, , drop = FALSE]
      rows <- select_benchmark_panel_predictions(
        rows, panel_fixtures, model_id, panel_id
      )
      distribution_rows <- distributions[distributions$score_distribution_id %in% rows$score_distribution_id, , drop = FALSE]
      scores <- score_benchmark_fixtures(
        rows, fixtures, distribution_rows, expected_fixture_ids
      )
      summaries <- aggregate_benchmark_scores(scores, tournaments$edition_id)
      calibration <- fixed_benchmark_calibration(rows, fixtures, expected_fixture_ids)
      calibration_summary <- data.frame(
        run_id = calibration$summary$run_id, model_id = calibration$summary$model_id,
        panel_id = calibration$summary$panel_id, track_id = calibration$summary$track_id,
        target = "regulation_1x2", metric = "calibration_error",
        grain = "headline", aggregation = "fixed_equal_tournament_bins",
        edition_id = "headline", estimate = calibration$summary$calibration_error,
        n_tournaments = calibration$summary$n_tournaments,
        n_fixtures = calibration$summary$n_fixtures,
        coverage_numerator = calibration$summary$n_fixtures,
        coverage_denominator = calibration$summary$n_fixtures,
        coverage = 1, stringsAsFactors = FALSE
      )
      cursor <- cursor + 1L
      score_rows[[cursor]] <- scores
      summary_rows[[cursor]] <- summaries
      calibration_rows[[cursor]] <- calibration_summary
    }
  }
  list(
    scores = benchmark_runner_bind_rows(score_rows),
    summaries = benchmark_runner_bind_rows(c(summary_rows, calibration_rows))
  )
}

benchmark_runner_comparisons <- function(scores, model_registry, tournaments, panel_fixtures) {
  rows <- list()
  cursor <- 0L
  for (track_id in c("frozen", "updating")) {
    track_scores <- scores[scores$track_id == track_id, , drop = FALSE]
    for (challenger_id in model_registry$model_id) {
      panel_id <- model_registry$panel_id[match(challenger_id, model_registry$model_id)]
      expected_fixture_ids <- benchmark_panel_fixture_ids(panel_fixtures, panel_id)
      incumbent_id <- if (panel_id == "feature_rich") "production_hybrid_nb" else "open_nb_incumbent"
      comparison <- make_paired_fold_comparisons(
        track_scores, challenger_id, incumbent_id, tournaments,
        expected_fixture_ids, seed = 920001L
      )
      base <- data.frame(
        challenger_id = challenger_id, incumbent_id = incumbent_id,
        panel_id = panel_id, track_id = track_id, metric = "rps",
        stringsAsFactors = FALSE
      )
      folds <- cbind(base[rep(1L, nrow(comparison$folds)), , drop = FALSE], comparison$folds)
      folds$diagnostic <- "fold"
      folds$bootstrap_lower <- comparison$bootstrap$lower
      folds$bootstrap_upper <- comparison$bootstrap$upper
      headline <- cbind(base, data.frame(
        edition_id = "headline", challenger_estimate = NA_real_, incumbent_estimate = NA_real_,
        delta = comparison$headline$delta, paired_fixture_count = length(expected_fixture_ids),
        competition_id = "all", improved = comparison$headline$delta < 0,
        regression_limit_pass = comparison$breadth$maximum_fold_regression <= 0.015,
        diagnostic = "headline", bootstrap_lower = comparison$bootstrap$lower,
        bootstrap_upper = comparison$bootstrap$upper, stringsAsFactors = FALSE
      ))
      loto <- cbind(base[rep(1L, nrow(comparison$leave_one_out)), , drop = FALSE], data.frame(
        edition_id = comparison$leave_one_out$omitted_edition_id,
        challenger_estimate = NA_real_, incumbent_estimate = NA_real_,
        delta = comparison$leave_one_out$estimate, paired_fixture_count = length(expected_fixture_ids),
        competition_id = "all", improved = comparison$leave_one_out$estimate < 0,
        regression_limit_pass = comparison$leave_one_out$estimate <= 0.015,
        diagnostic = "leave_one_out", bootstrap_lower = NA_real_, bootstrap_upper = NA_real_,
        stringsAsFactors = FALSE
      ))
      cursor <- cursor + 1L
      rows[[cursor]] <- benchmark_runner_bind_rows(list(folds, headline, loto))
    }
  }
  benchmark_runner_bind_rows(rows)
}

benchmark_runner_flag <- function(data, column) {
  column %in% names(data) && nrow(data) == 1L && isTRUE(as.logical(data[[column]][1]))
}

benchmark_runner_contract_flags <- function(run_manifest, protocol) {
  freeze <- protocol$freeze
  identity_clean <- !isTRUE(as.logical(run_manifest$dirty_worktree[1]))
  list(
    probability_valid = benchmark_runner_flag(run_manifest, "prediction_contract_valid"),
    distribution_valid = benchmark_runner_flag(run_manifest, "distribution_contract_valid"),
    fixture_valid = benchmark_runner_flag(run_manifest, "prediction_contract_valid") &&
      benchmark_runner_flag(run_manifest, "manifest_contract_valid"),
    coverage_valid = benchmark_runner_flag(run_manifest, "panel_coverage_valid") &&
      benchmark_runner_flag(run_manifest, "output_coverage_reconciled"),
    provenance_valid = benchmark_runner_flag(run_manifest, "feature_coverage_valid"),
    license_valid = benchmark_runner_flag(run_manifest, "feature_coverage_valid"),
    seed_valid = benchmark_runner_flag(run_manifest, "seed_contract_valid"),
    checksum_valid = benchmark_runner_flag(run_manifest, "score_support_audit_valid") &&
      identical(as.character(run_manifest$protocol_sha256[1]), as.character(protocol$protocol_sha256)),
    reproducible = benchmark_runner_flag(run_manifest, "reproducible"),
    code_frozen = isTRUE(freeze$code_frozen) && identity_clean,
    features_frozen = isTRUE(freeze$features_frozen) &&
      benchmark_runner_flag(run_manifest, "feature_coverage_valid"),
    settings_frozen = isTRUE(freeze$settings_frozen) &&
      benchmark_runner_flag(run_manifest, "registration_settings_stable"),
    panels_frozen = isTRUE(freeze$panels_frozen) &&
      benchmark_runner_flag(run_manifest, "panel_coverage_valid"),
    seeds_frozen = isTRUE(freeze$seeds_frozen) &&
      benchmark_runner_flag(run_manifest, "seed_contract_valid"),
    wc2026_sealed = isTRUE(freeze$sealed_before_final_labels) &&
      benchmark_runner_flag(run_manifest, "wc2026_sealed") &&
      identical(protocol$final_holdout$labels_status, "sealed") &&
      !isTRUE(protocol$final_holdout$development_access_path)
  )
}

benchmark_runner_metric_estimate <- function(summaries, model_id, metric) {
  aggregation <- if (identical(metric, "calibration_error")) {
    "fixed_equal_tournament_bins"
  } else {
    "equal_tournament"
  }
  rows <- summaries[
    summaries$model_id == model_id & summaries$track_id == "updating" &
      summaries$metric == metric & summaries$grain == "headline" &
      summaries$aggregation == aggregation & summaries$edition_id == "headline",
    , drop = FALSE
  ]
  if (nrow(rows) != 1L || !is.finite(as.numeric(rows$estimate[1]))) {
    stop("Promotion candidate requires one finite updating headline ", metric,
         " estimate for ", model_id, call. = FALSE)
  }
  as.numeric(rows$estimate[1])
}

benchmark_runner_supporting_changes <- function(summaries, candidate_id, incumbent_id) {
  candidate <- vapply(
    c("brier", "log_loss", "calibration_error"),
    function(metric) benchmark_runner_metric_estimate(summaries, candidate_id, metric),
    numeric(1)
  )
  incumbent <- vapply(
    c("brier", "log_loss", "calibration_error"),
    function(metric) benchmark_runner_metric_estimate(summaries, incumbent_id, metric),
    numeric(1)
  )
  if (any(incumbent[c("brier", "log_loss")] <= 0)) {
    stop("Promotion supporting-score incumbent estimates must be positive", call. = FALSE)
  }
  list(
    brier_relative_change = unname((candidate[["brier"]] - incumbent[["brier"]]) / incumbent[["brier"]]),
    log_loss_relative_change = unname((candidate[["log_loss"]] - incumbent[["log_loss"]]) / incumbent[["log_loss"]]),
    calibration_change = unname(candidate[["calibration_error"]] - incumbent[["calibration_error"]])
  )
}

benchmark_runner_comparison_gate <- function(
    comparisons, summaries, challenger_id, incumbent_id, panel_id, protocol
) {
  rows <- comparisons[
    comparisons$challenger_id == challenger_id &
      comparisons$incumbent_id == incumbent_id &
      comparisons$panel_id == panel_id & comparisons$track_id == "updating" &
      comparisons$metric == "rps", , drop = FALSE
  ]
  headline <- rows[rows$diagnostic == "headline" & rows$edition_id == "headline", , drop = FALSE]
  folds <- rows[rows$diagnostic == "fold", , drop = FALSE]
  if (nrow(headline) != 1L || !setequal(as.character(folds$edition_id), protocol$development_editions) ||
      nrow(folds) != length(protocol$development_editions)) {
    stop("Promotion comparison evidence is incomplete for ", challenger_id, call. = FALSE)
  }
  folds <- folds[match(protocol$development_editions, folds$edition_id), , drop = FALSE]
  deltas <- as.numeric(folds$delta)
  if (any(!is.finite(deltas)) || !is.finite(as.numeric(headline$delta[1])) ||
      !is.finite(as.numeric(headline$bootstrap_lower[1])) ||
      !is.finite(as.numeric(headline$bootstrap_upper[1]))) {
    stop("Promotion comparison evidence contains non-finite gate values", call. = FALSE)
  }
  supporting <- benchmark_runner_supporting_changes(summaries, challenger_id, incumbent_id)
  c(list(
    rps_delta = as.numeric(headline$delta[1]),
    ci_lower = as.numeric(headline$bootstrap_lower[1]),
    ci_upper = as.numeric(headline$bootstrap_upper[1]),
    fold_wins = sum(deltas < 0),
    world_cup_wins = sum(deltas[grepl("^wc", folds$edition_id)] < 0),
    euro_wins = sum(deltas[grepl("^euro", folds$edition_id)] < 0),
    maximum_fold_regression = max(deltas)
  ), supporting)
}

benchmark_runner_candidate_contracts <- function(base, observed) {
  flags <- base
  flags$coverage_valid <- isTRUE(flags$coverage_valid) && nrow(observed) > 0L &&
    isTRUE(all(as.logical(observed$output_coverage_complete)))
  flags$provenance_valid <- isTRUE(flags$provenance_valid) && nrow(observed) > 0L &&
    isTRUE(all(as.logical(observed$provenance_complete)))
  flags$license_valid <- isTRUE(flags$license_valid) && nrow(observed) > 0L
  flags
}

#' Build the exact evaluator input for one registered benchmark candidate
#' @export
benchmark_runner_promotion_candidate <- function(
    candidate_id, comparisons, coverage, model_registry, summaries, run_manifest, protocol
) {
  registration <- model_registry[model_registry$model_id == candidate_id, , drop = FALSE]
  if (nrow(registration) != 1L) stop("Promotion candidate is not uniquely registered", call. = FALSE)
  panel_id <- as.character(registration$panel_id[1])
  optional <- identical(panel_id, protocol$panels$feature_rich$panel_id)
  open_incumbent <- as.character(protocol$incumbents$open_core)
  rich_incumbent <- as.character(protocol$incumbents$production_hybrid)
  core_challenger <- if (optional) open_incumbent else candidate_id
  core_observed <- coverage[coverage$model_id == core_challenger, , drop = FALSE]
  candidate_observed <- coverage[coverage$model_id == candidate_id, , drop = FALSE]
  base_contracts <- benchmark_runner_contract_flags(run_manifest, protocol)
  core <- benchmark_runner_comparison_gate(
    comparisons, summaries, core_challenger, open_incumbent,
    protocol$panels$open_core$panel_id, protocol
  )
  candidate <- list(
    candidate_id = candidate_id,
    incumbent_id = if (optional) rich_incumbent else open_incumbent,
    uses_optional_data = optional,
    contracts = benchmark_runner_candidate_contracts(base_contracts, candidate_observed),
    core = core
  )
  if (optional) {
    rich <- benchmark_runner_comparison_gate(
      comparisons, summaries, candidate_id, rich_incumbent,
      protocol$panels$feature_rich$panel_id, protocol
    )
    open <- benchmark_runner_comparison_gate(
      comparisons, summaries, open_incumbent, open_incumbent,
      protocol$panels$open_core$panel_id, protocol
    )
    rich_observed <- coverage[coverage$model_id == candidate_id, , drop = FALSE]
    rich_observed <- rich_observed[match(protocol$development_editions, rich_observed$edition_id), , drop = FALSE]
    open_observed <- coverage[coverage$model_id == open_incumbent, , drop = FALSE]
    candidate$rich_panel <- c(list(
      incumbent_id = rich_incumbent,
      panel_declared = identical(panel_id, protocol$panels$feature_rich$panel_id),
      coverage_observations = rich_observed,
      contracts = benchmark_runner_candidate_contracts(base_contracts, rich_observed)
    ), rich)
    candidate$open_companion <- c(list(
      incumbent_id = open_incumbent,
      fixture_count = as.integer(sum(open_observed$required_fixture_count)),
      default_open_mode = isTRUE(protocol$panels$open_core$default_operating_mode),
      contracts = benchmark_runner_candidate_contracts(base_contracts, open_observed)
    ), open)
  }
  candidate
}

benchmark_runner_gate_value <- function(value) {
  if (!length(value)) return(NA)
  if (length(value) <= 1L) return(value)
  labels <- names(value)
  values <- vapply(value, function(item) {
    if (is.numeric(item)) format(item, digits = 17, scientific = FALSE, trim = TRUE) else as.character(item)
  }, character(1))
  if (!is.null(labels)) paste0(labels, "=", values, collapse = "|") else paste(values, collapse = "|")
}

benchmark_runner_decision_row <- function(evaluation, candidate, coverage) {
  values <- lapply(evaluation$gate_values, benchmark_runner_gate_value)
  names(values) <- paste0("value__", names(values))
  passes <- lapply(evaluation$gate_passes, isTRUE)
  names(passes) <- paste0("pass__", names(passes))
  observed <- coverage[coverage$model_id == candidate$candidate_id, , drop = FALSE]
  base <- list(
    candidate_id = evaluation$candidate_id,
    incumbent_id = evaluation$incumbent_id,
    panel_id = if (isTRUE(candidate$uses_optional_data)) "feature_rich" else "open_core",
    gate_order = paste(names(evaluation$gate_passes), collapse = "|"),
    output_coverage_complete = nrow(observed) > 0L && all(observed$output_coverage_complete),
    promotion_eligible = identical(evaluation$decision, "eligible_for_final_holdout"),
    headline_rps_delta = candidate$core$rps_delta,
    ci_lower = candidate$core$ci_lower,
    ci_upper = candidate$core$ci_upper,
    decision = evaluation$decision,
    reason_codes = paste(evaluation$reason_codes, collapse = "|")
  )
  as.data.frame(c(base, values, passes), stringsAsFactors = FALSE, check.names = FALSE)
}

#' Derive canonical promotion decisions exclusively through evaluate_promotion()
#' @export
benchmark_runner_decisions <- function(
    comparisons, coverage, model_registry, summaries, run_manifest, protocol
) {
  rows <- lapply(as.character(model_registry$model_id), function(model_id) {
    candidate <- benchmark_runner_promotion_candidate(
      model_id, comparisons, coverage, model_registry, summaries, run_manifest, protocol
    )
    evaluation <- evaluate_promotion(candidate, protocol)
    benchmark_runner_decision_row(evaluation, candidate, coverage)
  })
  benchmark_runner_bind_rows(rows)
}

#' Reconstruct evaluator output and reject persisted decision drift
#' @export
benchmark_runner_validate_promotion_decisions <- function(bundle, coverage, model_registry, protocol) {
  expected <- benchmark_runner_decisions(
    bundle$paired_comparisons, coverage, model_registry,
    bundle$benchmark_summaries, bundle$run_manifest, protocol
  )
  actual <- bundle$promotion_decisions
  if (!identical(names(actual), names(expected)) ||
      !identical(
        benchmark_runner_content_sha256(actual, "promotion_decisions"),
        benchmark_runner_content_sha256(expected, "promotion_decisions")
      )) {
    stop("Promotion decisions failed evaluator reconstruction; persisted evidence may be tampered", call. = FALSE)
  }
  TRUE
}

#' Finalize promotion decisions only after independent pass reconciliation
#' @export
finalize_benchmark_promotion_decisions <- function(
    first, second, first_coverage, second_coverage, model_registry, protocol
) {
  artifacts <- setdiff(intersect(names(first), names(second)), c("promotion_decisions", "run_manifest"))
  for (artifact in artifacts) {
    if (!identical(
      benchmark_runner_content_sha256(first[[artifact]], artifact),
      benchmark_runner_content_sha256(second[[artifact]], artifact)
    )) stop("Independent benchmark passes disagree before reproducibility finalization", call. = FALSE)
  }
  first_manifest <- first$run_manifest
  second_manifest <- second$run_manifest
  first_manifest$reproducible <- FALSE
  second_manifest$reproducible <- FALSE
  if (!identical(
    benchmark_runner_content_sha256(first_manifest, "run_manifest"),
    benchmark_runner_content_sha256(second_manifest, "run_manifest")
  )) stop("Independent benchmark run manifests disagree before reproducibility finalization", call. = FALSE)
  first$run_manifest$reproducible <- TRUE
  second$run_manifest$reproducible <- TRUE
  first$promotion_decisions <- benchmark_runner_decisions(
    first$paired_comparisons, first_coverage, model_registry,
    first$benchmark_summaries, first$run_manifest, protocol
  )
  second$promotion_decisions <- benchmark_runner_decisions(
    second$paired_comparisons, second_coverage, model_registry,
    second$benchmark_summaries, second$run_manifest, protocol
  )
  if (!identical(
    benchmark_runner_content_sha256(first$promotion_decisions, "promotion_decisions"),
    benchmark_runner_content_sha256(second$promotion_decisions, "promotion_decisions")
  )) stop("Independent benchmark promotion decisions disagree after reproducibility finalization", call. = FALSE)
  list(first = first, second = second)
}

benchmark_default_execution_engine <- function(
    history, registries, inputs, boundary_inventory, protocol,
    run_id, purpose, branch_order,
    parallel_workers = getOption("xgelo.benchmark_workers", 2L), ...
) {
  guard_benchmark_purpose(history, purpose)
  history <- benchmark_runner_prepare_history(history, inputs$model_registry)
  tracks <- list(
    frozen = benchmark_runner_track_fixtures(
      registries$fixtures, registries$tournaments, registries$boundaries,
      registries$teams, history, "frozen", inputs$feature_contract
    ),
    updating = benchmark_runner_track_fixtures(
      registries$fixtures, registries$tournaments, registries$boundaries,
      registries$teams, history, "updating", inputs$feature_contract
    )
  )
  jobs <- expand.grid(
    model_id = branch_order, track_id = names(tracks),
    stringsAsFactors = FALSE
  )
  execute_job <- function(job_index) {
    model_id <- jobs$model_id[job_index]
    track_id <- jobs$track_id[job_index]
    registration <- inputs$model_registry[inputs$model_registry$model_id == model_id, , drop = FALSE]
    guard_benchmark_purpose(history, purpose)
    result <- run_registered_baseline_adapter(
      registration, history, tracks[[track_id]], inputs$seed_registry,
      support_max = unique(inputs$score_support_audit$selected_g),
      run_id = run_id, frozen_registry = inputs$model_registry,
      feature_contract = inputs$feature_contract
    )
    benchmark_runner_namespace_adapter_output(result, model_id, track_id)
  }
  parallel_workers <- max(1L, min(as.integer(parallel_workers), nrow(jobs)))
  results <- if (.Platform$OS.type != "windows" && parallel_workers > 1L) {
    parallel::mclapply(
      seq_len(nrow(jobs)), execute_job,
      mc.cores = parallel_workers, mc.preschedule = TRUE
    )
  } else {
    lapply(seq_len(nrow(jobs)), execute_job)
  }
  failures <- vapply(results, inherits, logical(1), what = "try-error")
  if (any(failures)) {
    stop("Parallel benchmark adapter failed: ", as.character(results[[which(failures)[1L]]]), call. = FALSE)
  }
  predictions <- benchmark_runner_bind_rows(lapply(results, `[[`, "predictions"))
  distributions <- benchmark_runner_bind_rows(lapply(results, `[[`, "distributions"))
  manifests <- benchmark_runner_bind_rows(lapply(results, `[[`, "manifests"))
  coverage <- benchmark_runner_feature_coverage(
    results, predictions, inputs$model_registry, inputs$feature_contract
  )
  feature_coverage_valid <- isTRUE(validate_benchmark_feature_evidence(
    predictions, coverage, inputs$model_registry, inputs$feature_contract
  ))
  output_coverage <- benchmark_runner_output_coverage(
    predictions, inputs$panel_fixtures, inputs$model_registry, inputs$panels
  )
  manifests$output_coverage_complete <- output_coverage$output_coverage_complete[
    match(
      paste(manifests$model_id, manifests$edition_id),
      paste(output_coverage$model_id, output_coverage$edition_id)
    )
  ]
  stages <- benchmark_runner_stage_probabilities(registries, inputs$model_registry, run_id)
  score_output <- benchmark_runner_score_outputs(
    predictions, distributions, registries$fixtures, registries$tournaments,
    inputs$panel_fixtures, inputs$model_registry
  )
  comparisons <- benchmark_runner_comparisons(
    score_output$scores, inputs$model_registry, registries$tournaments,
    inputs$panel_fixtures
  )
  identity <- benchmark_runner_git_identity(".")
  input_hashes <- benchmark_runner_input_hashes(
    inputs$model_registry, boundary_inventory, inputs$score_support_audit
  )
  registry_manifest <- benchmark_registry_manifest(registries)
  run_manifest <- data.frame(
    run_id = run_id,
    protocol_version = protocol$protocol_version,
    protocol_sha256 = protocol$protocol_sha256,
    git_sha = identity$sha,
    dirty_worktree = identity$dirty,
    sealed_data_policy = "wc2026_labels_denied",
    registry_sha256 = benchmark_runner_hash(paste(registry_manifest$canonical_sha256, collapse = "|")),
    model_registry_sha256 = input_hashes$model_registry,
    score_support_audit_sha256 = input_hashes$score_support_audit,
    seed_registry_sha256 = canonical_benchmark_sha256(inputs$seed_registry, "seed_id"),
    selected_g = unique(inputs$score_support_audit$selected_g),
    r_version = as.character(getRversion()),
    package_versions = paste0(
      "digest=", as.character(utils::packageVersion("digest")),
      "|MASS=", as.character(utils::packageVersion("MASS")),
      "|targets=", as.character(utils::packageVersion("targets"))
    ),
    command = "run_rolling_tournament_benchmark",
    prediction_contract_valid = TRUE,
    distribution_contract_valid = TRUE,
    manifest_contract_valid = TRUE,
    feature_coverage_valid = feature_coverage_valid,
    panel_coverage_valid = all(output_coverage$output_coverage_complete),
    seed_contract_valid = TRUE,
    score_support_audit_valid = TRUE,
    registration_settings_stable = TRUE,
    output_coverage_reconciled = TRUE,
    wc2026_sealed = TRUE,
    network_free = TRUE,
    reproducible = FALSE,
    stringsAsFactors = FALSE
  )
  decisions <- benchmark_runner_decisions(
    comparisons, output_coverage, inputs$model_registry,
    score_output$summaries, run_manifest, protocol
  )
  list(
    model_manifests = manifests,
    feature_coverage = coverage,
    fixture_predictions = predictions,
    score_distributions = distributions,
    stage_probabilities = stages,
    fixture_scores = score_output$scores,
    benchmark_summaries = score_output$summaries,
    paired_comparisons = comparisons,
    promotion_decisions = decisions,
    run_manifest = run_manifest
  )
}

#' Run the cache-only rolling tournament benchmark
#'
#' The built-in engine executes every registered baseline on frozen and updating
#' tracks. Tests and later challengers may supply another adapter runner that
#' returns the complete artifact list accepted by write_rolling_benchmark_bundle().
#' @export
run_rolling_tournament_benchmark <- function(
    history,
    registry_dir = "data/benchmark/phase09",
    output_dir = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
    run_id = "phase09-baselines-frozen",
    purpose = "baseline_reproduction",
    adapter_runner = NULL,
    branch_order = NULL,
    source_git_sha = NULL,
    verify_reproducibility = TRUE,
    ...
) {
  history <- guard_benchmark_purpose(history, purpose = purpose)
  registries <- load_benchmark_registries(registry_dir)
  inputs <- benchmark_runner_load_inputs(registry_dir)
  additional_inputs <- benchmark_runner_additional_input_specs(registry_dir)
  boundary_inventory <- benchmark_runner_boundary_inventory(registries$boundaries)
  validate_score_support_audit(inputs$score_support_audit, inputs$model_registry, boundary_inventory)
  protocol_path <- file.path(registry_dir, "promotion_protocol.json")
  protocol <- load_promotion_protocol(protocol_path)
  validate_promotion_protocol(protocol, registry_dir = registry_dir)
  if (!identical(protocol$score_support$score_support_audit_sha256,
                 canonical_benchmark_sha256(inputs$score_support_audit, c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g")))) {
    stop("Promotion protocol score-support audit hash drift", call. = FALSE)
  }
  if (!is.null(branch_order) && !setequal(branch_order, inputs$model_registry$model_id)) {
    stop("branch_order must contain every registered model exactly once", call. = FALSE)
  }
  if (is.null(adapter_runner)) adapter_runner <- benchmark_default_execution_engine
  if (!is.function(adapter_runner)) stop("adapter_runner must be a function", call. = FALSE)
  effective_order <- if (is.null(branch_order)) inputs$model_registry$model_id else branch_order
  execute <- function(order) adapter_runner(
      history = history, registries = registries, inputs = inputs,
      boundary_inventory = boundary_inventory, protocol = protocol,
      run_id = run_id, purpose = purpose, branch_order = order, ...
    )
  bundle <- execute(effective_order)
  if (is.null(source_git_sha)) source_git_sha <- benchmark_runner_git_identity(".")$sha
  if (isTRUE(verify_reproducibility)) {
    output_dir <- normalizePath(output_dir, mustWork = FALSE)
    dir.create(dirname(output_dir), recursive = TRUE, showWarnings = FALSE)
    first_root <- tempfile("phase09-repro-", tmpdir = dirname(output_dir))
    staged_root <- tempfile(paste0(".", basename(output_dir), "-staged-"), tmpdir = dirname(output_dir))
    on.exit({
      if (dir.exists(first_root)) unlink(first_root, recursive = TRUE)
      if (dir.exists(staged_root)) unlink(staged_root, recursive = TRUE)
    }, add = TRUE)
    first_coverage <- benchmark_runner_output_coverage(
      bundle$fixture_predictions, inputs$panel_fixtures,
      inputs$model_registry, inputs$panels
    )
    first_sources <- bundle[c("benchmark_summaries", "paired_comparisons", "run_manifest")]
    first_written <- write_rolling_benchmark_bundle(
      bundle, first_root, inputs$score_support_audit, inputs$model_registry,
      boundary_inventory, source_git_sha, require_reproducible = FALSE,
      additional_inputs = additional_inputs, protocol = protocol
    )
    rm(bundle)
    invisible(gc())
    bundle <- execute(rev(effective_order))
    second_coverage <- benchmark_runner_output_coverage(
      bundle$fixture_predictions, inputs$panel_fixtures,
      inputs$model_registry, inputs$panels
    )
    second_provisional <- write_rolling_benchmark_bundle(
      bundle, staged_root, inputs$score_support_audit, inputs$model_registry,
      boundary_inventory, source_git_sha, require_reproducible = FALSE,
      additional_inputs = additional_inputs, protocol = protocol
    )
    compared <- setdiff(names(first_written$content_sha256), c("promotion_decisions", "run_manifest"))
    if (!identical(
      first_written$content_sha256[compared],
      second_provisional$content_sha256[compared]
    )) {
      stop("Repeated benchmark runs produced different canonical content hashes", call. = FALSE)
    }
    second_sources <- bundle[c("benchmark_summaries", "paired_comparisons", "run_manifest")]
    finalized <- finalize_benchmark_promotion_decisions(
      first_sources, second_sources, first_coverage, second_coverage,
      inputs$model_registry, protocol
    )
    bundle$run_manifest <- finalized$second$run_manifest
    bundle$promotion_decisions <- finalized$second$promotion_decisions
    first_hashes <- first_written$content_sha256
    first_hashes[["run_manifest"]] <- benchmark_runner_content_sha256(
      finalized$first$run_manifest, "run_manifest"
    )
    first_hashes[["promotion_decisions"]] <- benchmark_runner_content_sha256(
      finalized$first$promotion_decisions, "promotion_decisions"
    )
    first_hashes <- first_hashes[sort(names(first_hashes), method = "radix")]
    written <- write_rolling_benchmark_bundle(
      bundle, staged_root, inputs$score_support_audit, inputs$model_registry,
      boundary_inventory, source_git_sha, additional_inputs = additional_inputs,
      protocol = protocol
    )
    second_hashes <- written$content_sha256[sort(names(written$content_sha256), method = "radix")]
    if (!identical(first_hashes, second_hashes)) {
      stop("Finalized benchmark decisions differ across independent passes", call. = FALSE)
    }
    if (dir.exists(output_dir)) {
      backup_root <- tempfile(paste0(".", basename(output_dir), "-backup-"), tmpdir = dirname(output_dir))
      if (!file.rename(output_dir, backup_root)) stop("Could not stage the existing benchmark bundle for replacement", call. = FALSE)
      installed <- file.rename(staged_root, output_dir)
      if (!installed) {
        file.rename(backup_root, output_dir)
        stop("Could not install the reconciled benchmark bundle", call. = FALSE)
      }
      unlink(backup_root, recursive = TRUE)
    } else if (!file.rename(staged_root, output_dir)) {
      stop("Could not install the reconciled benchmark bundle", call. = FALSE)
    }
    written$paths <- benchmark_output_paths(output_dir)
  } else {
    written <- write_rolling_benchmark_bundle(
      bundle, output_dir, inputs$score_support_audit, inputs$model_registry,
      boundary_inventory, source_git_sha, require_reproducible = FALSE,
      additional_inputs = additional_inputs, protocol = protocol
    )
  }
  validation <- validate_rolling_benchmark_bundle(
    output_dir, inputs$score_support_audit, inputs$model_registry, boundary_inventory,
    additional_inputs, require_reproducible = verify_reproducibility,
    protocol = protocol
  )
  c(written, list(validation = validation))
}
