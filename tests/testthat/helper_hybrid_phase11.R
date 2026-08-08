hybrid_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")
)

hybrid_source_if_present <- function(relative_path) {
  path <- file.path(hybrid_project_root, relative_path)
  if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(path)
}

# Keep Wave 0 fixtures independent of later Phase 11 sibling APIs.  Existing
# benchmark contracts are shared infrastructure, not production APIs owned by
# a later hybrid task.  D-01 through D-04 stay on the two-goal, fold-local,
# common-distribution path; D-05 through D-08 stay on named open context.
hybrid_source_if_present("R/evaluation/proper_scores.R")
hybrid_source_if_present("R/benchmark/contracts.R")
hybrid_source_if_present("R/benchmark/baselines.R")
hybrid_source_if_present("R/forecast/xg_usage_audit.R")
hybrid_source_if_present("R/forecast/goal_ability.R")
hybrid_source_if_present("R/forecast/dynamic_goal_ability.R")
hybrid_source_if_present("R/benchmark/hybrid_protocol.R")
hybrid_source_if_present("R/forecast/hybrid_rf.R")
hybrid_source_if_present("R/forecast/context_features.R")
hybrid_source_if_present("R/forecast/structural_prior.R")

hybrid_require_api <- function(required, owner) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 0 RED contract awaits Phase 11 ", owner, " API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

hybrid_require_rf_api <- function() {
  hybrid_require_api(
    c(
      "fit_hybrid_two_goal_rf", "predict_hybrid_rf_means",
      "hybrid_rf_nb_score_distributions"
    ),
    "RF"
  )
}

hybrid_require_context_api <- function() {
  hybrid_require_api("build_open_context_features", "context")
}

hybrid_require_xg_api <- function() {
  hybrid_require_api("evaluate_hybrid_xg_gate", "xG gate")
}

hybrid_require_structural_api <- function() {
  hybrid_require_api(
    c(
      "load_structural_prior_snapshots", "compute_structural_prior_signal",
      "effective_recent_match_count", "apply_structural_sparse_shrinkage"
    ),
    "structural prior"
  )
}

hybrid_xg_current_files <- function() {
  list(
    feature_table = file.path(hybrid_project_root, "data/processed/goal_training_features_hybrid.csv"),
    home_model = file.path(hybrid_project_root, "models/home_goal_model_hybrid.rds"),
    away_model = file.path(hybrid_project_root, "models/away_goal_model_hybrid.rds"),
    rolling_form = file.path(hybrid_project_root, "data/processed/rolling_form.csv"),
    forecast_features = file.path(
      hybrid_project_root,
      "data/processed/worldcup_2026_forecast_features_hybrid.csv"
    )
  )
}

hybrid_xg_gate_thresholds <- function() {
  list(
    minimum_source_coverage = 0.80,
    minimum_nonzero_variance = 1e-8,
    require_complete_provenance = TRUE
  )
}

hybrid_result_field <- function(result, field) {
  if (is.data.frame(result)) return(result[[field]][1L])
  result[[field]]
}

