#' Phase 14 edition-scoped competition state candidate orchestration.
#'
#' This module is deliberately an in-memory candidate boundary.  It composes
#' accepted edition metadata with canonical matches and the release-active
#' forecast layer, but never promotes a derived state into a durable output.

if (!exists("phase14_build_fixture_forecasts", mode = "function")) {
  phase14_state_bundle_bootstrap_root <- normalizePath(".", winslash = "/", mustWork = FALSE)
  repeat {
    if (dir.exists(file.path(phase14_state_bundle_bootstrap_root, ".git")) ||
        file.exists(file.path(phase14_state_bundle_bootstrap_root, ".git"))) {
      break
    }
    phase14_state_bundle_bootstrap_parent <- dirname(phase14_state_bundle_bootstrap_root)
    if (identical(phase14_state_bundle_bootstrap_parent, phase14_state_bundle_bootstrap_root)) break
    phase14_state_bundle_bootstrap_root <- phase14_state_bundle_bootstrap_parent
  }
  source(file.path(
    phase14_state_bundle_bootstrap_root,
    "R/competition/forecast_layer.R"
  ), local = .GlobalEnv)
}

phase14_state_bundle_project_root <- function(path = ".") {
  if (exists("phase14_forecast_project_root", mode = "function")) {
    return(phase14_forecast_project_root(path))
  }
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

phase14_state_bundle_read_table <- function(value, default_path, name) {
  if (is.null(value)) value <- file.path(phase14_state_bundle_project_root(), default_path)
  if (is.character(value) && length(value) == 1L) {
    path <- as.character(value[[1L]])
    if (!grepl("^/", path) && !file.exists(path)) {
      path <- file.path(phase14_state_bundle_project_root(), path)
    }
    if (!file.exists(path)) stop("Phase 14 ", name, " is missing: ", path, call. = FALSE)
    return(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""))
  }
  if (!is.data.frame(value)) stop("Phase 14 ", name, " must be a data frame or CSV path", call. = FALSE)
  value
}

phase14_state_bundle_empty <- function() data.frame(stringsAsFactors = FALSE, check.names = FALSE)

phase14_state_bundle_or <- function(value, fallback) {
  if (is.null(value) || !length(value)) fallback else value
}

phase14_state_bundle_edition_row <- function(edition_registry, edition_id) {
  rows <- phase14_state_bundle_read_table(
    edition_registry,
    "data/competition/registries/competition_editions.csv",
    "competition edition registry"
  )
  if (!"edition_id" %in% names(rows)) stop("Phase 14 competition edition registry requires edition_id", call. = FALSE)
  selected <- rows[as.character(rows$edition_id) == as.character(edition_id), , drop = FALSE]
  if (nrow(selected) > 1L) stop("Phase 14 competition edition registry has ambiguous edition_id: ", edition_id, call. = FALSE)
  if (!nrow(selected)) stop("Phase 14 competition edition is not registered: ", edition_id, call. = FALSE)
  selected
}

phase14_state_bundle_scalar_text <- function(row, field, default = NA_character_) {
  if (!is.data.frame(row) || !nrow(row) || !field %in% names(row)) return(default)
  value <- as.character(row[[field]][[1L]])
  if (is.na(value) || !nzchar(trimws(value))) default else trimws(value)
}

phase14_state_bundle_edition_rows <- function(data, edition_id, name, allow_unscoped = TRUE) {
  if (is.null(data)) return(phase14_state_bundle_empty())
  if (!is.data.frame(data)) stop("Phase 14 ", name, " must be a data frame", call. = FALSE)
  if (!"edition_id" %in% names(data)) {
    if (!isTRUE(allow_unscoped)) {
      stop("Phase 14 ", name, " must declare edition_id before shared orchestration", call. = FALSE)
    }
    return(data)
  }
  values <- as.character(data$edition_id)
  foreign <- !is.na(values) & nzchar(values) & values != as.character(edition_id)
  if (any(foreign)) {
    stop(
      "Phase 14 cross-edition join rejected for ", name,
      ": expected edition_id=", edition_id,
      ", found=", paste(unique(values[foreign]), collapse = "|"),
      call. = FALSE
    )
  }
  data[!foreign, , drop = FALSE]
}

