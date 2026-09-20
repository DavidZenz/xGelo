#!/usr/bin/env Rscript

phase19_runner_abort <- function(...) {
  message(paste0(...))
  quit(save = "no", status = 1L)
}

phase19_runner_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
arguments <- commandArgs(trailingOnly = TRUE)
if (!length(arguments)) phase19_runner_abort("Phase 19 focused runner requires at least one test file")

files <- vapply(arguments, function(path) {
  candidate <- if (grepl("^/", path)) path else file.path(phase19_runner_root, path)
  if (!file.exists(candidate) || dir.exists(candidate)) {
    phase19_runner_abort("Missing Phase 19 focused test file: ", path)
  }
  normalizePath(candidate, winslash = "/", mustWork = TRUE)
}, character(1))

if (anyDuplicated(files)) phase19_runner_abort("Phase 19 focused test files must be unique")

for (file in files) {
  expression <- paste0(
    "setwd(", paste(deparse(phase19_runner_root), collapse = ""), ");",
    "x<-testthat::test_file(", paste(deparse(file), collapse = ""), ",reporter='silent');",
    "d<-as.data.frame(x);",
    "if(!nrow(d))quit(save='no',status=91L);",
    "required<-c('failed','error','warning','skipped','passed');",
    "if(length(setdiff(required,names(d))))quit(save='no',status=92L);",
    "bad<-sum(d$failed)+sum(d$error)+sum(d$warning)+sum(d$skipped);",
    "if(bad>0L)quit(save='no',status=93L);",
    "cat(sprintf('PHASE19_FOCUSED_RESULT tests=%d assertions=%d\\n',nrow(d),sum(d$passed)))"
  )
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", "-e", shQuote(expression)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  result_line <- output[grepl("^PHASE19_FOCUSED_RESULT ", output)]
  if (as.integer(status) != 0L || length(result_line) != 1L) {
    if (length(output)) cat(paste(output, collapse = "\n"), "\n", file = stderr())
    phase19_runner_abort("Phase 19 focused test failed: ", basename(file))
  }
  cat(sprintf("PASS %-48s %s\n", basename(file), result_line))
}

cat(sprintf("PHASE19_FOCUSED_OK files=%d\n", length(files)))
