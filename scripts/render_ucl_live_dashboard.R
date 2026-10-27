#!/usr/bin/env Rscript

# Render accepted live facts even while the independent forecast release is
# unavailable. This produces a reviewable local dashboard without replacing
# the other public competition routes.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
dependencies <- c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
  "R/competition/ucl_source_acceptance.R", "R/competition/ucl_source_bundle.R",
  "R/competition/ucl_source_refresh.R", "R/dashboard/edition_registry_v2.R",
  "R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R", "R/dashboard/renderer_v2.R")
for (path in dependencies) source(file.path(root, path), local = TRUE)
current <- phase18_read_ucl_refresh_current(file.path(root, "data/competition/accepted"),
  file.path(root, "data/competition/registries"))
registry <- phase21_default_edition_registry()
row <- registry[registry$edition_id == "ucl_2026_27", , drop = FALSE]
batch <- paste0("ucl-live-", substr(current$pointer$accepted_generation_sha256, 1L, 16L))
payload <- phase21_payload_ucl_live_source(current, row, batch)
out <- file.path(root, "outputs/competition/ucl_2026_27/dashboard")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(payload, file.path(out, "payload.json"), auto_unbox = TRUE,
  null = "null", na = "null", pretty = TRUE)
writeLines(phase21_render_dashboard(payload, "champions-league"), file.path(out, "index.html"), useBytes = TRUE)
cat("UCL_DASHBOARD source=accepted forecast=unavailable clubs=", length(payload$sections$standings$rows),
  " fixtures=", length(payload$sections$fixtures$rows), " results=", length(payload$sections$results$rows),
  " path=", file.path(out, "index.html"), "\n", sep = "")
