#' Frozen weighting schedule for Phase 09 supervised benchmark fits
#'
#' @return Named list describing the immutable schedule.
#' @export
benchmark_weight_schedule <- function() {
  list(
    schedule_id = "benchmark_supervised_730d_v1",
    half_life_days = 730,
    finals = 1.8,
    qualifier_or_nations_league = 1.3,
    friendly = 0.6,
    otherwise = 1.0,
    normalization = "mean_one_within_snapshot",
    recursive_elo = "not_applied"
  )
}

#' Tournament-importance multiplier for supervised benchmark observations
#'
#' @param tournament Tournament labels.
#' @return Numeric importance multipliers.
#' @export
benchmark_importance_weight <- function(tournament) {
  label <- tolower(trimws(as.character(tournament)))
  label[is.na(label)] <- ""
  is_friendly <- grepl("friendly", label)
  is_qualifier <- grepl("qualif|qualification|nations league", label)
  is_finals <- grepl("world cup|uefa euro|european championship", label) &
    !is_qualifier & !is_friendly
  ifelse(is_finals, 1.8, ifelse(is_qualifier, 1.3, ifelse(is_friendly, 0.6, 1.0)))
}

#' Frozen recency and importance weights for one supervised snapshot
#'
#' @param observations Match observations with a date and tournament column.
#' @param cutoff Exclusive evidence cutoff for the snapshot.
#' @param date_col Observation-date column.
#' @param tournament_col Tournament-label column.
#' @return Positive weights normalized to mean one.
#' @export
benchmark_observation_weights <- function(
    observations, cutoff, date_col = NULL, tournament_col = "tournament"
) {
  if (!is.data.frame(observations) || !nrow(observations)) {
    stop("observations must be a non-empty data frame", call. = FALSE)
  }
  if (is.null(date_col)) {
    date_col <- if ("actual_completion_date" %in% names(observations)) {
      "actual_completion_date"
    } else {
      "date"
    }
  }
  if (!date_col %in% names(observations)) stop("observations are missing the date column", call. = FALSE)
  dates <- as.Date(observations[[date_col]])
  cutoff <- as.Date(cutoff)
  if (length(cutoff) != 1L || is.na(cutoff)) stop("cutoff must be one valid date", call. = FALSE)
  if (any(is.na(dates) | dates >= cutoff)) {
    stop("supervised observations must be strictly before the snapshot cutoff", call. = FALSE)
  }
  tournament <- if (tournament_col %in% names(observations)) observations[[tournament_col]] else ""
  age_days <- as.numeric(cutoff - dates)
  raw <- 2^(-age_days / benchmark_weight_schedule()$half_life_days) *
    benchmark_importance_weight(tournament)
  if (any(!is.finite(raw) | raw <= 0)) stop("benchmark observation weights must be positive and finite", call. = FALSE)
  raw / mean(raw)
}
