#!/usr/bin/env Rscript

# Fresh-process aggregate gate for Phase 20.  This verifier checks the
# executable inventories before it runs mechanics, then compares fixed-root
# production and temporary fixture/replay boundaries.  Expected missing Phase
# 18/19 authority is reported as a typed blocker; it is never silently treated
# as a passing production forecast.

phase20_gate_command_args <- commandArgs(trailingOnly = FALSE)
phase20_gate_file_arg <- phase20_gate_command_args[grepl("^--file=", phase20_gate_command_args)]
if (length(phase20_gate_file_arg) != 1L) {
  stop("Phase 20 verifier requires an Rscript --file invocation", call. = FALSE)
}
phase20_gate_script_path <- normalizePath(
  sub("^--file=", "", phase20_gate_file_arg[[1L]]),
  winslash = "/", mustWork = FALSE
)
phase20_gate_root <- normalizePath(file.path(dirname(phase20_gate_script_path), ".."), winslash = "/", mustWork = TRUE)
phase20_gate_rscript <- file.path(R.home("bin"), "Rscript")

phase20_gate_abort <- function(...) {
  cat(paste0(..., "\n"), file = stderr())
  quit(save = "no", status = 1L)
}

phase20_gate_run <- function(program, arguments) {
  output <- suppressWarnings(system2(program, arguments, stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), output = as.character(output),
       text = paste(as.character(output), collapse = "\n"))
}

phase20_gate_tail <- function(output, n = 24L) {
  if (!length(output)) return("<no subprocess output>")
  paste(tail(as.character(output), n), collapse = "\n")
}

phase20_gate_normalize <- function(value) gsub("[[:space:]]+", " ", trimws(as.character(value)))

phase20_gate_source_runtime <- function() {
  # The verifier is already a fresh R process, so sourcing into .GlobalEnv is
  # isolated from the caller and lets the test-owned fixture helpers exercise
  # the same public UCL symbols as testthat.
  for (relative in c(
    "R/common/phase18_canonical_hash.R",
    "R/competition/source_contracts.R",
    "R/competition/ucl_source_acceptance.R",
    "R/competition/ucl_source_bundle.R",
    "R/competition/ucl_source_refresh.R",
    "R/competition/match_state.R",
    "R/competition/standings.R",
    "R/competition/uefa_champions_league_rules.R",
    "R/competition/uefa_champions_league_state.R",
    "R/competition/uefa_champions_league_simulation.R",
    "R/competition/uefa_champions_league_outcomes.R",
    "R/club/identity.R",
    "R/club/identity_bootstrap.R",
    "R/club/history_contract.R",
    "R/club/model_contract.R",
    "R/club/evaluation_protocol.R",
    "R/club/rating.R",
    "R/club/goal_model.R",
    "R/club/calibration.R",
    "R/club/evaluation.R",
    "R/club/release.R"
  )) {
    path <- file.path(phase20_gate_root, relative)
    if (!file.exists(path)) phase20_gate_abort("missing UCL runtime dependency: ", relative)
    sys.source(path, envir = .GlobalEnv)
  }
  helper <- file.path(phase20_gate_root, "tests/testthat/helper_uefa_champions_league.R")
  if (!file.exists(helper)) phase20_gate_abort("missing Phase 20 helper inventory")
  sys.source(helper, envir = .GlobalEnv)
  invisible(TRUE)
}

phase20_gate_snapshot <- function(paths, root = phase20_gate_root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  result <- character()
  add <- function(key, value) result[[key]] <<- value
  hash_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  for (relative in paths) {
    absolute <- normalizePath(file.path(root, relative), winslash = "/", mustWork = FALSE)
    if (!file.exists(absolute) && !dir.exists(absolute)) {
      add(paste0(relative, "/<absent>"), "absent")
      next
    }
    if (dir.exists(absolute)) {
      files <- list.files(absolute, recursive = TRUE, full.names = TRUE,
                          all.files = TRUE, include.dirs = FALSE, no.. = TRUE)
      files <- files[!file.info(files)$isdir]
      if (!length(files)) {
        add(paste0(relative, "/<empty>"), "empty")
      } else for (file in files) {
        key <- substring(file, nchar(paste0(root, "/")) + 1L)
        add(key, if (nzchar(Sys.readlink(file))) paste0("symlink:", Sys.readlink(file)) else hash_file(file))
      }
    } else add(relative, hash_file(absolute))
  }
  result[order(names(result), method = "radix")]
}

