invisible(source("_targets.R"))

output_dir <- "data/cache/phase10-tuning"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

phase09_dir <- "data/benchmark/phase09"
phase10_dir <- "data/benchmark/phase10"
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
inputs <- benchmark_runner_load_inputs(phase09_dir)
history <- read.csv(
  "data/processed/goal_training_features_hybrid.csv",
  stringsAsFactors = FALSE
)
validate_forecast_feature_evidence(
  history, inputs$feature_contract,
  derived_mappings = c(
    elo_difference_for_team = "elo_diff",
    venue_advantage_for_team = "elo_diff"
  )
)
history <- .phase10_runner_prepare_history(history, protocol)
invisible(guard_benchmark_purpose(history, "candidate_selection"))

started <- Sys.time()
penalized <- tune_statistical_penalized_family(
  history, protocol, protocol$tournaments
)
saveRDS(penalized, file.path(output_dir, "phase10_penalized_all.rds"))
cat(sprintf(
  "PHASE10_TUNING_PENALIZED_OK elapsed=%.3f path=%s\n",
  as.numeric(difftime(Sys.time(), started, units = "secs")),
  file.path(output_dir, "phase10_penalized_all.rds")
))

dynamic_started <- Sys.time()
dynamic <- tune_statistical_dynamic_family(
  history, protocol, protocol$tournaments
)
saveRDS(dynamic, file.path(output_dir, "phase10_dynamic_all.rds"))
cat(sprintf(
  "PHASE10_TUNING_DYNAMIC_OK elapsed=%.3f path=%s\n",
  as.numeric(difftime(Sys.time(), dynamic_started, units = "secs")),
  file.path(output_dir, "phase10_dynamic_all.rds")
))
cat(sprintf(
  "PHASE10_TUNING_CACHE_OK elapsed=%.3f output_dir=%s\n",
  as.numeric(difftime(Sys.time(), started, units = "secs")),
  output_dir
))
