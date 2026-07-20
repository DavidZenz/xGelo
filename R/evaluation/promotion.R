#' Frozen promotion governance for rolling tournament benchmarks

promotion_require_namespace <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(package, " is required for promotion protocol validation", call. = FALSE)
  }
}

promotion_sort_json_object <- function(x) {
  if (!is.list(x)) return(x)
  named_object <- !is.null(names(x)) && length(names(x)) && all(nzchar(names(x)))
  if (named_object) x <- x[sort(names(x), method = "radix")]
  lapply(x, promotion_sort_json_object)
}

#' Canonically serialize a promotion protocol without its self-checksum
#' @export
canonicalize_promotion_protocol <- function(protocol) {
  promotion_require_namespace("jsonlite")
  protocol$protocol_sha256 <- NULL
  canonical <- promotion_sort_json_object(protocol)
  as.character(jsonlite::toJSON(
    canonical, auto_unbox = TRUE, null = "null", na = "null",
    digits = 17, pretty = FALSE, force = TRUE
  ))
}

#' Compute the canonical protocol SHA-256
#' @export
promotion_protocol_sha256 <- function(protocol) {
  promotion_require_namespace("digest")
  digest::digest(
    canonicalize_promotion_protocol(protocol), algo = "sha256", serialize = FALSE
  )
}

#' Load all registry artifacts bound into the promotion protocol
#' @export
promotion_protocol_artifacts <- function(registry_dir) {
  files <- c(
    tournaments = "tournaments.csv", fixtures = "fixtures.csv", panels = "panels.csv",
    panel_fixtures = "panel_fixtures.csv", model_registry = "model_registry.csv",
    seed_registry = "seed_registry.csv", feature_contract = "feature_contract.csv",
    score_support_audit = "score_support_audit.csv", boundaries = "boundaries.csv"
  )
  paths <- file.path(registry_dir, unname(files))
  if (any(!file.exists(paths))) {
    stop("Promotion protocol registry artifacts are incomplete", call. = FALSE)
  }
  stats::setNames(lapply(paths, utils::read.csv, stringsAsFactors = FALSE), names(files))
}

promotion_protocol_hash_specs <- function() {
  list(
    tournaments = "edition_id",
    fixtures = "fixture_id",
    panels = "panel_id",
    panel_fixtures = c("panel_id", "fixture_id"),
    model_registry = "model_id",
    seed_registry = "seed_id",
    feature_contract = c("panel_id", "feature_id"),
    score_support_audit = c("model_id", "edition_id", "track_id", "boundary_id", "candidate_g")
  )
}

promotion_protocol_assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

promotion_protocol_rule <- function(protocol, group, rule) {
  protocol[[group]][[rule]]
}

