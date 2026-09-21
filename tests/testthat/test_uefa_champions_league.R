library(testthat)

if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(
    normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                 winslash = "/", mustWork = TRUE),
    "tests/testthat/helper_uefa_champions_league.R"
  ), local = .GlobalEnv)
}

phase20_test_rules_evidence_path <- file.path(
  phase20_test_project_root,
  "data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json"
)

phase20_test_read_rules_evidence <- function() {
  expect_true(file.exists(phase20_test_rules_evidence_path))
  jsonlite::fromJSON(phase20_test_rules_evidence_path, simplifyDataFrame = TRUE)
}

test_that("Wave 0 declares the complete 36-club / 144-fixture graph", {
  graph <- phase20_fixture_graph_36x144()

  expect_identical(nrow(graph$clubs), 36L)
  expect_identical(length(unique(graph$clubs$club_id)), 36L)
  expect_identical(nrow(graph$fixtures), 144L)
  expect_identical(length(unique(graph$fixtures$fixture_id)), 144L)
  expect_identical(graph$authority_mode, "fixture")
  expect_true(isTRUE(graph$fixture_authority))
  expect_false(isTRUE(graph$production_eligible))
  expect_true(is.null(graph$selector_path))
  expect_true(is.null(graph$production_root))
  expect_true(all(graph$fixtures$matchday %in% 1:8))
  expect_true(all(graph$fixtures$kickoff_confirmed))
  expect_true(all(nzchar(graph$fixtures$venue_id)))
  expect_true(all(nzchar(graph$fixtures$source_lineage_id)))
  degree <- table(c(graph$fixtures$home_club_id, graph$fixtures$away_club_id))
  expect_identical(as.integer(degree[graph$clubs$club_id]), rep(8L, 36L))
  expect_identical(as.integer(table(graph$fixtures$home_club_id)[graph$clubs$club_id]), rep(4L, 36L))
  expect_identical(as.integer(table(graph$fixtures$away_club_id)[graph$clubs$club_id]), rep(4L, 36L))
  expect_true(all(graph$fixtures$home_club_id != graph$fixtures$away_club_id))
  expect_true(all(grepl("^[0-9a-f]{64}$", graph$fixtures$source_row_sha256)))
})

test_that("Wave 0 keeps the approved-shape release fixture non-promotable", {
  release <- phase20_approved_release_fixture()
  expect_identical(release$authority_mode, "fixture")
  expect_true(isTRUE(release$fixture_authority))
  expect_false(isTRUE(release$production_eligible))
  expect_false(isTRUE(release$selector_authorized))
  expect_true(is.null(release$selector_path))
  expect_true(is.null(release$trusted_release_root))
  expect_identical(release$root_scope, "process_temporary")
  expect_identical(nrow(release$forecast_rows), 144L)
  expect_true(all(abs(release$forecast_rows$prob_home +
                     release$forecast_rows$prob_draw +
                     release$forecast_rows$prob_away - 1) < 1e-12))
  expect_true(all(release$forecast_rows$feature_cutoff_utc <
                  release$forecast_rows$kickoff_utc))
})

