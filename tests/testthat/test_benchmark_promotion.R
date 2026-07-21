library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/benchmark/registry.R"))
source(file.path(project_root, "R/evaluation/proper_scores.R"))
source(file.path(project_root, "R/benchmark/contracts.R"))
source(file.path(project_root, "R/evaluation/promotion.R"))

protocol_path <- file.path(project_root, "data/benchmark/phase09/promotion_protocol.json")
registry_dir <- dirname(protocol_path)
frozen_protocol <- load_promotion_protocol(protocol_path)

all_contracts_pass <- function() {
  fields <- c(
    "probability_valid", "distribution_valid", "fixture_valid", "coverage_valid",
    "provenance_valid", "license_valid", "seed_valid", "checksum_valid",
    "reproducible", "code_frozen", "features_frozen", "settings_frozen",
    "panels_frozen", "seeds_frozen", "wc2026_sealed"
  )
  stats::setNames(as.list(rep(TRUE, length(fields))), fields)
}

promotion_case <- function(optional = FALSE) {
  editions <- c("wc2002", "wc2006", "wc2010", "wc2014", "wc2018", "wc2022",
                "euro2004", "euro2008", "euro2012", "euro2016", "euro2020", "euro2024")
  coverage <- data.frame(
    edition_id = editions, output_coverage = 1, output_coverage_complete = TRUE,
    provenance_complete = TRUE, required_fixture_count = 1L, observed_fixture_count = 1L,
    stringsAsFactors = FALSE
  )
  list(
    candidate_id = if (optional) "rich_candidate" else "open_candidate",
    incumbent_id = "open_nb_incumbent",
    uses_optional_data = optional,
    core = list(
      rps_delta = -0.004, ci_upper = -0.001, fold_wins = 8L,
      world_cup_wins = 4L, euro_wins = 4L, maximum_fold_regression = 0.01,
      brier_relative_change = 0, log_loss_relative_change = 0,
      calibration_change = 0, fixture_count = 630L
    ),
    contracts = all_contracts_pass(),
    rich_panel = list(
      incumbent_id = "production_hybrid_nb", panel_declared = TRUE,
      coverage_observations = coverage, rps_delta = -0.004, ci_upper = -0.001,
      fold_wins = 8L, world_cup_wins = 4L, euro_wins = 4L,
      maximum_fold_regression = 0.01, brier_relative_change = 0,
      log_loss_relative_change = 0, calibration_change = 0,
      contracts = all_contracts_pass()
    ),
    open_companion = list(
      candidate_id = "rich_candidate_open", incumbent_id = "open_nb_incumbent",
      fixture_count = 630L, default_open_mode = TRUE, rps_delta = -0.001,
      ci_upper = 0.002, maximum_fold_regression = 0.01,
      brier_relative_change = 0, log_loss_relative_change = 0,
      calibration_change = 0, contracts = all_contracts_pass()
    )
  )
}

decision_for <- function(case) evaluate_promotion(case, frozen_protocol)

complete_gate_value_names <- function() {
  c(
    "core_rps_delta", "core_ci_upper", "core_fold_wins",
    "core_world_cup_wins", "core_euro_wins", "core_maximum_fold_regression",
    "core_brier_relative_change", "core_log_loss_relative_change",
    "core_calibration_change", "uses_optional_data",
    "rich_incumbent_id", "rich_panel_declared",
    "rich_output_coverage_by_edition", "rich_output_coverage_complete_by_edition",
    "rich_provenance_complete_by_edition",
    "rich_required_fixture_count_by_edition", "rich_observed_fixture_count_by_edition",
    "rich_rps_delta", "rich_ci_upper", "rich_fold_wins",
    "rich_world_cup_wins", "rich_euro_wins", "rich_maximum_fold_regression",
    "rich_brier_relative_change", "rich_log_loss_relative_change",
    "rich_calibration_change", "open_companion_incumbent_id",
    "open_companion_fixture_count", "open_companion_default_open_mode",
    "open_companion_rps_delta", "open_companion_ci_upper",
    "open_companion_maximum_fold_regression",
    "open_companion_brier_relative_change",
    "open_companion_log_loss_relative_change",
    "open_companion_calibration_change",
    paste0("common_", names(all_contracts_pass())),
    paste0("rich_", names(all_contracts_pass())),
    paste0("open_companion_", names(all_contracts_pass()))
  )
}

