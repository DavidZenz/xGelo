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

test_that("local parent files invalidate the correct downstream Phase 10 chain", {
  withr::local_dir(project_root)
  manifest <- require_statistical_targets()
  commands <- stats::setNames(as.character(manifest$command), manifest$name)
  registry_command <- commands[["benchmark_phase10_registry_files"]]
  expect_match(registry_command, "glmnet_provenance.csv", fixed = TRUE)
  expect_match(registry_command, "tuning_grid.csv", fixed = TRUE)
  expect_match(registry_command, "selection_protocol.json", fixed = TRUE)
  expect_match(registry_command, "storage_preflight.csv", fixed = TRUE)
  expect_match(registry_command, "panel_fixtures.csv", fixed = TRUE)
  expect_match(registry_command, "checksum_manifest.csv", fixed = TRUE)
  expect_match(registry_command, "goal_training_features_hybrid.csv", fixed = TRUE)

  registries_command <- commands[["benchmark_phase10_registries"]]
  expect_match(registries_command, "require_challenger_environment", fixed = TRUE)
  expect_match(registries_command, "load_and_validate_challenger_protocol", fixed = TRUE)
  expect_match(registries_command, "load_phase09_parent_bundle", fixed = TRUE)
  expect_match(registries_command, "feature_input_sha256", fixed = TRUE)

  predictions_command <- commands[["benchmark_phase10_predictions"]]
  expect_match(predictions_command, "benchmark_runner_track_fixtures", fixed = TRUE)
  expect_match(predictions_command, "guard_benchmark_purpose", fixed = TRUE)
  expect_match(predictions_command, "run_statistical_challenger_benchmark", fixed = TRUE)
  expect_false(grepl("benchmark_phase09_", predictions_command, fixed = TRUE))
  expect_false(grepl("hybrid_goal_training_features_file", predictions_command, fixed = TRUE))

  bundle_command <- commands[["benchmark_phase10_bundle_files"]]
  expect_match(bundle_command, "write_statistical_challenger_bundle", fixed = TRUE)
  expect_match(bundle_command, "phase10_output_paths", fixed = TRUE)
})

test_that("Phase 10 modules are sourced in deterministic dependency order", {
  code <- readLines(file.path(project_root, "_targets.R"), warn = FALSE)
  modules <- c(
    "challenger_preflight.R", "challenger_protocol.R", "penalized_poisson.R",
    "dynamic_goal_ability.R", "score_dependence.R", "challengers.R",
    "challenger_selection.R", "challenger_runner.R"
  )
  locations <- vapply(modules, function(module) {
    matches <- grep(module, code, fixed = TRUE)
    if (!length(matches)) NA_integer_ else matches[1]
  }, integer(1))
  expect_false(anyNA(locations))
  expect_lt(locations[["challenger_preflight.R"]], locations[["challenger_protocol.R"]])
  expect_lt(locations[["penalized_poisson.R"]], locations[["dynamic_goal_ability.R"]])
  expect_lt(locations[["dynamic_goal_ability.R"]], locations[["score_dependence.R"]])
  expect_lt(locations[["score_dependence.R"]], locations[["challengers.R"]])
  expect_lt(locations[["challengers.R"]], locations[["challenger_selection.R"]])
  expect_lt(locations[["challenger_selection.R"]], locations[["challenger_runner.R"]])
})
