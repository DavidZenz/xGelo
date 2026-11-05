# Production integration is separate from the fixture-only outcome writer.
# All public entry points resolve fixed source/model parents; no caller-selected
# graph, model, selector or output root can establish publication authority.
.ucl_live_ledger_authority <- local(list(token = new.env(parent = emptyenv())))

.ucl_live_fixed_current <- function() {
  root <- .ucl_out_project_root()
  phase18_read_ucl_refresh_current(file.path(root, "data/competition/accepted"), file.path(root, "data/competition/registries"))
}

.ucl_live_ledger_blocked <- function(reason) list(status = "blocked", reason_code = reason,
  production_eligible = FALSE, fixture_authority = FALSE, authority_mode = "production")

# Pure mechanics seam: its return value has no production token/authority.
.ucl_live_to_simulation_ledger <- function(bridge, forecasts) {
  if (!identical(bridge$graph_validation$status, "ready")) return(.ucl_live_ledger_blocked("accepted_schedule_not_ready"))
  if (!identical(bridge$readiness$source_freshness, "fresh")) return(.ucl_live_ledger_blocked("stale_current_source"))
  if (bridge$readiness$result_pending_count > 0L) return(.ucl_live_ledger_blocked("past_kickoff_results_pending"))
  table <- bridge$ledger
  graph <- bridge$graph
  completed <- .ucl_sim_status_completed(graph$fixtures$match_status)
  open_ids <- as.character(graph$fixtures$fixture_id[!completed])
  available <- table$forecast_status == "available"
  if (!setequal(as.character(table$fixture_id[available]), open_ids)) return(.ucl_live_ledger_blocked("future_forecast_coverage_incomplete"))
  if (any(!is.na(table$prob_home[table$fixture_id %in% graph$fixtures$fixture_id[completed]])))
    return(.ucl_live_ledger_blocked("retrospective_forecasts_forbidden"))
  table$score_grid <- rep(list(NULL), nrow(table))
  views <- list()
  for (i in which(available)) {
    fixture_id <- as.character(table$fixture_id[[i]])
    prediction <- forecasts$predictions[as.character(forecasts$predictions$fixture_id) == fixture_id, , drop = FALSE]
    if (nrow(prediction) != 1L) return(.ucl_live_ledger_blocked("supported_live_forecast_missing"))
    raw <- forecasts$score_distributions[as.character(forecasts$score_distributions$fixture_id) == fixture_id, , drop = FALSE]
    joint <- ucl_tournament_score_view(raw, as.numeric(table[i, c("prob_home", "prob_draw", "prob_away")]), fixture_id,
      prediction$model_release_id[[1L]], prediction$probability_view[[1L]], prediction$score_distribution_sha256[[1L]])
    table$score_grid[[i]] <- joint$grid
    views[[length(views) + 1L]] <- joint$provenance
  }
  table <- table[match(as.character(graph$fixtures$fixture_id), as.character(table$fixture_id)), , drop = FALSE]
  table$row_sha256 <- vapply(seq_len(nrow(table)), function(i)
    .ucl_sim_canonical_row_hash(table[i, , drop = FALSE], schema_tag = "ucl20-forecast-ledger-row-v1"), character(1))
  lineage <- bridge$model_lineage
  if (is.null(lineage)) return(.ucl_live_ledger_blocked("approved_model_lineage_missing"))
  ledger <- c(list(status = "ready", ledger = table, forecast_rows = table,
    graph_sha256 = .ucl_sim_graph_content_hash(graph), source_bundle_id = graph$source_bundle_id,
    source_bundle_sha256 = bridge$source_bundle_sha256, state_cutoff_utc = bridge$information_cutoff_utc,
    information_cutoff_utc = bridge$information_cutoff_utc, canonical_hash_version = "phase18-canonical-v2",
    table_sha256 = .ucl_sim_canonical_table_hash(table, key = "fixture_id", schema_tag = "ucl20-forecast-ledger-v1"),
    joint_score_views = if (length(views)) do.call(rbind, views) else data.frame(fixture_id = character()),
    fixture_authority = TRUE, production_eligible = FALSE, authority_mode = "fixture"), lineage)
  class(ledger) <- c("ucl_forecast_ledger", "list")
  check <- .ucl_sim_validate_ledger(ledger, graph, bridge$information_cutoff_utc)
  if (!isTRUE(check$valid)) return(.ucl_live_ledger_blocked(check$reason))
  ledger
}

