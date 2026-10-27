#!/usr/bin/env Rscript

# Fixed-edition live acquisition -> validated normalized candidate -> atomic
# accepted-source promotion. Existing terms/identity acceptance is required.
# Use normal R startup to load the ignored project credential configuration.
source("scripts/accept_ucl_provider.R", local = TRUE)
source("scripts/refresh_ucl_source.R", local = TRUE)

update_ucl_live_source <- function() {
  stamp <- format(Sys.time(), "%Y%m%d%H%M%S", tz = "UTC")
  bundle_id <- paste0("ucl-live-", stamp)
  candidate_root <- file.path("data/competition/candidates", bundle_id)
  result <- phase18_accept_ucl_provider_main(c(
    "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
    "--review-path", "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/provider_terms_review.csv",
    "--evidence-root", "data/competition/provider_acceptance", "--mode", "provider_live",
    "--club-registry-root", "data/club/registries", "--candidate-root", candidate_root,
    "--bundle-id", bundle_id))
  if (!identical(result$result_type, "bundle") || !identical(result$status, "success") ||
      !isTRUE(result$promotion_eligible)) {
    stop("Live candidate is blocked: ", result$reason_code, call. = FALSE)
  }
  refresh <- phase18_refresh_ucl_source_main(c("--candidate-root", candidate_root))
  if (!identical(refresh$status, "accepted")) {
    stop("Live source refresh is blocked: ", refresh$reason_code, call. = FALSE)
  }
  cat("UCL_LIVE_UPDATE source=accepted bundle=", bundle_id, " forecast_authority_unchanged=true\n", sep = "")
  invisible(refresh)
}

if (sys.nframe() == 0L) {
  if (length(commandArgs(trailingOnly = TRUE))) stop("This fixed-edition command accepts no arguments", call. = FALSE)
  update_ucl_live_source()
}
