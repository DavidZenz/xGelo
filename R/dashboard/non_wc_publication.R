# Production preparation for the three non-WC dashboard routes. Model/source
# authorities remain the existing closed providers; this layer only validates
# presentation readiness and stages their already accepted outputs.

phase21_non_wc_time <- function(value) {
  value <- phase21_safe_scalar(value)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$", value)) return(NA_real_)
  as.numeric(as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
}

phase21_non_wc_validate_ready <- function(payloads, now_utc) {
  expected <- phase21_enabled_edition_ids()
  if (!identical(sort(names(payloads)), sort(expected))) stop("All three non-WC editions are required")
  now <- phase21_non_wc_time(now_utc)
  if (!is.finite(now)) stop("Non-WC publication requires a canonical UTC generation time")
  for (id in expected) {
    p <- payloads[[id]]
    phase21_validate_payload(p, phase21_default_edition_registry())
    if (identical(id, "uefa_euro_2028_qualifying")) {
      if (identical(phase21_safe_scalar(p$metadata$lifecycle_state), "pre_draw")) {
        if (!identical(phase21_safe_scalar(p$metadata$forecast_status), "pre_draw") ||
            any(vapply(p$sections[-1L], function(s) length(s$rows) > 0L, logical(1))))
          stop("EURO pre-draw readiness forbids inferred groups, fixtures or predictions")
      } else if (!length(p$sections$structure$rows) || !length(p$sections$fixtures$rows)) {
        stop("EURO forecasts require complete accepted official structure and fixtures")
      }
      next
    }
    checked <- phase21_non_wc_time(p$metadata$last_refresh_at_utc)
    if (!is.finite(checked) || checked > now + 3600 || now - checked > 48 * 3600)
      stop("Refusing a new public batch from stale or invalid source checks: ", id)
    if (!identical(phase21_safe_scalar(p$metadata$source_status), "accepted"))
      stop("Public quantitative dashboards require accepted source authority: ", id)
    if (identical(id, "uefa_nations_league_2026_27")) {
      uefa_nl_mc_require_publication(p$metadata$simulation_count)
    }
    for (section_id in c("fixtures", "match_forecasts")) for (row in p$sections[[section_id]]$rows) {
      field <- intersect(c("Kickoff (UTC)", "kickoff_utc", "scheduled_at_utc"), names(row))
      if (!length(field)) next
      # Legacy NL sections contain completed as well as scheduled rows. Their
      # rich renderer separates completed outcomes from future forecasts.
      if (identical(id, "uefa_nations_league_2026_27")) next
      at <- phase21_non_wc_time(row[[field[[1L]]]])
      if (!is.finite(at) || at <= now) stop("Past or invalid CL kickoff cannot be published as upcoming")
    }
    if (identical(id, "ucl_2026_27") && length(p$sections$match_forecasts$rows)) {
      rows <- p$sections$match_forecasts$rows
      triples <- unique(vapply(rows, function(row) paste(row[c("Home win", "Draw", "Away win")], collapse = "|"), character(1)))
      if (length(rows) > 1L && length(triples) == 1L &&
          !grepl("Venue baseline", p$sections$match_forecasts$reason, fixed = TRUE))
        stop("Identical CL defaults cannot be published without explicit baseline disclosure")
    }
  }
  invisible(TRUE)
}

phase21_non_wc_stage_payloads <- function(payloads, legacy_payloads, stage_root,
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), publish = FALSE,
    public_root = file.path(getwd(), "docs/competitions"), injectors = list()) {
  phase21_non_wc_validate_ready(payloads, now_utc)
  registry <- phase21_default_edition_registry()
  batch <- phase21_batch_identity(payloads)
  for (id in names(payloads)) payloads[[id]]$metadata$batch_id <- batch
  renderers <- lapply(names(legacy_payloads), function(id) {
    legacy <- legacy_payloads[[id]]
    function(payload, route) {
      legacy$metadata <- payload$metadata
      phase21_decorate_legacy_html(render_phase17_dashboard(legacy, route), payload$metadata, registry)
    }
  })
  names(renderers) <- names(legacy_payloads)
  staged <- phase21_stage_batch(payloads, registry, stage_root,
    batch_id = batch, generated_at_utc = now_utc, renderers = renderers)
  phase21_non_wc_validate_ready(staged$validation$payloads, now_utc)
  promoted <- if (isTRUE(publish)) phase21_promote_batch(stage_root, public_root, registry, injectors = injectors) else NULL
  list(valid = TRUE, batch_id = batch, stage_root = stage_root,
    payloads = payloads, inventory = phase21_expected_public_inventory(registry),
    staged = staged, promoted = promoted)
}

