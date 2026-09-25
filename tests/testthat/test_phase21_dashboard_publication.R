phase21_test_root <- local({
  candidate <- if (basename(getwd()) == "testthat") file.path(getwd(), "../..") else getwd()
  normalizePath(candidate, winslash = "/", mustWork = TRUE)
})

phase21_test_source <- function(files, env) {
  for (file in files) sys.source(file.path(phase21_test_root, file), env)
  invisible(env)
}

testthat::test_that("Phase 21 registry supports zero, one, and many editions", {
  env <- new.env(parent = globalenv())
  phase21_test_source(c("R/dashboard/edition_registry_v2.R", "R/dashboard/payload_contract_v2.R"), env)
  registry <- env$phase21_default_edition_registry()
  testthat::expect_equal(nrow(env$phase21_validate_registry(registry)), 3L)
  testthat::expect_equal(nrow(env$phase21_validate_registry(registry[FALSE, , drop = FALSE])), 0L)
  testthat::expect_equal(nrow(env$phase21_validate_registry(registry[1L, , drop = FALSE])), 1L)
  testthat::expect_equal(length(env$phase21_batch_relative_inventory(registry[FALSE, , drop = FALSE])), 2L)
  testthat::expect_equal(length(env$phase21_batch_relative_inventory(registry)), 14L)
  duplicate <- registry
  duplicate$route_slug[[2L]] <- duplicate$route_slug[[1L]]
  testthat::expect_error(env$phase21_validate_registry(duplicate), "route_slug")
  unsafe <- registry
  unsafe$route_slug[[1L]] <- "../raw"
  testthat::expect_error(env$phase21_validate_registry(unsafe), "unsafe")
})

testthat::test_that("legacy Phase 17 payloads normalize into the twelve-section contract", {
  env <- new.env(parent = globalenv())
  phase21_test_source(c("R/dashboard/payload_contract.R", "R/dashboard/payload_nations_league.R",
                        "R/dashboard/payload_euro.R", "R/dashboard/edition_registry_v2.R",
                        "R/dashboard/payload_contract_v2.R"), env)
  registry <- env$phase21_default_edition_registry()
  legacy <- env$phase17_payload_nations_league(env$phase17_fixture_bundle("uefa_nations_league_2026_27"), "legacy-batch")
  payload <- env$phase21_normalize_phase17_payload(legacy, registry[1L, , drop = FALSE], "v2-batch")
  testthat::expect_identical(names(payload$sections), env$phase21_section_ids())
  testthat::expect_identical(payload$metadata$batch_id, "v2-batch")
  testthat::expect_identical(payload$sections$rank_distributions$status, "unavailable")
  testthat::expect_length(payload$sections$rank_distributions$rows, 0L)
  testthat::expect_true(isTRUE(env$phase21_validate_payload(payload, registry)))
})

testthat::test_that("UCL adapter maps named artifacts and preserves unresolved states", {
  env <- new.env(parent = globalenv())
  phase21_test_source(c("R/dashboard/edition_registry_v2.R", "R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R"), env)
  registry <- env$phase21_default_edition_registry()
  candidate <- list(
    edition_id = "ucl_2026_27", status = "unresolved_draw_procedure", authority_mode = "fixture",
    fixture_authority = TRUE, production_eligible = FALSE, unresolved = "missing_edition_draw_procedure",
    artifacts = list(
      competition_topology = data.frame(stage_id = "league", stringsAsFactors = FALSE),
      league_schedule = data.frame(fixture_id = "fixture-1", lifecycle_status = "scheduled", stringsAsFactors = FALSE),
      projected_standings = data.frame(club_id = "club-1", rank_interval_min = 1L, rank_interval_max = 3L, stringsAsFactors = FALSE),
      projected_rankings = data.frame(club_id = "club-1", rank_status = "unresolved", qualification_band = "unknown", stringsAsFactors = FALSE),
      knockout_paths = data.frame(path_status = "unresolved", unresolved_reason = "missing_edition_draw_procedure", stringsAsFactors = FALSE),
      progression_probabilities = data.frame(club_id = "club-1", probability = NA_real_, status = "unresolved", stringsAsFactors = FALSE),
      fixture_forecast_ledger = data.frame(fixture_id = "fixture-1", forecast_status = "available", stringsAsFactors = FALSE),
      simulation_metadata = data.frame(edition_id = "ucl_2026_27", authority_mode = "fixture", stringsAsFactors = FALSE),
      outcomes_manifest = data.frame(manifest_sha256 = "fixture-manifest", stringsAsFactors = FALSE)
    )
  )
  payload <- env$phase21_payload_ucl(candidate, registry[3L, , drop = FALSE], "ucl-batch")
  testthat::expect_true(isTRUE(env$phase21_validate_payload(payload, registry)))
  testthat::expect_equal(nrow(as.data.frame(payload$sections$fixtures$rows)), 1L)
  testthat::expect_identical(payload$sections$knockout_paths$status, "unresolved")
  testthat::expect_match(payload$sections$knockout_paths$reason, "missing_edition_draw_procedure")
  testthat::expect_true(is.na(payload$sections$progression_probabilities$rows[[1L]]$probability))
  testthat::expect_identical(payload$sections$form$status, "unavailable")
  blocked <- env$phase21_payload_ucl(list(status = "production_human_needed", human_needed_reason = "phase18_authority_missing", edition_id = "ucl_2026_27"), registry[3L, , drop = FALSE], "blocked-batch")
  testthat::expect_identical(blocked$sections$standings$status, "blocked")
  testthat::expect_length(blocked$sections$standings$rows, 0L)
})

