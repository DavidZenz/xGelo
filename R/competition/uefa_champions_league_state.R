# Accepted UCL schedule, canonical state, and immutable forecast-ledger seam.

.ucl_state_blocked <- function(reason_code, message, graph = NULL, diagnostics = list()) {
  structure(
    list(
      status = "blocked", reason_code = as.character(reason_code),
      message = as.character(message), graph = graph,
      diagnostics = diagnostics, production_eligible = FALSE,
      fixture_authority = if (is.null(graph)) FALSE else isTRUE(graph$fixture_authority)
    ),
    class = c("ucl_blocked_state", "list")
  )
}

.ucl_state_root <- function() {
  candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
    candidate <- parent
  }
}

.ucl_state_phase18_canonical_available <- function() {
  if (exists("phase18_hash_table_v2", mode = "function", inherits = TRUE) &&
      exists("phase18_hash_sequence_v2", mode = "function", inherits = TRUE)) {
    return(TRUE)
  }
  path <- file.path(.ucl_state_root(), "R", "common", "phase18_canonical_hash.R")
  if (file.exists(path)) {
    try(source(path, local = .GlobalEnv), silent = TRUE)
  }
  exists("phase18_hash_table_v2", mode = "function", inherits = TRUE) &&
    exists("phase18_hash_sequence_v2", mode = "function", inherits = TRUE)
}

.ucl_state_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL state requires digest", call. = FALSE)
  digest::digest(charToRaw(enc2utf8(paste(as.character(value), collapse = "\x1f"))), algo = "sha256", serialize = FALSE)
}

.ucl_state_framed_hash <- function(value) {
  if (!isTRUE(.ucl_state_phase18_canonical_available())) {
    stop("UCL state requires the Phase 18 canonical-v2 encoder", call. = FALSE)
  }
  phase18_v2_hash(value)
}

.ucl_state_framed_table_hash <- function(data, key, schema_tag, exclude = character()) {
  if (!isTRUE(.ucl_state_phase18_canonical_available())) {
    stop("UCL state requires the Phase 18 canonical-v2 table encoder", call. = FALSE)
  }
  phase18_hash_table_v2(data, key = key, exclude = exclude, schema_tag = schema_tag)
}

.ucl_state_framed_sequence_hash <- function(values, names, types, domain) {
  if (!isTRUE(.ucl_state_phase18_canonical_available())) {
    stop("UCL state requires the Phase 18 canonical-v2 sequence encoder", call. = FALSE)
  }
  phase18_hash_sequence_v2(values, domain = domain, names = names, types = types)
}

.ucl_state_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "true", "false")))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_state_graph_parts <- function(source, clubs = NULL, fixtures = NULL) {
  if (is.list(source) && !is.data.frame(source)) {
    clubs <- clubs %||% source$clubs
    fixtures <- fixtures %||% source$fixtures
  }
  list(
    graph = if (is.list(source) && !is.data.frame(source)) source else list(clubs = clubs, fixtures = fixtures),
    clubs = clubs, fixtures = fixtures
  )
}