ucl_live_build_simulation_ledger <- function(current, forecasts, now_utc, future_context = NULL) {
  fixed <- .ucl_live_fixed_current()
  if (!identical(as.character(current$accepted$bundle$bundle_sha256), as.character(fixed$accepted$bundle$bundle_sha256)))
    return(.ucl_live_ledger_blocked("source_parent_changed"))
  bridge <- ucl_live_build_bridge(fixed, forecasts, now_utc, allow_venue_baseline = FALSE)
  settled_only <- all(.ucl_sim_status_completed(bridge$fixtures$match_status))
  if (settled_only && exists("ucl_future_context_is_production", mode = "function") && ucl_future_context_is_production(future_context) &&
      identical(future_context$source_bundle_sha256, bridge$source_bundle_sha256) && identical(future_context$information_cutoff_utc, now_utc)) {
    bridge$model_lineage <- future_context[c("model_release_id", "model_sha256", "calibrator_sha256", "primary_probability_view")]
    forecasts <- list(predictions = data.frame(), score_distributions = data.frame())
  } else if (!identical(bridge$readiness$forecast_quality, "approved_team_strength_model"))
    return(.ucl_live_ledger_blocked(if (identical(bridge$readiness$forecast_quality, "venue_baseline_only")) "team_strength_model_not_promoted" else "approved_live_forecasts_unavailable"))
  ledger <- .ucl_live_to_simulation_ledger(bridge, forecasts)
  if (!inherits(ledger, "ucl_forecast_ledger")) return(ledger)
  ledger$fixture_authority <- FALSE
  ledger$production_eligible <- TRUE
  ledger$authority_mode <- "production"
  ledger$selector_authorized <- TRUE
  ledger$authority <- list(status = "production_ready", original_parent_reason = NA_character_,
    production_blocked_reason = NA_character_, normalization_error = FALSE)
  ledger$.authority_token <- .ucl_live_ledger_authority$token
  ledger$.authority_binding <- list(table_sha256 = ledger$table_sha256, graph_sha256 = ledger$graph_sha256,
    source_bundle_sha256 = ledger$source_bundle_sha256, model_release_id = ledger$model_release_id,
    model_sha256 = ledger$model_sha256, calibrator_sha256 = ledger$calibrator_sha256,
    joint_score_views_sha256 = phase18_hash_table_v2(ledger$joint_score_views, "fixture_id", schema_tag = "ucl-joint-view-ledger-v1"),
    information_cutoff_utc = now_utc)
  class(ledger) <- c("ucl_verified_live_ledger", class(ledger))
  ledger
}

.ucl_live_verify_simulation_ledger <- function(ledger, graph) {
  if (!inherits(ledger, "ucl_verified_live_ledger") || !identical(ledger$.authority_token, .ucl_live_ledger_authority$token) ||
      isTRUE(ledger$fixture_authority) || !identical(ledger$authority_mode, "production")) return(FALSE)
  check <- .ucl_sim_validate_ledger(ledger, graph, ledger$information_cutoff_utc)
  if (!isTRUE(check$valid)) return(FALSE)
  binding <- list(table_sha256 = ledger$table_sha256, graph_sha256 = ledger$graph_sha256,
    source_bundle_sha256 = ledger$source_bundle_sha256, model_release_id = ledger$model_release_id,
    model_sha256 = ledger$model_sha256, calibrator_sha256 = ledger$calibrator_sha256,
    joint_score_views_sha256 = phase18_hash_table_v2(ledger$joint_score_views, "fixture_id", schema_tag = "ucl-joint-view-ledger-v1"),
    information_cutoff_utc = ledger$information_cutoff_utc)
  identical(binding, ledger$.authority_binding)
}

