arguments <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
mode <- arguments[[2L]]
destination <- arguments[[3L]]
setwd(root)
descriptions <- switch(mode,
  blocked = "blocked club targets complete truthfully without release or selector files",
  authority = c("the production controller is an explicit fail-closed entrypoint",
    "the target manifest contains a validated club-only authority chain",
    "blocked club targets complete truthfully without release or selector files",
    "club file targets are explicit and downstream invalidation parents are visible"),
  fixture = c("explicit fixture mode completes through an isolated fixture release",
    "mode, root, domain, and mixed-root attacks fail before publication",
    "repeated fixture and blocked executions are deterministic and credential-free"),
  stop("Unknown diagnostic mode"))
results <- lapply(descriptions, function(description) testthat::test_file(
  file.path(root, "tests/testthat/test_phase19_club_pipeline.R"),
  reporter = "summary", desc = description))
frame <- do.call(rbind, lapply(results, as.data.frame))
stopifnot(nrow(frame) == length(descriptions))
conditions <- lapply(seq_len(nrow(frame)), function(index) {
  entries <- frame$result[[index]]
  list(test = frame$test[[index]], conditions = lapply(entries, function(value) {
    list(classes = class(value), message = tryCatch(conditionMessage(value),
      error = function(e) paste(as.character(value), collapse = "\n")))
  }))
})
bad <- sum(frame$failed) + sum(frame$error) + sum(frame$warning) + sum(frame$skipped)
jsonlite::write_json(list(root = root, mode = mode, tests = nrow(frame),
  assertions = sum(frame$passed), failures = sum(frame$failed), errors = sum(frame$error),
  warnings = sum(frame$warning), skips = sum(frame$skipped), cases = conditions),
  destination, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("PIPELINE_DIAGNOSTIC mode=%s tests=%d assertions=%d bad=%d\n",
  mode, nrow(frame), sum(frame$passed), bad))
quit(save = "no", status = if (bad) 1L else 0L)