complete_gate_pass_names <- function() {
  c(
    paste0("common_", names(all_contracts_pass())),
    "core_rps_effect", "core_ci", "core_fold_breadth",
    "core_world_cup_breadth", "core_euro_breadth", "core_max_regression",
    "core_brier", "core_log_loss", "core_calibration",
    "rich_panel_present", "rich_panel_declared", "rich_incumbent", "rich_output_coverage",
    "rich_provenance", "rich_edition_coverage_floor",
    paste0("rich_", names(all_contracts_pass())),
    "rich_rps_effect", "rich_ci", "rich_fold_breadth",
    "rich_world_cup_breadth", "rich_euro_breadth", "rich_max_regression",
    "rich_brier", "rich_log_loss", "rich_calibration",
    "open_companion_present", "open_companion_incumbent", "open_companion_coverage", "default_open_mode",
    paste0("open_companion_", names(all_contracts_pass())),
    "open_companion_rps_effect", "open_companion_ci",
    "open_companion_max_regression", "open_companion_brier",
    "open_companion_log_loss", "open_companion_calibration"
  )
}

expect_eligible <- function(case) {
  expect_equal(decision_for(case)$decision, "eligible_for_final_holdout")
}

expect_retained <- function(case, reason) {
  result <- decision_for(case)
  expect_equal(result$decision, "retain_incumbent")
  expect_true(reason %in% result$reason_codes)
}

test_that("the frozen promotion protocol validates and hashes canonically", {
  protocol <- frozen_protocol
  expect_silent(validate_promotion_protocol(protocol, registry_dir = registry_dir))
  expect_identical(
    canonicalize_promotion_protocol(protocol),
    canonicalize_promotion_protocol(protocol[rev(names(protocol))])
  )
  expect_match(protocol$protocol_sha256, "^[0-9a-f]{64}$")
  expect_equal(protocol$score_support$selected_g, 40L)
  expect_equal(protocol$bootstrap$replicates, 10000L)
  expect_equal(protocol$fixed_probability_bins, seq(0, 1, 0.1))
  expect_false(any(grepl("actual_(home|away)_goals|wc2026_result", canonicalize_promotion_protocol(protocol))))
  expect_length(promotion_veto_reasons(promotion_case(), protocol), 0L)
})

test_that("D-16 through D-20 expose complete full-precision values and booleans", {
  candidate <- promotion_case(TRUE)
  candidate$core$rps_delta <- -0.0030000000000004
  result <- decision_for(candidate)

  expect_identical(names(result$gate_values), complete_gate_value_names())
  expect_identical(names(result$gate_passes), complete_gate_pass_names())
  expect_identical(result$gate_values$core_rps_delta, candidate$core$rps_delta)
  expect_identical(
    result$gate_values$rich_output_coverage_by_edition,
    stats::setNames(candidate$rich_panel$coverage_observations$output_coverage,
                    candidate$rich_panel$coverage_observations$edition_id)
  )
  expect_true(all(vapply(result$gate_passes, is.logical, logical(1))))
  expect_true(all(lengths(result$gate_passes) == 1L))
})

test_that("false gate booleans and ordered reasons agree one-to-one", {
  candidate <- promotion_case(TRUE)
  candidate$contracts$distribution_valid <- FALSE
  candidate$core$rps_delta <- -0.002
  candidate$rich_panel$coverage_observations$provenance_complete[1] <- FALSE
  candidate$open_companion$default_open_mode <- FALSE

  result <- decision_for(candidate)
  failed <- names(result$gate_passes)[!unlist(result$gate_passes, use.names = FALSE)]
  expect_identical(
    result$reason_codes,
    unname(promotion_gate_reason_map()[failed])
  )
  expect_false(anyNA(result$reason_codes))
  expect_true(all(nzchar(result$reason_codes)))
})

test_that("clean and failed reason serialization preserve empty semantics", {
  clean <- decision_for(promotion_case(TRUE))
  expect_type(clean$reason_codes, "character")
  expect_length(clean$reason_codes, 0L)
  expect_identical(paste(clean$reason_codes, collapse = "|"), "")
  expect_true(all(unlist(clean$gate_passes, use.names = FALSE)))
  expect_length(promotion_contract_reasons(all_contracts_pass()), 0L)

  failed_case <- promotion_case()
  failed_case$core$ci_upper <- 0
  failed <- decision_for(failed_case)
  expect_true(nzchar(paste(failed$reason_codes, collapse = "|")))
  expect_false(failed$gate_passes$core_ci)
})