.ucl_live_joint_policy_approved <- function() {
  exists("ucl_future_policy_status", mode = "function") && identical(ucl_future_policy_status()$status, "approved")
}

.ucl_live_full_simulation_authority <- function(ledger, graph, rules, simulation) {
  if (!.ucl_live_verify_simulation_ledger(ledger, graph) || !.ucl_live_joint_policy_approved() ||
      !identical(simulation$status, "ready")) return(FALSE)
  future <- exists("ucl_future_verify_projection", mode = "function") && ucl_future_verify_projection(simulation$future_projection, ledger)
  if (!future) {
    if (!identical(simulation$metadata$draw_authority_mode, "production")) return(FALSE)
    draw <- ucl_validate_draw_artifact(simulation$draw_artifact, rules, graph$source_bundle_id, authority_mode = "production")
    if (!identical(draw$status, "accepted")) return(FALSE)
  }
  p <- simulation$progression_probabilities
  required <- c("direct_round_of_16", "knockout_play_off", "eliminated", "round_of_16", "quarter_final", "semi_final", "final", "champion")
  if (!is.data.frame(p) || nrow(p) != 36L * length(required) || !setequal(p$stage_id, required) ||
      any(p$status != "resolved") || any(!is.finite(p$probability))) return(FALSE)
  if (!is.data.frame(ledger$joint_score_views) || (!nrow(ledger$joint_score_views) && !future) ||
      any(ledger$joint_score_views$max_1x2_error > 1e-12) || any(ledger$joint_score_views$max_conditional_error > 1e-12)) return(FALSE)
  all(vapply(simulation$fixture_sampling, function(x) is.list(x) && !length(x$suppressed_fixture_ids), logical(1)))
}

ucl_live_monte_carlo_uncertainty <- function(progression) {
  if (!is.data.frame(progression) || !all(c("club_id", "stage_id", "probability", "simulation_count") %in% names(progression)))
    stop("CL Monte Carlo uncertainty requires progression counts and probabilities", call. = FALSE)
  n <- as.numeric(progression$simulation_count); p <- as.numeric(progression$probability)
  valid <- is.finite(p) & p >= 0 & p <= 1 & is.finite(n) & n > 0 & n == floor(n)
  if (any(is.finite(p) & !valid)) stop("Invalid CL Monte Carlo probability/count", call. = FALSE)
  if (any(valid & abs(p * n - round(p * n)) > 1e-7)) stop("CL probabilities are not empirical simulation frequencies", call. = FALSE)
  z <- 1.959963984540054
  denominator <- 1 + z^2 / n
  centre <- (p + z^2 / (2*n)) / denominator
  radius <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / denominator
  data.frame(club_id = as.character(progression$club_id), stage_id = as.character(progression$stage_id),
    probability = p, simulation_count = n, monte_carlo_se = ifelse(valid, sqrt(p*(1-p)/n), NA_real_),
    mc95_lower = ifelse(valid, pmax(0, centre-radius), NA_real_), mc95_upper = ifelse(valid, pmin(1, centre+radius), NA_real_),
    interval_method = "wilson_95_independent_simulation_draws", uncertainty_scope = "monte_carlo_only_not_model_uncertainty", stringsAsFactors = FALSE)
}

.ucl_live_publication_binding <- function(hashes, ledger, cutoff) {
  values <- c(hashes, ledger_table_sha256 = ledger$table_sha256, source_bundle_sha256 = ledger$source_bundle_sha256,
    model_release_id = ledger$model_release_id, information_cutoff_utc = cutoff)
  phase18_hash_sequence_v2(as.list(as.character(values)), "ucl-live-publication-binding-v1",
    names = names(values), types = rep("character", length(values)))
}

