#' Deterministic Phase 10 statistical challenger orchestration and publication

.phase10_runner_root <- function() {
  current <- normalizePath(".", winslash = "/", mustWork = TRUE)
  if (basename(current) == "testthat") current <- normalizePath(file.path(current, "../.."))
  current
}

.phase10_runner_source <- function(symbol, relative_path) {
  if (!exists(symbol, mode = "function")) {
    source(file.path(.phase10_runner_root(), relative_path), local = .GlobalEnv)
  }
  if (!exists(symbol, mode = "function")) {
    stop("Required Phase 10 service is unavailable: ", symbol, call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_runner_sha256 <- function(value = NULL, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required", call. = FALSE)
  if (isTRUE(file)) {
    return(digest::digest(file = value, algo = "sha256", serialize = FALSE))
  }
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.phase10_runner_candidates <- function() {
  c(
    "poisson_team_ridge", "poisson_team_ridge_elo", "dynamic_goal_ability",
    "dynamic_goal_ability_elo", "poisson_team_ridge_elo_dc",
    "poisson_team_ridge_elo_bivpois", "open_nb_elo_only_ablation"
  )
}

.phase10_runner_baselines <- function() {
  c(
    "uniform_1x2", "expanding_1x2", "elo_goal_nb", "open_nb_incumbent",
    "production_hybrid_nb"
  )
}

.phase10_runner_sort <- function(data) {
  if (!is.data.frame(data) || !nrow(data)) return(data)
  columns <- sort(names(data), method = "radix")
  keys <- lapply(data[columns], function(value) {
    if (inherits(value, "Date")) format(value, "%Y-%m-%d") else as.character(value)
  })
  index <- do.call(order, c(keys, list(na.last = TRUE, method = "radix")))
  output <- data[index, , drop = FALSE]
  rownames(output) <- NULL
  output
}

.phase10_runner_canonicalize <- function(value) {
  if (is.data.frame(value)) return(.phase10_runner_sort(value))
  if (is.list(value)) {
    labels <- names(value)
    if (is.null(labels)) return(lapply(value, .phase10_runner_canonicalize))
    labels <- sort(labels, method = "radix")
    return(lapply(value[labels], .phase10_runner_canonicalize))
  }
  value
}

.phase10_runner_content_sha256 <- function(value) {
  .phase10_runner_sha256(serialize(.phase10_runner_canonicalize(value), NULL, version = 3L))
}

.phase10_runner_table_sha256 <- function(data) {
  data <- .phase10_runner_sort(data)
  normalized <- as.data.frame(
    lapply(data, function(value) {
      output <- as.character(value)
      output[is.na(value)] <- "<NA>"
      output
    }),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  payload <- paste(
    c(names(normalized), unlist(normalized, use.names = FALSE)),
    collapse = "\u001f"
  )
  .phase10_runner_sha256(payload)
}

#' Return the complete Phase 10 publication graph
#' @export
phase10_output_paths <- function(output_dir) {
  if (!is.character(output_dir) || length(output_dir) != 1L || is.na(output_dir) || !nzchar(output_dir)) {
    stop("output_dir must be one non-empty path", call. = FALSE)
  }
  c(
    run_manifest = file.path(output_dir, "run_manifest.csv"),
    model_manifests = file.path(output_dir, "manifests", "model_manifests.csv"),
    feature_coverage = file.path(output_dir, "manifests", "feature_coverage.csv"),
    fold_tuning = file.path(output_dir, "manifests", "fold_tuning.csv"),
    checksum_manifest = file.path(output_dir, "manifests", "checksum_manifest.csv"),
    fixture_predictions = file.path(output_dir, "predictions", "fixture_predictions.csv"),
    score_distributions = file.path(output_dir, "predictions", "score_distributions.csv"),
    fixture_scores = file.path(output_dir, "scores", "fixture_scores.csv"),
    benchmark_summaries = file.path(output_dir, "scores", "benchmark_summaries.csv"),
    all_baseline_comparisons = file.path(output_dir, "comparisons", "all_baseline_comparisons.csv"),
    shortlist = file.path(output_dir, "shortlist", "research_shortlist.csv"),
    research_report = file.path(output_dir, "reports", "phase10_research_report.md")
  )
}

#' Validate and expose the immutable Phase 9 baseline parent
#' @export
load_phase09_parent_bundle <- function(
    output_dir = file.path(
      .phase10_runner_root(), "outputs", "benchmarks", "rolling_tournaments",
      "phase09-baselines-frozen"
    )
) {
  root <- .phase10_runner_root()
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  approved <- normalizePath(
    file.path(root, "outputs", "benchmarks", "rolling_tournaments"),
    winslash = "/", mustWork = TRUE
  )
  if (!startsWith(paste0(output_dir, "/"), paste0(approved, "/"))) {
    stop("Phase 9 parent must be inside the approved durable output root", call. = FALSE)
  }
  .phase10_runner_source("phase10_protocol_constants", "R/benchmark/challenger_protocol.R")
  .phase10_runner_source(".challenger_phase09_identity", "R/benchmark/challenger_preflight.R")
  constants <- phase10_protocol_constants()
  identity <- .challenger_phase09_identity(output_dir, constants$phase09_bundle_sha256)
  checksum_path <- file.path(output_dir, "manifests", "checksum_manifest.csv")
  checksum <- utils::read.csv(checksum_path, stringsAsFactors = FALSE, check.names = FALSE)
  score_row <- checksum[checksum$artifact == "fixture_scores", , drop = FALSE]
  if (nrow(score_row) != 1L) stop("Phase 9 fixture-score identity is missing", call. = FALSE)
  panel <- utils::read.csv(
    file.path(root, "data", "benchmark", "phase09", "panel_fixtures.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  registry <- utils::read.csv(
    file.path(root, "data", "benchmark", "phase09", "model_registry.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  fixtures <- utils::read.csv(
    file.path(root, "data", "benchmark", "phase09", "fixtures.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  panel_column <- if ("panel_id" %in% names(panel)) "panel_id" else "comparison_panel_id"
  eligible <- if ("eligible" %in% names(panel)) as.logical(panel$eligible) else rep(TRUE, nrow(panel))
  open_count <- length(unique(as.character(
    panel$fixture_id[panel[[panel_column]] == "open_core" & eligible]
  )))
  rich_count <- length(unique(as.character(
    panel$fixture_id[panel[[panel_column]] == "feature_rich" & eligible]
  )))
  editions <- length(unique(as.character(fixtures$edition_id)))
  baseline_column <- if ("model_id" %in% names(registry)) "model_id" else "candidate_id"
  baseline_ids <- as.character(registry[[baseline_column]])
  if (!identical(open_count, 630L) || !identical(rich_count, 609L) ||
      !identical(editions, 12L) || !setequal(baseline_ids, .phase10_runner_baselines())) {
    stop("Phase 9 parent panel, edition, or baseline facts drifted", call. = FALSE)
  }
  list(
    valid = TRUE,
    root = output_dir,
    bundle_sha256 = identity$bundle_sha256,
    open_fixture_count = open_count,
    rich_fixture_count = rich_count,
    edition_count = editions,
    baseline_ids = baseline_ids,
    fixture_scores_path = file.path(output_dir, as.character(score_row$relative_path)),
    fixture_scores_sha256 = as.character(score_row$sha256),
    parent_hashes = c(
      phase09_bundle_sha256 = identity$bundle_sha256,
      phase09_registry_sha256 = constants$phase09_registry_sha256,
      phase09_checksum_self_sha256 = identity$checksum_self_sha256,
      phase09_parent_graph_sha256 = identity$parent_graph_sha256
    )
  )
}

.phase10_runner_hashes <- function(result) {
  ignored <- c("canonical_hashes", "reproducible", "runtime_seconds")
  fields <- sort(setdiff(names(result), ignored), method = "radix")
  hashes <- vapply(result[fields], .phase10_runner_content_sha256, character(1))
  hashes
}

.phase10_runner_validate_result <- function(result, synthetic) {
  if (!is.list(result)) stop("challenger execution must return a named list", call. = FALSE)
  required <- c(
    "declared_open_fixture_count", "declared_rich_fixture_count",
    "declared_support_max"
  )
  missing <- setdiff(required, names(result))
  if (length(missing)) stop("challenger execution omitted: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(as.integer(result$declared_open_fixture_count), 630L) ||
      !identical(as.integer(result$declared_rich_fixture_count), 609L) ||
      !identical(as.integer(result$declared_support_max), 40L)) {
    stop("challenger execution declaration drifted from 630/609/G=40", call. = FALSE)
  }
  if (!isTRUE(synthetic)) {
    artifact_fields <- c(
      "model_manifests", "feature_coverage", "fold_tuning", "fixture_predictions",
      "score_distributions", "fixture_scores", "benchmark_summaries",
      "all_baseline_comparisons", "shortlist"
    )
    absent <- setdiff(artifact_fields, names(result))
    if (length(absent)) stop("canonical execution omitted artifacts: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_default_execution_engine <- function(
    candidate_order, history, fixtures, seed_registry, protocol,
    settings_by_candidate = list(), fold_tuning = NULL, parent_bundle, ...
) {
  if (is.null(history) || is.null(fixtures) || is.null(seed_registry)) {
    stop("canonical execution requires history, fixtures, and seed_registry", call. = FALSE)
  }
  .phase10_runner_source("run_registered_challenger_adapter", "R/benchmark/challengers.R")
  .phase10_runner_source("score_benchmark_fixtures", "R/evaluation/benchmark_scores.R")
  .phase10_runner_source("aggregate_benchmark_scores", "R/evaluation/benchmark_scores.R")
  .phase10_runner_source("benchmark_panel_fixture_ids", "R/benchmark/contracts.R")
  .phase10_runner_source("challenger_all_baseline_comparisons", "R/evaluation/challenger_selection.R")
  pieces <- lapply(candidate_order, function(candidate_id) {
    settings <- settings_by_candidate[[candidate_id]]
    if (is.null(settings)) settings <- list()
    run_registered_challenger_adapter(
      candidate_id, history, fixtures, seed_registry, support_max = 40L,
      settings = settings, protocol = protocol
    )
  })
  predictions <- do.call(rbind, lapply(pieces, `[[`, "predictions"))
  distributions <- do.call(rbind, lapply(pieces, `[[`, "distributions"))
  manifests <- do.call(rbind, lapply(pieces, `[[`, "manifests"))
  coverage <- do.call(rbind, lapply(pieces, `[[`, "feature_coverage"))
  scores <- do.call(rbind, lapply(split(predictions, predictions$track_id), function(track_predictions) {
    score_benchmark_fixtures(
      track_predictions, fixtures, distributions,
      benchmark_panel_fixture_ids(protocol$panel_fixtures, "open_core")
    )
  }))
  summaries <- aggregate_benchmark_scores(scores, unique(as.character(fixtures$edition_id)))
  baseline_scores <- challenger_selection_scores(
    parent_bundle$fixture_scores_path, parent_bundle$fixture_scores_sha256
  )
  comparisons <- challenger_all_baseline_comparisons(
    rbind(scores, baseline_scores), protocol$tournaments, protocol$panel_fixtures,
    candidate_order, parent_bundle$baseline_ids, parent_bundle$parent_hashes
  )
  if (is.null(fold_tuning)) {
    fold_tuning <- unique(manifests[intersect(
      c("model_id", "track_id", "boundary_id", "registration_sha256", "settings_sha256"),
      names(manifests)
    )])
  }
  list(
    model_manifests = manifests, feature_coverage = coverage, fold_tuning = fold_tuning,
    fixture_predictions = predictions, score_distributions = distributions,
    fixture_scores = scores, benchmark_summaries = summaries,
    all_baseline_comparisons = comparisons,
    declared_open_fixture_count = 630L, declared_rich_fixture_count = 609L,
    declared_support_max = 40L
  )
}

#' Run and reconcile normal and reversed Phase 10 challenger orders
#' @export
run_statistical_challenger_benchmark <- function(
    history = NULL, candidate_order = .phase10_runner_candidates(),
    execution_engine = NULL, synthetic = FALSE, publish = FALSE,
    output_dir = file.path(
      .phase10_runner_root(), "outputs", "benchmarks", "rolling_tournaments",
      "phase10-statistical-challengers"
    ), ...
) {
  candidate_order <- as.character(candidate_order)
  if (anyDuplicated(candidate_order) || !setequal(candidate_order, .phase10_runner_candidates())) {
    stop("candidate_order must contain the exact seven registered candidates", call. = FALSE)
  }
  if (!is.null(history)) {
    .phase10_runner_source("guard_benchmark_purpose", "R/benchmark/cutoffs.R")
    history <- guard_benchmark_purpose(history, purpose = "candidate_selection")
    holdout <- benchmark_holdout_rows(history)
    outcome_like <- grep(
      "(^|_)(goal|goals|score|result|outcome|winner)(_|$)", names(history),
      ignore.case = TRUE, value = TRUE
    )
    has_label <- length(outcome_like) && any(vapply(history[outcome_like], function(value) {
      if (is.logical(value)) return(any(!is.na(value[holdout])))
      any(!is.na(value[holdout]) & nzchar(as.character(value[holdout])))
    }, logical(1)))
    if (any(holdout) && has_label) {
      stop("sealed wc2026 holdout labels are forbidden for candidate selection", call. = FALSE)
    }
  }
  parent <- NULL
  protocol <- NULL
  environment <- NULL
  if (!isTRUE(synthetic)) {
    .phase10_runner_source("require_challenger_environment", "R/benchmark/challenger_preflight.R")
    .phase10_runner_source("load_and_validate_challenger_protocol", "R/benchmark/challenger_protocol.R")
    environment <- require_challenger_environment(
      file.path(.phase10_runner_root(), "data", "benchmark", "phase10", "glmnet_provenance.csv")
    )
    protocol <- load_and_validate_challenger_protocol(
      file.path(.phase10_runner_root(), "data", "benchmark", "phase10")
    )
    protocol$panel_fixtures <- utils::read.csv(
      file.path(.phase10_runner_root(), "data", "benchmark", "phase09", "panel_fixtures.csv"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    protocol$tournaments <- utils::read.csv(
      file.path(.phase10_runner_root(), "data", "benchmark", "phase09", "tournaments.csv"),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    parent <- load_phase09_parent_bundle()
  }
  if (is.null(execution_engine)) execution_engine <- .phase10_default_execution_engine
  if (!is.function(execution_engine)) stop("execution_engine must be a function", call. = FALSE)
  arguments <- list(
    history = history, synthetic = synthetic, protocol = protocol,
    environment = environment, parent_bundle = parent
  )
  arguments <- c(arguments, list(...))
  run_once <- function(order) {
    output <- do.call(execution_engine, c(list(candidate_order = order), arguments))
    .phase10_runner_validate_result(output, synthetic)
    output
  }
  first <- run_once(candidate_order)
  second <- run_once(rev(candidate_order))
  first_hashes <- .phase10_runner_hashes(first)
  second_hashes <- .phase10_runner_hashes(second)
  if (!identical(first_hashes, second_hashes)) {
    stop("normal and reversed challenger executions do not reconcile", call. = FALSE)
  }
  first$canonical_hashes <- first_hashes
  first$reproducible <- TRUE
  first$parent_bundle <- parent
  first$environment <- environment
  first$synthetic <- isTRUE(synthetic)
  if (isTRUE(publish)) {
    first$bundle_validation <- write_statistical_challenger_bundle(first, output_dir)
  }
  first
}

.phase10_synthetic_artifacts <- function(result) {
  candidates <- if (is.data.frame(result$candidates)) {
    .phase10_runner_sort(result$candidates)
  } else {
    data.frame(candidate_id = .phase10_runner_candidates(), stringsAsFactors = FALSE)
  }
  candidate_ids <- as.character(candidates$candidate_id)
  evidence <- vapply(candidate_ids, function(id) .phase10_runner_sha256(id), character(1))
  shortlist_index <- c(1L, min(7L, length(candidate_ids)), min(5L, length(candidate_ids)))
  shortlist <- data.frame(
    slot = c("best_proper_score", "simplest_non_inferior", "dependence_representative"),
    candidate_id = unname(candidate_ids[shortlist_index]),
    evidence_sha256 = unname(evidence[shortlist_index]),
    selection_basis = c(
      "lowest_updating_equal_tournament_rps",
      "lowest_complexity_practically_non_inferior",
      "registered_dependence_representative"
    ),
    non_exclusive = TRUE, stringsAsFactors = FALSE
  )
  distributions <- do.call(rbind, lapply(seq_along(candidate_ids), function(index) {
    grid <- expand.grid(home_goals = 0:40, away_goals = 0:40)
    grid$score_distribution_id <- paste0("synthetic__", candidate_ids[index])
    weight <- stats::dpois(grid$home_goals, 1 + index / 20) * stats::dpois(grid$away_goals, 1)
    grid$probability <- weight / sum(weight)
    grid[, c("score_distribution_id", "home_goals", "away_goals", "probability")]
  }))
  run_manifest <- data.frame(
    schema_version = "phase10-challenger-bundle-v1", run_id = "phase10-synthetic",
    phase09_bundle_sha256 = "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069",
    open_fixture_count = 630L, rich_fixture_count = 609L, selected_g = 40L,
    reproducible = TRUE, wc2026_sealed = TRUE, network_free = TRUE,
    research_only = TRUE, protected_paths_clean = TRUE, synthetic = TRUE,
    stringsAsFactors = FALSE
  )
  list(
    run_manifest = run_manifest,
    model_manifests = transform(candidates, track_id = "synthetic", boundary_id = "synthetic"),
    feature_coverage = data.frame(
      candidate_id = candidate_ids, coverage_valid = TRUE, stringsAsFactors = FALSE
    ),
    fold_tuning = data.frame(
      candidate_id = candidate_ids, tuning_valid = TRUE,
      tuning_sha256 = evidence, stringsAsFactors = FALSE
    ),
    fixture_predictions = data.frame(
      candidate_id = candidate_ids, fixture_id = paste0("synthetic_", seq_along(candidate_ids)),
      score_distribution_id = paste0("synthetic__", candidate_ids), stringsAsFactors = FALSE
    ),
    score_distributions = distributions,
    fixture_scores = data.frame(
      candidate_id = candidate_ids, metric = "rps", value = seq_along(candidate_ids) / 100,
      stringsAsFactors = FALSE
    ),
    benchmark_summaries = data.frame(
      candidate_id = candidate_ids, track_id = "updating", metric = "rps",
      estimate = seq_along(candidate_ids) / 100, stringsAsFactors = FALSE
    ),
    all_baseline_comparisons = expand.grid(
      candidate_id = candidate_ids, baseline_id = .phase10_runner_baselines(),
      track_id = c("frozen", "updating"), stringsAsFactors = FALSE
    ),
    shortlist = shortlist
  )
}

.phase10_runner_artifacts <- function(result) {
  fields <- c(
    "run_manifest", "model_manifests", "feature_coverage", "fold_tuning",
    "fixture_predictions", "score_distributions", "fixture_scores",
    "benchmark_summaries", "all_baseline_comparisons", "shortlist"
  )
  if (isTRUE(result$synthetic)) return(.phase10_synthetic_artifacts(result))
  artifacts <- result[fields]
  if (any(vapply(artifacts, is.null, logical(1)))) stop("bundle result is incomplete", call. = FALSE)
  artifacts
}

.phase10_runner_write_csv <- function(data, path, preserve_order = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  output <- if (isTRUE(preserve_order)) data else .phase10_runner_sort(data)
  utils::write.csv(output, path, row.names = FALSE, na = "")
  invisible(path)
}

.phase10_runner_report <- function(artifacts) {
  paste(
    "# Phase 10 Statistical Challenger Research Bundle",
    "",
    "This bundle contains deterministic research evidence only.",
    "",
    paste0("Candidates: ", length(unique(artifacts$model_manifests$candidate_id))),
    "Comparison panels: open_core=630; feature_rich=609",
    "Score support: G=40",
    sep = "\n"
  )
}

.phase10_runner_build_checksum <- function(stage, paths, artifacts) {
  artifact_names <- setdiff(names(paths), c("checksum_manifest"))
  relative <- substring(paths[artifact_names], nchar(stage) + 2L)
  rows <- vapply(artifact_names, function(name) {
    if (name == "research_report") return(NA_integer_)
    as.integer(nrow(artifacts[[name]]))
  }, integer(1))
  parent_hash <- as.character(artifacts$run_manifest$phase09_bundle_sha256[1])
  body <- data.frame(
    artifact = artifact_names, relative_path = relative,
    artifact_role = "output",
    sha256 = vapply(paths[artifact_names], .phase10_runner_sha256, character(1), file = TRUE),
    canonical_content_sha256 = vapply(paths[artifact_names], .phase10_runner_sha256, character(1), file = TRUE),
    rows = rows, bytes = as.numeric(file.info(paths[artifact_names])$size),
    producer = "run_statistical_challenger_benchmark",
    parent_hashes = parent_hash, selected_g = 40L,
    stringsAsFactors = FALSE
  )
  body <- .phase10_runner_sort(body)
  self_hash <- .phase10_runner_table_sha256(body)
  self <- data.frame(
    artifact = "checksum_manifest", relative_path = substring(paths[["checksum_manifest"]], nchar(stage) + 2L),
    artifact_role = "self", sha256 = self_hash, canonical_content_sha256 = self_hash,
    rows = nrow(body) + 1L, bytes = NA_real_, producer = "write_statistical_challenger_bundle",
    parent_hashes = parent_hash, selected_g = 40L, stringsAsFactors = FALSE
  )
  rbind(body, self)
}

#' Write, prevalidate, atomically install, and postvalidate a Phase 10 bundle
#' @export
write_statistical_challenger_bundle <- function(result, output_dir) {
  if (!is.list(result) || !isTRUE(result$reproducible)) {
    stop("only a reconciled challenger result may be published", call. = FALSE)
  }
  parent_dir <- dirname(output_dir)
  dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(output_dir), "-stage-"), tmpdir = parent_dir)
  dir.create(stage, recursive = TRUE, showWarnings = FALSE)
  artifacts <- .phase10_runner_artifacts(result)
  paths <- phase10_output_paths(stage)
  for (name in setdiff(names(artifacts), "run_manifest")) {
    .phase10_runner_write_csv(
      artifacts[[name]], paths[[name]], preserve_order = identical(name, "shortlist")
    )
  }
  .phase10_runner_write_csv(artifacts$run_manifest, paths[["run_manifest"]])
  dir.create(dirname(paths[["research_report"]]), recursive = TRUE, showWarnings = FALSE)
  writeLines(.phase10_runner_report(artifacts), paths[["research_report"]], useBytes = TRUE)
  artifacts$research_report <- .phase10_runner_report(artifacts)
  checksum <- .phase10_runner_build_checksum(stage, paths, artifacts)
  .phase10_runner_write_csv(checksum, paths[["checksum_manifest"]])
  .phase10_runner_source("benchmark_runner_install_staged_bundle", "R/benchmark/runner.R")
  validator <- if (isTRUE(result$synthetic)) smoke_statistical_challenger_bundle else validate_statistical_challenger_bundle
  benchmark_runner_install_staged_bundle(stage, output_dir, validator)
}

.phase10_runner_read_bundle <- function(output_dir, deep) {
  paths <- phase10_output_paths(output_dir)
  if (!all(file.exists(paths))) stop("Phase 10 bundle is incomplete", call. = FALSE)
  checksum <- utils::read.csv(paths[["checksum_manifest"]], stringsAsFactors = FALSE, check.names = FALSE)
  required_columns <- c(
    "artifact", "relative_path", "artifact_role", "sha256",
    "canonical_content_sha256", "rows", "bytes", "producer",
    "parent_hashes", "selected_g"
  )
  if (!identical(names(checksum), required_columns) || anyDuplicated(checksum$artifact)) {
    stop("Phase 10 checksum schema drift", call. = FALSE)
  }
  expected_artifacts <- names(paths)
  if (!setequal(as.character(checksum$artifact), expected_artifacts)) {
    stop("Phase 10 checksum graph is incomplete", call. = FALSE)
  }
  body <- checksum[checksum$artifact != "checksum_manifest", , drop = FALSE]
  self <- checksum[checksum$artifact == "checksum_manifest", , drop = FALSE]
  expected_self <- .phase10_runner_table_sha256(body)
  if (nrow(self) != 1L || !identical(as.character(self$canonical_content_sha256), expected_self)) {
    stop("Phase 10 checksum self-hash mismatch", call. = FALSE)
  }
  for (index in seq_len(nrow(body))) {
    path <- file.path(output_dir, as.character(body$relative_path[index]))
    if (!file.exists(path) || !identical(
      .phase10_runner_sha256(path, file = TRUE), as.character(body$sha256[index])
    )) stop("Phase 10 artifact checksum mismatch: ", body$artifact[index], call. = FALSE)
  }
  read_csv <- function(name) utils::read.csv(paths[[name]], stringsAsFactors = FALSE, check.names = FALSE)
  run <- read_csv("run_manifest")
  if (nrow(run) != 1L || !identical(as.integer(run$open_fixture_count), 630L) ||
      !identical(as.integer(run$rich_fixture_count), 609L) ||
      !identical(as.integer(run$selected_g), 40L)) {
    stop("Phase 10 run declaration drift", call. = FALSE)
  }
  required_flags <- c(
    "reproducible", "wc2026_sealed", "network_free", "research_only",
    "protected_paths_clean"
  )
  if (any(!vapply(run[required_flags], function(value) isTRUE(as.logical(value[[1]])), logical(1)))) {
    stop("Phase 10 protected-boundary flags are not accepted", call. = FALSE)
  }
  manifests <- read_csv("model_manifests")
  candidate_column <- if ("candidate_id" %in% names(manifests)) "candidate_id" else "model_id"
  if (!setequal(unique(as.character(manifests[[candidate_column]])), .phase10_runner_candidates())) {
    stop("Phase 10 candidate identity drift", call. = FALSE)
  }
  shortlist <- read_csv("shortlist")
  .phase10_runner_source("validate_statistical_shortlist", "R/evaluation/challenger_selection.R")
  validate_statistical_shortlist(shortlist)
  distributions <- read_csv("score_distributions")
  required_distribution <- c("score_distribution_id", "home_goals", "away_goals", "probability")
  if (!all(required_distribution %in% names(distributions))) {
    stop("Phase 10 distribution schema drift", call. = FALSE)
  }
  groups <- split(distributions, distributions$score_distribution_id)
  sampled <- groups[!duplicated(sub("^synthetic__", "", names(groups)))]
  if (!length(sampled) || any(vapply(sampled, function(rows) {
    max(rows$home_goals) != 40L || max(rows$away_goals) != 40L ||
      abs(sum(rows$probability) - 1) > 1e-10
  }, logical(1)))) stop("Phase 10 G=40 distribution sample failed", call. = FALSE)
  comparisons <- read_csv("all_baseline_comparisons")
  if (!setequal(unique(as.character(comparisons$baseline_id)), .phase10_runner_baselines()) ||
      !setequal(unique(as.character(comparisons$track_id)), c("frozen", "updating"))) {
    stop("Phase 10 all-baseline comparison coverage drift", call. = FALSE)
  }
  if (isTRUE(deep) && !isTRUE(as.logical(run$synthetic))) {
    if (nrow(unique(comparisons[c("candidate_id", "baseline_id", "track_id")])) != 70L) {
      stop("Phase 10 deep comparison identity count drift", call. = FALSE)
    }
    if (any(vapply(groups, function(rows) {
      nrow(rows) != 1681L || !setequal(rows$home_goals, 0:40) || !setequal(rows$away_goals, 0:40)
    }, logical(1)))) stop("Phase 10 deep score grid validation failed", call. = FALSE)
  }
  list(
    valid = TRUE, n_candidates = 7L, open_fixture_count = 630L,
    rich_fixture_count = 609L, score_support_max = 40L,
    reproducible = TRUE, wc2026_sealed = TRUE, research_only = TRUE,
    parents_valid = TRUE, sampled_grids_valid = TRUE,
    protected_paths_clean = TRUE,
    phase09_parent_bundle_sha256 = as.character(run$phase09_bundle_sha256)
  )
}

#' Fast control-plane validation for a Phase 10 bundle
#' @export
smoke_statistical_challenger_bundle <- function(output_dir) {
  .phase10_runner_read_bundle(output_dir, deep = FALSE)
}

#' Deep validation for an accepted canonical Phase 10 bundle
#' @export
validate_statistical_challenger_bundle <- function(output_dir) {
  .phase10_runner_read_bundle(output_dir, deep = TRUE)
}
