# Standard repository tests use code-only temporary roots, never live parents.
cl_sparse_origin <- Sys.getenv("XGELO_CL_PAYLOAD_TEST_PROJECT", unset = "")
if (!nzchar(cl_sparse_origin)) {
  cl_sparse_origin <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(cl_sparse_origin, "R/competition/ucl_production_runtime.R"))) {
    next_root <- dirname(cl_sparse_origin)
    if (identical(next_root, cl_sparse_origin)) stop("CL test code origin missing")
    cl_sparse_origin <- next_root
  }
}
sys.source(file.path(cl_sparse_origin, "tests/testthat/ucl_sparse_runtime_test_helper.R"), envir = environment())
cl_payload_test_root <- ucl_sparse_code_test_project(ucl_sparse_test_code_origin("XGELO_CL_PAYLOAD_TEST_PROJECT"))
cl_payload_namespace <- function() {
  env <- new.env(parent = baseenv())
  for (file in c("R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R", "R/dashboard/ucl_persisted_outcome_payload.R"))
    sys.source(file.path(cl_payload_test_root, file), env)
  env
}
cl_payload_declared_tables <- function() {
  ids <- sprintf("club_fixture_%02d", 1:36)
  clubs <- data.frame(club_id = ids, display_name = paste("Fixture club", 1:36), stringsAsFactors = FALSE)
  ranks <- data.frame(iteration = rep(1:2, each = 36), club_id = rep(ids, 2), rank = c(1:36, c(2:36, 1)), stringsAsFactors = FALSE)
  stages <- c("direct_round_of_16", "knockout_play_off", "eliminated", "round_of_16", "quarter_final", "semi_final", "final", "champion")
  p <- expand.grid(club_id = ids, stage_id = stages, stringsAsFactors = FALSE)
  p$simulation_count <- 2L
  p$probability <- vapply(seq_len(nrow(p)), function(i) {
    r <- ranks$rank[ranks$club_id == p$club_id[[i]]]
    eligible <- switch(p$stage_id[[i]], direct_round_of_16 = r <= 8, knockout_play_off = r >= 9 & r <= 24,
      eliminated = r >= 25, round_of_16 = r <= 16, quarter_final = r <= 8, semi_final = r <= 4, final = r <= 2, champion = r == 1)
    sum(eligible)/2
  }, numeric(1))
  z <- 1.959963984540054; n <- 2
  centre <- (p$probability + z*z/(2*n))/(1 + z*z/n)
  radius <- z*sqrt(p$probability*(1-p$probability)/n + z*z/(4*n*n))/(1+z*z/n)
  u <- data.frame(club_id = p$club_id, stage_id = p$stage_id, mc95_lower = pmax(0, centre-radius), mc95_upper = pmin(1, centre+radius))
  paths <- data.frame(stage_id = c("final", "champion"), participant_a = ids[1], participant_b = ids[2], leg_order = "single_neutral")
  list(clubs = clubs, tables = list(league_rank_inputs = ranks, progression_probabilities = p,
    monte_carlo_uncertainty = u, knockout_paths = paths))
}

test_that("declared rank counts and stage chances map to inspectable presentation", {
  env <- cl_payload_namespace(); fixture <- cl_payload_declared_tables()
  mapped <- env$.phase21_cl_format_tables(fixture$tables, fixture$clubs)
  expect_identical(mapped$counts$simulation_count, 2L)
  expect_equal(nrow(mapped$counts$rank_counts), 1296)
  expect_equal(nrow(mapped$counts$stage_counts), 288)
  expect_equal(nrow(mapped$rows$qualification_bands), 108)
  expect_equal(nrow(mapped$rows$progression_probabilities), 288)
  expect_equal(nrow(mapped$rows$projected_outcomes), 36)
  expect_equal(nrow(mapped$rows$knockout_paths), 1)
  first <- mapped$counts$rank_counts[mapped$counts$rank_counts$club_id == fixture$clubs$club_id[[1]], ]
  expect_identical(first$count[1:3], c(1L, 1L, 0L))
  expect_identical(mapped$rows$rank_distributions$Chance[1:3], c("50%", "50%", "0%"))
  expect_identical(mapped$rows$knockout_paths$Format, "Single match at neutral venue")
  expect_false(anyNA(mapped$rows$progression_probabilities$Club))
})