test_that("core practical-effect boundaries are exact and unrounded", {
  eps <- 1e-12
  for (value in c(-0.003 - eps, -0.003)) {
    x <- promotion_case(); x$core$rps_delta <- value; expect_eligible(x)
  }
  x <- promotion_case(); x$core$rps_delta <- -0.003 + eps
  expect_retained(x, "core_rps_effect_failed")

  x <- promotion_case(); x$core$ci_upper <- -eps; expect_eligible(x)
  x <- promotion_case(); x$core$ci_upper <- 0; expect_retained(x, "core_ci_failed")
  x <- promotion_case(); x$core$ci_upper <- eps; expect_retained(x, "core_ci_failed")

  for (value in c(0.015 - eps, 0.015)) {
    x <- promotion_case(); x$core$maximum_fold_regression <- value; expect_eligible(x)
  }
  x <- promotion_case(); x$core$maximum_fold_regression <- 0.015 + eps
  expect_retained(x, "core_max_regression_failed")
})

test_that("core breadth boundaries count strict fold wins by competition", {
  x <- promotion_case(); x$core$fold_wins <- 7L; expect_retained(x, "core_fold_breadth_failed")
  x <- promotion_case(); x$core$fold_wins <- 8L; expect_eligible(x)
  x <- promotion_case(); x$core$fold_wins <- 9L; expect_eligible(x)
  x <- promotion_case(); x$core$world_cup_wins <- 1L; expect_retained(x, "core_world_cup_breadth_failed")
  x <- promotion_case(); x$core$world_cup_wins <- 2L; expect_eligible(x)
  x <- promotion_case(); x$core$world_cup_wins <- 3L; expect_eligible(x)
  x <- promotion_case(); x$core$euro_wins <- 1L; expect_retained(x, "core_euro_breadth_failed")
  x <- promotion_case(); x$core$euro_wins <- 2L; expect_eligible(x)
  x <- promotion_case(); x$core$euro_wins <- 3L; expect_eligible(x)
})

test_that("supporting-score boundaries pass at the limit and fail one step above", {
  eps <- 1e-12
  checks <- list(
    brier_relative_change = "core_brier_veto",
    log_loss_relative_change = "core_log_loss_veto",
    calibration_change = "core_calibration_veto"
  )
  for (field in names(checks)) {
    x <- promotion_case(); x$core[[field]] <- 0.01 - eps; expect_eligible(x)
    x <- promotion_case(); x$core[[field]] <- 0.01; expect_eligible(x)
    x <- promotion_case(); x$core[[field]] <- 0.01 + eps
    expect_retained(x, checks[[field]])
  }
})

test_that("every common contract failure is an ordered hard veto", {
  expected <- c(
    probability_valid = "probability_contract_failed",
    distribution_valid = "distribution_contract_failed",
    fixture_valid = "fixture_contract_failed",
    coverage_valid = "coverage_contract_failed",
    provenance_valid = "provenance_contract_failed",
    license_valid = "license_contract_failed",
    seed_valid = "seed_contract_failed",
    checksum_valid = "checksum_contract_failed",
    reproducible = "reproducibility_failed",
    code_frozen = "code_freeze_failed",
    features_frozen = "features_freeze_failed",
    settings_frozen = "settings_freeze_failed",
    panels_frozen = "panels_freeze_failed",
    seeds_frozen = "seeds_freeze_failed",
    wc2026_sealed = "wc2026_seal_failed"
  )
  for (field in names(expected)) {
    x <- promotion_case(); x$contracts[[field]] <- FALSE
    result <- decision_for(x)
    expect_equal(result$decision, "veto", info = field)
    expect_true(expected[[field]] %in% result$reason_codes, info = field)
  }
})

test_that("rich-panel effect and uncertainty use production hybrid exact boundaries", {
  eps <- 1e-12
  for (value in c(-0.003 - eps, -0.003)) {
    x <- promotion_case(TRUE); x$rich_panel$rps_delta <- value; expect_eligible(x)
  }
  x <- promotion_case(TRUE); x$rich_panel$rps_delta <- -0.003 + eps
  expect_retained(x, "rich_rps_effect_failed")

  x <- promotion_case(TRUE); x$rich_panel$ci_upper <- -eps; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$ci_upper <- 0
  expect_retained(x, "rich_ci_failed")
  x <- promotion_case(TRUE); x$rich_panel$ci_upper <- eps
  expect_retained(x, "rich_ci_failed")

  x <- promotion_case(TRUE); x$rich_panel$incumbent_id <- "not_production"
  expect_equal(decision_for(x)$decision, "veto")
})

