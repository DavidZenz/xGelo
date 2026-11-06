set.seed(15017L)
test_file <- Sys.getenv("XGELO_VERIFY_TEST_FILE")
report_file <- Sys.getenv("XGELO_VERIFY_TEST_REPORT")
stopifnot(nzchar(test_file), nzchar(report_file), file.exists(test_file))
result <- testthat::test_file(test_file, reporter = "summary")
rows <- as.data.frame(result)
counts <- list(cases = nrow(rows), passed = sum(rows$passed), failed = sum(rows$failed),
               errors = sum(rows$error), warnings = sum(rows$warning), skipped = sum(rows$skipped))
report <- list(test_file = test_file, runtime = R.version.string,
               testthat_version = as.character(utils::packageVersion("testthat")),
               counts = counts, scope = "Installed focused tests; no production forecast/publication authority")
jsonlite::write_json(report, report_file, auto_unbox = TRUE, pretty = TRUE)
if (any(unlist(counts[c("failed", "errors", "warnings", "skipped")]) != 0L)) quit(status = 1L)