phase20_gate_protected_paths <- c(
  "data/competition/accepted", "data/competition/registries",
  "outputs/releases/club", "outputs/releases/approved_release.csv",
  "outputs/competition/ucl_2026_27/outcomes"
)

phase20_gate_test_expression <- function(path, tag) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  paste0(
    "x<-testthat::test_file(", deparse(path), ",reporter='summary');",
    "d<-as.data.frame(x);",
    "failed<-if('failed'%in%names(d))sum(d$failed)else 0L;",
    "errors<-if('error'%in%names(d))sum(d$error)else 0L;",
    "warnings<-if('warning'%in%names(d))sum(d$warning)else 0L;",
    "skips<-if('skipped'%in%names(d))sum(d$skipped)else 0L;",
    "cat(sprintf('PHASE20_TEST_RESULT tag=", tag,
    " tests=%d failed=%d errors=%d warnings=%d skips=%d\\n',nrow(d),failed,errors,warnings,skips));",
    "if(failed+errors+warnings+skips>0L)quit(save='no',status=93L)"
  )
}

phase20_gate_run_test_file <- function(relative, tag = basename(relative)) {
  path <- file.path(phase20_gate_root, relative)
  expression <- phase20_gate_test_expression(path, tag)
  result <- phase20_gate_run(phase20_gate_rscript, c("--vanilla", "-e", shQuote(expression)))
  line <- result$output[grepl("^PHASE20_TEST_RESULT ", result$output)]
  if (result$status != 0L || length(line) != 1L ||
      !grepl("failed=0 errors=0 warnings=0 skips=0", line, fixed = TRUE)) {
    phase20_gate_abort("Phase 20 test file failed: ", relative, "\n", phase20_gate_tail(result$output))
  }
  cat(line, "\n", sep = "")
  invisible(line)
}

phase20_gate_validate_public_symbols <- function() {
  module_env <- new.env(parent = baseenv())
  for (relative in c(
    "R/competition/uefa_champions_league_rules.R",
    "R/competition/uefa_champions_league_state.R",
    "R/competition/uefa_champions_league_simulation.R",
    "R/competition/uefa_champions_league_outcomes.R"
  )) sys.source(file.path(phase20_gate_root, relative), envir = module_env)
  expected <- sort(phase20_expected_public_symbols, method = "radix")
  exported <- sort(ls(module_env)[grepl("^(ucl_|ucl20_|phase20_)", ls(module_env))], method = "radix")
  if (!identical(exported, expected)) {
    phase20_gate_abort("Phase 20 public symbol drift; expected ", paste(expected, collapse = ", "),
                       " but found ", paste(exported, collapse = ", "))
  }
  cat(sprintf("PHASE20_PUBLIC_SYMBOLS count=%d private_helpers=dot_ucl_only\n", length(exported)))
  invisible(TRUE)
}

phase20_gate_target_section <- function() {
  lines <- readLines(file.path(phase20_gate_root, "_targets.R"), warn = FALSE, encoding = "UTF-8")
  start <- grep("^  # Phase 20 UCL target namespace", lines)
  if (length(start) != 1L) phase20_gate_abort("Phase 20 target namespace marker is missing or duplicated")
  end <- grep("^  )$", lines[(start + 1L):length(lines)])
  if (!length(end)) phase20_gate_abort("Phase 20 target namespace terminator is missing")
  lines[(start + 1L):(start + end[[1L]])]
}

