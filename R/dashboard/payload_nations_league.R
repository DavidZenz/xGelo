# Nations League adapter. Competition-specific field selection stops here;
# downstream payload validation and rendering are shared with EURO.

phase17_validate_nations_league_bundle <- function(bundle) {
  if (!is.list(bundle) || !identical(as.character(bundle$edition_id), "uefa_nations_league_2026_27")) {
    stop("Phase 17 Nations League adapter received the wrong edition", call. = FALSE)
  }
  phase17_normalize_metadata(bundle)
  invisible(TRUE)
}

phase17_payload_nations_league <- function(bundle, batch_id = "phase17-fixture-batch-v1") {
  phase17_validate_nations_league_bundle(bundle)
  payload <- phase17_neutral_payload(bundle, phase17_section_ids(), batch_id = batch_id)
  # Keep the public section order stable while carrying accepted Nations
  # League progression artifacts for the competition-specific views.
  payload$current_standings <- phase17_bundle_rows(bundle, "current_standings")
  payload$progression_probabilities <- phase17_bundle_rows(bundle, "progression_probabilities")
  payload$tournament_tree <- phase17_bundle_rows(bundle, "tournament_tree")
  payload$tournament_topology <- phase17_bundle_rows(bundle, "tournament_topology")
  queue <- phase17_bundle_rows(bundle, "euro_priority_queue")
  first <- if (length(queue)) queue[[1L]] else list()
  for (field in intersect(c("priority_policy_version", "priority_policy_sha256"), names(first))) payload$metadata[[field]] <- first[[field]]
  if (!is.null(bundle$outcomes_manifest_sha256)) payload$metadata$outcomes_manifest_sha256 <- bundle$outcomes_manifest_sha256
  fields <- c("priority_policy_version", "priority_policy_sha256", "cutoff_utc", "simulation_count", "simulation_seed",
              "projection_run_id", "source_bundle_id", "source_bundle_sha256", "model_release_id")
  payload$euro_safety_net <- list(
    schema_version = "euro-safety-net-v1",
    status = if (!length(queue)) "unavailable" else if (any(vapply(queue, function(row) identical(as.character(row$status), "unresolved"), logical(1)))) "unresolved" else "projected",
    reason = if (!length(queue)) "priority_artifact_not_available_rebuild_required" else "",
    metadata = first[intersect(fields, names(first))], rows = queue
  )
  phase17_validate_payload(payload)
  payload
}

phase17_build_nations_league_payload <- phase17_payload_nations_league
phase17_adapt_nations_league_bundle <- phase17_payload_nations_league
