library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/release/freeze_manifest.R"))

# Validation 12-00-01: the freeze surface retains all nine registered identities.
# Validation 12-00-02: synthetic registry rows never discover or mutate holdout data.

phase12_freeze_synthetic_registry <- function() {
  ids <- c(
    "phase11_rf_dynamic_elo_open", "phase11_rf_dynamic_elo_rich",
    "phase11_nb_dynamic_elo_open", "phase11_nb_dynamic_elo_rich",
    "phase11_penalized_poisson", "phase11_dynamic_goal_ability",
    "phase11_score_dependence", "phase11_context_prior", "phase11_structural_prior"
  )
  data.frame(
    candidate_id = ids,
    active_status = c(TRUE, rep(FALSE, 8L)),
    score_status = c("scored", rep("no_score", 8L)),
    research_only = c(FALSE, rep(TRUE, 8L)),
    sealed = TRUE,
    registry_order = seq_along(ids),
    stringsAsFactors = FALSE
  )
}

phase12_freeze_synthetic_inputs <- function() {
  root <- tempfile("phase12-freeze-")
  dir.create(root, recursive = TRUE)
  dir.create(file.path(root, "data/benchmark/phase09"), recursive = TRUE)
  dir.create(file.path(root, "data/benchmark/phase11"), recursive = TRUE)
  dir.create(file.path(root, "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen"), recursive = TRUE)
  dir.create(file.path(root, "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers"), recursive = TRUE)
  dir.create(file.path(root, "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers"), recursive = TRUE)
  registry <- phase12_freeze_synthetic_registry()
  registry_path <- file.path(root, "data/benchmark/phase11/model_registry.csv")
  write.csv(registry, registry_path, row.names = FALSE, quote = TRUE)
  protocol <- list(
    protocol_sha256 = strrep("a", 64),
    common_vetoes = c("probability_valid", "checksum_valid", "wc2026_sealed"),
    core_gate = list(rps_delta = list(operator = "<=", value = -0.003)),
    supporting_vetoes = list(calibration_change = list(operator = "<=", value = 0.01)),
    optional_data_gate = list(),
    score_support = list(selected_g = 40),
    freeze = list(thresholds_frozen = TRUE, sealed_before_final_labels = TRUE),
    tie_break_order = c("model_id")
  )
  protocol_path <- file.path(root, "data/benchmark/phase09/promotion_protocol.json")
  writeLines(phase12_json_bytes(protocol), protocol_path)
  parent_paths <- c(
    phase09_promotion_protocol = "data/benchmark/phase09/promotion_protocol.json",
    phase09_run_manifest = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/run_manifest.csv",
    phase10_run_manifest = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/run_manifest.csv",
    phase11_model_registry = "data/benchmark/phase11/model_registry.csv",
    phase11_run_manifest = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/run_manifest.csv"
  )
  for (id in c("phase09_run_manifest", "phase10_run_manifest")) {
    write.csv(data.frame(parent = "synthetic", stringsAsFactors = FALSE), file.path(root, parent_paths[[id]]), row.names = FALSE)
  }
  write.csv(data.frame(parent = "synthetic", stringsAsFactors = FALSE), file.path(root, parent_paths[["phase09_run_manifest"]]), row.names = FALSE)
  write.csv(data.frame(parent = "synthetic", stringsAsFactors = FALSE), file.path(root, parent_paths[["phase10_run_manifest"]]), row.names = FALSE)
  run <- data.frame(
    candidate_count = 9L, selected_g = 40L, wc2026_sealed = TRUE,
    network_free = TRUE, research_only = TRUE, protected_paths_clean = TRUE,
    phase12_decision_authority = FALSE,
    candidate_ids = paste(registry$candidate_id, collapse = "|"), stringsAsFactors = FALSE
  )
  write.csv(run, file.path(root, parent_paths[["phase11_run_manifest"]]), row.names = FALSE)
  list(root = root, registry = registry, registry_path = registry_path, protocol_path = protocol_path, parent_paths = parent_paths)
}

