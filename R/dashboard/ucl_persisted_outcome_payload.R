# Presentation only. Production inputs always come from the fixed persisted
# reader; neither payload metadata nor a caller-prepared receipt grants access.
.phase21_cl_payload_root <- local({
  found <- character()
  for (frame in rev(sys.frames())) for (field in c("ofile", "file")) {
    if (!base::exists(field, frame, inherits = FALSE)) next
    path <- get(field, frame, inherits = FALSE)
    if (!is.character(path) || length(path) != 1L || is.na(path) ||
        basename(path) != "ucl_persisted_outcome_payload.R") next
    if (!grepl("^/", path) && base::exists("owd", frame, inherits = FALSE))
      found <- c(found, file.path(get("owd", frame, inherits = FALSE), path))
    found <- c(found, path)
  }
  found <- found[file.exists(found)]
  if (!length(found)) stop("Cannot locate the fixed CL payload module", call. = FALSE)
  path <- normalizePath(found[[1L]], winslash = "/", mustWork = TRUE)
  root <- normalizePath(file.path(dirname(path), "../.."), winslash = "/", mustWork = TRUE)
  if (!identical(path, file.path(root, "R/dashboard/ucl_persisted_outcome_payload.R")))
    stop("Invalid fixed CL payload module location", call. = FALSE)
  root
})
.phase21_cl_facade_cache <- new.env(parent = emptyenv())
.phase21_cl_facade <- function() {
  path <- file.path(.phase21_cl_payload_root, "R/competition/ucl_production_runtime.R")
  if (!file.exists(path) || nzchar(Sys.readlink(path))) stop("Fixed CL runtime unavailable", call. = FALSE)
  hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
  if (!base::exists("namespace", .phase21_cl_facade_cache, inherits = FALSE) ||
      !identical(.phase21_cl_facade_cache$hash, hash)) {
    namespace <- new.env(parent = baseenv()); sys.source(path, namespace)
    .phase21_cl_facade_cache$namespace <- namespace; .phase21_cl_facade_cache$hash <- hash
  }
  .phase21_cl_facade_cache$namespace
}
.phase21_cl_tournament_sections <- function()
  c("structure", "rank_distributions", "qualification_bands", "knockout_paths", "progression_probabilities", "projected_outcomes")
.phase21_cl_percent <- function(x) paste0(ifelse(x == 0, "0", trimws(formatC(100*x, format = "fg", digits = 3))), "%")
.phase21_cl_stage_labels <- function() c(direct_round_of_16 = "Direct round of 16", knockout_play_off = "Knockout play-off",
  eliminated = "Eliminated after league phase", round_of_16 = "Round of 16", quarter_final = "Quarter-final",
  semi_final = "Semi-final", final = "Final", champion = "Winner")