phase14_state_bundle_match_rows <- function(canonical_matches, edition_id, edition_count) {
  if (is.null(canonical_matches)) return(phase14_state_bundle_empty())
  if (!is.data.frame(canonical_matches)) stop("Phase 14 canonical_matches must be a data frame", call. = FALSE)
  if (!"edition_id" %in% names(canonical_matches)) {
    if (edition_count > 1L && nrow(canonical_matches)) {
      stop("Phase 14 canonical_matches must declare edition_id for shared orchestration", call. = FALSE)
    }
    return(canonical_matches)
  }
  values <- as.character(canonical_matches$edition_id)
  foreign <- !is.na(values) & nzchar(values) & values != as.character(edition_id)
  canonical_matches[!foreign, , drop = FALSE]
}

phase14_state_bundle_status_rows <- function(rows) {
  if (!nrow(rows) || !"match_status" %in% names(rows) && !"source_status" %in% names(rows)) {
    return(rows[FALSE, , drop = FALSE])
  }
  status_column <- if ("match_status" %in% names(rows)) "match_status" else "source_status"
  status <- tolower(trimws(as.character(rows[[status_column]])))
  rows[status %in% c("completed", "complete", "played", "final", "result"), , drop = FALSE]
}

phase14_state_bundle_resolved_release <- function(
    resolved_release,
    selector_path,
    trusted_release_root) {
  if (!is.null(resolved_release)) return(resolved_release)
  selector <- phase14_state_bundle_or(selector_path, file.path(trusted_release_root, "approved_release.csv"))
  # There is intentionally no raw-model fallback at this boundary.
  phase14_resolve_approved_release(selector, trusted_release_root)
}

phase14_state_bundle_manifest <- function(
    resolved_release,
    model_manifest,
    model_manifest_path) {
  phase14_forecast_model_manifest(
    resolved_release,
    model_manifest = model_manifest,
    model_manifest_path = model_manifest_path
  )
}