phase12_freeze_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0("Wave 0 RED contract awaits Phase 12 ", owner, " API: ",
             paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

test_that("12-00-01 freeze fixture retains nine active and inactive rows", {
  registry <- phase12_freeze_synthetic_registry()
  expect_equal(nrow(registry), 9L)
  expect_equal(sum(registry$active_status), 1L)
  expect_equal(sum(registry$score_status == "no_score"), 8L)
  expect_true(all(registry$sealed))
  expect_identical(registry$registry_order, seq_len(9L))
})

test_that("12-00-01 freeze owner gate names manifest and seal APIs", {
  expect_invisible(phase12_freeze_require_api(
    c(
      "build_phase12_freeze_manifest",
      "validate_phase12_freeze_manifest",
      "phase12_freeze_parent_graph",
      "phase12_freeze_self_hash",
      "phase12_assert_unopened_holdout",
      "phase12_freeze_candidate_rows"
    ),
    "freeze"
  ))
})

test_that("12-01-01 builds and independently validates a synthetic nine-row freeze", {
  inputs <- phase12_freeze_synthetic_inputs()
  output <- file.path(inputs$root, "data/benchmark/phase12/freeze_manifest.csv")
  recipe <- file.path(inputs$root, "data/benchmark/phase12/calibration_recipe.json")
  manifest <- build_phase12_freeze_manifest(
    registry = inputs$registry_path, protocol = inputs$protocol_path,
    phase11_run_manifest = inputs$parent_paths[["phase11_run_manifest"]],
    recipe_path = recipe, output_path = output,
    project_root = inputs$root, parent_paths = inputs$parent_paths
  )
  expect_equal(nrow(manifest), 9L)
  expect_identical(manifest$candidate_id, sort(manifest$candidate_id))
  expect_true(all(manifest$selected_g == 40L))
  expect_equal(sum(manifest$score_status == "scored"), 1L)
  expect_equal(sum(manifest$score_status == "no_score"), 8L)
  expect_true(all(manifest$sealed_before_final_labels))
  expect_true(file.exists(recipe))
  expect_true(file.exists(output))
  expect_invisible(validate_phase12_freeze_manifest(
    output, registry = inputs$registry_path, protocol = inputs$protocol_path,
    recipe_path = recipe, project_root = inputs$root, parent_paths = inputs$parent_paths
  ))
})

test_that("12-01-02 freeze rejects empty, partial, single, and drifted registries", {
  inputs <- phase12_freeze_synthetic_inputs()
  expect_error(phase12_freeze_candidate_rows(inputs$registry[FALSE, ]), "empty|exactly nine")
  expect_error(phase12_freeze_candidate_rows(inputs$registry[1:8, ]), "exactly nine")
  expect_error(phase12_freeze_candidate_rows(inputs$registry[1, , drop = FALSE]), "exactly nine")
  sorted <- inputs$registry
  sorted$candidate_id[1:2] <- sorted$candidate_id[2:1]
  rows <- phase12_freeze_candidate_rows(sorted)
  expect_identical(rows$candidate_id, sort(rows$candidate_id))
  output <- file.path(inputs$root, "data/benchmark/phase12/freeze_manifest.csv")
  recipe <- file.path(inputs$root, "data/benchmark/phase12/calibration_recipe.json")
  build_phase12_freeze_manifest(
    registry = inputs$registry_path, protocol = inputs$protocol_path,
    phase11_run_manifest = inputs$parent_paths[["phase11_run_manifest"]],
    recipe_path = recipe, output_path = output,
    project_root = inputs$root, parent_paths = inputs$parent_paths
  )
  mutated <- inputs$registry
  mutated$active_status[1] <- FALSE
  expect_error(validate_phase12_freeze_manifest(
    output, registry = mutated, protocol = inputs$protocol_path,
    recipe_path = recipe, project_root = inputs$root, parent_paths = inputs$parent_paths
  ), "candidate|active_status|membership")
  phase11_path <- file.path(inputs$root, inputs$parent_paths[["phase11_run_manifest"]])
  writeLines(c(readLines(phase11_path), "tampered"), phase11_path)
  expect_error(validate_phase12_freeze_manifest(
    output, registry = inputs$registry_path, protocol = inputs$protocol_path,
    recipe_path = recipe, project_root = inputs$root, parent_paths = inputs$parent_paths
  ), "parent|checksum|run manifest")
})

test_that("12-01-02 unopened holdout guard rejects consumed markers and labels", {
  expect_invisible(phase12_assert_unopened_holdout(state = list(labels_opened = FALSE)))
  expect_error(phase12_assert_unopened_holdout(state = list(labels_opened = TRUE)), "consumed|opened")
  expect_error(phase12_assert_unopened_holdout(
    data.frame(edition_id = "wc2026", actual_home_goals = 1L, stringsAsFactors = FALSE)
  ), "holdout|outcomes")
})