test_that("Wave 0 pins the exact seven regulation records and unresolved draw row", {
  evidence <- phase20_test_read_rules_evidence()
  expected_ids <- c("article_17", "article_18", "article_19", "article_20",
                    "article_21", "article_22", "annex_b",
                    "draw_procedure_2026_27")
  expected_urls <- c(
    article_17 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-17-Match-system-league-phase-Online",
    article_18 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-18-Equality-of-points-league-phase-Online",
    article_19 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-19-Draw-system-knockout-phase-Online",
    article_20 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-20-Match-system-knockout-phase-Online",
    article_21 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online",
    article_22 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-22-Match-system-final-Online",
    annex_b = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Annex-B-UEFA-Champions-League-Competition-System-Online"
  )
  expect_identical(nrow(evidence), 8L)
  expect_setequal(evidence$document_id, expected_ids)
  expect_identical(names(evidence), c(
    "document_id", "article_or_annex", "edition_id", "canonical_domain",
    "canonical_article", "source_url", "artifact_url", "source_url_role",
    "reviewer", "reviewed_at_utc", "raw_sha256", "canonical_sha256",
    "accepted", "complete", "unresolved_reason"
  ))
  regulations <- evidence$document_id != "draw_procedure_2026_27"
  expect_true(all(evidence$edition_id == phase20_test_edition_id))
  expect_true(all(evidence$canonical_domain == "documents.uefa.com"))
  expect_identical(unname(evidence$source_url[regulations]), unname(expected_urls[evidence$document_id[regulations]]))
  expect_identical(unname(evidence$artifact_url[regulations]), unname(expected_urls[evidence$document_id[regulations]]))
  expect_true(all(evidence$accepted[regulations]))
  expect_true(all(evidence$complete[regulations]))
  expect_true(all(nzchar(evidence$reviewer[regulations])))
  expect_true(all(grepl("^[0-9a-f]{64}$", evidence$raw_sha256[regulations])))
  expect_true(all(grepl("^[0-9a-f]{64}$", evidence$canonical_sha256[regulations])))
  draw <- evidence[evidence$document_id == "draw_procedure_2026_27", , drop = FALSE]
  expect_identical(draw$article_or_annex, "draw_procedure")
  expect_identical(draw$canonical_article, "Article-19-Draw-system-knockout-phase-Online")
  expect_identical(draw$source_url, expected_urls[["article_19"]])
  expect_true(is.na(draw$artifact_url) || is.null(draw$artifact_url))
  expect_identical(draw$source_url_role, "governing_rule_anchor_for_missing_artifact")
  expect_identical(draw$reviewer, "unreviewed")
  expect_true(is.na(draw$reviewed_at_utc))
  expect_true(is.na(draw$raw_sha256))
  expect_true(is.na(draw$canonical_sha256))
  expect_false(isTRUE(draw$accepted))
  expect_false(isTRUE(draw$complete))
  expect_identical(draw$unresolved_reason, "missing_edition_draw_procedure")
})

test_that("Wave 0 records the closed Phase 19 parent-reason normalization map", {
  cases <- phase20_expected_parent_reason_cases()
  expect_identical(nrow(cases), 13L)
  expect_true(all(cases$normalized_status %in% c(
    "production_human_needed", "production_blocked"
  )))
  expect_setequal(unique(na.omit(cases$human_needed_reason)), c(
    "phase18_authority_missing", "phase19_cr01_cr05_repair_pending",
    "phase19_selector_not_accepted"
  ))
  phase20_test_require_ucl_entrypoints("phase20_result_contract", "parent-reason-normalization")
})

test_that("UCLRULE-01: project-owned league table and qualification bands", {
  phase20_test_require_ucl_entrypoints(c("ucl_validate_schedule", "ucl_build_state"), "UCLRULE-01")
})

test_that("UCLRULE-02: Article 18 ordered trace and unresolved rank interval", {
  phase20_test_require_ucl_entrypoints("ucl_apply_article18", "UCLRULE-02")
})

test_that("UCLRULE-03: accepted eight-opponent schedule contract", {
  phase20_test_require_ucl_entrypoints("ucl_validate_schedule", "UCLRULE-03")
})

test_that("UCLOUT-01: immutable approved pre-kickoff forecast ledger", {
  phase20_test_require_ucl_entrypoints("ucl_build_forecast_ledger", "UCLOUT-01")
})

test_that("UCLOUT-02: fixed-results conditional rank and band probabilities", {
  phase20_test_require_ucl_entrypoints(c("ucl_run_simulation", "ucl_aggregate_rank_distributions"), "UCLOUT-02")
})

test_that("UCLOUT-03: legal rank-constrained draw paths", {
  phase20_test_require_ucl_entrypoints(c("ucl_enumerate_legal_knockout_paths", "ucl_validate_draw_artifact"), "UCLOUT-03")
})

test_that("UCLOUT-04: two-leg and neutral-final resolution", {
  phase20_test_require_ucl_entrypoints(c("ucl_resolve_two_leg_tie", "ucl_resolve_final"), "UCLOUT-04")
})

test_that("UCLOUT-05: stage accounting and monotone progression", {
  phase20_test_require_ucl_entrypoints(c("ucl_aggregate_stage_events", "ucl_validate_progression_reconciliation"), "UCLOUT-05")
})

test_that("UCLOUT-06: canonical replay and protected incumbent bytes", {
  phase20_test_require_ucl_entrypoints(c(
    "ucl_validate_outcome_candidate", "ucl_write_outcome_candidate",
    "ucl_outcomes_manifest"
  ), "UCLOUT-06")
})

phase20_edge_inventory <- phase20_expected_edge_probe_inventory()
for (edge_index in seq_len(nrow(phase20_edge_inventory))) {
  edge <- phase20_edge_inventory[edge_index, , drop = FALSE]
  test_that(paste(edge$edge_id, "stable edge contract"), {
    phase20_test_require_ucl_entrypoints(
      edge$required_entrypoint,
      scope = edge$edge_id
    )
  })
}

