library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/benchmark/registry.R"))
source(file.path(project_root, "R/benchmark/challenger_protocol.R"))

task2_api <- c(
  "canonical_phase10_selection_protocol", "load_and_validate_challenger_protocol",
  "measure_challenger_partition_storage", "validate_challenger_storage_preflight",
  ".phase10_validate_task2_files", ".phase10_protocol_sha256"
)

test_that("Task 2 production protocol API exists", {
  expect_true(
    all(vapply(task2_api, exists, logical(1), mode = "function")),
    info = paste("Missing Task 2 production protocol API:", paste(task2_api, collapse = ", "))
  )
})

task2_ready <- all(vapply(task2_api, exists, logical(1), mode = "function"))

copy_task2_protocol <- function() {
  path <- tempfile("phase10-task2-")
  dir.create(path)
  files <- c("ablation_registry.csv", "selection_protocol.json", "storage_preflight.csv")
  copied <- file.copy(file.path(project_root, "data/benchmark/phase10", files), path)
  expect_true(all(copied))
  path
}

read_protocol_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
}

write_protocol_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
}

mutate_task2_csv <- function(file, mutate) {
  path <- copy_task2_protocol()
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(path, file)
  data <- read_protocol_csv(target)
  write_protocol_csv(mutate(data), target)
  expect_error(.phase10_validate_task2_files(path), regexp = "Phase 10|phase10|canonical|hash|schema|order|row|ablation|storage|formula|projection")
}

mutate_selection <- function(mutate, refresh_hash = FALSE, expected = "Phase 10|phase10|protocol|hash|selection|shortlist|forbidden|threshold") {
  path <- copy_task2_protocol()
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(path, "selection_protocol.json")
  protocol <- jsonlite::read_json(target, simplifyVector = FALSE)
  protocol <- mutate(protocol)
  if (isTRUE(refresh_hash)) protocol$protocol_sha256 <- .phase10_protocol_sha256(protocol)
  jsonlite::write_json(protocol, target, auto_unbox = TRUE, pretty = TRUE, digits = 17)
  expect_error(.phase10_validate_task2_files(path), regexp = expected)
}

test_that("ablation graph, thresholds, and shortlist are exact and research-only", {
  skip_if_not(task2_ready)
  protocol <- load_and_validate_challenger_protocol(file.path(project_root, "data/benchmark/phase10"), validate_parent = FALSE)
  expect_true(isTRUE(protocol$valid))
  expect_identical(protocol$shortlist_slots, c(
    "best_proper_score", "simplest_non_inferior", "dependence_representative"
  ))
  expect_identical(protocol$thresholds, c(
    dependence_rps_gain = -0.001,
    practical_tie = 0.0005,
    simpler_noninferiority = 0.001,
    brier_relative = 0.01,
    log_relative = 0.01,
    calibration = 0.01,
    maximum_fold_regression = 0.015,
    fold_wins = 8,
    world_cup_wins = 2,
    euro_wins = 2
  ))
  expect_identical(protocol$ablation_registry$ablation_id, c(
    "open_nb_incumbent", "open_nb_elo_only_ablation", "attack_xg",
    "defence_xg", "xgd", "form"
  ))
  expect_identical(protocol$ablation_registry$parent_candidate_id, c(
    "", rep("open_nb_incumbent", 5L)
  ))
  expect_identical(protocol$ablation_registry$activation_status,
                   c("reference_parent", "scored", rep("not_activated_zero_coverage", 4L)))
  expect_identical(protocol$ablation_registry$source_present[3:6], rep("false", 4L))
  expect_identical(protocol$ablation_registry$value_present[3:6], rep("false", 4L))
  expect_identical(protocol$ablation_registry$imputed[3:6], rep("true", 4L))
  expect_identical(protocol$ablation_registry$active_in_fit[3:6], rep("false", 4L))

  serialized <- tolower(jsonlite::toJSON(protocol$selection, auto_unbox = TRUE, null = "null"))
  expect_false(grepl("promot|release|final[_ -]?holdout|wc.?2026|world cup 2026", serialized, perl = TRUE))
})