phase14_state_bundle_active_input_audit <- function(
    resolved_release,
    model_manifest,
    model_manifest_path,
    canonical_matches,
    team_registry,
    national_team_xg_registry,
    national_team_xg_history,
    elo_ratings) {
  manifest <- phase14_state_bundle_manifest(resolved_release, model_manifest, model_manifest_path)
  active_ids <- unique(vapply(manifest$active_predictors, phase14_forecast_active_feature_id, character(1)))
  dropped <- manifest$dropped_predictors_with_reason
  xg_active <- phase14_forecast_active_xg(manifest$active_predictors)
  xg_status <- if (!xg_active) "inactive_optional_unavailable" else "active_required_missing"
  xg_reason <- if (!xg_active) "inactive_predictors_registered_missingness" else "no_accepted_point_in_time_national_team_xg"

  xg_registry <- national_team_xg_registry
  if (is.null(xg_registry)) {
    xg_registry <- file.path(
      phase14_state_bundle_project_root(),
      "data/competition/registries/national_team_xg_sources.csv"
    )
  }
  if (xg_active) {
    xg_registry <- phase14_national_team_xg_registry_read(
      xg_registry,
      project_root = phase14_state_bundle_project_root()
    )
    phase14_validate_national_team_xg_registry(
      xg_registry,
      project_root = phase14_state_bundle_project_root(),
      verify_artifacts = TRUE
    )
    accepted <- any(as.character(xg_registry$acceptance_status) == "accepted")
    history_present <- is.data.frame(national_team_xg_history) && nrow(national_team_xg_history) > 0L
    if (accepted && history_present && nrow(canonical_matches)) {
      teams <- unique(c(as.character(canonical_matches$home_team_id), as.character(canonical_matches$away_team_id)))
      cutoff <- min(as.POSIXct(canonical_matches$feature_cutoff_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), na.rm = TRUE)
      form <- phase14_build_model_form(
        xg_history = national_team_xg_history,
        teams = teams,
        feature_cutoff_utc = phase14_forecast_format_utc(cutoff),
        span = 12L,
        registry = xg_registry,
        edition_id = unique(as.character(canonical_matches$edition_id))[[1L]],
        project_root = phase14_state_bundle_project_root()
      )
      covered <- all(as.character(form$availability_status) == "available")
      if (covered) {
        xg_status <- "available"
        xg_reason <- "accepted_point_in_time_national_team_xg"
      }
    }
  }

  elo_status <- "not_required"
  required_status <- "available"
  failure_reason <- NA_character_
  if ("elo_diff" %in% active_ids) {
    elo_status <- "available"
    if (!is.data.frame(elo_ratings) || !nrow(elo_ratings)) {
      elo_status <- "active_required_missing"
      required_status <- "unavailable"
      failure_reason <- "active_predictor_evidence_unavailable"
    } else if (nrow(canonical_matches)) {
      eligible <- tolower(as.character(phase14_forecast_column(canonical_matches, c("match_status", "source_status"), "scheduled"))) %in% c("scheduled", "open", "pending")
      if (any(eligible)) {
        available <- vapply(which(eligible), function(index) {
          kickoff <- tryCatch(phase14_forecast_match_kickoff(canonical_matches, index), error = function(error) NULL)
          if (is.null(kickoff)) return(FALSE)
          cutoff <- tryCatch(phase14_forecast_cutoff_for_row(canonical_matches, index, kickoff, NULL), error = function(error) NULL)
          if (is.null(cutoff)) return(FALSE)
          home <- phase14_forecast_row_value(canonical_matches, index, "home_team_id", NA_character_)
          away <- phase14_forecast_row_value(canonical_matches, index, "away_team_id", NA_character_)
          registry <- phase14_forecast_team_registry(team_registry)
          names <- phase14_forecast_team_name_lookup(registry)
          if (is.na(names[[home]]) || is.na(names[[away]])) return(FALSE)
          evidence <- phase14_forecast_elo_evidence(
            elo_ratings, names[[home]], names[[away]], cutoff,
            phase14_forecast_row_value(canonical_matches, index, "venue", "home")
          )
          isTRUE(evidence$available)
        }, logical(1))
        if (any(!available)) {
          elo_status <- "active_required_missing"
          required_status <- "unavailable"
          failure_reason <- "active_predictor_evidence_unavailable"
        }
      }
    }
  }
  if (identical(xg_status, "active_required_missing")) {
    required_status <- "unavailable"
    failure_reason <- "active_national_team_xg_unavailable"
  }
  list(
    model_id = manifest$model_id,
    active_predictors = manifest$active_predictors,
    active_feature_ids = active_ids,
    dropped_predictors_with_reason = dropped,
    model_manifest_sha256 = manifest$manifest_sha256,
    xg_evidence_status = xg_status,
    xg_evidence_reason = xg_reason,
    elo_evidence_status = elo_status,
    required_active_input_status = required_status,
    failure_reason = failure_reason,
    fan_out = 0L
  )
}

phase14_state_bundle_empty_candidate <- function(
    edition_id,
    lifecycle_state,
    reason,
    shared_input_audit,
    resolved_release = NULL,
    edition_row = NULL) {
  empty_forecast <- phase14_forecast_empty_result(reason)
  list(
    edition_id = as.character(edition_id),
    candidate_status = "invalid",
    failure_reason = as.character(reason),
    lifecycle_state = as.character(lifecycle_state),
    edition_registry = edition_row,
    fixtures = phase14_state_bundle_empty(),
    results = phase14_state_bundle_empty(),
    groups = phase14_state_bundle_empty(),
    standings = phase14_state_bundle_empty(),
    competition_form = phase14_state_bundle_empty(),
    all_senior_form = phase14_state_bundle_empty(),
    forecast = empty_forecast,
    forecast_status = empty_forecast$fixture_status,
    shared_input_audit = shared_input_audit,
    resolved_release = resolved_release,
    state_status = reason
  )
}

