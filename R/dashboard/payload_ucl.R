# Phase 21 read-only adapter for the Phase 20 Champions League outcome
# artifacts.  This file maps accepted artifact tables; it never computes rules,
# draws, standings, forecasts, or probabilities.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase21_ucl_inventory <- function() {
  c("competition_topology", "league_schedule", "projected_standings", "projected_rankings",
    "knockout_paths", "progression_probabilities", "fixture_forecast_ledger",
    "simulation_metadata", "outcomes_manifest")
}

phase21_ucl_reason <- function(candidate, default = "No accepted Champions League outcome candidate is available.") {
  values <- c(candidate$production_blocked_reason, candidate$human_needed_reason,
              candidate$original_parent_reason, candidate$reason, candidate$error,
              candidate$unresolved)
  values <- as.character(values[!is.na(values) & nzchar(as.character(values))])
  if (length(values)) paste(unique(values), collapse = "; ") else default
}

phase21_ucl_artifacts <- function(candidate) {
  if (!is.list(candidate)) return(list())
  artifacts <- candidate$artifacts
  if (!is.list(artifacts)) artifacts <- candidate
  if (!is.list(artifacts)) return(list())
  artifacts[intersect(names(artifacts), phase21_ucl_inventory())]
}

phase21_ucl_first <- function(data, field, default = NA_character_) {
  if (!is.data.frame(data) || !nrow(data) || !field %in% names(data)) return(default)
  value <- data[[field]][[1L]]
  if (length(value) != 1L || is.na(value)) default else value
}

phase21_ucl_section_state <- function(rows, candidate_status, reason, unresolved = FALSE) {
  rows <- phase21_rows(rows)
  if (length(rows)) return(list(status = if (isTRUE(unresolved)) "unresolved" else "available", reason = if (isTRUE(unresolved)) reason else ""))
  if (isTRUE(unresolved)) return(list(status = "unresolved", reason = reason))
  if (candidate_status %in% c("production_blocked", "production_human_needed", "blocked")) return(list(status = "blocked", reason = reason))
  list(status = "unavailable", reason = reason)
}

phase21_ucl_metadata <- function(candidate, artifacts, registry_row = NULL, batch_id = "phase21-ucl-batch-v1") {
  edition_id <- phase21_safe_scalar(candidate$edition_id, phase21_ucl_first(artifacts$simulation_metadata, "edition_id", "ucl_2026_27"))
  display_name <- if (is.null(registry_row)) "UEFA Champions League 2026/27" else as.character(registry_row$display_name[[1L]])
  metadata <- phase21_default_metadata(edition_id, batch_id, display_name)
  simulation <- artifacts$simulation_metadata
  manifest <- artifacts$outcomes_manifest
  fields <- c("source_bundle_id", "ruleset_version", "ruleset_sha256", "model_release_id", "model_sha256",
              "calibrator_sha256", "draw_artifact_sha256", "information_cutoff_utc", "simulation_count", "seed",
              "run_id", "authority_mode", "production_eligible")
  for (field in intersect(fields, names(simulation))) {
    target <- switch(field, run_id = "projection_run_id", seed = "simulation_seed", information_cutoff_utc = "information_cutoff_utc", field)
    metadata[[target]] <- phase21_ucl_first(simulation, field, metadata[[target]])
  }
  if (is.data.frame(manifest) && nrow(manifest)) {
    if (is.na(metadata$source_bundle_id) || !nzchar(as.character(metadata$source_bundle_id))) metadata$source_bundle_id <- phase21_ucl_first(manifest, "parent_id")
    if (is.na(metadata$source_bundle_sha256) || !nzchar(as.character(metadata$source_bundle_sha256))) metadata$source_bundle_sha256 <- phase21_ucl_first(manifest, "parent_sha256")
    metadata$release_manifest_sha256 <- phase21_ucl_first(manifest, "manifest_sha256", metadata$release_manifest_sha256)
    metadata$artifact_inventory <- as.character(manifest$artifact_path)
    metadata$artifact_hashes <- stats::setNames(as.character(manifest$artifact_sha256), as.character(manifest$artifact_path))
  }
  if (!is.null(candidate$artifact_hashes)) metadata$artifact_hashes <- candidate$artifact_hashes
  metadata$edition_id <- edition_id
  metadata$batch_id <- batch_id
  metadata$lifecycle_state <- if (identical(as.character(candidate$status %||% ""), "unresolved_draw_procedure")) "pre_draw" else if (length(phase21_ucl_artifacts(candidate))) "active" else "unavailable"
  metadata$forecast_status <- if (is.data.frame(artifacts$fixture_forecast_ledger) && nrow(artifacts$fixture_forecast_ledger)) "available" else "unavailable"
  metadata$source_status <- if (length(phase21_ucl_artifacts(candidate))) "accepted_candidate" else "unavailable"
  metadata$authority_mode <- phase21_safe_scalar(candidate$authority_mode, phase21_safe_scalar(metadata$authority_mode, "fixture"))
  metadata$production_eligible <- isTRUE(candidate$production_eligible) || isTRUE(as.logical(metadata$production_eligible))
  metadata$freshness_status <- if (nzchar(phase21_safe_scalar(metadata$information_cutoff_utc))) "cutoff_bound" else "unknown"
  metadata$showing_last_accepted_snapshot <- isTRUE(candidate$showing_last_accepted_snapshot %||% FALSE)
  metadata$warnings <- as.character(candidate$warnings %||% character())
  metadata
}