phase20_gate_validate_target_graph <- function() {
  section <- phase20_gate_target_section()
  starts <- grep("^  tar_target\\(", section, perl = TRUE)
  if (!length(starts)) phase20_gate_abort("Phase 20 target namespace contains no tar_target declarations")
  names <- vapply(starts, function(index) {
    remaining <- section[(index + 1L):min(length(section), index + 3L)]
    hit <- remaining[grepl("^[[:space:]]*[a-z][a-z0-9_]*,?[[:space:]]*$", remaining)]
    if (!length(hit)) "" else sub("[,[:space:]]+$", "", trimws(hit[[1L]]))
  }, character(1))
  if (!identical(names, phase20_expected_target_names)) {
    phase20_gate_abort("Phase 20 target names are not the exact ten-name registry: ", paste(names, collapse = ", "))
  }
  bodies <- setNames(vector("list", length(starts)), names)
  for (position in seq_along(starts)) {
    from <- starts[[position]]
    to <- if (position == length(starts)) length(section) else starts[[position + 1L]] - 1L
    bodies[[position]] <- paste(section[from:to], collapse = "\n")
  }
  observed <- character()
  for (edge in seq_len(nrow(phase20_expected_target_edges))) {
    parent <- phase20_expected_target_edges[edge, 1L]
    child <- phase20_expected_target_edges[edge, 2L]
    body <- bodies[[match(child, names)]]
    if (is.null(body) || !grepl(paste0("\\b", parent, "\\b"), body, perl = TRUE)) {
      phase20_gate_abort("Missing Phase 20 target edge: ", parent, " -> ", child)
    }
    observed <- c(observed, paste(parent, child, sep = " -> "))
  }
  for (position in seq_along(names)) {
    references <- names[vapply(names, function(parent) {
      parent != names[[position]] && grepl(paste0("\\b", parent, "\\b"), bodies[[position]], perl = TRUE)
    }, logical(1))]
    allowed <- phase20_expected_target_edges[phase20_expected_target_edges[, 2L] == names[[position]], 1L]
    if (!identical(sort(references), sort(allowed))) {
      phase20_gate_abort("Unexpected Phase 20 target edges for ", names[[position]], ": ", paste(references, collapse = ", "))
    }
  }
  if (grepl("phase14_resolve_approved_release|resolve_phase12_approved_release|phase14_resolve_approved_release", paste(section, collapse = "\n"), perl = TRUE)) {
    phase20_gate_abort("Phase 20 target namespace contains a national/legacy authority resolver")
  }
  cat(sprintf("PHASE20_TARGET_GRAPH targets=%d edges=%d exact=true isolated=true\n", length(names), length(observed)))
  invisible(TRUE)
}

phase20_gate_validate_inventories <- function() {
  edges <- phase20_expected_edge_probe_inventory()
  threats <- phase20_expected_threat_mapping()
  schemas <- phase20_expected_output_schemas
  required <- c("UCLRULE-01", "UCLRULE-02", "UCLRULE-03", "UCLOUT-01", "UCLOUT-02", "UCLOUT-03", "UCLOUT-04", "UCLOUT-05", "UCLOUT-06")
  plans <- paste(readLines(file.path(phase20_gate_root, ".planning/phases/20-ucl-rules-state-and-tournament-outcomes/20-05-PLAN.md"), warn = FALSE), collapse = "\n")
  if (!all(vapply(required, function(id) grepl(id, plans, fixed = TRUE), logical(1)))) {
    phase20_gate_abort("Phase 20 requirement inventory is incomplete")
  }
  if (nrow(edges) != 19L || anyDuplicated(edges$edge_id) ||
      !identical(edges$edge_id, sprintf("EDGE-%02d", seq_len(19L)))) phase20_gate_abort("EDGE-01..EDGE-19 inventory drift")
  if (nrow(threats) != 21L || anyDuplicated(threats$threat_id)) phase20_gate_abort("critical/high threat mapping drift")
  if (length(schemas) != 10L || anyDuplicated(names(schemas))) phase20_gate_abort("ten-file output registry drift")
  expected_files <- paste0(names(schemas), ".csv")
  if (!identical(sort(expected_files), sort(c(
    "competition_topology.csv", "league_schedule.csv", "tie_break_trace.csv",
    "projected_standings.csv", "projected_rankings.csv", "knockout_paths.csv",
    "progression_probabilities.csv", "fixture_forecast_ledger.csv",
    "simulation_metadata.csv", "outcomes_manifest.csv"
  )))) phase20_gate_abort("output path registry drift")
  for (symbol in c(edges$test_symbol, edges$verifier_symbol,
                   threats$test_symbol, threats$verifier_symbol)) {
    if (!exists(symbol, envir = .GlobalEnv, mode = "function", inherits = TRUE)) {
      phase20_gate_abort("inventory symbol is not executable: ", symbol)
    }
  }
  cat(sprintf("PHASE20_INVENTORIES edges=%d threats=%d outputs=%d requirements=%d\n",
              nrow(edges), nrow(threats), length(schemas), length(required)))
  invisible(TRUE)
}