phase14_state_bundle_candidate <- function(
    edition_id,
    edition_row,
    canonical_matches,
    team_registry,
    resolved_release,
    selector_path,
    trusted_release_root,
    elo_ratings,
    national_team_xg_registry,
    national_team_xg_history,
    model_manifest,
    model_manifest_path,
    results,
    groups,
    standings,
    competition_form,
    all_senior_form,
    historical_matches,
    shared_input_audit) {
  lifecycle <- phase14_state_bundle_scalar_text(edition_row, "lifecycle_state", "scheduled")
  rows <- phase14_state_bundle_match_rows(canonical_matches, edition_id, 1L)
  if (identical(lifecycle, "pre_draw")) {
    forecast <- phase14_forecast_empty_result("pre_draw")
    return(list(
      edition_id = as.character(edition_id),
      candidate_status = "valid",
      failure_reason = NA_character_,
      lifecycle_state = lifecycle,
      edition_registry = edition_row,
      fixtures = phase14_state_bundle_empty(),
      results = phase14_state_bundle_empty(),
      groups = phase14_state_bundle_empty(),
      standings = phase14_state_bundle_empty(),
      competition_form = phase14_state_bundle_empty(),
      all_senior_form = phase14_state_bundle_empty(),
      forecast = forecast,
      forecast_status = "pre_draw",
      shared_input_audit = shared_input_audit,
      resolved_release = resolved_release,
      state_status = "pre_draw"
    ))
  }

  fixture_rows <- phase14_state_bundle_edition_rows(rows, edition_id, "fixtures")
  result_rows <- if (!is.null(results)) {
    phase14_state_bundle_edition_rows(results, edition_id, "results")
  } else {
    phase14_state_bundle_status_rows(fixture_rows)
  }
  group_rows <- phase14_state_bundle_edition_rows(groups, edition_id, "groups")
  standing_rows <- phase14_state_bundle_edition_rows(standings, edition_id, "standings")
  competition_form_rows <- phase14_state_bundle_edition_rows(competition_form, edition_id, "competition_form")
  all_senior_form_rows <- phase14_state_bundle_edition_rows(all_senior_form, edition_id, "all_senior_form")

  forecast <- phase14_build_fixture_forecasts(
    canonical_matches = fixture_rows,
    team_registry = team_registry,
    resolved_release = resolved_release,
    selector_path = selector_path,
    trusted_release_root = trusted_release_root,
    elo_ratings = elo_ratings,
    national_team_xg_registry = national_team_xg_registry,
    national_team_xg_history = national_team_xg_history,
    model_manifest = model_manifest,
    model_manifest_path = model_manifest_path,
    edition_registry = edition_row,
    edition_lifecycle_state = lifecycle
  )
  forecast_status <- forecast$fixture_status
  valid <- !length(shared_input_audit$failure_reason) || is.na(shared_input_audit$failure_reason)
  if (nrow(forecast_status) && any(as.character(forecast_status$forecast_status) == "suppressed")) valid <- FALSE
  failure_reason <- if (valid) NA_character_ else {
    if (length(shared_input_audit$failure_reason) && !is.na(shared_input_audit$failure_reason)) {
      shared_input_audit$failure_reason
    } else {
      unique(as.character(forecast_status$suppression_reason))[1L]
    }
  }
  list(
    edition_id = as.character(edition_id),
    candidate_status = if (valid) "valid" else "invalid",
    failure_reason = failure_reason,
    lifecycle_state = lifecycle,
    edition_registry = edition_row,
    fixtures = fixture_rows,
    results = result_rows,
    groups = group_rows,
    standings = standing_rows,
    competition_form = competition_form_rows,
    all_senior_form = all_senior_form_rows,
    forecast = forecast,
    forecast_status = forecast_status,
    shared_input_audit = shared_input_audit,
    resolved_release = resolved_release,
    state_status = if (valid) "scheduled" else "suppressed"
  )
}