#' Validate the checksum-backed D-16 through D-20 protocol and all parent artifacts
#' @export
validate_promotion_protocol <- function(protocol, registry_dir = NULL, artifacts = NULL) {
  if (!is.list(protocol)) stop("Promotion protocol must be a JSON object", call. = FALSE)
  required <- c(
    "schema_version", "protocol_version", "protocol_sha256", "source_git_sha",
    "development_editions", "primary_track", "incumbents", "panels",
    "fixed_probability_bins", "bootstrap", "core_gate", "supporting_vetoes",
    "optional_data_gate", "common_vetoes", "tie_break_order", "artifact_hashes",
    "model_hashes", "score_support", "freeze", "final_holdout"
  )
  missing <- setdiff(required, names(protocol))
  if (length(missing)) stop("Promotion protocol missing fields: ", paste(missing, collapse = ", "), call. = FALSE)
  promotion_protocol_assert(
    grepl("^[0-9a-f]{64}$", protocol$protocol_sha256) &&
      identical(tolower(protocol$protocol_sha256), promotion_protocol_sha256(protocol)),
    "Promotion protocol SHA-256 mismatch"
  )

  expected_editions <- c(
    "wc2002", "wc2006", "wc2010", "wc2014", "wc2018", "wc2022",
    "euro2004", "euro2008", "euro2012", "euro2016", "euro2020", "euro2024"
  )
  promotion_protocol_assert(identical(as.character(protocol$development_editions), expected_editions), "Promotion protocol edition order drifted")
  promotion_protocol_assert(
    isTRUE(all.equal(as.numeric(protocol$fixed_probability_bins), seq(0, 1, 0.1), tolerance = .Machine$double.eps)),
    "Promotion protocol fixed bins drifted"
  )
  promotion_protocol_assert(identical(protocol$primary_track, "updating"), "Promotion protocol primary track drifted")
  promotion_protocol_assert(as.integer(protocol$bootstrap$replicates) == 10000L, "Promotion protocol bootstrap repetitions drifted")
  promotion_protocol_assert(identical(protocol$bootstrap$resampling_unit, "tournament"), "Promotion protocol must bootstrap tournaments")
  promotion_protocol_assert(as.integer(protocol$bootstrap$quantile_type) == 8L, "Promotion protocol bootstrap quantile type drifted")

  exact_rules <- list(
    list(protocol$core_gate$rps_delta, "<=", -0.003),
    list(protocol$core_gate$ci_upper, "<", 0),
    list(protocol$core_gate$fold_wins, ">=", 8),
    list(protocol$core_gate$world_cup_wins, ">=", 2),
    list(protocol$core_gate$euro_wins, ">=", 2),
    list(protocol$core_gate$maximum_fold_regression, "<=", 0.015),
    list(protocol$supporting_vetoes$brier_relative_change, "<=", 0.01),
    list(protocol$supporting_vetoes$log_loss_relative_change, "<=", 0.01),
    list(protocol$supporting_vetoes$calibration_change, "<=", 0.01),
    list(protocol$optional_data_gate$rich$rps_delta, "<=", -0.003),
    list(protocol$optional_data_gate$rich$ci_upper, "<", 0),
    list(protocol$optional_data_gate$open_companion$rps_delta, "<=", 0),
    list(protocol$optional_data_gate$open_companion$ci_upper, "<", 0.003),
    list(protocol$optional_data_gate$open_companion$maximum_fold_regression, "<=", 0.015)
  )
  for (rule in exact_rules) {
    promotion_protocol_assert(
      identical(rule[[1]]$operator, rule[[2]]) && identical(as.numeric(rule[[1]]$value), as.numeric(rule[[3]])),
      "Promotion protocol threshold or operator drifted"
    )
  }
  promotion_protocol_assert(as.numeric(protocol$panels$feature_rich$coverage_floor) == 0.8, "Rich-panel coverage floor drifted")
  promotion_protocol_assert(as.integer(protocol$panels$open_core$fixture_count) == 630L, "Open-core fixture denominator drifted")
  promotion_protocol_assert(
    identical(as.character(protocol$tie_break_order), c(
      "core_headline_rps", "core_log_loss", "core_brier",
      "core_calibration_error", "complexity_rank", "model_id"
    )),
    "Promotion tie-break order drifted"
  )

  if (is.null(artifacts)) {
    if (is.null(registry_dir)) stop("registry_dir or artifacts is required", call. = FALSE)
    artifacts <- promotion_protocol_artifacts(registry_dir)
  }
  required_artifacts <- c(names(promotion_protocol_hash_specs()), "boundaries")
  if (!all(required_artifacts %in% names(artifacts))) stop("Promotion protocol artifacts are incomplete", call. = FALSE)

  boundaries <- artifacts$boundaries[, c("edition_id", "track", "boundary_id", "boundary_sha256"), drop = FALSE]
  names(boundaries)[names(boundaries) == "track"] <- "track_id"
  validate_score_support_audit(
    artifacts$score_support_audit, artifacts$model_registry, boundaries
  )
  selected_g <- unique(as.integer(artifacts$score_support_audit$selected_g))
  promotion_protocol_assert(
    length(selected_g) == 1L && selected_g == as.integer(protocol$score_support$selected_g),
    "Promotion protocol selected G does not match the normalized audit"
  )

  hashes <- vapply(names(promotion_protocol_hash_specs()), function(name) {
    canonical_benchmark_sha256(artifacts[[name]], promotion_protocol_hash_specs()[[name]])
  }, character(1))
  for (name in names(hashes)) {
    protocol_name <- paste0(name, "_sha256")
    promotion_protocol_assert(
      identical(tolower(protocol$artifact_hashes[[protocol_name]]), hashes[[name]]),
      if (name == "score_support_audit") "Promotion protocol score-support audit SHA-256 mismatch" else paste("Promotion protocol", name, "SHA-256 mismatch")
    )
  }
  promotion_protocol_assert(
    identical(protocol$score_support$score_support_audit_sha256, hashes[["score_support_audit"]]),
    "Promotion protocol score-support audit SHA-256 mismatch"
  )

  if (any(c("candidate_g", "raw_omitted_tail", "selected_g", "parent_hashes", "row_hash") %in% names(artifacts$model_registry))) {
    stop("Model registry must remain registration metadata, not an embedded support audit", call. = FALSE)
  }
  registered <- artifacts$model_registry
  for (model_id in registered$model_id) {
    frozen <- protocol$model_hashes[[model_id]]
    row <- registered[registered$model_id == model_id, , drop = FALSE]
    promotion_protocol_assert(!is.null(frozen), "Promotion protocol omitted a registered model hash")
    promotion_protocol_assert(
      identical(frozen$registration_sha256, row$registration_sha256) &&
        identical(frozen$settings_sha256, row$settings_sha256),
      "Promotion protocol model registration/settings hash mismatch"
    )
  }
  seed <- artifacts$seed_registry[artifacts$seed_registry$seed_id == protocol$bootstrap$seed_id, , drop = FALSE]
  promotion_protocol_assert(
    nrow(seed) == 1L && seed$purpose == "paired_tournament_bootstrap" &&
      seed$seed == as.integer(protocol$bootstrap$seed) && seed$bootstrap_replicates == 10000L,
    "Promotion protocol bootstrap seed registration mismatch"
  )
  promotion_protocol_assert(nrow(artifacts$tournaments) == 12L, "Promotion protocol requires 12 tournaments")
  promotion_protocol_assert(nrow(artifacts$fixtures) == 630L, "Promotion protocol requires 630 fixtures")
  promotion_protocol_assert(!any(c("output_coverage_complete", "promotion_eligible") %in% names(artifacts$panel_fixtures)), "Frozen panel declarations contain observed eligibility")

  serialized <- canonicalize_promotion_protocol(protocol)
  forbidden <- c("actual_home_goals", "actual_away_goals", "wc2026_result", "wc2026_outcome")
  promotion_protocol_assert(!any(vapply(forbidden, grepl, logical(1), x = serialized, fixed = TRUE)), "Promotion protocol contains World Cup 2026 result values")
  invisible(protocol)
}

