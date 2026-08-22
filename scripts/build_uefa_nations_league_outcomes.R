#!/usr/bin/env Rscript

# Compatibility entrypoint using the explicit UEFA production command name.
# The plan-owned implementation remains in build_nations_league_outcomes.R.
phase15_uefa_cli_args <- commandArgs(trailingOnly = FALSE)
phase15_uefa_file_arg <- phase15_uefa_cli_args[grepl("^--file=", phase15_uefa_cli_args)]
phase15_uefa_script_path <- if (length(phase15_uefa_file_arg) == 1L) {
  normalizePath(sub("^--file=", "", phase15_uefa_file_arg[[1L]]), mustWork = FALSE)
} else {
  normalizePath("scripts/build_uefa_nations_league_outcomes.R", mustWork = FALSE)
}
phase15_uefa_project_root <- normalizePath(file.path(dirname(phase15_uefa_script_path), ".."), mustWork = FALSE)
phase15_uefa_delegate <- file.path(phase15_uefa_project_root, "scripts/build_nations_league_outcomes.R")
if (!file.exists(phase15_uefa_delegate)) {
  stop("The plan-owned Nations League outcomes builder is missing.", call. = FALSE)
}
sys.source(phase15_uefa_delegate, envir = environment())