test_that("rich-panel breadth, regression, and supporting vetoes mirror the core gate", {
  eps <- 1e-12
  x <- promotion_case(TRUE); x$rich_panel$fold_wins <- 7L; expect_retained(x, "rich_fold_breadth_failed")
  x <- promotion_case(TRUE); x$rich_panel$fold_wins <- 8L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$fold_wins <- 9L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$world_cup_wins <- 1L; expect_retained(x, "rich_world_cup_breadth_failed")
  x <- promotion_case(TRUE); x$rich_panel$world_cup_wins <- 2L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$world_cup_wins <- 3L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$euro_wins <- 1L; expect_retained(x, "rich_euro_breadth_failed")
  x <- promotion_case(TRUE); x$rich_panel$euro_wins <- 2L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$euro_wins <- 3L; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$maximum_fold_regression <- 0.015 - eps; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$maximum_fold_regression <- 0.015; expect_eligible(x)
  x <- promotion_case(TRUE); x$rich_panel$maximum_fold_regression <- 0.015 + eps
  expect_retained(x, "rich_max_regression_failed")
  expected_reasons <- c(
    brier_relative_change = "rich_brier_veto",
    log_loss_relative_change = "rich_log_loss_veto",
    calibration_change = "rich_calibration_veto"
  )
  for (field in names(expected_reasons)) {
    x <- promotion_case(TRUE); x$rich_panel[[field]] <- 0.01 - eps; expect_eligible(x)
    x <- promotion_case(TRUE); x$rich_panel[[field]] <- 0.01; expect_eligible(x)
    x <- promotion_case(TRUE); x$rich_panel[[field]] <- 0.01 + eps
    expect_retained(x, expected_reasons[[field]])
  }
})

test_that("rich eligibility is derived from observed outputs, provenance, and the frozen floor", {
  x <- promotion_case(TRUE)
  x$rich_panel$promotion_eligible <- TRUE
  x$rich_panel$coverage_observations$output_coverage_complete[1] <- FALSE
  x$rich_panel$coverage_observations$observed_fixture_count[1] <- 0L
  x$rich_panel$coverage_observations$output_coverage[1] <- 0
  result <- decision_for(x)
  expect_equal(result$decision, "veto")
  expect_true("rich_output_coverage_incomplete" %in% result$reason_codes)

  x <- promotion_case(TRUE)
  x$rich_panel$coverage_observations$provenance_complete[1] <- FALSE
  expect_true("rich_provenance_incomplete" %in% decision_for(x)$reason_codes)

  x <- promotion_case(TRUE)
  x$rich_panel$coverage_observations$output_coverage[1] <- 0.8 - 1e-12
  expect_true("rich_edition_coverage_floor_failed" %in% decision_for(x)$reason_codes)
})

test_that("open companion gates preserve all 630 fixtures and exact non-regression boundaries", {
  eps <- 1e-12
  x <- promotion_case(TRUE); x$open_companion$rps_delta <- -eps; expect_eligible(x)
  x <- promotion_case(TRUE); x$open_companion$rps_delta <- 0; expect_eligible(x)
  x <- promotion_case(TRUE); x$open_companion$rps_delta <- eps
  expect_retained(x, "open_companion_rps_effect_failed")

  x <- promotion_case(TRUE); x$open_companion$ci_upper <- 0.003 - eps; expect_eligible(x)
  x <- promotion_case(TRUE); x$open_companion$ci_upper <- 0.003
  expect_retained(x, "open_companion_ci_failed")
  x <- promotion_case(TRUE); x$open_companion$ci_upper <- 0.003 + eps
  expect_retained(x, "open_companion_ci_failed")

  x <- promotion_case(TRUE); x$open_companion$maximum_fold_regression <- 0.015; expect_eligible(x)
  x <- promotion_case(TRUE); x$open_companion$maximum_fold_regression <- 0.015 - eps; expect_eligible(x)
  x <- promotion_case(TRUE); x$open_companion$maximum_fold_regression <- 0.015 + eps
  expect_retained(x, "open_companion_max_regression_failed")

  x <- promotion_case(TRUE); x$open_companion$fixture_count <- 629L
  expect_equal(decision_for(x)$decision, "veto")
  x <- promotion_case(TRUE); x$open_companion$default_open_mode <- FALSE
  expect_equal(decision_for(x)$decision, "veto")

  for (field in c("brier_relative_change", "log_loss_relative_change", "calibration_change")) {
    x <- promotion_case(TRUE); x$open_companion[[field]] <- 0.01 - eps; expect_eligible(x)
    x <- promotion_case(TRUE); x$open_companion[[field]] <- 0.01; expect_eligible(x)
    x <- promotion_case(TRUE); x$open_companion[[field]] <- 0.01 + eps
    expect_equal(decision_for(x)$decision, "retain_incumbent")
  }
})