phase21_non_wc_load_accepted_inputs <- function(project_root, now_utc) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  bundles <- phase17_load_accepted_production_bundles(project_root)
  # Validation always reads the accepted state. The environment cannot turn
  # publication QA into an expensive rebuild or a new forecast computation.
  gates <- phase17_production_callbacks(bundles, project_root, now_utc, phase14_state_mode = "accepted")
  for (id in c("phase13_validate_source_bundle", "phase13_validate_accepted_snapshot",
      "phase13_validate_competition_edition_registries", "phase14_build_competition_state_candidate",
      "phase14_resolve_approved_release", "phase15_validate_nl_outcomes_bundle",
      "phase16_validate_euro_source_bundle", "validate_euro_activation", "phase16_validate_euro_outcomes_bundle",
      "phase17_validate_probability_inputs")) {
    fn <- gates[[id]]
    if (!is.function(fn)) stop("Production readiness validator is missing: ", id)
    result <- fn()
    if (!is.list(result) || !isTRUE(result$valid)) stop("Production readiness failed: ", id,
      " ", result$failure_reason %||% "")
  }
  bundles
}

phase21_non_wc_prepare_national_payloads <- function(bundles, now_utc) {
  registry <- phase21_default_edition_registry()
  legacy <- list(uefa_nations_league_2026_27 = phase17_payload_nations_league(bundles$uefa_nations_league_2026_27),
    uefa_euro_2028_qualifying = phase17_payload_euro(bundles$uefa_euro_2028_qualifying))
  payloads <- lapply(names(legacy), function(id) {
    p <- legacy[[id]]
    p$metadata$projection_generated_at_utc <- p$metadata$generated_at_utc
    p$metadata$generated_at_utc <- now_utc
    p$metadata$source_as_of_utc <- p$metadata$accepted_data_cutoff_utc %||% p$metadata$last_refresh_at_utc
    p$metadata$source_status <- "accepted" # fixed provider above validated actual source contracts
    p$metadata$freshness_threshold_seconds <- 48 * 3600
    p$metadata$freshness_as_of_utc <- now_utc
    p$metadata$freshness_status <- if (identical(p$metadata$lifecycle_state, "pre_draw")) "not_applicable_pre_draw" else "fresh"
    p$metadata$forecast_readiness <- if (identical(p$metadata$lifecycle_state, "pre_draw"))
      "Awaiting accepted official structure and fixtures" else "Accepted production inputs"
    if (identical(p$metadata$lifecycle_state, "pre_draw")) {
      reason <- "Forecasting is inactive until the official EURO groups and fixtures are accepted. This is a readiness placeholder; no schedule or probabilities are inferred."
      p$metadata$source_capture_warnings <- p$metadata$warnings
      p$metadata$warnings <- reason
      for (section_id in setdiff(names(p$sections), "overview")) p$sections[[section_id]]$reason <- reason
    }
    normalized <- phase21_normalize_phase17_payload(p, registry[registry$edition_id == id, , drop = FALSE], "non-wc-stage")
    for (field in setdiff(names(p), names(normalized))) normalized[[field]] <- p[[field]]
    normalized
  })
  names(payloads) <- names(legacy)
  list(payloads = payloads, legacy = legacy)
}

phase21_non_wc_assert_lineage <- function(actual, expected, fields, edition_id) {
  for (field in fields) if (!identical(phase21_safe_scalar(actual[[field]]), phase21_safe_scalar(expected[[field]])))
    stop("Public payload differs from current accepted ", edition_id, " lineage: ", field, call. = FALSE)
  invisible(TRUE)
}

phase21_non_wc_assert_rows <- function(actual, expected, edition_id, section_ids) {
  for (id in section_ids) if (!identical(phase21_canonical_value_bytes(actual$sections[[id]]$rows),
      phase21_canonical_value_bytes(expected$sections[[id]]$rows)))
    stop("Public ", edition_id, " rows differ from accepted artifacts: ", id, call. = FALSE)
  invisible(TRUE)
}

