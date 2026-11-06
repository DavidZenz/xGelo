# Explicit test-only helper. Production code never reads these environment vars.
ucl_sparse_code_test_project <- function(origin) {
  origin <- normalizePath(origin, winslash = "/", mustWork = TRUE)
  cli <- "scripts/build_uefa_champions_league_outcomes.R"
  lines <- readLines(file.path(origin, cli), warn = FALSE)
  selected <- grepl('^phase20_ucl_source\\("[A-Za-z0-9_./]+"\\)$', lines)
  modules <- sub('^phase20_ucl_source\\("([A-Za-z0-9_./]+)"\\)$', '\\1', lines[selected])
  required <- c("R/competition/ucl_live_outcome_reader.R", "R/competition/ucl_production_runtime.R",
    "R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R", "R/dashboard/ucl_persisted_outcome_payload.R")
  paths <- unique(c(cli, modules, required))
  if (!length(modules) || any(grepl("(^|/)\\.\\.(/|$)", paths)) ||
      any(!file.exists(file.path(origin, paths)))) stop("Sparse CL test code inventory incomplete")
  project <- tempfile("ucl-sparse-code-project-"); dir.create(project)
  dir.create(file.path(project, ".planning"))
  for (relative in paths) {
    target <- file.path(project, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(origin, relative), target))
  }
  withr::defer(unlink(project, recursive = TRUE), envir = testthat::teardown_env())
  normalizePath(project, winslash = "/", mustWork = TRUE)
}

ucl_sparse_test_code_origin <- function(variable) {
  root <- Sys.getenv(variable, unset = "")
  if (nzchar(root)) return(normalizePath(root, winslash = "/", mustWork = TRUE))
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(root, "R/competition/ucl_production_runtime.R"))) {
    parent <- dirname(root)
    if (identical(parent, root)) stop("CL test code origin missing")
    root <- parent
  }
  root
}