#' Build one edition-scoped candidate, or a deterministic shared bundle.
#'
#' A vector edition_id is the only supported shared orchestration form.  Shared
#' release/strength/history failures fan out to every candidate; fixtures,
#' results, standings, form, and forecasts remain edition-local.
phase14_build_competition_state_candidate <- function(
    edition_id,
    edition_registry = NULL,
    canonical_matches = NULL,
    team_registry = file.path(phase14_state_bundle_project_root(), "data/competition/registries/team_identity.csv"),
    resolved_release = NULL,
    selector_path = NULL,
    trusted_release_root = file.path(phase14_state_bundle_project_root(), "outputs/releases"),
    elo_ratings = NULL,
    national_team_xg_registry = NULL,
    national_team_xg_history = NULL,
    model_manifest = NULL,
    model_manifest_path = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv",
    results = NULL,
    groups = NULL,
    standings = NULL,
    competition_form = NULL,
    all_senior_form = NULL,
    historical_matches = NULL,
    ...) {
  ids <- unique(as.character(edition_id))
  if (!length(ids) || any(is.na(ids) | !nzchar(ids))) stop("Phase 14 state candidate requires non-empty edition_id", call. = FALSE)
  if (length(ids) != length(as.character(edition_id))) stop("Phase 14 state candidate edition_id values must be unique", call. = FALSE)
  registry <- phase14_state_bundle_read_table(
    edition_registry,
    "data/competition/registries/competition_editions.csv",
    "competition edition registry"
  )
  edition_rows <- lapply(ids, function(id) phase14_state_bundle_edition_row(registry, id))
  names(edition_rows) <- ids
  resolved <- phase14_state_bundle_resolved_release(resolved_release, selector_path, trusted_release_root)
  audit <- phase14_state_bundle_active_input_audit(
    resolved,
    model_manifest,
    model_manifest_path,
    phase14_state_bundle_or(canonical_matches, phase14_state_bundle_empty()),
    team_registry,
    national_team_xg_registry,
    national_team_xg_history,
    elo_ratings
  )
  shared_failure <- if (length(audit$failure_reason) && !is.na(audit$failure_reason)) audit$failure_reason else NULL
  if (length(ids) > 1L) {
    if (!is.null(canonical_matches) && is.data.frame(canonical_matches) && nrow(canonical_matches) && !"edition_id" %in% names(canonical_matches)) {
      stop("Phase 14 canonical_matches must declare edition_id for shared orchestration", call. = FALSE)
    }
    audit$fan_out <- if (!is.null(shared_failure)) as.integer(length(ids)) else 0L
    candidates <- lapply(seq_along(ids), function(index) {
      id <- ids[[index]]
      if (!is.null(shared_failure)) {
        return(phase14_state_bundle_empty_candidate(
          id,
          lifecycle_state = phase14_state_bundle_scalar_text(edition_rows[[index]], "lifecycle_state", "scheduled"),
          reason = shared_failure,
          shared_input_audit = audit,
          resolved_release = resolved,
          edition_row = edition_rows[[index]]
        ))
      }
      local_audit <- audit
      local_audit$fan_out <- 0L
      local_rows <- phase14_state_bundle_match_rows(canonical_matches, id, length(ids))
      phase14_state_bundle_candidate(
        id,
        edition_rows[[index]],
        local_rows,
        team_registry,
        resolved,
        selector_path,
        trusted_release_root,
        elo_ratings,
        national_team_xg_registry,
        national_team_xg_history,
        model_manifest,
        model_manifest_path,
        results,
        groups,
        standings,
        competition_form,
        all_senior_form,
        historical_matches,
        local_audit
      )
    })
    names(candidates) <- ids
    return(list(
      candidates = candidates,
      shared_input_audit = audit,
      edition_ids = ids,
      resolved_release = resolved
    ))
  }

  if (!is.null(canonical_matches) && is.data.frame(canonical_matches) && "edition_id" %in% names(canonical_matches)) {
    values <- as.character(canonical_matches$edition_id)
    if (any(!is.na(values) & nzchar(values) & values != ids[[1L]])) {
      stop("Phase 14 cross-edition canonical_matches rejected for edition_id=", ids[[1L]], call. = FALSE)
    }
  }
  audit$fan_out <- 0L
  phase14_state_bundle_candidate(
    ids[[1L]],
    edition_rows[[1L]],
    phase14_state_bundle_match_rows(canonical_matches, ids[[1L]], 1L),
    team_registry,
    resolved,
    selector_path,
    trusted_release_root,
    elo_ratings,
    national_team_xg_registry,
    national_team_xg_history,
    model_manifest,
    model_manifest_path,
    results,
    groups,
    standings,
    competition_form,
    all_senior_form,
    historical_matches,
    audit
  )
}

phase14_build_competition_state_candidates <- phase14_build_competition_state_candidate
