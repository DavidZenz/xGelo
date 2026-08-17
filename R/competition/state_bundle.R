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

# ---------------------------------------------------------------------------
# Phase 14 production state-batch boundary
# ---------------------------------------------------------------------------
#
# The original candidate function above is retained as the small tracer
# implementation used by the earlier phase tests.  The production boundary
# below adds the properties that are intentionally absent from that tracer:
# one shared preflight, edition-local work, exact artifact inventory, stable
# hashes, and a fail-closed validator.  All state remains in memory here;
# durable publication is owned by the later promotion plan.

phase14_state_bundle_expected_inventory <- function() {
  c(
    "state/canonical_matches.csv",
    "state/standings.csv",
    "state/competition_form.csv",
    "state/all_international_form.csv",
    "state/model_form.csv",
    "state/forecast_status.csv",
    "state/forecasts.csv",
    "state/forecast_top10.csv",
    "audit/standings_reconciliation.csv",
    "audit/state_manifest.csv",
    "local/score_distributions.rds"
  )
}

phase14_state_bundle_named_empty <- function() {
  data.frame(stringsAsFactors = FALSE, check.names = FALSE)
}

phase14_state_bundle_hash_value <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 14 state-bundle lineage", call. = FALSE)
  }
  if (is.data.frame(value)) {
    # phase14_forecast_hash_data orders columns before serialising; base::order
    # has no vector to order for a zero-column empty schema.  Empty artifacts
    # are valid (notably pre_draw), so hash their stable column-name schema.
    if (!ncol(value)) {
      return(digest::digest(paste(names(value), collapse = "|"), algo = "sha256", serialize = FALSE))
    }
    return(phase14_forecast_hash_data(value))
  }
  if (is.raw(value)) return(digest::digest(value, algo = "sha256", serialize = FALSE))
  digest::digest(value, algo = "sha256")
}

phase14_state_bundle_row_hashes <- function(value) {
  if (!is.data.frame(value) || !nrow(value)) return(character())
  vapply(seq_len(nrow(value)), function(index) {
    phase14_forecast_hash_data(value[index, , drop = FALSE])
  }, character(1))
}

phase14_state_bundle_value_rows <- function(value) {
  if (is.data.frame(value)) return(as.integer(nrow(value)))
  if (is.null(value)) return(0L)
  1L
}

phase14_state_bundle_text <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

phase14_state_bundle_predictor_text <- function(value) {
  value <- as.character(value %||% character())
  value <- value[!is.na(value) & nzchar(trimws(value))]
  paste(unique(value), collapse = "|")
}

phase14_state_bundle_manifest_field <- function(manifest, field, default = "") {
  if (!is.list(manifest) || is.null(manifest[[field]])) return(default)
  value <- manifest[[field]]
  if (length(value) > 1L && is.character(value)) return(paste(value, collapse = "|"))
  phase14_state_bundle_text(value, default)
}

phase14_state_bundle_release_field <- function(release, path, default = "") {
  value <- release
  for (name in strsplit(path, "\\.", fixed = FALSE)[[1L]]) {
    if (!is.list(value) || is.null(value[[name]])) return(default)
    value <- value[[name]]
  }
  phase14_state_bundle_text(value, default)
}

phase14_state_bundle_default_edition_ids <- function(edition_registry) {
  # `both` is an explicit product choice, not a recency query.  The registry
  # order is deliberately ignored so replay does not depend on CSV ordering.
  fixed <- c("uefa_euro_2028_qualifying", "uefa_nations_league_2026_27")
  registry <- phase14_state_bundle_read_table(
    edition_registry,
    "data/competition/registries/competition_editions.csv",
    "competition edition registry"
  )
  registered <- as.character(registry$edition_id)
  ids <- fixed[fixed %in% registered]
  if (length(ids) != length(fixed)) {
    stop("Phase 14 explicit both-edition build requires the registered EURO and Nations League editions", call. = FALSE)
  }
  ids
}

phase14_state_bundle_normalize_edition_ids <- function(edition_id, edition_ids, edition_registry) {
  if (!is.null(edition_id) && !is.null(edition_ids)) {
    stop("Phase 14 state batch accepts edition_id or edition_ids, not both", call. = FALSE)
  }
  ids <- edition_ids %||% edition_id
  if (is.null(ids) || !length(ids)) stop("Phase 14 state batch requires an explicit edition_id", call. = FALSE)
  ids <- as.character(ids)
  if (length(ids) == 1L && identical(tolower(ids[[1L]]), "both")) {
    ids <- phase14_state_bundle_default_edition_ids(edition_registry)
  }
  if (any(is.na(ids) | !nzchar(trimws(ids))) || anyDuplicated(ids)) {
    stop("Phase 14 state batch edition IDs must be non-empty and unique", call. = FALSE)
  }
  ids
}

