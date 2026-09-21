# Deterministic UCL league sampling and editioned knockout mechanics.

# Cross-module identities use the Phase 18 framed canonical-v2 primitives.  The
# simulation file is also loaded directly by focused tests, so load those
# primitives into a private environment rather than leaking a second public
# API into the module namespace.  The small fallback is deliberately framed as
# well; it is only used when a source checkout does not contain the common
# module (for example, an isolated fixture harness).
.ucl_sim_canonical_env <- local({
  env <- new.env(parent = baseenv())
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    candidate <- file.path(root, "R", "common", "phase18_canonical_hash.R")
    if (file.exists(candidate)) {
      try(sys.source(candidate, envir = env), silent = TRUE)
      break
    }
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  env
})

.ucl_sim_or <- function(left, right) if (!is.null(left)) left else right

.ucl_sim_canonical_text <- function(value) {
  if (length(value) != 1L || is.null(value) || is.na(value)) return(NA_character_)
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  as.character(value[[1L]])
}

.ucl_sim_frame <- function(bytes) {
  if (!is.raw(bytes)) stop("UCL canonical frames require raw bytes", call. = FALSE)
  c(writeBin(as.integer(length(bytes)), raw(), size = 4L, endian = "big"), bytes)
}

.ucl_sim_framed_scalar <- function(value, field, type = "character") {
  field <- as.character(field[[1L]])
  type <- as.character(type[[1L]])
  missing <- length(value) != 1L || is.null(value) || is.na(value[[1L]])
  payload <- if (missing) raw() else charToRaw(enc2utf8(.ucl_sim_canonical_text(value)))
  do.call(c, list(
    .ucl_sim_frame(charToRaw("phase18-canonical-v2")),
    .ucl_sim_frame(charToRaw("scalar")),
    .ucl_sim_frame(charToRaw(enc2utf8(field))),
    .ucl_sim_frame(charToRaw(enc2utf8(type))),
    .ucl_sim_frame(charToRaw(if (missing) "missing" else "present")),
    .ucl_sim_frame(payload)
  ))
}

.ucl_sim_nested_text <- function(value) {
  if (is.null(value)) return(NA_character_)
  if (is.data.frame(value)) {
    key <- if (ncol(value)) names(value)[[1L]] else character()
    return(.ucl_sim_canonical_table_hash(value, key = key, schema_tag = "ucl20-nested-table-v1"))
  }
  if (is.list(value)) {
    parts <- vapply(seq_along(value), function(index) {
      nested <- .ucl_sim_nested_text(value[[index]])
      if (is.na(nested)) "<missing>" else nested
    }, character(1))
    return(.ucl_sim_sequence_hash(as.list(parts), names = paste0("item_", seq_along(parts)), domain = "ucl20-nested-sequence-v1"))
  }
  .ucl_sim_canonical_text(value)
}

.ucl_sim_hashable_table <- function(data) {
  if (!is.data.frame(data)) stop("UCL canonical table hashing requires a data frame", call. = FALSE)
  output <- data
  for (field in names(output)) {
    if (is.list(output[[field]]) && !is.data.frame(output[[field]])) {
      output[[field]] <- vapply(output[[field]], .ucl_sim_nested_text, character(1))
    }
  }
  output
}

.ucl_sim_canonical_row_hash <- function(data, schema_tag = "ucl20-row-v1", exclude = "row_sha256") {
  data <- .ucl_sim_hashable_table(data)
  fn <- if (exists("phase18_hash_row_v2", envir = .ucl_sim_canonical_env, inherits = FALSE)) get("phase18_hash_row_v2", envir = .ucl_sim_canonical_env, inherits = FALSE) else NULL
  if (is.function(fn)) return(fn(data, exclude = intersect(exclude, names(data)), schema_tag = schema_tag))
  fields <- setdiff(names(data), exclude)
  payload <- do.call(c, c(
    list(.ucl_sim_frame(charToRaw("phase18-canonical-v2")), .ucl_sim_frame(charToRaw("row")),
         .ucl_sim_frame(charToRaw(schema_tag)), .ucl_sim_frame(charToRaw(as.character(length(fields))))),
    lapply(fields, function(field) .ucl_sim_frame(.ucl_sim_framed_scalar(data[[field]][[1L]], field, typeof(data[[field]]))))
  ))
  .ucl_sim_digest(payload)
}

.ucl_sim_canonical_table_hash <- function(data, key, schema_tag = "ucl20-table-v1", exclude = character()) {
  data <- .ucl_sim_hashable_table(data)
  fn <- if (exists("phase18_hash_table_v2", envir = .ucl_sim_canonical_env, inherits = FALSE)) get("phase18_hash_table_v2", envir = .ucl_sim_canonical_env, inherits = FALSE) else NULL
  if (is.function(fn)) return(fn(data, key = key, exclude = intersect(exclude, names(data)), schema_tag = schema_tag))
  fields <- setdiff(names(data), exclude)
  row_payload <- lapply(seq_len(nrow(data)), function(index) {
    do.call(c, lapply(fields, function(field) .ucl_sim_frame(.ucl_sim_framed_scalar(data[[field]][[index]], field, typeof(data[[field]])))))
  })
  ordering <- if (nrow(data)) order(vapply(row_payload, function(x) paste(as.integer(x), collapse = ","), character(1)), method = "radix") else integer()
  row_payload <- row_payload[ordering]
  payload <- do.call(c, c(
    list(.ucl_sim_frame(charToRaw("phase18-canonical-v2")), .ucl_sim_frame(charToRaw("table")),
         .ucl_sim_frame(charToRaw(schema_tag)), .ucl_sim_frame(charToRaw(paste(fields, collapse = "\x1f"))),
         .ucl_sim_frame(charToRaw(as.character(nrow(data))))),
    lapply(row_payload, .ucl_sim_frame)
  ))
  .ucl_sim_digest(payload)
}

.ucl_sim_sequence_hash <- function(values, names, domain) {
  # Sequence metadata is intentionally framed as canonical text.  Coerce
  # logical/numeric scalars explicitly so the Phase 18 canonical-v2 encoder
  # receives the declared character type for every field.
  values <- lapply(values, function(value) {
    if (!length(value) || is.null(value)) return(NA_character_)
    if (length(value) > 1L) value <- value[[1L]]
    if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    if (is.na(value[[1L]])) return(NA_character_)
    as.character(value[[1L]])
  })
  names <- as.character(names)
  fn <- if (exists("phase18_hash_sequence_v2", envir = .ucl_sim_canonical_env, inherits = FALSE)) get("phase18_hash_sequence_v2", envir = .ucl_sim_canonical_env, inherits = FALSE) else NULL
  if (is.function(fn)) {
    return(fn(values, domain = domain, names = names, types = rep("character", length(values))))
  }
  fields <- lapply(seq_along(values), function(index) .ucl_sim_frame(.ucl_sim_framed_scalar(values[[index]], names[[index]], "character")))
  .ucl_sim_digest(do.call(c, c(list(.ucl_sim_frame(charToRaw("phase18-canonical-v2")), .ucl_sim_frame(charToRaw("sequence")), .ucl_sim_frame(charToRaw(domain)), .ucl_sim_frame(charToRaw(as.character(length(values))))), fields)))
}

.ucl_sim_digest <- function(bytes) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("UCL simulation requires digest", call. = FALSE)
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

