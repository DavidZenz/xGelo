# Native source selection is explicit and bound to both the original bytes and
# the selected exchange rows. Excluded source lines remain inspectable evidence.
phase18_history_scope_schema <- function() c(
  "source_id", "raw_sha256", "selection_policy", "parsed_rows", "selected_rows",
  "excluded_rows", "selected_source_match_ids", "selected_rows_sha256", "row_sha256"
)

phase18_select_openfootball_history <- function(rows, competition_id, selected_source_match_ids = NULL) {
  ucl <- identical(competition_id, "uefa-champions-league") ||
    grepl("^ucl$|champions-league", competition_id)
  stages <- if (ucl) c("GROUP_STAGE", "LEAGUE_STAGE") else c(
    "REGULAR_SEASON", "CHAMPIONSHIP_LEAGUE_STAGE", "RELEGATION_LEAGUE_STAGE",
    "EUROPE_LEAGUE_STAGE"
  )
  keep <- rows$status == "completed" & rows$score_semantics == "regulation" & rows$stage %in% stages
  eligible <- keep
  if (!is.null(selected_source_match_ids)) {
    ids <- strsplit(as.character(selected_source_match_ids), "|", fixed = TRUE)[[1L]]
    if (!length(ids) || any(!nzchar(ids)) || anyDuplicated(ids) || any(!ids %in% rows$source_match_id[eligible]))
      phase18_history_abort("history_scope_membership_invalid", "Reviewed first-observation membership contains unsupported source lines")
    keep <- eligible & rows$source_match_id %in% ids
  }
  selected <- rows[keep, phase18_openfootball_exchange_schema(), drop = FALSE]
  rownames(selected) <- NULL
  excluded <- rows[!keep, , drop = FALSE]
  if (nrow(excluded)) excluded$selection_exclusion <- ifelse(
    excluded$status != "completed", paste0("source_status_", excluded$status),
    ifelse(!excluded$stage %in% stages, "stage_outside_reviewed_training_scope",
           ifelse(excluded$score_semantics != "regulation", "unresolved_or_nonregulation_score",
                  "regulation_fixture_retained_at_another_pinned_snapshot"))
  ) else excluded$selection_exclusion <- character()
  policy <- if (ucl) "ucl_group_league_regulation_v1" else "domestic_league_regulation_v1"
  if (!is.null(selected_source_match_ids)) policy <- paste0(policy, "_first_observed")
  list(rows = selected, excluded = excluded, policy = policy,
       selected_rows_sha256 = phase18_history_table_sha256(selected, "source_match_id"))
}

phase18_history_source_scope <- function(rows, source_row, selected_source_match_ids = NULL) {
  selection <- phase18_select_openfootball_history(rows, source_row$competition_id[[1L]], selected_source_match_ids)
  if (!is.null(selected_source_match_ids) && "commit_utc" %in% names(source_row) &&
      any(paste0(selection$rows$event_date, "T00:00:00Z") > source_row$commit_utc[[1L]]))
    phase18_history_abort("history_result_predates_event", "A selected result cannot have been observed before its event date")
  scope <- data.frame(
    source_id = source_row$source_id[[1L]], raw_sha256 = source_row$raw_sha256[[1L]],
    selection_policy = selection$policy, parsed_rows = as.character(nrow(rows)),
    selected_rows = as.character(nrow(selection$rows)), excluded_rows = as.character(nrow(selection$excluded)),
    selected_source_match_ids = if (is.null(selected_source_match_ids)) "" else paste(sort(selection$rows$source_match_id), collapse = "|"),
    selected_rows_sha256 = selection$selected_rows_sha256, row_sha256 = "",
    stringsAsFactors = FALSE
  )
  scope$row_sha256 <- phase18_history_row_sha256(scope)
  scope
}

phase18_ingest_pinned_club_source <- function(path, source_row, scopes = NULL) {
  if (grepl("\\.csv$", path, ignore.case = TRUE)) {
    rows <- phase18_history_read_csv(path)
    if (!identical(names(rows), phase18_openfootball_exchange_schema())) {
      phase18_history_abort("unsupported_history_source_format", "Exchange CSV schema is not exact")
    }
    return(list(rows = rows, diagnostics = data.frame(), exclusions = data.frame()))
  }
  rows <- phase18_read_openfootball_source(path, source_row, strict = TRUE)
  if (!is.data.frame(scopes) || !identical(names(scopes), phase18_history_scope_schema())) {
    phase18_history_abort("history_scope_not_reviewed", "Native source requires the exact reviewed selection inventory")
  }
  expected <- scopes[scopes$source_id == source_row$source_id[[1L]], , drop = FALSE]
  membership <- if (nrow(expected) == 1L && nzchar(expected$selected_source_match_ids[[1L]])) expected$selected_source_match_ids[[1L]] else NULL
  scope <- phase18_history_source_scope(rows, source_row, membership)
  if (nrow(expected) != 1L || !identical(unname(as.character(expected[1L, ])), unname(as.character(scope[1L, ])))) {
    phase18_history_abort("history_scope_mismatch", "Pinned native selection differs from the owner-review inventory")
  }
  selected <- phase18_select_openfootball_history(rows, source_row$competition_id[[1L]], membership)
  list(rows = selected$rows, diagnostics = attr(rows, "diagnostics"), exclusions = selected$excluded)
}
