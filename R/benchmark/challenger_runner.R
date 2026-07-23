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

.phase10_runner_prepare_history <- function(history, protocol) {
  required <- c(
    "match_id", "date", "home_team", "away_team", "home_goals",
    "away_goals", "elo_diff", "elo_diff__source_date"
  )
  missing <- setdiff(required, names(history))
  if (length(missing)) {
    stop("Phase 10 history is missing canonical columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  root <- .phase10_runner_root()
  source_matches <- utils::read.csv(
    file.path(root, "data", "processed", "elo_matches.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  source_matches$match_id <- make.unique(as.character(source_matches$match_id), sep = "__")
  source_index <- match(as.character(history$match_id), as.character(source_matches$match_id))
  if (anyNA(source_index) || anyDuplicated(history$match_id) ||
      !identical(
        as.character(source_matches$home_team_canonical[source_index]),
        as.character(history$home_team)
      ) ||
      !identical(
        as.character(source_matches$away_team_canonical[source_index]),
        as.character(history$away_team)
      )) {
    stop("Phase 10 feature history no longer aligns with checked Elo match identities", call. = FALSE)
  }
  teams <- utils::read.csv(
    file.path(root, "data", "benchmark", "phase09", "teams.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  resolve_team <- function(values) {
    ids <- as.character(teams$team_id[match(as.character(values), as.character(teams$canonical_name))])
    missing_id <- is.na(ids) | !nzchar(ids)
    ids[missing_id] <- paste0(
      "team_history_",
      vapply(as.character(values[missing_id]), .phase10_runner_sha256, character(1))
    )
    ids
  }
  history$home_team_id <- resolve_team(history$home_team)
  history$away_team_id <- resolve_team(history$away_team)
  history$fixture_id <- as.character(history$match_id)
  history$actual_completion_date <- as.Date(history$date)
  history$evidence_cutoff_exclusive <- as.Date(history$date)
  history$venue_role <- ifelse(
    as.character(history$venue) %in% c("home", "neutral"),
    as.character(history$venue), "home"
  )
  history$tournament <- as.character(source_matches$tournament[source_index])
  history$edition_id <- ""
  catalog <- .phase10_edition_catalog()
  for (index in seq_len(nrow(catalog))) {
    selected <- history$tournament == as.character(catalog$competition[index]) &
      history$actual_completion_date >= as.Date(catalog$opener_date[index]) &
      history$actual_completion_date <= as.Date(catalog$final_date[index])
    history$edition_id[selected] <- as.character(catalog$edition_id[index])
  }
  expected_editions <- unique(as.character(protocol$tuning_editions$inner_edition_id))
  if (!all(expected_editions %in% unique(history$edition_id))) {
    stop("Phase 10 history does not cover every registered tuning edition", call. = FALSE)
  }
  history
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
    all_baseline_paired_comparisons = file.path(
      output_dir, "comparisons", "all_baseline_paired_comparisons.csv"
    ),
    shortlist = file.path(output_dir, "selection", "shortlist.csv"),
    statistical_challenger_report = file.path(
      output_dir, "selection", "statistical_challenger_report.md"
    )
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

.phase10_runner_protocol_file_hashes <- function(
    protocol_dir = file.path(.phase10_runner_root(), "data", "benchmark", "phase10")
) {
  files <- c(
    model_registry_sha256 = "model_registry.csv",
    feature_contract_sha256 = "feature_contract.csv",
    tuning_editions_sha256 = "tuning_editions.csv",
    tuning_grid_sha256 = "tuning_grid.csv",
    ablation_registry_sha256 = "ablation_registry.csv",
    selection_protocol_sha256 = "selection_protocol.json",
    storage_preflight_sha256 = "storage_preflight.csv",
    glmnet_provenance_sha256 = "glmnet_provenance.csv"
  )
  paths <- file.path(protocol_dir, unname(files))
  if (!all(file.exists(paths))) stop("Phase 10 protocol parent graph is incomplete", call. = FALSE)
  stats::setNames(
    vapply(paths, .phase10_runner_sha256, character(1), file = TRUE),
    names(files)
  )
}

#' Tune penalized means and fold-global dependence parameters
#' @export
tune_statistical_penalized_family <- function(history, protocol, tournaments) {
  .phase10_runner_source(
    "select_penalized_poisson_hyperparameters", "R/forecast/penalized_poisson.R"
  )
  .phase10_runner_source("fit_fold_dependence_parameters", "R/forecast/score_dependence.R")
  .phase10_runner_source("fit_registered_challenger", "R/benchmark/challengers.R")
  editions <- as.character(tournaments$edition_id)
  settings <- lapply(editions, function(outer_id) {
    select_penalized_poisson_hyperparameters(
      history = history, outer_edition_id = outer_id, tournaments = tournaments,
      tuning_editions = protocol$tuning_editions, tuning_grid = protocol$tuning_grid,
      tournament_map = history[c("match_id", "tournament")], support_max = 40L
    )
  })
  names(settings) <- editions
  dependence <- lapply(editions, function(outer_id) {
    opener <- as.Date(tournaments$opener_date[match(outer_id, tournaments$edition_id)])
    selected <- settings[[outer_id]][1L, , drop = FALSE]
    runtime <- list(
      team_ridge_lambda = as.numeric(selected$team_ridge_lambda),
      elo_lasso_lambda = as.numeric(selected$elo_lasso_lambda)
    )
    fit <- fit_registered_challenger(
      "poisson_team_ridge_elo", history, runtime, cutoff = opener,
      protocol = structure(protocol, class = c("validated_challenger_protocol", class(protocol)))
    )
    inner <- as.character(protocol$tuning_editions$inner_edition_id[
      protocol$tuning_editions$outer_edition_id == outer_id
    ])
    eligible <- history$edition_id %in% inner & as.Date(history$actual_completion_date) < opener
    fitting <- history[eligible, , drop = FALSE]
    means <- predict_penalized_poisson_means(fit, fitting)
    fitting$mu_home <- means$mu_home[match(fitting$fixture_id, means$fixture_id)]
    fitting$mu_away <- means$mu_away[match(fitting$fixture_id, means$fixture_id)]
    fit_fold_dependence_parameters(
      fitting, outer_id, opener, protocol$tuning_editions, support_max = 40L
    )
  })
  names(dependence) <- editions
  list(settings = settings, dependence = dependence)
}

#' Tune dynamic means and their signed Elo increment
#' @export
tune_statistical_dynamic_family <- function(
    history, protocol, tournaments, worker_count = 2L, checkpoint_path = NULL
) {
  .phase10_runner_source(
    "select_dynamic_goal_hyperparameters", "R/forecast/dynamic_goal_ability.R"
  )
  worker_count <- as.integer(worker_count)
  if (length(worker_count) != 1L || is.na(worker_count) || worker_count < 1L || worker_count > 2L) {
    stop("Dynamic tuning permits one or two independent workers", call. = FALSE)
  }
  dynamic_grid <- protocol$tuning_grid[
    protocol$tuning_grid$parameter_id == "dynamic_pseudo_exposure", , drop = FALSE
  ]
  inner_ids <- sort(
    unique(as.character(protocol$tuning_editions$inner_edition_id)), method = "radix"
  )
  prewarm_jobs <- expand.grid(
    inner_edition_id = inner_ids,
    pseudo_exposure = as.numeric(dynamic_grid$parameter_value),
    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
  )
  prewarm_job <- function(index) {
    inner_id <- as.character(prewarm_jobs$inner_edition_id[index])
    pseudo_exposure <- as.numeric(prewarm_jobs$pseudo_exposure[index])
    half_life_days <- as.numeric(dynamic_grid$half_life_days[
      match(pseudo_exposure, as.numeric(dynamic_grid$parameter_value))
    ])
    value <- dynamic_goal_candidate_rps(
      history, inner_id, pseudo_exposure, half_life_days, 40L
    )
    list(
      key = dynamic_goal_tuning_cache_key(
        history, inner_id, pseudo_exposure, half_life_days, 40L
      ),
      value = value
    )
  }
  valid_prewarm <- function(item) {
    is.list(item) && length(item$key) == 1L &&
      grepl("^[0-9a-f]{64}$", item$key) &&
      length(item$value) == 1L && is.finite(item$value)
  }
  prewarmed <- if (!is.null(checkpoint_path) && file.exists(checkpoint_path)) {
    readRDS(checkpoint_path)
  } else {
    list()
  }
  if (length(prewarmed) > nrow(prewarm_jobs)) {
    stop("Dynamic tuning checkpoint has excess jobs", call. = FALSE)
  }
  while (length(prewarmed) < nrow(prewarm_jobs)) {
    batch <- seq.int(
      length(prewarmed) + 1L,
      min(length(prewarmed) + 10L, nrow(prewarm_jobs))
    )
    computed <- if (.Platform$OS.type != "windows" && worker_count > 1L) {
      parallel::mclapply(
        batch, prewarm_job, mc.cores = worker_count, mc.preschedule = FALSE
      )
    } else {
      lapply(batch, prewarm_job)
    }
    if (any(!vapply(computed, valid_prewarm, logical(1)))) {
      stop("Dynamic tuning worker failed", call. = FALSE)
    }
    prewarmed <- c(prewarmed, computed)
    if (!is.null(checkpoint_path)) saveRDS(prewarmed, checkpoint_path)
    message(sprintf(
      "DYNAMIC_PREWARM_PROGRESS completed=%d total=%d",
      length(prewarmed), nrow(prewarm_jobs)
    ))
  }
  if (length(prewarmed) != nrow(prewarm_jobs) ||
      any(!vapply(prewarmed, valid_prewarm, logical(1)))) {
    stop("Dynamic tuning checkpoint is incomplete", call. = FALSE)
  }
  for (item in prewarmed) {
    assign(item$key, item$value, envir = .dynamic_goal_tuning_cache)
  }
  editions <- as.character(tournaments$edition_id)
  settings <- lapply(editions, function(outer_id) {
    select_dynamic_goal_hyperparameters(
      history = history, outer_edition_id = outer_id,
      tuning_editions = protocol$tuning_editions,
      tuning_grid = protocol$tuning_grid, support_max = 40L
    )
  })
  names(settings) <- editions
  fit_elo <- function(outer_id) {
    selected <- settings[[outer_id]][1L, , drop = FALSE]
    opener <- as.Date(tournaments$opener_date[match(outer_id, tournaments$edition_id)])
    fit_dynamic_elo_coefficient(
      history, outer_id, opener,
      pseudo_exposure = as.numeric(selected$pseudo_exposure),
      half_life_days = as.numeric(selected$half_life_days)
    )
  }
  elo <- if (.Platform$OS.type != "windows" && worker_count > 1L) {
    parallel::mclapply(editions, fit_elo, mc.cores = worker_count, mc.preschedule = FALSE)
  } else {
    lapply(editions, fit_elo)
  }
  if (any(!vapply(elo, function(fit) {
    is.list(fit) && isTRUE(fit$converged) && length(fit$coefficient) == 1L &&
      is.finite(fit$coefficient)
  }, logical(1)))) stop("Dynamic Elo tuning worker failed", call. = FALSE)
  names(elo) <- editions
  list(settings = settings, elo = elo)
}

.phase10_runner_compile_tuning <- function(penalized, dynamic, protocol, tournaments) {
  candidates <- .phase10_runner_candidates()
  editions <- as.character(tournaments$edition_id)
  tracks <- c("frozen", "updating")
  settings_by_candidate <- stats::setNames(vector("list", length(candidates)), candidates)
  rows <- list()
  row_index <- 0L
  for (outer_id in editions) {
    penalized_row <- penalized$settings[[outer_id]][1L, , drop = FALSE]
    dynamic_row <- dynamic$settings[[outer_id]][1L, , drop = FALSE]
    dependence <- penalized$dependence[[outer_id]]
    rho <- dependence$parameter[dependence$parameter_name == "rho"]
    q <- dependence$parameter[dependence$parameter_name == "q"]
    base_penalized <- list(
      team_ridge_lambda = as.numeric(penalized_row$team_ridge_lambda),
      elo_lasso_lambda = as.numeric(penalized_row$elo_lasso_lambda)
    )
    base_dynamic <- list(
      pseudo_exposure = as.numeric(dynamic_row$pseudo_exposure),
      half_life_days = as.numeric(dynamic_row$half_life_days)
    )
    settings_by_candidate$poisson_team_ridge[[outer_id]] <- base_penalized
    settings_by_candidate$poisson_team_ridge_elo[[outer_id]] <- base_penalized
    settings_by_candidate$poisson_team_ridge_elo_dc[[outer_id]] <- c(base_penalized, rho = rho)
    settings_by_candidate$poisson_team_ridge_elo_bivpois[[outer_id]] <- c(base_penalized, q = q)
    settings_by_candidate$dynamic_goal_ability[[outer_id]] <- base_dynamic
    settings_by_candidate$dynamic_goal_ability_elo[[outer_id]] <- c(
      base_dynamic, elo_coefficient = as.numeric(dynamic$elo[[outer_id]]$coefficient)
    )
    settings_by_candidate$open_nb_elo_only_ablation[[outer_id]] <- list()
    for (candidate_id in candidates) for (track_id in tracks) {
      runtime <- settings_by_candidate[[candidate_id]][[outer_id]]
      row_index <- row_index + 1L
      rows[[row_index]] <- data.frame(
        outer_edition_id = outer_id, track_id = track_id,
        candidate_id = candidate_id,
        team_ridge_lambda = if (is.null(runtime$team_ridge_lambda)) NA_real_ else runtime$team_ridge_lambda,
        elo_lasso_lambda = if (is.null(runtime$elo_lasso_lambda)) NA_real_ else runtime$elo_lasso_lambda,
        pseudo_exposure = if (is.null(runtime$pseudo_exposure)) NA_real_ else runtime$pseudo_exposure,
        half_life_days = if (is.null(runtime$half_life_days)) NA_real_ else runtime$half_life_days,
        elo_coefficient = if (is.null(runtime$elo_coefficient)) NA_real_ else runtime$elo_coefficient,
        rho = if (is.null(runtime$rho)) NA_real_ else runtime$rho,
        q = if (is.null(runtime$q)) NA_real_ else runtime$q,
        eligible_match_ids_sha256 = if (grepl("dynamic", candidate_id)) {
          dynamic$elo[[outer_id]]$eligible_match_ids_sha256
        } else {
          penalized_row$eligible_match_ids_sha256
        },
        settings_sha256 = .phase10_runner_content_sha256(runtime),
        tuning_editions_sha256 = .phase10_runner_content_sha256(
          protocol$tuning_editions[protocol$tuning_editions$outer_edition_id == outer_id, , drop = FALSE]
        ),
        dependence_training_sha256 = if (candidate_id %in% c(
          "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois"
        )) dependence$training_data_sha256[1L] else "",
        objective_track = "updating", shared_between_tracks = TRUE,
        strict_prior_only = TRUE, selected_g = 40L,
        stringsAsFactors = FALSE
      )
    }
  }
  list(
    settings_by_candidate = settings_by_candidate,
    fold_tuning = do.call(rbind, rows)
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
      "all_baseline_paired_comparisons", "shortlist"
    )
    absent <- setdiff(artifact_fields, names(result))
    if (length(absent)) stop("canonical execution omitted artifacts: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

.phase10_runner_validate_fixture_seeds <- function(fixtures, seed_registry) {
  required <- c("fixture_id", "edition_id", "track_id")
  missing_columns <- setdiff(required, names(fixtures))
  if (length(missing_columns)) {
    stop(
      "Phase 10 fixtures are missing seed-join columns: ",
      paste(missing_columns, collapse = ", "), call. = FALSE
    )
  }
  if (!"fixture_id" %in% names(seed_registry)) {
    stop("Phase 10 seed registry is missing fixture_id", call. = FALSE)
  }
  missing_ids <- sort(
    setdiff(unique(as.character(fixtures$fixture_id)), as.character(seed_registry$fixture_id)),
    method = "radix"
  )
  if (length(missing_ids)) {
    examples <- paste(utils::head(missing_ids, 5L), collapse = ", ")
    stop(
      "Phase 10 fixtures are missing shared seeds before model fitting: ", examples,
      if (length(missing_ids) > 5L) " ..." else "", call. = FALSE
    )
  }
  invisible(TRUE)
}

.phase10_default_execution_engine <- function(
    candidate_order, history, fixtures, seed_registry, protocol,
    settings_by_candidate = list(), fold_tuning = NULL, parent_bundle,
    environment = NULL, worker_count = 2L, ...
) {
  if (is.null(history) || is.null(fixtures) || is.null(seed_registry)) {
    stop("canonical execution requires history, fixtures, and seed_registry", call. = FALSE)
  }
  .phase10_runner_source("run_registered_challenger_adapter", "R/benchmark/challengers.R")
  .phase10_runner_source("score_benchmark_fixtures", "R/evaluation/benchmark_scores.R")
  .phase10_runner_source("aggregate_benchmark_scores", "R/evaluation/benchmark_scores.R")
  .phase10_runner_source("benchmark_panel_fixture_ids", "R/benchmark/contracts.R")
  .phase10_runner_source("challenger_all_baseline_comparisons", "R/evaluation/challenger_selection.R")
  worker_count <- as.integer(worker_count)
  if (length(worker_count) != 1L || is.na(worker_count) || worker_count < 1L || worker_count > 2L) {
    stop("Phase 10 permits one or two independent model-track workers", call. = FALSE)
  }
  tracks <- sort(unique(as.character(fixtures$track_id)), method = "radix")
  if (!identical(tracks, c("frozen", "updating"))) {
    stop("canonical execution requires exact frozen and updating tracks", call. = FALSE)
  }
  .phase10_runner_validate_fixture_seeds(fixtures, seed_registry)
  editions <- unique(as.character(fixtures$edition_id))
  jobs <- expand.grid(
    candidate_id = candidate_order, track_id = tracks, edition_id = editions,
    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
  )
  run_job <- function(index) {
    candidate_id <- as.character(jobs$candidate_id[index])
    track_id <- as.character(jobs$track_id[index])
    edition_id <- as.character(jobs$edition_id[index])
    settings <- settings_by_candidate[[candidate_id]]
    if (is.list(settings) && !is.null(names(settings)) && edition_id %in% names(settings)) {
      settings <- settings[[edition_id]]
    }
    if (is.null(settings)) settings <- list()
    run_registered_challenger_adapter(
      candidate_id, history,
      fixtures[
        as.character(fixtures$track_id) == track_id &
          as.character(fixtures$edition_id) == edition_id,
        , drop = FALSE
      ],
      seed_registry, support_max = 40L,
      settings = settings, protocol = protocol
    )
  }
  pieces <- if (worker_count == 2L && .Platform$OS.type != "windows") {
    parallel::mclapply(seq_len(nrow(jobs)), run_job, mc.cores = 2L, mc.preschedule = FALSE)
  } else {
    lapply(seq_len(nrow(jobs)), run_job)
  }
  failed <- which(vapply(pieces, inherits, logical(1), what = "try-error"))
  if (length(failed)) {
    labels <- paste(
      jobs$candidate_id[failed], jobs$track_id[failed], jobs$edition_id[failed],
      sep = "/"
    )
    details <- unique(vapply(pieces[failed], function(error) {
      trimws(as.character(error)[[1L]])
    }, character(1)))
    stop(
      "Phase 10 model-track jobs failed: ", paste(labels, collapse = ", "),
      "; errors: ", paste(details, collapse = " | "), call. = FALSE
    )
  }
  predictions <- do.call(rbind, lapply(pieces, `[[`, "predictions"))
  distributions <- do.call(rbind, lapply(pieces, `[[`, "distributions"))
  manifests <- do.call(rbind, lapply(pieces, `[[`, "manifests"))
  coverage <- do.call(rbind, lapply(pieces, `[[`, "feature_coverage"))
  scores <- do.call(rbind, lapply(split(predictions, predictions$track_id), function(track_predictions) {
    track_id <- unique(as.character(track_predictions$track_id))
    track_fixtures <- fixtures[as.character(fixtures$track_id) == track_id, , drop = FALSE]
    score_benchmark_fixtures(
      track_predictions, track_fixtures, distributions,
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
  headline <- comparisons[
    comparisons$track_id == "updating" &
      comparisons$baseline_id == "open_nb_incumbent" &
      comparisons$diagnostic == "equal_tournament_headline",
    , drop = FALSE
  ]
  headline <- headline[match(candidate_order, headline$candidate_id), , drop = FALSE]
  if (anyNA(headline$candidate_id)) stop("candidate headline evidence is incomplete", call. = FALSE)
  complexity <- protocol$model_registry$complexity_rank[
    match(candidate_order, protocol$model_registry$candidate_id)
  ]
  best_estimate <- min(headline$candidate_estimate)
  selection_evidence <- data.frame(
    candidate_id = candidate_order,
    updating_equal_tournament_rps = headline$candidate_estimate,
    practically_non_inferior = headline$candidate_estimate <= best_estimate + 0.001,
    complexity_rank = complexity,
    evidence_sha256 = vapply(seq_len(nrow(headline)), function(index) {
      .phase10_runner_content_sha256(headline[index, , drop = FALSE])
    }, character(1)),
    stringsAsFactors = FALSE
  )
  independent <- selection_evidence$updating_equal_tournament_rps[
    selection_evidence$candidate_id == "poisson_team_ridge_elo"
  ]
  dependence_ids <- c(
    "poisson_team_ridge_elo", "poisson_team_ridge_elo_dc",
    "poisson_team_ridge_elo_bivpois"
  )
  dependence_evidence <- selection_evidence[
    match(dependence_ids, selection_evidence$candidate_id), , drop = FALSE
  ]
  dependence_evidence$updating_rps_delta <-
    dependence_evidence$updating_equal_tournament_rps - independent
  for (column in c(
    "brier_veto", "log_loss_veto", "calibration_veto",
    "fold_breadth_veto", "stability_veto"
  )) dependence_evidence[[column]] <- FALSE
  .phase10_runner_source("select_dependence_representative", "R/evaluation/challenger_selection.R")
  dependence <- select_dependence_representative(dependence_evidence)
  shortlist <- build_statistical_shortlist(
    selection_evidence, dependence$representative_id
  )
  protocol_hashes <- .phase10_runner_protocol_file_hashes()
  comparisons$selection_protocol_sha256 <- unname(
    protocol_hashes[["selection_protocol_sha256"]]
  )
  shortlist$selection_protocol_sha256 <- unname(protocol_hashes[["selection_protocol_sha256"]])
  names(shortlist)[names(shortlist) == "slot"] <- "shortlist_slot"
  names(shortlist)[names(shortlist) == "candidate_id"] <- "challenger_id"
  shortlist <- shortlist[c(
    "shortlist_slot", "challenger_id", "evidence_sha256", "selection_basis",
    "selection_protocol_sha256", "non_exclusive"
  )]
  names(comparisons)[names(comparisons) == "candidate_id"] <- "challenger_id"
  environment_value <- function(name) {
    value <- environment[[name]]
    if (is.null(value)) "" else as.character(value)
  }
  run_manifest <- data.frame(
    schema_version = "phase10-challenger-bundle-v1",
    run_id = "phase10-statistical-challengers",
    source_git_sha = trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
    r_version = as.character(getRversion()),
    canonical_process_mode = "fresh_normal_reversed",
    model_track_workers = worker_count,
    candidate_count = 7L, track_count = 2L, edition_count = 12L,
    phase09_bundle_sha256 = parent_bundle$bundle_sha256,
    phase09_checksum_self_sha256 = parent_bundle$parent_hashes[["phase09_checksum_self_sha256"]],
    phase09_parent_graph_sha256 = parent_bundle$parent_hashes[["phase09_parent_graph_sha256"]],
    glmnet_index_sha256 = environment_value("index_sha256"),
    glmnet_metadata_sha256 = environment_value("metadata_sha256"),
    glmnet_dependency_inventory_sha256 = environment_value("dependency_inventory_sha256"),
    glmnet_archive_sha256 = environment_value("archive_sha256"),
    glmnet_installed_content_sha256 = environment_value("installed_content_sha256"),
    matrix_installed_content_sha256 = environment_value("matrix_installed_content_sha256"),
    phase10_model_registry_sha256 = unname(protocol_hashes[["model_registry_sha256"]]),
    phase10_feature_contract_sha256 = unname(protocol_hashes[["feature_contract_sha256"]]),
    phase10_tuning_editions_sha256 = unname(protocol_hashes[["tuning_editions_sha256"]]),
    phase10_tuning_grid_sha256 = unname(protocol_hashes[["tuning_grid_sha256"]]),
    phase10_ablation_registry_sha256 = unname(protocol_hashes[["ablation_registry_sha256"]]),
    phase10_selection_protocol_sha256 = unname(protocol_hashes[["selection_protocol_sha256"]]),
    phase10_storage_preflight_sha256 = unname(protocol_hashes[["storage_preflight_sha256"]]),
    phase10_glmnet_provenance_sha256 = unname(protocol_hashes[["glmnet_provenance_sha256"]]),
    open_fixture_count = 630L, rich_fixture_count = 609L, selected_g = 40L,
    reproducible = FALSE, wc2026_sealed = TRUE, network_free = TRUE,
    research_only = TRUE, protected_paths_clean = TRUE, synthetic = FALSE,
    stringsAsFactors = FALSE
  )
  list(
    run_manifest = run_manifest, model_manifests = manifests,
    feature_coverage = coverage, fold_tuning = fold_tuning,
    fixture_predictions = predictions, score_distributions = distributions,
    fixture_scores = scores, benchmark_summaries = summaries,
    all_baseline_paired_comparisons = comparisons, shortlist = shortlist,
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
    protocol <- structure(
      protocol, class = c("validated_challenger_protocol", class(protocol))
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
    history <- .phase10_runner_prepare_history(history, protocol)
  }
  if (is.null(execution_engine)) execution_engine <- .phase10_default_execution_engine
  if (!is.function(execution_engine)) stop("execution_engine must be a function", call. = FALSE)
  extra_arguments <- list(...)
  if (!isTRUE(synthetic) && is.null(extra_arguments$settings_by_candidate)) {
    tune_one <- function(family) switch(
      family,
      penalized = tune_statistical_penalized_family(history, protocol, protocol$tournaments),
      dynamic = tune_statistical_dynamic_family(history, protocol, protocol$tournaments)
    )
    tuning_parts <- if (.Platform$OS.type != "windows") {
      parallel::mclapply(c("penalized", "dynamic"), tune_one, mc.cores = 2L)
    } else {
      lapply(c("penalized", "dynamic"), tune_one)
    }
    tuning <- .phase10_runner_compile_tuning(
      tuning_parts[[1L]], tuning_parts[[2L]], protocol, protocol$tournaments
    )
    extra_arguments$settings_by_candidate <- tuning$settings_by_candidate
    extra_arguments$fold_tuning <- tuning$fold_tuning
  }
  arguments <- list(
    history = history, synthetic = synthetic, protocol = protocol,
    environment = environment, parent_bundle = parent
  )
  arguments <- c(arguments, extra_arguments)
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
  if (is.data.frame(first$run_manifest) && "reproducible" %in% names(first$run_manifest)) {
    first$run_manifest$reproducible <- TRUE
  }
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
  if (anyDuplicated(candidate_ids) || !setequal(candidate_ids, .phase10_runner_candidates())) {
    stop("synthetic candidate identity drift", call. = FALSE)
  }
  evidence <- vapply(candidate_ids, function(id) .phase10_runner_sha256(id), character(1))
  shortlist_index <- c(1L, min(7L, length(candidate_ids)), min(5L, length(candidate_ids)))
  shortlist <- data.frame(
    shortlist_slot = c("best_proper_score", "simplest_non_inferior", "dependence_representative"),
    challenger_id = unname(candidate_ids[shortlist_index]),
    evidence_sha256 = unname(evidence[shortlist_index]),
    selection_basis = c(
      "lowest_updating_equal_tournament_rps",
      "lowest_complexity_practically_non_inferior",
      "registered_dependence_representative"
    ),
    selection_protocol_sha256 = .phase10_runner_sha256("synthetic-selection-protocol"),
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
    sample_distribution_ids = paste0(
      "synthetic__", paste(candidate_ids, collapse = "|synthetic__")
    ),
    sample_distribution_count = 7L,
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
    all_baseline_paired_comparisons = expand.grid(
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
    "benchmark_summaries", "all_baseline_paired_comparisons", "shortlist"
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

.phase10_runner_csv_rows <- function(path) {
  output <- suppressWarnings(system2("wc", c("-l", path), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  fields <- strsplit(trimws(output[[1L]]), "[[:space:]]+")[[1L]]
  lines <- suppressWarnings(as.integer(fields[[1L]]))
  if ((!is.null(status) && status != 0L) || is.na(lines) || lines < 1L) {
    stop("Could not stream Phase 10 CSV row count: ", path, call. = FALSE)
  }
  lines - 1L
}

.phase10_runner_order_distributions <- function(distributions) {
  distribution_ids <- as.character(distributions$score_distribution_id)
  candidates <- .phase10_runner_candidates()
  candidate_rows <- lapply(candidates, function(id) {
    which(startsWith(distribution_ids, paste0(id, "__")) |
      endsWith(distribution_ids, paste0("__", id)))
  })
  sample_ids <- vapply(seq_along(candidates), function(index) {
    id <- candidates[[index]]
    rows <- candidate_rows[[index]]
    ids <- unique(distribution_ids[rows])
    if (!length(ids)) stop("A candidate is missing score distributions", call. = FALSE)
    sort(ids, method = "radix")[[1L]]
  }, character(1))
  sample_rows <- lapply(seq_along(candidates), function(index) {
    candidate_rows[[index]][
      distribution_ids[candidate_rows[[index]]] == sample_ids[[index]]
    ]
  })
  sample_index <- unlist(sample_rows, use.names = FALSE)
  remaining_index <- unlist(lapply(seq_along(candidates), function(index) {
    setdiff(candidate_rows[[index]], sample_rows[[index]])
  }), use.names = FALSE)
  ordered <- distributions[c(sample_index, remaining_index), , drop = FALSE]
  rownames(ordered) <- NULL
  list(data = ordered, sample_ids = sample_ids)
}

.phase10_runner_report <- function(artifacts) {
  shortlist <- artifacts$shortlist
  comparisons <- artifacts$all_baseline_paired_comparisons
  shortlist_lines <- paste0(
    "- ", shortlist$shortlist_slot, ": `", shortlist$challenger_id,
    "` (evidence `", shortlist$evidence_sha256, "`)"
  )
  comparison_columns <- c(
    "challenger_id", "baseline_id", "track_id", "diagnostic",
    "comparison_panel_id", "delta", "paired_fixture_count"
  )
  comparison_lines <- if (all(comparison_columns %in% names(comparisons))) {
    headline <- comparisons[
      comparisons$track_id == "updating" &
        comparisons$diagnostic == "equal_tournament_headline",
      , drop = FALSE
    ]
    headline <- headline[order(
      headline$challenger_id, headline$baseline_id, method = "radix"
    ), , drop = FALSE]
    sprintf(
      "- `%s` vs `%s` on `%s`: equal-tournament RPS delta %.8f (%d paired fixtures)",
      headline$challenger_id, headline$baseline_id, headline$comparison_panel_id,
      headline$delta, headline$paired_fixture_count
    )
  } else {
    "- Synthetic contract fixture (no historical estimate)."
  }
  paste(
    "# Phase 10 Statistical Challenger Research Bundle",
    "",
    "This bundle contains deterministic pre-2026 historical research evidence only.",
    "",
    paste0("Candidates: ", length(unique(artifacts$model_manifests$candidate_id))),
    paste0("Paired comparison rows: ", nrow(comparisons)),
    "Comparison panels: open_core=630; feature_rich=609",
    "Score support: G=40",
    "",
    "## Three-slot research handoff",
    "",
    shortlist_lines,
    "",
    "The three slots are non-exclusive and carry forward historical evidence only.",
    "",
    "## Updating-track paired historical evidence",
    "",
    comparison_lines,
    sep = "\n"
  )
}

.phase10_runner_build_checksum <- function(stage, paths, artifacts) {
  artifact_names <- setdiff(names(paths), c("checksum_manifest"))
  relative <- substring(paths[artifact_names], nchar(stage) + 2L)
  rows <- vapply(artifact_names, function(name) {
    if (name == "statistical_challenger_report") return(NA_integer_)
    as.integer(nrow(artifacts[[name]]))
  }, integer(1))
  run <- artifacts$run_manifest[1L, , drop = FALSE]
  parent_columns <- if (isTRUE(as.logical(run$synthetic))) {
    "phase09_bundle_sha256"
  } else {
    c(
      "phase09_bundle_sha256", "phase09_checksum_self_sha256",
      "phase09_parent_graph_sha256", "glmnet_index_sha256",
      "glmnet_metadata_sha256", "glmnet_dependency_inventory_sha256",
      "glmnet_archive_sha256", "glmnet_installed_content_sha256",
      "matrix_installed_content_sha256", grep("^phase10_.*_sha256$", names(run), value = TRUE)
    )
  }
  parent_columns <- unique(parent_columns)
  if (!all(parent_columns %in% names(run)) || any(!grepl(
    "^[0-9a-f]{64}$", unlist(run[parent_columns], use.names = FALSE)
  ))) stop("Phase 10 run manifest parent graph is incomplete", call. = FALSE)
  parent_hash <- paste(
    paste(parent_columns, unlist(run[parent_columns], use.names = FALSE), sep = "="),
    collapse = ";"
  )
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

#' Materialize one complete Phase 10 candidate-run stage
#' @export
stage_statistical_challenger_bundle <- function(result, stage, validate = FALSE) {
  if (!is.list(result) || !isTRUE(result$reproducible)) {
    stop("only a reconciliation-authorized challenger result may be staged", call. = FALSE)
  }
  if (dir.exists(stage) || file.exists(stage)) {
    stop("Phase 10 stage path must not already exist", call. = FALSE)
  }
  dir.create(stage, recursive = TRUE, showWarnings = FALSE)
  artifacts <- .phase10_runner_artifacts(result)
  ordered_distributions <- .phase10_runner_order_distributions(artifacts$score_distributions)
  artifacts$score_distributions <- ordered_distributions$data
  artifacts$run_manifest$sample_distribution_ids <- paste(
    ordered_distributions$sample_ids, collapse = "|"
  )
  artifacts$run_manifest$sample_distribution_count <- length(ordered_distributions$sample_ids)
  paths <- phase10_output_paths(stage)
  for (name in setdiff(names(artifacts), "run_manifest")) {
    .phase10_runner_write_csv(
      artifacts[[name]], paths[[name]], preserve_order = name %in% c(
        "shortlist", "score_distributions"
      )
    )
  }
  .phase10_runner_write_csv(artifacts$run_manifest, paths[["run_manifest"]])
  dir.create(dirname(paths[["statistical_challenger_report"]]), recursive = TRUE, showWarnings = FALSE)
  writeLines(
    .phase10_runner_report(artifacts), paths[["statistical_challenger_report"]],
    useBytes = TRUE
  )
  artifacts$statistical_challenger_report <- .phase10_runner_report(artifacts)
  checksum <- .phase10_runner_build_checksum(stage, paths, artifacts)
  .phase10_runner_write_csv(checksum, paths[["checksum_manifest"]])
  if (isTRUE(validate)) {
    validator <- if (isTRUE(result$synthetic)) {
      smoke_statistical_challenger_bundle
    } else {
      validate_statistical_challenger_bundle
    }
    validator(stage)
  }
  invisible(unname(paths))
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
  stage_statistical_challenger_bundle(result, stage, validate = TRUE)
  .phase10_runner_source("benchmark_runner_install_staged_bundle", "R/benchmark/runner.R")
  validator <- if (isTRUE(result$synthetic)) {
    smoke_statistical_challenger_bundle
  } else {
    validate_statistical_challenger_bundle
  }
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
    if (!identical(as.numeric(file.info(path)$size), as.numeric(body$bytes[index]))) {
      stop("Phase 10 artifact byte count mismatch: ", body$artifact[index], call. = FALSE)
    }
    if (isTRUE(deep) && grepl("\\.csv$", path) && !is.na(body$rows[index])) {
      row_count <- .phase10_runner_csv_rows(path)
      if (!identical(as.integer(row_count), as.integer(body$rows[index]))) {
        stop("Phase 10 artifact row count mismatch: ", body$artifact[index], call. = FALSE)
      }
    }
  }
  read_csv <- function(name) utils::read.csv(paths[[name]], stringsAsFactors = FALSE, check.names = FALSE)
  run <- read_csv("run_manifest")
  if (nrow(run) != 1L || !identical(as.integer(run$open_fixture_count), 630L) ||
      !identical(as.integer(run$rich_fixture_count), 609L) ||
      !identical(as.integer(run$selected_g), 40L) ||
      (!isTRUE(as.logical(run$synthetic)) && (
        !identical(as.integer(run$candidate_count), 7L) ||
        !identical(as.integer(run$track_count), 2L) ||
        !identical(as.integer(run$edition_count), 12L) ||
        !identical(as.integer(run$model_track_workers), 2L) ||
        !identical(as.character(run$canonical_process_mode), "fresh_normal_reversed")
      ))) {
    stop("Phase 10 run declaration drift", call. = FALSE)
  }
  expected_parent <- "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069"
  parent_columns <- if (isTRUE(as.logical(run$synthetic))) {
    "phase09_bundle_sha256"
  } else {
    c(
      "phase09_bundle_sha256", "phase09_checksum_self_sha256",
      "phase09_parent_graph_sha256", "glmnet_index_sha256",
      "glmnet_metadata_sha256", "glmnet_dependency_inventory_sha256",
      "glmnet_archive_sha256", "glmnet_installed_content_sha256",
      "matrix_installed_content_sha256", grep("^phase10_.*_sha256$", names(run), value = TRUE)
    )
  }
  expected_parent_graph <- paste(
    paste(parent_columns, unlist(run[parent_columns], use.names = FALSE), sep = "="),
    collapse = ";"
  )
  if (!identical(as.character(run$phase09_bundle_sha256), expected_parent) ||
      any(as.character(checksum$parent_hashes) != expected_parent_graph)) {
    stop("Phase 10 immutable parent identity drift", call. = FALSE)
  }
  required_flags <- c(
    "reproducible", "wc2026_sealed", "network_free", "research_only",
    "protected_paths_clean"
  )
  if (any(!vapply(run[required_flags], function(value) isTRUE(as.logical(value[[1]])), logical(1)))) {
    stop("Phase 10 protected-boundary flags are not accepted", call. = FALSE)
  }
  if (!isTRUE(as.logical(run$synthetic))) {
    protocol_hashes <- .phase10_runner_protocol_file_hashes()
    manifest_protocol <- unlist(
      run[paste0("phase10_", names(protocol_hashes))], use.names = FALSE
    )
    if (!identical(unname(manifest_protocol), unname(protocol_hashes))) {
      stop("Phase 10 protocol parent identity drift", call. = FALSE)
    }
    .phase10_runner_source("require_challenger_environment", "R/benchmark/challenger_preflight.R")
    environment <- require_challenger_environment(file.path(
      .phase10_runner_root(), "data", "benchmark", "phase10", "glmnet_provenance.csv"
    ))
    environment_map <- c(
      glmnet_index_sha256 = "index_sha256",
      glmnet_metadata_sha256 = "metadata_sha256",
      glmnet_dependency_inventory_sha256 = "dependency_inventory_sha256",
      glmnet_archive_sha256 = "archive_sha256",
      glmnet_installed_content_sha256 = "installed_content_sha256",
      matrix_installed_content_sha256 = "matrix_installed_content_sha256"
    )
    if (any(vapply(names(environment_map), function(column) {
      !identical(as.character(run[[column]]), as.character(environment[[environment_map[[column]]]]))
    }, logical(1)))) stop("Phase 10 installed dependency provenance drift", call. = FALSE)
    declared_rows <- stats::setNames(as.integer(body$rows), as.character(body$artifact))
    if (!identical(declared_rows[["fixture_predictions"]], 8820L) ||
        !identical(declared_rows[["score_distributions"]], 14826420L)) {
      stop("Phase 10 declared canonical row totals drift", call. = FALSE)
    }
  }
  manifests <- read_csv("model_manifests")
  candidate_column <- if ("candidate_id" %in% names(manifests)) "candidate_id" else "model_id"
  if (!setequal(unique(as.character(manifests[[candidate_column]])), .phase10_runner_candidates())) {
    stop("Phase 10 candidate identity drift", call. = FALSE)
  }
  shortlist <- read_csv("shortlist")
  .phase10_runner_source("validate_statistical_shortlist", "R/evaluation/challenger_selection.R")
  validate_statistical_shortlist(shortlist)
  boundary_pattern <- "promot|release|winner|final_holdout"
  research_tables <- lapply(
    c("benchmark_summaries", "all_baseline_paired_comparisons", "shortlist"), read_csv
  )
  if (any(vapply(research_tables, function(table) {
    any(grepl(boundary_pattern, names(table), ignore.case = TRUE))
  }, logical(1)))) {
    stop("Phase 10 research evidence crossed its decision-authority boundary", call. = FALSE)
  }
  report_text <- readLines(paths[["statistical_challenger_report"]], warn = FALSE)
  if (any(grepl("promot|release|winner|final_holdout|wc2026", report_text, ignore.case = TRUE))) {
    stop("Phase 10 research report crossed its control boundary", call. = FALSE)
  }
  sample_count <- 7L * 1681L
  distributions <- if (isTRUE(deep)) {
    read_csv("score_distributions")
  } else {
    utils::read.csv(
      paths[["score_distributions"]], stringsAsFactors = FALSE,
      check.names = FALSE, nrows = sample_count
    )
  }
  required_distribution <- c("score_distribution_id", "home_goals", "away_goals", "probability")
  if (!all(required_distribution %in% names(distributions))) {
    stop("Phase 10 distribution schema drift", call. = FALSE)
  }
  sample_ids <- strsplit(as.character(run$sample_distribution_ids), "|", fixed = TRUE)[[1L]]
  sampled <- split(distributions, distributions$score_distribution_id)[sample_ids]
  if (!length(sampled) || any(vapply(sampled, function(rows) {
    nrow(rows) != 1681L || max(rows$home_goals) != 40L || max(rows$away_goals) != 40L ||
      abs(sum(rows$probability) - 1) > 1e-10
  }, logical(1)))) stop("Phase 10 G=40 distribution sample failed", call. = FALSE)
  comparisons <- read_csv("all_baseline_paired_comparisons")
  protocol_links_valid <- isTRUE(as.logical(run$synthetic)) || (
    "selection_protocol_sha256" %in% names(comparisons) &&
      "selection_protocol_sha256" %in% names(shortlist) &&
      all(as.character(comparisons$selection_protocol_sha256) ==
        as.character(run$phase10_selection_protocol_sha256)) &&
      all(as.character(shortlist$selection_protocol_sha256) ==
        as.character(run$phase10_selection_protocol_sha256))
  )
  if (!setequal(unique(as.character(comparisons$baseline_id)), .phase10_runner_baselines()) ||
      !setequal(unique(as.character(comparisons$track_id)), c("frozen", "updating")) ||
      !protocol_links_valid) {
    stop("Phase 10 all-baseline comparison coverage drift", call. = FALSE)
  }
  if (isTRUE(deep) && !isTRUE(as.logical(run$synthetic))) {
    if (nrow(unique(comparisons[c("challenger_id", "baseline_id", "track_id")])) != 70L) {
      stop("Phase 10 deep comparison identity count drift", call. = FALSE)
    }
    predictions <- read_csv("fixture_predictions")
    coverage <- read_csv("feature_coverage")
    if (nrow(predictions) != 8820L ||
        !setequal(unique(as.character(predictions$model_id)), .phase10_runner_candidates()) ||
        !setequal(unique(as.character(predictions$track_id)), c("frozen", "updating")) ||
        !setequal(
          unique(as.character(predictions$feature_coverage_id)),
          unique(as.character(coverage$feature_coverage_id))
        )) {
      stop("Phase 10 prediction-to-feature evidence graph drift", call. = FALSE)
    }
    distribution_runs <- rle(as.character(distributions$score_distribution_id))
    if (length(distribution_runs$values) != 8820L ||
        anyDuplicated(distribution_runs$values) ||
        any(distribution_runs$lengths != 1681L)) {
      stop("Phase 10 deep score distribution identity drift", call. = FALSE)
    }
    expected_home <- rep.int(0:40, times = 41L)
    expected_away <- rep.int(0:40, each = 41L)
    home_matrix <- matrix(as.integer(distributions$home_goals), nrow = 1681L)
    away_matrix <- matrix(as.integer(distributions$away_goals), nrow = 1681L)
    probability_matrix <- matrix(as.numeric(distributions$probability), nrow = 1681L)
    if (any(home_matrix != expected_home) || any(away_matrix != expected_away) ||
        any(!is.finite(probability_matrix)) || any(probability_matrix < 0) ||
        any(abs(colSums(probability_matrix) - 1) > 1e-10)) {
      stop("Phase 10 deep score grid validation failed", call. = FALSE)
    }
  }
  tuning <- read_csv("fold_tuning")
  if (!isTRUE(as.logical(run$synthetic)) && (nrow(tuning) != 168L ||
      !setequal(unique(as.character(tuning$candidate_id)), .phase10_runner_candidates()) ||
      !setequal(unique(as.character(tuning$track_id)), c("frozen", "updating")) ||
      any(!as.logical(tuning$shared_between_tracks)) ||
      any(!as.logical(tuning$strict_prior_only)))) {
    stop("Phase 10 fold tuning evidence is incomplete", call. = FALSE)
  }
  target_source <- readLines(file.path(.phase10_runner_root(), "_targets.R"), warn = FALSE)
  target_text <- paste(target_source, collapse = "\n")
  required_targets <- c(
    "benchmark_phase10_registry_files", "benchmark_phase10_registries",
    "benchmark_phase10_predictions", "benchmark_phase10_scores",
    "benchmark_phase10_comparisons", "benchmark_phase10_bundle_files"
  )
  if (!all(vapply(required_targets, grepl, logical(1), x = target_text, fixed = TRUE)) ||
      grepl("evaluate_promotion\\s*\\(", paste(target_source[592:712], collapse = "\n"))) {
    stop("Phase 10 target ancestry crossed its control boundary", call. = FALSE)
  }
  protected <- c(
    "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
    "outputs/dashboard", "outputs/evaluation/wc2026"
  )
  git_status <- suppressWarnings(system2(
    "git", c("diff", "--quiet", "--", protected), stdout = FALSE, stderr = FALSE
  ))
  if (!identical(as.integer(git_status), 0L)) {
    stop("Phase 10 protected paths contain tracked changes", call. = FALSE)
  }
  fold_editions <- if ("diagnostic" %in% names(comparisons)) {
    unique(as.character(comparisons$edition_id[comparisons$diagnostic == "fold"]))
  } else {
    character()
  }
  n_editions <- if (isTRUE(as.logical(run$synthetic))) 12L else length(fold_editions)
  if (!identical(as.integer(n_editions), 12L)) {
    stop("Phase 10 edition coverage drift", call. = FALSE)
  }
  list(
    valid = TRUE, n_editions = 12L, n_candidates = 7L, open_fixture_count = 630L,
    rich_fixture_count = 609L, score_support_max = 40L,
    reproducible = TRUE, wc2026_sealed = TRUE, research_only = TRUE,
    promotion_free = TRUE, targets_isolated = TRUE,
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
