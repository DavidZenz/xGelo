# Edition-local national Elo continuation. Model fitting and approved releases
# remain immutable; only genuine prior accepted NL results update inference.

nl_elo_contract <- function() "nl-local-elo-v1"
nl_elo_inventory <- function() c("forecast_inputs/elo_ratings.csv", "forecast_inputs/elo_provenance.json")
nl_elo_source_context <- function(source) {
  if (!is.null(source$as_of_utc) && !is.null(source$source_bundle_sha256) && is.data.frame(source$results)) return(source)
  results <- if (is.data.frame(source$results)) source$results else source$tables$results
  hash <- source$source_bundle_sha256
  if (is.null(hash)) hash <- as.character(source$bundle$source_bundle_sha256[[1L]])
  manifest <- source$manifest
  if (!is.data.frame(manifest) || !"retrieved_at_utc" %in% names(manifest)) stop("NL local Elo requires accepted source capture provenance", call. = FALSE)
  as_of <- as.character(manifest$retrieved_at_utc[[which.max(nl_elo_time(manifest$retrieved_at_utc))]])
  list(results = results, source_bundle_sha256 = as.character(hash), as_of_utc = as_of)
}
nl_elo_team_projection <- function(registry, fixtures) {
  teams <- unique(registry[c("team_id", "canonical_name")])
  ids <- unique(c(as.character(fixtures$home_team_id), as.character(fixtures$away_team_id)))
  teams <- teams[as.character(teams$team_id) %in% ids, , drop = FALSE]
  if (!setequal(as.character(teams$team_id), ids)) stop("NL local Elo roster coverage is incomplete", call. = FALSE)
  teams
}
nl_elo_hash <- function(value) digest::digest(value, algo = "sha256", serialize = FALSE)
nl_elo_file_hash <- function(path) digest::digest(file = path, algo = "sha256")
nl_elo_json_hash <- function(value) {
  value$self_sha256 <- NULL
  nl_elo_hash(jsonlite::toJSON(value[sort(names(value))], auto_unbox = TRUE, null = "null", digits = 17, na = "null"))
}
nl_elo_time <- function(value, required = TRUE) {
  value <- as.character(value)
  parsed <- suppressWarnings(as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  bad <- is.na(value) | !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$", value) | is.na(parsed)
  if (required && any(bad)) stop("NL local Elo requires valid UTC evidence timestamps", call. = FALSE)
  parsed[bad] <- as.POSIXct(NA, tz = "UTC")
  parsed
}
nl_elo_bool <- function(value) {
  text <- tolower(as.character(value)); out <- rep(NA, length(text))
  out[text %in% c("true", "t", "1")] <- TRUE
  out[text %in% c("false", "f", "0")] <- FALSE
  out
}
nl_elo_policy <- function(project_root) {
  path <- file.path(project_root, "R/elo/runner_optimized.R")
  if (!file.exists(path)) stop("NL local Elo policy is unavailable", call. = FALSE)
  policy <- new.env(parent = baseenv())
  sys.source(path, envir = policy)
  list(functions = policy, sha256 = nl_elo_file_hash(path), home_advantage = 60)
}

nl_elo_build <- function(seed_history, results, teams, as_of_utc, policy, parents = list()) {
  required <- c("team_id", "canonical_name")
  if (!all(required %in% names(teams))) stop("NL local Elo requires canonical team identity", call. = FALSE)
  teams <- unique(teams[required]); teams <- teams[order(teams$team_id), , drop = FALSE]
  if (anyNA(teams) || anyDuplicated(teams$team_id) || anyDuplicated(teams$canonical_name)) stop("NL local Elo team identity is ambiguous", call. = FALSE)
  fields <- c("fixture_id", "home_team_id", "away_team_id", "scheduled_at_utc", "match_status", "counts_for_form", "final_home_goals", "final_away_goals", "evidence_completed_at_utc")
  if (!all(fields %in% names(results)) || anyDuplicated(results$fixture_id)) stop("NL local Elo accepted results are incomplete or duplicated", call. = FALSE)
  as_of <- nl_elo_time(as_of_utc)
  if (length(as_of) != 1L) stop("NL local Elo needs one source as-of timestamp", call. = FALSE)
  kickoff <- nl_elo_time(results$scheduled_at_utc)
  base_date <- min(as.Date(kickoff, tz = "UTC"))
  base_cutoff <- paste0(base_date, "T00:00:00Z")
  if (nl_elo_time(base_cutoff) > as_of) stop("NL local Elo pre-edition boundary is after the source as-of", call. = FALSE)
  counts <- nl_elo_bool(results$counts_for_form)
  if (anyNA(counts)) stop("NL local Elo needs explicit counted-result flags", call. = FALSE)
  complete <- as.character(results$match_status) == "completed"
  if (any(counts & !complete)) stop("NL local Elo cannot consume uncompleted scores", call. = FALSE)
  selected <- which(counts & complete)
  played <- results[selected, , drop = FALSE]
  played$.__kickoff <- kickoff[selected]
  played$.__evidence <- nl_elo_time(played$evidence_completed_at_utc)
  hg <- suppressWarnings(as.numeric(as.character(played$final_home_goals)))
  ag <- suppressWarnings(as.numeric(as.character(played$final_away_goals)))
  if (any(!is.finite(hg) | !is.finite(ag) | hg < 0 | ag < 0 | hg != floor(hg) | ag != floor(ag)) ||
      any(played$.__evidence < played$.__kickoff | played$.__evidence <= nl_elo_time(base_cutoff) | played$.__evidence > as_of)) stop("NL local Elo score/evidence is invalid or after source as-of", call. = FALSE)
  played$.__home_goals <- hg; played$.__away_goals <- ag
  played <- played[order(played$.__kickoff, played$fixture_id, method = "radix"), , drop = FALSE]
  if (!all(c(played$home_team_id, played$away_team_id) %in% teams$team_id)) stop("NL local Elo result has an unmapped team", call. = FALSE)
  if (!all(c("date", "team", "rating", "match_id", "is_post_match") %in% names(seed_history))) stop("NL local Elo seed history is incomplete", call. = FALSE)
  seed_history$.__date <- as.Date(seed_history$date)
  post <- nl_elo_bool(seed_history$is_post_match)
  seed_history <- seed_history[!is.na(post) & post & !is.na(seed_history$.__date) & seed_history$.__date < base_date, , drop = FALSE]
  seed_history$.__row <- seq_len(nrow(seed_history))
  states <- list(); output <- list(); seed_times <- character(nrow(teams)); consumed <- integer(nrow(teams))
  names(consumed) <- names(seed_times) <- as.character(teams$team_id)
  for (index in seq_len(nrow(teams))) {
    id <- as.character(teams$team_id[[index]]); name <- as.character(teams$canonical_name[[index]])
    rows <- seed_history[as.character(seed_history$team) == name, , drop = FALSE]
    rows <- rows[order(rows$.__date, rows$.__row), , drop = FALSE]
    if (!nrow(rows)) stop("NL local Elo lacks a pre-edition post-match seed for ", id, call. = FALSE)
    last <- rows[nrow(rows), , drop = FALSE]
    years <- as.integer(format(rows$.__date, "%Y")); encountered <- sort(unique(years))
    this <- sum(years == utils::tail(encountered, 1L))
    previous <- if (length(encountered) > 1L) sum(years == encountered[[length(encountered) - 1L]]) else 0L
    rating <- as.numeric(last$rating[[1L]])
    if (!is.finite(rating)) stop("NL local Elo seed rating is not finite", call. = FALSE)
    evidence <- paste0(last$.__date[[1L]], "T00:00:00Z")
    seed_times[[id]] <- evidence
    fifa <- if ("fifa_code" %in% names(last)) as.character(last$fifa_code[[1L]]) else NA_character_
    states[[id]] <- list(rating = rating, last_date = last$.__date[[1L]], evidence = evidence,
      this_year = as.integer(this), last_year = as.integer(previous), name = name, fifa = fifa)
    output[[length(output) + 1L]] <- data.frame(date = as.character(last$.__date[[1L]]), team = name, fifa_code = fifa,
      rating = rating, match_id = as.character(last$match_id[[1L]]), is_post_match = TRUE, team_id = id,
      evidence_at_utc = evidence, evidence_precision = "date", evidence_completed_at_utc = NA_character_, source_kind = "pre_edition_seed", stringsAsFactors = FALSE)
  }
  for (batch in unique(as.numeric(played$.__kickoff))) {
    indexes <- which(as.numeric(played$.__kickoff) == batch)
    participants <- c(as.character(played$home_team_id[indexes]), as.character(played$away_team_id[indexes]))
    if (anyDuplicated(participants)) stop("NL local Elo same-kickoff participant overlap is ambiguous", call. = FALSE)
    prior <- states
    for (index in indexes) {
      row <- played[index, , drop = FALSE]
      home <- as.character(row$home_team_id[[1L]]); away <- as.character(row$away_team_id[[1L]])
      h <- prior[[home]]; a <- prior[[away]]; day <- as.Date(row$.__kickoff[[1L]], tz = "UTC")
      if (nl_elo_time(h$evidence) >= row$.__kickoff || nl_elo_time(a$evidence) >= row$.__kickoff)
        stop("NL local Elo requires strictly prior evidence at kickoff", call. = FALSE)
      hr <- policy$functions$apply_decay(h$rating, as.numeric(day - h$last_date))
      ar <- policy$functions$apply_decay(a$rating, as.numeric(day - a$last_date))
      actual <- if (row$.__home_goals > row$.__away_goals) 1 else if (row$.__home_goals == row$.__away_goals) .5 else 0
      neutral <- if ("neutral" %in% names(row)) isTRUE(nl_elo_bool(row$neutral)[[1L]]) else FALSE
      update <- policy$functions$elo_update(hr, ar, actual,
        policy$functions$get_k_factor(h$last_year, h$this_year), policy$functions$get_k_factor(a$last_year, a$this_year),
        home_advantage = policy$home_advantage, is_home = !neutral)
      for (side in c("home", "away")) {
        id <- if (side == "home") home else away; state <- prior[[id]]
        value <- if (side == "home") update$rating_a else update$rating_b
        if (format(state$last_date, "%Y") != format(day, "%Y")) {
          state$last_year <- state$this_year; state$this_year <- 1L
        } else state$this_year <- state$this_year + 1L
        state$rating <- value; state$last_date <- day; state$evidence <- as.character(row$evidence_completed_at_utc[[1L]])
        states[[id]] <- state; consumed[[id]] <- consumed[[id]] + 1L
        output[[length(output) + 1L]] <- data.frame(date = as.character(day), team = state$name, fifa_code = state$fifa,
          rating = value, match_id = as.character(row$fixture_id[[1L]]), is_post_match = TRUE, team_id = id,
          evidence_at_utc = state$evidence, evidence_precision = "timestamp", evidence_completed_at_utc = state$evidence,
          source_kind = "accepted_nl_result", stringsAsFactors = FALSE)
      }
    }
  }
  ratings <- do.call(rbind, output); ratings <- ratings[order(ratings$team_id, nl_elo_time(ratings$evidence_at_utc), ratings$match_id), , drop = FALSE]; rownames(ratings) <- NULL
  per_team <- lapply(as.character(teams$team_id), function(id) list(team_id = id, seed_evidence_at_utc = seed_times[[id]],
    seed_evidence_precision = "date", latest_evidence_at_utc = states[[id]]$evidence,
    latest_evidence_precision = if (consumed[[id]]) "timestamp" else "date", consumed_result_count = unname(consumed[[id]])))
  latest <- vapply(per_team, function(row) row$latest_evidence_at_utc, character(1)); times <- nl_elo_time(latest)
  provenance <- c(list(schema_version = nl_elo_contract(), policy_sha256 = policy$sha256,
    policy_home_advantage = policy$home_advantage, policy_k = "get_k_factor(20/40;15-match threshold)", policy_decay = "0.995^(days/365)",
    scope = "Pre-edition national seeds plus accepted NL results only; no claim of all-international post-base coverage",
    admission_policy = "counts_for_form=true;match_status=completed;base_cutoff<completion<=source_as_of",
    as_of_utc = as.character(as_of_utc), base_cutoff_utc = base_cutoff,
    base_latest_evidence_at_utc = seed_times[[which.max(nl_elo_time(seed_times))]],
    earliest_team_evidence_at_utc = latest[[which.min(times)]], latest_evidence_at_utc = latest[[which.max(times)]],
    team_count = nrow(teams), completed_result_count = nrow(played)), parents)
  list(ratings = ratings, provenance = provenance, per_team = per_team)
}

nl_elo_build_from_project <- function(project_root, source, teams, as_of_utc) {
  seed <- file.path(project_root, "data/processed/elo_ratings.csv")
  results <- file.path(project_root, "data/competition/accepted/uefa_nations_league_2026_27/results.csv")
  identity <- file.path(project_root, "data/competition/registries/team_identity.csv")
  if (!is.null(source$as_of_utc) && !identical(as.character(source$as_of_utc), as.character(as_of_utc)))
    stop("NL local Elo source as-of does not match its accepted capture", call. = FALSE)
  nl_elo_build(utils::read.csv(seed, stringsAsFactors = FALSE, check.names = FALSE), source$results,
    teams, as_of_utc, nl_elo_policy(project_root), parents = list(seed_sha256 = nl_elo_file_hash(seed),
      results_sha256 = nl_elo_file_hash(results), team_identity_sha256 = nl_elo_file_hash(identity),
      source_bundle_sha256 = as.character(source$source_bundle_sha256)))
}

nl_elo_serialize <- function(input) {
  text <- character(); connection <- textConnection("text", "w", local = TRUE)
  utils::write.csv(input$ratings, connection, row.names = FALSE, na = ""); close(connection)
  ratings <- charToRaw(paste0(paste(text, collapse = "\n"), "\n"))
  value <- input$provenance; value$ratings_sha256 <- nl_elo_hash(ratings)
  value$self_sha256 <- nl_elo_json_hash(value)
  provenance <- charToRaw(paste0(jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, digits = 17, na = "null"), "\n"))
  list(artifacts = stats::setNames(list(ratings, provenance), nl_elo_inventory()), provenance = value,
    hashes = list(elo_input_sha256 = value$ratings_sha256, elo_input_provenance_sha256 = nl_elo_hash(provenance)))
}
nl_elo_write <- function(input, state_root) {
  serialized <- nl_elo_serialize(input)
  for (name in names(serialized$artifacts)) {
    path <- file.path(state_root, name); dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeBin(serialized$artifacts[[name]], path)
  }
  list(ratings_sha256 = serialized$hashes$elo_input_sha256,
    provenance_sha256 = serialized$hashes$elo_input_provenance_sha256, provenance = serialized$provenance)
}

