#!/usr/bin/env Rscript

# Thin registered wrapper.  The implementation and validation contract live
# in build_euro_qualifying_outcomes.R so callers have one source of truth.
phase16_euro_wrapper_args <- commandArgs(trailingOnly = FALSE)
phase16_euro_wrapper_file_arg <- phase16_euro_wrapper_args[
  grepl("^--file=", phase16_euro_wrapper_args)
]
phase16_euro_wrapper_script_path <- if (length(phase16_euro_wrapper_file_arg) == 1L) {
  normalizePath(
    sub("^--file=", "", phase16_euro_wrapper_file_arg[[1L]]),
    winslash = "/",
    mustWork = FALSE
  )
} else {
  normalizePath("scripts/build_uefa_euro_qualifying_outcomes.R", mustWork = FALSE)
}
phase16_euro_wrapper_project_root <- normalizePath(
  file.path(dirname(phase16_euro_wrapper_script_path), ".."),
  winslash = "/",
  mustWork = FALSE
)
phase16_euro_wrapper_delegate <- file.path(
  phase16_euro_wrapper_project_root,
  "scripts/build_euro_qualifying_outcomes.R"
)
if (!file.exists(phase16_euro_wrapper_delegate)) {
  stop("EURO outcomes CLI delegate is missing", call. = FALSE)
}
sys.source(phase16_euro_wrapper_delegate, envir = environment())

phase16_euro_wrapper_direct_invocation <- !interactive() &&
  any(grepl("^--file=", phase16_euro_wrapper_args))
if (isTRUE(phase16_euro_wrapper_direct_invocation)) {
  phase16_euro_wrapper_result <- phase16_build_euro_qualifying_outcomes_main()
  phase16_euro_cli_print_result(phase16_euro_wrapper_result)
}