.ucl_live_extra_bindings <- function(hashes, result) c(hashes,
  joint_score_views = .ucl_out_artifact_hash(result$joint_score_views),
  monte_carlo_uncertainty = .ucl_out_artifact_hash(result$monte_carlo_uncertainty),
  future_knockout_events = .ucl_out_artifact_hash(result$future_knockout_events),
  future_matchup_provenance = .ucl_out_artifact_hash(result$future_matchup_provenance),
  league_rank_inputs=.ucl_out_artifact_hash(result$league_rank_inputs),
  late_tie_prior_samples=.ucl_out_artifact_hash(result$late_tie_prior_samples),
  late_tie_prior_contribution=.ucl_out_artifact_hash(result$late_tie_prior_contribution),
  forecast_scope = result$forecast_scope)

.ucl_live_result <- function(reason = NULL, cutoff = NA_character_, candidate = NULL, ledger = NULL, simulation = NULL) {
  ready <- is.null(reason) && is.list(candidate) && isTRUE(candidate$valid) && isTRUE(candidate$production_eligible)
  result <- list(schema_version = "ucl-live-production-result-v1", status = if (ready) "production_ready" else
    if (!is.null(candidate) && identical(candidate$status, "unresolved_draw_procedure")) "unresolved_draw_procedure" else "production_blocked",
    exit_code = 0L, mechanics_complete = is.list(candidate) && isTRUE(candidate$valid), production_eligible = ready,
    production_blocked_reason = if (is.null(reason)) NA_character_ else as.character(reason),
    blocked_reason_codes = if (is.null(reason)) character() else as.character(reason),
    human_needed = FALSE, normalization_error = FALSE, selector_changed = FALSE, incumbent_changed = FALSE,
    information_cutoff_utc = cutoff, failures = character(), warnings = character(), skips = character(), unexpected_failures = character(),
    artifact_hashes = if (is.null(candidate)) character() else candidate$artifact_hashes,
    artifacts = if (is.null(candidate)) list() else candidate$artifacts,
    joint_score_views = if (is.null(ledger)) data.frame() else ledger$joint_score_views,
    monte_carlo_uncertainty = if (is.null(simulation)) data.frame() else ucl_live_monte_carlo_uncertainty(simulation$progression_probabilities))
  result$forecast_scope <- if (!is.null(simulation$future_projection)) "unconditioned_regulations_prior" else "official_draw_conditioned"
  extra <- if (!is.null(simulation$future_projection)) ucl_future_projection_artifacts(simulation$future_projection) else
    list(events=data.frame(stage_event_id=character()),provenance=data.frame(fixture_id=character()),
      league_rank_inputs=data.frame(),late_tie_prior_samples=data.frame(),late_tie_prior_contribution=data.frame())
  result$future_knockout_events <- extra$events
  result$future_matchup_provenance <- extra$provenance
  result$league_rank_inputs <- extra$league_rank_inputs
  result$late_tie_prior_samples <- extra$late_tie_prior_samples
  result$late_tie_prior_contribution <- extra$late_tie_prior_contribution
  if (ready) {
    result$.authority_token <- .ucl_live_ledger_authority$token
    result$.candidate <- candidate; result$.ledger <- ledger; result$.simulation <- simulation
    hashes <- .ucl_live_extra_bindings(candidate$artifact_hashes, result)
    result$.binding_sha256 <- .ucl_live_publication_binding(hashes, ledger, cutoff)
  }
  result
}