phase14_state_bundle_validate_history <- function(historical_matches, edition_count) {
  if (is.null(historical_matches)) {
    return(list(status = "not_supplied", scope = "all_senior_international", sha256 = ""))
  }
  if (!is.data.frame(historical_matches)) {
    stop("Phase 14 shared historical senior-international input must be a data frame", call. = FALSE)
  }
  scope <- attr(historical_matches, "history_scope") %||% ""
  if ("history_scope" %in% names(historical_matches) && nrow(historical_matches)) {
    declared <- unique(as.character(historical_matches$history_scope))
    declared <- declared[!is.na(declared) & nzchar(declared)]
    if (length(declared)) scope <- paste(unique(declared), collapse = "|")
  }
  if (!nzchar(scope)) scope <- "all_senior_international"
  if (!identical(scope, "all_senior_international")) {
    stop("Phase 14 shared historical input requires declared all_senior_international scope", call. = FALSE)
  }
  if (edition_count > 1L && "edition_id" %in% names(historical_matches)) {
    values <- as.character(historical_matches$edition_id)
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) {
      stop("Phase 14 historical competition joins require the declared all_senior_international scope", call. = FALSE)
    }
  }
  list(
    status = if (nrow(historical_matches)) "available" else "empty",
    scope = scope,
    sha256 = phase14_state_bundle_hash_value(historical_matches)
  )
}

phase14_state_bundle_empty_audit <- function(reason = NA_character_, scope = NA_character_) {
  list(
    model_id = "",
    active_predictors = character(),
    active_feature_ids = character(),
    dropped_predictors_with_reason = character(),
    model_manifest_sha256 = "",
    xg_evidence_status = "not_evaluated",
    xg_evidence_reason = "not_evaluated",
    elo_evidence_status = "not_evaluated",
    required_active_input_status = if (is.na(reason)) "not_evaluated" else "unavailable",
    failure_reason = reason,
    failure_scope = scope,
    fan_out = 0L,
    history_status = "not_evaluated",
    history_scope = "all_senior_international",
    history_sha256 = ""
  )
}

phase14_state_bundle_shared_preflight <- function(
    ids,
    edition_registry,
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
    historical_matches) {
  identity_error <- NULL
  tryCatch(
    phase14_forecast_team_registry(team_registry),
    error = function(error) identity_error <<- error
  )
  resolved_error <- NULL
  resolved <- resolved_release
  if (is.null(identity_error) && is.null(resolved)) {
    resolved <- tryCatch(
      phase14_state_bundle_resolved_release(resolved_release, selector_path, trusted_release_root),
      error = function(error) {
        resolved_error <<- error
        NULL
      }
    )
  }
  if (is.null(identity_error) && is.null(resolved_error) && is.null(resolved)) {
    resolved_error <- simpleError("Phase 14 approved release is unavailable")
  }

  history_error <- NULL
  history_audit <- tryCatch(
    phase14_state_bundle_validate_history(historical_matches, length(ids)),
    error = function(error) {
      history_error <<- error
      phase14_state_bundle_validate_history(NULL, length(ids))
    }
  )
  manifest <- NULL
  manifest_error <- NULL
  if (is.null(identity_error) && is.null(resolved_error)) {
    manifest <- tryCatch(
      phase14_state_bundle_manifest(resolved, model_manifest, model_manifest_path),
      error = function(error) {
        manifest_error <<- error
        NULL
      }
    )
  }
  audit <- if (!is.null(manifest) && is.null(history_error)) {
    tryCatch(
      phase14_state_bundle_active_input_audit(
        resolved,
        model_manifest,
        model_manifest_path,
        phase14_state_bundle_or(canonical_matches, phase14_state_bundle_empty()),
        team_registry,
        national_team_xg_registry,
        national_team_xg_history,
        elo_ratings
      ),
      error = function(error) {
        manifest_error <<- error
        phase14_state_bundle_empty_audit()
      }
    )
  } else {
    phase14_state_bundle_empty_audit()
  }
  audit$history_status <- history_audit$status
  audit$history_scope <- history_audit$scope
  audit$history_sha256 <- history_audit$sha256

  failure_reason <- NA_character_
  failure_scope <- NA_character_
  if (!is.null(identity_error)) {
    failure_reason <- "shared_identity_validation_failed"
    failure_scope <- "shared"
  } else if (!is.null(resolved_error) || !is.null(manifest_error)) {
    failure_reason <- if (!is.null(resolved_error)) {
      if (exists("phase14_forecast_batch_release_failure_reason", mode = "function")) {
        phase14_forecast_batch_release_failure_reason(resolved_error)
      } else {
        "shared_release_validation_failed"
      }
    } else {
      "shared_release_validation_failed"
    }
    failure_scope <- "shared"
  } else if (!is.null(history_error)) {
    failure_reason <- "shared_history_validation_failed"
    failure_scope <- "shared"
  } else if (!is.null(audit$failure_reason) && !is.na(audit$failure_reason)) {
    failure_reason <- as.character(audit$failure_reason)
    failure_scope <- "shared"
  }
  audit$failure_reason <- failure_reason
  audit$failure_scope <- failure_scope
  audit$release_status <- if (is.null(resolved_error) && is.null(manifest_error) && !is.null(resolved)) "available" else "unavailable"
  audit$release_failure_reason <- if (is.null(resolved_error) && is.null(manifest_error)) NA_character_ else failure_reason
  list(
    resolved_release = resolved,
    manifest = manifest,
    audit = audit,
    failure_reason = if (is.na(failure_reason)) NULL else failure_reason,
    failure_scope = failure_scope,
    identity_error = identity_error,
    resolved_error = resolved_error,
    manifest_error = manifest_error,
    history_error = history_error
  )
}

