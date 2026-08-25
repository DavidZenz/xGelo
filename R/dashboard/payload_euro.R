# EURO qualifying adapter. In particular, it preserves pre_draw and blocked
# states instead of inferring groups, fixtures, teams, or probabilities.

phase17_validate_euro_bundle <- function(bundle) {
  if (!is.list(bundle) || !identical(as.character(bundle$edition_id), "uefa_euro_2028_qualifying")) {
    stop("Phase 17 EURO adapter received the wrong edition", call. = FALSE)
  }
  phase17_normalize_metadata(bundle)
  lifecycle <- phase17_bundle_scalar(bundle, "lifecycle_state")
  if (identical(lifecycle, "pre_draw")) {
    for (name in c("structure", "standings", "fixtures", "results", "form", "forecasts", "projected_outcomes")) {
      if (length(phase17_bundle_rows(bundle, name))) stop("Phase 17 EURO pre_draw cannot contain fabricated rows", call. = FALSE)
    }
  }
  invisible(TRUE)
}

phase17_payload_euro <- function(bundle, batch_id = "phase17-fixture-batch-v1") {
  phase17_validate_euro_bundle(bundle)
  phase17_neutral_payload(bundle, phase17_section_ids(), batch_id = batch_id)
}

phase17_build_euro_payload <- phase17_payload_euro
phase17_adapt_euro_bundle <- phase17_payload_euro