# Read-only publication QA: accepted source/release/outcome authorities are
# resolved afresh. It never fits a model, replays ratings, generates forecasts
# or reruns tournament Monte Carlo. Public status flags are not authority.
phase21_non_wc_validate_production_publication <- function(public_root, project_root = getwd(),
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  public_root <- normalizePath(public_root, winslash = "/", mustWork = TRUE)
  before <- getwd(); setwd(project_root); on.exit(setwd(before), add = TRUE)
  validated <- phase21_validate_batch(public_root)
  phase21_non_wc_validate_ready(validated$payloads, now_utc)
  bundles <- phase21_non_wc_load_accepted_inputs(project_root, now_utc)
  accepted <- phase21_non_wc_prepare_national_payloads(bundles, now_utc)$payloads
  fields <- c("source_bundle_id", "source_bundle_sha256", "source_as_of_utc", "last_refresh_at_utc",
    "accepted_data_cutoff_utc", "lifecycle_state", "model_release_id", "model_sha256", "calibrator_sha256",
    "release_manifest_sha256", "ruleset_version", "ruleset_sha256", "projection_run_id",
    "simulation_seed", "simulation_count", "information_cutoff_utc", "feature_cutoff_utc",
    "projection_generated_at_utc", "outcomes_manifest_sha256", "article15_access_list_sha256",
    "article15_discipline_points_sha256", "article15_rule_inputs_manifest_sha256")
  for (id in names(accepted)) {
    payload <- validated$payloads[[id]]
    phase21_non_wc_assert_lineage(payload$metadata, accepted[[id]]$metadata, fields, id)
    phase21_non_wc_assert_rows(payload, accepted[[id]], id, phase21_section_ids())
    for (field in setdiff(names(accepted[[id]]), c("schema_version", "edition_id", "metadata", "sections", "credits")))
      if (!identical(phase21_canonical_value_bytes(payload[[field]]), phase21_canonical_value_bytes(accepted[[id]][[field]])))
        stop("Public ", id, " enrichment differs from accepted artifacts: ", field, call. = FALSE)
  }
  current <- phase18_read_ucl_refresh_current(file.path(project_root, "data/competition/accepted"),
    file.path(project_root, "data/competition/registries"))
  phase18_validate_ucl_refresh_current(current)
  cl <- validated$payloads$ucl_2026_27
  row <- phase21_default_edition_registry()[phase21_default_edition_registry()$edition_id == "ucl_2026_27", , drop = FALSE]
  facts <- phase21_payload_ucl_live_source(current, row, now_utc = cl$metadata$generated_at_utc)
  phase21_non_wc_assert_lineage(cl$metadata, facts$metadata,
    c("source_bundle_id", "source_bundle_sha256", "source_as_of_utc", "last_refresh_at_utc", "lifecycle_state"), "ucl_2026_27")
  phase21_non_wc_assert_rows(cl, facts, "ucl_2026_27", c("standings", "fixtures", "results", "form"))
  unsupported <- c("structure", "rank_distributions", "qualification_bands", "knockout_paths",
    "progression_probabilities", "projected_outcomes")
  if (any(vapply(cl$sections[unsupported], function(s) length(s$rows) > 0L, logical(1))))
    stop("Public CL tournament projections have no connected accepted tournament authority", call. = FALSE)
  model_fields <- c("model_release_id", "model_sha256", "calibrator_sha256")
  if (length(cl$sections$match_forecasts$rows) || any(vapply(cl$metadata[model_fields], function(x) nzchar(phase21_safe_scalar(x)), logical(1)))) {
    release <- phase19_resolve_production_club_release()
    contract <- release$model_contract
    contract$model_release_id <- release$release_id
    phase21_non_wc_assert_lineage(cl$metadata, contract, model_fields, "ucl_2026_27 model")
    phase21_non_wc_assert_lineage(cl$metadata$forecast_provenance, cl$metadata,
      c("source_bundle_sha256", "model_release_id", "model_sha256", "calibrator_sha256"), "ucl_2026_27 forecast")
    if (length(cl$sections$match_forecasts$rows) &&
        (!isTRUE(cl$metadata$production_eligible) || !identical(cl$metadata$forecast_status, "available")))
      stop("Public CL match forecasts must be an eligible accepted production release", call. = FALSE)
  } else if (isTRUE(cl$metadata$production_eligible) || !identical(cl$metadata$forecast_status, "unavailable")) {
    stop("Public CL facts without an accepted model must explicitly disable forecasts", call. = FALSE)
  }
  validated$production_authority_valid <- TRUE
  validated
}

phase21_non_wc_build <- function(stage_root, project_root = getwd(), publish = FALSE,
    cl_forecasts = "approved", now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  bundles <- phase21_non_wc_load_accepted_inputs(project_root, now_utc)
  national <- phase21_non_wc_prepare_national_payloads(bundles, now_utc)
  payloads <- national$payloads
  uefa_nl_mc_require_publication(payloads$uefa_nations_league_2026_27$metadata$simulation_count)
  nl_checked <- phase21_non_wc_time(payloads$uefa_nations_league_2026_27$metadata$last_refresh_at_utc)
  if (!is.finite(nl_checked) || phase21_non_wc_time(now_utc) - nl_checked > 48 * 3600)
    stop("Nations League source checks are stale; no dashboard candidate was installed")
  payloads$ucl_2026_27 <- render_ucl_live_dashboard(forecast_mode = cl_forecasts, now_utc = now_utc, write_output = FALSE)
  phase21_non_wc_stage_payloads(payloads, national$legacy, stage_root, now_utc, publish,
    public_root = file.path(project_root, "docs/competitions"))
}
