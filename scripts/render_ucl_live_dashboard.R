#!/usr/bin/env Rscript

# Render accepted live facts even while the independent forecast release is
# unavailable. This produces a reviewable local dashboard without replacing
# the other public competition routes.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
dependencies <- c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
  "R/competition/ucl_source_acceptance.R", "R/competition/ucl_source_bundle.R",
  "R/competition/ucl_source_refresh.R", "R/dashboard/edition_registry_v2.R",
  "R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R", "R/dashboard/renderer_v2.R",
  "R/competition/edition_registry.R", "R/club/identity.R", "R/club/identity_bootstrap.R",
  "R/club/history_contract.R", "R/competition/football_data_org_adapter.R",
  "R/club/model_contract.R", "R/evaluation/proper_scores.R", "R/evaluation/benchmark_scores.R",
  "R/club/evaluation_protocol.R", "R/club/rating.R", "R/club/goal_model.R",
  "R/club/calibration.R", "R/club/evaluation.R", "R/club/release.R", "R/club/live_predictions.R")
for (path in dependencies) source(file.path(root, path), local = TRUE)
render_ucl_live_dashboard <- function(forecast_mode = "approved",
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), write_output = TRUE) {
if (!forecast_mode %in% c("approved", "disabled")) stop("Unsupported CL forecast mode")
current <- phase18_read_ucl_refresh_current(file.path(root, "data/competition/accepted"),
  file.path(root, "data/competition/registries"))
registry <- phase21_default_edition_registry()
row <- registry[registry$edition_id == "ucl_2026_27", , drop = FALSE]
batch <- paste0("ucl-live-", substr(current$pointer$accepted_generation_sha256, 1L, 16L))
forecasts <- if (identical(forecast_mode, "approved")) phase19_forecast_current_ucl(now_utc) else
  phase19_live_club_absence("team_strength_calibration_not_accepted",
    "Team-strength predictions have not passed calibration checks. Match predictions are disabled.")
payload <- phase21_payload_ucl_live_source(current, row, batch, now_utc, forecasts)
if (identical(forecast_mode, "disabled")) payload$metadata$forecast_model_quality <-
  "Disabled pending team-strength model calibration QA"
if (!isTRUE(write_output)) return(payload)
out <- file.path(root, "outputs/competition/ucl_2026_27/dashboard")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
html <- phase21_render_dashboard(payload, "champions-league")
stage <- tempfile(".ucl-render-", tmpdir = out)
dir.create(stage)
on.exit(unlink(stage, recursive = TRUE), add = TRUE)
jsonlite::write_json(payload, file.path(stage, "payload.json"), auto_unbox = TRUE,
  null = "null", na = "null", pretty = TRUE)
writeLines(html, file.path(stage, "index.html"), useBytes = TRUE)
targets <- file.path(out, c("payload.json", "index.html"))
before <- lapply(targets, function(path) if (file.exists(path)) readBin(path, "raw", n = file.info(path)$size) else NULL)
committed <- FALSE
on.exit(if (!committed) for (i in seq_along(targets)) {
  if (is.null(before[[i]])) unlink(targets[i]) else writeBin(before[[i]], targets[i])
}, add = TRUE)
for (i in seq_along(targets)) if (!file.rename(file.path(stage, basename(targets[i])), targets[i]))
  stop("Could not install validated local CL render")
committed <- TRUE
cat("UCL_DASHBOARD source=accepted forecast=", payload$metadata$forecast_status, " clubs=", length(payload$sections$standings$rows),
  " fixtures=", length(payload$sections$fixtures$rows), " results=", length(payload$sections$results$rows),
  " path=", file.path(out, "index.html"), "\n", sep = "")
invisible(payload)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 1L || (length(args) && !grepl("^--forecast-mode=(approved|disabled)$", args)))
    stop("Use --forecast-mode=approved or --forecast-mode=disabled")
  render_ucl_live_dashboard(if (length(args)) sub("^--forecast-mode=", "", args) else "approved")
}
