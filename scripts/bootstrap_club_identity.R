#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

phase18_cli_args <- commandArgs(trailingOnly = TRUE)
phase18_cli_options <- list()
phase18_cli_positionals <- character(0)
for (argument in phase18_cli_args) {
  if (grepl("^--[^=]+=", argument)) {
    key <- sub("^--([^=]+)=.*$", "\\1", argument)
    phase18_cli_options[[key]] <- sub("^--[^=]+=", "", argument)
  } else {
    phase18_cli_positionals <- c(phase18_cli_positionals, argument)
  }
}
phase18_cli_mode <- phase18_cli_options$mode
if (is.null(phase18_cli_mode) && length(phase18_cli_positionals)) phase18_cli_mode <- phase18_cli_positionals[[1L]]
if (is.null(phase18_cli_mode)) phase18_cli_mode <- "verify"
phase18_cli_root <- normalizePath(phase18_cli_options$`project-root` %||% getwd(), mustWork = TRUE)

source(file.path(phase18_cli_root, "R/club/identity.R"), local = .GlobalEnv)
source(file.path(phase18_cli_root, "R/club/identity_bootstrap.R"), local = .GlobalEnv)

phase18_cli_trusted_path <- function(value, default, must_exist = FALSE) {
  candidate <- value %||% default
  if (!grepl("^/", candidate)) candidate <- file.path(phase18_cli_root, candidate)
  parent <- if (file.exists(candidate)) candidate else dirname(candidate)
  parent <- normalizePath(parent, mustWork = TRUE)
  allowed <- c(
    normalizePath(file.path(phase18_cli_root, "data/club"), mustWork = TRUE),
    normalizePath(file.path(phase18_cli_root, "data/competition"), mustWork = TRUE),
    normalizePath(file.path(phase18_cli_root, "outputs"), mustWork = TRUE)
  )
  inside <- vapply(allowed, function(root) identical(parent, root) || startsWith(parent, paste0(root, "/")), logical(1))
  if (!any(inside)) stop("Path is outside trusted club/competition/output roots: ", candidate, call. = FALSE)
  if (must_exist && !file.exists(candidate)) stop("Required path does not exist: ", candidate, call. = FALSE)
  candidate
}

phase18_cli_read <- function(path, schema = NULL) {
  if (!file.exists(path)) {
    if (is.null(schema)) return(NULL)
    return(phase18_empty_table(schema))
  }
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  data[] <- lapply(data, function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  data
}

phase18_cli_run <- function() {
  registry_root <- phase18_cli_trusted_path(
    phase18_cli_options$`registry-root`, "data/club/registries"
  )
  review_root <- phase18_cli_trusted_path(
    phase18_cli_options$`review-root`, "data/club/identity_reviews"
  )
  current_tokens_path <- file.path(review_root, "current_ucl_tokens.csv")
  history_tokens_path <- file.path(review_root, "historical_inventory_tokens.csv")
  unresolved_path <- file.path(review_root, "unresolved_club_tokens.csv")

  if (identical(phase18_cli_mode, "extract")) {
    current_path <- phase18_cli_options$current
    history_path <- phase18_cli_options$history
    current <- if (is.null(current_path)) NULL else phase18_cli_read(phase18_cli_trusted_path(current_path, current_path, TRUE))
    history <- if (is.null(history_path)) NULL else phase18_cli_read(phase18_cli_trusted_path(history_path, history_path, TRUE))
    tokens <- phase18_extract_club_tokens(current, history)
    phase18_write_csv_atomic(tokens[tokens$corpus == "current_ucl", , drop = FALSE], current_tokens_path)
    phase18_write_csv_atomic(tokens[tokens$corpus == "historical_inventory", , drop = FALSE], history_tokens_path)
    message("club_identity_extract status=complete tokens=", nrow(tokens))
    return(invisible(TRUE))
  }

  tokens <- rbind(
    phase18_cli_read(current_tokens_path, phase18_club_token_schema()),
    phase18_cli_read(history_tokens_path, phase18_club_token_schema())
  )
  review_path <- phase18_cli_options$review

  if (identical(phase18_cli_mode, "review")) {
    if (is.null(review_path)) stop("--review=<path> is required for review mode", call. = FALSE)
    review <- phase18_cli_read(phase18_cli_trusted_path(review_path, review_path, TRUE))
    phase18_validate_club_identity_review(tokens, review)
    message("club_identity_review status=valid rows=", nrow(review))
    return(invisible(TRUE))
  }

  if (identical(phase18_cli_mode, "apply")) {
    if (is.null(review_path)) stop("--review=<path> is required for apply mode", call. = FALSE)
    review <- phase18_cli_read(phase18_cli_trusted_path(review_path, review_path, TRUE))
    registries <- phase18_load_club_registries(registry_root)
    result <- phase18_apply_club_identity_review(tokens, review, registries)
    phase18_write_club_registries_atomic(result$registries, registry_root)
    phase18_write_csv_atomic(result$unresolved, unresolved_path)
    message(
      "club_identity_apply status=complete registry_sha256=", result$registry_sha256,
      " unresolved=", nrow(result$unresolved)
    )
    return(invisible(TRUE))
  }

  if (!identical(phase18_cli_mode, "verify")) {
    stop("Mode must be one of extract|review|apply|verify", call. = FALSE)
  }
  unresolved <- phase18_cli_read(unresolved_path, phase18_unresolved_club_token_schema())
  result <- list(
    registries = phase18_load_club_registries(registry_root),
    tokens = tokens, unresolved = unresolved
  )
  current_expected <- as.integer(phase18_cli_options$`current-expected` %||% nrow(tokens[tokens$corpus == "current_ucl", , drop = FALSE]))
  history_expected <- as.integer(phase18_cli_options$`history-expected` %||% nrow(tokens[tokens$corpus == "historical_inventory", , drop = FALSE]))
  report <- phase18_validate_identity_bootstrap(
    result,
    current_expectations = list(
      required = FALSE, expected_tokens = current_expected,
      not_run = !nrow(tokens[tokens$corpus == "current_ucl", , drop = FALSE])
    ),
    history_expectations = list(required = TRUE, expected_tokens = history_expected)
  )
  message("club_identity_verify status=complete registry_sha256=", phase18_club_registry_hash(result$registries))
  utils::write.table(report, row.names = FALSE, sep = ",", quote = FALSE)
  invisible(TRUE)
}

tryCatch(
  phase18_cli_run(),
  error = function(error) {
    reason <- if (!is.null(error$reason)) error$reason else class(error)[[1L]]
    message("club_identity_bootstrap status=blocked reason=", reason, " message=", conditionMessage(error))
    quit(save = "no", status = 2L)
  }
)