test_that("optional variants apply every common veto to rich and open companions", {
  x <- promotion_case(TRUE); x$rich_panel$contracts$license_valid <- FALSE
  expect_equal(decision_for(x)$decision, "veto")
  expect_true("rich_license_contract_failed" %in% decision_for(x)$reason_codes)
  x <- promotion_case(TRUE); x$open_companion$contracts$distribution_valid <- FALSE
  expect_equal(decision_for(x)$decision, "veto")
  expect_true("open_companion_distribution_contract_failed" %in% decision_for(x)$reason_codes)
})

test_that("multiple vetoes retain the frozen reason-code order", {
  x <- promotion_case()
  x$contracts$distribution_valid <- FALSE
  x$contracts$fixture_valid <- FALSE
  expect_equal(
    decision_for(x)$reason_codes[1:2],
    c("distribution_contract_failed", "fixture_contract_failed")
  )
})

test_that("protocol validation detects normalized audit, selected G, and parent tampering", {
  protocol <- load_promotion_protocol(protocol_path)
  artifacts <- promotion_protocol_artifacts(registry_dir)

  bad_hash <- protocol
  bad_hash$score_support$score_support_audit_sha256 <- strrep("0", 64)
  bad_hash$protocol_sha256 <- promotion_protocol_sha256(bad_hash)
  expect_error(validate_promotion_protocol(bad_hash, artifacts = artifacts), "score-support audit SHA-256")

  bad_g <- protocol
  bad_g$score_support$selected_g <- 39L
  bad_g$protocol_sha256 <- promotion_protocol_sha256(bad_g)
  expect_error(validate_promotion_protocol(bad_g, artifacts = artifacts), "selected G")

  bad_parent <- artifacts
  bad_parent$score_support_audit$parent_hashes[1] <- strrep("f", 64)
  bad_parent$score_support_audit$row_hash <- benchmark_row_sha256(
    bad_parent$score_support_audit, "row_hash"
  )
  expect_error(validate_promotion_protocol(protocol, artifacts = bad_parent), "parent hash")
})

test_that("self comparison and exact fold ties retain the incumbent", {
  x <- promotion_case()
  x$candidate_id <- "open_nb_incumbent"
  x$core$rps_delta <- 0
  x$core$ci_upper <- 0
  x$core$fold_wins <- 0L
  x$core$world_cup_wins <- 0L
  x$core$euro_wins <- 0L
  result <- decision_for(x)
  expect_equal(result$decision, "retain_incumbent")
  expect_equal(result$gate_values$core_rps_delta, 0)
})

test_that("eligible candidates use the frozen deterministic tie-break order", {
  evaluations <- data.frame(
    candidate_id = c("open_nb_incumbent", "zeta", "alpha", "beta"),
    decision = c("incumbent", rep("eligible_for_final_holdout", 3)),
    core_headline_rps = c(0.20, 0.19, 0.19, 0.19),
    core_log_loss = c(0.70, 0.68, 0.68, 0.68),
    core_brier = c(0.50, 0.49, 0.49, 0.49),
    core_calibration_error = c(0.04, 0.03, 0.03, 0.03),
    complexity_rank = c(4L, 7L, 6L, 6L), stringsAsFactors = FALSE
  )
  expect_equal(select_promoted_candidate(evaluations, "open_nb_incumbent")$selected_id, "alpha")

  tied <- evaluations[1:2, ]
  tied[2, c("core_headline_rps", "core_log_loss", "core_brier", "core_calibration_error", "complexity_rank")] <-
    tied[1, c("core_headline_rps", "core_log_loss", "core_brier", "core_calibration_error", "complexity_rank")]
  expect_equal(select_promoted_candidate(tied, "open_nb_incumbent")$selected_id, "open_nb_incumbent")
})
