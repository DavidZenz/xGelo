invisible(source("_targets.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    "usage: phase10_canonical_run.R <normal|reversed> <stage> ",
    "<penalized_rds> <dynamic_rds> <worker_count>",
    call. = FALSE
  )
}

order_id <- args[[1L]]
stage <- args[[2L]]
penalized_path <- args[[3L]]
dynamic_path <- args[[4L]]
worker_count <- as.integer(args[[5L]])
if (!order_id %in% c("normal", "reversed")) {
  stop("invalid candidate order", call. = FALSE)
}

phase09_dir <- "data/benchmark/phase09"
phase10_dir <- "data/benchmark/phase10"
environment <- require_challenger_environment(
  file.path(phase10_dir, "glmnet_provenance.csv")
)
protocol <- load_and_validate_challenger_protocol(phase10_dir)
protocol <- structure(
  protocol, class = c("validated_challenger_protocol", class(protocol))
)
protocol$panel_fixtures <- read.csv(
  file.path(phase09_dir, "panel_fixtures.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
protocol$tournaments <- read.csv(
  file.path(phase09_dir, "tournaments.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
registries <- load_benchmark_registries(phase09_dir)
inputs <- benchmark_runner_load_inputs(phase09_dir)
parent <- load_phase09_parent_bundle(
  "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"
)
history <- read.csv(
  "data/processed/goal_training_features_hybrid.csv", stringsAsFactors = FALSE
)
validate_forecast_feature_evidence(
  history, inputs$feature_contract,
  derived_mappings = c(
    elo_difference_for_team = "elo_diff",
    venue_advantage_for_team = "elo_diff"
  )
)
history <- .phase10_runner_prepare_history(history, protocol)
history <- history[
  as.Date(history$actual_completion_date) <= max(as.Date(
    registries$fixtures$actual_completion_date
  )),
  , drop = FALSE
]
invisible(guard_benchmark_purpose(history, "candidate_selection"))
fixtures <- do.call(rbind, lapply(c("frozen", "updating"), function(track_id) {
  benchmark_runner_track_fixtures(
    registries$fixtures, registries$tournaments, registries$boundaries,
    registries$teams, history, track_id, inputs$feature_contract
  )
}))
tuning <- .phase10_runner_compile_tuning(
  readRDS(penalized_path), readRDS(dynamic_path), protocol, registries$tournaments
)
candidate_order <- .phase10_runner_candidates()
if (order_id == "reversed") candidate_order <- rev(candidate_order)
started <- Sys.time()
result <- .phase10_default_execution_engine(
  candidate_order = candidate_order, history = history, fixtures = fixtures,
  seed_registry = inputs$seed_registry, protocol = protocol,
  settings_by_candidate = tuning$settings_by_candidate,
  fold_tuning = tuning$fold_tuning, parent_bundle = parent,
  environment = environment, worker_count = worker_count
)
.phase10_runner_validate_result(result, synthetic = FALSE)
result$run_manifest$reproducible <- TRUE
result$reproducible <- TRUE
result$synthetic <- FALSE
stage_statistical_challenger_bundle(result, stage, validate = FALSE)
cat(sprintf(
  "CANONICAL_STAGE_OK order=%s candidates=%d predictions=%d distributions=%d elapsed=%.3f stage=%s\n",
  order_id, length(candidate_order), nrow(result$fixture_predictions),
  nrow(result$score_distributions),
  as.numeric(difftime(Sys.time(), started, units = "secs")), stage
))