hybrid_structural_snapshot_fixture <- function() {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for structural test fixtures", call. = FALSE)
  }
  directory <- tempfile("hybrid-structural-")
  dir.create(directory, recursive = TRUE)
  snapshots <- data.frame(
    country_iso3 = c("DEU", "FRA", "ITA", "DEU", "FRA", "ITA"),
    country_name = c("Germany", "France", "Italy", "Germany", "France", "Italy"),
    indicator_id = rep(c("gdp_per_capita", "population"), each = 3L),
    indicator_name = rep(c("GDP per capita", "Population"), each = 3L),
    indicator_definition = rep(c("synthetic GDP proxy", "synthetic population proxy"), each = 3L),
    source_year = rep(2009L, 6L),
    snapshot_year = rep(2009L, 6L),
    source_date = as.Date(rep("2009-12-31", 6L)),
    vintage_id = rep("synthetic_2009_v1", 6L),
    value = c(42000, 39000, 36000, 82000000, 67000000, 60000000),
    transformation = rep("registered_synthetic_fixture", 6L),
    source_name = rep("synthetic-open-structural-source", 6L),
    source_url_or_label = rep("synthetic test fixture", 6L),
    license_class = rep("open-or-derived-open", 6L),
    retrieved_at_utc = rep("2010-01-10T00:00:00Z", 6L),
    parent_source_sha256 = rep(strrep("a", 64), 6L),
    row_sha256 = rep(strrep("0", 64), 6L),
    stringsAsFactors = FALSE
  )
  snapshots$row_sha256 <- benchmark_contract_row_hash(snapshots, "row_sha256")
  snapshot_path <- file.path(directory, "structural_sources.csv")
  utils::write.csv(snapshots, snapshot_path, row.names = FALSE)

  metadata <- data.frame(
    vintage_id = "synthetic_2009_v1",
    snapshot_year = 2009L,
    source_date = as.Date("2009-12-31"),
    source_name = "synthetic-open-structural-source",
    source_url_or_label = "synthetic test fixture",
    license_class = "open-or-derived-open",
    indicator_definition = "GDP/population proxies used only to form a sparse-team prior",
    transformation_policy = "registered_synthetic_fixture",
    acquisition_note = "manual deterministic test fixture; no network access",
    stringsAsFactors = FALSE
  )
  metadata_path <- file.path(directory, "structural_sources_metadata.csv")
  utils::write.csv(metadata, metadata_path, row.names = FALSE)

  checksums <- data.frame(
    artifact_path = c(
      "structural_sources.csv", "structural_sources_metadata.csv", "structural_sources_rows"
    ),
    artifact_kind = c("snapshot", "metadata", "canonical_row_set"),
    sha256 = c(
      digest::digest(file = snapshot_path, algo = "sha256"),
      digest::digest(file = metadata_path, algo = "sha256"),
      digest::digest(snapshots, algo = "sha256", serialize = TRUE)
    ),
    vintage_id = "synthetic_2009_v1",
    stringsAsFactors = FALSE
  )
  checksums_path <- file.path(directory, "structural_sources_checksums.csv")
  utils::write.csv(checksums, checksums_path, row.names = FALSE)

  list(
    directory = directory,
    snapshot_path = snapshot_path,
    metadata_path = metadata_path,
    checksums_path = checksums_path,
    snapshots = snapshots,
    metadata = metadata,
    checksums = checksums
  )
}

hybrid_rf_settings <- function() {
  list(
    support_max = 40L,
    home_theta = 8,
    away_theta = 8,
    seed = 920001L,
    feature_set_id = "phase11_rf_dynamic_elo_open"
  )
}

hybrid_rf_history <- function() {
  data.frame(
    fixture_id = sprintf("hybrid_train_%02d", 1:12),
    date = as.Date("2010-01-01") + c(1:6, 15:20),
    home_team_id = rep(c("team_alpha", "team_beta", "team_gamma"), 4),
    away_team_id = rep(c("team_beta", "team_gamma", "team_alpha"), 4),
    home_goals = c(1L, 2L, 0L, 2L, 1L, 3L, 0L, 1L, 2L, 1L, 3L, 0L),
    away_goals = c(0L, 1L, 1L, 2L, 0L, 1L, 2L, 0L, 1L, 1L, 0L, 2L),
    venue_role = rep(c("home", "neutral", "home"), 4),
    home_attack_effect = rep(c(0.20, 0.05, -0.10), 4),
    home_defence_effect = rep(c(-0.10, 0.02, 0.15), 4),
    away_attack_effect = rep(c(-0.05, 0.18, 0.04), 4),
    away_defence_effect = rep(c(0.12, -0.08, 0.03), 4),
    elo_diff = rep(c(45, -20, 10), 4),
    home_attack_effect__source_date = as.Date("2009-12-20"),
    away_attack_effect__source_date = as.Date("2009-12-20"),
    home_defence_effect__source_date = as.Date("2009-12-20"),
    away_defence_effect__source_date = as.Date("2009-12-20"),
    elo_diff__source_date = as.Date("2009-12-20"),
    home_attack_effect__source_present = TRUE,
    away_attack_effect__source_present = TRUE,
    home_defence_effect__source_present = TRUE,
    away_defence_effect__source_present = TRUE,
    elo_diff__source_present = TRUE,
    home_attack_effect__value_present = TRUE,
    away_attack_effect__value_present = TRUE,
    home_defence_effect__value_present = TRUE,
    away_defence_effect__value_present = TRUE,
    elo_diff__value_present = TRUE,
    home_attack_effect__imputed = FALSE,
    away_attack_effect__imputed = FALSE,
    home_defence_effect__imputed = FALSE,
    away_defence_effect__imputed = FALSE,
    elo_diff__imputed = FALSE,
    home_attack_effect__imputation_reason = "",
    away_attack_effect__imputation_reason = "",
    home_defence_effect__imputation_reason = "",
    away_defence_effect__imputation_reason = "",
    elo_diff__imputation_reason = "",
    stringsAsFactors = FALSE
  )
}