#' Load and validate a canonical promotion protocol
#' @export
load_promotion_protocol <- function(path, validate = TRUE) {
  promotion_require_namespace("jsonlite")
  if (!file.exists(path)) stop("Promotion protocol file does not exist", call. = FALSE)
  protocol <- jsonlite::fromJSON(path, simplifyVector = TRUE, simplifyDataFrame = FALSE)
  if (isTRUE(validate)) validate_promotion_protocol(protocol, registry_dir = dirname(path))
  protocol
}

promotion_contract_reason_map <- function() {
  c(
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
}

promotion_contract_reasons <- function(flags, prefix = "") {
  mapping <- promotion_contract_reason_map()
  missing <- setdiff(names(mapping), names(flags))
  if (length(missing)) return(paste0(prefix, mapping[missing]))
  failed <- names(mapping)[!vapply(flags[names(mapping)], isTRUE, logical(1))]
  paste0(prefix, unname(mapping[failed]))
}

promotion_metric_reasons <- function(metrics, prefix, thresholds, include_breadth = TRUE) {
  reasons <- character()
  if (!(metrics$rps_delta <= thresholds$rps_delta$value)) reasons <- c(reasons, paste0(prefix, "rps_effect_failed"))
  if (!(metrics$ci_upper < thresholds$ci_upper$value)) reasons <- c(reasons, paste0(prefix, "ci_failed"))
  if (include_breadth) {
    if (!(metrics$fold_wins >= thresholds$fold_wins$value)) reasons <- c(reasons, paste0(prefix, "fold_breadth_failed"))
    if (!(metrics$world_cup_wins >= thresholds$world_cup_wins$value)) reasons <- c(reasons, paste0(prefix, "world_cup_breadth_failed"))
    if (!(metrics$euro_wins >= thresholds$euro_wins$value)) reasons <- c(reasons, paste0(prefix, "euro_breadth_failed"))
  }
  if (!(metrics$maximum_fold_regression <= thresholds$maximum_fold_regression$value)) reasons <- c(reasons, paste0(prefix, "max_regression_failed"))
  reasons
}

promotion_supporting_reasons <- function(metrics, prefix, protocol) {
  reasons <- character()
  if (!(metrics$brier_relative_change <= protocol$supporting_vetoes$brier_relative_change$value)) reasons <- c(reasons, paste0(prefix, "brier_veto"))
  if (!(metrics$log_loss_relative_change <= protocol$supporting_vetoes$log_loss_relative_change$value)) reasons <- c(reasons, paste0(prefix, "log_loss_veto"))
  if (!(metrics$calibration_change <= protocol$supporting_vetoes$calibration_change$value)) reasons <- c(reasons, paste0(prefix, "calibration_veto"))
  reasons
}

#' Return ordered machine-readable promotion failure reasons
#' @export
promotion_veto_reasons <- function(candidate, protocol) {
  reasons <- promotion_contract_reasons(candidate$contracts)
  reasons <- c(
    reasons,
    promotion_metric_reasons(candidate$core, "core_", protocol$core_gate),
    promotion_supporting_reasons(candidate$core, "core_", protocol)
  )
  if (isTRUE(candidate$uses_optional_data)) {
    rich <- candidate$rich_panel
    open <- candidate$open_companion
    if (is.null(rich)) {
      reasons <- c(reasons, "rich_panel_missing")
    } else {
      if (!isTRUE(rich$panel_declared)) reasons <- c(reasons, "rich_panel_not_predeclared")
      if (!identical(rich$incumbent_id, protocol$incumbents$production_hybrid)) reasons <- c(reasons, "rich_incumbent_mismatch")
      coverage <- rich$coverage_observations
      if (!is.data.frame(coverage) || !all(c(
        "edition_id", "output_coverage", "output_coverage_complete", "provenance_complete",
        "required_fixture_count", "observed_fixture_count"
      ) %in% names(coverage)) || !setequal(coverage$edition_id, protocol$development_editions)) {
        reasons <- c(reasons, "rich_output_coverage_incomplete")
      } else {
        if (any(!coverage$output_coverage_complete | coverage$observed_fixture_count != coverage$required_fixture_count)) reasons <- c(reasons, "rich_output_coverage_incomplete")
        if (any(!coverage$provenance_complete)) reasons <- c(reasons, "rich_provenance_incomplete")
        if (any(coverage$output_coverage < protocol$panels$feature_rich$coverage_floor)) reasons <- c(reasons, "rich_edition_coverage_floor_failed")
      }
      reasons <- c(
        reasons,
        promotion_contract_reasons(rich$contracts, "rich_"),
        promotion_metric_reasons(rich, "rich_", protocol$optional_data_gate$rich),
        promotion_supporting_reasons(rich, "rich_", protocol)
      )
    }
    if (is.null(open)) {
      reasons <- c(reasons, "open_companion_missing")
    } else {
      if (!identical(open$incumbent_id, protocol$incumbents$open_core)) reasons <- c(reasons, "open_companion_incumbent_mismatch")
      if (as.integer(open$fixture_count) != as.integer(protocol$panels$open_core$fixture_count)) reasons <- c(reasons, "open_companion_coverage_incomplete")
      if (!isTRUE(open$default_open_mode)) reasons <- c(reasons, "default_open_mode_failed")
      reasons <- c(
        reasons,
        promotion_contract_reasons(open$contracts, "open_companion_"),
        promotion_metric_reasons(
          open, "open_companion_", protocol$optional_data_gate$open_companion,
          include_breadth = FALSE
        ),
        promotion_supporting_reasons(open, "open_companion_", protocol)
      )
    }
  }
  unique(reasons)
}

promotion_hard_reason_codes <- function() {
  base <- unname(promotion_contract_reason_map())
  c(
    base, paste0("rich_", base), paste0("open_companion_", base),
    "rich_panel_missing", "rich_panel_not_predeclared", "rich_incumbent_mismatch",
    "rich_output_coverage_incomplete", "rich_provenance_incomplete",
    "rich_edition_coverage_floor_failed", "open_companion_missing",
    "open_companion_incumbent_mismatch", "open_companion_coverage_incomplete",
    "default_open_mode_failed"
  )
}

#' Evaluate a candidate against the frozen promotion protocol
#' @export
evaluate_promotion <- function(candidate, protocol) {
  reasons <- promotion_veto_reasons(candidate, protocol)
  hard_failure <- any(reasons %in% promotion_hard_reason_codes())
  decision <- if (hard_failure) {
    "veto"
  } else if (length(reasons)) {
    "retain_incumbent"
  } else {
    "eligible_for_final_holdout"
  }
  list(
    candidate_id = candidate$candidate_id,
    incumbent_id = candidate$incumbent_id,
    decision = decision,
    reason_codes = reasons,
    gate_values = c(
      list(
        core_rps_delta = candidate$core$rps_delta,
        core_ci_upper = candidate$core$ci_upper,
        core_fold_wins = candidate$core$fold_wins,
        core_world_cup_wins = candidate$core$world_cup_wins,
        core_euro_wins = candidate$core$euro_wins,
        core_maximum_fold_regression = candidate$core$maximum_fold_regression
      ),
      if (isTRUE(candidate$uses_optional_data)) list(
        rich_rps_delta = candidate$rich_panel$rps_delta,
        rich_ci_upper = candidate$rich_panel$ci_upper,
        open_companion_rps_delta = candidate$open_companion$rps_delta,
        open_companion_ci_upper = candidate$open_companion$ci_upper
      ) else list()
    ),
    gate_passes = list(
      contracts = !hard_failure,
      statistics = !length(setdiff(reasons, promotion_hard_reason_codes())),
      all = !length(reasons)
    )
  )
}

#' Select the deterministic best fully eligible candidate or retain incumbent
#' @export
select_promoted_candidate <- function(evaluations, incumbent_id) {
  required <- c(
    "candidate_id", "decision", "core_headline_rps", "core_log_loss", "core_brier",
    "core_calibration_error", "complexity_rank"
  )
  missing <- setdiff(required, names(evaluations))
  if (length(missing)) stop("Promotion evaluations missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  incumbent <- evaluations[evaluations$candidate_id == incumbent_id, , drop = FALSE]
  if (nrow(incumbent) != 1L) stop("Promotion selection requires exactly one incumbent row", call. = FALSE)
  eligible <- evaluations[evaluations$decision == "eligible_for_final_holdout", , drop = FALSE]
  if (!nrow(eligible)) {
    return(list(selected_id = incumbent_id, decision = "retain_incumbent", tie_break = "no_eligible_candidate"))
  }
  metric_columns <- c(
    "core_headline_rps", "core_log_loss", "core_brier", "core_calibration_error", "complexity_rank"
  )
  ordering <- do.call(order, c(eligible[c(metric_columns, "candidate_id")], list(method = "radix")))
  best <- eligible[ordering[1], , drop = FALSE]
  exact_incumbent_tie <- all(vapply(metric_columns, function(column) {
    identical(as.numeric(best[[column]]), as.numeric(incumbent[[column]]))
  }, logical(1)))
  if (exact_incumbent_tie) {
    return(list(selected_id = incumbent_id, decision = "retain_incumbent", tie_break = "exact_tie"))
  }
  list(selected_id = best$candidate_id, decision = "selected", tie_break = paste(c(metric_columns, "model_id"), collapse = ">"))
}