.ucl_state_parse_time <- function(value) {
  text <- as.character(value)
  parsed <- suppressWarnings(as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  missing <- is.na(parsed) & !is.na(text)
  if (any(missing)) parsed[missing] <- suppressWarnings(as.POSIXct(text[missing], format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
  parsed
}

.ucl_state_validate_cutoff <- function(value, field = "information_cutoff_utc") {
  if (is.null(value) || length(value) != 1L || is.na(value) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", as.character(value))) {
    return(list(error = "state_cutoff_invalid"))
  }
  parsed <- .ucl_state_parse_time(as.character(value))
  if (is.na(parsed)) return(list(error = "state_cutoff_invalid"))
  # A 2099-style sentinel is not an information boundary.  Production callers
  # must supply the observed cutoff explicitly; fixture callers may use a real
  # historical timestamp but never this open-ended placeholder.
  if (as.numeric(parsed) >= as.numeric(as.POSIXct("2099-01-01T00:00:00Z", tz = "UTC"))) {
    return(list(error = "state_cutoff_sentinel_forbidden"))
  }
  list(
    error = NULL,
    value = format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

.ucl_state_required_fixture_fields <- function() {
  c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id",
    "venue_id", "kickoff_utc", "kickoff_confirmed", "confirmed_kickoff_at_utc",
    "source_artifact_id", "source_row_key", "source_lineage_id", "source_bundle_id",
    "source_row_sha256",
    "source_status", "match_status", "completion_method",
    "regulation_home_goals", "regulation_away_goals", "final_home_goals",
    "final_away_goals", "shootout_home_goals", "shootout_away_goals",
    "counts_for_standings")
}

.ucl_state_status_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

.ucl_state_validate_scores <- function(fixtures) {
  normalize <- function(value) tolower(trimws(as.character(value)))
  source_status <- normalize(fixtures$source_status)
  match_status <- normalize(fixtures$match_status)
  completion_method <- normalize(fixtures$completion_method)
  source_map <- rep(NA_character_, length(source_status))
  source_map[source_status %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture")] <- "scheduled"
  source_map[source_status %in% c("live", "in_progress", "in-progress", "inplay", "in_play")] <- "in_progress"
  source_map[source_status %in% c("completed", "complete", "finished", "full_time", "full-time", "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded", "historical_completed")] <- "completed"
  source_map[source_status %in% c("postponed", "delayed")] <- "postponed"
  source_map[source_status %in% c("abandoned", "cancelled", "canceled", "suspended")] <- "abandoned"
  status_map <- rep(NA_character_, length(match_status))
  status_map[match_status %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture")] <- "scheduled"
  status_map[match_status %in% c("live", "in_progress", "in-progress", "inplay", "in_play")] <- "in_progress"
  status_map[match_status %in% c("completed", "complete", "finished", "full_time", "full-time", "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded", "historical_completed")] <- "completed"
  status_map[match_status %in% c("postponed", "delayed")] <- "postponed"
  status_map[match_status %in% c("abandoned", "cancelled", "canceled", "suspended")] <- "abandoned"
  if (any(is.na(source_map) | !nzchar(source_status))) return("source_status_unmapped")
  if (any(is.na(status_map) | !nzchar(match_status))) return("match_status_unmapped")
  if (any(source_map != status_map)) return("lifecycle_status_mismatch")
  if (any(!completion_method %in% c("not_completed", "not_applicable", "regulation", "extra_time", "penalties", "awarded"))) return("completion_method_unmapped")
  completed <- status_map == "completed"
  if (any(!completed & !completion_method %in% c("not_completed", "not_applicable"))) return("open_fixture_completion_invalid")
  if (any(completed & completion_method %in% c("not_completed", "not_applicable"))) return("completed_completion_missing")
  count_values <- as.character(fixtures$counts_for_standings)
  if (any(is.na(fixtures$counts_for_standings) | !tolower(count_values) %in% c("true", "false"))) return("counts_for_standings_invalid")
  winner_field <- intersect(c("winner_club_id", "winner_team_id"), names(fixtures))[1L]
  winner <- if (length(winner_field) && !is.na(winner_field)) as.character(fixtures[[winner_field]]) else rep(NA_character_, nrow(fixtures))
  completed <- status_map == "completed"
  score_fields <- c("regulation_home_goals", "regulation_away_goals", "final_home_goals", "final_away_goals", "shootout_home_goals", "shootout_away_goals")
  for (field in score_fields) {
    values <- trimws(as.character(fixtures[[field]]))
    present <- !is.na(values) & nzchar(values)
    numeric_values <- suppressWarnings(as.numeric(values))
    if (any(present & (is.na(numeric_values) | !is.finite(numeric_values) | numeric_values < 0 | numeric_values != floor(numeric_values)))) {
      return("score_not_nonnegative_integer")
    }
  }
  present_score <- function(field) {
    values <- trimws(as.character(fixtures[[field]]))
    !is.na(values) & nzchar(values)
  }
  regulation_complete <- present_score("regulation_home_goals") & present_score("regulation_away_goals")
  regulation_partial <- xor(present_score("regulation_home_goals"), present_score("regulation_away_goals"))
  final_complete <- present_score("final_home_goals") & present_score("final_away_goals")
  final_partial <- xor(present_score("final_home_goals"), present_score("final_away_goals"))
  shootout_complete <- present_score("shootout_home_goals") & present_score("shootout_away_goals")
  shootout_partial <- xor(present_score("shootout_home_goals"), present_score("shootout_away_goals"))
  if (any(regulation_partial | final_partial | shootout_partial)) return("score_pair_incomplete")
  if (any(!completed & (regulation_complete | final_complete | shootout_complete | !is.na(winner) & nzchar(trimws(winner))))) return("open_fixture_has_score")
  if (!any(completed)) return(invisible(NULL))
  regulation_home <- suppressWarnings(as.numeric(fixtures$regulation_home_goals))
  regulation_away <- suppressWarnings(as.numeric(fixtures$regulation_away_goals))
  final_home <- suppressWarnings(as.numeric(fixtures$final_home_goals))
  final_away <- suppressWarnings(as.numeric(fixtures$final_away_goals))
  shootout_home <- suppressWarnings(as.numeric(fixtures$shootout_home_goals))
  shootout_away <- suppressWarnings(as.numeric(fixtures$shootout_away_goals))
  for (index in which(completed)) {
    method <- completion_method[[index]]
    if (method == "regulation") {
      if (!regulation_complete[[index]] || !final_complete[[index]] || shootout_complete[[index]] ||
          regulation_home[[index]] != final_home[[index]] || regulation_away[[index]] != final_away[[index]]) return("regulation_score_contradiction")
      expected <- if (final_home[[index]] > final_away[[index]]) as.character(fixtures$home_club_id[[index]]) else if (final_away[[index]] > final_home[[index]]) as.character(fixtures$away_club_id[[index]]) else NA_character_
    } else if (method == "extra_time") {
      if (!regulation_complete[[index]] || !final_complete[[index]] || shootout_complete[[index]] ||
          final_home[[index]] < regulation_home[[index]] || final_away[[index]] < regulation_away[[index]]) return("extra_time_score_contradiction")
      expected <- if (final_home[[index]] > final_away[[index]]) as.character(fixtures$home_club_id[[index]]) else if (final_away[[index]] > final_home[[index]]) as.character(fixtures$away_club_id[[index]]) else NA_character_
    } else if (method == "penalties") {
      if (!regulation_complete[[index]] || !final_complete[[index]] || !shootout_complete[[index]] || final_home[[index]] != final_away[[index]] || shootout_home[[index]] == shootout_away[[index]]) return("penalty_score_contradiction")
      expected <- if (shootout_home[[index]] > shootout_away[[index]]) as.character(fixtures$home_club_id[[index]]) else as.character(fixtures$away_club_id[[index]])
    } else if (method == "awarded") {
      if (!final_complete[[index]] || regulation_complete[[index]] || shootout_complete[[index]]) return("awarded_score_contradiction")
      expected <- if (final_home[[index]] > final_away[[index]]) as.character(fixtures$home_club_id[[index]]) else if (final_away[[index]] > final_home[[index]]) as.character(fixtures$away_club_id[[index]]) else NA_character_
    } else {
      return("completed_completion_missing")
    }
    observed <- winner[[index]]
    if (is.na(expected)) {
      if (!is.na(observed) && nzchar(trimws(observed))) return("winner_score_contradiction")
    } else if (is.na(observed) || !identical(trimws(observed), expected)) {
      return("winner_score_contradiction")
    }
  }
  invisible(NULL)
}

.ucl_state_canonical_sort <- function(fixtures) {
  fixtures[order(as.character(fixtures$fixture_id), as.character(fixtures$home_club_id), as.character(fixtures$away_club_id), method = "radix"), , drop = FALSE]
}

.ucl_state_graph_hash <- function(graph) {
  if (!is.list(graph) || !is.data.frame(graph$clubs) || !is.data.frame(graph$fixtures)) {
    stop("UCL graph hashing requires validated clubs and fixtures tables", call. = FALSE)
  }
  clubs <- graph$clubs[order(as.character(graph$clubs$club_id), method = "radix"), , drop = FALSE]
  fixtures <- .ucl_state_canonical_sort(graph$fixtures)
  club_hash <- .ucl_state_framed_table_hash(
    clubs, key = "club_id", schema_tag = "ucl-state-clubs-v2"
  )
  fixture_hash <- .ucl_state_framed_table_hash(
    fixtures, key = "fixture_id", schema_tag = "ucl-state-fixtures-v2"
  )
  metadata_names <- c(
    "edition_id", "source_bundle_id", "source_lineage_id", "authority_mode",
    "source_bundle_sha256", "fixture_authority", "production_eligible",
    "selector_path", "production_root"
  )
  metadata_values <- lapply(metadata_names, function(field) {
    value <- graph[[field]]
    if (is.null(value) || !length(value)) return(NA_character_)
    if (is.logical(value)) return(as.logical(value[[1L]]))
    as.character(value[[1L]])
  })
  metadata_types <- vapply(metadata_values, function(value) {
    if (is.logical(value)) "logical" else "character"
  }, character(1))
  metadata_hash <- .ucl_state_framed_sequence_hash(
    metadata_values, names = metadata_names, types = metadata_types,
    domain = "ucl-state-graph-metadata-v2"
  )
  .ucl_state_framed_sequence_hash(
    as.list(c(club_hash, fixture_hash, metadata_hash)),
    names = c("clubs_sha256", "fixtures_sha256", "metadata_sha256"),
    types = rep("character", 3L), domain = "ucl-state-graph-v2"
  )
}

.ucl_state_validate_source_lineage <- function(fixtures) {
  fields <- c("source_artifact_id", "source_row_key", "source_lineage_id", "source_bundle_id")
  if (!all(fields %in% names(fixtures))) return("source_lineage_missing")
  for (field in fields) {
    values <- as.character(fixtures[[field]])
    if (any(is.na(values) | !nzchar(trimws(values)))) return(paste0(field, "_missing"))
  }
  source_keys <- paste(as.character(fixtures$source_artifact_id), as.character(fixtures$source_row_key), sep = "\x1f")
  if (anyDuplicated(source_keys)) return("source_row_key_duplicate")
  if ("source_row_sha256" %in% names(fixtures)) {
    values <- as.character(fixtures$source_row_sha256)
    if (any(is.na(values) | !grepl("^[0-9a-f]{64}$", values))) return("source_row_hash_missing")
  }
  invisible(NULL)
}

.ucl_state_bool_column <- function(values, field) {
  if (is.logical(values)) {
    if (anyNA(values)) return(NULL)
    return(as.logical(values))
  }
  text <- tolower(trimws(as.character(values)))
  if (any(is.na(text) | !text %in% c("true", "false"))) return(NULL)
  text == "true"
}

.ucl_state_source_bundle_candidate <- function(source, graph) {
  candidates <- list(
    if (is.list(graph)) graph$source_bundle_evidence else NULL,
    if (is.list(graph)) graph$accepted_source else NULL,
    if (is.list(graph)) graph$source_bundle else NULL,
    if (is.list(source) && !is.data.frame(source)) source$accepted else NULL,
    if (is.list(source) && !is.data.frame(source)) source$source_bundle_evidence else NULL
  )
  for (candidate in candidates) {
    if (is.list(candidate) && !is.null(candidate$bundle) &&
        !is.null(candidate$tables) && !is.null(candidate$authority)) return(candidate)
  }
  NULL
}

.ucl_state_validate_authority_evidence <- function(source, graph, fixtures, require_authority = FALSE) {
  fixture_marker <- NULL
  if ("fixture_authority" %in% names(fixtures)) {
    fixture_marker <- .ucl_state_bool_column(fixtures$fixture_authority, "fixture_authority")
    if (is.null(fixture_marker) || length(unique(fixture_marker)) != 1L) {
      return(list(error = "fixture_authority_evidence_invalid"))
    }
    fixture_marker <- isTRUE(fixture_marker[[1L]])
  } else {
    # A graph-level flag is caller metadata, not authority evidence.  It may
    # never manufacture fixture status when the validated fixture rows do not
    # carry their own non-promotable marker.
    if (isTRUE(graph$fixture_authority)) {
      return(list(error = "fixture_authority_evidence_missing"))
    }
    fixture_marker <- FALSE
  }
  if (!is.null(graph$fixture_authority) &&
      !identical(isTRUE(graph$fixture_authority), fixture_marker)) {
    return(list(error = "fixture_authority_metadata_mismatch"))
  }

  production_marker <- !fixture_marker
  if ("production_eligible" %in% names(fixtures)) {
    eligible <- .ucl_state_bool_column(fixtures$production_eligible, "production_eligible")
    if (is.null(eligible) || length(unique(eligible)) != 1L ||
        !identical(isTRUE(eligible[[1L]]), production_marker)) {
      return(list(error = "production_eligibility_evidence_invalid"))
    }
  }
  if (!is.null(graph$production_eligible) &&
      !identical(isTRUE(graph$production_eligible), production_marker)) {
    return(list(error = "production_eligibility_metadata_mismatch"))
  }

  requested_mode <- if (is.null(graph$authority_mode)) NULL else as.character(graph$authority_mode)
  if (length(requested_mode) > 1L || (!is.null(requested_mode) &&
      (is.na(requested_mode) || !nzchar(requested_mode)))) {
    return(list(error = "authority_mode_invalid"))
  }
  if (fixture_marker && !is.null(requested_mode) && !identical(requested_mode, "fixture")) {
    return(list(error = "authority_mode_metadata_mismatch"))
  }
  if (!fixture_marker && !is.null(requested_mode) &&
      !requested_mode %in% c("production", "accepted")) {
    return(list(error = "authority_mode_metadata_mismatch"))
  }

  if (fixture_marker) {
    return(list(error = NULL, fixture_authority = TRUE,
                authority_mode = "fixture", production_eligible = FALSE,
                source_bundle_sha256 = NULL))
  }

  candidate <- .ucl_state_source_bundle_candidate(source, graph)
  if (is.null(candidate) ||
      !exists("phase18_validate_ucl_source_bundle", mode = "function", inherits = TRUE)) {
    return(list(error = "source_bundle_evidence_missing"))
  }
  validated <- tryCatch({
    phase18_validate_ucl_source_bundle(candidate)
    TRUE
  }, error = function(error) error)
  if (inherits(validated, "error")) {
    return(list(error = "source_bundle_evidence_invalid", message = conditionMessage(validated)))
  }
  bundle <- candidate$bundle
  if (!is.data.frame(bundle) || nrow(bundle) != 1L ||
      !all(c("bundle_id", "bundle_sha256", "edition_id") %in% names(bundle))) {
    return(list(error = "source_bundle_evidence_invalid"))
  }
  bundle_id <- as.character(bundle$bundle_id[[1L]])
  bundle_hash <- tolower(as.character(bundle$bundle_sha256[[1L]]))
  if (!identical(bundle_id, as.character(fixtures$source_bundle_id[[1L]])) ||
      !grepl("^[0-9a-f]{64}$", bundle_hash)) {
    return(list(error = "source_bundle_lineage_mismatch"))
  }
  if (!is.null(graph$source_bundle_sha256) &&
      !identical(tolower(as.character(graph$source_bundle_sha256)), bundle_hash)) {
    return(list(error = "source_bundle_hash_metadata_mismatch"))
  }
  if ("source_bundle_sha256" %in% names(fixtures) &&
      any(tolower(as.character(fixtures$source_bundle_sha256)) != bundle_hash)) {
    return(list(error = "source_bundle_hash_mismatch"))
  }
  list(error = NULL, fixture_authority = FALSE,
       authority_mode = if (is.null(requested_mode)) "production" else requested_mode,
       production_eligible = TRUE, source_bundle_sha256 = bundle_hash)
}

#' Validate the complete accepted 36-club/144-fixture league graph.
#'
#' Invalid inputs return a typed blocked value and never synthesize missing
#' pairings.  Valid inputs return a canonical, semantically sorted graph.
ucl_validate_schedule <- function(source, clubs = NULL, fixtures = NULL, rules = NULL, require_authority = FALSE) {
  parts <- .ucl_state_graph_parts(source, clubs, fixtures)
  graph <- parts$graph; clubs <- parts$clubs; fixtures <- parts$fixtures
  if (!is.data.frame(clubs) || !is.data.frame(fixtures)) return(.ucl_state_blocked("source_schema_invalid", "UCL schedule requires clubs and fixtures tables", graph))
  expected_edition <- if (!is.null(rules) && !is.null(rules$edition_id)) as.character(rules$edition_id) else "ucl_2026_27"
  missing_fixture <- setdiff(.ucl_state_required_fixture_fields(), names(fixtures))
  if (length(missing_fixture)) return(.ucl_state_blocked("fixture_schema_incomplete", paste0("UCL fixtures missing: ", paste(missing_fixture, collapse = ", ")), graph, list(missing = missing_fixture)))
  if (!"club_id" %in% names(clubs)) return(.ucl_state_blocked("club_schema_incomplete", "UCL clubs require club_id", graph))
  if (nrow(clubs) != 36L || length(unique(as.character(clubs$club_id))) != 36L) return(.ucl_state_blocked("club_cardinality_invalid", "UCL schedule requires exactly 36 unique clubs", graph))
  if (nrow(fixtures) != 144L || anyDuplicated(as.character(fixtures$fixture_id))) return(.ucl_state_blocked("fixture_cardinality_invalid", "UCL schedule requires exactly 144 unique fixtures", graph))
  club_ids <- as.character(clubs$club_id); fixture_ids <- as.character(fixtures$fixture_id)
  if (any(is.na(club_ids) | !nzchar(club_ids)) || anyDuplicated(club_ids) || any(is.na(fixture_ids) | !nzchar(fixture_ids))) return(.ucl_state_blocked("identity_invalid", "UCL club and fixture identities must be stable and non-empty", graph))
  if (length(unique(as.character(fixtures$edition_id))) != 1L || any(as.character(fixtures$edition_id) != expected_edition)) return(.ucl_state_blocked("foreign_edition", "UCL fixtures must belong to one supported edition", graph))
  club_editions <- if ("edition_id" %in% names(clubs)) as.character(clubs$edition_id) else rep(expected_edition, nrow(clubs))
  if (any(is.na(club_editions) | !nzchar(club_editions) | club_editions != expected_edition)) return(.ucl_state_blocked("foreign_club_edition", "UCL clubs must belong to the supported edition", graph))
  endpoints <- c(as.character(fixtures$home_club_id), as.character(fixtures$away_club_id))
  if (any(!endpoints %in% club_ids)) return(.ucl_state_blocked("unknown_fixture_endpoint", "UCL fixture references an unknown club", graph))
  if (any(as.character(fixtures$home_club_id) == as.character(fixtures$away_club_id))) return(.ucl_state_blocked("self_fixture", "UCL fixtures cannot contain a club against itself", graph))
  degree <- table(factor(endpoints, levels = club_ids))
  home_degree <- table(factor(as.character(fixtures$home_club_id), levels = club_ids))
  away_degree <- table(factor(as.character(fixtures$away_club_id), levels = club_ids))
  if (any(as.integer(degree) != 8L) || any(as.integer(home_degree) != 4L) || any(as.integer(away_degree) != 4L)) return(.ucl_state_blocked("schedule_degree_invalid", "UCL schedule requires eight opponents and a 4/4 home-away split", graph))
  opponents <- lapply(club_ids, function(id) unique(c(as.character(fixtures$away_club_id[fixtures$home_club_id == id]), as.character(fixtures$home_club_id[fixtures$away_club_id == id]))))
  if (any(vapply(opponents, length, integer(1)) != 8L)) return(.ucl_state_blocked("opponent_cardinality_invalid", "UCL schedule requires eight distinct opponents per club", graph))
  if (any(is.na(suppressWarnings(as.integer(fixtures$matchday)))) || any(as.integer(fixtures$matchday) < 1L | as.integer(fixtures$matchday) > 8L)) return(.ucl_state_blocked("matchday_invalid", "UCL matchday must be in 1 through 8", graph))
  if (any(is.na(as.character(fixtures$venue_id)) | !nzchar(trimws(as.character(fixtures$venue_id))))) return(.ucl_state_blocked("venue_missing", "UCL fixture venue evidence is required", graph))
  kickoff <- .ucl_state_parse_time(fixtures$kickoff_utc); confirmed <- as.logical(fixtures$kickoff_confirmed)
  confirmed_time <- .ucl_state_parse_time(fixtures$confirmed_kickoff_at_utc)
  if (any(is.na(kickoff)) || any(is.na(confirmed)) || any(!confirmed) || any(is.na(confirmed_time))) return(.ucl_state_blocked("kickoff_unconfirmed", "UCL fixtures require a confirmed kickoff", graph))
  if (any(as.numeric(kickoff) != as.numeric(confirmed_time))) return(.ucl_state_blocked("kickoff_confirmation_mismatch", "Confirmed kickoff evidence must equal the scheduled kickoff", graph))
  endpoint_pairs <- paste(pmin(as.character(fixtures$home_club_id), as.character(fixtures$away_club_id)), pmax(as.character(fixtures$home_club_id), as.character(fixtures$away_club_id)), sep = "\x1f")
  if (anyDuplicated(endpoint_pairs)) return(.ucl_state_blocked("duplicate_opponent_pair", "UCL schedule cannot repeat an unordered opponent pair", graph))
  fixture_bundles <- as.character(fixtures$source_bundle_id)
  if (any(is.na(fixture_bundles) | !nzchar(trimws(fixture_bundles)) |
          fixture_bundles != fixture_bundles[[1L]])) return(.ucl_state_blocked("lineage_bundle_mismatch", "UCL fixtures must share one source bundle", graph))
  if (!is.null(graph$source_bundle_id) &&
      (length(graph$source_bundle_id) != 1L || is.na(graph$source_bundle_id) ||
       !identical(as.character(graph$source_bundle_id), fixture_bundles[[1L]]))) {
    return(.ucl_state_blocked("lineage_bundle_metadata_mismatch", "Caller graph source bundle disagrees with fixture evidence", graph))
  }
  lineage_error <- .ucl_state_validate_source_lineage(fixtures)
  if (!is.null(lineage_error)) return(.ucl_state_blocked("source_lineage_invalid", lineage_error, graph))
  score_error <- .ucl_state_validate_scores(fixtures)
  if (!is.null(score_error)) return(.ucl_state_blocked("score_semantics_invalid", score_error, graph))
  authority <- .ucl_state_validate_authority_evidence(source, graph, fixtures, require_authority)
  if (!is.null(authority$error)) {
    return(.ucl_state_blocked(
      "source_authority_invalid", authority$error, graph,
      diagnostics = authority[setdiff(names(authority), "error")]
    ))
  }
  graph$edition_id <- expected_edition
  graph$clubs <- clubs[order(as.character(clubs$club_id), method = "radix"), , drop = FALSE]
  graph$fixtures <- .ucl_state_canonical_sort(fixtures)
  graph$source_bundle_id <- fixture_bundles[[1L]]
  fixture_lineages <- sort(unique(as.character(graph$fixtures$source_lineage_id)), method = "radix")
  # A source may expose one bundle lineage on the club manifest while each
  # fixture carries a row lineage.  Both are evidence; arbitrary graph-level
  # lineage strings are not.
  manifest_lineages <- character()
  if ("source_lineage_id" %in% names(graph$clubs)) {
    manifest_lineages <- c(manifest_lineages, as.character(graph$clubs$source_lineage_id))
  }
  if ("source_artifact_id" %in% names(graph$clubs)) {
    manifest_lineages <- c(manifest_lineages, as.character(graph$clubs$source_artifact_id))
  }
  lineage_evidence <- unique(c(fixture_lineages, manifest_lineages))
  derived_lineage <- paste(fixture_lineages, collapse = ";")
  if (!is.null(graph$source_lineage_id) &&
      (length(graph$source_lineage_id) != 1L || is.na(graph$source_lineage_id) ||
       (!as.character(graph$source_lineage_id) %in% lineage_evidence &&
        !identical(as.character(graph$source_lineage_id), derived_lineage)))) {
    return(.ucl_state_blocked(
      "lineage_metadata_mismatch",
      "Caller graph source lineage disagrees with fixture evidence",
      graph
    ))
  }
  graph$source_lineage_id <- derived_lineage
  graph$authority_mode <- authority$authority_mode
  graph$fixture_authority <- authority$fixture_authority
  graph$production_eligible <- authority$production_eligible
  if (!is.null(authority$source_bundle_sha256)) {
    graph$source_bundle_sha256 <- authority$source_bundle_sha256
  }
  graph$selector_path <- graph$selector_path %||% NULL
  graph$production_root <- graph$production_root %||% NULL
  if (isTRUE(require_authority) && identical(graph$authority_mode, "fixture") && !isTRUE(graph$fixture_authority)) return(.ucl_state_blocked("fixture_authority_marker_missing", "Fixture source must carry its non-promotable marker", graph))
  graph$graph_sha256 <- .ucl_state_graph_hash(graph)
  structure(list(status = "ready", graph = graph, clubs = graph$clubs, fixtures = graph$fixtures,
                 edition_id = expected_edition, source_bundle_id = graph$source_bundle_id,
                 authority_mode = graph$authority_mode, fixture_authority = graph$fixture_authority,
                 production_eligible = graph$production_eligible, graph_sha256 = graph$graph_sha256),
            class = c("ucl_schedule_validation", "list"))
}

.ucl_state_to_phase14_matches <- function(fixtures, state_cutoff_utc = "2099-12-31T23:59:59Z") {
  n <- nrow(fixtures)
  final_home <- as.integer(fixtures$final_home_goals)
  final_away <- as.integer(fixtures$final_away_goals)
  final_home[is.na(final_home)] <- as.integer(fixtures$regulation_home_goals[is.na(final_home)])
  final_away[is.na(final_away)] <- as.integer(fixtures$regulation_away_goals[is.na(final_away)])
  completed <- .ucl_state_status_completed(fixtures$match_status)
  evidence <- ifelse(completed, as.character(fixtures$confirmed_kickoff_at_utc), NA_character_)
  data.frame(
    schema_version = "phase14-canonical-match-v1",
    match_id = as.character(fixtures$fixture_id), source_namespace = "ucl_fixture",
    source_id = as.character(fixtures$source_artifact_id), source_match_id = as.character(fixtures$source_row_key),
    source_lineage_id = as.character(fixtures$source_lineage_id), edition_id = as.character(fixtures$edition_id),
    fixture_id = as.character(fixtures$fixture_id), source_group_id = "league_phase", group_id = "league_phase",
    home_team_id = as.character(fixtures$home_club_id), away_team_id = as.character(fixtures$away_club_id),
    home_display_name = as.character(fixtures$home_club_id), away_display_name = as.character(fixtures$away_club_id),
    scheduled_at_utc = as.character(fixtures$kickoff_utc), match_date = substr(as.character(fixtures$kickoff_utc), 1L, 10L),
    kickoff_confirmed = as.logical(fixtures$kickoff_confirmed), confirmed_kickoff_at_utc = as.character(fixtures$confirmed_kickoff_at_utc),
    neutral = FALSE, venue_context = as.character(fixtures$venue_id), source_status = as.character(fixtures$source_status),
    match_status = as.character(fixtures$match_status),
    completion_method = ifelse(completed, ifelse(as.character(fixtures$completion_method) == "not_completed", "regulation", as.character(fixtures$completion_method)), "not_applicable"),
    regulation_home_goals = as.integer(fixtures$regulation_home_goals), regulation_away_goals = as.integer(fixtures$regulation_away_goals),
    final_home_goals = final_home, final_away_goals = final_away,
    shootout_home_goals = as.integer(fixtures$shootout_home_goals), shootout_away_goals = as.integer(fixtures$shootout_away_goals),
    winner_team_id = ifelse(!completed, NA_character_, ifelse(final_home > final_away, as.character(fixtures$home_club_id), ifelse(final_away > final_home, as.character(fixtures$away_club_id), NA_character_))),
    evidence_completed_at_utc = evidence, counts_for_standings = as.logical(fixtures$counts_for_standings),
    counts_for_form = as.logical(fixtures$counts_for_standings), source_artifact_id = as.character(fixtures$source_artifact_id),
    fixture_source_artifact_id = as.character(fixtures$source_artifact_id), competition_lineage_id = as.character(fixtures$source_lineage_id),
    history_lineage_id = as.character(fixtures$source_lineage_id), source_row_sha256 = as.character(fixtures$source_row_sha256),
    state_cutoff_utc = as.character(state_cutoff_utc),
    row_sha256 = NA_character_, table_sha256 = NA_character_, stringsAsFactors = FALSE, check.names = FALSE
  )
}

.ucl_state_source_phase14 <- function() {
  if (exists("phase14_compute_standings", mode = "function", inherits = TRUE)) return(invisible(TRUE))
  root <- .ucl_state_root()
  source_errors <- character()
  for (relative in c("R/competition/standings.R", "R/competition/match_state.R")) {
    path <- file.path(root, relative)
    if (file.exists(path)) {
      result <- tryCatch({
        source(path, local = .GlobalEnv)
        NULL
      }, error = function(error) error)
      if (inherits(result, "error")) source_errors <- c(source_errors, conditionMessage(result))
    }
  }
  invisible(exists("phase14_compute_standings", mode = "function", inherits = TRUE))
}

.ucl_state_fallback_standings <- function(matches, team_ids) {
  rows <- lapply(team_ids, function(team) {
    counted <- (as.character(matches$home_team_id) == team | as.character(matches$away_team_id) == team) & as.logical(matches$counts_for_standings)
    home <- counted & as.character(matches$home_team_id) == team
    away <- counted & as.character(matches$away_team_id) == team
    hg <- as.numeric(matches$final_home_goals); ag <- as.numeric(matches$final_away_goals)
    gf <- c(hg[home], ag[away]); ga <- c(ag[home], hg[away]);
    data.frame(team_id = team, played = sum(!is.na(gf) & !is.na(ga)), wins = sum(gf > ga, na.rm = TRUE), draws = sum(gf == ga, na.rm = TRUE), losses = sum(gf < ga, na.rm = TRUE), goals_for = sum(gf, na.rm = TRUE), goals_against = sum(ga, na.rm = TRUE), goal_difference = sum(gf - ga, na.rm = TRUE), points = 3 * sum(gf > ga, na.rm = TRUE) + sum(gf == ga, na.rm = TRUE), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Build canonical UCL league state and Article 18 projection.
ucl_build_state <- function(source, rules = NULL, state_cutoff_utc = NULL, provider_standings = NULL,
                            evidence = NULL, evidence_path = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract(evidence, evidence_path) else NULL
  validation <- ucl_validate_schedule(source, rules = rules)
  if (!identical(validation$status, "ready")) return(validation)
  if (is.null(state_cutoff_utc)) {
    return(.ucl_state_blocked(
      "state_cutoff_required",
      "UCL state construction requires one explicit information cutoff",
      validation$graph
    ))
  }
  cutoff_validation <- .ucl_state_validate_cutoff(state_cutoff_utc, "state_cutoff_utc")
  if (!is.null(cutoff_validation$error)) {
    return(.ucl_state_blocked(
      cutoff_validation$error,
      "UCL state cutoff must be an explicit non-sentinel UTC timestamp",
      validation$graph
    ))
  }
  state_cutoff_utc <- cutoff_validation$value
  cutoff <- .ucl_state_parse_time(state_cutoff_utc)
  graph <- validation$graph
  matches <- .ucl_state_to_phase14_matches(graph$fixtures, state_cutoff_utc)
  phase14_available <- isTRUE(.ucl_state_source_phase14())
  if (!phase14_available && !isTRUE(graph$fixture_authority)) {
    return(.ucl_state_blocked(
      "phase14_authority_missing",
      "Phase 14 standings authority could not be loaded for a production state",
      graph
    ))
  }
  universal <- tryCatch(
    if (phase14_available && exists("phase14_compute_standings", mode = "function", inherits = TRUE)) {
      phase14_compute_standings(matches = matches, edition_id = graph$edition_id, group_id = "league_phase", state_cutoff_utc = state_cutoff_utc, source_bundle_id = graph$source_bundle_id, ruleset_adapter = NULL, team_ids = graph$clubs$club_id)
    } else {
      .ucl_state_fallback_standings(matches, as.character(graph$clubs$club_id))
    },
    error = function(error) .ucl_state_blocked("phase14_standings_blocked", conditionMessage(error), graph)
  )
  if (inherits(universal, "ucl_blocked_state")) return(universal)
  ranking <- ucl_apply_article18(universal, matches = graph$fixtures, evidence = evidence, rules = rules)
  ranking$source_bundle_id <- graph$source_bundle_id
  ranking$ruleset_sha256 <- rules$ruleset_sha256
  provider <- if (is.null(provider_standings)) NULL else as.data.frame(provider_standings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.null(provider)) {
    provider_ids <- if ("club_id" %in% names(provider)) as.character(provider$club_id) else if ("team_id" %in% names(provider)) as.character(provider$team_id) else rep(NA_character_, nrow(provider))
    provider_bundle <- if ("source_bundle_id" %in% names(provider)) as.character(provider$source_bundle_id) else rep(NA_character_, nrow(provider))
    provider$reconciliation_status <- ifelse(
      is.na(provider_ids) | !nzchar(provider_ids), "unusable",
      ifelse(!provider_ids %in% as.character(ranking$club_id), "foreign_identity",
             ifelse(is.na(provider_bundle) | !nzchar(provider_bundle) | provider_bundle != as.character(graph$source_bundle_id), "foreign_lineage", "same_lineage_candidate"))
    )
  }
  status <- attr(ranking, "status", exact = TRUE) %||% "ready"
  structure(list(
    status = "ready", ranking_status = status, edition_id = graph$edition_id,
    state_cutoff_utc = state_cutoff_utc, source_bundle_id = graph$source_bundle_id,
    source_lineage_id = graph$source_lineage_id, authority_mode = graph$authority_mode,
    fixture_authority = graph$fixture_authority, production_eligible = graph$production_eligible,
    standings_authority = if (phase14_available) "phase14" else "fixture_fallback_non_promotable",
    graph_sha256 = graph$graph_sha256, graph = graph, clubs = graph$clubs,
    fixtures = graph$fixtures, canonical_matches = matches,
    universal_standings = universal, standings = ranking, projected_standings = ranking,
    projected_rankings = ranking[, intersect(c("edition_id", "club_id", "rank", "rank_interval_min", "rank_interval_max", "rank_status", "qualification_band", "source_bundle_id", "ruleset_sha256"), names(ranking)), drop = FALSE],
    tie_break_trace = attr(ranking, "trace", exact = TRUE), provider_reconciliation = provider,
    rules = rules, ruleset_version = rules$ruleset_version, ruleset_sha256 = rules$ruleset_sha256
  ), class = c("ucl_state_bundle", "list"))
}

.ucl_state_normalize_parent_reason <- function(reason) {
  original <- if (length(reason) && !is.na(reason[[1L]])) as.character(reason[[1L]]) else ""
  if (identical(original, "no_accepted_current_ucl")) return(list(status = "production_human_needed", human_needed_reason = "phase18_authority_missing", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (original %in% c("no_accepted_club_history", "protocol_policy_not_approved", "fold_inventory_not_approved", "phase19_cr01_roster_mismatch", "phase19_cr02_rating_replay_unverified", "phase19_cr03_fold_identity_unverified", "phase19_cr04_probability_lineage_unverified", "phase19_cr05_unbacked_installer")) return(list(status = "production_human_needed", human_needed_reason = "phase19_cr01_cr05_repair_pending", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  if (identical(original, "phase19_selector_not_accepted")) return(list(status = "production_human_needed", human_needed_reason = "phase19_selector_not_accepted", production_blocked_reason = NA_character_, normalization_error = FALSE, original_parent_reason = original))
  list(status = "production_blocked", human_needed_reason = NA_character_, production_blocked_reason = "unrecognized_parent_reason", normalization_error = TRUE, original_parent_reason = original)
}

.ucl_state_production_release <- function() {
  if (!exists("phase19_resolve_production_club_release", mode = "function", inherits = TRUE)) {
    release_path <- file.path(.ucl_state_root(), "R", "club", "release.R")
    if (file.exists(release_path)) try(source(release_path, local = .GlobalEnv), silent = TRUE)
  }
  if (!exists("phase19_resolve_production_club_release", mode = "function", inherits = TRUE)) return(list(error = "no_accepted_club_history"))
  tryCatch(list(value = phase19_resolve_production_club_release()), error = function(error) {
    reason <- if (!is.null(error$reason_code)) as.character(error$reason_code) else "phase19_selector_not_accepted"
    if (reason %in% c("release_root_invalid", "release_artifact_missing", "release_dependency_missing", "release_preflight_stale")) {
      reason <- "no_accepted_club_history"
    }
    list(error = reason, message = conditionMessage(error))
  })
}

.ucl_state_ledger_hash <- function(row) {
  if (!is.data.frame(row) || nrow(row) != 1L) {
    stop("UCL ledger row hashing requires exactly one data-frame row", call. = FALSE)
  }
  .ucl_state_framed_table_hash(
    row, key = intersect("fixture_id", names(row)), exclude = "row_sha256",
    schema_tag = "ucl-forecast-ledger-row-v2"
  )
}

.ucl_state_legacy_ledger_hash <- function(row) {
  if (!is.data.frame(row) || nrow(row) != 1L) {
    stop("UCL legacy ledger row hashing requires exactly one data-frame row", call. = FALSE)
  }
  fields <- setdiff(names(row), "row_sha256")
  scalar <- function(value) {
    if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
    if (!length(value)) return("")
    # Phase 20 fixture rows were issued before the framed-v2 migration.  The
    # compatibility check below is restricted to explicitly marked fixture
    # evidence and is never accepted for production release rows.
    if (is.na(value[[1L]])) return("NA")
    as.character(value[[1L]])
  }
  .ucl_state_hash(paste(vapply(row[fields], scalar, character(1)), collapse = "|"))
}

.ucl_state_row_hash_matches <- function(row, fixture_authority = FALSE) {
  if (!is.data.frame(row) || nrow(row) != 1L || !"row_sha256" %in% names(row)) return(FALSE)
  actual <- tolower(as.character(row$row_sha256[[1L]]))
  if (!grepl("^[0-9a-f]{64}$", actual)) return(FALSE)
  if (identical(actual, tolower(.ucl_state_ledger_hash(row)))) return(TRUE)
  isTRUE(fixture_authority) && identical(actual, tolower(.ucl_state_legacy_ledger_hash(row)))
}

.ucl_state_release_hash <- function(value) {
  length(value) == 1L && !is.na(value) && grepl("^[0-9a-fA-F]{64}$", as.character(value))
}

.ucl_state_first_release_value <- function(release, fields, fallback = NULL) {
  for (field in fields) {
    value <- if (is.list(release) && !is.null(release[[field]])) release[[field]] else NULL
    if (is.list(value) && !is.data.frame(value)) value <- value[[1L]] %||% NULL
    if (!is.null(value) && length(value) == 1L && !is.na(value) && nzchar(as.character(value))) {
      return(as.character(value))
    }
  }
  fallback
}

.ucl_state_release_descriptor <- function(release) {
  if (!is.list(release) || is.data.frame(release)) {
    return(list(error = "release_schema_invalid"))
  }
  metadata <- release$model_contract %||% release$metadata
  if (!is.null(metadata) && !is.list(metadata) && !is.data.frame(metadata)) metadata <- NULL
  authority_mode <- .ucl_state_first_release_value(
    release, c("authority_mode"),
    fallback = .ucl_state_first_release_value(metadata, c("authority_mode"), "")
  )
  fixture_authority <- isTRUE(release$fixture_authority) ||
    identical(authority_mode, "fixture") || identical(as.character(release$root_scope %||% ""), "process_temporary")
  production_eligible <- isTRUE(release$production_eligible) ||
    isTRUE(if (is.list(metadata)) metadata$production_eligible else FALSE)
  rows <- if (is.data.frame(release$forecast_rows)) release$forecast_rows else if (is.data.frame(release$forecasts)) release$forecasts else NULL
  if (fixture_authority) {
    if (!identical(authority_mode, "fixture") || production_eligible ||
        isTRUE(release$selector_authorized)) {
      return(list(error = "fixture_release_promotable"))
    }
    if (is.null(rows)) return(list(error = "forecast_rows_missing"))
    release_id <- .ucl_state_first_release_value(release, c("release_id"))
    model_sha <- .ucl_state_first_release_value(release, c("model_sha256"))
    calibrator_sha <- .ucl_state_first_release_value(release, c("calibrator_sha256"))
  } else {
    if (!identical(authority_mode, "production") || !production_eligible || isTRUE(release$fixture_authority)) {
      return(list(error = "production_release_not_authorized"))
    }
    release_id <- .ucl_state_first_release_value(release, c("release_id"), .ucl_state_first_release_value(metadata, c("release_id")))
    model_sha <- .ucl_state_first_release_value(release, c("model_sha256"), .ucl_state_first_release_value(metadata, c("model_sha256")))
    calibrator_sha <- .ucl_state_first_release_value(release, c("calibrator_sha256"), .ucl_state_first_release_value(metadata, c("calibrator_sha256")))
    if (is.null(rows)) return(list(error = "phase19_forecast_rows_missing", release_id = release_id))
  }
  if (is.null(release_id) || !nzchar(release_id) ||
      !.ucl_state_release_hash(model_sha) || !.ucl_state_release_hash(calibrator_sha)) {
    return(list(error = "release_lineage_invalid"))
  }
  list(
    error = NULL, release = release, rows = rows,
    release_id = release_id, model_sha256 = tolower(model_sha),
    calibrator_sha256 = tolower(calibrator_sha),
    fixture_authority = fixture_authority,
    authority_mode = if (fixture_authority) "fixture" else "production",
    production_eligible = !fixture_authority && production_eligible
  )
}

.ucl_state_validate_release_rows <- function(rows, fixtures, descriptor) {
  if (!is.data.frame(rows) || !nrow(rows)) return("forecast_rows_missing")
  required <- c("fixture_id", "model_release_id", "model_sha256", "calibrator_sha256", "row_sha256")
  if (length(setdiff(required, names(rows)))) return("forecast_rows_schema_invalid")
  ids <- as.character(rows$fixture_id)
  expected_ids <- as.character(fixtures$fixture_id)
  if (any(is.na(ids) | !nzchar(ids)) || anyDuplicated(ids) || !setequal(ids, expected_ids)) {
    return("forecast_rows_coverage_invalid")
  }
  for (field in c("model_release_id", "model_sha256", "calibrator_sha256")) {
    values <- as.character(rows[[field]])
    if (any(is.na(values) | !nzchar(values)) || length(unique(values)) != 1L) {
      return("release_lineage_mixed")
    }
  }
  if (!identical(as.character(rows$model_release_id[[1L]]), as.character(descriptor$release_id)) ||
      !identical(tolower(as.character(rows$model_sha256[[1L]])), descriptor$model_sha256) ||
      !identical(tolower(as.character(rows$calibrator_sha256[[1L]])), descriptor$calibrator_sha256)) {
    return("release_lineage_mismatch")
  }
  if (any(is.na(rows$row_sha256) | !grepl("^[0-9a-fA-F]{64}$", as.character(rows$row_sha256)))) {
    return("forecast_rows_hash_missing")
  }
  NULL
}

.ucl_state_candidate_issue <- function(fixture, candidate, cutoff = NULL, expected = NULL) {
  if (!is.data.frame(candidate) || nrow(candidate) != 1L) return("insufficient_model_evidence")
  required <- c(
    "edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc",
    "forecast_status", "model_release_id", "model_sha256", "calibrator_sha256",
    "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away", "xg_home",
    "xg_away", "likely_score", "source_bundle_id"
  )
  if (!all(required %in% names(candidate))) return("insufficient_model_evidence")
  identity_fields <- c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc")
  if (any(vapply(identity_fields, function(field) {
    !identical(as.character(candidate[[field]][[1L]]), as.character(fixture[[field]][[1L]]))
  }, logical(1)))) return("identity_unresolved")
  if (!identical(as.character(candidate$source_bundle_id[[1L]]), as.character(fixture$source_bundle_id[[1L]]))) return("lineage_mismatch")
  kickoff <- .ucl_state_parse_time(fixture$kickoff_utc[[1L]])
  feature_cutoff <- .ucl_state_parse_time(candidate$feature_cutoff_utc[[1L]])
  if (is.na(kickoff) || is.na(feature_cutoff) || !(feature_cutoff < kickoff)) return("cutoff_violation")
  if (!is.null(cutoff)) {
    state_cutoff <- .ucl_state_parse_time(cutoff)
    if (is.na(state_cutoff) || !(state_cutoff < kickoff)) return("cutoff_violation")
  }
  probabilities <- suppressWarnings(as.numeric(candidate[c("prob_home", "prob_draw", "prob_away")]))
  if (any(!is.finite(probabilities)) || any(probabilities < 0 | probabilities > 1) || abs(sum(probabilities) - 1) > 1e-10) {
    return("insufficient_model_evidence")
  }
  xg <- suppressWarnings(as.numeric(candidate[c("xg_home", "xg_away")]))
  if (any(!is.finite(xg)) || any(xg < 0)) return("insufficient_model_evidence")
  if (is.na(candidate$likely_score[[1L]]) || !grepl("^[0-9]+-[0-9]+$", as.character(candidate$likely_score[[1L]]))) return("insufficient_model_evidence")
  if (is.na(candidate$model_release_id[[1L]]) || !nzchar(trimws(as.character(candidate$model_release_id[[1L]]))) ||
      !.ucl_state_release_hash(candidate$model_sha256[[1L]]) || !.ucl_state_release_hash(candidate$calibrator_sha256[[1L]])) {
    return("insufficient_model_evidence")
  }
  if (!is.null(expected) &&
      (!identical(as.character(candidate$model_release_id[[1L]]), as.character(expected$release_id)) ||
       !identical(tolower(as.character(candidate$model_sha256[[1L]])), expected$model_sha256) ||
       !identical(tolower(as.character(candidate$calibrator_sha256[[1L]])), expected$calibrator_sha256))) {
    return("release_lineage_mismatch")
  }
  fixture_marker <- if ("fixture_authority" %in% names(fixture)) {
    .ucl_state_bool_column(fixture$fixture_authority, "fixture_authority")
  } else NULL
  fixture_authority <- isTRUE(length(fixture_marker) == 1L && fixture_marker[[1L]])
  if (!.ucl_state_row_hash_matches(candidate, fixture_authority = fixture_authority)) {
    return("insufficient_model_evidence")
  }
  if (!as.character(candidate$forecast_status[[1L]]) %in% c("available", "eligible", "eligible_fixture", "forecast_available")) {
    return("insufficient_model_evidence")
  }
  NULL
}

.ucl_state_prior_matches_fixture <- function(prior, fixture) {
  if (!is.data.frame(prior) || nrow(prior) != 1L) return(FALSE)
  fields <- c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "source_bundle_id")
  all(fields %in% names(prior)) && all(vapply(fields, function(field) {
    identical(as.character(prior[[field]][[1L]]), as.character(fixture[[field]][[1L]]))
  }, logical(1)))
}

.ucl_state_validate_prior_row <- function(prior, fixture, expected = NULL) {
  if (!is.data.frame(prior) || nrow(prior) != 1L) return("prior_schema_invalid")
  if (!.ucl_state_prior_matches_fixture(prior, fixture)) return("prior_identity_mismatch")
  required <- c(
    "edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc",
    "forecast_status", "model_release_id", "model_sha256", "calibrator_sha256",
    "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away", "xg_home",
    "xg_away", "likely_score", "source_bundle_id", "row_sha256"
  )
  if (length(setdiff(required, names(prior)))) return("prior_schema_invalid")
  row_hash <- as.character(prior$row_sha256[[1L]])
  fixture_marker <- if ("fixture_authority" %in% names(fixture)) {
    .ucl_state_bool_column(fixture$fixture_authority, "fixture_authority")
  } else NULL
  fixture_authority <- isTRUE(length(fixture_marker) == 1L && fixture_marker[[1L]])
  if (!.ucl_state_row_hash_matches(prior, fixture_authority = fixture_authority)) {
    return("prior_row_hash_mismatch")
  }
  issue <- .ucl_state_candidate_issue(fixture, prior, cutoff = NULL, expected = expected)
  if (!is.null(issue)) return(paste0("prior_", issue))
  NULL
}

.ucl_state_forecast_row <- function(fixture, release_rows = NULL, prior = NULL,
                                    authority = NULL, cutoff = NULL, expected = NULL) {
  fixture_id <- as.character(fixture$fixture_id[[1L]])
  completed <- .ucl_state_status_completed(fixture$match_status[[1L]])
  candidate <- if (!is.null(release_rows) && nrow(release_rows)) release_rows[as.character(release_rows$fixture_id) == fixture_id, , drop = FALSE] else data.frame()
  candidate_issue <- .ucl_state_candidate_issue(fixture, candidate, cutoff, expected = expected)
  valid_candidate <- is.null(candidate_issue)
  if (completed && !is.null(prior) && .ucl_state_prior_matches_fixture(prior, fixture)) {
    prior_issue <- .ucl_state_validate_prior_row(prior, fixture, expected = expected)
    if (is.null(prior_issue)) {
      # Completed forecast bytes are immutable, but only after the complete
      # prior row schema, canonical row hash, cutoff, and release lineage pass.
      return(prior[1L, , drop = FALSE])
    }
    candidate_issue <- prior_issue
  } else if (completed && !is.null(prior) && nrow(prior)) {
    # Do not let a release candidate replace a completed row when the supplied
    # prior failed the immutable identity boundary.  The completed fixture is
    # suppressed until a caller supplies the exact fixture row again.
    candidate_issue <- "prior_identity_mismatch"
  }
  if (completed) {
    valid_candidate <- FALSE
    candidate_issue <- candidate_issue %||% if (!is.null(prior) && nrow(prior)) "prior_identity_mismatch" else "insufficient_model_evidence"
  }
  result <- data.frame(
    edition_id = as.character(fixture$edition_id[[1L]]), fixture_id = fixture_id,
    home_club_id = as.character(fixture$home_club_id[[1L]]), away_club_id = as.character(fixture$away_club_id[[1L]]),
    kickoff_utc = as.character(fixture$kickoff_utc[[1L]]),
    forecast_status = if (valid_candidate) as.character(candidate$forecast_status[[1L]] %||% "available") else "suppressed",
    suppression_reason = if (valid_candidate) NA_character_ else if (!isTRUE(fixture$kickoff_confirmed[[1L]])) "kickoff_unconfirmed" else if (!nrow(candidate) && !is.null(authority) && !is.null(authority$error)) "release_unavailable" else if (!is.null(candidate_issue)) candidate_issue else "insufficient_model_evidence",
    model_release_id = if (valid_candidate) as.character(candidate$model_release_id[[1L]]) else NA_character_,
    model_sha256 = if (valid_candidate) as.character(candidate$model_sha256[[1L]]) else NA_character_,
    calibrator_sha256 = if (valid_candidate) as.character(candidate$calibrator_sha256[[1L]]) else NA_character_,
    feature_cutoff_utc = if (valid_candidate) as.character(candidate$feature_cutoff_utc[[1L]]) else NA_character_,
    prob_home = if (valid_candidate) as.numeric(candidate$prob_home[[1L]]) else NA_real_,
    prob_draw = if (valid_candidate) as.numeric(candidate$prob_draw[[1L]]) else NA_real_,
    prob_away = if (valid_candidate) as.numeric(candidate$prob_away[[1L]]) else NA_real_,
    xg_home = if (valid_candidate) as.numeric(candidate$xg_home[[1L]]) else NA_real_,
    xg_away = if (valid_candidate) as.numeric(candidate$xg_away[[1L]]) else NA_real_,
    likely_score = if (valid_candidate) as.character(candidate$likely_score[[1L]]) else NA_character_,
    source_bundle_id = as.character(fixture$source_bundle_id[[1L]]), row_sha256 = NA_character_,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  result$row_sha256 <- .ucl_state_ledger_hash(result)
  result
}

.ucl_state_ledger_blocked <- function(reason_code, message, validation,
                                      authority = list(), cutoff = NULL) {
  result <- list(
    status = "production_blocked", reason_code = as.character(reason_code),
    message = as.character(message), ledger = NULL, forecast_rows = NULL,
    authority = authority, original_parent_reason = authority$original_parent_reason %||% NA_character_,
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = FALSE, selector_authorized = FALSE,
    source_bundle_id = validation$graph$source_bundle_id,
    graph_sha256 = validation$graph$graph_sha256,
    information_cutoff_utc = cutoff, state_cutoff_utc = cutoff
  )
  class(result) <- c("ucl_forecast_ledger", "ucl_blocked_state", "list")
  result
}

#' Build one immutable, typed forecast row for every accepted UCL fixture.
ucl_build_forecast_ledger <- function(state, release = NULL, prior_ledger = NULL,
                                      state_cutoff_utc = NULL, authority_mode = NULL,
                                      production_resolver = NULL) {
  graph <- if (is.list(state) && !is.data.frame(state) && !is.null(state$graph)) state$graph else state
  validation <- ucl_validate_schedule(graph)
  if (!identical(validation$status, "ready")) return(validation)
  if (is.null(state_cutoff_utc) && is.list(state) && !is.null(state$state_cutoff_utc)) state_cutoff_utc <- state$state_cutoff_utc
  cutoff_validation <- .ucl_state_validate_cutoff(state_cutoff_utc)
  if (!is.null(cutoff_validation$error)) {
    return(.ucl_state_ledger_blocked(
      "information_cutoff_required", "Forecast ledger construction requires one explicit information cutoff",
      validation, cutoff = NULL
    ))
  }
  state_cutoff_utc <- cutoff_validation$value
  production <- if (is.null(production_resolver)) .ucl_state_production_release() else tryCatch(list(value = production_resolver()), error = function(error) list(error = if (!is.null(error$reason_code)) as.character(error$reason_code) else "phase19_selector_not_accepted", message = conditionMessage(error)))
  parent_reason <- if (!is.null(production$error)) production$error else ""
  authority <- .ucl_state_normalize_parent_reason(parent_reason)
  chosen <- release
  explicit_fixture <- is.list(chosen) && (isTRUE(chosen$fixture_authority) || identical(as.character(chosen$authority_mode %||% ""), "fixture"))
  # A caller may use the explicit release argument only for process-local
  # fixture mechanics.  Production rows must come from the selector-authorized
  # Phase 19 resolver invoked above; a forged release is never promoted.
  if (!is.null(chosen) && !explicit_fixture) {
    if (!is.null(production$error)) {
      return(.ucl_state_ledger_blocked(
        "phase19_release_not_authorized",
        "Caller-supplied production release cannot bypass the Phase 19 resolver",
        validation, authority = authority, cutoff = state_cutoff_utc
      ))
    }
    chosen <- production$value
  }
  if (is.null(chosen) && is.null(production$error)) chosen <- production$value
  is_fixture <- is.list(chosen) && (isTRUE(chosen$fixture_authority) || identical(as.character(chosen$authority_mode %||% ""), "fixture"))
  if (is_fixture) {
    # The descriptor below must see the original marker values.  In
    # particular, never coerce a forged promotable fixture into a seemingly
    # safe fixture contract.
    chosen$authority_mode <- as.character(chosen$authority_mode %||% "fixture")
  }
  descriptor <- if (is.null(chosen)) NULL else .ucl_state_release_descriptor(chosen)
  if (!is.null(descriptor) && !is.null(descriptor$error)) {
    if (!is_fixture || !identical(descriptor$error, "forecast_rows_missing")) {
      return(.ucl_state_ledger_blocked(
        descriptor$error,
        "Trusted Phase 19 release did not provide a validated forecast-row seam",
        validation, authority = authority, cutoff = state_cutoff_utc
      ))
    }
  }
  if (!is.null(descriptor) && is.null(descriptor$error)) {
    row_error <- .ucl_state_validate_release_rows(
      descriptor$rows, validation$graph$fixtures, descriptor
    )
    if (!is.null(row_error)) {
      return(.ucl_state_ledger_blocked(
        row_error,
        "Phase 19 release forecast rows are incomplete or mix model lineage",
        validation, authority = authority, cutoff = state_cutoff_utc
      ))
    }
  }
  if (!is.null(descriptor) && is.null(descriptor$error) && !is_fixture) {
    authority <- list(
      status = "production_ready", human_needed_reason = NA_character_,
      production_blocked_reason = NA_character_, normalization_error = FALSE,
      original_parent_reason = NA_character_
    )
  }
  release_rows <- if (!is.null(descriptor) && is.null(descriptor$error)) descriptor$rows else NULL
  previous <- if (is.data.frame(prior_ledger)) prior_ledger else if (is.list(prior_ledger) && is.data.frame(prior_ledger$ledger)) prior_ledger$ledger else NULL
  rows <- lapply(seq_len(nrow(validation$graph$fixtures)), function(index) {
    fixture <- validation$graph$fixtures[index, , drop = FALSE]
    prior <- if (!is.null(previous)) previous[as.character(previous$fixture_id) == as.character(fixture$fixture_id), , drop = FALSE] else NULL
    .ucl_state_forecast_row(
      fixture, release_rows, prior, if (is_fixture) NULL else production,
      state_cutoff_utc, expected = if (!is.null(descriptor) && is.null(descriptor$error)) descriptor else NULL
    )
  })
  ledger <- do.call(rbind, rows)
  ledger <- ledger[order(as.character(ledger$fixture_id), method = "radix"), , drop = FALSE]
  row.names(ledger) <- NULL
  if (anyDuplicated(as.character(ledger$fixture_id)) || !setequal(as.character(ledger$fixture_id), as.character(validation$graph$fixtures$fixture_id))) stop("UCL forecast ledger coverage is not one row per fixture", call. = FALSE)
  fixture_authority <- isTRUE(validation$graph$fixture_authority) || is_fixture
  result <- list(
    status = if (fixture_authority) "fixture_mechanics" else authority$status,
    ledger = ledger, forecast_rows = ledger, authority = authority,
    original_parent_reason = authority$original_parent_reason,
    authority_mode = if (fixture_authority) "fixture" else "production",
    fixture_authority = fixture_authority,
    production_eligible = !fixture_authority && !is.null(descriptor) &&
      is.null(descriptor$error) && isTRUE(descriptor$production_eligible),
    selector_authorized = !fixture_authority && !is.null(chosen$selector),
    source_bundle_id = validation$graph$source_bundle_id,
    graph_sha256 = validation$graph$graph_sha256,
    information_cutoff_utc = state_cutoff_utc,
    state_cutoff_utc = state_cutoff_utc,
    release_id = if (!is.null(descriptor) && is.null(descriptor$error)) descriptor$release_id else NA_character_,
    model_sha256 = if (!is.null(descriptor) && is.null(descriptor$error)) descriptor$model_sha256 else NA_character_,
    calibrator_sha256 = if (!is.null(descriptor) && is.null(descriptor$error)) descriptor$calibrator_sha256 else NA_character_,
    forecast_row_seam = if (!is.null(descriptor) && is.null(descriptor$error)) "phase19_release_forecast_rows" else "suppressed"
  )
  class(result) <- c("ucl_forecast_ledger", "list")
  result
}
