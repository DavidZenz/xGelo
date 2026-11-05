#!/usr/bin/env Rscript
# Validate immutable publication bytes/readiness without rebuilding forecasts.
script <- commandArgs(trailingOnly = FALSE)
script <- script[startsWith(script, "--file=")]
if (length(script) != 1L) stop("Use the standalone publication validator")
root <- dirname(dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", script), fixed = TRUE), mustWork = TRUE)))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || !identical(args[[1L]], "--public-root") || !startsWith(args[[2L]], "/"))
  stop("Use --public-root <absolute validated candidate directory>")
source(file.path(root, "scripts/stage_non_wc_dashboards.R"))
validated <- non_wc_runtime$phase21_non_wc_validate_production_publication(args[[2L]], root,
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
cat("NON_WC_PUBLICATION validated=true batch=", validated$batch_id,
  " files=", length(validated$files), "\n", sep = "")
