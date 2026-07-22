library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))

phase10_target_names <- function() {
  c(
    "benchmark_phase10_registry_files", "benchmark_phase10_registries",
    "benchmark_phase10_predictions", "benchmark_phase10_scores",
    "benchmark_phase10_comparisons", "benchmark_phase10_bundle_files"
  )
}

phase10_target_ancestors <- function(manifest, target_name) {
  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  visit <- function(name, seen = character()) {
    if (name %in% seen || !name %in% names(commands)) return(seen)
    dependencies <- names(commands)[vapply(
      names(commands), function(candidate) {
        grepl(paste0("(^|[^A-Za-z0-9_.])", candidate, "([^A-Za-z0-9_.]|$)"), commands[[name]])
      }, logical(1)
    )]
    Reduce(function(acc, dependency) visit(dependency, acc), dependencies, init = c(seen, name))
  }
  setdiff(visit(target_name), target_name)
}

require_statistical_targets <- function() {
  manifest <- targets::tar_manifest(fields = c("name", "command"))
  missing <- setdiff(phase10_target_names(), manifest$name)
  if (length(missing)) {
    stop(paste("Wave 0 RED contract awaits:", paste(missing, collapse = ", ")), call. = FALSE)
  }
  manifest
}

test_that("target manifest contains the six exact Phase 10 nodes", {
  withr::local_dir(project_root)
  manifest <- require_statistical_targets()
  expect_true(all(phase10_target_names() %in% manifest$name))
  expect_false(any(grepl("phase10.*promotion|promotion.*phase10", manifest$name, ignore.case = TRUE)))
})

test_that("Phase 10 target chain is downstream-only and ordered", {
  withr::local_dir(project_root)
  manifest <- require_statistical_targets()
  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  expect_match(commands[["benchmark_phase10_registries"]], "benchmark_phase10_registry_files", fixed = TRUE)
  expect_match(commands[["benchmark_phase10_predictions"]], "benchmark_phase10_registries", fixed = TRUE)
  expect_match(commands[["benchmark_phase10_scores"]], "benchmark_phase10_predictions", fixed = TRUE)
  expect_match(commands[["benchmark_phase10_comparisons"]], "benchmark_phase10_scores", fixed = TRUE)
  expect_match(commands[["benchmark_phase10_bundle_files"]], "benchmark_phase10_comparisons", fixed = TRUE)

  ancestors <- phase10_target_ancestors(manifest, "benchmark_phase10_bundle_files")
  expect_true(all(phase10_target_names()[-6] %in% ancestors))
  forbidden <- "dashboard|download|refresh|retrospective|wc2026|promotion"
  expect_false(any(grepl(forbidden, ancestors, ignore.case = TRUE)))
  expect_false(any(grepl(forbidden, commands[c(ancestors, "benchmark_phase10_bundle_files")], ignore.case = TRUE)))
})

test_that("manifest inspection does not execute the historical benchmark", {
  withr::local_dir(project_root)
  manifest <- require_statistical_targets()
  command <- as.character(manifest$command[manifest$name == "benchmark_phase10_bundle_files"])
  expect_match(command, "benchmark_phase10_comparisons", fixed = TRUE)
  expect_false(grepl("tar_make|run_rolling_tournament_benchmark", command, fixed = TRUE))
})