ucl_live_validate_result <- function(result) {
  if (!is.list(result) || !identical(result$schema_version, "ucl-live-production-result-v1") ||
      !result$status %in% c("production_ready", "production_blocked", "unresolved_draw_procedure") ||
      !identical(result$exit_code, 0L) || length(result$failures) || isTRUE(result$selector_changed) || isTRUE(result$incumbent_changed)) return(FALSE)
  if (length(result$artifact_hashes)) {
    actual <- vapply(result$artifacts, .ucl_out_artifact_hash, character(1))
    if (!identical(result$artifact_hashes, actual)) return(FALSE)
  }
  if (!isTRUE(result$production_eligible)) return(!identical(result$status, "production_ready") &&
    (length(result$blocked_reason_codes) > 0L))
  if (!identical(result$.authority_token, .ucl_live_ledger_authority$token) || !identical(result$status, "production_ready")) return(FALSE)
  candidate <- result$.candidate; ledger <- result$.ledger; simulation <- result$.simulation
  if (!isTRUE(candidate$valid) || !isTRUE(candidate$production_eligible) ||
      !.ucl_live_full_simulation_authority(ledger, simulation$graph, simulation$metadata$rules %||% .ucl_rule_contract(), simulation)) return(FALSE)
  hashes <- .ucl_live_extra_bindings(result$artifact_hashes, result)
  binding <- .ucl_live_publication_binding(hashes, ledger, result$information_cutoff_utc)
  identical(binding, result$.binding_sha256)
}

ucl20_build_live_outcomes <- function(simulations = 1000L, seed = 20260921L, information_cutoff_utc = NULL, write = FALSE) {
  cutoff <- .ucl_out_validate_cutoff(information_cutoff_utc)
  if (!isTRUE(cutoff$valid)) return(.ucl_live_result(cutoff$reason))
  if (length(simulations) != 1L || !is.finite(simulations) || simulations < 1 || simulations != floor(simulations) ||
      length(seed) != 1L || !is.finite(seed) || seed < 0 || seed != floor(seed)) return(.ucl_live_result("simulation_controls_invalid", cutoff$value))
  current <- tryCatch(.ucl_live_fixed_current(), error = function(e) NULL)
  if (is.null(current)) return(.ucl_live_result("no_accepted_current_ucl", cutoff$value))
  bridge <- tryCatch(ucl_live_build_bridge(current, now_utc = cutoff$value), error = function(e) NULL)
  if (is.null(bridge) || !identical(bridge$graph_validation$status, "ready")) return(.ucl_live_result("accepted_schedule_not_ready", cutoff$value))
  if (!identical(bridge$readiness$source_freshness, "fresh")) return(.ucl_live_result("stale_current_source", cutoff$value))
  release <- tryCatch(phase19_resolve_production_club_release(), error = function(e) e)
  if (inherits(release, "error")) return(.ucl_live_result(if (!is.null(release$reason_code)) release$reason_code else "approved_release_unavailable", cutoff$value))
  if (!identical(as.character(release$model_contract$selected_model_id), "club_elo_nb"))
    return(.ucl_live_result("team_strength_model_not_promoted", cutoff$value))
  if (!.ucl_live_joint_policy_approved()) return(.ucl_live_result("tournament_joint_view_review_pending", cutoff$value))
  future_context <- ucl_future_production_context(cutoff$value)
  if (!inherits(future_context, "ucl_future_matchup_context")) return(.ucl_live_result(future_context$reason_code, cutoff$value))
  settled_only <- all(.ucl_sim_status_completed(bridge$fixtures$match_status))
  forecasts <- if (settled_only) NULL else phase19_forecast_current_ucl(cutoff$value)
  if (!settled_only && !identical(forecasts$status, "available")) return(.ucl_live_result(forecasts$reason_code, cutoff$value))
  ledger <- ucl_live_build_simulation_ledger(current, forecasts, cutoff$value, future_context)
  if (!inherits(ledger, "ucl_verified_live_ledger")) return(.ucl_live_result(ledger$reason_code, cutoff$value))
  rules <- .ucl_rule_contract()
  state <- ucl_build_state(bridge$graph, rules = rules, state_cutoff_utc = cutoff$value)
  if (!identical(state$status, "ready")) return(.ucl_live_result(state$reason_code, cutoff$value))
  raw_draw <- current$accepted$draw_artifact
  draw <- .ucl_resolve_trusted_draw_artifact(raw_draw, rules, state$graph$source_bundle_id)
  simulation <- ucl_run_simulation(state, ledger, simulations, seed, rules, draw,
    information_cutoff_utc = cutoff$value, draw_authority_mode = "production", future_context = future_context)
  if (identical(simulation$status, "blocked")) return(.ucl_live_result(simulation$reason, cutoff$value))
  candidate <- ucl_validate_outcome_candidate(list(state = state, ledger = ledger, simulation = simulation), rules, cutoff$value)
  reason <- if (!isTRUE(candidate$valid)) candidate$failures else if (!isTRUE(candidate$production_eligible)) {
    unique(c(candidate$unresolved, as.character(simulation$progression_probabilities$unresolved_reason)))
  } else NULL
  reason <- reason[!is.na(reason) & nzchar(reason)]
  if (!length(reason) && !isTRUE(candidate$production_eligible)) reason <- "full_tournament_authority_incomplete"
  result <- .ucl_live_result(if (length(reason)) reason else NULL, cutoff$value, candidate, ledger, simulation)
  if (isTRUE(write)) result <- .ucl_live_publish_result(result)
  result
}

