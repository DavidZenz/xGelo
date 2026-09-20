library(testthat)

`%||%` <- function(x, y) if (is.null(x)) y else x

phase18_adversarial_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_adversarial_required_critical <- sprintf("CR-%02d", seq_len(15L))
phase18_adversarial_required_warnings <- sprintf("WR-%02d", seq_len(4L))

source(file.path(phase18_adversarial_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/club/identity.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/club/identity_bootstrap.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/competition/football_data_org_adapter.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/competition/ucl_source_bundle.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/competition/ucl_source_refresh.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "R/club/history_contract.R"), local = .GlobalEnv)
source(file.path(phase18_adversarial_root, "scripts/accept_ucl_provider.R"), local = .GlobalEnv, chdir = TRUE)

phase18_adversarial_import_helpers <- function(relative_path) {
  for (expression in parse(file.path(phase18_adversarial_root, relative_path))) {
    assignment <- is.call(expression) &&
      (identical(expression[[1L]], as.name("<-")) || identical(expression[[1L]], as.name("=")))
    if (!assignment || !is.symbol(expression[[2L]]) ||
        !startsWith(as.character(expression[[2L]]), "phase18_")) next
    eval(expression, envir = .GlobalEnv)
  }
}

invisible(lapply(c(
  "tests/testthat/test_phase18_source_acceptance.R",
  "tests/testthat/test_phase18_football_data_adapter.R",
  "tests/testthat/test_phase18_source_bundle.R",
  "tests/testthat/test_phase18_refresh_failure.R",
  "tests/testthat/test_phase18_club_identity.R",
  "tests/testthat/test_phase18_club_history_contract.R"
), phase18_adversarial_import_helpers))

phase18_adversarial_executed <- new.env(parent = emptyenv())
phase18_adversarial_executed$ids <- character()

phase18_adversarial_probe_catalog <- function() list(
  critical = phase18_adversarial_required_critical,
  warnings = phase18_adversarial_required_warnings
)

phase18_adversarial_mark <- function(id) {
  required <- unname(unlist(phase18_adversarial_probe_catalog(), use.names = FALSE))
  if (!id %in% required) stop("unknown Phase 18 adversarial probe: ", id, call. = FALSE)
  if (id %in% phase18_adversarial_executed$ids) stop("duplicate Phase 18 adversarial probe: ", id, call. = FALSE)
  phase18_adversarial_executed$ids <- c(phase18_adversarial_executed$ids, id)
  invisible(id)
}

phase18_adversarial_raw <- function(path) {
  if (!file.exists(path)) return(raw())
  readBin(path, "raw", n = file.info(path)$size)
}

test_that("Phase 18 adversarial probe catalog is exact", {
  catalog <- phase18_adversarial_probe_catalog()
  expect_identical(catalog$critical, phase18_adversarial_required_critical)
  expect_identical(catalog$warnings, phase18_adversarial_required_warnings)
})

test_that("CR-01 delimiter collision hashes diverge and persisted tampering fails", {
  phase18_adversarial_mark("CR-01")
  left <- data.frame(first = "x|y", second = "z", stringsAsFactors = FALSE)
  right <- data.frame(first = "x", second = "y|z", stringsAsFactors = FALSE)
  expect_false(identical(
    phase18_hash_row_v2(left, schema_tag = "collision-probe-v1"),
    phase18_hash_row_v2(right, schema_tag = "collision-probe-v1")
  ))
  registries <- phase18_identity_test_registry()
  registries$clubs$canonical_name[[1L]] <- "attacker|club"
  expect_error(phase18_validate_club_registries(registries), class = "club_registry_hash_mismatch")
})

test_that("CR-02 durable owner review tampering and multiplexing fail closed", {
  phase18_adversarial_mark("CR-02")
  path <- tempfile("phase18-adversarial-review-", fileext = ".csv")
  review <- phase18_test_review("approved")
  utils::write.csv(review, path, row.names = FALSE, na = "", quote = TRUE)
  expect_identical(phase18_read_terms_review(path)$row_sha256, review$row_sha256)
  tampered <- review; tampered$reviewer[[1L]] <- "attacker"
  utils::write.csv(tampered, path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase18_read_terms_review(path), "integrity")
  multiplexed <- rbind(transform(review, review_set = "first"), transform(review, review_set = "second"))
  utils::write.csv(multiplexed, path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase18_read_terms_review(path), "review sets|schema")
})