test_that("ablation and selection artifacts fail closed on every drift class", {
  skip_if_not(task2_ready)
  mutate_task2_csv("ablation_registry.csv", function(x) x[-1, , drop = FALSE])
  mutate_task2_csv("ablation_registry.csv", function(x) rbind(x, x[1, , drop = FALSE]))
  mutate_task2_csv("ablation_registry.csv", function(x) x[c(2, 1, 3:nrow(x)), , drop = FALSE])
  mutate_task2_csv("ablation_registry.csv", function(x) { x$parent_candidate_id[3] <- "open_nb_elo_only_ablation"; x })
  mutate_task2_csv("ablation_registry.csv", function(x) { x$parent_candidate_id[1] <- "form"; x })
  mutate_task2_csv("ablation_registry.csv", function(x) { x$activation_status[3] <- "scored"; x })
  mutate_task2_csv("ablation_registry.csv", function(x) { x$row_sha256[1] <- strrep("a", 64); x })

  mutate_selection(function(x) { x$shortlist$slots <- x$shortlist$slots[-1]; x })
  mutate_selection(function(x) { x$shortlist$slots <- c(x$shortlist$slots, "extra_slot"); x })
  mutate_selection(function(x) { x$shortlist$slots <- rev(x$shortlist$slots); x })
  mutate_selection(function(x) { x$thresholds$dependence_meaningful_rps_delta$value <- -0.002; x })
  mutate_selection(function(x) { x$protocol_sha256 <- strrep("b", 64); x })
  mutate_selection(function(x) { x$governance$release_decision <- TRUE; x }, refresh_hash = TRUE, expected = "forbidden")
  mutate_selection(function(x) { x$source_paths <- c(x$source_paths, "outputs/wc2026/results.csv"); x }, refresh_hash = TRUE, expected = "forbidden")
})

test_that("storage preflight freezes deterministic exact-cardinality measurement", {
  skip_if_not(task2_ready)
  loaded <- load_and_validate_challenger_protocol(file.path(project_root, "data/benchmark/phase10"), validate_parent = FALSE)
  storage <- loaded$storage
  expect_true(validate_challenger_storage_preflight(storage))
  expect_identical(as.numeric(storage$fixture_count), 630)
  expect_identical(as.numeric(storage$track_count), 2)
  expect_identical(as.numeric(storage$distribution_count), 1260)
  expect_identical(as.numeric(storage$support_max), 40)
  expect_identical(as.numeric(storage$rows_per_distribution), 1681)
  expect_identical(as.numeric(storage$pilot_row_count), 2118060)
  expect_identical(storage$content_sha256, storage$deterministic_replay_sha256)
  expect_identical(as.numeric(storage$score_projection), 7 * as.numeric(storage$compressed_bytes))
  expected_bundle <- as.numeric(storage$score_projection) + max(1024^3, ceiling(0.25 * as.numeric(storage$score_projection)))
  expect_identical(as.numeric(storage$one_bundle_projection), expected_bundle)
  expect_identical(as.numeric(storage$minimum_free_bytes), ceiling(3 * expected_bundle * 1.10))
  expect_identical(as.numeric(storage$worker_ceiling), 2)
})

test_that("storage validator rejects operand, hash, boolean, and schema mutations", {
  skip_if_not(task2_ready)
  fields <- c(
    "fixture_count", "track_count", "distribution_count", "support_max",
    "rows_per_distribution", "pilot_row_count", "compressed_bytes",
    "score_projection", "one_bundle_projection", "minimum_free_bytes",
    "worker_ceiling", "measured_available_bytes", "schema_sha256",
    "generator_sha256", "content_sha256", "deterministic_replay_sha256",
    "cardinality_valid", "formula_valid", "free_space_pass", "row_sha256"
  )
  for (field in fields) {
    mutate_task2_csv("storage_preflight.csv", function(x) {
      if (grepl("sha256$", field)) x[[field]] <- strrep("c", 64)
      else if (field %in% c("cardinality_valid", "formula_valid", "free_space_pass")) x[[field]] <- ifelse(x[[field]] == "true", "false", "true")
      else x[[field]] <- as.character(suppressWarnings(as.numeric(x[[field]]) + 1))
      x
    })
  }
  mutate_task2_csv("storage_preflight.csv", function(x) x[, -1, drop = FALSE])
  mutate_task2_csv("storage_preflight.csv", function(x) { x$extra <- "forbidden"; x })
})

test_that("protocol loading never reaches the Phase 9 promotion evaluator", {
  skip_if_not(task2_ready)
  called <- FALSE
  evaluate_promotion <- function(...) {
    called <<- TRUE
    stop("promotion evaluator must remain unreachable")
  }
  result <- load_and_validate_challenger_protocol(file.path(project_root, "data/benchmark/phase10"), validate_parent = FALSE)
  expect_true(isTRUE(result$valid))
  expect_false(called)
})
