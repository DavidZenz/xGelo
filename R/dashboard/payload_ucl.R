# Phase 21 read-only adapters for Champions League outcome artifacts and
# accepted live source facts. This file maps accepted tables; it never computes
# competition rules, draws, standings, forecasts, or probabilities.

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

phase21_ucl_utc_seconds <- function(value) {
  value <- as.character(value)
  valid <- !is.na(value) & grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$", value)
  result <- rep(NA_real_, length(value))
  result[valid] <- as.numeric(as.POSIXct(value[valid], tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
  result
}

phase21_ucl_partition_forecasts <- function(predictions, now_utc) {
  now <- phase21_ucl_utc_seconds(now_utc)
  times <- phase21_ucl_utc_seconds(predictions$kickoff_utc)
  if (length(now) != 1L || !is.finite(now) || any(!is.finite(times)))
    stop("Forecast presentation requires canonical UTC instants", call. = FALSE)
  list(upcoming = predictions[times > now, , drop = FALSE],
    archived = predictions[times <= now, , drop = FALSE])
}

# Display accepted current-state facts independently of model availability.
# This view never creates forecast, draw, or tournament probability authority.
phase21_payload_ucl_live_source <- function(current, registry_row = NULL,
    batch_id = "ucl-live-source", now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    forecasts = NULL) {
  if (!is.list(current) || !identical(as.character(current$pointer$accepted_status), "accepted") ||
      !is.list(current$accepted)) stop("An accepted UCL current-source generation is required", call. = FALSE)
  if (!exists("phase18_validate_ucl_refresh_current", mode = "function")) stop("UCL current-state validation is required", call. = FALSE)
  phase18_validate_ucl_refresh_current(current)
  accepted <- current$accepted
  if (!exists("phase18_validate_ucl_source_bundle", mode = "function")) stop("UCL source validation is required", call. = FALSE)
  phase18_validate_ucl_source_bundle(accepted)
  if (!identical(as.character(accepted$authority$authority_type[[1L]]), "provider_acceptance") ||
      !isTRUE(accepted$authority$provider_automation_enabled[[1L]])) {
    stop("Live dashboard facts require accepted provider authority", call. = FALSE)
  }
  edition <- as.character(accepted$bundle$edition_id[[1L]])
  reason <- "Club forecasts are unavailable until the historical training data and an evaluated club model release are accepted."
  payload <- phase21_payload_ucl(list(edition_id = edition, status = "production_blocked",
    production_blocked_reason = reason, authority_mode = "production", production_eligible = FALSE), registry_row, batch_id)
  tables <- accepted$tables
  clubs <- setNames(as.character(tables$clubs$display_name), as.character(tables$clubs$club_id))
  standing <- tables$standings[order(as.integer(tables$standings$position)), , drop = FALSE]
  standing_rows <- data.frame(Position = standing$position, Club = unname(clubs[standing$club_id]),
    Played = standing$played, Won = standing$won, Drawn = standing$drawn, Lost = standing$lost,
    GF = standing$goals_for, GA = standing$goals_against, GD = standing$goal_difference,
    Points = standing$points, stringsAsFactors = FALSE, check.names = FALSE)
  matches <- tables$matches[order(tables$matches$kickoff_utc, tables$matches$provider_match_id), , drop = FALSE]
  completed <- as.character(matches$status) == "FINISHED"
  now_seconds <- phase21_ucl_utc_seconds(now_utc)
  kickoff_seconds <- phase21_ucl_utc_seconds(matches$kickoff_utc)
  if (length(now_seconds) != 1L || !is.finite(now_seconds) || any(!is.finite(kickoff_seconds)))
    stop("CL dashboard requires canonical UTC kickoff and generation instants", call. = FALSE)
  expired <- !completed & kickoff_seconds <= now_seconds
  upcoming <- !completed & !expired & as.character(matches$status) %in% c("SCHEDULED", "TIMED")
  confirmation_pending <- expired & !as.character(matches$status) %in% c("CANCELLED", "POSTPONED", "AWARDED")
  score <- rep(NA_character_, nrow(matches))
  scored <- completed & !is.na(matches$home_score) & !is.na(matches$away_score)
  score[scored] <- paste(matches$home_score[scored], matches$away_score[scored], sep = "–")
  match_rows <- data.frame(Matchday = matches$matchday, `Kickoff (UTC)` = matches$kickoff_utc,
    Home = unname(clubs[matches$home_club_id]), Away = unname(clubs[matches$away_club_id]),
    Score = score, Status = tools::toTitleCase(gsub("_", " ", tolower(as.character(matches$status)))),
    stringsAsFactors = FALSE, check.names = FALSE)
  match_rows$Status[confirmation_pending] <- "Result awaiting source confirmation"
  live <- confirmation_pending & as.character(matches$status) %in% c("IN_PLAY", "PAUSED", "SUSPENDED")
  match_rows$Status[live] <- paste0(tools::toTitleCase(tolower(as.character(matches$status[live]))), " — final result pending")
  metadata <- payload$metadata
  metadata$lifecycle_state <- "league_phase"
  metadata$source_status <- "accepted"
  metadata$source_confidence <- "provider_accepted"
  metadata$source_bundle_id <- as.character(accepted$bundle$bundle_id[[1L]])
  metadata$source_bundle_sha256 <- as.character(accepted$bundle$bundle_sha256[[1L]])
  metadata$last_refresh_at_utc <- as.character(accepted$bundle$created_at_utc[[1L]])
  metadata$source_as_of_utc <- metadata$last_refresh_at_utc
  if (is.data.frame(accepted$artifacts) && all(c("resource_type", "source_as_of_utc") %in% names(accepted$artifacts))) {
    source_instants <- as.character(accepted$artifacts$source_as_of_utc[accepted$artifacts$resource_type == "matches"])
    if (length(source_instants) && all(is.finite(phase21_ucl_utc_seconds(source_instants))))
      metadata$source_as_of_utc <- max(source_instants)
  }
  metadata$generated_at_utc <- now_utc
  metadata$freshness_as_of_utc <- now_utc
  metadata$freshness_threshold_seconds <- 48 * 3600
  metadata$result_confirmation_pending_count <- sum(confirmation_pending)
  metadata$completed_result_count <- sum(completed)
  metadata$upcoming_fixture_count <- sum(upcoming)
  age <- as.numeric(difftime(as.POSIXct(now_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    as.POSIXct(metadata$last_refresh_at_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"), units = "secs"))
  metadata$delay_seconds <- age
  stale <- !is.finite(age) || age < -3600 || age > 48 * 3600
  metadata$freshness_status <- if (stale) "stale" else "fresh"
  metadata$showing_last_accepted_snapshot <- stale || !is.null(current$sidecar)
  metadata$warnings <- c(reason, if (stale) "The accepted source is outside the 48-hour refresh window.",
    if (!is.null(current$sidecar)) "The latest source refresh was blocked; the last accepted source is shown.",
    if (any(expired)) sprintf("%d past-kickoff fixtures await accepted result confirmation; they are not upcoming fixtures.", sum(expired)))
  payload$metadata <- metadata
  for (id in names(payload$sections)) {
    payload$sections[[id]]$status <- "unavailable"
    payload$sections[[id]]$reason <- reason
  }
  payload$sections$form$reason <- "Club form is not included in this live source view."
  payload$sections$rank_distributions$reason <- reason
  status <- if (stale) "stale" else "available"
  payload$sections$overview <- phase21_section("overview", "Overview", status = status,
    reason = "Accepted fixtures, results and provider standings are available. Forecast sections remain unavailable.")
  payload$sections$standings <- phase21_section("standings", "Standings", standing_rows, status,
    "Provider league-phase TOTAL table, reconciled with completed results.")
  payload$sections$fixtures <- phase21_section("fixtures", "Upcoming fixtures", match_rows[upcoming, , drop = FALSE], status)
  payload$sections$results <- phase21_section("results", "Results and fixture status", match_rows[!upcoming, , drop = FALSE], status,
    if (any(expired)) "Rows awaiting source confirmation have no inferred score or completed-result claim." else "")
  payload$credits <- list(source_name = "football-data.org", source_url = "https://www.football-data.org/",
    attribution = "Football data provided by the Football-Data.org API.")
  if (!is.null(forecasts)) payload <- phase21_ucl_attach_live_forecasts(payload, forecasts, matches, clubs)
  phase21_validate_payload(payload)
  payload
}


# Presentation consumes already validated forecasts; accepted result rows remain
# factual results and never gain retrospective pre-match probabilities.
phase21_ucl_attach_live_forecasts <- function(payload, forecasts, matches, clubs) {
  phase19_validate_live_club_forecasts(forecasts)
  if (!identical(forecasts$status, "available")) {
    reason <- as.character(forecasts$reason)
    payload$metadata$forecast_status <- "unavailable"
    payload$metadata$forecast_reason_code <- as.character(forecasts$reason_code)
    payload$metadata$warnings <- unique(c(payload$metadata$warnings, reason))
    payload$sections$match_forecasts$reason <- reason
    return(payload)
  }
  predictions <- forecasts$predictions
  if (any(predictions$authority_mode != "production") || any(predictions$fixture_authority) ||
      !identical(as.character(forecasts$metadata$source_bundle_sha256), as.character(payload$metadata$source_bundle_sha256)))
    stop("Dashboard forecasts require the approved production model and the displayed accepted source generation", call. = FALSE)
  index <- match(predictions$fixture_id, as.character(matches$provider_match_id))
  if (anyNA(index) || any(matches$status[index] == "FINISHED") ||
      any(as.character(matches$kickoff_utc[index]) != predictions$kickoff_utc) ||
      any(as.character(matches$home_club_id[index]) != predictions$home_club_id) ||
      any(as.character(matches$away_club_id[index]) != predictions$away_club_id))
    stop("Live forecast identities must match unplayed accepted fixtures", call. = FALSE)
  # A saved forecast envelope is evidence of its earlier information cutoff,
  # never permission to keep a past fixture in the live upcoming table.
  partition <- phase21_ucl_partition_forecasts(predictions, payload$metadata$generated_at_utc)
  archived <- partition$archived
  predictions <- partition$upcoming
  payload$metadata$archived_forecast_count <- nrow(archived)
  if (nrow(archived)) payload$forecast_archive <- phase21_rows(archived[, intersect(
    c("fixture_id", "kickoff_utc", "home_club_id", "away_club_id", "p_home", "p_draw", "p_away", "information_cutoff_utc", "model_release_id"), names(archived)), drop = FALSE])
  rows <- data.frame(`Kickoff (UTC)` = predictions$kickoff_utc,
    Home = unname(clubs[predictions$home_club_id]), Away = unname(clubs[predictions$away_club_id]),
    `Home win` = sprintf("%.1f%%", 100 * predictions$p_home),
    Draw = sprintf("%.1f%%", 100 * predictions$p_draw),
    `Away win` = sprintf("%.1f%%", 100 * predictions$p_away),
    `Expected home goals` = round(predictions$expected_home_goals, 2),
    `Expected away goals` = round(predictions$expected_away_goals, 2),
    `Most likely score` = paste(predictions$likely_home_goals, predictions$likely_away_goals, sep = "–"),
    stringsAsFactors = FALSE, check.names = FALSE)
  payload$sections$match_forecasts <- phase21_section("match_forecasts", "Match forecasts", rows,
    "available", paste0(if (identical(forecasts$metadata$probability_view, "calibrated_1x2")) "Calibrated" else "Raw",
      " match probabilities selected by the approved release; expected goals and likely scores use the raw negative-binomial score distribution."))
  if (identical(unique(as.character(predictions$model_id)), "club_venue_nb"))
    payload$sections$match_forecasts$reason <- paste(
      "Venue baseline: probabilities use historical home/away scoring rates and do not distinguish team strength.",
      payload$sections$match_forecasts$reason)
  payload$metadata$forecast_model_quality <- if (identical(unique(as.character(forecasts$predictions$model_id)), "club_venue_nb"))
    "Venue baseline only; team-strength model did not pass promotion QA" else "Approved club model"
  payload$metadata$forecast_status <- "available"
  payload$metadata$production_eligible <- TRUE
  payload$metadata$forecast_provenance <- forecasts$metadata
  payload$metadata$forecast_sha256 <- forecasts$forecast_sha256
  for (field in c("model_release_id", "model_sha256", "calibrator_sha256", "information_cutoff_utc"))
    payload$metadata[[field]] <- forecasts$metadata[[field]]
  payload$metadata$forecast_count <- nrow(predictions)
  payload$metadata$forecast_unavailable_count <- nrow(forecasts$unavailable)
  payload$metadata$forecast_unavailable <- phase21_rows(forecasts$unavailable)
  if (!nrow(predictions) || identical(payload$metadata$freshness_status, "stale")) {
    payload$metadata$forecast_status <- "unavailable"
    payload$metadata$forecast_reason_code <- if (!nrow(predictions)) "no_future_forecasts" else "stale_current_source"
    payload$metadata$production_eligible <- FALSE
    payload$sections$match_forecasts <- phase21_section("match_forecasts", "Match forecasts", list(), "unavailable",
      if (!nrow(predictions)) "No supported forecast has kickoff after this page generation time." else "Current-source data is stale. Refresh the accepted feed before using match predictions.")
    payload$metadata$forecast_count <- 0L
  }
  unavailable_reason <- "Club forecasts are unavailable until the historical training data and an evaluated club model release are accepted."
  payload$metadata$warnings <- setdiff(payload$metadata$warnings, unavailable_reason)
  payload$sections$overview$reason <- if (identical(payload$metadata$forecast_status, "available"))
    "Accepted fixtures, results, provider standings and supported upcoming match forecasts are available." else
    "Accepted source facts are shown with their freshness and confirmation status. Match predictions are unavailable."
  for (id in c("structure", "rank_distributions", "qualification_bands", "knockout_paths", "progression_probabilities", "projected_outcomes"))
    payload$sections[[id]]$reason <- "An accepted tournament simulation release is required for this section."
  payload
}