test_that("CR-03 pending default edition expectations cannot authorize", {
  phase18_adversarial_mark("CR-03")
  pending <- phase18_default_edition_expectations("ucl_2026_27", "2026-09-19T12:00:00Z")
  validated <- phase18_validate_edition_expectations(pending)
  expect_false(validated$valid)
  expect_identical(validated$reason_code, "terms")
})

test_that("CR-04 incomplete or zero-observation capability evidence cannot automate", {
  phase18_adversarial_mark("CR-04")
  expectations <- phase18_gap08_approved_expectations()
  checks <- phase18_test_machine_checks("live_acceptance_probe", TRUE)
  expect_equal(nrow(checks), 16L)
  expect_true(phase18_validate_machine_checks(checks)$valid)
  expect_false(phase18_validate_machine_checks(checks[-1L, , drop = FALSE])$valid)
  zero <- checks; integrated <- zero$decision == "INTEGRATE"; zero$observed_count[integrated] <- 0L
  zero <- phase18_hash_machine_checks(zero)
  expect_false(phase18_validate_machine_checks(zero)$valid)
})

test_that("CR-05 changed schema fingerprint rows invalidate manifest authority", {
  phase18_adversarial_mark("CR-05")
  review <- phase18_test_review("approved")
  expectations <- phase18_gap08_approved_expectations()
  fingerprint <- phase18_default_schema_fingerprint("2026-09-19T12:00:00Z")
  checks <- phase18_default_machine_checks(expectations, "2026-09-19T12:00:00Z", "missing_credential")
  manifest <- phase18_build_acceptance_manifest(checks, review, expectations, fingerprint,
    "cr05", "2026-09-19T12:00:00Z", parser_commit_sha = "0123456789abcdef0123456789abcdef01234567")
  tampered <- fingerprint; tampered$endpoint[[1L]] <- "/competitions/evil"
  expect_error(phase18_validate_schema_fingerprint(tampered), "integrity")
  expect_error(phase18_validate_acceptance_manifest(
    manifest, checks, review, expectations, tampered
  ), "integrity|fingerprint")
})

test_that("CR-06 wrong-edition and unrelated-raw authority cannot promote", {
  phase18_adversarial_mark("CR-06")
  fetched <- phase18_bundle_test_fetched()
  aggregate <- phase18_ucl_raw_aggregate_sha256(fetched)
  manual <- phase18_bundle_test_manual_review(fetched)
  wrong_edition <- manual; wrong_edition$edition_id <- "ucl_2025_26"
  wrong_edition$manual_review_sha256 <- phase18_ucl_manual_review_hash(wrong_edition)
  wrong_edition$row_sha256 <- phase18_ucl_row_hash(wrong_edition)
  expect_error(phase18_validate_source_authority(
    "manual_reviewed", list(authority_type = "manual_source_review", manual_source_review = wrong_edition),
    "ucl_2026_27", aggregate
  ), class = "blocked_authority")
  wrong_raw <- manual; wrong_raw$aggregate_raw_sha256 <- paste(rep("0", 64L), collapse = "")
  wrong_raw$manual_review_sha256 <- phase18_ucl_manual_review_hash(wrong_raw)
  wrong_raw$row_sha256 <- phase18_ucl_row_hash(wrong_raw)
  expect_error(phase18_validate_source_authority(
    "manual_reviewed", list(authority_type = "manual_source_review", manual_source_review = wrong_raw),
    "ucl_2026_27", aggregate
  ), class = "blocked_authority")
})

test_that("CR-07 lexical in-root symlink remains rejected", {
  skip_on_os("windows")
  phase18_adversarial_mark("CR-07")
  root <- phase18_bundle_test_candidate_tree("cr07")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  target <- file.path(root, "raw", "competition_metadata.json")
  link <- file.path(root, "raw", "teams.json")
  unlink(link)
  expect_true(file.symlink(target, link))
  expect_error(phase18_read_ucl_candidate(root), class = "blocked_symlink")
})

