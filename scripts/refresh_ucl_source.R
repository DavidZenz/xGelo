#!/usr/bin/env Rscript

phase18_refresh_script_file <- tryCatch(sys.frame(1)$ofile, error = function(error) NULL)
if (is.null(phase18_refresh_script_file) || !nzchar(phase18_refresh_script_file)) {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  phase18_refresh_script_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "scripts/refresh_ucl_source.R"
}
phase18_refresh_script_root <- normalizePath(
  file.path(dirname(phase18_refresh_script_file), ".."), winslash = "/", mustWork = TRUE
)

source(file.path(phase18_refresh_script_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
source(file.path(phase18_refresh_script_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
source(file.path(phase18_refresh_script_root, "R/competition/edition_registry.R"), local = .GlobalEnv)
source(file.path(phase18_refresh_script_root, "R/competition/ucl_source_bundle.R"), local = .GlobalEnv)
source(file.path(phase18_refresh_script_root, "R/competition/ucl_source_refresh.R"), local = .GlobalEnv)

phase18_refresh_ucl_parse_args <- function(args) {
  allowed <- c("mode", "candidate-root", "exit-review", "dry-run")
  options <- list(mode = "refresh", `candidate-root` = NULL, `exit-review` = NULL, `dry-run` = FALSE)
  index <- 1L
  while (index <= length(args)) {
    token <- args[[index]]
    if (!startsWith(token, "--")) stop("Unknown positional argument", call. = FALSE)
    key <- substring(token, 3L)
    if (!key %in% allowed) stop("Unsupported refresh option: --", key, call. = FALSE)
    if (identical(key, "dry-run")) {
      options[[key]] <- TRUE
      index <- index + 1L
    } else {
      if (index == length(args)) stop("Missing value for --", key, call. = FALSE)
      options[[key]] <- args[[index + 1L]]
      index <- index + 2L
    }
  }
  if (!options$mode %in% c("refresh", "provider_exit")) {
    stop("--mode must be refresh or provider_exit", call. = FALSE)
  }
  options
}

#' Fixed-root operator entrypoint; no force or bypass options exist.
phase18_refresh_ucl_source_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- phase18_refresh_ucl_parse_args(args)
  accepted_root <- file.path(phase18_refresh_script_root, "data/competition/accepted")
  registry_root <- file.path(phase18_refresh_script_root, "data/competition/registries")
  acceptance_root <- file.path(phase18_refresh_script_root, "data/competition/provider_acceptance")
  if (identical(options$mode, "refresh")) {
    if (is.null(options$`candidate-root`)) stop("Refresh mode requires --candidate-root", call. = FALSE)
    candidate_root <- normalizePath(options$`candidate-root`, winslash = "/", mustWork = TRUE)
    candidate_parent <- normalizePath(file.path(phase18_refresh_script_root, "data/competition/candidates"), winslash = "/", mustWork = FALSE)
    if (!phase18_ucl_path_within(candidate_root, candidate_parent) || identical(candidate_root, candidate_parent)) {
      stop("--candidate-root must be a direct trusted candidate descendant", call. = FALSE)
    }
    if (isTRUE(options$`dry-run`)) {
      candidate <- phase18_read_ucl_candidate(candidate_root)
      phase18_validate_ucl_source_bundle(candidate)
      phase18_ucl_refresh_validate_provider_authority(candidate, acceptance_root)
      return(invisible(list(status = "dry_run_validated", mutation = FALSE)))
    }
    return(phase18_refresh_ucl_source(
      candidate_root, accepted_root, registry_root, acceptance_root
    ))
  }
  if (is.null(options$`exit-review`)) stop("Provider-exit mode requires --exit-review", call. = FALSE)
  review_path <- normalizePath(options$`exit-review`, winslash = "/", mustWork = TRUE)
  review_root <- normalizePath(file.path(acceptance_root, "football_data_org_v4", "ucl_2026_27"), winslash = "/", mustWork = TRUE)
  if (!phase18_ucl_path_within(review_path, review_root)) {
    stop("--exit-review must be inside the fixed provider acceptance root", call. = FALSE)
  }
  review <- phase18_ucl_read_csv(review_path)
  phase18_validate_ucl_provider_exit_review(review)
  if (isTRUE(options$`dry-run`)) return(invisible(list(status = "dry_run_exit_review_validated", mutation = FALSE)))
  phase18_apply_provider_exit(review, accepted_root, registry_root)
}

if (sys.nframe() == 0L) {
  result <- tryCatch(
    phase18_refresh_ucl_source_main(),
    error = function(error) {
      message(conditionMessage(error))
      quit(save = "no", status = 1L)
    }
  )
  if (!is.null(result)) print(result)
}