.ucl_sim_scalar <- function(value) {
  if (inherits(value, "POSIXt")) return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (!length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

.ucl_sim_hash <- function(value) {
  values <- as.list(value)
  .ucl_sim_sequence_hash(
    values,
    names = paste0("value_", seq_along(values)),
    domain = "ucl20-simulation-sequence-v2"
  )
}

.ucl_sim_with_seed <- function(seed, callback) {
  if (length(seed) != 1L || is.na(seed) || !is.finite(as.numeric(seed))) stop("UCL simulation seed must be finite", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  set.seed(as.integer(seed))
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  callback()
}

.ucl_sim_seed_for <- function(seed, ...) {
  digest <- .ucl_sim_hash(c(seed, ...))
  value <- suppressWarnings(strtoi(substr(digest, 1L, 7L), base = 16L))
  if (is.na(value)) value <- 1L
  as.integer((as.numeric(value) %% (.Machine$integer.max - 1)) + 1)
}

.ucl_sim_status_completed <- function(value) {
  tolower(trimws(as.character(value))) %in% c(
    "completed", "complete", "finished", "full_time", "full-time",
    "after_extra_time", "after-extra-time", "after_penalties", "after-penalties", "awarded"
  )
}

.ucl_sim_status_fixed <- function(value) {
  status <- tolower(trimws(as.character(value)))
  .ucl_sim_status_completed(status) || status %in% c("postponed", "cancelled", "canceled", "abandoned")
}

.ucl_sim_open_status <- function(value) {
  status <- tolower(trimws(as.character(value)))
  is.na(status) || !nzchar(status) || status %in% c("scheduled", "not_started", "not-started", "upcoming", "fixture", "open")
}

.ucl_sim_before <- function(left, right) {
  left_time <- .ucl_sim_parse_utc(left)
  right_time <- .ucl_sim_parse_utc(right)
  !is.na(left_time) && !is.na(right_time) && left_time < right_time
}

.ucl_sim_parse_utc <- function(value) {
  if (length(value) != 1L || is.null(value) || is.na(value[[1L]])) return(as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"))
  text <- as.character(value[[1L]])
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", text)) return(as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"))
  parsed <- suppressWarnings(as.POSIXct(text, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (is.na(parsed)) as.POSIXct(NA, origin = "1970-01-01", tz = "UTC") else parsed
}

.ucl_sim_validate_information_cutoff <- function(cutoff_utc) {
  if (length(cutoff_utc) != 1L || is.null(cutoff_utc) || is.na(cutoff_utc) || !nzchar(as.character(cutoff_utc))) {
    return(list(valid = FALSE, reason = "information_cutoff_missing", value = NA_character_))
  }
  value <- as.character(cutoff_utc[[1L]])
  parsed <- .ucl_sim_parse_utc(value)
  if (is.na(parsed)) return(list(valid = FALSE, reason = "information_cutoff_invalid", value = value))
  # 2099/9999 are the state builder's sentinel defaults, not information
  # boundaries.  They must never authorize sampling.
  if (parsed >= as.POSIXct("2099-01-01T00:00:00Z", format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
    return(list(valid = FALSE, reason = "information_cutoff_sentinel", value = value))
  }
  list(valid = TRUE, reason = NA_character_, value = value)
}

.ucl_sim_probability <- function(row) {
  fields <- intersect(c("prob_home", "prob_draw", "prob_away", "p_home", "p_draw", "p_away"), names(row))
  if (length(fields) == 6L) fields <- fields[1:3]
  if (length(fields) != 3L) return(c(NA_real_, NA_real_, NA_real_))
  p <- suppressWarnings(as.numeric(row[fields]))
  if (any(!is.finite(p)) || any(p < 0) || abs(sum(p) - 1) > 1e-8) return(c(NA_real_, NA_real_, NA_real_))
  p
}

.ucl_sim_score_grid <- function(row) {
  grid <- NULL
  for (field in c("score_grid", "score_distribution", "score_grid_json")) {
    if (!field %in% names(row)) next
    candidate <- row[[field]][[1L]]
    if (is.character(candidate) && length(candidate) == 1L && nzchar(candidate) && requireNamespace("jsonlite", quietly = TRUE)) {
      candidate <- tryCatch(jsonlite::fromJSON(candidate), error = function(error) NULL)
    }
    if (!is.null(candidate)) {
      grid <- candidate
      break
    }
  }
  if (is.null(grid)) return(NULL)
  if (is.list(grid) && !is.data.frame(grid) && !is.null(grid$home_goals)) grid <- as.data.frame(grid, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(grid) || !all(c("home_goals", "away_goals", "probability") %in% names(grid)) || !nrow(grid)) return(NULL)
  home <- suppressWarnings(as.numeric(grid$home_goals)); away <- suppressWarnings(as.numeric(grid$away_goals)); probability <- suppressWarnings(as.numeric(grid$probability))
  if (any(!is.finite(c(home, away, probability))) || any(home < 0 | away < 0) || any(home != floor(home) | away != floor(away)) || any(probability < 0) || abs(sum(probability) - 1) > 1e-8 || anyDuplicated(paste(home, away, sep = ":"))) return(NULL)
  grid <- data.frame(home_goals = as.integer(home), away_goals = as.integer(away), probability = probability, stringsAsFactors = FALSE, check.names = FALSE)
  grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
}

.ucl_sim_sample_score <- function(row) {
  grid <- .ucl_sim_score_grid(row)
  if (is.null(grid)) return(list(home = NA_integer_, away = NA_integer_, status = "suppressed", reason = "insufficient_model_evidence"))
  index <- sample.int(nrow(grid), size = 1L, prob = grid$probability)
  list(home = grid$home_goals[[index]], away = grid$away_goals[[index]], status = "sampled", reason = "none")
}

# Normalize lifecycle rows before sampling. Settled rows and postponed rows are
# immutable; only open rows with a valid score grid can be sampled.
.ucl_prepare_iteration_matches <- function(fixtures, cutoff_utc = NULL) {
  fixtures <- as.data.frame(fixtures, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"fixture_id" %in% names(fixtures)) stop("UCL iteration matches require fixture_id", call. = FALSE)
  status <- if ("match_status" %in% names(fixtures)) as.character(fixtures$match_status) else rep("scheduled", nrow(fixtures))
  fixed <- vapply(status, .ucl_sim_status_fixed, logical(1))
  open <- !fixed & vapply(status, .ucl_sim_open_status, logical(1))
  fixture_ids <- as.character(fixtures$fixture_id)
  if (anyDuplicated(fixture_ids)) stop("UCL iteration matches require unique fixture ids", call. = FALSE)
  cutoff <- .ucl_sim_validate_information_cutoff(cutoff_utc)
  kickoff <- if ("kickoff_utc" %in% names(fixtures)) vapply(fixtures$kickoff_utc, .ucl_sim_parse_utc, as.POSIXct(NA, origin = "1970-01-01", tz = "UTC")) else rep(as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"), nrow(fixtures))
  cutoff_eligible <- if (isTRUE(cutoff$valid)) !is.na(kickoff) & kickoff > .ucl_sim_parse_utc(cutoff$value) else rep(FALSE, nrow(fixtures))
  list(
    matches = fixtures,
    fixed_fixture_ids = sort(fixture_ids[fixed], method = "radix"),
    open_fixture_ids = sort(fixture_ids[open], method = "radix"),
    eligible_open_fixture_ids = sort(fixture_ids[open & cutoff_eligible], method = "radix"),
    suppressed_fixture_ids = sort(fixture_ids[open & !cutoff_eligible], method = "radix"),
    cutoff_utc = if (isTRUE(cutoff$valid)) cutoff$value else NA_character_,
    cutoff_status = cutoff$reason,
    cutoff_valid = isTRUE(cutoff$valid)
  )
}

.ucl_sample_open_fixtures <- function(prepared, ledger, seed = 20260921L, cutoff_utc = NULL) {
  if (is.data.frame(prepared)) prepared <- .ucl_prepare_iteration_matches(prepared, cutoff_utc = cutoff_utc)
  if (!is.list(prepared) || !is.data.frame(prepared$matches)) stop("UCL prepared iteration matches are invalid", call. = FALSE)
  table <- if (is.list(ledger) && is.data.frame(ledger$ledger)) ledger$ledger else as.data.frame(ledger, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"fixture_id" %in% names(table)) stop("UCL forecast ledger requires fixture_id", call. = FALSE)
  fixtures <- prepared$matches
  sampled <- character(); suppressed <- character(); records <- list(); record_index <- 0L
  ids <- sort(as.character(fixtures$fixture_id), method = "radix")
  for (fixture_id in ids) {
    index <- match(fixture_id, as.character(fixtures$fixture_id))
    if (!fixture_id %in% prepared$open_fixture_ids) next
    row <- table[as.character(table$fixture_id) == fixture_id, , drop = FALSE]
    reason <- NULL
    if (nrow(row) != 1L) reason <- "forecast_row_missing"
    if (is.null(reason) && (!"forecast_status" %in% names(row) || !as.character(row$forecast_status[[1L]]) %in% c("available", "eligible", "eligible_fixture", "eligible_production", "forecast_available"))) {
      reason <- if ("suppression_reason" %in% names(row) && length(row$suppression_reason)) as.character(row$suppression_reason[[1L]] %||% "forecast_suppressed") else "forecast_suppressed"
    }
    kickoff <- if ("kickoff_utc" %in% names(fixtures)) fixtures$kickoff_utc[[index]] else NA_character_
    feature_cutoff <- if (nrow(row) && "feature_cutoff_utc" %in% names(row)) row$feature_cutoff_utc[[1L]] else NA_character_
    run_cutoff <- cutoff_utc %||% prepared$cutoff_utc
    cutoff_check <- .ucl_sim_validate_information_cutoff(run_cutoff)
    if (is.null(reason) && !isTRUE(cutoff_check$valid)) reason <- cutoff_check$reason
    if (is.null(reason) && !.ucl_sim_before(run_cutoff, kickoff)) reason <- "information_cutoff_violation"
    if (is.null(reason) && !.ucl_sim_before(feature_cutoff, kickoff)) reason <- "cutoff_violation"
    if (is.null(reason) && !.ucl_sim_before(feature_cutoff, run_cutoff)) reason <- "feature_after_information_cutoff"
    if (is.null(reason) && is.null(.ucl_sim_score_grid(row))) reason <- "insufficient_model_evidence"
    if (!is.null(reason)) {
      suppressed <- c(suppressed, fixture_id)
      record_index <- record_index + 1L
      records[[record_index]] <- data.frame(fixture_id = fixture_id, sampling_status = "suppressed", suppression_reason = reason, sampled_home_goals = NA_integer_, sampled_away_goals = NA_integer_, stringsAsFactors = FALSE, check.names = FALSE)
      next
    }
    sampled_score <- .ucl_sim_with_seed(.ucl_sim_seed_for(seed, "fixture", fixture_id), function() .ucl_sim_sample_score(row))
    if (!identical(sampled_score$status, "sampled")) {
      suppressed <- c(suppressed, fixture_id)
      next
    }
    fixtures$source_status[[index]] <- "completed"
    fixtures$match_status[[index]] <- "completed"
    fixtures$completion_method[[index]] <- "regulation"
    fixtures$regulation_home_goals[[index]] <- sampled_score$home
    fixtures$regulation_away_goals[[index]] <- sampled_score$away
    fixtures$final_home_goals[[index]] <- sampled_score$home
    fixtures$final_away_goals[[index]] <- sampled_score$away
    fixtures$counts_for_standings[[index]] <- TRUE
    fixtures$winner_club_id[[index]] <- if (sampled_score$home > sampled_score$away) fixtures$home_club_id[[index]] else if (sampled_score$away > sampled_score$home) fixtures$away_club_id[[index]] else NA_character_
    sampled <- c(sampled, fixture_id)
    record_index <- record_index + 1L
    records[[record_index]] <- data.frame(fixture_id = fixture_id, sampling_status = "sampled", suppression_reason = NA_character_, sampled_home_goals = sampled_score$home, sampled_away_goals = sampled_score$away, stringsAsFactors = FALSE, check.names = FALSE)
  }
  list(
    matches = fixtures,
    fixed_fixture_ids = prepared$fixed_fixture_ids,
    sampled_fixture_ids = sort(sampled, method = "radix"),
    suppressed_fixture_ids = sort(unique(suppressed), method = "radix"),
    eligible_open_fixture_ids = prepared$eligible_open_fixture_ids,
    records = if (length(records)) do.call(rbind, records) else data.frame(),
    cutoff_utc = cutoff_utc %||% prepared$cutoff_utc,
    cutoff_status = prepared$cutoff_status %||% NA_character_,
    cutoff_valid = isTRUE(prepared$cutoff_valid) && isTRUE(.ucl_sim_validate_information_cutoff(cutoff_utc %||% prepared$cutoff_utc)$valid)
  )
}

.ucl_sim_iteration_graph <- function(graph, ledger, seed = 20260921L, cutoff_utc = NULL, iteration = 1L) {
  output <- graph
  prepared <- .ucl_prepare_iteration_matches(output$fixtures, cutoff_utc = cutoff_utc)
  sampled <- .ucl_sample_open_fixtures(prepared, ledger = ledger, seed = .ucl_sim_seed_for(seed, "iteration", iteration), cutoff_utc = cutoff_utc)
  output$fixtures <- sampled$matches
  attr(output, "ucl_sampling") <- sampled
  output
}

.ucl_sim_rank_rows <- function(ranking, iteration, run_id) {
  if (!is.data.frame(ranking) || !nrow(ranking)) return(data.frame())
  data.frame(
    run_id = run_id, iteration = as.integer(iteration), edition_id = as.character(ranking$edition_id),
    club_id = as.character(ranking$club_id), rank = as.integer(ranking$rank),
    rank_interval_min = as.integer(ranking$rank_interval_min), rank_interval_max = as.integer(ranking$rank_interval_max),
    rank_status = as.character(ranking$rank_status), qualification_band = as.character(ranking$qualification_band),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

.ucl_sim_table_key <- function(data, preferred = character()) {
  preferred <- preferred[preferred %in% names(data)]
  if (length(preferred)) return(preferred[[1L]])
  if (!ncol(data)) return(character())
  names(data)[[1L]]
}

.ucl_sim_graph_content_hash <- function(graph) {
  if (!is.list(graph) || !is.data.frame(graph$clubs) || !is.data.frame(graph$fixtures)) return(NA_character_)
  clubs <- graph$clubs[order(as.character(graph$clubs$club_id), method = "radix"), , drop = FALSE]
  fixtures <- graph$fixtures[order(as.character(graph$fixtures$fixture_id), method = "radix"), , drop = FALSE]
  club_hash <- .ucl_sim_canonical_table_hash(clubs, key = .ucl_sim_table_key(clubs, "club_id"), schema_tag = "ucl20-state-clubs-v1")
  fixture_hash <- .ucl_sim_canonical_table_hash(fixtures, key = .ucl_sim_table_key(fixtures, "fixture_id"), schema_tag = "ucl20-state-fixtures-v2")
  .ucl_sim_sequence_hash(
    list(
      graph$edition_id %||% NA_character_, graph$source_bundle_id %||% NA_character_,
      graph$source_lineage_id %||% NA_character_, graph$authority_mode %||% NA_character_,
      graph$fixture_authority %||% NA, graph$production_eligible %||% NA,
      graph$selector_path %||% NA_character_, graph$production_root %||% NA_character_,
      club_hash, fixture_hash
    ),
    names = c("edition_id", "source_bundle_id", "source_lineage_id", "authority_mode",
              "fixture_authority", "production_eligible", "selector_path", "production_root",
              "clubs_sha256", "fixtures_sha256"),
    domain = "ucl20-validated-state-v2"
  )
}

.ucl_sim_state_content_hash <- function(state, graph) {
  graph_hash <- .ucl_sim_graph_content_hash(graph)
  table_hashes <- list()
  for (field in c("universal_standings", "standings", "projected_standings", "projected_rankings", "tie_break_trace", "canonical_matches")) {
    value <- if (is.list(state) && !is.null(state[[field]])) state[[field]] else NULL
    if (!is.data.frame(value)) next
    key <- .ucl_sim_table_key(value, c("fixture_id", "match_id", "club_id", "team_id", "tie_group_id", "criterion_order"))
    if (!length(key)) next
    table_hashes[[field]] <- .ucl_sim_canonical_table_hash(value, key = key, schema_tag = paste0("ucl20-state-", field, "-v1"))
  }
  table_names <- sort(names(table_hashes), method = "radix")
  .ucl_sim_sequence_hash(
    c(
      list(graph_hash),
      unname(table_hashes[table_names]),
      list(if (is.list(state)) state$state_cutoff_utc %||% NA_character_ else NA_character_,
           if (is.list(state)) state$edition_id %||% graph$edition_id else graph$edition_id,
           if (is.list(state)) state$source_bundle_id %||% graph$source_bundle_id else graph$source_bundle_id,
           if (is.list(state)) state$authority_mode %||% graph$authority_mode else graph$authority_mode,
           if (is.list(state)) state$fixture_authority %||% graph$fixture_authority else graph$fixture_authority)
    ),
    names = c("graph_sha256", paste0("table_", table_names), "state_cutoff_utc", "edition_id",
              "source_bundle_id", "authority_mode", "fixture_authority"),
    domain = "ucl20-complete-state-v2"
  )
}

.ucl_sim_ledger_table <- function(ledger) {
  if (!is.list(ledger) || !inherits(ledger, "ucl_forecast_ledger")) return(NULL)
  if (!is.data.frame(ledger$ledger)) return(NULL)
  ledger$ledger
}

.ucl_sim_validate_ledger <- function(ledger, graph, information_cutoff_utc) {
  table <- .ucl_sim_ledger_table(ledger)
  if (is.null(table)) return(list(valid = FALSE, reason = "ledger_contract_invalid"))
  if (length(ledger$canonical_hash_version) != 1L ||
      !identical(as.character(ledger$canonical_hash_version), "phase18-canonical-v2")) {
    return(list(valid = FALSE, reason = "ledger_canonical_hash_version_invalid"))
  }
  required_metadata <- c("graph_sha256", "source_bundle_id", "state_cutoff_utc", "table_sha256",
                         "model_release_id", "model_sha256", "calibrator_sha256")
  if (!all(required_metadata %in% names(ledger))) {
    return(list(valid = FALSE, reason = "ledger_metadata_incomplete"))
  }
  metadata_values <- lapply(required_metadata, function(field) ledger[[field]])
  if (any(vapply(metadata_values, function(value) length(value) != 1L || is.null(value) || is.na(value[[1L]]) ||
                 !nzchar(trimws(as.character(value[[1L]]))), logical(1)))) {
    return(list(valid = FALSE, reason = "ledger_metadata_incomplete"))
  }
  if (!identical(as.character(ledger$state_cutoff_utc), as.character(information_cutoff_utc)) ||
      !isTRUE(.ucl_sim_validate_information_cutoff(ledger$state_cutoff_utc)$valid)) {
    return(list(valid = FALSE, reason = "ledger_cutoff_mismatch"))
  }
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(ledger$model_sha256)) ||
      !grepl("^[0-9a-fA-F]{64}$", as.character(ledger$calibrator_sha256))) {
    return(list(valid = FALSE, reason = "ledger_model_lineage_invalid"))
  }
  expected_graph_sha <- as.character(.ucl_sim_graph_content_hash(graph))
  ledger_graph_sha <- as.character(ledger$graph_sha256 %||% "")
  if (length(ledger_graph_sha) != 1L || is.na(ledger_graph_sha) ||
      !grepl("^[0-9a-fA-F]{64}$", ledger_graph_sha) ||
      !identical(tolower(ledger_graph_sha), tolower(expected_graph_sha))) {
    return(list(valid = FALSE, reason = "ledger_graph_lineage_mismatch"))
  }
  ledger_source_bundle <- as.character(ledger$source_bundle_id %||% "")
  if (length(ledger_source_bundle) != 1L || is.na(ledger_source_bundle) ||
      !nzchar(trimws(ledger_source_bundle)) ||
      !identical(ledger_source_bundle, as.character(graph$source_bundle_id))) {
    return(list(valid = FALSE, reason = "ledger_lineage_mismatch"))
  }
  if (!all(c("model_release_id", "model_sha256", "calibrator_sha256") %in% names(ledger))) {
    return(list(valid = FALSE, reason = "ledger_model_lineage_metadata_missing"))
  }
  for (cutoff_field in c("state_cutoff_utc", "information_cutoff_utc")) {
    if (!is.null(ledger[[cutoff_field]]) &&
        !identical(as.character(ledger[[cutoff_field]]), as.character(information_cutoff_utc))) {
      return(list(valid = FALSE, reason = "ledger_cutoff_mismatch"))
    }
  }
  required <- c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc",
                "forecast_status", "suppression_reason", "model_release_id", "model_sha256",
                "calibrator_sha256", "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away",
                "xg_home", "xg_away", "likely_score", "source_bundle_id", "row_sha256")
  missing <- setdiff(required, names(table))
  if (length(missing)) return(list(valid = FALSE, reason = "ledger_schema_incomplete", missing = missing))
  fixture_ids <- as.character(graph$fixtures$fixture_id)
  ledger_ids <- as.character(table$fixture_id)
  if (nrow(table) != length(fixture_ids) || anyNA(ledger_ids) || any(!nzchar(ledger_ids)) || anyDuplicated(ledger_ids) || !setequal(ledger_ids, fixture_ids)) {
    return(list(valid = FALSE, reason = "ledger_coverage_invalid"))
  }
  if (any(as.character(table$edition_id) != as.character(graph$edition_id)) || any(as.character(table$source_bundle_id) != as.character(graph$source_bundle_id))) {
    return(list(valid = FALSE, reason = "ledger_lineage_mismatch"))
  }
  ordered <- table[match(fixture_ids, ledger_ids), , drop = FALSE]
  graph_rows <- graph$fixtures[match(fixture_ids, as.character(graph$fixtures$fixture_id)), , drop = FALSE]
  identity_fields <- c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc")
  for (field in identity_fields) {
    graph_field <- if (field %in% names(graph_rows)) field else if (field == "edition_id") "edition_id" else field
    if (field %in% names(ordered) && graph_field %in% names(graph_rows) && any(as.character(ordered[[field]]) != as.character(graph_rows[[graph_field]]))) {
      return(list(valid = FALSE, reason = "ledger_fixture_identity_mismatch"))
    }
  }
  cutoff_check <- .ucl_sim_validate_information_cutoff(information_cutoff_utc)
  if (!isTRUE(cutoff_check$valid)) return(list(valid = FALSE, reason = cutoff_check$reason))
  row_hashes <- vapply(seq_len(nrow(ordered)), function(index) {
    .ucl_sim_canonical_row_hash(ordered[index, , drop = FALSE], schema_tag = "ucl20-forecast-ledger-row-v1")
  }, character(1))
  observed_hashes <- tolower(as.character(ordered$row_sha256))
  if (anyNA(observed_hashes) || any(!grepl("^[0-9a-f]{64}$", observed_hashes)) || any(observed_hashes != tolower(row_hashes))) {
    return(list(valid = FALSE, reason = "ledger_row_hash_mismatch"))
  }
  status_values <- as.character(ordered$forecast_status)
  allowed_status <- c("available", "eligible", "eligible_fixture", "eligible_production", "forecast_available", "suppressed")
  if (any(is.na(status_values) | !status_values %in% allowed_status)) {
    return(list(valid = FALSE, reason = "ledger_status_invalid"))
  }
  available <- status_values %in% c("available", "eligible", "eligible_fixture", "eligible_production", "forecast_available")
  if (any(!available & (is.na(ordered$suppression_reason) | !nzchar(trimws(as.character(ordered$suppression_reason)))))) {
    return(list(valid = FALSE, reason = "ledger_suppression_reason_missing"))
  }
  if (any(available)) {
    probability_rows <- suppressWarnings(data.matrix(ordered[available, c("prob_home", "prob_draw", "prob_away"), drop = FALSE]))
    if (any(!is.finite(probability_rows)) || any(probability_rows < 0 | probability_rows > 1) ||
        any(abs(rowSums(probability_rows) - 1) > 1e-8)) {
      return(list(valid = FALSE, reason = "ledger_probability_invalid"))
    }
    xg <- suppressWarnings(as.numeric(data.matrix(ordered[available, c("xg_home", "xg_away"), drop = FALSE])))
    if (any(!is.finite(xg)) || any(xg < 0)) return(list(valid = FALSE, reason = "ledger_xg_invalid"))
    likely <- as.character(ordered$likely_score[available])
    if (any(is.na(likely) | !grepl("^[0-9]+-[0-9]+$", likely))) return(list(valid = FALSE, reason = "ledger_likely_score_invalid"))
    feature_values <- as.character(ordered$feature_cutoff_utc[available])
    feature_times <- vapply(feature_values, .ucl_sim_parse_utc, as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"))
    kickoff_times <- vapply(as.character(ordered$kickoff_utc[available]), .ucl_sim_parse_utc, as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"))
    cutoff_time <- .ucl_sim_parse_utc(information_cutoff_utc)
    if (any(is.na(feature_times)) || any(is.na(kickoff_times)) || any(!(feature_times < kickoff_times)) || any(!(feature_times < cutoff_time))) {
      return(list(valid = FALSE, reason = "ledger_cutoff_invalid"))
    }
  }
  supplied_table_hash <- as.character(ledger$table_sha256 %||% "")
  table_hash <- .ucl_sim_canonical_table_hash(ordered, key = "fixture_id", schema_tag = "ucl20-forecast-ledger-v1")
  if (length(supplied_table_hash) != 1L || is.na(supplied_table_hash) ||
      !grepl("^[0-9a-fA-F]{64}$", supplied_table_hash) ||
      !identical(tolower(supplied_table_hash), tolower(table_hash))) {
    return(list(valid = FALSE, reason = "ledger_table_hash_mismatch"))
  }
  if (any(available)) {
    release_ids <- as.character(ordered$model_release_id[available])
    model_hashes <- as.character(ordered$model_sha256[available])
    calibrator_hashes <- as.character(ordered$calibrator_sha256[available])
    if (any(is.na(release_ids) | !nzchar(release_ids)) || length(unique(release_ids)) != 1L ||
        any(!grepl("^[0-9a-fA-F]{64}$", model_hashes)) || length(unique(model_hashes)) != 1L ||
        any(!grepl("^[0-9a-fA-F]{64}$", calibrator_hashes)) || length(unique(calibrator_hashes)) != 1L) {
      return(list(valid = FALSE, reason = "ledger_model_lineage_invalid"))
    }
    if (!identical(as.character(ledger$model_release_id), release_ids[[1L]]) ||
        !identical(tolower(as.character(ledger$model_sha256)), tolower(model_hashes[[1L]])) ||
        !identical(tolower(as.character(ledger$calibrator_sha256)), tolower(calibrator_hashes[[1L]]))) {
      return(list(valid = FALSE, reason = "ledger_model_lineage_mismatch"))
    }
  }
  list(
    valid = TRUE, ledger = ordered,
    table_sha256 = table_hash, canonical_hash_version = "phase18-canonical-v2",
    row_sha256 = row_hashes,
    source_bundle_id = as.character(graph$source_bundle_id),
    model_release_id = if (any(available)) unique(as.character(ordered$model_release_id[available]))[[1L]] else NA_character_,
    model_sha256 = if (any(available)) unique(as.character(ordered$model_sha256[available]))[[1L]] else NA_character_,
    calibrator_sha256 = if (any(available)) unique(as.character(ordered$calibrator_sha256[available]))[[1L]] else NA_character_
  )
}

.ucl_sim_draw_hashes <- function(artifact, rules = NULL) {
  rules <- rules %||% list(draw_policy_id = NA_character_, ruleset_sha256 = NA_character_)
  pairings <- artifact$pairings[order(as.character(artifact$pairings$stage_id), as.character(artifact$pairings$path_id), method = "radix"), , drop = FALSE]
  rank_inputs <- artifact$rank_inputs[order(as.character(artifact$rank_inputs$club_id), method = "radix"), , drop = FALSE]
  pairings_hash <- .ucl_sim_canonical_table_hash(pairings, key = "path_id", schema_tag = "ucl20-accepted-draw-pairings-v1")
  rank_hash <- .ucl_sim_canonical_table_hash(rank_inputs, key = "club_id", schema_tag = "ucl20-accepted-draw-ranks-v1")
  content_hash <- .ucl_sim_sequence_hash(
    list(artifact$edition_id, artifact$source_bundle_id, artifact$draw_artifact_id %||% artifact$artifact_id,
         artifact$source_artifact_ids, rules$draw_policy_id, rules$ruleset_sha256, pairings_hash, rank_hash),
    names = c("edition_id", "source_bundle_id", "draw_artifact_id", "source_artifact_ids", "draw_policy_id", "ruleset_sha256", "pairings_sha256", "rank_inputs_sha256"),
    domain = "ucl20-accepted-draw-v1"
  )
  list(pairings_sha256 = pairings_hash, rank_input_sha256 = rank_hash, draw_artifact_sha256 = content_hash)
}

.ucl_sim_stage_inventory <- function() {
  c(knockout_play_off = 8L, round_of_16 = 8L, quarter_final = 4L,
    semi_final = 2L, final = 1L, champion = 1L)
}

.ucl_sim_stage_order <- function(stage_id) {
  match(as.character(stage_id), names(.ucl_sim_stage_inventory()))
}

.ucl_sim_suppressed_stage_events <- function(reason, rules, source_bundle_id, run_id, draw = NULL) {
  inventory <- .ucl_sim_stage_inventory()
  rows <- lapply(names(inventory), function(stage_id) {
    n <- inventory[[stage_id]]
    do.call(rbind, lapply(seq_len(n), function(index) {
      .ucl_record_stage_event(
        list(status = "suppressed", reason = reason, participant_a = NA_character_, participant_b = NA_character_,
             leg_order = if (stage_id == "champion") "single_neutral" else "seeded_return_leg",
             ruleset_sha256 = rules$ruleset_sha256),
        stage_id = stage_id, stage_event_id = sprintf("%s-%02d", stage_id, index),
        seed_slot_id = sprintf("%s-slot-%02d", stage_id, index), draw_policy_id = rules$draw_policy_id,
        draw_artifact_id = if (is.null(draw)) NA_character_ else draw$draw_artifact_id,
        draw_artifact_sha256 = if (is.null(draw)) NA_character_ else draw$draw_artifact_sha256,
        source_artifact_ids = NA_character_, source_bundle_id = source_bundle_id,
        simulation_run_id = run_id
      )
    }))
  })
  result <- do.call(rbind, rows)
  result$status <- result$path_status
  row.names(result) <- NULL
  result
}

.ucl_sim_accepted_stage_events <- function(draw, paths, rules, source_bundle_id, run_id) {
  pairings <- draw$pairings
  pairings <- pairings[order(.ucl_sim_stage_order(pairings$stage_id), as.character(pairings$path_id), method = "radix"), , drop = FALSE]
  event_rows <- lapply(seq_len(nrow(pairings)), function(index) {
    row <- pairings[index, , drop = FALSE]
    resolution <- as.list(row[1L, , drop = FALSE])
    resolution$status <- "unresolved"
    resolution$reason <- "knockout_score_evidence_missing"
    resolution$ruleset_sha256 <- rules$ruleset_sha256
    .ucl_record_stage_event(
      resolution, stage_id = as.character(row$stage_id[[1L]]), stage_event_id = as.character(row$path_id[[1L]]),
      seed_slot_id = as.character(row$seed_slot_id[[1L]]), draw_policy_id = rules$draw_policy_id,
      draw_artifact_id = draw$draw_artifact_id, draw_artifact_sha256 = draw$draw_artifact_sha256,
      source_artifact_ids = as.character(row$source_artifact_ids[[1L]]), source_bundle_id = source_bundle_id,
      simulation_run_id = run_id
    )
  })
  generated <- list(
    quarter_final = c("winner:r16-01-v-winner:r16-02", "winner:r16-03-v-winner:r16-04", "winner:r16-05-v-winner:r16-06", "winner:r16-07-v-winner:r16-08"),
    semi_final = c("winner:quarter_final-01-v-winner:quarter_final-02", "winner:quarter_final-03-v-winner:quarter_final-04"),
    final = "winner:semi_final-01-v-winner:semi_final-02",
    champion = "winner:final-01"
  )
  for (stage_id in names(generated)) {
    values <- generated[[stage_id]]
    for (index in seq_along(values)) {
      participants <- strsplit(values[[index]], "-v-", fixed = TRUE)[[1L]]
      if (stage_id == "champion") participants <- c(values[[index]], NA_character_)
      event_rows[[length(event_rows) + 1L]] <- .ucl_record_stage_event(
        list(status = "unresolved", reason = "knockout_score_evidence_missing",
             participant_a = participants[[1L]], participant_b = participants[[2L]],
             leg_order = if (stage_id == "final" || stage_id == "champion") "single_neutral" else "seeded_return_leg",
             ruleset_sha256 = rules$ruleset_sha256),
        stage_id = stage_id, stage_event_id = sprintf("%s-%02d", stage_id, index),
        seed_slot_id = sprintf("%s-slot-%02d", stage_id, index), draw_policy_id = rules$draw_policy_id,
        draw_artifact_id = draw$draw_artifact_id, draw_artifact_sha256 = draw$draw_artifact_sha256,
        source_artifact_ids = as.character(draw$source_artifact_ids %||% NA_character_),
        source_bundle_id = source_bundle_id, simulation_run_id = run_id
      )
    }
  }
  result <- do.call(rbind, event_rows)
  result$status <- result$path_status
  row.names(result) <- NULL
  result
}

.ucl_sim_build_progression <- function(rank_rows, club_ids, rules, draw, source_bundle_id, run_id, simulations, seed) {
  club_ids <- sort(unique(as.character(club_ids)), method = "radix")
  if (!length(club_ids)) return(data.frame())
  stages <- c("direct_round_of_16", "knockout_play_off", "eliminated", "round_of_16", "quarter_final", "semi_final", "final", "champion")
  rows <- lapply(club_ids, function(club) {
    values <- rank_rows[as.character(rank_rows$club_id) == club, , drop = FALSE]
    valid <- nrow(values) == length(unique(rank_rows$iteration)) && nrow(values) > 0L &&
      all(is.finite(as.numeric(values$rank))) && all(as.character(values$rank_status) != "unresolved")
    band_probability <- if (valid) vapply(stages[1:3], function(band) mean(as.character(values$qualification_band) == band), numeric(1)) else rep(NA_real_, 3L)
    later_status <- if (identical(draw$status, "accepted")) "unresolved" else "suppressed"
    later_reason <- if (identical(draw$status, "accepted")) "knockout_score_evidence_missing" else as.character(draw$reason %||% "missing_edition_draw_procedure")
    data.frame(
      edition_id = rules$edition_id, club_id = club, stage_id = stages,
      probability = c(band_probability, rep(NA_real_, length(stages) - 3L)),
      status = c(if (valid) rep("resolved", 3L) else rep("unresolved", 3L), rep(later_status, length(stages) - 3L)),
      qualification_band = c(stages[1:3], rep(NA_character_, length(stages) - 3L)),
      unresolved_reason = c(rep(NA_character_, 3L), rep(later_reason, length(stages) - 3L)),
      stage_order = c(1, 1, 0, 2, 3, 4, 5, 6), source_bundle_id = source_bundle_id,
      ruleset_sha256 = rules$ruleset_sha256,
      draw_artifact_sha256 = if (identical(draw$status, "accepted")) draw$draw_artifact_sha256 else NA_character_,
      simulation_count = as.integer(simulations), seed = as.integer(seed), run_id = run_id,
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  result <- do.call(rbind, rows)
  row.names(result) <- NULL
  result
}

#' Run a seeded conditional league-phase simulation.
ucl_run_simulation <- function(state, ledger = NULL, simulations = 1L, seed = 20260921L,
                               rules = NULL, draw_artifact = NULL, source_bundle_id = NULL,
                               information_cutoff_utc = NULL) {
  if (is.list(state) && !is.data.frame(state) && !is.null(state$status) &&
      !identical(as.character(state$status), "ready")) {
    return(structure(list(
      status = "blocked", reason = as.character(state$reason_code %||% state$reason %||% "state_not_ready"),
      simulations = data.frame(), rank_rows = data.frame(), knockout_paths = data.frame(),
      stage_events = data.frame(), progression_probabilities = data.frame(),
      metadata = list(status = "blocked", state_reason = as.character(state$reason_code %||% state$reason %||% "state_not_ready")),
      graph = state$graph %||% NULL, production_eligible = FALSE
    ), class = c("ucl_simulation_run", "list")))
  }
  graph <- if (is.list(state) && !is.data.frame(state) && !is.null(state$graph)) state$graph else state
  validation <- ucl_validate_schedule(graph, rules = rules)
  if (!identical(validation$status, "ready")) return(list(status = "blocked", reason = validation$reason_code, simulations = data.frame(), metadata = list()))
  if (!is.null(source_bundle_id) && !identical(as.character(source_bundle_id), as.character(validation$graph$source_bundle_id))) {
    return(structure(list(
      status = "blocked", reason = "source_bundle_mismatch", simulations = data.frame(), rank_rows = data.frame(),
      knockout_paths = data.frame(), stage_events = data.frame(), progression_probabilities = data.frame(),
      metadata = list(status = "blocked", source_bundle_id = as.character(source_bundle_id), expected_source_bundle_id = as.character(validation$graph$source_bundle_id)),
      graph = validation$graph, production_eligible = FALSE
    ), class = c("ucl_simulation_run", "list")))
  }
  cutoff <- .ucl_sim_validate_information_cutoff(information_cutoff_utc)
  if (!isTRUE(cutoff$valid)) {
    return(structure(list(
      status = "blocked", reason = cutoff$reason, simulations = data.frame(), rank_rows = data.frame(),
      knockout_paths = data.frame(), stage_events = data.frame(), progression_probabilities = data.frame(),
      metadata = list(status = "blocked", information_cutoff_utc = cutoff$value, cutoff_reason = cutoff$reason),
      graph = validation$graph, production_eligible = FALSE
    ), class = c("ucl_simulation_run", "list")))
  }
  ledger_authority <- if (is.list(ledger) && !is.null(ledger$authority)) ledger$authority else list()
  ledger_check <- .ucl_sim_validate_ledger(ledger, validation$graph, cutoff$value)
  if (!isTRUE(ledger_check$valid)) {
    return(structure(list(
      status = "blocked", reason = ledger_check$reason, simulations = data.frame(), rank_rows = data.frame(),
      knockout_paths = data.frame(), stage_events = data.frame(), progression_probabilities = data.frame(),
      metadata = list(status = "blocked", information_cutoff_utc = cutoff$value, ledger_reason = ledger_check$reason),
      graph = validation$graph, production_eligible = FALSE
    ), class = c("ucl_simulation_run", "list")))
  }
  ledger_table <- ledger_check$ledger
  simulations <- as.integer(simulations)
  if (length(simulations) != 1L || is.na(simulations) || simulations < 1L || simulations > 100000L) stop("UCL simulation count must be between 1 and 100000", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else NULL
  source_bundle_id <- source_bundle_id %||% validation$graph$source_bundle_id
  graph_hash <- .ucl_sim_graph_content_hash(validation$graph)
  state_hash <- .ucl_sim_state_content_hash(state, validation$graph)
  draw <- ucl_validate_draw_artifact(draw_artifact, rules = rules, source_bundle_id = source_bundle_id)
  draw_identity <- if (identical(draw$status, "accepted")) draw$draw_artifact_sha256 else paste0("unresolved:", draw$reason %||% "unknown")
  run_id <- .ucl_sim_sequence_hash(
    list(
      state_hash, ledger_check$table_sha256, source_bundle_id,
      ledger_check$model_release_id, ledger_check$model_sha256, ledger_check$calibrator_sha256,
      if (is.null(rules)) NA_character_ else rules$ruleset_sha256,
      draw_identity, if (identical(draw$status, "accepted")) draw$rank_input_sha256 else NA_character_,
      as.integer(seed), simulations, cutoff$value, "ucl-conditional-league-v3"
    ),
    names = c("state_sha256", "ledger_sha256", "source_bundle_id", "model_release_id", "model_sha256", "calibrator_sha256", "ruleset_sha256", "draw_identity", "rank_input_sha256", "seed", "simulation_count", "information_cutoff_utc", "algorithm_version"),
    domain = "ucl20-simulation-run-v3"
  )
  iteration_results <- lapply(seq_len(simulations), function(iteration) {
    graph_i <- .ucl_sim_iteration_graph(validation$graph, ledger_table, seed = seed, cutoff_utc = cutoff$value, iteration = iteration)
    built <- if (exists("ucl_build_state", mode = "function")) ucl_build_state(graph_i, rules = rules, state_cutoff_utc = cutoff$value) else NULL
    list(graph = graph_i, rows = if (is.null(built) || !identical(built$status, "ready")) data.frame() else .ucl_sim_rank_rows(built$standings, iteration, run_id))
  })
  rows <- do.call(rbind, lapply(iteration_results, `[[`, "rows")); if (is.null(rows)) rows <- data.frame(); row.names(rows) <- NULL
  path_state <- ucl_enumerate_legal_knockout_paths(if (nrow(rows)) rows[rows$iteration == max(rows$iteration), , drop = FALSE] else data.frame(), draw_artifact = draw_artifact, rules = rules, source_bundle_id = source_bundle_id, seed = seed)
  draw_conditioned <- identical(draw$status, "accepted") && is.data.frame(path_state) && nrow(path_state) == 16L &&
    all(as.character(path_state$path_status) == "accepted_draw")
  stage_draw <- if (draw_conditioned) draw else list(status = "unresolved", reason = if (identical(draw$status, "accepted")) "draw_rank_input_mismatch" else draw$reason)
  stage_events <- if (draw_conditioned) {
    .ucl_sim_accepted_stage_events(draw, path_state, rules, source_bundle_id, run_id)
  } else {
    .ucl_sim_suppressed_stage_events(stage_draw$reason %||% "missing_edition_draw_procedure", rules, source_bundle_id, run_id, draw = if (identical(draw$status, "accepted")) draw else NULL)
  }
  stage_inputs <- .ucl_sim_stage_inventory()
  stage_reconciliation <- ucl_aggregate_stage_events(stage_events, rules = rules, stage_inputs = stage_inputs, league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L), required_stage_ids = names(stage_inputs))
  progression <- .ucl_sim_build_progression(rows, validation$graph$clubs$club_id, rules, stage_draw, source_bundle_id, run_id, simulations, seed)
  progression_reconciliation <- ucl_validate_progression_reconciliation(
    progression, stage_inputs = stage_inputs,
    league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L),
    required_stage_ids = names(stage_inputs)
  )
  sampling <- lapply(iteration_results, function(result) attr(result$graph, "ucl_sampling"))
  path_statuses <- if (is.data.frame(path_state) && nrow(path_state)) as.character(path_state$path_status) else character()
  unresolved_draw <- !draw_conditioned && (length(path_statuses) == 0L || any(path_statuses %in% c("pre_draw_legal", "unresolved")))
  if (!isTRUE(attr(stage_reconciliation, "valid")) || !isTRUE(progression_reconciliation$valid)) {
    stage_reason <- c(attr(stage_reconciliation, "errors"), progression_reconciliation$errors)
    return(structure(list(
      status = "blocked", reason = unique(stage_reason), run_id = run_id, rank_rows = rows, simulations = rows,
      knockout_paths = stage_events, legal_paths = path_state, stage_events = stage_events, progression_probabilities = progression,
      stage_reconciliation = stage_reconciliation, progression_reconciliation = progression_reconciliation,
      metadata = list(status = "blocked", run_id = run_id, graph_sha256 = graph_hash, state_sha256 = state_hash, ledger_sha256 = ledger_check$table_sha256,
                      information_cutoff_utc = cutoff$value, stage_errors = unique(stage_reason)),
      graph = validation$graph, ledger = ledger_table, fixture_sampling = sampling,
      fixture_authority = isTRUE(validation$graph$fixture_authority), production_eligible = FALSE
    ), class = c("ucl_simulation_run", "list")))
  }
  metadata <- list(
    run_id = run_id, graph_sha256 = graph_hash, state_sha256 = state_hash, ledger_sha256 = ledger_check$table_sha256,
    edition_id = validation$graph$edition_id, source_bundle_id = source_bundle_id,
    ruleset_version = if (is.null(rules)) NA_character_ else rules$ruleset_version,
    ruleset_sha256 = if (is.null(rules)) NA_character_ else rules$ruleset_sha256,
    draw_policy_id = if (is.null(rules)) "ucl-2026-27-article19-annexb-v1" else rules$draw_policy_id,
    draw_artifact_id = if (identical(draw$status, "accepted")) draw$draw_artifact_id else NA_character_,
    draw_artifact_sha256 = if (identical(draw$status, "accepted")) draw$draw_artifact_sha256 else NA_character_,
    information_cutoff_utc = cutoff$value, algorithm_version = "ucl-conditional-league-v3",
    simulation_count = simulations, seed = as.integer(seed), path_policy_id = attr(path_state, "path_policy")$policy_id %||% "ucl-2026-27-article19-annexb-v1",
    path_policy_count = if (is.data.frame(path_state)) nrow(path_state) else 0L,
    path_policy_mode = attr(path_state, "path_policy")$mode %||% "unresolved",
    path_policy_seed = as.integer(seed), legality_checks = TRUE,
    authority_mode = as.character(validation$graph$authority_mode), production_eligible = FALSE,
    original_parent_reason = as.character(ledger_authority$original_parent_reason %||% ledger_authority$parent_reason %||% NA_character_),
    human_needed_reason = as.character(ledger_authority$human_needed_reason %||% NA_character_),
    model_release_id = ledger_check$model_release_id, model_sha256 = ledger_check$model_sha256,
    calibrator_sha256 = ledger_check$calibrator_sha256,
    stage_event_count = nrow(stage_events), progression_row_count = nrow(progression),
    status = if (unresolved_draw) "unresolved_draw_procedure" else "ready"
  )
  structure(list(status = metadata$status, run_id = run_id, rank_rows = rows, simulations = rows,
                 knockout_paths = stage_events, legal_paths = path_state, stage_events = stage_events, progression_probabilities = progression,
                 stage_reconciliation = stage_reconciliation, progression_reconciliation = progression_reconciliation,
                 metadata = metadata, graph = validation$graph, state_sha256 = state_hash,
                 graph_sha256 = graph_hash,
                 ledger = ledger_table, fixture_sampling = sampling,
                 club_ids = sort(as.character(validation$graph$clubs$club_id), method = "radix"),
                 fixture_authority = isTRUE(validation$graph$fixture_authority), production_eligible = FALSE),
            class = c("ucl_simulation_run", "list"))
}

#' Aggregate rank, band, and cut-line probabilities from simulation rows.
ucl_aggregate_rank_distributions <- function(simulation, rules = NULL, club_ids = NULL) {
  rows <- if (is.list(simulation) && is.data.frame(simulation$rank_rows)) simulation$rank_rows else simulation
  if (!is.data.frame(rows) || !nrow(rows)) return(list(status = "unresolved", reason = "rank_rows_empty", rank_distribution = data.frame(), band_probabilities = data.frame(), cutline_distributions = list(), cutline = data.frame()))
  required_columns <- c("iteration", "edition_id", "club_id", "rank", "rank_status", "qualification_band")
  if (!all(required_columns %in% names(rows))) return(list(status = "unresolved", reason = "rank_schema_incomplete", rank_distribution = data.frame(), band_probabilities = data.frame(), cutline_distributions = list(), cutline = data.frame()))
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(cardinality = list(clubs = 36L))
  club_count <- as.integer(rules$cardinality$clubs %||% 36L)
  authoritative <- club_ids
  if (is.null(authoritative) && is.list(simulation) && !is.null(simulation$club_ids)) authoritative <- simulation$club_ids
  if (is.null(authoritative) && is.list(simulation) && is.list(simulation$graph) && is.data.frame(simulation$graph$clubs)) authoritative <- simulation$graph$clubs$club_id
  if (is.null(authoritative) && is.list(rules) && !is.null(rules$club_ids)) authoritative <- rules$club_ids
  authoritative <- sort(unique(as.character(authoritative %||% character())), method = "radix")
  iterations <- sort(unique(suppressWarnings(as.integer(rows$iteration))), method = "radix")
  if (length(authoritative) != club_count || anyNA(authoritative) || any(!nzchar(authoritative)) ||
      !length(iterations) || anyNA(iterations)) {
    return(list(status = "blocked", reason = "authoritative_club_ids_missing", rank_distribution = data.frame(), band_probabilities = data.frame(), cutline_distributions = list(), cutline = data.frame(), simulation_count = length(iterations), run_id = if (is.list(simulation)) simulation$run_id %||% NA_character_ else NA_character_))
  }
  band_levels <- c("direct_round_of_16", "knockout_play_off", "eliminated")
  complete_iteration <- vapply(iterations, function(iteration) {
    values <- rows[suppressWarnings(as.integer(rows$iteration)) == iteration, , drop = FALSE]
    ids <- as.character(values$club_id); ranks <- suppressWarnings(as.integer(values$rank))
    nrow(values) == club_count && !anyNA(ids) && !anyDuplicated(ids) && setequal(ids, authoritative) &&
      !anyNA(ranks) && !anyDuplicated(ranks) && identical(sort(ranks), seq_len(club_count)) &&
      all(as.character(values$rank_status) == "resolved") && all(!is.na(values$qualification_band))
  }, logical(1))
  complete <- all(complete_iteration %in% TRUE)
  status_for <- function(values) {
    !isTRUE(complete) || nrow(values) != length(iterations) || any(is.na(values$rank) | as.character(values$rank_status) != "resolved" | is.na(values$qualification_band))
  }
  rank_distribution <- do.call(rbind, lapply(authoritative, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    unresolved <- status_for(values)
    probability <- if (unresolved) rep(NA_real_, club_count) else vapply(seq_len(club_count), function(rank) mean(as.integer(values$rank) == rank), numeric(1))
    data.frame(edition_id = as.character(values$edition_id[[1L]] %||% NA_character_), club_id = club, rank = seq_len(club_count), probability = probability, status = if (unresolved) "unresolved" else "resolved", stringsAsFactors = FALSE, check.names = FALSE)
  }))
  band_probabilities <- do.call(rbind, lapply(authoritative, function(club) {
    values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
    unresolved <- status_for(values)
    probability <- if (unresolved) rep(NA_real_, length(band_levels)) else vapply(band_levels, function(band) mean(as.character(values$qualification_band) == band), numeric(1))
    data.frame(club_id = club, qualification_band = band_levels, probability = probability, status = if (unresolved) "unresolved" else "resolved", stringsAsFactors = FALSE, check.names = FALSE)
  }))
  cutline_distributions <- setNames(lapply(c(8L, 24L), function(boundary) {
    data.frame(cutline = boundary, club_id = authoritative, probability = vapply(authoritative, function(club) {
      values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
      if (status_for(values)) return(NA_real_)
      mean(as.integer(values$rank) == boundary)
    }, numeric(1)), status = vapply(authoritative, function(club) {
      values <- rows[as.character(rows$club_id) == club, , drop = FALSE]
      if (status_for(values)) "unresolved" else "resolved"
    }, character(1)), stringsAsFactors = FALSE, check.names = FALSE)
  }), c("rank_8", "rank_24"))
  cutline <- do.call(rbind, cutline_distributions)
  list(status = if (complete) "ready" else "unresolved", reason = if (complete) NA_character_ else "rank_permutation_incomplete", rank_distribution = rank_distribution,
       band_probabilities = band_probabilities, cutline_distributions = cutline_distributions, cutline = cutline, simulation_count = length(iterations),
       run_id = if (is.list(simulation)) simulation$run_id %||% NA_character_ else NA_character_, club_ids = authoritative)
}

.ucl_sim_rank_value <- function(rankings, club_id) {
  row <- rankings[as.character(rankings$club_id) == as.character(club_id), , drop = FALSE]
  if (nrow(row) != 1L) return(NA_integer_)
  status <- as.character(row$rank_status[[1L]] %||% "resolved")
  if (!is.na(row$rank[[1L]]) && status != "unresolved") return(as.integer(row$rank[[1L]]))
  lo <- as.integer(row$rank_interval_min[[1L]]); hi <- as.integer(row$rank_interval_max[[1L]])
  if (is.na(lo) || is.na(hi) || lo != hi || status == "unresolved") return(NA_integer_)
  lo
}

.ucl_unresolved_path <- function(rules, source_bundle_id, reason = "unresolved_rank_interval") {
  data.frame(edition_id = rules$edition_id, path_id = "pre-draw-unresolved", stage_id = "knockout_play_off", seed_slot_id = NA_character_, bracket_position = NA_character_, participant_a = NA_character_, participant_b = NA_character_, seed_rank = NA_integer_, opponent_rank = NA_integer_, leg_order = NA_character_, draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "unresolved", unresolved_reason = reason, source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
}

.ucl_validate_legal_path <- function(path, rules = NULL, rank_lookup = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27", draw_policy_id = "ucl-2026-27-article19-annexb-v1", ruleset_sha256 = NA_character_)
  if (!is.data.frame(path) || nrow(path) != 1L || !all(c("stage_id", "participant_a", "participant_b", "leg_order", "bracket_position") %in% names(path))) return(FALSE)
  path_status <- if ("path_status" %in% names(path)) as.character(path$path_status[[1L]]) else "accepted_draw"
  if (path_status == "unresolved") return(FALSE)
  stage <- as.character(path$stage_id[[1L]])
  participant_a <- as.character(path$participant_a[[1L]])
  participant_b <- as.character(path$participant_b[[1L]])
  leg_order <- as.character(path$leg_order[[1L]])
  bracket_position <- as.character(path$bracket_position[[1L]])
  if (anyNA(c(stage, participant_a, participant_b, leg_order, bracket_position)) ||
      any(!nzchar(trimws(c(stage, participant_a, participant_b, leg_order, bracket_position)))) ||
      !identical(leg_order, "seeded_return_leg")) return(FALSE)
  seed_rank <- suppressWarnings(as.integer(path$seed_rank[[1L]])); opponent_rank <- suppressWarnings(as.integer(path$opponent_rank[[1L]]))
  if (stage == "knockout_play_off") {
    policy <- .ucl_rule_draw_policy(rules); families <- policy$playoff_pair_families
    valid_family <- nrow(families) == 4L && any(seed_rank >= families$seed_rank_min & seed_rank <= families$seed_rank_max & opponent_rank >= families$opponent_rank_min & opponent_rank <= families$opponent_rank_max & bracket_position == as.character(families$bracket_position))
    if (!is.null(rank_lookup)) {
      a_rank <- if (!is.null(names(rank_lookup)) && participant_a %in% names(rank_lookup)) rank_lookup[[participant_a]] else NA_integer_
      b_rank <- if (!is.null(names(rank_lookup)) && participant_b %in% names(rank_lookup)) rank_lookup[[participant_b]] else NA_integer_
      if (is.na(a_rank) || is.na(b_rank) || a_rank != seed_rank || b_rank != opponent_rank) return(FALSE)
    }
    return(isTRUE(valid_family) && !identical(participant_a, participant_b))
  }
  if (stage == "round_of_16") {
    policy <- .ucl_rule_draw_policy(rules); pairs <- policy$round_of_16_seed_pairs
    valid_position <- bracket_position %in% c(as.character(pairs$bracket_position_a), as.character(pairs$bracket_position_b))
    if (!is.null(rank_lookup)) {
      a_rank <- if (!is.null(names(rank_lookup)) && participant_a %in% names(rank_lookup)) rank_lookup[[participant_a]] else NA_integer_
      if (is.na(a_rank) || a_rank != seed_rank) return(FALSE)
    }
    return(seed_rank %in% 1:8 && is.na(opponent_rank) && valid_position && grepl("^winner:", participant_b))
  }
  FALSE
}

#' Enumerate only rank-compatible play-off and round-of-16 path families.
ucl_enumerate_legal_knockout_paths <- function(rankings, draw_artifact = NULL, rules = NULL, seed = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27", ruleset_sha256 = NA_character_, draw_policy_id = "ucl-2026-27-article19-annexb-v1")
  draw <- ucl_validate_draw_artifact(draw_artifact, rules = rules, source_bundle_id = source_bundle_id)
  if (identical(draw$status, "accepted")) {
    if (!is.data.frame(rankings) || nrow(rankings) != 36L || !all(c("club_id", "rank") %in% names(rankings))) {
      return(.ucl_unresolved_path(rules, source_bundle_id, "draw_rank_input_missing"))
    }
    if (is.data.frame(rankings) && nrow(rankings) && all(c("club_id", "rank") %in% names(rankings))) {
      passed <- setNames(vapply(as.character(rankings$club_id), function(club) .ucl_sim_rank_value(rankings, club), integer(1)), as.character(rankings$club_id))
      expected <- setNames(as.integer(draw$rank_inputs$rank), as.character(draw$rank_inputs$club_id))
      if (length(passed) != length(expected) || !setequal(names(passed), names(expected)) || anyNA(passed) || anyNA(expected) || any(passed[names(expected)] != expected)) return(.ucl_unresolved_path(rules, source_bundle_id, "draw_rank_input_mismatch"))
    }
    output <- draw$pairings
    output$edition_id <- rules$edition_id; output$draw_policy_id <- rules$draw_policy_id; output$draw_artifact_id <- draw$draw_artifact_id; output$draw_artifact_sha256 <- draw$draw_artifact_sha256; output$path_status <- "accepted_draw"; output$unresolved_reason <- NA_character_; output$source_bundle_id <- source_bundle_id %||% draw$source_bundle_id %||% NA_character_; output$ruleset_sha256 <- rules$ruleset_sha256
    attr(output, "path_policy") <- list(policy_id = rules$draw_policy_id, mode = "accepted_draw_conditioning", count = nrow(output), seed = seed %||% NA_integer_)
    return(output)
  }
  if (!is.data.frame(rankings) || !nrow(rankings) || !all(c("club_id", "rank") %in% names(rankings))) return(.ucl_unresolved_path(rules, source_bundle_id, draw$reason %||% "unresolved_rank_interval"))
  club_rank <- setNames(vapply(as.character(rankings$club_id), function(club) .ucl_sim_rank_value(rankings, club), integer(1)), as.character(rankings$club_id))
  if (anyNA(club_rank) || anyDuplicated(club_rank) || !identical(sort(as.integer(club_rank)), seq_len(36L))) return(.ucl_unresolved_path(rules, source_bundle_id, if (identical(draw$reason, "missing_edition_draw_procedure")) "unresolved_rank_interval" else draw$reason %||% "unresolved_rank_interval"))
  by_rank <- setNames(names(club_rank), as.character(club_rank)); policy <- .ucl_rule_draw_policy(rules); rows <- list(); index <- 0L
  families <- policy$playoff_pair_families
  for (family_index in seq_len(nrow(families))) {
    family <- families[family_index, , drop = FALSE]
    for (seed_rank in family$seed_rank_min:family$seed_rank_max) for (opponent_rank in family$opponent_rank_min:family$opponent_rank_max) {
      index <- index + 1L
      rows[[index]] <- data.frame(edition_id = rules$edition_id, path_id = sprintf("playoff-%02d", index), stage_id = "knockout_play_off", seed_slot_id = paste0("playoff-seed-", sprintf("%02d", seed_rank)), bracket_position = as.character(family$bracket_position), participant_a = by_rank[[as.character(seed_rank)]], participant_b = by_rank[[as.character(opponent_rank)]], seed_rank = as.integer(seed_rank), opponent_rank = as.integer(opponent_rank), leg_order = "seeded_return_leg", draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "pre_draw_legal", unresolved_reason = "missing_edition_draw_procedure", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  pairs <- policy$round_of_16_seed_pairs
  for (pair_index in seq_len(nrow(pairs))) {
    pair <- pairs[pair_index, , drop = FALSE]
    for (position_index in 1:2) {
      seed_rank <- if (position_index == 1L) pair$seed_rank_min else pair$seed_rank_max
      bracket <- if (position_index == 1L) pair$bracket_position_a else pair$bracket_position_b
      index <- index + 1L
      rows[[index]] <- data.frame(edition_id = rules$edition_id, path_id = sprintf("r16-%02d", index - 16L), stage_id = "round_of_16", seed_slot_id = as.character(pair$seed_pair_id), bracket_position = as.character(bracket), participant_a = by_rank[[as.character(seed_rank)]], participant_b = paste0("winner:playoff-", sprintf("%02d", ((pair_index - 1L) * 4L) + position_index)), seed_rank = as.integer(seed_rank), opponent_rank = NA_integer_, leg_order = "seeded_return_leg", draw_policy_id = rules$draw_policy_id, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, path_status = "pre_draw_legal", unresolved_reason = "missing_edition_draw_procedure", source_bundle_id = source_bundle_id %||% NA_character_, ruleset_sha256 = rules$ruleset_sha256, stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  output <- do.call(rbind, rows); row.names(output) <- NULL
  attr(output, "path_policy") <- list(policy_id = rules$draw_policy_id, mode = "deterministic_pre_draw_enumeration", count = nrow(output), seed = seed %||% NA_integer_, legality_checks = TRUE)
  output
}

#' Validate a same-edition accepted draw or return a typed unresolved state.
ucl_validate_draw_artifact <- function(draw_artifact = NULL, rules = NULL, source_bundle_id = NULL) {
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(edition_id = "ucl_2026_27")
  if (is.null(draw_artifact)) return(list(status = "unresolved", reason = "missing_edition_draw_procedure", draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  if (is.list(draw_artifact) && identical(as.character(draw_artifact$status %||% ""), "unresolved") && !is.null(draw_artifact$reason)) return(list(status = "unresolved", reason = as.character(draw_artifact$reason), draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_))
  if (!is.list(draw_artifact) || !is.data.frame(draw_artifact$pairings)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  artifact <- draw_artifact; pairings <- artifact$pairings
  required <- c("path_id", "stage_id", "seed_slot_id", "bracket_position", "participant_a", "participant_b", "seed_rank", "opponent_rank", "leg_order", "leg_1_venue_id", "leg_2_venue_id", "source_artifact_ids")
  if (!all(required %in% names(pairings)) || !nrow(pairings) || anyNA(pairings$path_id) || anyDuplicated(as.character(pairings$path_id)) || any(!nzchar(trimws(as.character(pairings$path_id))))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  artifact_bundle <- as.character(artifact$source_bundle_id %||% "")
  if (!identical(as.character(artifact$edition_id %||% ""), as.character(rules$edition_id)) ||
      length(artifact_bundle) != 1L || is.na(artifact_bundle) || !nzchar(trimws(artifact_bundle)) ||
      (!is.null(source_bundle_id) && !identical(artifact_bundle, as.character(source_bundle_id)))) return(list(status = "unresolved", reason = "foreign_lineage"))
  if (!isTRUE(artifact$accepted) || !isTRUE(artifact$complete)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  draw_id <- as.character(artifact$draw_artifact_id %||% artifact$artifact_id %||% ""); hash <- as.character(artifact$draw_artifact_sha256 %||% artifact$artifact_sha256 %||% "")
  if (!nzchar(draw_id) || !grepl("^[0-9a-f]{64}$", hash)) return(list(status = "unresolved", reason = "stale_draw_artifact"))
  rank_inputs <- artifact$rank_inputs
  if (!is.data.frame(rank_inputs) || !identical(names(rank_inputs)[1:2], c("club_id", "rank")) || nrow(rank_inputs) != 36L || anyNA(rank_inputs$club_id) || any(!nzchar(trimws(as.character(rank_inputs$club_id)))) || anyDuplicated(as.character(rank_inputs$club_id)) || anyNA(rank_inputs$rank) || anyDuplicated(as.integer(rank_inputs$rank)) || !identical(sort(as.integer(rank_inputs$rank)), seq_len(36L)) || !grepl("^[0-9a-f]{64}$", as.character(artifact$rank_input_sha256 %||% ""))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  rank_map <- setNames(as.integer(rank_inputs$rank), as.character(rank_inputs$club_id))
  if (length(rank_map) != 36L || anyDuplicated(names(rank_map)) || !identical(sort(unname(rank_map)), seq_len(36L))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  stage_values <- as.character(pairings$stage_id)
  if (!all(stage_values %in% c("knockout_play_off", "round_of_16")) || sum(stage_values == "knockout_play_off") != 8L || sum(stage_values == "round_of_16") != 8L) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  if (any(is.na(pairings$seed_slot_id) | !nzchar(trimws(as.character(pairings$seed_slot_id)))) || anyDuplicated(as.character(pairings$seed_slot_id))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  artifact_sources <- as.character(artifact$source_artifact_ids %||% "")
  if (any(is.na(pairings$source_artifact_ids) | !nzchar(trimws(as.character(pairings$source_artifact_ids)))) || length(artifact_sources) != 1L || is.na(artifact_sources) || !nzchar(trimws(artifact_sources)) || any(as.character(pairings$source_artifact_ids) != artifact_sources)) return(list(status = "unresolved", reason = "foreign_lineage"))
  if (any(is.na(pairings$leg_1_venue_id) | !nzchar(trimws(as.character(pairings$leg_1_venue_id)))) || any(is.na(pairings$leg_2_venue_id) | !nzchar(trimws(as.character(pairings$leg_2_venue_id))))) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  playoff <- pairings[stage_values == "knockout_play_off", , drop = FALSE]
  r16 <- pairings[stage_values == "round_of_16", , drop = FALSE]
  policy <- .ucl_rule_draw_policy(rules)
  expected_playoff_ids <- sprintf("playoff-%02d", seq_len(8L))
  expected_r16_ids <- sprintf("r16-%02d", seq_len(8L))
  if (!setequal(as.character(playoff$path_id), expected_playoff_ids) || !setequal(as.character(r16$path_id), expected_r16_ids)) return(list(status = "unresolved", reason = "partial_draw_artifact"))
  expected_families <- as.character(policy$playoff_pair_families$bracket_position)
  observed_families <- table(factor(as.character(playoff$bracket_position), levels = expected_families))
  if (any(as.integer(observed_families) != 2L)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  expected_brackets <- c(as.character(policy$round_of_16_seed_pairs$bracket_position_a), as.character(policy$round_of_16_seed_pairs$bracket_position_b))
  observed_brackets <- table(factor(as.character(r16$bracket_position), levels = expected_brackets))
  if (any(as.integer(observed_brackets) != 1L)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  playoff_ranks <- c(as.integer(playoff$seed_rank), as.integer(playoff$opponent_rank))
  if (anyNA(playoff_ranks) || anyDuplicated(playoff_ranks) || !identical(sort(playoff_ranks), 9:24) || any(as.integer(playoff$seed_rank) < 9L | as.integer(playoff$seed_rank) > 16L) || any(as.integer(playoff$opponent_rank) < 17L | as.integer(playoff$opponent_rank) > 24L)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  if (any(as.integer(r16$seed_rank) < 1L | as.integer(r16$seed_rank) > 8L) || anyNA(r16$seed_rank) || anyDuplicated(as.integer(r16$seed_rank)) || !identical(sort(as.integer(r16$seed_rank)), 1:8) || any(!is.na(r16$opponent_rank))) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  playoff_ids <- as.character(playoff$path_id)
  if (any(!grepl("^winner:", as.character(r16$participant_b))) || anyDuplicated(sub("^winner:", "", as.character(r16$participant_b))) || !setequal(sub("^winner:", "", as.character(r16$participant_b)), playoff_ids)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  expected_family <- function(seed_rank, opponent_rank, bracket) {
    any(seed_rank >= policy$playoff_pair_families$seed_rank_min & seed_rank <= policy$playoff_pair_families$seed_rank_max & opponent_rank >= policy$playoff_pair_families$opponent_rank_min & opponent_rank <= policy$playoff_pair_families$opponent_rank_max & bracket == policy$playoff_pair_families$bracket_position)
  }
  for (index in seq_len(nrow(pairings))) {
    row <- pairings[index, , drop = FALSE]
    if (!.ucl_validate_legal_path(row, rules = rules, rank_lookup = rank_map)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
    a <- as.character(row$participant_a[[1L]]); b <- as.character(row$participant_b[[1L]])
    if (as.character(row$stage_id[[1L]]) == "knockout_play_off" && !expected_family(as.integer(row$seed_rank[[1L]]), as.integer(row$opponent_rank[[1L]]), as.character(row$bracket_position[[1L]]))) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
    if (grepl("^winner:", b)) next
    if (!a %in% names(rank_map) || !b %in% names(rank_map)) return(list(status = "unresolved", reason = "foreign_lineage"))
    if (identical(a, b)) return(list(status = "unresolved", reason = "contradictory_draw_artifact"))
  }
  hashes <- .ucl_sim_draw_hashes(artifact, rules = rules)
  if (!identical(tolower(as.character(artifact$rank_input_sha256)), tolower(hashes$rank_input_sha256)) || !identical(tolower(hash), tolower(hashes$draw_artifact_sha256))) return(list(status = "unresolved", reason = "draw_hash_mismatch"))
  list(status = "accepted", reason = NA_character_, draw_artifact_id = draw_id, draw_artifact_sha256 = hash, pairings = pairings, edition_id = rules$edition_id, source_bundle_id = as.character(artifact$source_bundle_id), rank_inputs = rank_inputs, rank_input_sha256 = hashes$rank_input_sha256, pairings_sha256 = hashes$pairings_sha256, source_artifact_ids = as.character(artifact$source_artifact_ids))
}

.ucl_sim_score <- function(row, fields, default = NA_real_) {
  fields <- fields[fields %in% names(row)]
  if (!length(fields)) return(default)
  value <- suppressWarnings(as.numeric(row[[fields[[1L]]]][[1L]]))
  if (!length(value) || is.na(value)) return(default)
  value
}

.ucl_sim_valid_goal <- function(value, allow_na = TRUE) {
  if (is.na(value)) return(isTRUE(allow_na))
  is.finite(value) && value >= 0 && value == floor(value)
}

.ucl_sim_id <- function(row, fields, default = NA_character_) {
  fields <- fields[fields %in% names(row)]
  if (!length(fields)) return(default)
  value <- row[[fields[[1L]]]][[1L]]
  if (length(value) != 1L || is.na(value) || !nzchar(trimws(as.character(value)))) return(default)
  trimws(as.character(value))
}

.ucl_sim_leg_payload <- function(row) {
  regulation_home <- .ucl_sim_score(row, c("regulation_home_goals", "home_goals", "final_home_goals"))
  regulation_away <- .ucl_sim_score(row, c("regulation_away_goals", "away_goals", "final_away_goals"))
  extra_home <- .ucl_sim_score(row, c("extra_time_home_goals", "extra_home_goals", "et_home_goals"), NA_real_)
  extra_away <- .ucl_sim_score(row, c("extra_time_away_goals", "extra_away_goals", "et_away_goals"), NA_real_)
  final_home <- .ucl_sim_score(row, c("final_home_goals", "home_final_goals"), NA_real_)
  final_away <- .ucl_sim_score(row, c("final_away_goals", "away_final_goals"), NA_real_)
  shootout_home <- .ucl_sim_score(row, c("penalty_home", "penalties_home", "penalty_shootout_home_goals", "shootout_home_goals"), NA_real_)
  shootout_away <- .ucl_sim_score(row, c("penalty_away", "penalties_away", "penalty_shootout_away_goals", "shootout_away_goals"), NA_real_)
  list(
    regulation_home = regulation_home, regulation_away = regulation_away,
    extra_home = extra_home, extra_away = extra_away,
    final_home = final_home, final_away = final_away,
    shootout_home = shootout_home, shootout_away = shootout_away
  )
}

.ucl_sim_strict_two_leg <- function(first, second) {
  any(c("stage_id", "participant_a", "participant_b", "leg_order", "leg_number", "seed_rank", "opponent_rank") %in% names(first)) ||
    any(c("stage_id", "participant_a", "participant_b", "leg_order", "leg_number", "seed_rank", "opponent_rank") %in% names(second))
}

.ucl_sim_invalid_resolution <- function(reason, rules = NULL, ...) {
  list(status = "blocked", reason = reason, winner = NA_character_, loser = NA_character_,
       ruleset_sha256 = if (is.list(rules)) rules$ruleset_sha256 %||% NA_character_ else NA_character_, ...)
}

#' Resolve a UCL two-leg tie by aggregate goals, then second-leg ET and penalties.
ucl_resolve_two_leg_tie <- function(first_leg, second_leg, rules = NULL, penalty_winner = NULL) {
  first <- as.data.frame(first_leg, stringsAsFactors = FALSE, check.names = FALSE)
  second <- as.data.frame(second_leg, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(first) != 1L || nrow(second) != 1L) stop("UCL two-leg resolver requires one row per leg", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(two_leg_policy = "aggregate_regulation_then_second_leg_extra_time_then_penalties_no_away_goals")
  strict <- .ucl_sim_strict_two_leg(first, second)
  if (strict) {
    if (!all(c("leg_number", "leg_order") %in% names(first)) || !all(c("leg_number", "leg_order") %in% names(second))) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
    leg_numbers <- suppressWarnings(as.integer(c(first$leg_number[[1L]], second$leg_number[[1L]])))
    if (anyNA(leg_numbers) || !identical(sort(leg_numbers), 1:2) || any(as.character(c(first$leg_order[[1L]], second$leg_order[[1L]])) != "seeded_return_leg")) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  } else {
    if (!"leg_number" %in% names(first)) first$leg_number <- 1L
    if (!"leg_number" %in% names(second)) second$leg_number <- 2L
    if (!"leg_order" %in% names(first)) first$leg_order <- "legacy_two_leg"
    if (!"leg_order" %in% names(second)) second$leg_order <- "legacy_two_leg"
  }
  ordered <- if (as.integer(first$leg_number[[1L]]) == 1L) list(first = first, second = second) else list(first = second, second = first)
  first <- ordered$first; second <- ordered$second
  home_first <- .ucl_sim_id(first, c("home_club_id", "home_team_id", "home_team"))
  away_first <- .ucl_sim_id(first, c("away_club_id", "away_team_id", "away_team"))
  home_second <- .ucl_sim_id(second, c("home_club_id", "home_team_id", "home_team"))
  away_second <- .ucl_sim_id(second, c("away_club_id", "away_team_id", "away_team"))
  if (any(is.na(c(home_first, away_first, home_second, away_second))) ||
      any(!nzchar(c(home_first, away_first, home_second, away_second))) ||
      any(c(home_first, away_first, home_second, away_second)[c(TRUE, FALSE, TRUE, FALSE)] == c(away_first, away_second)) ||
      !identical(sort(c(home_first, away_first)), sort(c(home_second, away_second))) ||
      length(unique(c(home_first, away_first))) != 2L || !setequal(c(home_first, home_second), c(home_first, away_first))) {
    return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  }
  explicit_participants <- all(c("participant_a", "participant_b") %in% names(first)) && all(c("participant_a", "participant_b") %in% names(second))
  participant_a <- if (explicit_participants) .ucl_sim_id(first, "participant_a") else home_first
  participant_b <- if (explicit_participants) .ucl_sim_id(first, "participant_b") else away_first
  if (is.na(participant_a) || is.na(participant_b) || identical(participant_a, participant_b) ||
      !identical(sort(c(participant_a, participant_b)), sort(c(home_first, away_first))) ||
      (explicit_participants && (.ucl_sim_id(second, "participant_a") != participant_a || .ucl_sim_id(second, "participant_b") != participant_b))) {
    return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
  }
  if (strict) {
    if (!all(c("venue_id") %in% names(first)) || !all(c("venue_id") %in% names(second)) ||
        any(!nzchar(c(.ucl_sim_id(first, "venue_id", ""), .ucl_sim_id(second, "venue_id", ""))))) return(.ucl_sim_invalid_resolution("invalid_leg_topology", rules))
    if (!all(c("seed_rank", "opponent_rank") %in% names(first)) ||
        suppressWarnings(as.integer(first$seed_rank[[1L]])) >= suppressWarnings(as.integer(first$opponent_rank[[1L]]))) {
      return(.ucl_sim_invalid_resolution("invalid_leg_order", rules))
    }
    if (!identical(home_first, participant_b) || !identical(home_second, participant_a)) return(.ucl_sim_invalid_resolution("invalid_leg_order", rules))
  }
  first_payload <- .ucl_sim_leg_payload(first); second_payload <- .ucl_sim_leg_payload(second)
  regulation <- c(0, 0); names(regulation) <- c(participant_a, participant_b)
  final <- regulation
  if (any(!vapply(c(first_payload$regulation_home, first_payload$regulation_away, second_payload$regulation_home, second_payload$regulation_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b))
  regulation[home_first] <- regulation[home_first] + first_payload$regulation_home
  regulation[away_first] <- regulation[away_first] + first_payload$regulation_away
  regulation[home_second] <- regulation[home_second] + second_payload$regulation_home
  regulation[away_second] <- regulation[away_second] + second_payload$regulation_away
  final <- regulation
  extra_applied <- FALSE; penalty_applied <- FALSE; winner <- NA_character_; resolution <- "aggregate"
  et_home <- second_payload$extra_home; et_away <- second_payload$extra_away
  if (identical(as.numeric(regulation[[participant_a]]), as.numeric(regulation[[participant_b]]))) {
    pen_home <- second_payload$shootout_home; pen_away <- second_payload$shootout_away
    if (any(!vapply(c(et_home, et_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) {
      if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) {
        et_home <- 0L; et_away <- 0L
      } else if (!is.null(penalty_winner) && length(penalty_winner) == 1L && as.character(penalty_winner) %in% c(participant_a, participant_b)) {
        et_home <- 0L; et_away <- 0L
      } else {
        return(list(status = "unresolved", reason = "extra_time_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), extra_time_applied = FALSE, penalty_applied = FALSE, away_goals_used = FALSE))
      }
    }
    extra_applied <- TRUE
    final[home_second] <- final[home_second] + et_home
    final[away_second] <- final[away_second] + et_away
    resolution <- "extra_time"
  }
  if (final[[participant_a]] > final[[participant_b]]) winner <- participant_a
  if (final[[participant_b]] > final[[participant_a]]) winner <- participant_b
  pen_home <- second_payload$shootout_home; pen_away <- second_payload$shootout_away
  if (is.na(winner)) {
    if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) {
      penalty_applied <- TRUE; resolution <- "penalties"
      winner <- if (pen_home > pen_away) home_second else away_second
    } else if (!is.null(penalty_winner) && length(penalty_winner) == 1L && as.character(penalty_winner) %in% c(participant_a, participant_b)) {
      penalty_applied <- TRUE; resolution <- "penalties"; winner <- as.character(penalty_winner)
    }
  }
  if (is.na(winner)) return(list(status = "unresolved", reason = "penalty_evidence_missing", winner = NA_character_, participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), aggregate_final_home = as.integer(final[[participant_a]]), aggregate_final_away = as.integer(final[[participant_b]]), extra_time_applied = extra_applied, extra_time_home = et_home, extra_time_away = et_away, penalty_applied = penalty_applied, penalty_home = pen_home, penalty_away = pen_away, away_goals_used = FALSE, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_))
  list(status = "resolved", reason = NA_character_, winner = winner, loser = setdiff(c(participant_a, participant_b), winner)[[1L]], participant_a = participant_a, participant_b = participant_b, aggregate_regulation_home = as.integer(regulation[[participant_a]]), aggregate_regulation_away = as.integer(regulation[[participant_b]]), aggregate_final_home = as.integer(final[[participant_a]]), aggregate_final_away = as.integer(final[[participant_b]]), extra_time_applied = extra_applied, extra_time_home = if (extra_applied) as.integer(et_home) else NA_integer_, extra_time_away = if (extra_applied) as.integer(et_away) else NA_integer_, penalty_applied = penalty_applied, penalty_home = if (penalty_applied) as.integer(pen_home) else NA_integer_, penalty_away = if (penalty_applied) as.integer(pen_away) else NA_integer_, away_goals_used = FALSE, leg_order = as.character(first$leg_order[[1L]]), leg_1_venue_id = .ucl_sim_id(first, "venue_id"), leg_2_venue_id = .ucl_sim_id(second, "venue_id"), second_leg_venue_id = .ucl_sim_id(second, "venue_id"), resolution = resolution, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

#' Resolve the neutral, single-match UCL final.
ucl_resolve_final <- function(match, rules = NULL, penalty_winner = NULL) {
  row <- as.data.frame(match, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(row) != 1L) stop("UCL final resolver requires one match row", call. = FALSE)
  rules <- rules %||% if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract() else list(final_policy = "single_neutral_match_extra_time_then_penalties")
  home <- .ucl_sim_id(row, c("home_club_id", "home_team_id", "home_team")); away <- .ucl_sim_id(row, c("away_club_id", "away_team_id", "away_team"))
  if (is.na(home) || is.na(away) || identical(home, away)) return(.ucl_sim_invalid_resolution("invalid_final_participants", rules))
  strict <- "stage_id" %in% names(row) || "stage_event_id" %in% names(row)
  neutral <- if ("neutral" %in% names(row)) isTRUE(row$neutral[[1L]]) else TRUE
  if (!neutral) return(.ucl_sim_invalid_resolution("final_not_neutral", rules))
  venue <- .ucl_sim_id(row, c("venue_id", "venue", "neutral_venue_id"), NA_character_)
  if (strict && is.na(venue)) return(.ucl_sim_invalid_resolution("final_venue_missing", rules))
  payload <- .ucl_sim_leg_payload(row)
  if (any(!vapply(c(payload$regulation_home, payload$regulation_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) return(list(status = "unresolved", reason = "score_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away))
  regulation_tied <- payload$regulation_home == payload$regulation_away
  et_home <- payload$extra_home; et_away <- payload$extra_away
  final_home <- payload$regulation_home; final_away <- payload$regulation_away
  extra_applied <- FALSE; penalty_applied <- FALSE; winner <- if (final_home > final_away) home else if (final_away > final_home) away else NA_character_; resolution <- "regulation"
  if (regulation_tied) {
    pen_home <- payload$shootout_home; pen_away <- payload$shootout_away
    if (any(!vapply(c(et_home, et_away), .ucl_sim_valid_goal, logical(1), allow_na = FALSE))) {
      if ((.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) || (!is.null(penalty_winner) && as.character(penalty_winner) %in% c(home, away))) {
        et_home <- 0L; et_away <- 0L
      } else {
        return(list(status = "unresolved", reason = "extra_time_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away, venue_id = venue))
      }
    }
    extra_applied <- TRUE; final_home <- final_home + et_home; final_away <- final_away + et_away; resolution <- "extra_time"
    winner <- if (final_home > final_away) home else if (final_away > final_home) away else NA_character_
  }
  pen_home <- payload$shootout_home; pen_away <- payload$shootout_away
  if (is.na(winner)) {
    if (.ucl_sim_valid_goal(pen_home) && .ucl_sim_valid_goal(pen_away) && pen_home != pen_away) { penalty_applied <- TRUE; resolution <- "penalties"; winner <- if (pen_home > pen_away) home else away }
    else if (!is.null(penalty_winner) && as.character(penalty_winner) %in% c(home, away)) { penalty_applied <- TRUE; resolution <- "penalties"; winner <- as.character(penalty_winner) }
  }
  if (is.na(winner)) return(list(status = "unresolved", reason = "penalty_evidence_missing", winner = NA_character_, neutral = TRUE, home_club_id = home, away_club_id = away, venue_id = venue, extra_time_applied = extra_applied, penalty_applied = penalty_applied))
  list(status = "resolved", reason = NA_character_, winner = winner, loser = setdiff(c(home, away), winner)[[1L]], neutral = TRUE, home_advantage = FALSE, home_club_id = home, away_club_id = away, venue_id = venue, regulation_home_goals = as.integer(payload$regulation_home), regulation_away_goals = as.integer(payload$regulation_away), final_home_goals = as.integer(final_home), final_away_goals = as.integer(final_away), extra_time_applied = extra_applied, extra_time_home = if (extra_applied) as.integer(et_home) else NA_integer_, extra_time_away = if (extra_applied) as.integer(et_away) else NA_integer_, penalty_applied = penalty_applied, penalty_home = if (penalty_applied) as.integer(pen_home) else NA_integer_, penalty_away = if (penalty_applied) as.integer(pen_away) else NA_integer_, resolution = resolution, ruleset_sha256 = rules$ruleset_sha256 %||% NA_character_)
}

# Persist one canonical stage-event row.  This is intentionally private: the
# public output seam is the closed knockout_paths.csv artifact.
.ucl_record_stage_event <- function(resolution, stage_id, stage_event_id, seed_slot_id = NA_character_, draw_policy_id = NA_character_, draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_, source_artifact_ids = NA_character_, source_bundle_id = NA_character_, simulation_run_id = NA_character_) {
  resolution <- if (is.data.frame(resolution)) as.list(resolution[1L, , drop = FALSE]) else resolution
  scalar <- function(name, default = NA) { value <- resolution[[name]]; if (is.null(value) || !length(value)) return(default); value[[1L]] }
  aggregate_regulation_home <- scalar("aggregate_regulation_home", scalar("regulation_home_goals", NA_integer_))
  aggregate_regulation_away <- scalar("aggregate_regulation_away", scalar("regulation_away_goals", NA_integer_))
  aggregate_final_home <- scalar("aggregate_final_home", scalar("final_home_goals", NA_integer_))
  aggregate_final_away <- scalar("aggregate_final_away", scalar("final_away_goals", NA_integer_))
  status <- as.character(scalar("status", scalar("path_status", "unresolved")))
  if (status %in% c("completed", "accepted_draw")) status <- "resolved"
  venue <- scalar("venue_id", scalar("second_leg_venue_id", NA_character_))
  leg_1 <- scalar("leg_1_venue_id", venue); leg_2 <- scalar("leg_2_venue_id", venue)
  if (identical(as.character(stage_id), "final")) { leg_1 <- venue; leg_2 <- NA_character_ }
  out <- data.frame(
    edition_id = scalar("edition_id", if (exists(".ucl_rule_contract", mode = "function")) .ucl_rule_contract()$edition_id else "ucl_2026_27"),
    path_id = as.character(stage_event_id), stage_event_id = as.character(stage_event_id), stage_id = as.character(stage_id), seed_slot_id = as.character(seed_slot_id),
    participant_a = as.character(scalar("participant_a", scalar("home_club_id", NA_character_))), participant_b = as.character(scalar("participant_b", scalar("away_club_id", NA_character_))),
    leg_order = as.character(scalar("leg_order", if (identical(as.character(stage_id), "final")) "single_neutral" else "seeded_return_leg")),
    leg_1_venue_id = as.character(leg_1), leg_2_venue_id = as.character(leg_2),
    aggregate_regulation_home = as.integer(aggregate_regulation_home), aggregate_regulation_away = as.integer(aggregate_regulation_away), aggregate_final_home = as.integer(aggregate_final_home), aggregate_final_away = as.integer(aggregate_final_away),
    extra_time_applied = isTRUE(scalar("extra_time_applied", FALSE)), extra_time_home = as.integer(scalar("extra_time_home", NA_integer_)), extra_time_away = as.integer(scalar("extra_time_away", NA_integer_)), penalty_applied = isTRUE(scalar("penalty_applied", FALSE)), penalty_home = as.integer(scalar("penalty_home", NA_integer_)), penalty_away = as.integer(scalar("penalty_away", NA_integer_)),
    draw_policy_id = as.character(draw_policy_id), draw_artifact_id = as.character(draw_artifact_id), draw_artifact_sha256 = as.character(draw_artifact_sha256), path_status = status, unresolved_reason = as.character(scalar("reason", scalar("unresolved_reason", NA_character_))), source_artifact_ids = as.character(source_artifact_ids), source_bundle_id = as.character(source_bundle_id), ruleset_sha256 = as.character(scalar("ruleset_sha256", NA_character_)), simulation_run_id = as.character(simulation_run_id), stringsAsFactors = FALSE, check.names = FALSE
  )
  out
}

#' Aggregate stage input/output event counts without repairing unresolved rows.
ucl_aggregate_stage_events <- function(events, rules = NULL, stage_inputs = NULL, league_bands = NULL, required_stage_ids = NULL) {
  empty <- data.frame(stage_id = character(), input_count = integer(), resolved_count = integer(), unresolved_count = integer(), suppressed_count = integer(), output_count = integer(), stringsAsFactors = FALSE, check.names = FALSE)
  if (is.null(events)) {
    attr(empty, "valid") <- FALSE
    attr(empty, "errors") <- "stage_events_empty"
    return(empty)
  }
  events <- as.data.frame(events, stringsAsFactors = FALSE, check.names = FALSE)
  if (!all(c("stage_id") %in% names(events))) stop("UCL stage events require stage_id", call. = FALSE)
  stage <- as.character(events$stage_id)
  if (!any(c("status", "path_status") %in% names(events))) {
    attr(empty, "valid") <- FALSE
    attr(empty, "errors") <- "stage_event_status_missing"
    return(empty)
  }
  raw_status <- if ("status" %in% names(events)) as.character(events$status) else as.character(events$path_status)
  if (all(c("status", "path_status") %in% names(events)) &&
      any(is.na(events$status) | is.na(events$path_status) |
          as.character(events$status) != as.character(events$path_status))) {
    attr(empty, "valid") <- FALSE
    attr(empty, "errors") <- "stage_event_status_mismatch"
    return(empty)
  }
  if (length(raw_status) != nrow(events) || any(is.na(raw_status) | !nzchar(trimws(raw_status)))) {
    attr(empty, "valid") <- FALSE
    attr(empty, "errors") <- "stage_event_status_missing"
    return(empty)
  }
  resolved_status <- c("resolved", "completed", "accepted_draw")
  unresolved_status <- c("unresolved", "blocked")
  suppressed_status <- c("suppressed", "pre_draw_legal")
  unknown <- !raw_status %in% c(resolved_status, unresolved_status, suppressed_status)
  classified <- ifelse(raw_status %in% resolved_status, "resolved", ifelse(raw_status %in% suppressed_status, "suppressed", "unresolved"))
  input_names <- names(stage_inputs)
  if (!is.null(stage_inputs) && (is.null(input_names) || any(!nzchar(input_names)))) stop("stage_inputs must be a named count vector", call. = FALSE)
  ids <- sort(unique(c(stage, input_names %||% character())), method = "radix")
  errors <- character()
  if (!is.null(required_stage_ids) && !setequal(as.character(required_stage_ids), unique(stage))) errors <- c(errors, "stage_inventory_incomplete")
  out <- do.call(rbind, lapply(ids, function(stage_id) {
    observed <- classified[stage == stage_id]
    expected <- if (!is.null(stage_inputs) && stage_id %in% input_names) suppressWarnings(as.integer(stage_inputs[[stage_id]])) else length(observed)
    if (is.na(expected) || expected < 0L) {
      errors <<- c(errors, paste0("invalid_stage_input:", stage_id))
      expected <- length(observed)
    }
    if (!is.null(stage_inputs) && length(observed) != expected) errors <<- c(errors, paste0("stage_inventory_incomplete:", stage_id))
    if (length(observed) > expected) errors <<- c(errors, paste0("stage_input_overflow:", stage_id))
    missing <- 0L
    data.frame(stage_id = stage_id, input_count = as.integer(expected), resolved_count = as.integer(sum(observed == "resolved")), unresolved_count = as.integer(sum(observed == "unresolved") + missing), suppressed_count = as.integer(sum(observed == "suppressed")), output_count = as.integer(sum(observed == "resolved")), stringsAsFactors = FALSE, check.names = FALSE)
  }))
  if (any(unknown)) errors <- c(errors, "unknown_stage_event_status")
  if (any(out$input_count != out$resolved_count + out$unresolved_count + out$suppressed_count)) errors <- c(errors, "stage_count_nonconservation")
  if (!is.null(league_bands)) {
    bands <- suppressWarnings(as.numeric(league_bands))
    if (anyNA(bands) || any(bands < 0) || abs(sum(bands) - 36) > 0) errors <- c(errors, "league_band_nonconservation")
  }
  if ("stage_event_id" %in% names(events) && (anyNA(events$stage_event_id) || any(!nzchar(trimws(as.character(events$stage_event_id)))) || anyDuplicated(as.character(events$stage_event_id)))) errors <- c(errors, "stage_event_identity_invalid")
  row.names(out) <- NULL
  attr(out, "valid") <- !length(errors)
  attr(out, "errors") <- unique(errors)
  out
}

#' Validate probability conservation and monotone progression.
ucl_validate_progression_reconciliation <- function(progression, stage_inputs = NULL, league_bands = NULL, tolerance = 1e-10, required_stage_ids = NULL) {
  if (!is.data.frame(progression) || !nrow(progression)) return(list(status = "unresolved", valid = FALSE, errors = "progression_empty"))
  required <- c("club_id", "stage_id", "probability")
  if (!all(required %in% names(progression))) return(list(status = "blocked", valid = FALSE, errors = "progression_schema_incomplete"))
  errors <- character()
  status_values <- if ("status" %in% names(progression)) as.character(progression$status) else rep("resolved", nrow(progression))
  if (!"status" %in% names(progression)) errors <- c(errors, "progression_status_missing")
  if (length(status_values) != nrow(progression) || anyNA(status_values) ||
      any(!status_values %in% c("resolved", "unresolved", "suppressed", "blocked"))) {
    errors <- c(errors, "progression_status_invalid")
    status_values <- rep("unresolved", nrow(progression))
  }
  if (anyNA(progression$club_id) || any(!nzchar(trimws(as.character(progression$club_id)))) ||
      anyNA(progression$stage_id) || any(!nzchar(trimws(as.character(progression$stage_id))))) {
    errors <- c(errors, "progression_identity_invalid")
  }
  if (anyDuplicated(paste(as.character(progression$club_id), as.character(progression$stage_id), sep = "\x1f"))) errors <- c(errors, "progression_stage_identity_invalid")
  if (is.null(stage_inputs) && max(table(as.character(progression$club_id))) < 2L) errors <- c(errors, "stage_inputs_required")
  p <- suppressWarnings(as.numeric(progression$probability))
  finite <- !is.na(p)
  if (any(!is.finite(p[finite]) | p[finite] < -tolerance | p[finite] > 1 + tolerance)) errors <- c(errors, "probability_bounds")
  if (any(is.na(p) & status_values == "resolved")) errors <- c(errors, "resolved_probability_missing")
  default_order <- c(direct_round_of_16 = 1, knockout_play_off = 1, eliminated = 0,
                     round_of_16 = 2, quarter_final = 3, semi_final = 4, final = 5, champion = 6,
                     league = 1, playoff = 1)
  stage_order <- if ("stage_order" %in% names(progression)) suppressWarnings(as.numeric(progression$stage_order)) else unname(default_order[as.character(progression$stage_id)])
  if (length(stage_order) != nrow(progression) || any(is.na(stage_order))) errors <- c(errors, "stage_order_missing")
  if (!is.null(required_stage_ids) && !all(as.character(required_stage_ids) %in% unique(as.character(progression$stage_id)))) errors <- c(errors, "progression_stage_inventory_incomplete")
  for (club in unique(as.character(progression$club_id))) {
    rows <- progression[as.character(progression$club_id) == club, , drop = FALSE]
    order_values <- stage_order[as.character(progression$club_id) == club]
    ordered <- rows[order(order_values), , drop = FALSE]
    ordered_probability <- suppressWarnings(as.numeric(ordered$probability))
    active <- !as.character(ordered$stage_id) %in% c("direct_round_of_16", "knockout_play_off", "eliminated")
    monotone_probability <- ordered_probability[active]
    if (length(monotone_probability) > 1L && any(diff(monotone_probability) > tolerance, na.rm = TRUE)) errors <- c(errors, paste0("non_monotone:", club))
    if ("qualification_band" %in% names(ordered)) {
      resolved <- if ("status" %in% names(ordered)) ordered[as.character(ordered$status) == "resolved", , drop = FALSE] else ordered
      values <- suppressWarnings(as.numeric(resolved$probability))
      if (length(values) && all(is.finite(values)) && abs(sum(values) - 1) > tolerance) errors <- c(errors, paste0("band_sum:", club))
    }
  }
  if (!is.null(stage_inputs) && all(status_values == "resolved")) {
    for (stage_id in intersect(names(stage_inputs), unique(as.character(progression$stage_id)))) {
      values <- suppressWarnings(as.numeric(progression$probability[as.character(progression$stage_id) == stage_id]))
      if (length(values) > 1L && all(is.finite(values)) && abs(sum(values) - 1) > tolerance) errors <- c(errors, paste0("stage_sum:", stage_id))
    }
  }
  if (!is.null(stage_inputs)) {
    if (is.null(names(stage_inputs)) || any(!nzchar(names(stage_inputs))) || anyNA(as.numeric(stage_inputs)) || any(as.numeric(stage_inputs) < 0)) errors <- c(errors, "stage_input_schema")
    unknown_stages <- setdiff(names(stage_inputs), unique(as.character(progression$stage_id)))
    if (length(unknown_stages)) errors <- c(errors, paste0("stage_input_missing:", unknown_stages))
  }
  if (!is.null(league_bands)) {
    bands <- suppressWarnings(as.numeric(league_bands))
    if (anyNA(bands) || any(bands < 0) || abs(sum(bands) - 36) > 0) errors <- c(errors, "league_band_nonconservation")
  }
  errors <- unique(errors)
  list(status = if (length(errors)) "invalid" else "ready", valid = !length(errors), errors = errors)
}
