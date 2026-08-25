invisible(source("_targets.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop(
    "usage: phase10_reconcile_publish.R <normal_stage> <reversed_stage> ",
    "<output_dir> <penalized_rds> <dynamic_rds>",
    call. = FALSE
  )
}

normal_stage <- args[[1L]]
reversed_stage <- args[[2L]]
output_dir <- args[[3L]]
penalized_path <- args[[4L]]
dynamic_path <- args[[5L]]

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
  file.path("outputs", "benchmarks", "rolling_tournaments", "phase09-baselines-frozen")
)
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

# Exercise every registered adapter on one real edition before accepting the stages.
preflight_edition <- as.character(protocol$tuning_editions$outer_edition_id[[1L]])
preflight_fixtures <- fixtures[
  as.character(fixtures$edition_id) == preflight_edition,
  , drop = FALSE
]
if (!nrow(preflight_fixtures)) {
  stop("Phase 10 preflight edition has no fixtures: ", preflight_edition, call. = FALSE)
}
.phase10_runner_validate_fixture_seeds(preflight_fixtures, inputs$seed_registry)
candidate_order <- .phase10_runner_candidates()
for (track_id in c("frozen", "updating")) {
  track_fixtures <- preflight_fixtures[
    as.character(preflight_fixtures$track_id) == track_id,
    , drop = FALSE
  ]
  fit_cache <- new.env(parent = emptyenv())
  mean_cache <- new.env(parent = emptyenv())
  for (candidate_id in candidate_order) {
    settings <- tuning$settings_by_candidate[[candidate_id]]
    if (is.list(settings) && !is.null(names(settings)) &&
        preflight_edition %in% names(settings)) {
      settings <- settings[[preflight_edition]]
    }
    if (is.null(settings)) settings <- list()
    adapter <- run_registered_challenger_adapter(
      candidate_id, history, track_fixtures, inputs$seed_registry,
      support_max = 40L, settings = settings, protocol = protocol,
      fit_cache = fit_cache, mean_cache = mean_cache
    )
    required <- c("predictions", "distributions", "manifests", "feature_coverage")
    if (!all(required %in% names(adapter))) {
      stop("Phase 10 preflight adapter contract is incomplete: ", candidate_id, call. = FALSE)
    }
    if (nrow(adapter$predictions) != nrow(track_fixtures) ||
        nrow(adapter$distributions) != nrow(track_fixtures) * 1681L ||
        !nrow(adapter$manifests) || !nrow(adapter$feature_coverage)) {
      stop("Phase 10 preflight cardinality drift: ", candidate_id, "/", track_id, call. = FALSE)
    }
  }
}
cat(sprintf(
  "PHASE10_PREFLIGHT_OK edition=%s candidates=%d tracks=%d\n",
  preflight_edition, length(candidate_order), 2L
))

stage_check <- function(stage) {
  if (!dir.exists(stage)) stop("Phase 10 stage is missing: ", stage, call. = FALSE)
  validation <- smoke_statistical_challenger_bundle(stage)
  checksum_path <- file.path(stage, "manifests", "checksum_manifest.csv")
  list(
    validation = validation,
    checksum_bytes = readBin(
      checksum_path, what = "raw", n = as.integer(file.info(checksum_path)$size)
    )
  )
}

normal <- stage_check(normal_stage)
reversed <- stage_check(reversed_stage)
if (!identical(normal$checksum_bytes, reversed$checksum_bytes)) {
  stop("normal and reversed Phase 10 checksum manifests differ", call. = FALSE)
}
cat("PHASE10_RECONCILIATION_OK checksum_manifests=byte_identical\n")

dir.create(dirname(output_dir), recursive = TRUE, showWarnings = FALSE)
published <- benchmark_runner_install_staged_bundle(
  normal_stage, output_dir, validate_statistical_challenger_bundle
)
if (!isTRUE(published$valid) || !isTRUE(published$reproducible) ||
    !isTRUE(published$parents_valid) || !isTRUE(published$wc2026_sealed) ||
    !isTRUE(published$research_only)) {
  stop("Phase 10 published bundle failed acceptance flags", call. = FALSE)
}
cat(sprintf(
  "PHASE10_PUBLISHED_OK output=%s candidates=%d editions=%d predictions=%d distributions=%d\n",
  output_dir, published$n_candidates, published$n_editions,
  published$open_fixture_count * published$n_candidates * 2L,
  published$open_fixture_count * published$n_candidates * 2L *
    (published$score_support_max + 1L)^2L
))
