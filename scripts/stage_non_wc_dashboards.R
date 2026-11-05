#!/usr/bin/env Rscript

# Fixed-production adapter and atomic three-route staging entry point. It does
# not acquire sources, change owner authority, run Git or touch WC routes.
non_wc_file <- commandArgs(trailingOnly = FALSE)
non_wc_file <- non_wc_file[startsWith(non_wc_file, "--file=")]
non_wc_root <- if (length(non_wc_file)) dirname(dirname(normalizePath(gsub("~+~", " ",
  sub("^--file=", "", non_wc_file[[1L]]), fixed = TRUE), winslash = "/", mustWork = TRUE))) else getwd()
non_wc_root <- normalizePath(non_wc_root, winslash = "/", mustWork = TRUE)
while (!file.exists(file.path(non_wc_root, "R/dashboard/non_wc_publication.R"))) {
  parent <- dirname(non_wc_root)
  if (identical(parent, non_wc_root)) stop("Could not locate the xGelo project for dashboard staging")
  non_wc_root <- parent
}
non_wc_load_runtime <- function(project_root) {
  before <- getwd(); setwd(project_root); on.exit(setwd(before), add = TRUE)
  runtime <- new.env(parent = globalenv())
  for (path in c("scripts/refresh_competition_dashboards.R", "scripts/render_ucl_live_dashboard.R",
      "R/competition/nl_simulation_precision.R", "R/dashboard/non_wc_publication.R"))
    sys.source(file.path(project_root, path), runtime)
  runtime
}
non_wc_runtime <- non_wc_load_runtime(non_wc_root)

stage_non_wc_dashboards_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(stage_root = NULL, publish = FALSE, cl_forecasts = "approved")
  i <- 1L
  while (i <= length(args)) {
    value <- args[[i]]
    if (identical(value, "--publish")) options$publish <- TRUE else if (identical(value, "--stage-root")) {
      i <- i + 1L
      if (i > length(args) || !is.null(options$stage_root)) stop("One --stage-root value is required")
      options$stage_root <- args[[i]]
    } else if (grepl("^--cl-forecasts=(approved|disabled)$", value)) options$cl_forecasts <- sub("^--cl-forecasts=", "", value) else
      stop("Use --stage-root <absolute> [--cl-forecasts=approved|disabled] [--publish]")
    i <- i + 1L
  }
  if (is.null(options$stage_root) || !startsWith(options$stage_root, "/")) stop("An absolute --stage-root is required")
  stage <- normalizePath(options$stage_root, winslash = "/", mustWork = FALSE)
  public <- file.path(non_wc_root, "docs/competitions")
  if (identical(stage, public) || startsWith(stage, paste0(public, "/"))) stop("Stage must be separate from the public competition root")
  if (dir.exists(stage) && length(list.files(stage, all.files = TRUE, no.. = TRUE))) stop("Stage root must be empty")
  before <- getwd(); setwd(non_wc_root); on.exit(setwd(before), add = TRUE)
  result <- non_wc_runtime$phase21_non_wc_build(stage, non_wc_root,
    publish = options$publish, cl_forecasts = options$cl_forecasts)
  cat("NON_WC_DASHBOARDS status=validated batch=", result$batch_id,
    " routes=3 publish=", options$publish, " stage=", stage, "\n", sep = "")
  invisible(result)
}

if (sys.nframe() == 0L) stage_non_wc_dashboards_main()
