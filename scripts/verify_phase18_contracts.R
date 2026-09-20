#!/usr/bin/env Rscript

phase18_gate_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(phase18_gate_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
`%||%` <- function(x, y) if (is.null(x)) y else x
phase18_gate_abort <- function(...) stop(paste0(...), call. = FALSE)

phase18_gate_prohibitions <- function() {
  plans <- file.path(phase18_gate_root, ".planning/phases/18-club-and-ucl-source-contracts",
    sprintf("18-%02d-PLAN.md", seq_len(14L)))
  rows <- lapply(plans, function(path) {
    lines <- readLines(path, warn = FALSE)
    start <- match("  prohibitions:", lines)
    if (is.na(start)) return(NULL)
    finish <- which(seq_along(lines) > start & lines == "---")[[1L]]
    block <- lines[(start + 1L):(finish - 1L)]
    block <- block[grepl("[FLAGGED-UNVERIFIED]", block, fixed = TRUE)]
    text <- vapply(strsplit(block, "[FLAGGED-UNVERIFIED]", fixed = TRUE),
      function(parts) trimws(parts[[2L]]), character(1))
    if (!length(text)) return(NULL)
    plan <- sub("-PLAN.md$", "", basename(path))
    digest <- vapply(text, phase18_hash_scalar_v2, character(1),
      field_name = "prohibition", type_tag = "character")
    data.frame(plan = plan, ordinal = seq_along(text), text = text, digest = digest,
      identity = paste(plan, seq_along(text), digest, sep = ":"), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

phase18_gate_evidence_by_plan <- c(
  `18-01` = "test_phase18_source_acceptance.R", `18-02` = "test_phase18_club_identity.R",
  `18-03` = "test_phase18_football_data_adapter.R", `18-04` = "test_phase18_refresh_failure.R",
  `18-05` = "test_phase18_club_history_contract.R", `18-06` = "test_phase18_source_bundle.R",
  `18-08` = "test_phase18_source_acceptance.R", `18-09` = "test_phase18_football_data_adapter.R",
  `18-10` = "test_phase18_source_bundle.R", `18-11` = "test_phase18_refresh_failure.R",
  `18-12` = "test_phase18_club_history_contract.R", `18-13` = "test_phase18_adversarial_regression.R",
  `18-14` = "test_phase18_canonical_hash.R"
)

phase18_gate_edge_map <- data.frame(
  edge_id = c(
    "UCLSRC-01-CONCURRENCY", "UCLSRC-01-INTERRUPTION", "UCLSRC-02-UNCLASSIFIED",
    "UCLSRC-03-COLLISION", "UCLSRC-03-EMPTY-NULL", "UCLSRC-03-STABLE-ORDER",
    "UCLSRC-04-TECHNICAL-FAILURE", "UCLSRC-04-NO-INCUMBENT",
    "CLUBID-01-ADJACENCY", "CLUBID-01-EMPTY-NULL", "CLUBID-01-ACTIVE-STATUS",
    "CLUBID-01-STABLE-ORDER", "CLUBHIST-01-THRESHOLD", "CLUBHIST-01-PRECISION",
    "CLUBHIST-01-TIES"
  ),
  test_file = c(
    "test_phase18_source_acceptance.R", "test_phase18_source_acceptance.R",
    "test_phase18_football_data_adapter.R", "test_phase18_canonical_hash.R",
    "test_phase18_source_bundle.R", "test_phase18_football_data_adapter.R",
    "test_phase18_refresh_failure.R", "test_phase18_refresh_failure.R",
    rep("test_phase18_club_identity.R", 4L), rep("test_phase18_club_history_contract.R", 3L)
  ),
  test_name = c(
    "concurrency and writer interruption preserve incumbent bytes",
    "terminating a writer on either side of the pointer swap preserves a complete generation",
    "unknown acquisition failures are sanitized into one closed blocked reason",
    "length-prefixed row encoding rejects the reproduced delimiter collision",
    "empty null adjacent and equal-key resource outcomes are explicit",
    "provider row reordering preserves canonical projection order and hashes",
    "technical reason vocabulary is closed and sanitized",
    "technical first-refresh failure records explicit no-incumbent without accepted bytes",
    "half-open boundaries assign an instant only to the adjacent row",
    "empty and cross-domain inputs fail with typed reasons",
    "club status and validity are closed and active at the event instant",
    "registry hash and resolution are invariant to row order",
    "coverage equality and all zero-tolerance gates fail at one step",
    "completed evidence obeys conservative completion and cutoff boundaries",
    "date-only evidence uses next-day UTC and strict prior-information cutoff"
  ), stringsAsFactors = FALSE
)

phase18_gate_snapshot <- function(paths) {
  entries <- character()
  for (path in paths) {
    absolute <- file.path(phase18_gate_root, path)
    if (!file.exists(absolute) && !dir.exists(absolute)) {
      entries[paste0(path, "/<absent>")] <- "absent"
    } else if (dir.exists(absolute)) {
      files <- sort(list.files(absolute, recursive = TRUE, full.names = TRUE,
        all.files = TRUE, no.. = TRUE))
      files <- files[!file.info(files)$isdir]
      if (!length(files)) entries[paste0(path, "/<empty>")] <- "empty"
      for (file in files) {
        relative <- substring(file, nchar(phase18_gate_root) + 2L)
        entries[relative] <- digest::digest(file = file, algo = "sha256", serialize = FALSE)
      }
    } else {
      entries[path] <- digest::digest(file = absolute, algo = "sha256", serialize = FALSE)
    }
  }
  entries[order(names(entries))]
}

phase18_verify_contract_gate <- function() {
  prohibitions <- phase18_gate_prohibitions()
  original <- prohibitions$plan %in% sprintf("18-%02d", 1:6)
  if (nrow(prohibitions) != 50L || sum(original) != 20L || sum(!original) != 30L ||
      anyDuplicated(prohibitions$identity)) {
    phase18_gate_abort("prohibition inventory must be exactly 50 unique entries = 20 original + 30 gap")
  }
  identity <- sort(prohibitions$identity)
  inventory_sha256 <- phase18_hash_sequence_v2(as.list(identity), "phase18-prohibition-map-v1",
    identity, rep("character", length(identity)))
  if (!identical(inventory_sha256, "46b3e47ac93ace9c18b21bb9dadd9df3b418665acf200b95d1de543e848a47d9")) {
    phase18_gate_abort("prohibition plan+ordinal+text-digest inventory changed")
  }
  prohibition_map <- transform(prohibitions,
    evidence_type = "automated", evidence_ref = unname(phase18_gate_evidence_by_plan[plan]))
  if (nrow(prohibition_map) != 50L || anyNA(prohibition_map$evidence_ref) ||
      any(!nzchar(prohibition_map$evidence_ref)) || anyDuplicated(prohibition_map$identity)) {
    phase18_gate_abort("prohibition-to-evidence mapping is not a bijection")
  }

  adversarial_source <- paste(readLines(file.path(phase18_gate_root,
    "tests/testthat/test_phase18_adversarial_regression.R"), warn = FALSE), collapse = "\n")
  marked <- regmatches(adversarial_source, gregexpr(
    "phase18_adversarial_mark\\(\"(CR|WR)-[0-9]{2}\"\\)", adversarial_source, perl = TRUE))[[1L]]
  ids <- sub('.*\"((CR|WR)-[0-9]{2})\".*', "\\1", marked)
  required_ids <- c(sprintf("CR-%02d", 1:15), sprintf("WR-%02d", 1:4))
  if (length(ids) != 19L || anyDuplicated(ids) || !setequal(ids, required_ids)) {
    phase18_gate_abort("critical/warning inventory must execute CR-01..CR-15 and WR-01..WR-04 exactly once")
  }
  if (nrow(phase18_gate_edge_map) != 15L || anyDuplicated(phase18_gate_edge_map$edge_id)) {
    phase18_gate_abort("edge probe inventory is incomplete or duplicated")
  }

  production_paths <- c(
    "data/competition/provider_acceptance", "data/competition/registries",
    "data/competition/ucl_source_generations", "data/competition/accepted",
    "data/club/history_current.json", "data/club/history_generations",
    "data/club/history_audits", "data/club/registries", "data/club/identity_reviews"
  )
  before <- phase18_gate_snapshot(production_paths)

  source(file.path(phase18_gate_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/club/identity.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/club/identity_bootstrap.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/competition/ucl_source_bundle.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/competition/ucl_source_refresh.R"), local = .GlobalEnv)
  source(file.path(phase18_gate_root, "R/club/history_contract.R"), local = .GlobalEnv)
  authority <- phase18_validate_provider_live_authority(file.path(phase18_gate_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"))
  if (isTRUE(authority$authorized) || !identical(authority$reason_code, "missing_credential")) {
    phase18_gate_abort("committed provider evidence must remain fail-closed")
  }
  phase18_validate_club_registries(phase18_load_club_registries(
    file.path(phase18_gate_root, "data/club/registries")))
  refresh <- phase18_read_ucl_refresh_current(file.path(phase18_gate_root, "data/competition/accepted"),
    file.path(phase18_gate_root, "data/competition/registries"))
  if (!identical(refresh$pointer$accepted_status, "no_incumbent") ||
      nzchar(refresh$pointer$accepted_generation_id)) phase18_gate_abort("UCL refresh must have no incumbent")
  history <- phase18_read_club_history_current(file.path(phase18_gate_root, "data/club/history_current.json"),
    file.path(phase18_gate_root, "data/club/history_generations"))
  if (!identical(history$acceptance_state, "blocked") ||
      nzchar(history$accepted_generation_id)) phase18_gate_abort("history must remain training-ineligible")

  expected_files <- sort(c(
    "test_phase18_adversarial_regression.R", "test_phase18_canonical_hash.R",
    "test_phase18_club_history_contract.R", "test_phase18_club_identity.R",
    "test_phase18_football_data_adapter.R", "test_phase18_refresh_failure.R",
    "test_phase18_source_acceptance.R", "test_phase18_source_bundle.R"))
  test_dir <- file.path(phase18_gate_root, "tests/testthat")
  actual_files <- sort(list.files(test_dir, pattern = "^test_phase18_.*\\.R$"))
  if (!identical(actual_files, expected_files)) phase18_gate_abort("Phase 18 test inventory changed")
  total_tests <- 0L; total_assertions <- 0L
  for (file in expected_files) {
    expected_names <- phase18_gate_edge_map$test_name[phase18_gate_edge_map$test_file == file]
    expression <- paste0(
      "source(", paste(deparse(file.path(phase18_gate_root, "R/common/phase18_canonical_hash.R")), collapse = ""), ",local=.GlobalEnv);",
      "x<-testthat::test_file(", paste(deparse(file.path(test_dir, file)), collapse = ""), ",reporter='silent');d<-as.data.frame(x);",
      "expected<-", paste(deparse(expected_names), collapse = ""), ";",
      "bad<-sum(d$failed)+sum(d$error)+sum(d$warning)+sum(d$skipped);",
      "if(bad||length(setdiff(expected,d$test)))quit(status=1L,save='no');",
      "cat(sprintf('PHASE18_RESULT %d %d\\n',nrow(d),sum(d$passed)))")
    output <- suppressWarnings(system2("Rscript", c("--vanilla", "-e", shQuote(expression)),
      stdout = TRUE, stderr = TRUE))
    status <- attr(output, "status") %||% 0L
    if (as.integer(status) != 0L) {
      cat(paste(output, collapse = "\n"), "\n", file = stderr())
      phase18_gate_abort("fresh-process test failed: ", file)
    }
    line <- output[grepl("^PHASE18_RESULT ", output)]
    if (length(line) != 1L) phase18_gate_abort("missing result inventory for ", file)
    counts <- as.integer(strsplit(line, " ", fixed = TRUE)[[1L]][2:3])
    total_tests <- total_tests + counts[[1L]]; total_assertions <- total_assertions + counts[[2L]]
    cat(sprintf("PASS %-48s tests=%d assertions=%d\n", file, counts[[1L]], counts[[2L]]))
  }
  after <- phase18_gate_snapshot(production_paths)
  if (!identical(before, after)) phase18_gate_abort("verification mutated production evidence")
  cat(sprintf(paste0(
    "PHASE18_GATE_OK critical=15 warnings=4 edges=15 prohibitions=50 original=20 gap=30 ",
    "files=%d tests=%d assertions=%d production_fail_closed=true\n"),
    length(expected_files), total_tests, total_assertions))
  invisible(TRUE)
}

phase18_verify_contract_gate()