.phase21_cl_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# Pure presentation seam. The fixed reader separately authenticates the ledger.
.phase21_cl_format_match_rows <- function(ledger, clubs, generated_at_utc) {
  fields <- c("fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "forecast_status",
    "prob_home", "prob_draw", "prob_away", "xg_home", "xg_away", "likely_score")
  if (!is.data.frame(ledger) || !all(fields %in% names(ledger)) || anyNA(ledger$forecast_status) ||
      !is.character(generated_at_utc) || length(generated_at_utc) != 1L || is.na(generated_at_utc) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", generated_at_utc))
    stop("CL match presentation requires a complete ledger and UTC page time", call. = FALSE)
  x <- ledger[ledger$forecast_status == "available", fields, drop = FALSE]
  if (anyNA(x) || anyDuplicated(x$fixture_id) ||
      any(!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", x$kickoff_utc)))
    stop("CL match presentation has incomplete identities or values", call. = FALSE)
  x <- x[x$kickoff_utc > generated_at_utc, , drop = FALSE]
  x <- x[order(x$kickoff_utc, x$fixture_id), , drop = FALSE]
  labels <- stats::setNames(as.character(clubs$display_name), as.character(clubs$club_id))
  if (any(!c(x$home_club_id, x$away_club_id) %in% names(labels)))
    stop("CL match presentation has unknown clubs", call. = FALSE)
  data.frame(`Kickoff (UTC)` = x$kickoff_utc,
    Home = unname(labels[x$home_club_id]), Away = unname(labels[x$away_club_id]),
    `Home win` = sprintf("%.1f%%", 100*x$prob_home), Draw = sprintf("%.1f%%", 100*x$prob_draw),
    `Away win` = sprintf("%.1f%%", 100*x$prob_away),
    `Expected home goals` = round(x$xg_home, 2), `Expected away goals` = round(x$xg_away, 2),
    `Most likely score` = gsub("-", "–", x$likely_score, fixed = TRUE),
    stringsAsFactors = FALSE, check.names = FALSE)
}

# Pure formatting/aggregation seam. It has no authority or publication flags.
.phase21_cl_format_tables <- function(tables, clubs) {
  ids <- sort(as.character(clubs$club_id), method = "radix")
  if (length(ids) != 36L || anyNA(ids) || anyDuplicated(ids) ||
      !all(c("club_id", "display_name") %in% names(clubs)) || anyNA(clubs$display_name))
    stop("CL presentation requires the complete club identity table", call. = FALSE)
  labels <- stats::setNames(as.character(clubs$display_name), as.character(clubs$club_id))
  ranks <- tables$league_rank_inputs; p <- tables$progression_probabilities; u <- tables$monte_carlo_uncertainty
  if (!is.numeric(p$simulation_count) || any(!is.finite(p$simulation_count) | p$simulation_count != floor(p$simulation_count)))
    stop("CL simulation count must be an exact integer", call. = FALSE)
  n <- unique(as.integer(p$simulation_count))
  if (length(n) != 1L || is.na(n) || n < 1L || nrow(ranks) != 36*n ||
      !setequal(ranks$club_id, ids) || any(!ranks$rank %in% 1:36)) stop("CL rank counts are incomplete", call. = FALSE)
  counts <- table(factor(ranks$club_id, levels = ids), factor(ranks$rank, levels = 1:36))
  if (any(rowSums(counts) != n) || any(colSums(counts) != n)) stop("CL rank counts do not reconcile", call. = FALSE)
  rank_counts <- data.frame(club_id = rep(ids, each = 36L), rank = rep(1:36, length(ids)),
    count = as.integer(as.vector(t(counts))), stringsAsFactors = FALSE)
  stages <- .phase21_cl_stage_labels()
  if (nrow(p) != 36L*length(stages) || !setequal(p$club_id, ids) || !setequal(p$stage_id, names(stages)) ||
      anyDuplicated(paste(p$club_id, p$stage_id)) || any(!is.finite(p$probability) | p$probability < 0 | p$probability > 1) ||
      any(abs(p$probability*n - round(p$probability*n)) > 1e-7)) stop("CL stage counts are incomplete", call. = FALSE)
  p <- p[order(match(p$stage_id, names(stages)), p$club_id), , drop = FALSE]
  keys <- paste(p$club_id, p$stage_id); at <- match(keys, paste(u$club_id, u$stage_id))
  if (nrow(u) != nrow(p) || anyNA(at) || anyDuplicated(paste(u$club_id, u$stage_id)) ||
      any(!is.finite(u$mc95_lower) | !is.finite(u$mc95_upper)) ||
      any(u$mc95_lower < 0 | u$mc95_upper > 1 | u$mc95_lower > u$mc95_upper)) stop("CL sampling intervals are incomplete", call. = FALSE)
  stage_counts <- data.frame(club_id = p$club_id, stage_id = p$stage_id, count = as.integer(round(p$probability*n)), stringsAsFactors = FALSE)
  progression <- data.frame(Club = unname(labels[p$club_id]), Outcome = unname(stages[p$stage_id]),
    Chance = .phase21_cl_percent(p$probability), `95% sampling interval` = paste0(.phase21_cl_percent(u$mc95_lower[at]), "–", .phase21_cl_percent(u$mc95_upper[at])),
    stringsAsFactors = FALSE, check.names = FALSE)
  path <- tables$knockout_paths
  path <- path[path$stage_id != "champion", , drop = FALSE]
  bracket <- data.frame(Round = unname(stages[path$stage_id]),
    `Club A` = unname(labels[path$participant_a]), `Club B` = unname(labels[path$participant_b]),
    Format = ifelse(path$leg_order == "single_neutral", "Single match at neutral venue", "Two legs"),
    stringsAsFactors = FALSE, check.names = FALSE)
  if (anyNA(bracket)) stop("CL illustrative bracket has unknown clubs or stages", call. = FALSE)
  rows <- list(structure = data.frame(Format = "36-club league phase; eight matches per club; legal knockout bracket", stringsAsFactors = FALSE),
    rank_distributions = data.frame(Club = unname(labels[rank_counts$club_id]), Position = rank_counts$rank,
      Chance = .phase21_cl_percent(rank_counts$count/n), stringsAsFactors = FALSE),
    qualification_bands = progression[p$stage_id %in% c("direct_round_of_16", "knockout_play_off", "eliminated"), , drop = FALSE],
    knockout_paths = bracket, progression_probabilities = progression,
    projected_outcomes = progression[p$stage_id == "champion", , drop = FALSE])
  list(rows = rows, counts = list(simulation_count = n, rank_counts = rank_counts, stage_counts = stage_counts))
}

.phase21_cl_context <- function(now_utc = NULL) {
  # A page/as-of argument never drives authority. Each potentially slow boundary
  # obtains its own real current clock through the fixed facade defaults.
  facade <- .phase21_cl_facade()
  read <- facade$ucl_read_production_outcomes()
  if (!identical(read$status, "available") || !isTRUE(read$production_eligible) ||
      !isTRUE(facade$ucl_validate_production_outcome_read_result(read)))
    return(list(status = "blocked", reason_code = if (is.null(read$reason_code)) "accepted_outcomes_unavailable" else read$reason_code))
  namespace <- facade$.ucl_runtime_load()
  current <- facade$.ucl_runtime_in_project(function() namespace$phase20_ucl_runtime$.ucl_live_fixed_current())
  if (!identical(as.character(current$accepted$bundle$bundle_sha256[[1L]]), read$publication$source_bundle_sha256))
    stop("CL presentation source changed during read", call. = FALSE)
  list(status = "available", receipt = read, clubs = current$accepted$tables$clubs)
}

.phase21_cl_projection_values <- function(context) {
  read <- context$receipt; table <- read$tables$simulation_metadata
  n <- as.integer(table$simulation_count[[1L]])
  if (is.na(n) || n < 9600L) return(list(status = "blocked", reason_code = "insufficient_monte_carlo_precision"))
  formatted <- .phase21_cl_format_tables(read$tables, context$clubs)
  prior <- read$tables$late_tie_prior_contribution
  prior_bound <- if (nrow(prior)) max(prior$all_stage_max_absolute_probability_change_bound) else 0
  if (!is.finite(prior_bound) || prior_bound < 0 || prior_bound > 1) stop("CL tie-break sensitivity bound is invalid", call. = FALSE)
  metadata <- list(tournament_status = "available", tournament_reason_code = "none", forecast_scope = "unconditioned_regulations_prior",
    projection_run_id = read$publication$simulation_run_id, simulation_seed = table$seed[[1L]], simulation_count = n,
    information_cutoff_utc = read$information_cutoff_utc,
    tournament_information_cutoff_utc = read$information_cutoff_utc,
    model_release_id = table$model_release_id[[1L]],
    model_sha256 = table$model_sha256[[1L]], calibrator_sha256 = table$calibrator_sha256[[1L]],
    ruleset_version = table$ruleset_version[[1L]], ruleset_sha256 = table$ruleset_sha256[[1L]],
    draw_artifact_sha256 = table$draw_artifact_sha256[[1L]],
    tournament_publication_sha256 = read$publication$publication_manifest_sha256,
    monte_carlo_coverage_scope = "95% pointwise sampling only; model and policy uncertainty excluded",
    late_tie_prior_probability_change_bound = prior_bound)
  reason <- "Possible legal brackets before the knockout draw. Sampling intervals exclude model and tie-break assumption uncertainty."
  if (prior_bound > 0) reason <- paste0(reason, " Late tie-break assumptions affect up to ", .phase21_cl_percent(prior_bound),
    " of simulations; this is a conservative sensitivity bound, not a confidence interval.")
  list(status = "available", metadata = metadata, rows = formatted$rows, counts = formatted$counts, reason = reason)
}

phase21_ucl_attach_persisted_outcomes <- function(payload, now_utc = NULL) {
  if (!identical(payload$edition_id, "ucl_2026_27")) stop("CL persisted adapter requires a CL facts payload", call. = FALSE)
  if (is.null(now_utc)) now_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  # Match inference and an earlier persisted tournament run can have different
  # cutoffs. Preserve the match cutoff even when tournament reads are blocked.
  match_cutoff <- if (length(payload$sections$match_forecasts$rows)) {
    prior <- payload$metadata$match_information_cutoff_utc
    if (is.character(prior) && length(prior) == 1L && !is.na(prior) && nzchar(prior)) prior else
      payload$metadata$information_cutoff_utc
  } else NA_character_
  values <- tryCatch({
    context <- .phase21_cl_context(now_utc)
    if (context$status != "available") context else {
      if (!identical(payload$metadata$source_bundle_sha256, context$receipt$publication$source_bundle_sha256))
        stop("CL payload and persisted outcomes use different accepted sources", call. = FALSE)
      metadata <- context$receipt$tables$simulation_metadata
      for (field in c("model_release_id", "model_sha256", "calibrator_sha256")) {
        current <- payload$metadata[[field]]
        if (length(current) == 1L && !is.na(current) && nzchar(as.character(current)) &&
            !identical(as.character(current), as.character(metadata[[field]][[1L]])))
          stop("CL match and tournament models differ", call. = FALSE)
      }
      .phase21_cl_projection_values(context)
    }
  }, error = function(error) list(status = "blocked", reason_code = "fixed_outcome_read_unavailable"))
  for (id in .phase21_cl_tournament_sections()) {
    section <- payload$sections[[id]]
    section$rows <- list(); section$status <- "unavailable"
    section$reason <- "Tournament forecasts await accepted model, rules and outcome readiness checks."
    payload$sections[[id]] <- section
  }
  payload$cl_tournament_evidence <- NULL
  for (field in c("tournament_publication_sha256", "projection_run_id", "simulation_seed", "simulation_count",
      "forecast_scope", "monte_carlo_coverage_scope", "late_tie_prior_probability_change_bound",
      "information_cutoff_utc", "tournament_information_cutoff_utc", "ruleset_version", "ruleset_sha256", "draw_artifact_sha256"))
    payload$metadata[[field]] <- NA_character_
  payload$metadata$match_information_cutoff_utc <- match_cutoff
  if (length(payload$sections$match_forecasts$rows)) {
    payload$metadata$information_cutoff_utc <- match_cutoff
    disclosure <- paste0("Match forecast information cutoff: ", match_cutoff, ".")
    if (!grepl(disclosure, payload$sections$match_forecasts$reason, fixed = TRUE))
      payload$sections$match_forecasts$reason <- paste(payload$sections$match_forecasts$reason, disclosure)
  }
  payload$metadata$tournament_status <- "unavailable"
  payload$metadata$tournament_reason_code <- values$reason_code
  if (values$status != "available") return(payload)
  for (id in .phase21_cl_tournament_sections()) {
    payload$sections[[id]]$rows <- phase21_rows(values$rows[[id]])
    payload$sections[[id]]$status <- "available"
    payload$sections[[id]]$reason <- if (id == "knockout_paths")
      "One sampled legal bracket for illustration. These pairings have not been drawn or scheduled." else values$reason
  }
  payload$sections$knockout_paths$label <- "Illustrative sampled bracket"
  for (name in names(values$metadata)) payload$metadata[[name]] <- values$metadata[[name]]
  warnings <- as.character(payload$metadata$warnings)
  warnings <- warnings[warnings != "Club match and tournament projections are unavailable until model and tournament readiness checks pass."]
  payload$metadata$warnings <- unique(c(warnings, values$reason))
  payload$metadata$production_eligible <- TRUE
  payload$sections$overview$reason <- "Accepted competition facts and validated tournament outlooks are available."
  payload$cl_tournament_evidence <- values$counts
  phase21_validate_payload(payload)
  payload
}

# Pure presentation merge after slow validation. It grants no authority: the
# resulting public claims still require the fixed publication validator below.
.phase21_cl_rebase_facts <- function(facts, presented) {
  if (!identical(facts$edition_id, "ucl_2026_27") || !identical(presented$edition_id, "ucl_2026_27") ||
      !identical(facts$metadata$source_bundle_sha256, presented$metadata$source_bundle_sha256))
    stop("CL factual refresh and outlook presentation have different sources", call. = FALSE)
  available <- identical(presented$metadata$tournament_status, "available")
  for (id in .phase21_cl_tournament_sections()) facts$sections[[id]] <- presented$sections[[id]]
  projection_fields <- c("tournament_status", "tournament_reason_code", "tournament_publication_sha256",
    "projection_run_id", "simulation_seed", "simulation_count", "forecast_scope", "monte_carlo_coverage_scope",
    "late_tie_prior_probability_change_bound", "tournament_information_cutoff_utc",
    "ruleset_version", "ruleset_sha256", "draw_artifact_sha256")
  for (field in projection_fields) facts$metadata[[field]] <- presented$metadata[[field]]
  if (available) {
    for (field in c("model_release_id", "model_sha256", "calibrator_sha256")) {
      value <- facts$metadata[[field]]
      if (length(value) == 1L && !is.na(value) && nzchar(as.character(value)) &&
          !identical(as.character(value), as.character(presented$metadata[[field]])))
        stop("CL refreshed facts and tournament models differ", call. = FALSE)
      facts$metadata[[field]] <- presented$metadata[[field]]
    }
    facts$metadata$information_cutoff_utc <- presented$metadata$tournament_information_cutoff_utc
    warnings <- as.character(facts$metadata$warnings)
    warnings <- warnings[warnings != "Club match and tournament projections are unavailable until model and tournament readiness checks pass."]
    facts$metadata$warnings <- unique(c(warnings, presented$sections$progression_probabilities$reason))
    facts$metadata$production_eligible <- isTRUE(facts$metadata$production_eligible) ||
      isTRUE(presented$metadata$production_eligible)
    facts$sections$overview$reason <- "Accepted competition facts and validated tournament outlooks are available."
    facts$cl_tournament_evidence <- presented$cl_tournament_evidence
  } else facts$cl_tournament_evidence <- NULL
  cutoff <- if (length(facts$sections$match_forecasts$rows))
    facts$metadata$forecast_provenance$information_cutoff_utc else NA_character_
  facts$metadata$match_information_cutoff_utc <- cutoff
  if (length(facts$sections$match_forecasts$rows)) {
    if (!available) facts$metadata$information_cutoff_utc <- cutoff
    disclosure <- paste0("Match forecast information cutoff: ", cutoff, ".")
    if (!grepl(disclosure, facts$sections$match_forecasts$reason, fixed = TRUE))
      facts$sections$match_forecasts$reason <- paste(facts$sections$match_forecasts$reason, disclosure)
  }
  phase21_validate_payload(facts)
  facts
}

# Publication re-resolves the fixed reader; no serialized receipt or public
# eligibility/hash flags can substitute for current genuine authority.
phase21_validate_ucl_persisted_outcome_payload <- function(payload, now_utc = NULL) {
  tryCatch({
    if (!identical(payload$edition_id, "ucl_2026_27")) return(FALSE)
    ids <- .phase21_cl_tournament_sections()
    claimed <- identical(payload$metadata$tournament_status, "available") ||
      any(vapply(payload$sections[ids], function(section)
        identical(section$status, "available") || length(section$rows) > 0L, logical(1))) ||
      !is.null(payload$cl_tournament_evidence)
    if (!claimed) return(TRUE)
    if (!isTRUE(payload$metadata$production_eligible)) return(FALSE)
    timestamp <- function(value) {
      if (!is.character(value) || length(value) != 1L || is.na(value) ||
          !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)) return(NA_real_)
      as.numeric(as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    }
    if (!is.null(now_utc)) {
      requested <- timestamp(now_utc)
      if (!is.finite(requested) || abs(requested - as.numeric(Sys.time())) > 60) return(FALSE)
    }
    context <- .phase21_cl_context()
    if (context$status != "available" ||
        !identical(payload$metadata$source_bundle_sha256, context$receipt$publication$source_bundle_sha256)) return(FALSE)
    generated <- timestamp(payload$metadata$generated_at_utc)
    now <- as.numeric(Sys.time()); cutoff <- timestamp(context$receipt$information_cutoff_utc)
    if (any(!is.finite(c(generated, now, cutoff))) || generated < cutoff ||
        generated > now + 300 || now - generated > 48*3600) return(FALSE)
    values <- .phase21_cl_projection_values(context)
    if (values$status != "available") return(FALSE)
    canonical <- function(value) as.character(jsonlite::toJSON(value, auto_unbox = TRUE,
      null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE))
    for (field in names(values$metadata))
      if (!identical(canonical(payload$metadata[[field]]), canonical(values$metadata[[field]]))) return(FALSE)
    for (id in ids) {
      section <- payload$sections[[id]]
      reason <- if (id == "knockout_paths")
        "One sampled legal bracket for illustration. These pairings have not been drawn or scheduled." else values$reason
      if (!identical(section$status, "available") || !identical(section$reason, reason) ||
          !identical(canonical(section$rows), canonical(phase21_rows(values$rows[[id]])))) return(FALSE)
    }
    if (length(payload$sections$match_forecasts$rows)) {
      expected_matches <- .phase21_cl_format_match_rows(context$receipt$tables$fixture_forecast_ledger,
        context$clubs, payload$metadata$generated_at_utc)
      if (!identical(canonical(payload$sections$match_forecasts$rows), canonical(phase21_rows(expected_matches)))) return(FALSE)
    }
    identical(canonical(payload$cl_tournament_evidence), canonical(values$counts))
  }, error = function(error) FALSE)
}