testthat::test_that("Phase 21 renderer escapes hostile text and exposes all sections and metadata", {
  env <- new.env(parent = globalenv())
  phase21_test_source(c("R/dashboard/edition_registry_v2.R", "R/dashboard/payload_contract_v2.R", "R/dashboard/renderer_v2.R"), env)
  registry <- env$phase21_default_edition_registry()
  payload <- env$phase21_blocked_payload("ucl_2026_27", "<script>alert(\"x\")</script>", registry[3L, , drop = FALSE], "render-batch")
  html <- env$phase21_render_dashboard(payload, "champions-league")
  for (label in c("Standings", "Fixtures", "Results", "Form", "Match forecasts", "Rank distributions", "Qualification bands", "Knockout paths", "Progression probabilities")) testthat::expect_true(grepl(tolower(label), tolower(html), fixed = TRUE))
  testthat::expect_match(html, "@media", fixed = TRUE)
  testthat::expect_match(html, "prefers-reduced-motion", fixed = TRUE)
  testthat::expect_match(html, "Refresh blocked", fixed = TRUE)
  testthat::expect_match(html, "&lt;script&gt;", fixed = TRUE)
  testthat::expect_false(grepl("<script>alert", html, fixed = TRUE))
  testthat::expect_true(grepl("simulation seed", tolower(html), fixed = TRUE))
})

testthat::test_that("Phase 21 publication is exact and preserves incumbent bytes on rollback", {
  env <- new.env(parent = globalenv())
  phase21_test_source(c("R/dashboard/edition_registry_v2.R", "R/dashboard/payload_contract_v2.R", "R/dashboard/renderer_v2.R", "R/dashboard/publication_v2.R"), env)
  registry <- env$phase21_default_edition_registry()
  payloads <- lapply(seq_len(nrow(registry)), function(index) env$phase21_blocked_payload(registry$edition_id[[index]], "blocked", registry[index, , drop = FALSE], "publish-batch"))
  names(payloads) <- registry$edition_id
  public_root <- tempfile("phase21-public-")
  first <- env$phase21_publish_batch(payloads, registry, public_root, batch_id = "publish-batch")
  testthat::expect_true(isTRUE(first$valid))
  testthat::expect_true(isTRUE(env$phase21_validate_batch(public_root, registry)$valid))
  incumbent_files <- list.files(public_root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
  incumbent <- lapply(incumbent_files, function(path) readBin(path, "raw", n = as.integer(file.info(path)$size)))
  names(incumbent) <- sub(paste0("^", gsub("([\\.\\+\\?\\(\\)\\[\\]\\{\\}\\^\\$\\|])", "\\\\\\1", public_root), "/?"), "", incumbent_files)
  replacement <- payloads
  replacement$ucl_2026_27$metadata$batch_id <- "replacement"
  testthat::expect_error(env$phase21_publish_batch(replacement, registry, public_root, batch_id = "replacement", injectors = list(read_back = function() stop("injected read-back"))))
  after_files <- list.files(public_root, recursive = TRUE, full.names = TRUE, include.dirs = FALSE)
  after <- lapply(after_files, function(path) readBin(path, "raw", n = as.integer(file.info(path)$size)))
  names(after) <- sub(paste0("^", gsub("([\\.\\+\\?\\(\\)\\[\\]\\{\\}\\^\\$\\|])", "\\\\\\1", public_root), "/?"), "", after_files)
  testthat::expect_identical(incumbent, after)
  zero <- registry
  zero$enabled <- FALSE
  zero$publish_enabled <- FALSE
  zero_root <- tempfile("phase21-zero-")
  testthat::expect_true(isTRUE(env$phase21_publish_batch(list(), zero, zero_root, batch_id = "zero")$valid))
  testthat::expect_true(isTRUE(env$phase21_validate_batch(zero_root, zero)$valid))
})

testthat::test_that("registry dispatch sends all editions through one v2 refresh and blocks fixture mechanics", {
  env <- new.env(parent = globalenv())
  sys.source(file.path(phase21_test_root, "scripts/refresh_competition_dashboards.R"), env)
  registry <- env$phase21_default_edition_registry()
  bundles <- list(
    uefa_nations_league_2026_27 = env$phase17_fixture_bundle("uefa_nations_league_2026_27"),
    uefa_euro_2028_qualifying = env$phase17_fixture_bundle("uefa_euro_2028_qualifying"),
    ucl_2026_27 = list(status = "mechanics_complete", fixture_authority = TRUE, authority_mode = "fixture", edition_id = "ucl_2026_27")
  )
  result <- env$phase21_refresh_main(registry = registry, bundles = bundles, project_root = phase21_test_root, dry_run = TRUE, batch_id = "dispatch-batch")
  testthat::expect_true(isTRUE(result$valid))
  testthat::expect_equal(names(result$payloads), registry$edition_id)
  testthat::expect_identical(result$payloads$ucl_2026_27$metadata$source_status, "blocked")
  testthat::expect_match(result$payloads$ucl_2026_27$sections$overview$reason, "non-promotable")
  testthat::expect_identical(unname(vapply(result$payloads, function(payload) payload$metadata$batch_id, character(1))), rep("dispatch-batch", 3L))
})