phase14_state_bundle_model_form <- function(forecast) {
  if (is.list(forecast) && is.list(forecast$features) && is.data.frame(forecast$features$model_form)) {
    return(forecast$features$model_form)
  }
  phase14_state_bundle_named_empty()
}

phase14_state_bundle_status_table <- function(candidate) {
  if (is.data.frame(candidate$forecast_status)) return(candidate$forecast_status)
  data.frame(
    edition_id = as.character(candidate$edition_id),
    lifecycle_state = as.character(candidate$lifecycle_state),
    forecast_status = as.character(candidate$forecast_status %||% candidate$state_status),
    suppression_reason = as.character(candidate$forecast_status %||% candidate$state_status),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_state_bundle_candidate_production <- function(
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
    shared_input_audit,
    generated_at_utc = NULL) {
  lifecycle <- phase14_state_bundle_scalar_text(edition_row, "lifecycle_state", "scheduled")
  rows <- phase14_state_bundle_match_rows(canonical_matches, edition_id, 1L)
  if (identical(lifecycle, "pre_draw")) {
    forecast <- phase14_forecast_empty_result("pre_draw")
    forecast$forecast_top10 <- phase14_state_bundle_named_empty()
    forecast$local_score_distributions <- forecast$score_distributions
    return(list(
      edition_id = as.character(edition_id),
      candidate_status = "valid",
      failure_reason = NA_character_,
      failure_scope = NA_character_,
      lifecycle_state = lifecycle,
      edition_registry = edition_row,
      fixtures = phase14_state_bundle_empty(),
      results = phase14_state_bundle_empty(),
      groups = phase14_state_bundle_empty(),
      standings = phase14_state_bundle_empty(),
      competition_form = phase14_state_bundle_empty(),
      all_senior_form = phase14_state_bundle_empty(),
      model_form = phase14_state_bundle_named_empty(),
      forecast = forecast,
      forecast_status = "pre_draw",
      forecast_status_table = data.frame(
        edition_id = as.character(edition_id), lifecycle_state = lifecycle,
        forecast_status = "pre_draw", suppression_reason = "pre_draw",
        stringsAsFactors = FALSE, check.names = FALSE
      ),
      shared_input_audit = shared_input_audit,
      resolved_release = resolved_release,
      state_status = "pre_draw",
      historical_matches = historical_matches
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
    edition_lifecycle_state = lifecycle,
    generated_at_utc = generated_at_utc
  )
  forecast$forecast_top10 <- forecast$forecast_top10 %||% phase14_state_bundle_named_empty()
  forecast$local_score_distributions <- forecast$local_score_distributions %||% forecast$score_distributions
  forecast_status <- forecast$fixture_status
  valid <- is.null(shared_input_audit$failure_reason) || is.na(shared_input_audit$failure_reason)
  if (nrow(forecast_status) && any(as.character(forecast_status$forecast_status) == "suppressed")) valid <- FALSE
  failure_reason <- if (valid) NA_character_ else {
    if (!is.null(shared_input_audit$failure_reason) && !is.na(shared_input_audit$failure_reason)) {
      as.character(shared_input_audit$failure_reason)
    } else {
      as.character(unique(forecast_status$suppression_reason)[[1L]])
    }
  }
  list(
    edition_id = as.character(edition_id),
    candidate_status = if (valid) "valid" else "invalid",
    failure_reason = failure_reason,
    failure_scope = if (valid) NA_character_ else "edition_local",
    lifecycle_state = lifecycle,
    edition_registry = edition_row,
    fixtures = fixture_rows,
    results = result_rows,
    groups = group_rows,
    standings = standing_rows,
    competition_form = competition_form_rows,
    all_senior_form = all_senior_form_rows,
    model_form = phase14_state_bundle_model_form(forecast),
    forecast = forecast,
    forecast_status = forecast_status,
    forecast_status_table = forecast_status,
    shared_input_audit = shared_input_audit,
    resolved_release = resolved_release,
    state_status = if (valid) "scheduled" else "suppressed",
    historical_matches = historical_matches
  )
}

phase14_state_bundle_local_failure <- function(
    edition_id,
    edition_row,
    reason,
    message,
    shared_input_audit,
    resolved_release) {
  candidate <- phase14_state_bundle_empty_candidate(
    edition_id,
    lifecycle_state = phase14_state_bundle_scalar_text(edition_row, "lifecycle_state", "scheduled"),
    reason = reason,
    shared_input_audit = shared_input_audit,
    resolved_release = resolved_release,
    edition_row = edition_row
  )
  candidate$failure_scope <- "edition_local"
  candidate$local_failure_message <- as.character(message)
  candidate$forecast_status_table <- candidate$forecast$fixture_status
  candidate$model_form <- phase14_state_bundle_named_empty()
  candidate$forecast$forecast_top10 <- phase14_state_bundle_named_empty()
  candidate$forecast$local_score_distributions <- candidate$forecast$score_distributions
  candidate$state_status <- "invalid"
  candidate
}

phase14_state_bundle_artifact_values <- function(candidate) {
  forecast <- candidate$forecast %||% phase14_forecast_empty_result("invalid")
  status <- candidate$forecast_status_table %||% phase14_state_bundle_status_table(candidate)
  model_form <- candidate$model_form %||% phase14_state_bundle_model_form(forecast)
  top10 <- forecast$forecast_top10 %||% phase14_state_bundle_named_empty()
  grids <- forecast$score_distributions %||% phase14_state_bundle_named_empty()
  list(
    "state/canonical_matches.csv" = candidate$fixtures %||% phase14_state_bundle_named_empty(),
    "state/standings.csv" = candidate$standings %||% phase14_state_bundle_named_empty(),
    "state/competition_form.csv" = candidate$competition_form %||% phase14_state_bundle_named_empty(),
    "state/all_international_form.csv" = candidate$all_senior_form %||% phase14_state_bundle_named_empty(),
    "state/model_form.csv" = model_form,
    "state/forecast_status.csv" = status,
    "state/forecasts.csv" = forecast$forecasts %||% phase14_state_bundle_named_empty(),
    "state/forecast_top10.csv" = top10,
    "audit/standings_reconciliation.csv" = candidate$standings_reconciliation %||% phase14_state_bundle_named_empty(),
    "audit/state_manifest.csv" = phase14_state_bundle_named_empty(),
    "local/score_distributions.rds" = grids
  )
}

phase14_state_bundle_parent_map <- function() {
  list(
    "state/canonical_matches.csv" = character(),
    "state/standings.csv" = "state/canonical_matches.csv",
    "state/competition_form.csv" = "state/canonical_matches.csv",
    "state/all_international_form.csv" = character(),
    "state/model_form.csv" = c("state/canonical_matches.csv", "state/all_international_form.csv"),
    "state/forecast_status.csv" = "state/canonical_matches.csv",
    "state/forecasts.csv" = c("state/forecast_status.csv", "state/model_form.csv"),
    "state/forecast_top10.csv" = c("state/forecasts.csv", "local/score_distributions.rds"),
    "audit/standings_reconciliation.csv" = c("state/canonical_matches.csv", "state/standings.csv"),
    "audit/state_manifest.csv" = character(),
    "local/score_distributions.rds" = c("state/forecast_status.csv", "state/model_form.csv")
  )
}

phase14_state_bundle_manifest_rows <- function(
    candidate,
    artifacts,
    generated_at_utc = NULL) {
  release <- candidate$resolved_release %||% list()
  audit <- candidate$shared_input_audit %||% phase14_state_bundle_empty_audit()
  active <- phase14_state_bundle_predictor_text(audit$active_predictors %||% candidate$forecast$active_predictors)
  dropped <- phase14_state_bundle_predictor_text(audit$dropped_predictors_with_reason %||% candidate$forecast$dropped_predictors_with_reason)
  model_cutoff <- phase14_state_bundle_text(release$model_data_cutoff, "")
  status <- candidate$forecast_status_table %||% phase14_state_bundle_status_table(candidate)
  cutoff_values <- if (is.data.frame(status) && "feature_cutoff_utc" %in% names(status)) as.character(status$feature_cutoff_utc) else character()
  cutoff_values <- cutoff_values[!is.na(cutoff_values) & nzchar(cutoff_values)]
  if (!length(cutoff_values) && is.data.frame(candidate$fixtures) && "feature_cutoff_utc" %in% names(candidate$fixtures)) {
    cutoff_values <- as.character(candidate$fixtures$feature_cutoff_utc)
    cutoff_values <- cutoff_values[!is.na(cutoff_values) & nzchar(cutoff_values)]
  }
  feature_cutoff <- paste(unique(cutoff_values), collapse = "|")
  release_id <- phase14_state_bundle_release_field(release, "release_identity.release_id")
  release_manifest_hash <- phase14_state_bundle_release_field(release, "release_identity.manifest_sha256")
  selector_hash <- phase14_state_bundle_release_field(release, "release_identity.selector_self_sha256")
  model_id <- phase14_state_bundle_release_field(release, "model_identity.model_id")
  model_hash <- phase14_state_bundle_release_field(release, "model_identity.sha256")
  calibrator_id <- phase14_state_bundle_release_field(release, "calibrator_identity.calibrator_id")
  calibrator_hash <- phase14_state_bundle_release_field(release, "calibrator_identity.sha256")
  parents <- phase14_state_bundle_parent_map()
  paths <- phase14_state_bundle_expected_inventory()
  rows <- lapply(paths, function(path) {
    value <- artifacts[[path]]
    parent_paths <- parents[[path]] %||% character()
    parent_hashes <- if (length(parent_paths)) {
      vapply(parent_paths, function(parent) phase14_state_bundle_hash_value(artifacts[[parent]]), character(1))
    } else character()
    data.frame(
      edition_id = as.character(candidate$edition_id),
      artifact_path = path,
      artifact_type = if (identical(path, "local/score_distributions.rds")) "rds" else "csv",
      row_count = phase14_state_bundle_value_rows(value),
      content_sha256 = if (identical(path, "audit/state_manifest.csv")) "" else phase14_state_bundle_hash_value(value),
      row_sha256 = if (identical(path, "audit/state_manifest.csv")) "" else paste(phase14_state_bundle_row_hashes(value), collapse = "|"),
      parent_paths = paste(parent_paths, collapse = "|"),
      parent_sha256 = paste(parent_hashes, collapse = "|"),
      model_release_id = release_id,
      release_manifest_sha256 = release_manifest_hash,
      release_selector_sha256 = selector_hash,
      model_id = model_id,
      model_sha256 = model_hash,
      calibrator_id = calibrator_id,
      calibrator_sha256 = calibrator_hash,
      model_data_cutoff = model_cutoff,
      feature_cutoff_utc = feature_cutoff,
      active_predictors = active,
      dropped_predictors_with_reason = dropped,
      national_team_xg_status = phase14_state_bundle_text(audit$xg_evidence_status, "not_evaluated"),
      national_team_xg_source_id = phase14_state_bundle_text(candidate$forecast$features$national_team_xg_source_id, "national_team_xg_sources.csv"),
      national_team_xg_sample_count = as.integer(candidate$forecast$features$national_team_xg_sample_count %||% 0L),
      national_team_xg_feature_cutoff_utc = phase14_state_bundle_text(candidate$forecast$features$national_team_xg_feature_cutoff_utc, ""),
      national_team_xg_availability_reason = phase14_state_bundle_text(candidate$forecast$features$national_team_xg_availability_reason, phase14_state_bundle_text(audit$xg_evidence_reason, "not_evaluated")),
      failure_scope = phase14_state_bundle_text(candidate$failure_scope, ""),
      failure_reason = phase14_state_bundle_text(candidate$failure_reason, ""),
      warnings = if (identical(audit$xg_evidence_status, "inactive_optional_unavailable")) "national_team_xg_unavailable_inactive" else if (is.na(candidate$failure_reason)) "none" else as.character(candidate$failure_reason),
      validation_status = if (identical(candidate$candidate_status, "valid")) "valid" else "invalid",
      generated_at_utc = phase14_state_bundle_text(generated_at_utc, phase14_forecast_text(candidate$forecast$generated_at_utc, "")),
      manifest_sha256 = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output$row_count <- as.integer(output$row_count)
  output$national_team_xg_sample_count <- as.integer(output$national_team_xg_sample_count)
  output
}

phase14_state_bundle_attach_manifest <- function(candidate, generated_at_utc = NULL) {
  artifacts <- phase14_state_bundle_artifact_values(candidate)
  base <- phase14_state_bundle_manifest_rows(candidate, artifacts, generated_at_utc)
  manifest_hash <- phase14_state_bundle_hash_value(base)
  base$manifest_sha256 <- manifest_hash
  self_index <- which(base$artifact_path == "audit/state_manifest.csv")
  base$row_count[[self_index]] <- nrow(base)
  base$content_sha256[[self_index]] <- manifest_hash
  base$row_sha256 <- vapply(seq_len(nrow(base)), function(index) {
    row <- base[index, , drop = FALSE]
    row$row_sha256 <- ""
    phase14_state_bundle_hash_value(row)
  }, character(1))
  artifacts[["audit/state_manifest.csv"]] <- base
  candidate$state_artifacts <- artifacts
  candidate$state_manifest <- base
  candidate$manifest <- base
  candidate$state_manifest_sha256 <- manifest_hash
  candidate$state_status <- candidate$state_status %||% candidate$candidate_status
  candidate
}

phase14_state_bundle_ids_from_status <- function(status) {
  if (!is.data.frame(status) || !nrow(status)) return(character())
  ids <- if ("fixture_id" %in% names(status)) status$fixture_id else character()
  ids <- as.character(ids)
  ids[!is.na(ids) & nzchar(ids)]
}

phase14_state_bundle_validate_in_memory_candidate <- function(candidate) {
  if (!is.list(candidate) || is.null(candidate$edition_id)) stop("Phase 14 state validator requires one candidate", call. = FALSE)
  manifest <- candidate$state_manifest
  expected <- phase14_state_bundle_expected_inventory()
  if (!is.data.frame(manifest) || !identical(as.character(manifest$artifact_path), expected)) {
    stop("Phase 14 state candidate manifest does not enumerate the exact eleven-artifact inventory", call. = FALSE)
  }
  artifacts <- candidate$state_artifacts %||% phase14_state_bundle_artifact_values(candidate)
  if (!identical(names(artifacts), expected)) stop("Phase 14 state candidate artifact inventory is incomplete", call. = FALSE)
  for (index in seq_along(expected)) {
    path <- expected[[index]]
    value <- artifacts[[path]]
    if (!identical(as.integer(manifest$row_count[[index]]), phase14_state_bundle_value_rows(value))) {
      stop("Phase 14 state artifact row count mismatch: ", path, call. = FALSE)
    }
    if (!identical(as.character(manifest$content_sha256[[index]]), as.character(
      if (identical(path, "audit/state_manifest.csv")) manifest$manifest_sha256[[index]] else phase14_state_bundle_hash_value(value)
    ))) {
      stop("Phase 14 state artifact hash mismatch: ", path, call. = FALSE)
    }
    parents <- phase14_state_bundle_text(manifest$parent_paths[[index]], "")
    parent_hashes <- phase14_state_bundle_text(manifest$parent_sha256[[index]], "")
    if (nzchar(parents)) {
      parent_paths <- strsplit(parents, "|", fixed = TRUE)[[1L]]
      expected_hashes <- vapply(parent_paths, function(parent) {
        parent_index <- match(parent, manifest$artifact_path)
        if (is.na(parent_index)) stop("Phase 14 state parent is outside the artifact inventory: ", parent, call. = FALSE)
        phase14_state_bundle_hash_value(artifacts[[parent]])
      }, character(1))
      if (!identical(paste(expected_hashes, collapse = "|"), parent_hashes)) {
        stop("Phase 14 state parent hash mismatch: ", manifest$artifact_path[[index]], call. = FALSE)
      }
    }
  }

  status <- artifacts[["state/forecast_status.csv"]]
  fixtures <- artifacts[["state/canonical_matches.csv"]]
  forecasts <- artifacts[["state/forecasts.csv"]]
  grids <- artifacts[["local/score_distributions.rds"]]
  top10 <- artifacts[["state/forecast_top10.csv"]]
  lifecycle <- as.character(candidate$lifecycle_state %||% "scheduled")
  if (identical(lifecycle, "pre_draw")) {
    if (any(vapply(list(fixtures, forecasts, grids, top10), function(value) is.data.frame(value) && nrow(value), logical(1)))) {
      stop("Phase 14 pre_draw candidate must remain structurally empty", call. = FALSE)
    }
  } else {
    fixture_ids <- if (is.data.frame(fixtures) && nrow(fixtures)) phase14_forecast_batch_fixture_ids(fixtures) else character()
    status_ids <- phase14_state_bundle_ids_from_status(status)
    if (anyDuplicated(status_ids) || !setequal(fixture_ids, status_ids)) {
      stop("Phase 14 state status coverage does not equal canonical fixture coverage", call. = FALSE)
    }
    available_ids <- if (is.data.frame(status) && nrow(status)) as.character(status$fixture_id[status$forecast_status == "available"]) else character()
    forecast_ids <- if (is.data.frame(forecasts) && nrow(forecasts)) as.character(forecasts$fixture_id) else character()
    grid_ids <- if (is.data.frame(grids) && nrow(grids)) sub("__score$", "", unique(as.character(grids$score_distribution_id))) else character()
    top_ids <- if (is.data.frame(top10) && nrow(top10)) unique(as.character(top10$fixture_id)) else character()
    if (anyDuplicated(forecast_ids) || !setequal(available_ids, forecast_ids) ||
        !setequal(available_ids, grid_ids) || !setequal(available_ids, top_ids)) {
      stop("Phase 14 state forecast/status/grid/top10 coverage is not exact", call. = FALSE)
    }
    if (length(available_ids)) {
      if (any(as.integer(forecasts$score_support_max) != 40L) || any(as.integer(forecasts$score_cell_count) != 1681L)) {
        stop("Phase 14 state available forecasts must use fixed G=40 support", call. = FALSE)
      }
      for (fixture_id in available_ids) {
        grid <- grids[as.character(grids$score_distribution_id) == paste0(fixture_id, "__score"), , drop = FALSE]
        if (nrow(grid) != 1681L || !identical(sort(unique(as.integer(grid$home_goals))), 0:40) ||
            !identical(sort(unique(as.integer(grid$away_goals))), 0:40)) {
          stop("Phase 14 state local score grid is not the complete G=40 rectangle: ", fixture_id, call. = FALSE)
        }
      }
      if (any(table(as.character(top10$fixture_id)) > 10L)) stop("Phase 14 state compact top10 output exceeds ten rows", call. = FALSE)
    }
  }
  reason_enum <- c(
    "none", "available", "pre_draw", "kickoff_unconfirmed", "identity_unresolved",
    "feature_evidence_unavailable", "release_not_calibrated", "status_ineligible",
    "approved_release_selector_unavailable", "approved_release_manifest_unavailable",
    "approved_release_model_unavailable", "approved_release_calibrator_unavailable",
    "approved_release_unavailable", "cross_edition"
  )
  if (is.data.frame(status) && nrow(status) && "suppression_reason" %in% names(status)) {
    reasons <- unique(as.character(status$suppression_reason))
    if (any(!reasons %in% reason_enum)) stop("Phase 14 state status has an unsupported suppression reason", call. = FALSE)
  }
  required_manifest_fields <- c("model_data_cutoff", "feature_cutoff_utc", "active_predictors", "dropped_predictors_with_reason", "validation_status")
  if (any(!required_manifest_fields %in% names(manifest))) stop("Phase 14 state manifest lineage is incomplete", call. = FALSE)
  if (any(as.character(manifest$validation_status) == "valid" & is.na(manifest$model_data_cutoff))) {
    stop("Phase 14 state manifest has missing model cutoff", call. = FALSE)
  }
  invisible(TRUE)
}

phase14_validate_competition_state_bundle <- function(bundle) {
  if (is.character(bundle) && length(bundle) == 1L) {
    root <- normalizePath(bundle, winslash = "/", mustWork = TRUE)
    expected <- phase14_state_bundle_expected_inventory()
    present <- file.path(root, expected)
    if (!all(file.exists(present))) stop("Phase 14 durable state bundle is missing an inventory artifact", call. = FALSE)
    relative <- list.files(root, recursive = TRUE, all.files = FALSE, include.dirs = FALSE)
    if (!setequal(relative, expected)) stop("Phase 14 durable state bundle contains an unexpected inventory artifact", call. = FALSE)
    artifacts <- lapply(expected, function(path) {
      full_path <- file.path(root, path)
      if (identical(path, "local/score_distributions.rds")) {
        readRDS(full_path)
      } else {
        utils::read.csv(full_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
      }
    })
    names(artifacts) <- expected
    manifest <- artifacts[["audit/state_manifest.csv"]]
    if (!is.data.frame(manifest) || !nrow(manifest)) stop("Phase 14 durable state bundle manifest is empty", call. = FALSE)
    candidate <- list(
      edition_id = as.character(manifest$edition_id[[1L]]),
      candidate_status = if (all(as.character(manifest$validation_status) == "valid")) "valid" else "invalid",
      lifecycle_state = if (nrow(artifacts[["state/forecast_status.csv"]]) && "lifecycle_state" %in% names(artifacts[["state/forecast_status.csv"]])) {
        as.character(artifacts[["state/forecast_status.csv"]]$lifecycle_state[[1L]])
      } else "scheduled",
      state_manifest = manifest,
      state_artifacts = artifacts
    )
    phase14_state_bundle_validate_in_memory_candidate(candidate)
    return(invisible(TRUE))
  }
  if (!is.list(bundle)) stop("Phase 14 state validator requires a candidate or batch", call. = FALSE)
  if (!is.null(bundle$candidates)) {
    if (!is.character(bundle$edition_ids) || !identical(names(bundle$candidates), bundle$edition_ids)) {
      stop("Phase 14 state batch candidate identity is not deterministic", call. = FALSE)
    }
    for (candidate in bundle$candidates) phase14_state_bundle_validate_in_memory_candidate(candidate)
    if (!is.data.frame(bundle$batch_manifest) || nrow(bundle$batch_manifest) != length(bundle$edition_ids)) {
      stop("Phase 14 state batch manifest is incomplete", call. = FALSE)
    }
    if (!is.character(bundle$batch_sha256) || length(bundle$batch_sha256) != 1L ||
        !grepl("^[0-9a-f]{64}$", bundle$batch_sha256)) {
      stop("Phase 14 state batch SHA-256 is missing", call. = FALSE)
    }
    batch_projection <- bundle$batch_manifest
    if (!"batch_sha256" %in% names(batch_projection)) stop("Phase 14 state batch manifest hash column is missing", call. = FALSE)
    batch_projection$batch_sha256 <- ""
    if (!identical(phase14_state_bundle_hash_value(batch_projection), bundle$batch_sha256)) {
      stop("Phase 14 state batch manifest hash mismatch", call. = FALSE)
    }
    return(invisible(TRUE))
  }
  phase14_state_bundle_validate_in_memory_candidate(bundle)
  invisible(TRUE)
}

phase14_build_competition_state_batch <- function(
    edition_id = NULL,
    edition_ids = NULL,
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
    generated_at_utc = NULL,
    ...) {
  registry <- phase14_state_bundle_read_table(
    edition_registry,
    "data/competition/registries/competition_editions.csv",
    "competition edition registry"
  )
  ids <- phase14_state_bundle_normalize_edition_ids(edition_id, edition_ids, registry)
  if (length(ids) == 1L && is.data.frame(canonical_matches) && "edition_id" %in% names(canonical_matches)) {
    values <- as.character(canonical_matches$edition_id)
    if (any(!is.na(values) & nzchar(values) & values != ids[[1L]])) {
      stop("Phase 14 cross-edition canonical_matches rejected for edition_id=", ids[[1L]], call. = FALSE)
    }
  }
  edition_rows <- lapply(ids, function(id) phase14_state_bundle_edition_row(registry, id))
  names(edition_rows) <- ids
  preflight <- phase14_state_bundle_shared_preflight(
    ids = ids,
    edition_registry = registry,
    canonical_matches = canonical_matches,
    team_registry = team_registry,
    resolved_release = resolved_release,
    selector_path = selector_path,
    trusted_release_root = trusted_release_root,
    elo_ratings = elo_ratings,
    national_team_xg_registry = national_team_xg_registry,
    national_team_xg_history = national_team_xg_history,
    model_manifest = model_manifest,
    model_manifest_path = model_manifest_path,
    historical_matches = historical_matches
  )
  shared_audit <- preflight$audit
  shared_failure <- preflight$failure_reason
  shared_audit$fan_out <- if (!is.null(shared_failure)) as.integer(length(ids)) else 0L
  candidates <- lapply(seq_along(ids), function(index) {
    id <- ids[[index]]
    edition_row <- edition_rows[[index]]
    if (!is.null(shared_failure)) {
      candidate <- phase14_state_bundle_empty_candidate(
        id,
        lifecycle_state = phase14_state_bundle_scalar_text(edition_row, "lifecycle_state", "scheduled"),
        reason = shared_failure,
        shared_input_audit = shared_audit,
        resolved_release = preflight$resolved_release,
        edition_row = edition_row
      )
      candidate$failure_scope <- "shared"
      candidate$state_status <- "invalid"
      candidate$forecast_status_table <- candidate$forecast$fixture_status
      candidate$model_form <- phase14_state_bundle_named_empty()
      candidate$forecast$forecast_top10 <- phase14_state_bundle_named_empty()
      candidate$forecast$local_score_distributions <- candidate$forecast$score_distributions
      return(phase14_state_bundle_attach_manifest(candidate, generated_at_utc))
    }
    local_audit <- shared_audit
    local_audit$fan_out <- 0L
    local_rows <- phase14_state_bundle_match_rows(canonical_matches, id, length(ids))
    candidate <- tryCatch(
      phase14_state_bundle_candidate_production(
        id, edition_row, local_rows, team_registry, preflight$resolved_release,
        selector_path, trusted_release_root, elo_ratings, national_team_xg_registry,
        national_team_xg_history, model_manifest, model_manifest_path, results,
        groups, standings, competition_form, all_senior_form, historical_matches,
        local_audit, generated_at_utc
      ),
      error = function(error) phase14_state_bundle_local_failure(
        id, edition_row, "edition_local_build_failed", conditionMessage(error),
        local_audit, preflight$resolved_release
      )
    )
    phase14_state_bundle_attach_manifest(candidate, generated_at_utc)
  })
  names(candidates) <- ids
  batch_manifest <- do.call(rbind, lapply(candidates, function(candidate) {
    data.frame(
      edition_id = as.character(candidate$edition_id),
      candidate_status = as.character(candidate$candidate_status),
      lifecycle_state = as.character(candidate$lifecycle_state),
      failure_scope = phase14_state_bundle_text(candidate$failure_scope, ""),
      failure_reason = phase14_state_bundle_text(candidate$failure_reason, ""),
      state_manifest_sha256 = as.character(candidate$state_manifest_sha256),
      canonical_matches_sha256 = phase14_state_bundle_hash_value(candidate$state_artifacts[["state/canonical_matches.csv"]]),
      forecast_status_rows = phase14_state_bundle_value_rows(candidate$state_artifacts[["state/forecast_status.csv"]]),
      forecast_rows = phase14_state_bundle_value_rows(candidate$state_artifacts[["state/forecasts.csv"]]),
      score_grid_rows = phase14_state_bundle_value_rows(candidate$state_artifacts[["local/score_distributions.rds"]]),
      top10_rows = phase14_state_bundle_value_rows(candidate$state_artifacts[["state/forecast_top10.csv"]]),
      model_data_cutoff = phase14_state_bundle_text(preflight$resolved_release$model_data_cutoff, ""),
      active_predictors = phase14_state_bundle_predictor_text(shared_audit$active_predictors),
      dropped_predictors_with_reason = phase14_state_bundle_predictor_text(shared_audit$dropped_predictors_with_reason),
      generated_at_utc = phase14_state_bundle_text(generated_at_utc, phase14_forecast_text(candidate$forecast$generated_at_utc, "")),
      validation_status = if (identical(candidate$candidate_status, "valid")) "valid" else "invalid",
      batch_sha256 = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }))
  rownames(batch_manifest) <- NULL
  batch_sha256 <- phase14_state_bundle_hash_value(batch_manifest)
  batch_manifest$batch_sha256 <- batch_sha256
  batch <- list(
    edition_ids = ids,
    candidates = candidates,
    shared_input_audit = shared_audit,
    resolved_release = preflight$resolved_release,
    batch_manifest = batch_manifest,
    batch_sha256 = batch_sha256,
    generated_at_utc = phase14_state_bundle_text(generated_at_utc, "")
  )
  phase14_validate_competition_state_bundle(batch)
  batch
}

# Public single-edition and vector entry points now share the production batch
# boundary.  The vector form intentionally returns the batch envelope; the
# single form returns its one candidate to preserve the established API.
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
    generated_at_utc = NULL,
    ...) {
  ids <- as.character(edition_id)
  batch <- phase14_build_competition_state_batch(
    edition_id = ids,
    edition_registry = edition_registry,
    canonical_matches = canonical_matches,
    team_registry = team_registry,
    resolved_release = resolved_release,
    selector_path = selector_path,
    trusted_release_root = trusted_release_root,
    elo_ratings = elo_ratings,
    national_team_xg_registry = national_team_xg_registry,
    national_team_xg_history = national_team_xg_history,
    model_manifest = model_manifest,
    model_manifest_path = model_manifest_path,
    results = results,
    groups = groups,
    standings = standings,
    competition_form = competition_form,
    all_senior_form = all_senior_form,
    historical_matches = historical_matches,
    generated_at_utc = generated_at_utc,
    ...
  )
  if (length(ids) > 1L) batch else batch$candidates[[ids[[1L]]]]
}

phase14_build_competition_state_candidates <- phase14_build_competition_state_candidate