test_that("CR-08 killed writer and concurrent readers see complete generations only", {
  skip_on_os("windows")
  phase18_adversarial_mark("CR-08")
  x <- phase18_refresh_test_sandbox()
  on.exit(unlink(x$root, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:01:00Z")
  pointer_path <- file.path(x$registry_root, "ucl_source_current.json")
  incumbent <- phase18_adversarial_raw(pointer_path)
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(x$candidate_root, phase18_refresh_test_candidate("ucl-refresh-next-v2", "next"))
  marker <- tempfile("phase18-cr08-marker-")
  writer <- parallel::mcparallel(phase18_refresh_ucl_source(
    x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    writer_hooks = list(interrupt = function(...) { writeLines("ready", marker); Sys.sleep(60) }),
    now_utc = "2026-09-20T18:02:00Z"
  ), silent = TRUE)
  deadline <- Sys.time() + 10
  while (!file.exists(marker) && Sys.time() < deadline) Sys.sleep(0.02)
  expect_true(file.exists(marker))
  tools::pskill(writer$pid, signal = 9L)
  suppressWarnings(parallel::mccollect(writer, wait = TRUE))
  expect_identical(phase18_adversarial_raw(pointer_path), incumbent)
  expect_silent(phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root))
  reader <- parallel::mcparallel({
    ids <- character()
    for (i in seq_len(30L)) {
      ids <- c(ids, phase18_read_ucl_refresh_current(
        x$accepted_root, x$registry_root
      )$accepted$bundle$bundle_id[[1L]])
      Sys.sleep(0.005)
    }
    ids
  }, silent = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:03:00Z")
  observed <- parallel::mccollect(reader)[[1L]]
  expect_true(all(observed %in% c("ucl-refresh-candidate-v2", "ucl-refresh-next-v2")))
})

test_that("CR-09 refresh lock loser mutates no durable bytes", {
  phase18_adversarial_mark("CR-09")
  x <- phase18_refresh_test_sandbox()
  on.exit(unlink(x$root, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:10:00Z")
  dir.create(file.path(x$root, ".phase18-ucl-refresh.lock"))
  before <- phase18_refresh_test_snapshot(x$root)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root)
  expect_identical(result$reason_code, "concurrent_refresh")
  expect_false(result$recorded)
  expect_identical(phase18_refresh_test_snapshot(x$root), before)
})

test_that("CR-10 bad prior ledger hashes block before append", {
  phase18_adversarial_mark("CR-10")
  x <- phase18_refresh_test_sandbox()
  on.exit(unlink(x$root, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:11:00Z")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  ledger <- file.path(current$transaction_generation_root, "ucl_source_refreshes.csv")
  value <- phase18_ucl_refresh_read_history(ledger); value$reason_code[[1L]] <- "schema_invalid"
  utils::write.csv(value, ledger, row.names = FALSE, na = "", quote = TRUE)
  before <- phase18_refresh_test_snapshot(x$root)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root)
  expect_identical(result$status, "blocked")
  expect_false(result$recorded)
  expect_identical(phase18_refresh_test_snapshot(x$root), before)
})

test_that("CR-11 unrelated or manual incumbent rejects provider exit", {
  phase18_adversarial_mark("CR-11")
  x <- phase18_refresh_test_sandbox()
  on.exit(unlink(x$root, recursive = TRUE, force = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:14:00Z")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  review <- phase18_refresh_test_exit_review(current, "retain")
  before <- phase18_adversarial_raw(file.path(x$registry_root, "ucl_source_current.json"))
  expect_error(phase18_apply_provider_exit(review, x$accepted_root, x$registry_root),
    class = "phase18_refresh_provider_exit_required")
  expect_identical(phase18_adversarial_raw(file.path(x$registry_root, "ucl_source_current.json")), before)
})

test_that("CR-12 pre-completion evidence is model-ineligible", {
  phase18_adversarial_mark("CR-12")
  rows <- utils::read.csv(
    file.path(phase18_adversarial_root, "tests/fixtures/phase18/openfootball/score_cases.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL
  )
  regulation <- rows[rows$source_match_id == "reg-1", , drop = FALSE]
  regulation$evidence_updated_at_utc <- "2025-05-01T19:59:59Z"
  normalized <- phase18_normalize_club_history(
    regulation, phase18_history_test_source(1L), phase18_history_test_registries(), "2025-06-01T00:00:00Z"
  )
  expect_false(normalized$counts_for_model)
  expect_identical(normalized$exclusion_reason, "evidence_before_completion")
})

test_that("CR-13 one stale team match or standings row fails aggregate freshness", {
  phase18_adversarial_mark("CR-13")
  reason <- function(payloads) phase18_fd_test_reason(phase18_fd_project_resources(
    phase18_fd_test_fetch(payloads), "ucl_2026_27", phase18_fd_test_registries(),
    phase18_fd_test_expectations(), now_utc = "2026-09-19T12:00:00Z"
  ))
  payloads <- phase18_fd_test_payloads(); payloads$teams$teams[[7L]]$lastUpdated <- "2020-01-01T00:00:00Z"
  expect_identical(reason(payloads), "blocked_stale_resource")
  payloads <- phase18_fd_test_payloads(); payloads$matches$matches[[9L]]$lastUpdated <- "2020-01-01T00:00:00Z"
  expect_identical(reason(payloads), "blocked_stale_resource")
  payloads <- phase18_fd_test_payloads(); payloads$standings$lastUpdated <- "2020-01-01T00:00:00Z"
  expect_identical(reason(payloads), "blocked_stale_resource")
})

test_that("CR-14 rehashed forged audit claims remain rejected", {
  phase18_adversarial_mark("CR-14")
  audit <- phase18_audit_club_history(
    phase18_history_test_good_matches(5L), phase18_history_test_source(5L),
    phase18_history_test_registries(), "2025-06-01T00:00:00Z",
    identity_review = phase18_history_test_review(), unresolved_identity = phase18_history_test_unresolved()
  )
  root <- tempfile("phase18-cr14-")
  phase18_history_write_bundle_candidate(audit, root)
  matches_path <- file.path(root, "matches.csv")
  forged <- phase18_history_read_csv(matches_path); forged$home_club_id[[1L]] <- ""
  forged$row_sha256 <- phase18_history_row_sha256(forged)
  phase18_history_write_csv(forged, matches_path)
  manifest_path <- file.path(root, "corpus_manifest.csv")
  manifest <- phase18_history_read_csv(manifest_path)
  manifest$matches_sha256 <- phase18_history_table_sha256(forged, c("source_id", "source_match_id", "match_id"))
  manifest$manifest_sha256 <- phase18_history_row_sha256(manifest, "manifest_sha256")
  phase18_history_write_csv(manifest, manifest_path)
  expect_error(phase18_validate_club_history_corpus(root), class = "history_recomputed_audit_mismatch")
})

test_that("CR-15 unsafe edition CLI creates no path and exits usage", {
  phase18_adversarial_mark("CR-15")
  sandbox <- tempfile("phase18-cr15-"); dir.create(sandbox)
  review_path <- file.path(sandbox, "review.csv")
  utils::write.csv(phase18_test_review("approved"), review_path, row.names = FALSE, na = "", quote = TRUE)
  before <- phase18_test_tree_sha(sandbox)
  output <- suppressWarnings(system2("Rscript", c(
    "--vanilla", file.path(phase18_adversarial_root, "scripts/accept_ucl_provider.R"),
    "--provider-id", "football_data_org_v4", "--edition-id", "../escape",
    "--review-path", review_path, "--evidence-root", file.path(sandbox, "evidence")
  ), stdout = TRUE, stderr = TRUE))
  expect_identical(attr(output, "status"), 64L)
  expect_identical(phase18_test_tree_sha(sandbox), before)
})

test_that("WR-01 inactive status and invalid validity remain closed", {
  phase18_adversarial_mark("WR-01")
  registries <- phase18_identity_test_registry()
  inactive <- registries; inactive$clubs$club_status[[1L]] <- "inactive"
  inactive <- phase18_hash_club_registry_rows(inactive)
  expect_error(phase18_resolve_club_identity(
    inactive, "provider", "101", "Alpha FC", "2026-09-19T12:00:00Z"
  ), class = "inactive_club_identity")
  invalid <- registries; invalid$clubs$valid_to_utc[[1L]] <- invalid$clubs$valid_from_utc[[1L]]
  invalid <- phase18_hash_club_registry_rows(invalid)
  expect_error(phase18_validate_club_registries(invalid), class = "invalid_club_validity")
})

test_that("WR-02 hidden and surplus candidate inventory remains closed", {
  phase18_adversarial_mark("WR-02")
  hidden <- phase18_bundle_test_candidate_tree("wr02-hidden")
  writeLines("secret", file.path(hidden, ".credential"))
  expect_error(phase18_read_ucl_candidate(hidden), class = "blocked_inventory")
  surplus <- phase18_bundle_test_candidate_tree("wr02-surplus")
  writeLines("surplus", file.path(surplus, "authority_evidence", "surplus.csv"))
  expect_error(phase18_read_ucl_candidate(surplus), class = "blocked_inventory")
})

test_that("WR-03 successful candidate CLI subprocess exits zero truthfully", {
  phase18_adversarial_mark("WR-03")
  evidence <- phase18_bundle_test_provider_evidence()
  payload <- tempfile("phase18-wr03-", fileext = ".rds")
  script <- tempfile("phase18-wr03-", fileext = ".R")
  candidate_root <- tempfile("phase18-wr03-candidate-")
  registry_root <- tempfile("phase18-wr03-registry-"); dir.create(registry_root)
  evidence_parent <- tempfile("phase18-wr03-evidence-")
  evidence_root <- file.path(evidence_parent, "football_data_org_v4", "ucl_2026_27")
  dir.create(evidence_root, recursive = TRUE)
  phase18_publish_acceptance_generation(
    evidence_root, evidence$owner_review, evidence$edition_expectations,
    evidence$machine_checks, evidence$schema_fingerprint, evidence$manifest, "# fixture\n"
  )
  review_path <- tempfile("phase18-wr03-review-", fileext = ".csv")
  utils::write.csv(evidence$owner_review, review_path, row.names = FALSE, na = "", quote = TRUE)
  saveRDS(list(projected = phase18_bundle_test_projected(evidence), fetched = phase18_bundle_test_fetched()), payload)
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "root <- args[[1L]]; payload <- readRDS(args[[2L]])",
    "source(file.path(root, 'scripts/accept_ucl_provider.R'), local = .GlobalEnv, chdir = TRUE)",
    "result <- phase18_accept_ucl_provider_main(args[-c(1L, 2L)], token_present = TRUE,",
    "  now_utc = '2026-09-19T12:30:00Z', candidate_input_fn = function(options, accepted) payload)",
    "cat(phase18_accept_render_result(result))",
    "quit(status = phase18_accept_cli_exit_code(result), save = 'no')"
  ), script)
  output <- system2("Rscript", c(
    "--vanilla", script, phase18_adversarial_root, payload,
    "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
    "--review-path", review_path, "--evidence-root", evidence_parent, "--mode", "provider_live",
    "--club-registry-root", registry_root, "--candidate-root", candidate_root,
    "--bundle-id", "ucl-2026-27-wr03-v1"
  ), stdout = TRUE, stderr = TRUE)
  expect_equal(attr(output, "status") %||% 0L, 0L, info = paste(output, collapse = "\n"))
  expect_true(any(grepl("type=bundle", output, fixed = TRUE)))
  expect_true(any(grepl("status=success", output, fixed = TRUE)))
  expect_silent(phase18_read_ucl_candidate(candidate_root))
})

test_that("WR-04 audit and accepted history linkage advances atomically", {
  phase18_adversarial_mark("WR-04")
  sandbox <- tempfile("phase18-wr04-")
  generations <- file.path(sandbox, "generations"); current <- file.path(sandbox, "history_current.json")
  audit <- phase18_audit_club_history(
    phase18_history_test_good_matches(5L), phase18_history_test_source(5L),
    phase18_history_test_registries(), "2025-06-01T00:00:00Z", corpus_id = "wr04-accepted",
    identity_review = phase18_history_test_review(), unresolved_identity = phase18_history_test_unresolved()
  )
  descriptor <- phase18_publish_club_history_generation(audit, generations, current)
  expect_identical(descriptor$audit_generation_id, descriptor$accepted_generation_id)
  expect_silent(phase18_read_club_history_current(current, generations))
  before <- phase18_adversarial_raw(current)
  replacement <- audit; replacement$corpus_manifest$corpus_id <- "wr04-replacement"
  replacement$corpus_manifest$manifest_sha256 <- phase18_history_row_sha256(replacement$corpus_manifest, "manifest_sha256")
  expect_error(phase18_publish_club_history_generation(
    replacement, generations, current,
    writer_hook = function(boundary, ...) if (identical(boundary, "before_pointer_replace")) stop("injected")
  ), "injected")
  expect_identical(phase18_adversarial_raw(current), before)
  expect_silent(phase18_read_club_history_current(current, generations))
})

test_that("Phase 18 adversarial executed inventory is exact and duplicate-free", {
  expected <- c(phase18_adversarial_required_critical, phase18_adversarial_required_warnings)
  expect_identical(sort(phase18_adversarial_executed$ids), sort(expected))
  expect_equal(anyDuplicated(phase18_adversarial_executed$ids), 0L)
})
