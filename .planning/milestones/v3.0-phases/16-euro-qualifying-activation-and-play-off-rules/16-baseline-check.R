#!/usr/bin/env Rscript

phase16_baseline_expression <- "testthat::test_dir(\"tests/testthat\", reporter=\"summary\")"
phase16_baseline_command <- paste(
  "Rscript --vanilla -e",
  shQuote(phase16_baseline_expression)
)
phase16_baseline_known_signature <-
  "156 fixture IDs paired with zero-length normalized source columns"
phase16_baseline_known_shape_error <-
  "arguments imply differing number of rows: 156, 0"

phase16_baseline_usage <- function() {
  paste(
    "Usage:",
    "Rscript --vanilla .planning/phases/16-euro-qualifying-activation-and-play-off-rules/16-baseline-check.R",
    "--capture|--compare --baseline <path>"
  )
}

phase16_baseline_stop <- function(message, status = 2L) {
  message(sprintf("Phase 16 baseline helper error: %s", message), appendLF = TRUE)
  quit(save = "no", status = as.integer(status), runLast = FALSE)
}

phase16_baseline_project_root <- function() {
  arguments <- commandArgs(trailingOnly = FALSE)
  script_argument <- arguments[startsWith(arguments, "--file=")]
  if (length(script_argument)) {
    script_path <- sub("^--file=", "", script_argument[[1L]])
    script_path <- normalizePath(script_path, winslash = "/", mustWork = TRUE)
    candidate <- dirname(dirname(dirname(dirname(script_path))))
  } else {
    candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  }

  repeat {
    if (file.exists(file.path(candidate, "AGENTS.md")) &&
        dir.exists(file.path(candidate, "tests", "testthat")) &&
        dir.exists(file.path(candidate, ".planning"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  phase16_baseline_stop("could not resolve the repository root")
}

phase16_baseline_sha256 <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase16_baseline_stop("the existing digest package is required for SHA-256 capture")
  }
  bytes <- if (is.raw(value)) {
    value
  } else {
    charToRaw(enc2utf8(paste0(value, collapse = "")))
  }
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase16_baseline_parse_args <- function(arguments) {
  mode_flags <- intersect(arguments, c("--capture", "--compare"))
  if (length(mode_flags) != 1L) {
    phase16_baseline_stop(phase16_baseline_usage())
  }
  baseline_flag <- match("--baseline", arguments)
  if (is.na(baseline_flag) || baseline_flag == length(arguments)) {
    phase16_baseline_stop(phase16_baseline_usage())
  }
  baseline_path <- arguments[[baseline_flag + 1L]]
  if (!nzchar(baseline_path) || startsWith(baseline_path, "--")) {
    phase16_baseline_stop(phase16_baseline_usage())
  }
  list(
    mode = sub("^--", "", mode_flags[[1L]]),
    baseline_path = baseline_path
  )
}

phase16_baseline_child_run <- function(project_root) {
  old_wd <- setwd(project_root)
  on.exit(setwd(old_wd), add = TRUE)
  output_file <- tempfile("phase16-baseline-child-", fileext = ".log")
  on.exit(unlink(output_file, force = TRUE), add = TRUE)
  status <- tryCatch(
    system2(
      "Rscript",
      c(
        "--vanilla",
        "-e",
        shQuote(phase16_baseline_expression)
      ),
      stdout = output_file,
      stderr = output_file
    ),
    error = function(error) {
      structure(NA_integer_, phase16_launch_error = conditionMessage(error))
    }
  )
  launch_error <- attr(status, "phase16_launch_error")
  if (!is.null(launch_error)) {
    phase16_baseline_stop(sprintf("full-suite child launch failed: %s", launch_error), status = 1L)
  }
  if (is.null(status) || !length(status) || is.na(status[[1L]])) status <- 0L
  output_size <- file.info(output_file)$size
  output_raw <- if (is.finite(output_size) && output_size > 0) {
    readBin(output_file, what = "raw", n = output_size)
  } else {
    raw()
  }
  output <- if (length(output_raw)) rawToChar(output_raw) else ""
  list(
    command = phase16_baseline_command,
    exit_status = as.integer(status),
    output = output,
    output_sha256 = phase16_baseline_sha256(output_raw)
  )
}

phase16_baseline_failure_count <- function(output) {
  lines <- strsplit(output, "\n", fixed = TRUE)[[1L]]
  summary_lines <- grep("FAIL[[:space:]]+[0-9]+|Maximum number of [0-9]+ failures reached", lines, value = TRUE)
  capped_lines <- grep("Maximum number of [0-9]+ failures reached", lines, value = TRUE)
  if (length(capped_lines)) {
    capped <- regmatches(capped_lines[[1L]], regexec("Maximum number of ([0-9]+) failures reached", capped_lines[[1L]], perl = TRUE))[[1L]]
    if (length(capped) >= 2L) return(as.integer(capped[[2L]]))
  }
  error_headers <- grep("^[[:space:]]*──[[:space:]]+[0-9]+\\.[[:space:]]+(Error|Failure)\\b", lines, value = TRUE, perl = TRUE)
  if (length(error_headers)) {
    indexes <- regmatches(error_headers, regexec("^[[:space:]]*──[[:space:]]+([0-9]+)\\.", error_headers, perl = TRUE))
    values <- suppressWarnings(as.integer(vapply(indexes, function(match) if (length(match) >= 2L) match[[2L]] else NA_character_, character(1))))
    values <- values[!is.na(values)]
    if (length(values)) return(max(values))
  }
  if (!length(summary_lines)) return(NA_integer_)
  counts <- regmatches(summary_lines, regexec("FAIL[[:space:]]+([0-9]+)", summary_lines, perl = TRUE))
  values <- vapply(counts, function(match) {
    if (length(match) < 2L) return(NA_integer_)
    suppressWarnings(as.integer(match[[2L]]))
  }, integer(1))
  values <- values[!is.na(values)]
  if (!length(values)) NA_integer_ else max(values)
}

phase16_baseline_normalize_failures <- function(output) {
  lines <- strsplit(output, "\n", fixed = TRUE)[[1L]]
  candidates <- grep(
    "(Failure|Error)[[:space:]]*\\(['\"]?[^'\"]+\\.R",
    lines,
    value = TRUE,
    perl = TRUE
  )
  if (!length(candidates)) {
    return(character())
  }
  identities <- vapply(candidates, function(line) {
    match <- regmatches(
      line,
      regexec(
        "(?:Failure|Error)[[:space:]]*\\(['\"]?([^'\"]+?\\.R)(?::[0-9]+(?::[0-9]+)?)?['\"]?\\)[[:space:]]*:?[[:space:]]*(.*?)([─-]+)?[[:space:]]*$",
        line,
        perl = TRUE
      )
    )[[1L]]
    if (length(match) < 3L) return(NA_character_)
    file_name <- basename(match[[2L]])
    test_name <- trimws(match[[3L]])
    if (!nzchar(file_name) || !nzchar(test_name)) return(NA_character_)
    paste(file_name, test_name, sep = "::")
  }, character(1))
  identities <- identities[!is.na(identities) & nzchar(identities)]
  sort(unique(identities), method = "radix")
}

phase16_baseline_signature <- function(output) {
  if (grepl(phase16_baseline_known_signature, output, fixed = TRUE) ||
      grepl(phase16_baseline_known_shape_error, output, fixed = TRUE)) {
    return(phase16_baseline_known_signature)
  }
  ""
}

phase16_baseline_record <- function(capture) {
  identities <- if (length(capture$failure_identities)) {
    paste(sprintf("- `%s`", capture$failure_identities), collapse = "\n")
  } else {
    "- none"
  }
  signature <- if (nzchar(capture$known_failure_signature)) {
    sprintf("`%s`", capture$known_failure_signature)
  } else {
    "none"
  }
  c(
    "# Phase 16 full-suite baseline",
    "",
    "This is a regression fingerprint, not a claim that the full repository suite is green.",
    "Phase 16 acceptance uses the focused/relevant suites plus the comparison rule below:",
    "a persistent recorded failure remains non-green, while only new or unparseable failures gate the comparator.",
    "",
    "## Capture",
    "",
    sprintf("- Capture date (UTC): `%s`", capture$capture_date_utc),
    sprintf("- Full-suite command: `%s`", capture$command),
    sprintf("- Child-process exit status: `%d`", capture$exit_status),
    "- Capture disposition: `record persisted`",
    sprintf("- Combined stdout/stderr SHA-256: `%s`", capture$output_sha256),
    "- Output normalization: `sorted unique test_file::test_name entries`",
    sprintf("- Normalization status: `%s`", capture$normalization_status),
    "",
    "## Known baseline disposition",
    "",
    "- Allowed pre-existing disposition: exactly the recorded failure identity and known signature below.",
    "- A nonzero child status is retained as evidence; capture success means only that this record was written.",
    "- Output-hash drift is reported evidence and is not a standalone comparison failure.",
    sprintf("- Known failure signature: %s", signature),
    "- Known failing test identities:",
    identities,
    "",
    "## Comparison policy",
    "",
    "- Exit zero when the current suite has no failures.",
    "- Exit zero, while reporting `persistent known baseline (non-green)`, when current identities and signature exactly match this record.",
    "- Exit nonzero for a new identity, a missing known signature, an unparseable failure, or a helper/launch/read failure.",
    "",
    "## Recorded signature",
    "",
    sprintf("`%s`", phase16_baseline_known_signature),
    ""
  )
}

phase16_baseline_write <- function(path, capture) {
  parent <- dirname(path)
  if (!dir.exists(parent) && !dir.create(parent, recursive = TRUE, showWarnings = FALSE)) {
    phase16_baseline_stop(sprintf("could not create baseline directory: %s", parent), status = 1L)
  }
  temporary <- tempfile("16-baseline-", tmpdir = parent, fileext = ".md")
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  write_ok <- tryCatch({
    writeLines(phase16_baseline_record(capture), temporary, useBytes = TRUE)
    TRUE
  }, error = function(error) {
    phase16_baseline_stop(sprintf("could not write baseline record: %s", conditionMessage(error)), status = 1L)
  })
  if (!isTRUE(write_ok) || !file.rename(temporary, path)) {
    phase16_baseline_stop(sprintf("could not persist baseline record: %s", path), status = 1L)
  }
  invisible(path)
}

phase16_baseline_read <- function(path) {
  if (!file.exists(path)) {
    phase16_baseline_stop(sprintf("baseline record does not exist: %s", path), status = 1L)
  }
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(error) {
    phase16_baseline_stop(sprintf("could not read baseline record: %s", conditionMessage(error)), status = 1L)
  })
  status_line <- grep("^- Child-process exit status:", lines, value = TRUE)
  hash_line <- grep("^- Combined stdout/stderr SHA-256:", lines, value = TRUE)
  identity_start <- match("- Known failing test identities:", lines)
  signature_line <- grep("^- Known failure signature:", lines, value = TRUE)
  if (!length(status_line) || !length(hash_line) || !length(signature_line) || is.na(identity_start)) {
    phase16_baseline_stop("baseline record is missing required fields", status = 1L)
  }
  identity_lines <- lines[seq.int(identity_start + 1L, min(length(lines), identity_start + 100L))]
  identity_lines <- identity_lines[grepl("^- `.*`$", identity_lines)]
  identities <- sub("^- `", "", sub("`$", "", identity_lines))
  signature <- sub("^- Known failure signature: ", "", signature_line[[1L]])
  signature <- if (identical(signature, "none")) "" else sub("^`", "", sub("`$", "", signature))
  list(
    exit_status = as.integer(sub("^- Child-process exit status: `(-?[0-9]+)`$", "\\1", status_line[[1L]])),
    output_sha256 = sub("^- Combined stdout/stderr SHA-256: `([0-9a-f]+)`$", "\\1", hash_line[[1L]]),
    known_failure_signature = signature,
    failure_identities = sort(unique(identities), method = "radix")
  )
}

phase16_baseline_compare <- function(baseline, current) {
  current_count <- phase16_baseline_failure_count(current$output)
  current_identities <- phase16_baseline_normalize_failures(current$output)
  current_signature <- phase16_baseline_signature(current$output)
  cat(sprintf("Current child-process exit status: %d\n", current$exit_status))
  cat(sprintf("Current normalized failure identities: %s\n", if (length(current_identities)) paste(current_identities, collapse = ", ") else "none"))
  cat(sprintf("Current combined-output SHA-256: %s\n", current$output_sha256))
  if (!is.na(current_count) && current_count == 0L) {
    cat("Comparison disposition: full suite has no failures.\n")
    return(0L)
  }
  if (is.na(current_count)) {
    cat("Comparison disposition: unparseable failure summary; full suite remains non-green.\n")
    return(1L)
  }
  if (identical(current_identities, baseline$failure_identities) &&
      identical(current_signature, baseline$known_failure_signature) &&
      nzchar(current_signature)) {
    cat("Comparison disposition: persistent known baseline (non-green); no new failures.\n")
    return(0L)
  }
  cat("Comparison disposition: new or changed failure; full suite remains non-green.\n")
  1L
}

phase16_baseline_main <- function(arguments = commandArgs(trailingOnly = TRUE)) {
  options <- phase16_baseline_parse_args(arguments)
  project_root <- phase16_baseline_project_root()
  baseline_path <- if (grepl("^/", options$baseline_path)) {
    options$baseline_path
  } else {
    file.path(project_root, options$baseline_path)
  }
  current <- phase16_baseline_child_run(project_root)
  failure_count <- phase16_baseline_failure_count(current$output)
  current$failure_identities <- phase16_baseline_normalize_failures(current$output)
  current$known_failure_signature <- phase16_baseline_signature(current$output)
  if (is.na(failure_count)) {
    phase16_baseline_stop("could not normalize the full-suite failure summary", status = 1L)
  }
  if (failure_count > 0L && length(current$failure_identities) == 0L) {
    phase16_baseline_stop("full-suite failures were present but no test identities could be normalized", status = 1L)
  }
  current$normalization_status <- "parsed"
  if (identical(options$mode, "capture")) {
    current$capture_date_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    phase16_baseline_write(baseline_path, current)
    cat(sprintf("Baseline capture persisted at %s\n", baseline_path))
    cat(sprintf("Child-process exit status retained: %d\n", current$exit_status))
    cat(sprintf("Normalized failure identities: %s\n", if (length(current$failure_identities)) paste(current$failure_identities, collapse = ", ") else "none"))
    cat(sprintf("Combined-output SHA-256: %s\n", current$output_sha256))
    cat("Capture disposition: record persisted; this is not a green-suite claim.\n")
    return(0L)
  }
  baseline <- phase16_baseline_read(baseline_path)
  phase16_baseline_compare(baseline, current)
}

status <- tryCatch(phase16_baseline_main(), error = function(error) {
  phase16_baseline_stop(conditionMessage(error), status = 1L)
})
quit(save = "no", status = as.integer(status), runLast = FALSE)
