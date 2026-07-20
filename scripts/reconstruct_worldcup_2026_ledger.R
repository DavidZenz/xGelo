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
max_commits <- as.numeric(read_option("--max-commits", "Inf"))

source("R/evaluation/worldcup_ledger.R")

result <- write_forecast_ledger_bundle(
  source_ref = source_ref,
  output_dir = output_dir,
  max_commits = max_commits
)

cat("World Cup ledger written to", normalizePath(output_dir), "\n")
cat("Official fixtures:", nrow(result$fixtures), "\n")
cat("Forecast occurrences:", nrow(result$ledger), "\n")
cat("Selected views:", nrow(result$selected), "\n")

