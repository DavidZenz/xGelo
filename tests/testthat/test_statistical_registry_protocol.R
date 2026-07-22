library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/benchmark/registry.R"))
source(file.path(project_root, "R/benchmark/challenger_preflight.R"))

protocol_path <- file.path(project_root, "R/benchmark/challenger_protocol.R")
if (file.exists(protocol_path)) source(protocol_path)

task1_api <- c(
  "phase10_protocol_constants", "canonical_phase10_tuning_grid",
  "canonical_phase10_tuning_relations", "validate_phase09_parent_identity",
  "run_pre2002_grid_diagnostic", ".phase10_validate_task1_files"
)

test_that("Task 1 production protocol API exists", {
  expect_true(
    all(vapply(task1_api, exists, logical(1), mode = "function")),
    info = paste("Missing Task 1 production protocol API:", paste(task1_api, collapse = ", "))
  )
})

task1_ready <- all(vapply(task1_api, exists, logical(1), mode = "function"))

copy_task1_protocol <- function() {
  path <- tempfile("phase10-task1-")
  dir.create(path)
  files <- c("model_registry.csv", "feature_contract.csv", "tuning_editions.csv", "tuning_grid.csv")
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

mutate_task1_file <- function(file, mutate) {
  path <- copy_task1_protocol()
  on.exit(unlink(path, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(path, file)
  data <- read_protocol_csv(target)
  write_protocol_csv(mutate(data), target)
  expect_error(.phase10_validate_task1_files(path), regexp = "Phase 10|phase10|canonical|hash|schema|order|row|registry|relation|grid|feature")
}

test_that("canonical candidate, grid, and chronology definitions are exact", {
  skip_if_not(task1_ready)
  constants <- phase10_protocol_constants()
  expect_identical(constants$candidate_ids, c(
    "poisson_team_ridge", "poisson_team_ridge_elo",
    "dynamic_goal_ability", "dynamic_goal_ability_elo",
    "poisson_team_ridge_elo_dc", "poisson_team_ridge_elo_bivpois",
    "open_nb_elo_only_ablation"
  ))
  expect_identical(constants$phase09_bundle_sha256, "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069")
  expect_identical(constants$phase09_registry_sha256, "a3d21b90568aec86f44cefe2964555cb5565e1ab4e205489f42009a3ec489255")
  expect_identical(constants$phase09_checksum_self_sha256, "4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309")
  expect_identical(constants$phase09_parent_graph_sha256, "19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584")

  grid <- canonical_phase10_tuning_grid()
  expect_equal(nrow(grid), 33L)
  expect_identical(grid$parameter_id[1:13], rep("team_ridge_lambda", 13L))
  expect_equal(as.numeric(grid$parameter_value[1:13]), 10^seq(-4, 2, by = 0.5), tolerance = 1e-15)
  expect_identical(grid$parameter_id[14:26], rep("elo_lasso_lambda", 13L))
  expect_equal(as.numeric(grid$parameter_value[14:26]), 10^seq(-5, 1, by = 0.5), tolerance = 1e-15)
  expect_equal(as.numeric(grid$parameter_value[27:31]), c(2, 4, 8, 16, 32))
  expect_identical(grid$half_life_days[27:31], rep("730", 5L))
  expect_identical(grid$parameter_id[32:33], c("dixon_coles_rho", "bivariate_q"))
  expect_identical(grid$interior_epsilon[32], "0.00000001")
  expect_identical(grid$lower_bound[33], "0")
  expect_identical(grid$upper_bound[33], "0.95")
  expect_identical(grid$upper_inclusive[33], "false")
  expect_identical(grid$optimizer_tolerance[33], "0.00000001")

  relations <- canonical_phase10_tuning_relations()
  expect_equal(nrow(relations), 114L)
  expect_identical(unique(relations$outer_edition_id), constants$outer_edition_ids)
  expect_identical(unique(relations$inner_edition_id[relations$inner_source == "pre2002_diagnostic"]),
                   c("wc1994", "euro1996", "wc1998", "euro2000"))
  expect_true(all(as.Date(relations$inner_final_date) < as.Date(relations$outer_opener_date)))
  expect_identical(
    as.integer(table(factor(relations$outer_edition_id, levels = constants$outer_edition_ids))),
    4:15
  )
})

test_that("untouched Task 1 files validate and inherited feature rows remain exact", {
  skip_if_not(task1_ready)
  validated <- .phase10_validate_task1_files(file.path(project_root, "data/benchmark/phase10"))
  expect_true(isTRUE(validated$valid))
  expect_equal(nrow(validated$model_registry), 7L)
  expect_equal(nrow(validated$tuning_grid), 33L)
  expect_equal(nrow(validated$tuning_editions), 114L)

  inherited <- read_protocol_csv(file.path(project_root, "data/benchmark/phase09/feature_contract.csv"))
  expect_identical(validated$feature_contract[seq_len(nrow(inherited)), , drop = FALSE], inherited)
  expect_true(all(c(
    "attack_prior_match_count", "defence_prior_match_count", "team_shrinkage_weight",
    "team_cold_start", "dynamic_state_age_days", "dynamic_state_exposure",
    "dependence_parameter", "xg_form_inactive_status"
  ) %in% validated$feature_contract$feature_id))
})

test_that("Task 1 registries fail closed on schema, row, order, value, and hash drift", {
  skip_if_not(task1_ready)
  mutate_task1_file("model_registry.csv", function(x) x[-1, , drop = FALSE])
  mutate_task1_file("model_registry.csv", function(x) rbind(x, x[1, , drop = FALSE]))
  mutate_task1_file("model_registry.csv", function(x) x[rev(seq_len(nrow(x))), , drop = FALSE])
  mutate_task1_file("model_registry.csv", function(x) { x$adapter_id[1] <- "valid_looking_but_unknown"; x })
  mutate_task1_file("model_registry.csv", function(x) { x$registration_sha256[1] <- strrep("a", 64); x })
  mutate_task1_file("model_registry.csv", function(x) x[, -1, drop = FALSE])
  mutate_task1_file("model_registry.csv", function(x) { x$extra <- "forbidden"; x })

  mutate_task1_file("feature_contract.csv", function(x) x[-1, , drop = FALSE])
  mutate_task1_file("feature_contract.csv", function(x) rbind(x, x[1, , drop = FALSE]))
  mutate_task1_file("feature_contract.csv", function(x) x[c(2, 1, 3:nrow(x)), , drop = FALSE])
  mutate_task1_file("feature_contract.csv", function(x) { x$definition[1] <- paste0(x$definition[1], " drift"); x })
  mutate_task1_file("feature_contract.csv", function(x) { x$row_sha256[1] <- strrep("b", 64); x })

  mutate_task1_file("tuning_grid.csv", function(x) x[-1, , drop = FALSE])
  mutate_task1_file("tuning_grid.csv", function(x) rbind(x, x[1, , drop = FALSE]))
  mutate_task1_file("tuning_grid.csv", function(x) x[c(2, 1, 3:nrow(x)), , drop = FALSE])
  mutate_task1_file("tuning_grid.csv", function(x) { x$parameter_value[1] <- "1e-04"; x })
  mutate_task1_file("tuning_grid.csv", function(x) { x$row_sha256[1] <- strrep("c", 64); x })

  mutate_task1_file("tuning_editions.csv", function(x) x[-1, , drop = FALSE])
  mutate_task1_file("tuning_editions.csv", function(x) rbind(x, x[1, , drop = FALSE]))
  mutate_task1_file("tuning_editions.csv", function(x) x[c(2, 1, 3:nrow(x)), , drop = FALSE])
  mutate_task1_file("tuning_editions.csv", function(x) { x$inner_edition_id[1] <- "euro1996"; x })
  mutate_task1_file("tuning_editions.csv", function(x) { x$relation_sha256[1] <- strrep("d", 64); x })
})

test_that("Phase 9 parent identity is reconstructed from durable evidence", {
  skip_if_not(task1_ready)
  parent <- validate_phase09_parent_identity()
  expect_true(isTRUE(parent$valid))
  expect_identical(parent$bundle_sha256, phase10_protocol_constants()$phase09_bundle_sha256)
  expect_identical(parent$model_registry_sha256, phase10_protocol_constants()$phase09_registry_sha256)
  expect_identical(parent$checksum_self_sha256, phase10_protocol_constants()$phase09_checksum_self_sha256)
  expect_identical(parent$parent_graph_sha256, phase10_protocol_constants()$phase09_parent_graph_sha256)
})

test_that("pre-2002 diagnostic is finite, assessment-free, and read-only", {
  skip_if_not(task1_ready)
  result <- run_pre2002_grid_diagnostic()
  expect_true(isTRUE(result$valid))
  expect_identical(result$edition_ids, c("wc1994", "euro1996", "wc1998", "euro2000"))
  expect_true(result$max_evidence_date < as.Date("2002-01-01"))
  expect_true(isTRUE(result$assessment_rows_absent))
  expect_true(all(result$finite_reach))
  expect_identical(result$grid_sha256_before, result$grid_sha256_after)
})