hybrid_rf_fixtures <- function() {
  data.frame(
    fixture_id = c("hybrid_score_01", "hybrid_score_02"),
    edition_id = "wc2010",
    boundary_id = "wc2010__frozen",
    actual_completion_date = as.Date(c("2010-06-11", "2010-06-11")),
    evidence_cutoff_exclusive = as.Date(c("2010-06-11", "2010-06-11")),
    home_team_id = c("team_alpha", "team_gamma"),
    away_team_id = c("team_beta", "team_alpha"),
    venue_role = c("home", "neutral"),
    home_attack_effect = c(0.20, -0.10),
    home_defence_effect = c(-0.10, 0.15),
    away_attack_effect = c(0.18, -0.05),
    away_defence_effect = c(-0.08, 0.12),
    elo_diff = c(45, -20),
    home_attack_effect__source_date = as.Date("2010-06-01"),
    away_attack_effect__source_date = as.Date("2010-06-01"),
    home_defence_effect__source_date = as.Date("2010-06-01"),
    away_defence_effect__source_date = as.Date("2010-06-01"),
    elo_diff__source_date = as.Date("2010-06-01"),
    home_attack_effect__source_present = TRUE,
    away_attack_effect__source_present = TRUE,
    home_defence_effect__source_present = TRUE,
    away_defence_effect__source_present = TRUE,
    elo_diff__source_present = TRUE,
    home_attack_effect__value_present = TRUE,
    away_attack_effect__value_present = TRUE,
    home_defence_effect__value_present = TRUE,
    away_defence_effect__value_present = TRUE,
    elo_diff__value_present = TRUE,
    home_attack_effect__imputed = FALSE,
    away_attack_effect__imputed = FALSE,
    home_defence_effect__imputed = FALSE,
    away_defence_effect__imputed = FALSE,
    elo_diff__imputed = FALSE,
    home_attack_effect__imputation_reason = "",
    away_attack_effect__imputation_reason = "",
    home_defence_effect__imputation_reason = "",
    away_defence_effect__imputation_reason = "",
    elo_diff__imputation_reason = "",
    stringsAsFactors = FALSE
  )
}

hybrid_rf_evidence_features <- function() {
  c(
    "home_attack_effect", "home_defence_effect",
    "away_attack_effect", "away_defence_effect", "elo_diff"
  )
}

hybrid_context_history <- function() {
  data.frame(
    fixture_id = c("context_prior_de", "context_prior_it", "context_prior_fr"),
    date = as.Date(c("2010-06-01", "2010-06-02", "2010-06-03")),
    home_team_id = c("team_deu", "team_ita", "team_fra"),
    away_team_id = c("team_fra", "team_deu", "team_ita"),
    venue_country = c("FRA", "ITA", "DEU"),
    stringsAsFactors = FALSE
  )
}

hybrid_context_fixtures <- function() {
  data.frame(
    fixture_id = c("context_fixture_01", "context_fixture_02"),
    date = as.Date(c("2010-06-12", "2010-06-14")),
    edition_id = "wc2010",
    home_team_id = c("team_deu", "team_ita"),
    away_team_id = c("team_fra", "team_deu"),
    venue_country = c("DEU", "ITA"),
    host_country = c("DEU", "DEU"),
    host_team_id = c("team_deu", "team_deu"),
    venue_role = c("neutral", "neutral"),
    neutral = TRUE,
    stage_id = c("group", "round_of_16"),
    stringsAsFactors = FALSE
  )
}

hybrid_context_centroids <- function() {
  data.frame(
    country_iso3 = c("DEU", "FRA", "ITA"),
    country_name = c("Germany", "France", "Italy"),
    latitude = c(51.1657, 46.2276, 41.8719),
    longitude = c(10.4515, 2.2137, 12.5674),
    coordinate_role = "country_proxy",
    source_name = "synthetic-open-centroids",
    source_url_or_label = "synthetic test fixture",
    source_vintage = 2010L,
    license_class = "open-or-derived-open",
    derivation_rule = "deterministic synthetic country proxy",
    parent_source_sha256 = strrep("a", 64),
    row_sha256 = strrep("b", 64),
    stringsAsFactors = FALSE
  )
}

hybrid_context_feature_names <- function() {
  # D-06 keeps supplemental regional evidence outside the frozen primary core.
  c("host", "neutral", "rest_days", "travel_km", "stage_id")
}
