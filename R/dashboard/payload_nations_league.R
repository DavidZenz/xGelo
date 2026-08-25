# Nations League adapter. Competition-specific field selection stops here;
# downstream payload validation and rendering are shared with EURO.

phase17_validate_nations_league_bundle <- function(bundle) {
  if (!is.list(bundle) || !identical(as.character(bundle$edition_id), "uefa_nations_league_2026_27")) {
    stop("Phase 17 Nations League adapter received the wrong edition", call. = FALSE)
  }
  phase17_normalize_metadata(bundle)
  invisible(TRUE)
}

phase17_payload_nations_league <- function(bundle, batch_id = "phase17-fixture-batch-v1") {
  phase17_validate_nations_league_bundle(bundle)
  phase17_neutral_payload(bundle, phase17_section_ids(), batch_id = batch_id)
}

phase17_build_nations_league_payload <- phase17_payload_nations_league
phase17_adapt_nations_league_bundle <- phase17_payload_nations_league