.ucl_live_write_tables <- function(tables, directory) {
  files <- lapply(names(tables), function(name) {
    table <- tables[[name]]
    if (!is.data.frame(table) || !grepl("^[a-z_]+$", name)) stop("Invalid CL publication table", call. = FALSE)
    path <- file.path(directory, paste0(name, ".csv"))
    phase18_ucl_write_csv(table, path)
    types <- phase18_ucl_column_types_json(table)
    nulls <- phase18_ucl_null_rows_json(table)
    restored <- phase18_ucl_read_typed_csv(path, types, nulls)
    if (!identical(.ucl_out_artifact_hash(table), .ucl_out_artifact_hash(restored))) stop("CL publication CSV read-back differs", call. = FALSE)
    list(path = basename(path), sha256 = digest::digest(file = path, algo = "sha256"),
      canonical_sha256 = .ucl_out_artifact_hash(table), rows = nrow(table), column_types_json = types, null_rows_json = nulls)
  })
  names(files) <- names(tables)
  files
}

.ucl_live_publish_result <- function(result) {
  if (!ucl_live_validate_result(result) || !isTRUE(result$production_eligible)) {
    result$production_eligible <- FALSE
    if (identical(result$status, "production_ready")) result$status <- "production_blocked"
    result$blocked_reason_codes <- unique(c(result$blocked_reason_codes, "production_writer_not_authorized"))
    result$production_blocked_reason <- paste(result$blocked_reason_codes, collapse = ";")
    return(result)
  }
  root <- file.path(.ucl_out_project_root(), "outputs/competition/ucl_2026_27")
  linked <- function(path) { value <- Sys.readlink(path); length(value) == 1L && !is.na(value) && nzchar(value) }
  if (linked(root) || linked(file.path(root, "outcome_generations"))) stop("CL output roots must not be symlinks", call. = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  lock <- file.path(root, ".live-outcomes.lock")
  if (!dir.create(lock, showWarnings = FALSE)) stop("CL production publication is already locked", call. = FALSE)
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  generations <- file.path(root, "outcome_generations")
  dir.create(generations, showWarnings = FALSE)
  stage <- tempfile(".ucl-live-stage-", tmpdir = generations)
  dir.create(stage)
  on.exit(if (dir.exists(stage)) unlink(stage, recursive = TRUE), add = TRUE)
  tables <- c(result$artifacts, list(joint_score_views = result$joint_score_views, monte_carlo_uncertainty = result$monte_carlo_uncertainty,
    future_knockout_events=result$future_knockout_events,future_matchup_provenance=result$future_matchup_provenance,
    league_rank_inputs=result$league_rank_inputs,late_tie_prior_samples=result$late_tie_prior_samples,late_tie_prior_contribution=result$late_tie_prior_contribution))
  files <- .ucl_live_write_tables(tables, stage)
  ledger <- result$.ledger
  manifest <- list(schema_version = "ucl-live-production-publication-v1", edition_id = "ucl_2026_27",
    simulation_run_id = result$.simulation$run_id, source_bundle_sha256 = ledger$source_bundle_sha256,
    model_release_id = ledger$model_release_id, model_sha256 = ledger$model_sha256,
    calibrator_sha256 = ledger$calibrator_sha256, information_cutoff_utc = result$information_cutoff_utc,
    sampler_view = "ucl-outcome-conditional-nb-v1", forecast_scope = result$forecast_scope,
    assumptions_policy_id = "ucl-conditional-tournament-forecast-v1", assumptions_policy_sha256 = result$.simulation$metadata$future_policy_sha256,
    model_uncertainty_included = FALSE, production_eligible = TRUE, files = files)
  manifest_path <- file.path(stage, "publication_manifest.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, null = "null", pretty = TRUE)
  manifest_sha <- digest::digest(file = manifest_path, algo = "sha256")
  generation <- paste0("ucl-live-", substr(manifest_sha, 1L, 24L))
  destination <- file.path(generations, generation)
  # Re-read both independent parents before installing or selecting anything.
  fresh <- .ucl_live_fixed_current()
  release <- phase19_resolve_production_club_release()
  if (!identical(as.character(fresh$accepted$bundle$bundle_sha256), ledger$source_bundle_sha256) ||
      !identical(as.character(release$model_contract$release_id), ledger$model_release_id) ||
      !ucl_live_validate_result(result)) stop("CL parents changed before atomic publication", call. = FALSE)
  if (dir.exists(destination)) {
    existing <- file.path(destination, "publication_manifest.json")
    if (!file.exists(existing) || !identical(digest::digest(file = existing, algo = "sha256"), manifest_sha))
      stop("CL immutable generation collision", call. = FALSE)
    for (file in files) if (!file.exists(file.path(destination, file$path)) ||
        !identical(digest::digest(file = file.path(destination, file$path), algo = "sha256"), file$sha256))
      stop("CL immutable generation bytes differ", call. = FALSE)
  } else if (!file.rename(stage, destination)) stop("Could not atomically install CL generation", call. = FALSE)
  pointer <- list(schema_version = "ucl-live-outcomes-current-v1", edition_id = "ucl_2026_27", generation = generation,
    publication_manifest_sha256 = manifest_sha, simulation_run_id = result$.simulation$run_id,
    source_bundle_sha256 = ledger$source_bundle_sha256, model_release_id = ledger$model_release_id,
    information_cutoff_utc = result$information_cutoff_utc)
  pointer_path <- file.path(root, "outcomes_current.json")
  before <- if (file.exists(pointer_path)) digest::digest(file = pointer_path, algo = "sha256") else NA_character_
  pending <- tempfile(".ucl-live-pointer-", tmpdir = root)
  on.exit(if (file.exists(pending)) unlink(pending), add = TRUE)
  jsonlite::write_json(pointer, pending, auto_unbox = TRUE, pretty = TRUE)
  if (!file.rename(pending, pointer_path)) stop("Could not atomically select CL outcome generation", call. = FALSE)
  if (!identical(jsonlite::read_json(pointer_path, simplifyVector = TRUE), pointer)) stop("CL outcome pointer read-back differs", call. = FALSE)
  result$publication <- pointer
  result$outcomes_pointer_changed <- !identical(before, digest::digest(file = pointer_path, algo = "sha256"))
  result
}
