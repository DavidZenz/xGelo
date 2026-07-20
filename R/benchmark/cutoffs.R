#' Leakage-safe benchmark boundaries and holdout sealing

benchmark_boundary_hashes <- function(data) {
  if (exists("benchmark_row_sha256", mode = "function")) {
    return(benchmark_row_sha256(data, "boundary_sha256"))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark boundary hashes", call. = FALSE)
  fields <- setdiff(names(data), "boundary_sha256")
  vapply(seq_len(nrow(data)), function(i) {
    values <- vapply(data[i, fields, drop = FALSE], function(x) {
      if (inherits(x, "Date")) x <- format(x, "%Y-%m-%d")
      if (is.logical(x)) x <- ifelse(is.na(x), "", ifelse(x, "true", "false"))
      x <- as.character(x)
      x[is.na(x)] <- ""
      x
    }, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

#' Construct frozen and date-complete updating boundaries
#'
#' @param tournaments Tournament registry.
#' @param fixtures Fixture registry.
#' @return Boundary registry.
#' @export
make_benchmark_boundaries <- function(tournaments, fixtures) {
  required_tournaments <- c("edition_id", "opener_date", "expected_fixture_count")
  required_fixtures <- c("edition_id", "actual_completion_date")
  if (length(missing <- setdiff(required_tournaments, names(tournaments)))) stop("Tournament data missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(missing <- setdiff(required_fixtures, names(fixtures)))) stop("Fixture data missing: ", paste(missing, collapse = ", "), call. = FALSE)
  tournaments$opener_date <- as.Date(tournaments$opener_date)
  fixtures$actual_completion_date <- as.Date(fixtures$actual_completion_date)
  tournaments <- tournaments[order(tournaments$edition_id), , drop = FALSE]

  frozen <- data.frame(
    schema_version = "1.0",
    boundary_id = paste0(tournaments$edition_id, "__frozen"),
    edition_id = tournaments$edition_id,
    sequence = 0L,
    track = "frozen",
    assessment_date = tournaments$opener_date,
    evidence_cutoff_exclusive = tournaments$opener_date,
    prior_boundary_id = "",
    fixture_count = as.integer(tournaments$expected_fixture_count),
    completed_input_count = 0L,
    status = "frozen",
    stringsAsFactors = FALSE
  )
  updating <- do.call(rbind, lapply(tournaments$edition_id, function(edition_id) {
    rows <- fixtures[fixtures$edition_id == edition_id, , drop = FALSE]
    dates <- sort(unique(rows$actual_completion_date))
    data.frame(
      schema_version = "1.0",
      boundary_id = paste(edition_id, dates, sep = "__"),
      edition_id = edition_id,
      sequence = seq_along(dates),
      track = "updating",
      assessment_date = dates,
      evidence_cutoff_exclusive = dates,
      prior_boundary_id = c("", paste(edition_id, head(dates, -1L), sep = "__")),
      fixture_count = vapply(dates, function(date) sum(rows$actual_completion_date == date), integer(1)),
      completed_input_count = vapply(dates, function(date) sum(rows$actual_completion_date < date), integer(1)),
      status = "frozen",
      stringsAsFactors = FALSE
    )
  }))
  boundaries <- rbind(frozen, updating)
  rownames(boundaries) <- NULL
  boundaries$boundary_sha256 <- ""
  boundaries$boundary_sha256 <- benchmark_boundary_hashes(boundaries)
  boundaries
}

#' Select history strictly before a benchmark boundary
#'
#' @param history Historical match rows.
#' @param boundary One boundary row or an ISO cutoff.
#' @return Eligible prior rows in canonical order.
#' @export
eligible_benchmark_history <- function(history, boundary) {
  date_col <- if ("actual_completion_date" %in% names(history)) "actual_completion_date" else if ("date" %in% names(history)) "date" else stop("History requires actual_completion_date or date", call. = FALSE)
  cutoff <- if (is.data.frame(boundary)) boundary$evidence_cutoff_exclusive[1] else boundary[1]
  cutoff <- as.Date(cutoff)
  dates <- as.Date(history[[date_col]])
  eligible <- history[!is.na(dates) & dates < cutoff, , drop = FALSE]
  if (nrow(eligible)) {
    order_columns <- intersect(c(date_col, "fixture_id", "match_id", "home_team_id", "away_team_id"), names(eligible))
    args <- lapply(eligible[order_columns], function(x) if (inherits(x, "Date")) as.character(x) else x)
    eligible <- eligible[do.call(order, c(args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rownames(eligible) <- NULL
  eligible
}

#' Assert the strict date-batch cutoff contract
#'
#' @param fixtures Fixture registry.
#' @param boundaries Boundary registry.
#' @param tournaments Optional tournament registry for opener checks.
#' @return TRUE invisibly.
#' @export
assert_benchmark_cutoffs <- function(fixtures, boundaries, tournaments = NULL) {
  fixture_required <- c("edition_id", "fixture_id", "actual_completion_date", "boundary_id")
  boundary_required <- c("boundary_id", "edition_id", "sequence", "track", "assessment_date", "evidence_cutoff_exclusive", "prior_boundary_id")
  if (length(missing <- setdiff(fixture_required, names(fixtures)))) stop("Fixtures missing cutoff columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(missing <- setdiff(boundary_required, names(boundaries)))) stop("Boundaries missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(boundaries$boundary_id)) stop("Boundary IDs must be unique", call. = FALSE)
  fixtures$actual_completion_date <- as.Date(fixtures$actual_completion_date)
  boundaries$assessment_date <- as.Date(boundaries$assessment_date)
  boundaries$evidence_cutoff_exclusive <- as.Date(boundaries$evidence_cutoff_exclusive)
  updating <- boundaries[boundaries$track == "updating", , drop = FALSE]
  match_index <- match(fixtures$boundary_id, updating$boundary_id)
  if (any(is.na(match_index))) stop("Every fixture must reference one registered updating boundary", call. = FALSE)
  if (any(fixtures$actual_completion_date != updating$assessment_date[match_index]) || any(fixtures$actual_completion_date != updating$evidence_cutoff_exclusive[match_index])) {
    stop("Updating boundaries must use the complete assessment date as the exclusive cutoff", call. = FALSE)
  }
  date_keys <- paste(fixtures$edition_id, fixtures$actual_completion_date, sep = "|")
  if (any(vapply(split(fixtures$boundary_id, date_keys), function(x) length(unique(x)) != 1L, logical(1)))) stop("Same-date fixtures must share one boundary", call. = FALSE)
  for (edition_id in unique(updating$edition_id)) {
    rows <- updating[updating$edition_id == edition_id, , drop = FALSE]
    rows <- rows[order(rows$sequence), , drop = FALSE]
    if (!identical(as.integer(rows$sequence), seq_len(nrow(rows)))) stop("Updating boundary sequences must be contiguous", call. = FALSE)
    if (nrow(rows) > 1L && !identical(as.character(rows$prior_boundary_id[-1]), as.character(rows$boundary_id[-nrow(rows)]))) stop("Updating prior-boundary linkage is incomplete", call. = FALSE)
    first_prior <- rows$prior_boundary_id[1]
    if (!is.na(first_prior) && nzchar(first_prior)) stop("First updating boundary must not have a prior boundary", call. = FALSE)
  }
  frozen <- boundaries[boundaries$track == "frozen", , drop = FALSE]
  if (nrow(frozen) != length(unique(fixtures$edition_id))) stop("Every edition requires one frozen boundary", call. = FALSE)
  if (!is.null(tournaments)) {
    openers <- setNames(as.Date(tournaments$opener_date), tournaments$edition_id)
    if (any(frozen$evidence_cutoff_exclusive != openers[frozen$edition_id])) stop("Frozen evidence must be the pre-opener state", call. = FALSE)
  }
  invisible(TRUE)
}

benchmark_state_hash <- function(history, edition_id, track, boundary_id, cutoff) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark state hashes", call. = FALSE)
  history_hash <- if (exists("canonical_benchmark_sha256", mode = "function") && ncol(history)) {
    key <- intersect(c("fixture_id", "match_id", "actual_completion_date", "date"), names(history))[1]
    canonical_benchmark_sha256(history, key)
  } else {
    digest::digest(history, algo = "sha256")
  }
  digest::digest(paste(edition_id, track, boundary_id, as.character(cutoff), history_hash, sep = "|"), algo = "sha256", serialize = FALSE)
}

#' Build one frozen and one date-batch updating state per fixture
#'
#' @param history Historical evidence rows.
#' @param fixtures Assessment fixtures.
#' @param boundaries Valid benchmark boundaries.
#' @return Fixture-track state table.
#' @export
build_benchmark_track_states <- function(history, fixtures, boundaries) {
  assert_benchmark_cutoffs(fixtures, boundaries)
  fixtures$actual_completion_date <- as.Date(fixtures$actual_completion_date)
  boundaries$assessment_date <- as.Date(boundaries$assessment_date)
  boundaries$evidence_cutoff_exclusive <- as.Date(boundaries$evidence_cutoff_exclusive)
  state_rows <- vector("list", nrow(fixtures) * 2L)
  cursor <- 0L
  for (i in seq_len(nrow(fixtures))) {
    for (track in c("frozen", "updating")) {
      boundary <- if (track == "frozen") {
        boundaries[boundaries$edition_id == fixtures$edition_id[i] & boundaries$track == "frozen", , drop = FALSE]
      } else {
        boundaries[boundaries$boundary_id == fixtures$boundary_id[i] & boundaries$track == "updating", , drop = FALSE]
      }
      if (nrow(boundary) != 1L) stop("Fixture-track state must resolve exactly one boundary", call. = FALSE)
      eligible <- eligible_benchmark_history(history, boundary)
      date_col <- if ("actual_completion_date" %in% names(eligible)) "actual_completion_date" else if ("date" %in% names(eligible)) "date" else NULL
      max_date <- if (is.null(date_col) || !nrow(eligible)) as.Date(NA) else max(as.Date(eligible[[date_col]]), na.rm = TRUE)
      cursor <- cursor + 1L
      state_rows[[cursor]] <- data.frame(
        fixture_id = fixtures$fixture_id[i],
        edition_id = fixtures$edition_id[i],
        track = track,
        boundary_id = boundary$boundary_id,
        assessment_date = fixtures$actual_completion_date[i],
        evidence_cutoff_exclusive = boundary$evidence_cutoff_exclusive,
        eligible_history_rows = nrow(eligible),
        max_evidence_date = max_date,
        state_sha256 = benchmark_state_hash(eligible, fixtures$edition_id[i], track, boundary$boundary_id, boundary$evidence_cutoff_exclusive),
        stringsAsFactors = FALSE
      )
    }
  }
  states <- do.call(rbind, state_rows)
  states <- states[order(states$fixture_id, states$track), , drop = FALSE]
  rownames(states) <- NULL
  states
}

benchmark_holdout_rows <- function(data) {
  holdout <- rep(FALSE, nrow(data))
  if ("edition_id" %in% names(data)) holdout <- holdout | tolower(as.character(data$edition_id)) == "wc2026"
  if ("fixture_id" %in% names(data)) holdout <- holdout | grepl("^wc2026", tolower(as.character(data$fixture_id)))
  if ("competition_id" %in% names(data) && "edition_year" %in% names(data)) {
    holdout <- holdout | (tolower(as.character(data$competition_id)) == "world_cup" & suppressWarnings(as.integer(data$edition_year)) == 2026L)
  }
  holdout
}

benchmark_outcome_columns <- function(data) {
  explicit <- c(
    "regulation_home_goals", "regulation_away_goals", "final_home_goals", "final_away_goals",
    "home_score", "away_score", "actual_home_goals", "actual_away_goals", "actual_winner_team",
    "winner_team_id", "result", "outcome", "observed_outcome", "went_extra_time", "went_penalties"
  )
  intersect(explicit, names(data))
}

#' Guard sealed World Cup 2026 outcomes before development callbacks
#'
#' @param data Candidate data passed to an adapter.
#' @param purpose Access purpose.
#' @param adapter Optional callback invoked only after the guard passes.
#' @return Guarded data or adapter result.
#' @export
guard_benchmark_purpose <- function(data, purpose, adapter = NULL) {
  development_purposes <- c("development", "baseline_reproduction", "candidate_selection", "fit", "feature_selection", "tuning", "calibration")
  allowed_purposes <- c(development_purposes, "sealed_evaluation", "reporting")
  if (length(purpose) != 1L || is.na(purpose) || !purpose %in% allowed_purposes) stop("Unknown benchmark purpose", call. = FALSE)
  if (!is.data.frame(data)) stop("Benchmark purpose guard requires a data frame", call. = FALSE)
  holdout <- benchmark_holdout_rows(data)
  labels <- benchmark_outcome_columns(data)
  label_present <- function(column) {
    values <- data[[column]][holdout]
    if (is.logical(values)) return(any(!is.na(values)))
    any(!is.na(values) & nzchar(as.character(values)))
  }
  if (purpose %in% development_purposes && any(holdout) && length(labels) && any(vapply(labels, label_present, logical(1)))) {
    stop("Sealed wc2026 outcome labels are forbidden for benchmark development purposes", call. = FALSE)
  }
  if (!is.null(adapter)) {
    if (!is.function(adapter)) stop("adapter must be a function", call. = FALSE)
    return(adapter(data))
  }
  data
}
