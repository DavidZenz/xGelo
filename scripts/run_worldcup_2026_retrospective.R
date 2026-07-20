#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

read_option <- function(name, default) {
  index <- match(name, args)
  if (is.na(index)) return(default)
  if (index == length(args)) stop("Missing value for ", name)
  args[index + 1L]
}

source_ref <- read_option("--source-ref", "HEAD")
output_dir <- read_option("--output-dir", "outputs/evaluation/wc2026")
bootstrap_reps <- as.integer(read_option("--bootstrap-reps", "2000"))
seed <- as.integer(read_option("--seed", "20260720"))
if (!is.finite(bootstrap_reps) || bootstrap_reps < 1L) stop("--bootstrap-reps must be positive")
if (!is.finite(seed)) stop("--seed must be an integer")

source("R/evaluation/proper_scores.R")
source("R/evaluation/worldcup_ledger.R")
source("R/evaluation/worldcup_retrospective.R")
source("R/visualization/worldcup_retrospective.R")

ledger_bundle <- write_forecast_ledger_bundle(source_ref = source_ref, output_dir = output_dir)
distributions <- readRDS(file.path(output_dir, "selected_distributions.rds"))
match_scores <- score_worldcup_matches(ledger_bundle$selected, distributions$scorelines)
aggregate_scores <- aggregate_worldcup_scores(
  match_scores, n_official = nrow(ledger_bundle$fixtures),
  reps = bootstrap_reps, seed = seed
)
calibration_bins <- make_calibration_bins(ledger_bundle$selected)
advancement_scores <- score_knockout_advancement(ledger_bundle$selected)
anchors <- select_stage_reach_anchors(ledger_bundle$selected, distributions$stage, ledger_bundle$fixtures)
stage_reach_scores <- score_stage_reach(anchors, distributions$stage, ledger_bundle$fixtures)
write_worldcup_score_bundle(
  match_scores, aggregate_scores, calibration_bins, advancement_scores,
  stage_reach_scores, output_dir
)

figure_paths <- generate_worldcup_retrospective_figures(output_dir)
output_dir_abs <- normalizePath(output_dir, mustWork = TRUE)
report_path <- file.path(output_dir_abs, "worldcup_2026_retrospective.html")
if (!requireNamespace("rmarkdown", quietly = TRUE)) stop("rmarkdown is required")
rmarkdown::render(
  input = "notebooks/worldcup_2026_retrospective.Rmd",
  output_file = basename(report_path), output_dir = dirname(report_path),
  params = list(output_dir = output_dir_abs),
  envir = new.env(parent = globalenv()), quiet = TRUE
)

source_sha <- run_git_read(c("rev-parse", source_ref))[1]
manifest_files <- unique(c(
  unname(ledger_bundle$paths),
  file.path(output_dir, c(
    "match_scores.csv", "aggregate_scores.csv", "calibration_bins.csv",
    "advancement_scores.csv", "stage_reach_scores.csv", "score_manifest.csv"
  )),
  unname(figure_paths), report_path
))
manifest_files <- manifest_files[file.exists(manifest_files)]
final_manifest <- data.frame(
  path = manifest_files,
  bytes = as.numeric(file.info(manifest_files)$size),
  md5 = unname(tools::md5sum(manifest_files)),
  source_ref = source_ref,
  source_sha = source_sha,
  bootstrap_reps = bootstrap_reps,
  seed = seed,
  stringsAsFactors = FALSE
)
write.csv(final_manifest, file.path(output_dir, "retrospective_manifest.csv"), row.names = FALSE)

headline <- aggregate_scores[
  aggregate_scores$sample == "strict" & aggregate_scores$view == "latest_valid" &
    aggregate_scores$metric == "rps" & aggregate_scores$cut_type == "overall", , drop = FALSE
]
cat("World Cup retrospective written to", normalizePath(report_path), "\n")
cat("Source SHA:", source_sha, "\n")
cat("Strict coverage:", headline$n_scored, "/", headline$n_official, "\n")
cat("Strict latest-valid RPS:", sprintf("%.6f", headline$estimate), "\n")