phase20_gate_validate_evidence <- function() {
  path <- file.path(phase20_gate_root, "data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json")
  evidence <- jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
  expected <- c("article_17", "article_18", "article_19", "article_20", "article_21", "article_22", "annex_b", "draw_procedure_2026_27")
  if (!is.data.frame(evidence) || nrow(evidence) != 8L || !setequal(as.character(evidence$document_id), expected)) {
    phase20_gate_abort("UCL evidence identity/count is not exact")
  }
  regulations <- evidence$document_id != "draw_procedure_2026_27"
  if (any(!as.logical(evidence$accepted[regulations])) || any(!as.logical(evidence$complete[regulations])) ||
      any(as.character(evidence$canonical_domain) != "documents.uefa.com")) phase20_gate_abort("UCL regulation evidence is not accepted/canonical")
  draw <- evidence[evidence$document_id == "draw_procedure_2026_27", , drop = FALSE]
  if (nrow(draw) != 1L || isTRUE(draw$accepted[[1L]]) || isTRUE(draw$complete[[1L]]) ||
      !identical(as.character(draw$unresolved_reason[[1L]]), "missing_edition_draw_procedure") ||
      !grepl("Article-19-Draw-system-knockout-phase-Online", as.character(draw$canonical_article[[1L]]), fixed = TRUE)) {
    phase20_gate_abort("edition draw evidence must remain typed unresolved")
  }
  cat("PHASE20_EVIDENCE rows=8 regulations=7 draw_status=unresolved anchor=article_19\n")
  invisible(TRUE)
}

phase20_gate_validate_cr_probes <- function() {
  probes <- list(
    phase20_probe_cr01_forged_roster_rejected,
    phase20_probe_cr02_rating_replay_tamper_rejected,
    phase20_probe_cr03_forged_fold_rejected,
    phase20_probe_cr04_forged_probability_calibrator_rejected,
    phase20_probe_cr05_unbacked_installer_rejected
  )
  for (probe in probes) {
    value <- probe()
    if (!identical(as.character(value$status), "rejected") ||
        !identical(as.character(value$normalized_status), "production_human_needed") ||
        !identical(as.character(value$human_needed_reason), "phase19_cr01_cr05_repair_pending") ||
        !identical(as.character(value$original_parent_reason), as.character(value$reason))) {
      phase20_gate_abort("CR probe did not retain/reject its original reason")
    }
  }
  normalizer <- get(".ucl_state_normalize_parent_reason", envir = .GlobalEnv)
  cases <- phase20_expected_parent_reason_cases()
  for (index in seq_len(nrow(cases))) {
    actual <- normalizer(cases$original_parent_reason[[index]])
    if (!identical(as.character(actual$status), cases$normalized_status[[index]]) ||
        !identical(as.character(actual$human_needed_reason), as.character(cases$human_needed_reason[[index]])) ||
        !identical(as.logical(actual$normalization_error), cases$normalization_error[[index]])) {
      phase20_gate_abort("closed parent-reason normalization drift at row ", index)
    }
  }
  cat("PHASE20_CR_GATE probes=5 normalized=13 current_parent_gate=closed\n")
  invisible(TRUE)
}

phase20_gate_validate_result <- function(result, label) {
  if (!is.list(result) || !result$status %in% phase20_expected_result_statuses ||
      length(result$failures) || length(result$warnings) || length(result$skips) ||
      length(result$unexpected_failures) || isTRUE(result$production_eligible) ||
      isTRUE(result$selector_changed) || isTRUE(result$incumbent_changed)) {
    phase20_gate_abort(label, " returned an invalid or unsafe typed result")
  }
  if (identical(as.character(result$status), "unexpected_failure")) {
    if (identical(as.integer(result$exit_code), 0L) ||
        (!length(result$failures) && !length(result$unexpected_failures))) {
      phase20_gate_abort(label, " returned an empty or zero-exit unexpected failure")
    }
  } else if (!identical(as.integer(result$exit_code), 0L)) {
    phase20_gate_abort(label, " returned a nonzero exit code")
  }
  raw_hashes <- result$artifact_hashes %||% character()
  hashes <- as.character(raw_hashes)
  names(hashes) <- names(raw_hashes)
  if (result$status %in% c("mechanics_complete", "unresolved_draw_procedure")) {
    if (length(hashes) != 10L || is.null(names(hashes)) || anyNA(hashes) ||
        any(!grepl("^[0-9a-fA-F]{64}$", hashes))) {
      phase20_gate_abort(label, " did not preserve all ten artifact hashes")
    }
    if (is.list(result$artifacts) && length(result$artifacts)) {
      actual <- vapply(result$artifacts, .ucl_out_artifact_hash, character(1))
      if (!identical(names(hashes), names(actual)) || !identical(tolower(hashes), tolower(actual))) {
        phase20_gate_abort(label, " artifact hashes do not bind actual artifact bytes")
      }
    }
  }
  if (identical(result$status, "production_human_needed") &&
      !as.character(result$human_needed_reason) %in% c("phase18_authority_missing", "phase19_cr01_cr05_repair_pending", "phase19_selector_not_accepted")) {
    phase20_gate_abort(label, " returned an unrecognized human-needed reason")
  }
  if (identical(result$status, "production_blocked") &&
      !isTRUE(result$normalization_error) && !nzchar(as.character(result$production_blocked_reason))) {
    phase20_gate_abort(label, " returned an untyped production blocker")
  }
  invisible(TRUE)
}