nl_elo_read_validate <- function(project_root, state_root, source, teams, state_manifest = NULL) {
  source <- nl_elo_source_context(source)
  paths <- file.path(state_root, nl_elo_inventory())
  if (!all(file.exists(paths)) || any(Sys.readlink(paths) != "")) stop("NL forecast synchronization requires genuine local Elo input artifacts", call. = FALSE)
  observed <- list.files(file.path(state_root, "forecast_inputs"), recursive = TRUE, all.files = TRUE, no.. = TRUE)
  if (!setequal(file.path("forecast_inputs", observed), nl_elo_inventory())) stop("NL forecast input auxiliary inventory is invalid", call. = FALSE)
  value <- jsonlite::read_json(paths[[2L]], simplifyVector = TRUE)
  if (!identical(value$schema_version, nl_elo_contract()) || !identical(value$self_sha256, nl_elo_json_hash(value)) ||
      !identical(value$ratings_sha256, nl_elo_file_hash(paths[[1L]]))) stop("NL local Elo input provenance/hash is invalid", call. = FALSE)
  rebuilt <- nl_elo_build_from_project(project_root, source, teams, value$as_of_utc)
  fields <- names(rebuilt$provenance)
  for (field in fields) if (!isTRUE(all.equal(rebuilt$provenance[[field]], value[[field]], check.attributes = FALSE)))
    stop("NL local Elo parent/policy is stale or altered: ", field, call. = FALSE)
  ratings <- utils::read.csv(paths[[1L]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (!identical(names(ratings), names(rebuilt$ratings)) || nrow(ratings) != nrow(rebuilt$ratings) ||
      !isTRUE(all.equal(ratings, rebuilt$ratings, tolerance = 1e-12, check.attributes = FALSE))) stop("NL local Elo ratings disagree with causal replay", call. = FALSE)
  hashes <- list(elo_input_sha256 = value$ratings_sha256, elo_input_provenance_sha256 = nl_elo_file_hash(paths[[2L]]))
  if (!is.null(state_manifest)) {
    if (!"validation_status" %in% names(state_manifest) || anyNA(state_manifest$validation_status) || !all(as.character(state_manifest$validation_status) == "valid")) stop("NL forecast state has an invalid semantic candidate status", call. = FALSE)
    for (field in names(hashes)) if (!field %in% names(state_manifest) || !all(as.character(state_manifest[[field]]) == hashes[[field]]))
      stop("NL state manifest is not bound to actual local Elo input provenance", call. = FALSE)
  }
  c(rebuilt, list(hashes = hashes))
}

nl_elo_validate_forecast_evidence <- function(input, forecasts, fixtures) {
  if (!is.data.frame(forecasts) || !nrow(forecasts)) stop("NL accepted forecast authority is missing", call. = FALSE)
  for (i in seq_len(nrow(forecasts))) {
    row <- forecasts[i, , drop = FALSE]; fixture <- fixtures[as.character(fixtures$fixture_id) == as.character(row$fixture_id[[1L]]), , drop = FALSE]
    if (nrow(fixture) != 1L) stop("NL forecast evidence has no unique accepted fixture", call. = FALSE)
    cutoff <- nl_elo_time(row$feature_cutoff_utc[[1L]])
    selected <- lapply(c(as.character(fixture$home_team_id[[1L]]), as.character(fixture$away_team_id[[1L]])), function(team) {
      data <- input$ratings[as.character(input$ratings$team_id) == team, , drop = FALSE]
      times <- nl_elo_time(data$evidence_at_utc)
      keep <- times < cutoff & (data$evidence_precision != "date" | as.Date(data$date) < as.Date(cutoff, tz = "UTC"))
      data <- data[keep, , drop = FALSE]
      if (!nrow(data)) stop("NL forecast lacks strictly prior local Elo evidence", call. = FALSE)
      data[which.max(nl_elo_time(data$evidence_at_utc)), , drop = FALSE]
    })
    dates <- vapply(selected, function(x) as.character(x$evidence_at_utc[[1L]]), character(1))
    expected <- dates[[which.max(nl_elo_time(dates))]]
    if (!"latest_evidence_at_utc" %in% names(row) || !identical(as.character(row$latest_evidence_at_utc[[1L]]), expected))
      stop("NL forecast evidence time does not match its actual prior local ratings", call. = FALSE)
  }
  invisible(TRUE)
}

nl_elo_validate_accepted_state <- function(project_root, source, state, registry) {
  context <- nl_elo_source_context(source)
  artifacts <- if (is.list(state$artifacts)) state$artifacts else state$state_artifacts
  manifest <- if (is.data.frame(state$state_manifest)) state$state_manifest else artifacts[["audit/state_manifest.csv"]]
  fixtures <- artifacts[["state/canonical_matches.csv"]]; forecasts <- artifacts[["state/forecasts.csv"]]
  teams <- nl_elo_team_projection(registry, fixtures)
  root <- file.path(project_root, "outputs/competition/uefa_nations_league_2026_27")
  input <- nl_elo_read_validate(project_root, root, context, teams, manifest)
  if (!all(as.character(manifest$source_bundle_sha256) == context$source_bundle_sha256)) stop("NL state does not consume its actual accepted source", call. = FALSE)
  if (!"generated_at_utc" %in% names(manifest) || anyNA(manifest$generated_at_utc) || !all(nzchar(as.character(manifest$generated_at_utc)))) stop("NL accepted state generation time is unavailable", call. = FALSE)
  if (!"generated_at_utc" %in% names(forecasts) || anyNA(forecasts$generated_at_utc) ||
      length(unique(as.character(manifest$generated_at_utc))) != 1L ||
      !all(as.character(forecasts$generated_at_utc) == as.character(manifest$generated_at_utc[[1L]])))
    stop("NL forecast and state operational timestamps disagree", call. = FALSE)
  if (any(nl_elo_time(manifest$generated_at_utc) < nl_elo_time(context$as_of_utc))) stop("NL state generation predates its accepted source", call. = FALSE)
  status <- artifacts[["state/forecast_status.csv"]]
  if (!is.data.frame(status) || anyDuplicated(status$fixture_id) ||
      !setequal(as.character(status$fixture_id), as.character(fixtures$fixture_id))) stop("NL state status coverage is incomplete", call. = FALSE)
  expected_completed <- phase14_state_bundle_expected_completed_suppression(status, fixtures, context$results,
    "uefa_nations_league_2026_27", data.frame(retrieved_at_utc = context$as_of_utc))
  if (any(as.character(status$forecast_status) != "available" & !expected_completed))
    stop("NL accepted state contains a real future forecast suppression", call. = FALSE)
  if (anyDuplicated(forecasts$fixture_id) || !setequal(as.character(forecasts$fixture_id),
      as.character(status$fixture_id[as.character(status$forecast_status) == "available"]))) stop("NL accepted forecast coverage is incomplete", call. = FALSE)
  for (path in c("state/standings.csv", "state/competition_form.csv", "state/all_international_form.csv", "audit/standings_reconciliation.csv")) {
    facts <- artifacts[[path]]
    if (!is.data.frame(facts) || !"team_id" %in% names(facts) || anyDuplicated(facts$team_id) ||
        !setequal(as.character(facts$team_id), as.character(teams$team_id))) stop("NL accepted factual/form state is incomplete: ", path, call. = FALSE)
  }
  if (any(nl_elo_time(forecasts$kickoff_utc) <= nl_elo_time(context$as_of_utc))) stop("NL accepted forecast has expired kickoff", call. = FALSE)
  nl_elo_validate_forecast_evidence(input, forecasts, fixtures)
  input
}

nl_elo_public_evidence <- function(input) {
  p <- input$provenance; h <- input$hashes
  metadata <- list(forecast_input_contract = nl_elo_contract(), forecast_input_status = "validated",
    forecast_input_sha256 = h$elo_input_sha256, forecast_input_provenance_sha256 = h$elo_input_provenance_sha256)
  for (field in c("seed_sha256", "results_sha256", "source_bundle_sha256", "policy_sha256", "as_of_utc", "base_cutoff_utc",
      "base_latest_evidence_at_utc", "earliest_team_evidence_at_utc", "latest_evidence_at_utc", "team_count", "completed_result_count"))
    metadata[[paste0("forecast_input_", field)]] <- p[[field]]
  list(metadata = metadata, evidence = c(list(schema_version = nl_elo_contract(), per_team = input$per_team), metadata))
}

# Full publisher authority is additional to input evidence: a genuine outcome
# must consume this exact current state and retain its real computation clock.
nl_elo_validate_projection <- function(state, outcomes, source) {
  context <- nl_elo_source_context(source)
  manifest <- outcomes$manifest
  artifacts <- outcomes$artifacts
  simulation <- artifacts[["outcomes/simulation_metadata.csv"]]
  if (!is.data.frame(manifest) || !nrow(manifest) || !is.data.frame(simulation) || nrow(simulation) != 1L)
    stop("NL projection computation receipt is unavailable", call. = FALSE)
  for (table in list(manifest, simulation)) {
    if (!"state_manifest_sha256" %in% names(table) || anyNA(table$state_manifest_sha256) ||
        !all(as.character(table$state_manifest_sha256) == as.character(state$state_manifest_sha256)))
      stop("NL projection does not consume the actual current forecast state", call. = FALSE)
    if (!"source_bundle_sha256" %in% names(table) || anyNA(table$source_bundle_sha256) ||
        !all(as.character(table$source_bundle_sha256) == context$source_bundle_sha256))
      stop("NL projection does not consume the actual current accepted source", call. = FALSE)
  }
  generated <- unique(as.character(manifest$generated_at_utc))
  if (length(generated) != 1L || !identical(generated, as.character(simulation$generated_at_utc)))
    stop("NL projection has no unique operational computation timestamp", call. = FALSE)
  time <- nl_elo_time(generated)
  state_time <- max(nl_elo_time(state$state_manifest$generated_at_utc))
  if (time < state_time || time < nl_elo_time(context$as_of_utc)) stop("NL projection computation predates its actual parents", call. = FALSE)
  invisible(TRUE)
}
