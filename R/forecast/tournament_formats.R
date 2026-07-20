#' Data-driven frozen tournament-format adapters

benchmark_parse_stage_counts <- function(value) {
  parts <- strsplit(as.character(value), "\\|", fixed = FALSE)[[1]]
  key_value <- strsplit(parts, ":", fixed = TRUE)
  stats::setNames(
    as.integer(vapply(key_value, `[[`, character(1), 2L)),
    vapply(key_value, `[[`, character(1), 1L)
  )
}

benchmark_format_reach_mass <- function(format_id) {
  switch(
    as.character(format_id),
    wc32_r16 = c(round_of_16 = 16, quarterfinal = 8, semifinal = 4, final = 2, champion = 1),
    euro16_qf = c(quarterfinal = 8, semifinal = 4, final = 2, champion = 1),
    euro24_r16_best4third = c(round_of_16 = 16, quarterfinal = 8, semifinal = 4, final = 2, champion = 1),
    stop("Unknown registered tournament format", call. = FALSE)
  )
}

#' Load one frozen tournament format and its routing table
#' @export
get_tournament_format_adapter <- function(format_id, formats, route_rules) {
  format <- formats[formats$format_id == format_id, , drop = FALSE]
  if (nrow(format) != 1L) stop("Tournament format must resolve to exactly one registry row", call. = FALSE)
  routes <- route_rules[route_rules$format_id == format_id, , drop = FALSE]
  adapter <- list(
    format = format,
    routes = routes,
    fixture_stage_counts = benchmark_parse_stage_counts(format$stage_counts),
    reach_mass = benchmark_format_reach_mass(format_id)
  )
  class(adapter) <- "registered_tournament_format"
  validate_tournament_format(adapter)
  adapter
}

#' Validate one registered tournament-format adapter
#' @export
validate_tournament_format <- function(adapter) {
  if (!inherits(adapter, "registered_tournament_format")) stop("adapter is not a registered tournament format", call. = FALSE)
  format <- adapter$format
  required <- c(
    "format_id", "team_count", "group_count", "group_size",
    "group_stage_fixture_count", "group_advancers", "best_third_advancers",
    "first_knockout_stage", "stage_counts"
  )
  missing <- setdiff(required, names(format))
  if (length(missing)) stop("Tournament format missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (format$team_count != format$group_count * format$group_size) {
    stop("Tournament format team and group counts do not reconcile", call. = FALSE)
  }
  expected_group_fixtures <- format$group_count * choose(format$group_size, 2)
  if (format$group_stage_fixture_count != expected_group_fixtures) {
    stop("Tournament format group fixture count is invalid", call. = FALSE)
  }
  first_mass <- format$group_count * format$group_advancers + format$best_third_advancers
  if (first_mass != unname(adapter$reach_mass[[format$first_knockout_stage]])) {
    stop("Tournament format first knockout-stage mass is invalid", call. = FALSE)
  }
  expected_knockout_matches <- sum(adapter$fixture_stage_counts[names(adapter$fixture_stage_counts) != "group"])
  if (expected_knockout_matches < 1L || tail(adapter$fixture_stage_counts, 1) != 1L) {
    stop("Tournament knockout fixture counts are invalid", call. = FALSE)
  }
  if (!nrow(adapter$routes)) stop("Tournament format requires frozen routing rules", call. = FALSE)
  invisible(adapter)
}

#' Accumulate team stage-reach probabilities from common-random-number paths
#' @export
accumulate_stage_probabilities <- function(
    paths, team_ids, adapter, run_id, model_id, edition_id,
    anchor_boundary_id, n_simulations, seed_id
) {
  required <- c("simulation_id", "team_id", "stage_id")
  if (!is.data.frame(paths) || any(!required %in% names(paths))) {
    stop("Tournament paths require simulation_id, team_id, and stage_id", call. = FALSE)
  }
  if (n_simulations != 50000L) stop("Registered tournaments require 50,000 paths", call. = FALSE)
  if (any(!paths$simulation_id %in% seq_len(n_simulations))) stop("Tournament paths contain unknown simulation IDs", call. = FALSE)
  if (any(!paths$team_id %in% team_ids)) stop("Tournament paths contain unknown teams", call. = FALSE)
  stages <- names(adapter$reach_mass)
  if (any(!paths$stage_id %in% stages)) stop("Tournament paths contain an unregistered reach stage", call. = FALSE)
  if (anyDuplicated(paths[required])) stop("Tournament paths contain duplicate team-stage reaches", call. = FALSE)
  expected_per_path <- adapter$reach_mass
  observed <- table(
    factor(paths$simulation_id, levels = seq_len(n_simulations)),
    factor(paths$stage_id, levels = stages)
  )
  if (any(sweep(observed, 2, expected_per_path, `!=`))) {
    stop("Tournament path stage participant mass is invalid", call. = FALSE)
  }
  keys <- expand.grid(team_id = team_ids, stage_id = stages, stringsAsFactors = FALSE)
  counts <- aggregate(
    list(reaches = rep(1L, nrow(paths))),
    paths[c("team_id", "stage_id")], sum
  )
  keys <- merge(keys, counts, by = c("team_id", "stage_id"), all.x = TRUE, sort = FALSE)
  keys$reaches[is.na(keys$reaches)] <- 0L
  keys$stage_order <- match(keys$stage_id, stages)
  keys$probability <- keys$reaches / n_simulations
  result <- data.frame(
    run_id = run_id, model_id = model_id, edition_id = edition_id,
    anchor_boundary_id = anchor_boundary_id, team_id = keys$team_id,
    stage_id = keys$stage_id, stage_order = keys$stage_order,
    probability = keys$probability, n_simulations = as.integer(n_simulations),
    seed_id = seed_id, format_id = adapter$format$format_id,
    stringsAsFactors = FALSE
  )
  result <- result[order(result$team_id, result$stage_order), , drop = FALSE]
  rownames(result) <- NULL
  validate_stage_probabilities(result)
  result
}

#' Simulate one registered tournament with a model-independent ledger seed
#'
#' The supplied path generator is called once after the common seed is set. It
#' must return all team/stage reaches for the requested number of paths.
#' @export
simulate_registered_tournament <- function(
    adapter, team_ids, seed_ledger, path_generator,
    run_id, model_id, edition_id, anchor_boundary_id,
    n_simulations = 50000L
) {
  validate_tournament_format(adapter)
  if (length(unique(team_ids)) != adapter$format$team_count) {
    stop("Registered tournament team count does not match the format", call. = FALSE)
  }
  if (!is.function(path_generator)) stop("path_generator must be a function", call. = FALSE)
  seeds <- seed_ledger[
    seed_ledger$purpose == "stage_simulation" & seed_ledger$model_independent,
    , drop = FALSE
  ]
  if (nrow(seeds) != 1L) stop("Tournament requires exactly one model-independent stage seed", call. = FALSE)
  if ("model_id" %in% names(seed_ledger)) stop("Tournament seed ledger must be independent of model ID", call. = FALSE)
  set.seed(as.integer(seeds$seed))
  paths <- path_generator(adapter, as.character(team_ids), as.integer(n_simulations))
  accumulate_stage_probabilities(
    paths, as.character(team_ids), adapter, run_id, model_id, edition_id,
    anchor_boundary_id, as.integer(n_simulations), as.character(seeds$seed_id)
  )
}