phase21_payload_ucl <- function(candidate = NULL, registry_row = NULL, batch_id = "phase21-ucl-batch-v1", blocked_reason = NULL) {
  candidate <- candidate %||% list(status = "production_blocked", production_blocked_reason = blocked_reason %||% "phase18_authority_missing", edition_id = "ucl_2026_27")
  artifacts <- phase21_ucl_artifacts(candidate)
  edition_id <- phase21_safe_scalar(candidate$edition_id, phase21_ucl_first(artifacts$simulation_metadata, "edition_id", "ucl_2026_27"))
  metadata <- phase21_ucl_metadata(candidate, artifacts, registry_row, batch_id)
  reason <- blocked_reason %||% phase21_ucl_reason(candidate)
  candidate_status <- phase21_safe_scalar(candidate$status, "production_blocked")
  unresolved <- identical(candidate_status, "unresolved_draw_procedure") || length(candidate$unresolved %||% character()) > 0L
  labels <- c(overview = "Overview", structure = "Structure", standings = "Standings", fixtures = "Fixtures", results = "Results", form = "Form", match_forecasts = "Match forecasts", rank_distributions = "Rank distributions", qualification_bands = "Qualification bands", knockout_paths = "Knockout paths", progression_probabilities = "Progression probabilities", projected_outcomes = "Projected outcomes")
  topology <- artifacts$competition_topology
  schedule <- artifacts$league_schedule
  if (!is.data.frame(schedule)) schedule <- data.frame(stringsAsFactors = FALSE)
  completed <- if (nrow(schedule) && "lifecycle_status" %in% names(schedule)) {
    tolower(as.character(schedule$lifecycle_status)) %in% c("completed", "complete", "finished", "final", "played")
  } else logical(nrow(schedule))
  section_rows <- list(
    structure = topology,
    standings = artifacts$projected_standings,
    fixtures = if (nrow(schedule)) schedule[!completed, , drop = FALSE] else schedule,
    results = if (nrow(schedule)) schedule[completed, , drop = FALSE] else schedule,
    form = data.frame(stringsAsFactors = FALSE),
    match_forecasts = artifacts$fixture_forecast_ledger,
    rank_distributions = data.frame(stringsAsFactors = FALSE),
    qualification_bands = artifacts$projected_rankings,
    knockout_paths = artifacts$knockout_paths,
    progression_probabilities = artifacts$progression_probabilities,
    projected_outcomes = artifacts$projected_rankings
  )
  sections <- list(overview = phase21_section("overview", labels[["overview"]], list(), if (length(artifacts)) "available" else "blocked", if (length(artifacts)) "Lineage metadata and artifact status are shown below." else reason, "section"))
  for (id in phase21_section_ids()[-1L]) {
    rows <- section_rows[[id]]
    status <- phase21_ucl_section_state(rows, candidate_status, reason, unresolved && id %in% c("knockout_paths", "progression_probabilities", "qualification_bands", "projected_outcomes"))
    section_reason <- status$reason
    if (id == "form" && !length(phase21_rows(rows))) section_reason <- "Phase 20 does not publish a competition-form artifact."
    if (id == "rank_distributions" && !length(phase21_rows(rows))) section_reason <- "Phase 20 does not publish a rank-distribution artifact."
    sections[[id]] <- phase21_section(id, labels[[id]], rows, status$status, section_reason,
                                      c("section", "club", "team", "stage", "matchday", "status"))
  }
  credits <- list(source_name = "UEFA", source_url = "https://www.uefa.com/", license = "Official competition source", attribution = "xGelo forecast dashboard")
  payload <- list(schema_version = phase21_dashboard_schema_version, edition_id = edition_id,
                  metadata = metadata, sections = sections, credits = credits)
  phase21_validate_payload(payload)
  payload
}

phase21_build_ucl_payload <- phase21_payload_ucl