phase20_gate_run_production <- function() {
  before <- phase20_gate_snapshot(phase20_gate_protected_paths)
  script <- file.path(phase20_gate_root, "scripts/build_uefa_champions_league_outcomes.R")
  result <- phase20_gate_run(phase20_gate_rscript, c("--vanilla", script, "--edition-id=ucl_2026_27", "--simulations=1", "--seed=20260921", "--information-cutoff-utc=2026-09-21T00:00:00Z", "--dry-run"))
  line <- result$output[grepl("^PHASE20_RESULT ", result$output)]
  if (result$status != 0L || length(line) != 1L ||
      !grepl("status=production_human_needed|status=production_blocked|status=unresolved_draw_procedure", line)) {
    phase20_gate_abort("fixed-root UCL production CLI failed\n", phase20_gate_tail(result$output))
  }
  after <- phase20_gate_snapshot(phase20_gate_protected_paths)
  if (!identical(before, after)) phase20_gate_abort("fixed-root production CLI mutated protected bytes")
  if (any(grepl("PHASE20_RESULT", result$output) & grepl("production_eligible=TRUE", result$output, fixed = TRUE))) {
    phase20_gate_abort("production CLI exposed an eligible result without accepted publication")
  }
  cat("PHASE20_PRODUCTION status=typed_human_needed_or_blocked protected_bytes_unchanged=true selector_changed=false incumbent_changed=false\n")
  invisible(TRUE)
}

phase20_gate_run_root_rejections <- function() {
  script <- file.path(phase20_gate_root, "scripts/build_uefa_champions_league_outcomes.R")
  arguments <- c(
    "--fixture-root=/tmp/fixture", "--output-root=/tmp/output", "--selector-path=/tmp/selector",
    "--trusted-release-root=/tmp/release", "--national-root=/tmp/national", "--source-root=/tmp/source"
  )
  for (argument in arguments) {
    result <- phase20_gate_run(phase20_gate_rscript, c("--vanilla", script, argument))
    if (result$status == 0L || !grepl("does not accept caller-selected", result$text, fixed = TRUE)) {
      phase20_gate_abort("caller-selected root was not rejected: ", argument)
    }
  }
  cat(sprintf("PHASE20_ROOT_REJECTIONS count=%d fixed=true\n", length(arguments)))
  invisible(TRUE)
}

phase20_gate_fixture_replay <- function() {
  graph <- phase20_fixture_graph_36x144()
  release <- phase20_approved_release_fixture(graph)
  # The fixture release is mechanics evidence only.  Attach the explicit
  # process-local score-grid fixture so the strict simulator can sample open
  # rows without manufacturing model evidence.
  release$forecast_rows$score_grid <- lapply(
    as.character(release$forecast_rows$fixture_id), phase20_fixture_score_grid
  )
  builder <- get("ucl20_build_outcomes", envir = .GlobalEnv)
  runs <- lapply(list(FALSE, TRUE, FALSE), function(reverse) {
    input <- graph
    if (isTRUE(reverse)) {
      input$clubs <- input$clubs[nrow(input$clubs):1L, , drop = FALSE]
      input$fixtures <- input$fixtures[nrow(input$fixtures):1L, , drop = FALSE]
    }
    builder(graph = input, release = release, simulations = 1L, seed = 20260921L,
            information_cutoff_utc = phase20_test_information_cutoff_utc, write = FALSE)
  })
  for (run in runs) {
    phase20_gate_validate_result(run, "fixture replay")
    if (!isTRUE(graph$fixture_authority) || !isTRUE(release$fixture_authority) ||
        isTRUE(run$production_eligible) ||
        !as.character(run$status) %in% c("mechanics_complete", "unresolved_draw_procedure")) {
      phase20_gate_abort("fixture replay crossed the production authority boundary")
    }
  }
  hashes <- lapply(runs, function(run) run$artifact_hashes)
  if (!identical(hashes[[1L]], hashes[[2L]]) || !identical(hashes[[1L]], hashes[[3L]])) {
    phase20_gate_abort("normal/reverse/repeat fixture replay is not byte-identical")
  }
  cat("PHASE20_FIXTURE_REPLAY runs=3 byte_identical=true fixture_authority=true production_eligible=false\n")
  invisible(TRUE)
}

