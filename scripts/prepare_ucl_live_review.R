#!/usr/bin/env Rscript

# Prepare evidence-bound owner review inputs from the real fixed API window.
# No acceptance, registry, selector or dashboard pointer is modified here.
source("scripts/accept_ucl_provider.R", local = TRUE)

prepare_ucl_live_review <- function() {
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  fetched <- phase18_fd_fetch_window(phase18_fd_request_plan(), phase18_fd_live_performer())
  payload <- lapply(fetched, `[[`, "parsed")
  if (!identical(payload$competition_metadata$code, "CL") ||
      !startsWith(payload$competition_metadata$currentSeason$startDate, "2026-")) {
    stop("Provider did not return the supported CL season", call. = FALSE)
  }
  teams <- phase18_fd_list_rows(payload$teams$teams, "teams")
  if (length(teams) != 36L || length(payload$matches$matches) != 144L) {
    stop("Owner review requires the complete 36-club / 144-match window", call. = FALSE)
  }
  value <- function(field) vapply(teams, function(team) phase18_fd_scalar(team[[field]], field), character(1))
  ids <- value("id")
  if (anyDuplicated(ids)) stop("Provider club IDs are duplicated", call. = FALSE)
  current <- data.frame(source_system = "football_data_org_v4", source_row = paste0("teams:", ids),
    source_club_id = ids, display_name = value("name"), event_at_utc = now,
    stringsAsFactors = FALSE)
  tokens <- phase18_extract_club_tokens(current_resources = current)
  review <- tokens[, c("schema_version", "hash_encoding_version", "corpus", "source_system", "source_row",
    "source_club_id", "display_value", "evidence_sha256"), drop = FALSE]
  review$schema_version <- "phase18-club-review-v2"
  review$club_id <- paste0("club_fd_", review$source_club_id)
  review$entity_kind <- "club"
  review$canonical_name <- review$display_value
  areas <- setNames(vapply(teams, function(team) phase18_fd_scalar(team$area$code, "team.area.code"), character(1)), ids)
  review$association_code <- unname(areas[review$source_club_id])
  review$valid_from_utc <- "2026-01-01T00:00:00Z"
  review$valid_to_utc <- "2027-07-01T00:00:00Z"
  review$reviewer <- "pending_owner_review"
  review$reviewed_at_utc <- now
  review$review_state <- "pending"
  review$source_bundle_id <- "ucl-live-identity-review-2026-27"
  review$row_sha256 <- ""
  review <- phase18_hash_club_review_rows(review[, phase18_club_review_schema(), drop = FALSE])
  phase18_validate_club_identity_review(tokens, review)
  phase18_fd_assert_secret_absent(list(tokens = tokens, review = review), Sys.getenv("FOOTBALL_DATA_API_TOKEN"))
  root <- file.path(phase18_accept_project_root, "data/club/identity_reviews")
  phase18_write_csv_atomic(tokens, file.path(root, "proposed_current_ucl_tokens.csv"))
  phase18_write_csv_atomic(review, file.path(root, "proposed_current_ucl_review.csv"))
  cat("UCL_REVIEW status=pending clubs=36 league_phase_matches=144 production_mutated=false\n")
  print(review[, c("source_club_id", "club_id", "canonical_name", "association_code")], row.names = FALSE)
  invisible(review)
}

if (sys.nframe() == 0L) {
  tryCatch(prepare_ucl_live_review(), error = function(error) {
    cat("UCL_REVIEW status=blocked reason=", if (is.null(error$reason_code)) "preparation_failed" else error$reason_code,
      " message=", conditionMessage(error), "\n", sep = "")
    quit(save = "no", status = 2L)
  })
}
