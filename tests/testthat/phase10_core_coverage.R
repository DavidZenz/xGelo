phase10_core_coverage_spec <- function() {
  list(
    "R/forecast/penalized_poisson.R" = c(
      "tests/testthat/test_statistical_penalized_poisson_design.R",
      "tests/testthat/test_statistical_penalized_poisson_tuning.R"
    ),
    "R/forecast/dynamic_goal_ability.R" = c(
      "tests/testthat/test_statistical_dynamic_state.R",
      "tests/testthat/test_statistical_dynamic_tuning.R"
    ),
    "R/forecast/score_dependence.R" = c(
      "tests/testthat/test_statistical_dependence_pmf.R",
      "tests/testthat/test_statistical_dependence_parameters.R"
    ),
    "R/benchmark/challengers.R" = c(
      "tests/testthat/test_statistical_ablation_hierarchy.R",
      "tests/testthat/test_statistical_adapter_dispatch.R",
      "tests/testthat/test_statistical_ablation_selection.R"
    ),
    "R/evaluation/challenger_selection.R" = "tests/testthat/test_statistical_selection.R"
  )
}

phase10_coverage_command <- function(source_file, test_files) {
  paste0(
    "covr::file_coverage(source_files=", dQuote(source_file),
    ",test_files=c(", paste(dQuote(test_files), collapse = ","), ")",
    ",line_exclusions=NULL,function_exclusions=NULL,parent_env=globalenv())"
  )
}

phase10_sha256_text <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required to validate Phase 10 coverage evidence", call. = FALSE)
  }
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

read_phase10_coverage_exceptions <- function(
    path = "tests/testthat/phase10_coverage_exceptions.csv",
    spec = phase10_core_coverage_spec()
) {
  required <- c(
    "source_file", "reason_code", "instrumentation_command", "error_text",
    "error_sha256", "evidence_path", "reviewer_note"
  )
  if (!file.exists(path)) stop("Phase 10 coverage exception registry is missing", call. = FALSE)
  exceptions <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(exceptions), required)) {
    stop("Phase 10 coverage exception registry schema drift", call. = FALSE)
  }
  if (anyDuplicated(exceptions$source_file)) {
    stop("Phase 10 coverage exception registry contains duplicate source files", call. = FALSE)
  }
  if (nrow(exceptions)) {
    unmatched <- setdiff(exceptions$source_file, names(spec))
    if (length(unmatched)) stop("Coverage exceptions must match a whole core source file", call. = FALSE)
    if (any(exceptions$reason_code != "whole_file_instrumentation_failure")) {
      stop("Only reproduced whole-file instrumentation failures may be excepted", call. = FALSE)
    }
    expected_commands <- vapply(exceptions$source_file, function(source_file) {
      phase10_coverage_command(source_file, spec[[source_file]])
    }, character(1))
    if (any(exceptions$instrumentation_command != expected_commands)) {
      stop("Coverage exception instrumentation command is not exact", call. = FALSE)
    }
    expected_hashes <- vapply(exceptions$error_text, phase10_sha256_text, character(1))
    if (any(!nzchar(exceptions$error_text)) || any(exceptions$error_sha256 != expected_hashes)) {
      stop("Coverage exception error text/hash evidence is invalid", call. = FALSE)
    }
    if (any(!grepl("^[0-9a-f]{64}$", exceptions$error_sha256)) ||
        any(!nzchar(exceptions$evidence_path)) || any(!file.exists(exceptions$evidence_path)) ||
        any(!nzchar(exceptions$reviewer_note))) {
      stop("Coverage exception evidence path or reviewer note is invalid", call. = FALSE)
    }
    evidence_valid <- vapply(seq_len(nrow(exceptions)), function(i) {
      evidence <- readLines(exceptions$evidence_path[i], warn = FALSE)
      required_evidence <- c(
        paste0("source_file=", exceptions$source_file[i]),
        paste0("instrumentation_command=", exceptions$instrumentation_command[i]),
        paste0("error_sha256=", exceptions$error_sha256[i])
      )
      all(required_evidence %in% evidence)
    }, logical(1))
    if (any(!evidence_valid)) {
      stop("Coverage exception evidence does not bind source, command, and error hash", call. = FALSE)
    }
  }
  exceptions
}

phase10_measure_file_coverage <- function(source_file, test_files) {
  if (!requireNamespace("covr", quietly = TRUE)) {
    stop("covr is required for Phase 10 core coverage", call. = FALSE)
  }
  if (!file.exists(source_file) || any(!file.exists(test_files))) {
    stop("Phase 10 coverage source or focused test file is missing", call. = FALSE)
  }
  coverage <- covr::file_coverage(
    source_files = source_file,
    test_files = test_files,
    line_exclusions = NULL,
    function_exclusions = NULL,
    parent_env = globalenv()
  )
  as.numeric(covr::percent_coverage(coverage))
}

#' Measure and enforce per-file Phase 10 core modelling coverage
#'
#' @param threshold Minimum percentage required independently for every file.
#' @param exception_path Header-compatible whole-file instrumentation registry.
#' @return One row per core source file with measured coverage or validated exception evidence.
#' @export
run_phase10_core_coverage <- function(
    threshold = 80,
    exception_path = "tests/testthat/phase10_coverage_exceptions.csv"
) {
  threshold <- as.numeric(threshold)
  if (length(threshold) != 1L || !is.finite(threshold) || threshold != 80) {
    stop("Phase 10 core coverage threshold is fixed at 80 percent", call. = FALSE)
  }
  spec <- phase10_core_coverage_spec()
  exceptions <- read_phase10_coverage_exceptions(exception_path, spec)
  rows <- lapply(names(spec), function(source_file) {
    command <- phase10_coverage_command(source_file, spec[[source_file]])
    attempt <- tryCatch(
      list(coverage = phase10_measure_file_coverage(source_file, spec[[source_file]]), error = NULL),
      error = function(error) list(coverage = NA_real_, error = conditionMessage(error))
    )
    exception <- exceptions[exceptions$source_file == source_file, , drop = FALSE]
    exception_valid <- FALSE
    if (!is.null(attempt$error) && nrow(exception) == 1L) {
      exception_valid <- identical(exception$instrumentation_command, command) &&
        identical(exception$error_text, attempt$error) &&
        identical(exception$error_sha256, phase10_sha256_text(attempt$error))
    } else if (is.null(attempt$error) && nrow(exception)) {
      stop("Stale Phase 10 coverage exception: instrumentation now succeeds for ", source_file,
           call. = FALSE)
    }
    data.frame(
      source_file = source_file,
      coverage_percent = attempt$coverage,
      instrumentation_exception_valid = exception_valid,
      instrumentation_error = if (is.null(attempt$error)) "" else attempt$error,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  failed <- !result$instrumentation_exception_valid &
    (!is.finite(result$coverage_percent) | result$coverage_percent < threshold)
  if (any(failed)) {
    detail <- paste0(
      result$source_file[failed], "=",
      ifelse(is.finite(result$coverage_percent[failed]),
             sprintf("%.2f%%", result$coverage_percent[failed]), "instrumentation_failed")
    )
    stop("Phase 10 per-file core coverage below 80%: ", paste(detail, collapse = ", "),
         call. = FALSE)
  }
  result
}