phase20_gate_run_regressions <- function() {
  selected <- c(
    "tests/testthat/test_phase14_match_state.R",
    "tests/testthat/test_phase14_standings.R",
    "tests/testthat/test_phase14_forecast_layer.R",
    "tests/testthat/test_phase14_state_bundle.R",
    "tests/testthat/test_phase15_nations_league.R",
    "tests/testthat/test_phase16_euro_qualifying.R"
  )
  # Execute each selected suite in a fresh process.  A declaration/parse smoke
  # is not a regression result and must never be reported as green.
  regression_failures <- character()
  for (relative in selected) {
    path <- file.path(phase20_gate_root, relative)
    if (!file.exists(path)) phase20_gate_abort("missing regression file: ", relative)
    expression <- phase20_gate_test_expression(path, paste0("regression-", basename(path)))
    result <- phase20_gate_run(phase20_gate_rscript, c("--vanilla", "-e", shQuote(expression)))
    line <- result$output[grepl("^PHASE20_TEST_RESULT ", result$output)]
    passed <- result$status == 0L && length(line) == 1L &&
      grepl("failed=0 errors=0 warnings=0 skips=0", line, fixed = TRUE)
    if (isTRUE(passed)) {
      cat("PHASE20_REGRESSION_RESULT file=", relative, " status=passed\n", sep = "")
    } else {
      regression_failures <- c(regression_failures, relative)
      cat("PHASE20_REGRESSION_RESULT file=", relative, " status=failed\n", sep = "")
      cat(phase20_gate_tail(result$output), "\n", sep = "")
    }
  }
  phase18 <- phase20_gate_run(phase20_gate_rscript, c(
    "--vanilla", file.path(phase20_gate_root, "scripts/verify_phase18_contracts.R")
  ))
  if (phase18$status != 0L || !any(grepl("PHASE18_GATE_OK|PHASE18_GATE_BLOCKED", phase18$output))) {
    phase20_gate_abort("Phase 18 verifier failed\n", phase20_gate_tail(phase18$output))
  }
  cat("PHASE20_REGRESSION_PHASE18 status=executed\n")
  phase19_path <- file.path(phase20_gate_root, "scripts/verify_phase19_contracts.R")
  phase19_lines <- readLines(phase19_path, warn = FALSE, encoding = "UTF-8")
  if (!any(grepl("PHASE19_GATE_BLOCKED", phase19_lines, fixed = TRUE)) ||
      !any(grepl("phase12-wc2026-incumbent-retained-v1/model/approved_model.rds", phase19_lines, fixed = TRUE))) {
    phase20_gate_abort("Phase 19 known repair blocker is not explicitly isolated in its verifier")
  }
  cat("PHASE20_REGRESSION_SMOKE file=verify_phase19_contracts.R parse=true known_blocker_isolated=true\n")
  if (length(regression_failures)) {
    cat("PHASE20_REGRESSIONS phase14_15_16=executed_with_failures phase18=executed phase19=known_preexisting_repair_blocker bounded=true\n")
    phase20_gate_abort("bounded historical regressions failed: ", paste(regression_failures, collapse = ", "))
  }
  cat("PHASE20_REGRESSIONS phase14_15_16=executed phase18=executed phase19=known_preexisting_repair_blocker bounded=true\n")
  invisible(TRUE)
}

phase20_gate_source_runtime()
phase20_gate_validate_inventories()
phase20_gate_validate_public_symbols()
phase20_gate_validate_target_graph()
phase20_gate_validate_evidence()
phase20_gate_validate_cr_probes()
phase20_gate_run_test_file("tests/testthat/test_phase20_outcomes_wiring_review.R")
phase20_gate_run_test_file("tests/testthat/test_phase20_simulation_review.R")
phase20_gate_run_production()
phase20_gate_run_root_rejections()
phase20_gate_fixture_replay()
phase20_gate_run_regressions()
cat("PHASE20_PROTECTED_BYTES unchanged=true\n")
cat("PHASE20_GATE_OK mechanics=true production=typed_human_needed_or_blocked replay=true warnings=0 skips=0 failures=0 unexpected_failures=0\n")