test_that("formatting retains rare positive chances and refuses incomplete inputs", {
  env <- cl_payload_namespace(); fixture <- cl_payload_declared_tables()
  expect_false(identical(env$.phase21_cl_percent(0.000001), "0%"))
  changed <- fixture$tables; changed$league_rank_inputs <- changed$league_rank_inputs[-1L, ]
  expect_error(env$.phase21_cl_format_tables(changed, fixture$clubs), "rank counts")
  changed <- fixture$tables; changed$progression_probabilities$simulation_count <- 2.5
  expect_error(env$.phase21_cl_format_tables(changed, fixture$clubs), "exact integer")
  changed <- fixture$tables; changed$monte_carlo_uncertainty <- changed$monte_carlo_uncertainty[-1L, ]
  expect_error(env$.phase21_cl_format_tables(changed, fixture$clubs), "sampling intervals")
  changed <- fixture$tables; changed$knockout_paths$participant_a <- "unknown_club"
  expect_error(env$.phase21_cl_format_tables(changed, fixture$clubs), "unknown clubs")
})

test_that("actual missing-parent production read clears projections without changing facts", {
  env <- cl_payload_namespace()
  before <- getwd()
  context <- env$.phase21_cl_context(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  expect_identical(context$status, "blocked")
  expect_identical(context$reason_code, "publication_missing")
  facade <- env$.phase21_cl_facade()
  expect_identical(parent.env(facade), baseenv())
  expect_identical(facade$.ucl_runtime_load()$phase20_ucl_project_root, cl_payload_test_root)
  expect_identical(getwd(), before)
  payload <- env$phase21_payload_ucl(list(edition_id = "ucl_2026_27", status = "production_blocked"))
  payload$sections$standings$rows <- list(list(Club = "Declared fixture fact", Points = 3L))
  original <- payload$sections[c("standings", "fixtures", "results", "form", "match_forecasts")]
  for (id in env$.phase21_cl_tournament_sections()) payload$sections[[id]]$rows <- list(list(Chance = "100%"))
  payload$metadata$tournament_status <- "available"
  payload$metadata$tournament_publication_sha256 <- strrep("a", 64)
  payload$metadata$simulation_count <- 10000L
  payload$cl_tournament_evidence <- list(simulation_count = 10000L)
  output <- env$phase21_ucl_attach_persisted_outcomes(payload)
  expect_identical(output$metadata$tournament_status, "unavailable")
  expect_true(all(vapply(output$sections[env$.phase21_cl_tournament_sections()], function(x) !length(x$rows), logical(1))))
  expect_identical(output$sections[names(original)], original)
  expect_null(output$cl_tournament_evidence)
  expect_true(is.na(output$metadata$tournament_publication_sha256))
  expect_true(is.na(output$metadata$simulation_count))
  expect_false(isTRUE(output$metadata$production_eligible))
  expect_true(env$phase21_validate_ucl_persisted_outcome_payload(output))
  expect_identical(names(formals(env$phase21_ucl_attach_persisted_outcomes)), c("payload", "now_utc"))
  expect_error(env$phase21_ucl_attach_persisted_outcomes(list(edition_id = "wc2026")), "CL facts payload")
})

test_that("low simulation counts stay explicitly ineligible for presentation", {
  env <- cl_payload_namespace()
  # Only the internal scalar precision seam is exercised, with no read receipt.
  context <- list(receipt = list(tables = list(simulation_metadata = data.frame(simulation_count = 1000L))))
  values <- env$.phase21_cl_projection_values(context)
  expect_identical(values$status, "blocked")
  expect_identical(values$reason_code, "insufficient_monte_carlo_precision")
  expect_null(values$rows)
})

test_that("public flags or counts cannot authorize populated CL outlooks", {
  env <- cl_payload_namespace()
  payload <- env$phase21_payload_ucl(list(edition_id = "ucl_2026_27", status = "production_blocked"))
  payload$metadata$production_eligible <- TRUE
  payload$metadata$tournament_status <- "available"
  payload$metadata$tournament_publication_sha256 <- strrep("a", 64)
  payload$metadata$simulation_count <- 10000L
  payload$sections$projected_outcomes$rows <- list(list(Club = "Declared fixture", Chance = "100%"))
  expect_false(env$phase21_validate_ucl_persisted_outcome_payload(payload))
  payload$sections$projected_outcomes$rows <- list()
  payload$cl_tournament_evidence <- list(simulation_count = 10000L)
  expect_false(env$phase21_validate_ucl_persisted_outcome_payload(payload))
  payload$metadata$tournament_status <- "unavailable"
  payload$cl_tournament_evidence <- NULL
  payload$sections$projected_outcomes$status <- "available"
  expect_false(env$phase21_validate_ucl_persisted_outcome_payload(payload))
  expect_identical(names(formals(env$phase21_validate_ucl_persisted_outcome_payload)), c("payload", "now_utc"))
})
