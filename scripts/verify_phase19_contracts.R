#!/usr/bin/env Rscript

# Credential-free aggregate gate for Phase 19.  The verifier deliberately keeps
# fixture capability and production authority as separate outcomes: fixture
# replay may be green while the fixed production controller remains human_needed.

phase19_gate_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
phase19_gate_rscript <- file.path(R.home("bin"), "Rscript")
phase19_gate_abort <- function(...) {
  cat(paste0(..., "\n"), file = stderr())
  quit(save = "no", status = 1L)
}
phase19_gate_normalize <- function(value) {
  gsub("[[:space:]]+", " ", trimws(as.character(value)))
}
phase19_gate_tail <- function(output, n = 20L) {
  if (!length(output)) return("<no subprocess output>")
  paste(tail(as.character(output), n), collapse = "\n")
}
phase19_gate_run <- function(program, arguments) {
  output <- suppressWarnings(system2(program, arguments, stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = output,
       text = paste(output, collapse = "\n"))
}

phase19_gate_snapshot_paths <- function(paths, base = phase19_gate_root) {
  base <- normalizePath(base, winslash = "/", mustWork = FALSE)
  entries <- character()
  add_entry <- function(key, value) entries[[key]] <<- value
  for (relative in paths) {
    absolute <- if (identical(relative, ".")) base else file.path(base, relative)
    absolute <- normalizePath(absolute, winslash = "/", mustWork = FALSE)
    if (!file.exists(absolute) && !dir.exists(absolute)) {
      add_entry(paste0(relative, "/<absent>"), "absent")
      next
    }
    if (nzchar(Sys.readlink(absolute))) {
      add_entry(paste0(relative, "/<symlink>"), Sys.readlink(absolute))
      next
    }
    if (dir.exists(absolute)) {
      files <- list.files(absolute, recursive = TRUE, full.names = TRUE,
                          all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
      if (!length(files)) {
        add_entry(paste0(relative, "/<empty>"), "empty")
        next
      }
      for (file in files) {
        rel <- substring(file, nchar(paste0(base, "/")) + 1L)
        if (nzchar(Sys.readlink(file))) {
          add_entry(rel, paste0("symlink:", Sys.readlink(file)))
        } else if (!dir.exists(file)) {
          add_entry(rel, digest::digest(file = file, algo = "sha256", serialize = FALSE))
        }
      }
    } else {
      add_entry(relative, digest::digest(file = absolute, algo = "sha256", serialize = FALSE))
    }
  }
  entries[order(names(entries))]
}

phase19_gate_directory_snapshot <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (!dir.exists(root)) return(c("<absent>" = "absent"))
  files <- list.files(root, recursive = TRUE, full.names = TRUE,
                      all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
  if (!length(files)) return(c("<empty>" = "empty"))
  result <- character()
  for (file in files) {
    relative <- substring(file, nchar(paste0(root, "/")) + 1L)
    result[[relative]] <- if (nzchar(Sys.readlink(file))) {
      paste0("symlink:", Sys.readlink(file))
    } else {
      digest::digest(file = file, algo = "sha256", serialize = FALSE)
    }
  }
  result[order(names(result))]
}

phase19_gate_plan_prohibitions <- function() {
  plans <- file.path(
    phase19_gate_root, ".planning/phases/19-independent-club-forecast-authority",
    sprintf("19-%02d-PLAN.md", seq_len(10L))
  )
  rows <- lapply(seq_along(plans), function(index) {
    path <- plans[[index]]
    if (!file.exists(path)) phase19_gate_abort("missing Phase 19 plan: ", path)
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    flagged <- lines[grepl("[FLAGGED-UNVERIFIED]", lines, fixed = TRUE)]
    flagged <- flagged[grepl("^\\s*-\\s*\"", flagged)]
    text <- sub("^\\s*-\\s*\"(.*)\"\\s*$", "\\1", flagged)
    if (length(text) && any(text == flagged)) {
      phase19_gate_abort("malformed Phase 19 prohibition row in: ", path)
    }
    plan <- sprintf("19-%02d", index)
    data.frame(
      plan = plan,
      ordinal = seq_along(text),
      plan_task = sprintf("%s-%02d", plan, seq_along(text)),
      description = vapply(text, phase19_gate_normalize, character(1)),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

phase19_gate_probe_inventory <- function() {
  path <- file.path(phase19_gate_root,
                    "tests/testthat/test_phase19_adversarial_regression.R")
  if (!file.exists(path)) phase19_gate_abort("missing adversarial probe file")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  marked <- lines[startsWith(lines, "# PHASE19_PROBE|")]
  rows <- lapply(marked, function(line) {
    values <- strsplit(sub("^# PHASE19_PROBE\\|", "", line), "|", fixed = TRUE)[[1L]]
    if (length(values) != 5L) phase19_gate_abort("malformed Phase 19 probe inventory row")
    values
  })
  if (!length(rows)) phase19_gate_abort("Phase 19 probe inventory is empty")
  result <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(result) <- c("plan_task", "probe_id", "description", "boundary", "outcome")
  result$description <- vapply(result$description, phase19_gate_normalize, character(1))
  result
}

phase19_gate_validate_inventory <- function() {
  prohibitions <- phase19_gate_plan_prohibitions()
  probes <- phase19_gate_probe_inventory()
  if (nrow(prohibitions) != 30L || nrow(probes) != 30L) {
    phase19_gate_abort("Phase 19 requires exactly 30 prohibitions and 30 probes")
  }
  if (anyDuplicated(prohibitions$plan_task) || anyDuplicated(probes$plan_task) ||
      anyDuplicated(probes$probe_id) ||
      !identical(sort(prohibitions$plan_task), sort(probes$plan_task))) {
    phase19_gate_abort("Phase 19 prohibition/probe identity inventory is not bijective")
  }
  for (identity in prohibitions$plan_task) {
    left <- prohibitions[prohibitions$plan_task == identity, , drop = FALSE]
    right <- probes[probes$plan_task == identity, , drop = FALSE]
    if (!identical(left$description[[1L]], right$description[[1L]])) {
      phase19_gate_abort("Phase 19 prohibition text drift for ", identity)
    }
  }
  source_text <- paste(readLines(
    file.path(phase19_gate_root, "tests/testthat/test_phase19_adversarial_regression.R"),
    warn = FALSE, encoding = "UTF-8"
  ), collapse = "\n")
  matched <- regmatches(source_text, gregexpr(
    "phase19_adversarial_hit\\(\"P[0-9]{2}\"\\)", source_text, perl = TRUE
  ))[[1L]]
  if (identical(matched, character(0))) matched <- character()
  hits <- sub(".*\"(P[0-9]{2})\".*", "\\1", matched)
  if (length(hits) != 30L || anyDuplicated(hits) ||
      !identical(sort(hits), sort(probes$probe_id))) {
    phase19_gate_abort("Phase 19 executable probe evidence is not exactly one hit per probe")
  }
  cat("PHASE19_PROHIBITIONS count=30\n")
  cat("PHASE19_PROBES count=30 evidence=30\n")
  list(prohibitions = prohibitions, probes = probes)
}

phase19_gate_test_inventory <- function() {
  test_dir <- file.path(phase19_gate_root, "tests/testthat")
  expected <- sort(c(
    "test_phase19_adversarial_regression.R", "test_phase19_club_calibration.R",
    "test_phase19_club_domain_contract.R", "test_phase19_club_evaluation.R",
    "test_phase19_club_folds.R", "test_phase19_club_goal_model.R",
    "test_phase19_club_pipeline.R", "test_phase19_club_protocol.R",
    "test_phase19_club_rating.R", "test_phase19_club_release.R"
  ))
  actual <- sort(list.files(test_dir, pattern = "^test_phase19_.*\\.R$"))
  if (!identical(actual, expected)) {
    phase19_gate_abort(
      "Phase 19 test inventory drift; expected ", paste(expected, collapse = ", "),
      " but found ", paste(actual, collapse = ", ")
    )
  }
  list(directory = test_dir, files = expected)
}

phase19_gate_run_phase19_tests <- function(inventory) {
  runner <- file.path(phase19_gate_root, "scripts/run_phase19_focused_test.R")
  total_tests <- 0L
  total_assertions <- 0L
  for (file in inventory$files) {
    path <- file.path(inventory$directory, file)
    result <- phase19_gate_run(phase19_gate_rscript, c("--vanilla", runner, path))
    lines <- result$output[grepl("^PASS .*PHASE19_FOCUSED_RESULT tests=[0-9]+ assertions=[0-9]+$",
                                 result$output)]
    if (result$status != 0L || length(lines) != 1L) {
      phase19_gate_abort("Phase 19 fresh-process test failed: ", file, "\n",
                         phase19_gate_tail(result$output))
    }
    values <- as.integer(strsplit(
      sub("^.*tests=([0-9]+) assertions=([0-9]+)$", "\\1 \\2", lines),
      " ", fixed = TRUE
    )[[1L]])
    total_tests <- total_tests + values[[1L]]
    total_assertions <- total_assertions + values[[2L]]
    cat(sprintf("PASS %-48s tests=%d assertions=%d\n", file, values[[1L]], values[[2L]]))
  }
  cat(sprintf("PHASE19_TESTS files=%d tests=%d assertions=%d warnings=0 skips=0 failures=0\n",
              length(inventory$files), total_tests, total_assertions))
  c(tests = total_tests, assertions = total_assertions)
}

phase19_gate_run_phase18 <- function() {
  script <- file.path(phase19_gate_root, "scripts/verify_phase18_contracts.R")
  result <- phase19_gate_run(phase19_gate_rscript, c("--vanilla", script))
  lines <- result$output[grepl("^PHASE18_GATE_OK ", result$output)]
  if (result$status != 0L || length(lines) != 1L) {
    phase19_gate_abort("Phase 18 contract gate failed\n", phase19_gate_tail(result$output))
  }
  cat(lines, "\n", sep = "")
  invisible(TRUE)
}

phase19_gate_test_file_expression <- function(path, tag) {
  quoted <- paste(deparse(path), collapse = "")
  paste0(
    "x<-testthat::test_file(", quoted, ",reporter='progress');",
    "d<-as.data.frame(x);bad<-sum(d$failed)+sum(d$error)+sum(d$warning)+sum(d$skipped);",
    "cat(sprintf('PHASE19_REGRESSION_RESULT tag=", tag,
    " tests=%d assertions=%d bad=%d\\n',nrow(d),sum(d$passed),bad));",
    "if(bad>0L)quit(save='no',status=93L)"
  )
}

phase19_gate_run_national <- function() {
  relative <- c(
    "tests/testthat/test_phase12_release.R",
    "tests/testthat/test_phase14_calibration_release.R",
    "tests/testthat/test_phase14_forecast_layer.R",
    "tests/testthat/test_phase14_state_bundle.R",
    "tests/testthat/test_phase15_nations_league.R"
  )
  blockers <- character()
  for (path in relative) {
    absolute <- file.path(phase19_gate_root, path)
    if (!file.exists(absolute)) phase19_gate_abort("missing national regression: ", path)
    expression <- phase19_gate_test_file_expression(absolute, basename(path))
    result <- phase19_gate_run(phase19_gate_rscript,
                               c("--vanilla", "-e", shQuote(expression)))
    line <- result$output[grepl("^PHASE19_REGRESSION_RESULT ", result$output)]
    if (result$status != 0L || length(line) != 1L) {
      if (grepl("phase12-wc2026-incumbent-retained-v1/model/approved_model.rds",
                result$text, fixed = TRUE)) {
        blockers <- c(blockers, paste0(path, ": missing pre-existing Phase 12 approved_model.rds"))
        cat("BLOCKED ", path,
            " reason=preexisting_missing_phase12_approved_model.rds\n", sep = "")
        next
      }
      phase19_gate_abort("national regression failed: ", path, "\n",
                         phase19_gate_tail(result$output))
    }
    cat("PASS ", line, "\n", sep = "")
  }
  blockers
}

phase19_gate_fixture_replay <- function() {
  # Build the fixture only from test-owned helpers and keep every resulting root
  # below tempdir().  The CLI wrapper deliberately rematerializes a caller's
  # fixture below a fresh process sandbox.  That makes raw release bytes differ
  # between processes because the fixture-root hash is path-bound.  Materialize
  # once here, then invoke the same fixture-only controller twice with isolated
  # output/release roots so replay compares the actual canonical bytes emitted
  # by one authoritative fixture root.
  source(file.path(phase19_gate_root, "tests/testthat/helper_phase19_club_fixture.R"), local = .GlobalEnv)
  phase19_test_load()
  fixture_root <- phase19_test_fixture_root("aggregate-replay")
  output_one <- tempfile("phase19-aggregate-output-one-", tmpdir = tempdir())
  release_one <- tempfile("phase19-aggregate-release-one-", tmpdir = tempdir())
  output_two <- tempfile("phase19-aggregate-output-two-", tmpdir = tempdir())
  release_two <- tempfile("phase19-aggregate-release-two-", tmpdir = tempdir())
  for (root in c(output_one, release_one, output_two, release_two)) {
    if (!dir.create(root, recursive = TRUE, showWarnings = FALSE) && !dir.exists(root)) {
      phase19_gate_abort("isolated fixture replay root creation failed")
    }
  }
  script <- file.path(phase19_gate_root, "scripts/run_phase19_club_evaluation.R")
  cli_lines <- readLines(script, warn = FALSE)
  main_line <- which(trimws(cli_lines) == "phase19_cli_main()")
  if (length(main_line) != 1L) phase19_gate_abort("fixture CLI main boundary is not exact")
  source(textConnection(cli_lines[seq_len(main_line - 1L)]), local = .GlobalEnv)
  materialized <- phase19_cli_prepare_fixture_run(list(
    fixture_root = fixture_root, output_root = output_one, release_root = release_one
  ))
  shared_fixture <- materialized$internal$fixture_root
  on.exit(unlink(c(fixture_root, dirname(shared_fixture), output_one, release_one,
                   output_two, release_two),
                recursive = TRUE, force = TRUE), add = TRUE)
  first <- tryCatch(
    phase19_cli_fixture(list(fixture_root = shared_fixture,
                             output_root = output_one, release_root = release_one)),
    error = function(error) structure(list(error = conditionMessage(error)), class = "phase19_gate_fixture_error")
  )
  second <- tryCatch(
    phase19_cli_fixture(list(fixture_root = shared_fixture,
                             output_root = output_two, release_root = release_two)),
    error = function(error) structure(list(error = conditionMessage(error)), class = "phase19_gate_fixture_error")
  )
  if (inherits(first, "phase19_gate_fixture_error") ||
      inherits(second, "phase19_gate_fixture_error")) {
    errors <- c(if (inherits(first, "phase19_gate_fixture_error")) first$error else character(),
                if (inherits(second, "phase19_gate_fixture_error")) second$error else character())
    phase19_gate_abort("isolated fixture replay failed\n", paste(errors, collapse = "\n"))
  }
  for (record in list(first, second)) {
    if (!identical(as.character(record$status), "human_needed") ||
        !identical(as.character(record$reason_code), "fixture_ineligible") ||
        !identical(as.character(record$promotion_status), "retained")) {
      phase19_gate_abort("fixture replay did not remain human_needed/retained")
    }
  }
  first_snapshot <- c(
    output = phase19_gate_directory_snapshot(output_one),
    release = phase19_gate_directory_snapshot(release_one)
  )
  second_snapshot <- c(
    output = phase19_gate_directory_snapshot(output_two),
    release = phase19_gate_directory_snapshot(release_two)
  )
  # The installed selector intentionally records the current approval time, so
  # it is the one non-canonical byte surface.  Compare every other artifact
  # byte-for-byte, then validate both selector rows and compare their stable
  # identity projection below.
  selector_key <- "release.approved_release.csv"
  canonical_snapshot <- function(snapshot) snapshot[setdiff(names(snapshot), selector_key)]
  if (!identical(canonical_snapshot(first_snapshot), canonical_snapshot(second_snapshot))) {
    keys <- union(names(canonical_snapshot(first_snapshot)), names(canonical_snapshot(second_snapshot)))
    differing <- keys[vapply(keys, function(key) {
      identical(canonical_snapshot(first_snapshot)[[key]], canonical_snapshot(second_snapshot)[[key]])
    }, logical(1)) == FALSE]
    phase19_gate_abort(
      "isolated fixture replay artifacts are not byte-identical; differing entries: ",
      paste(differing, collapse = ", ")
    )
  }
  selector_records <- lapply(c(release_one, release_two), function(root) {
    selector_path <- file.path(root, "approved_release.csv")
    if (!file.exists(selector_path)) phase19_gate_abort("fixture replay selector is missing")
    selector <- utils::read.csv(selector_path, stringsAsFactors = FALSE,
                                check.names = FALSE, colClasses = "character", na.strings = character())
    if (!identical(names(selector), phase19_club_release_selector_columns()) || nrow(selector) != 1L ||
        !nzchar(as.character(selector$approved_at_utc[[1L]])) ||
        !identical(tolower(as.character(selector$row_sha256[[1L]])),
                   phase19_club_release_selector_hash(selector))) {
      phase19_gate_abort("fixture replay selector is not a valid self-hashed row")
    }
    selector
  })
  stable_selector_fields <- setdiff(phase19_club_release_selector_columns(), c("approved_at_utc", "row_sha256"))
  if (!identical(selector_records[[1L]][stable_selector_fields],
                 selector_records[[2L]][stable_selector_fields])) {
    phase19_gate_abort("fixture replay selector identity changed")
  }
  records <- lapply(c(output_one, output_two), function(root) {
    path <- file.path(root, "phase19-fixture-result.json")
    jsonlite::fromJSON(path, simplifyVector = TRUE)
  })
  for (record in records) {
    if (!identical(as.character(record$status), "human_needed") ||
        !identical(as.character(record$reason_code), "fixture_ineligible") ||
        !identical(as.character(record$promotion_status), "retained")) {
      phase19_gate_abort("fixture decision fields are not the retained non-production contract")
    }
  }
  cat("PHASE19_FIXTURE_REPLAY runs=2 byte_identical=true status=human_needed promotion_status=retained\n")
  invisible(TRUE)
}

phase19_gate_production_cli <- function() {
  blocked_path <- file.path(phase19_gate_root,
                            "outputs/club_model/blocked/phase19-production-blocked.json")
  existed <- file.exists(blocked_path)
  script <- file.path(phase19_gate_root, "scripts/run_phase19_club_evaluation.R")
  result <- phase19_gate_run(phase19_gate_rscript, c("--vanilla", script))
  lines <- result$output[grepl("^PHASE19_RESULT ", result$output)]
  if (result$status != 0L || length(lines) != 1L ||
      !grepl("status=human_needed", lines, fixed = TRUE) ||
      !grepl("reason_code=no_accepted_club_history", lines, fixed = TRUE) ||
      !grepl("promotion_status=blocked", lines, fixed = TRUE)) {
    phase19_gate_abort("fixed-root production CLI did not stop at no_accepted_club_history\n",
                       phase19_gate_tail(result$output))
  }
  if (file.exists(file.path(phase19_gate_root, "outputs/releases/club/approved_release.csv"))) {
    phase19_gate_abort("production CLI created or exposed a club selector")
  }
  if (!file.exists(blocked_path)) phase19_gate_abort("production CLI did not emit blocked evidence")
  record <- jsonlite::fromJSON(blocked_path, simplifyVector = TRUE)
  if (!identical(as.character(record$status), "human_needed") ||
      !identical(as.character(record$reason_code), "no_accepted_club_history") ||
      !identical(as.logical(record$model_work_started), FALSE) ||
      !identical(as.logical(record$release_mutated), FALSE) ||
      !identical(as.logical(record$selector_mutated), FALSE)) {
    phase19_gate_abort("production blocked record is not fail-closed/human_needed")
  }
  if (!existed && file.exists(blocked_path)) {
    unlink(blocked_path, force = TRUE)
    blocked_dir <- dirname(blocked_path)
    model_dir <- dirname(blocked_dir)
    if (dir.exists(blocked_dir) && !length(list.files(blocked_dir, all.files = TRUE, no.. = TRUE))) {
      unlink(blocked_dir, recursive = FALSE)
    }
    if (dir.exists(model_dir) && !length(list.files(model_dir, all.files = TRUE, no.. = TRUE))) {
      unlink(model_dir, recursive = FALSE)
    }
  }
  cat("PHASE19_PRODUCTION status=human_needed reason_code=no_accepted_club_history selector=absent model_work_started=false\n")
  invisible(TRUE)
}

phase19_gate_later_reasons <- function() {
  required <- c(
    "no_accepted_current_ucl", "current_ucl_identity_incomplete",
    "protocol_policy_not_approved", "fold_inventory_not_approved",
    "domain_mismatch", "protocol_domain_mismatch", "evaluation_cutoff_invalid",
    "evaluation_coverage_invalid", "byte_reproducibility_failed",
    "release_inventory_mismatch", "selector_changed_during_resolution"
  )
  before <- phase19_gate_snapshot_paths(phase19_gate_protected_paths)
  probe <- function(reason_code, thunk) {
    observed <- tryCatch(thunk(), error = function(error) error)
    actual <- if (inherits(observed, "error")) {
      if (is.null(observed$reason_code)) "" else as.character(observed$reason_code)
    } else if (is.list(observed) && !is.null(observed$reason_code)) {
      as.character(observed$reason_code)
    } else {
      as.character(observed)
    }
    if (!identical(actual, reason_code)) {
      phase19_gate_abort(
        "runtime reason-code probe failed; expected ", reason_code,
        " but observed ", paste(actual, collapse = "|")
      )
    }
    invisible(TRUE)
  }

  probe("no_accepted_current_ucl", function() {
    phase19_club_production_block_reason("ready", "blocked", "ready", "ready")
  })
  probe("current_ucl_identity_incomplete", function() {
    root <- phase19_test_fixture_root("runtime-current-incomplete", current_identity_complete = FALSE)
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    phase19_load_fixture_current_ucl_club_snapshot(root)$reason_code
  })
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  probe("protocol_policy_not_approved", function() {
    phase19_evaluate_policy_review(protocol, list(), authority_mode = "production")$reason_code
  })
  probe("fold_inventory_not_approved", function() {
    phase19_club_production_block_reason("ready", "ready", "ready", "blocked")
  })
  probe("domain_mismatch", function() {
    phase19_club_release_decision_check(list(forecast_domain = "national_team"), "fixture")
  })
  probe("protocol_domain_mismatch", function() {
    phase19_evaluate_policy_review(protocol, protocol$policy_review, authority_mode = "national_team")
  })

  fixture_root <- phase19_test_fixture_root("runtime-cutoffs")
  training <- phase19_load_fixture_club_training_snapshot(fixture_root)
  current <- phase19_load_fixture_current_ucl_club_snapshot(fixture_root)
  current <- phase19_cli_fixture_matching_current(current, training)
  folds <- phase19_build_fixture_club_fold_registry(training, protocol)
  fold <- folds[1L, , drop = FALSE]
  outcomes <- phase19_cli_outcomes(training, fold)
  predictions <- outcomes[, c("fixture_id", "home_club_id", "away_club_id"), drop = FALSE]
  probe("evaluation_cutoff_invalid", function() {
    invalid <- outcomes
    invalid$kickoff_utc[[1L]] <- "1900-01-01T00:00:00Z"
    phase19_club_evaluation_outcomes(invalid, fold, predictions)
  })
  probe("evaluation_coverage_invalid", function() {
    phase19_club_evaluation_outcomes(outcomes[-1L, , drop = FALSE], fold, predictions)
  })
  metrics <- as.list(setNames(
    rep(1, length(phase19_club_evaluation_metric_names())),
    phase19_club_evaluation_metric_names()
  ))
  metrics$byte_reproducibility <- 0
  probe("byte_reproducibility_failed", function() {
    gates <- phase19_apply_club_promotion_gates(metrics, protocol, "fixture")
    as.character(gates$failure_reason_code[gates$gate_id == "byte_reproducibility"])
  })
  probe("release_inventory_mismatch", function() {
    root <- tempfile("phase19-runtime-empty-release-", tmpdir = tempdir())
    dir.create(root, recursive = TRUE)
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    phase19_validate_club_release(root, load_models = FALSE, expected_domain = "club")
  })

  output_root <- tempfile("phase19-runtime-selector-output-", tmpdir = tempdir())
  release_root <- tempfile("phase19-runtime-selector-release-", tmpdir = tempdir())
  dir.create(output_root, recursive = TRUE)
  dir.create(release_root, recursive = TRUE)
  fixture <- phase19_cli_fixture(list(
    fixture_root = fixture_root, output_root = output_root, release_root = release_root
  ))
  original_reader <- phase19_read_club_selector
  reads <- 0L
  assign("phase19_read_club_selector", function(...) {
    reads <<- reads + 1L
    selected <- original_reader(...)
    if (reads == 2L) {
      selected$selector_self_sha256 <- paste0(
        substr(selected$selector_self_sha256, 1L, 63L),
        ifelse(substr(selected$selector_self_sha256, 64L, 64L) == "0", "1", "0")
      )
    }
    selected
  }, envir = .GlobalEnv)
  on.exit(assign("phase19_read_club_selector", original_reader, envir = .GlobalEnv), add = TRUE)
  probe("selector_changed_during_resolution", function() {
    phase19_resolve_fixture_club_release(release_root)
  })
  unlink(c(fixture_root, output_root, release_root), recursive = TRUE, force = TRUE)
  after <- phase19_gate_snapshot_paths(phase19_gate_protected_paths)
  if (!identical(before, after)) phase19_gate_abort("runtime later-reason probes mutated protected production bytes")
  cat("PHASE19_LATER_REASON_CODES count=11 isolated_nonproduction=true runtime_probes=11\n")
  invisible(TRUE)
}

phase19_gate_protected_paths <- c(
  "data/club/history_current.json", "data/club/history_generations",
  "data/club/fold_protocol_runtime", "data/club/registries",
  "data/competition/accepted", "data/competition/registries",
  "data/competition/ucl_source_generations", "outputs/releases/club",
  "outputs/releases/approved_release.csv",
  "outputs/releases/phase12-wc2026-incumbent-retained-v1",
  "outputs/releases/phase14-open-nb-incumbent-calibrated-v1",
  "outputs/club_model"
)

inventory <- phase19_gate_validate_inventory()
tests <- phase19_gate_test_inventory()
before <- phase19_gate_snapshot_paths(phase19_gate_protected_paths)
phase19_gate_run_phase19_tests(tests)
phase19_gate_run_phase18()
national_blockers <- phase19_gate_run_national()
phase19_gate_fixture_replay()
phase19_gate_later_reasons()
phase19_gate_production_cli()
after <- phase19_gate_snapshot_paths(phase19_gate_protected_paths)
if (!identical(before, after)) phase19_gate_abort("verification mutated protected production bytes")
cat("PHASE19_PROTECTED_BYTES unchanged=true\n")

if (length(national_blockers)) {
  cat("PHASE19_GATE_BLOCKED reason=preexisting_national_regression_artifact_missing\n")
  cat(paste0("PHASE19_BLOCKER ", national_blockers, "\n"), sep = "")
  quit(save = "no", status = 2L)
}

cat("PHASE19_GATE_OK mechanics=true production=human_needed protected_bytes_unchanged=true\n")
