#!/usr/bin/env Rscript

# Fixed-root Phase 20 UCL outcome entrypoint.
#
# The command deliberately keeps its authority boundary inside this file.  It
# accepts run controls (edition, seed, simulation count, and mode), but never a
# source, release, selector, fixture, or output path.  Missing Phase 18/19
# authority is a normal typed result; it is not converted into a guessed
# fixture or a partially written production bundle.

phase20_ucl_command_args <- commandArgs(trailingOnly = FALSE)
phase20_ucl_file_arg <- phase20_ucl_command_args[grepl("^--file=", phase20_ucl_command_args)]
phase20_ucl_script_path <- if (length(phase20_ucl_file_arg) == 1L) {
  sub("^--file=", "", phase20_ucl_file_arg[[1L]])
} else {
  "scripts/build_uefa_champions_league_outcomes.R"
}
phase20_ucl_script_path <- normalizePath(phase20_ucl_script_path, winslash = "/", mustWork = FALSE)
phase20_ucl_project_root <- normalizePath(
  file.path(dirname(phase20_ucl_script_path), ".."),
  winslash = "/", mustWork = FALSE
)
phase20_ucl_runtime <- new.env(parent = baseenv())

phase20_ucl_source <- function(relative_path) {
  path <- file.path(phase20_ucl_project_root, relative_path)
  if (!file.exists(path)) {
    stop(sprintf("Required UCL dependency is missing: %s", relative_path), call. = FALSE)
  }
  sys.source(path, envir = phase20_ucl_runtime)
  invisible(path)
}

# These files are read-only runtime dependencies.  Loading the Phase 18
# refresh reader and the final Phase 19 resolver into one private environment
# prevents the CLI from inheriting a caller-selected root through global state.
phase20_ucl_source("R/common/phase18_canonical_hash.R")
phase20_ucl_source("R/release/domain_contract.R")
phase20_ucl_source("R/competition/source_contracts.R")
phase20_ucl_source("R/competition/ucl_source_acceptance.R")
phase20_ucl_source("R/competition/ucl_source_bundle.R")
phase20_ucl_source("R/competition/ucl_source_refresh.R")
phase20_ucl_source("R/competition/match_state.R")
phase20_ucl_source("R/competition/standings.R")
phase20_ucl_source("R/competition/uefa_champions_league_rules.R")
phase20_ucl_source("R/competition/uefa_champions_league_state.R")
phase20_ucl_source("R/competition/uefa_champions_league_simulation.R")
phase20_ucl_source("R/competition/uefa_champions_league_outcomes.R")

# Phase 19 release.R is intentionally loaded only after the UCL source and
# state contracts.  It is the final resolver, not a national/legacy selector.
phase20_ucl_source("R/club/identity.R")
phase20_ucl_source("R/club/identity_bootstrap.R")
phase20_ucl_source("R/club/history_contract.R")
phase20_ucl_source("R/club/model_contract.R")
phase20_ucl_source("R/club/evaluation_protocol.R")
phase20_ucl_source("R/club/rating.R")
phase20_ucl_source("R/club/goal_model.R")
phase20_ucl_source("R/club/calibration.R")
phase20_ucl_source("R/club/evaluation.R")
phase20_ucl_source("R/club/release.R")

phase20_ucl_get <- function(name) {
  get(name, envir = phase20_ucl_runtime, inherits = TRUE)
}

phase20_ucl_stop <- function(message) {
  stop(as.character(message), call. = FALSE)
}

phase20_ucl_require_scalar <- function(value, option) {
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    phase20_ucl_stop(sprintf("Option %s requires one non-empty value.", option))
  }
  as.character(value)
}

phase20_ucl_parse_integer <- function(value, option, minimum, maximum = Inf) {
  value <- phase20_ucl_require_scalar(value, option)
  parsed <- suppressWarnings(as.integer(value))
  if (is.na(parsed) || parsed < minimum || parsed > maximum ||
      !identical(as.character(parsed), value)) {
    phase20_ucl_stop(sprintf(
      "%s must be an integer in [%s, %s].", option, minimum,
      if (is.infinite(maximum)) "Inf" else maximum
    ))
  }
  parsed
}

phase20_ucl_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- list(
    edition_id = "ucl_2026_27", simulations = 1000L, seed = 20260921L,
    information_cutoff_utc = "2026-09-21T00:00:00Z",
    dry_run = TRUE, replay_check = FALSE, write = FALSE, help = FALSE,
    mode = "dry-run"
  )
  forbidden_roots <- c(
    "fixture-root", "output-root", "selector-path", "trusted-root",
    "trusted-release-root", "production-root", "national-root", "source-root"
  )
  value_options <- c("edition-id", "simulations", "seed", "information-cutoff-utc")
  saw_dry_run <- FALSE
  saw_write <- FALSE
  index <- 1L
  while (index <= length(args)) {
    argument <- as.character(args[[index]])
    if (argument %in% c("--help", "-h")) {
      options$help <- TRUE
      index <- index + 1L
      next
    }
    if (argument %in% c("--dry-run", "--replay-check", "--write")) {
      if (identical(argument, "--dry-run")) {
        options$dry_run <- TRUE
        saw_dry_run <- TRUE
      }
      if (identical(argument, "--replay-check")) options$replay_check <- TRUE
      if (identical(argument, "--write")) {
        options$write <- TRUE
        options$dry_run <- FALSE
        saw_write <- TRUE
      }
      index <- index + 1L
      next
    }

    key <- sub("^--", "", sub("=.*$", "", argument))
    if (!startsWith(argument, "--") || !nzchar(key)) {
      phase20_ucl_stop(sprintf("Unsupported argument: %s", argument))
    }
    if (key %in% forbidden_roots) {
      phase20_ucl_stop(sprintf(
        "UCL CLI does not accept caller-selected authority/output roots: --%s",
        key
      ))
    }
    if (!key %in% value_options) {
      phase20_ucl_stop(sprintf("Unknown UCL argument: %s", argument))
    }

    if (grepl("=", argument, fixed = TRUE)) {
      value <- sub("^[^=]*=", "", argument)
    } else {
      if (index == length(args)) phase20_ucl_stop(sprintf("Option --%s requires one value.", key))
      index <- index + 1L
      value <- as.character(args[[index]])
    }
    value <- phase20_ucl_require_scalar(value, paste0("--", key))
    if (identical(key, "edition-id")) {
      options$edition_id <- value
    } else if (identical(key, "simulations")) {
      options$simulations <- phase20_ucl_parse_integer(value, "--simulations", 1L, 100000L)
    } else if (identical(key, "seed")) {
      options$seed <- phase20_ucl_parse_integer(value, "--seed", 0L, .Machine$integer.max)
    } else if (identical(key, "information-cutoff-utc")) {
      options$information_cutoff_utc <- value
    }
    index <- index + 1L
  }

  if (isTRUE(options$help)) return(options)
  if (!identical(options$edition_id, "ucl_2026_27")) {
    phase20_ucl_stop(sprintf(
      "Unsupported edition-id '%s'; only ucl_2026_27 is registered.",
      options$edition_id
    ))
  }
  if (isTRUE(saw_write) && isTRUE(saw_dry_run)) {
    phase20_ucl_stop("--write cannot be combined with --dry-run.")
  }
  if (isTRUE(options$write) && isTRUE(options$replay_check)) {
    phase20_ucl_stop("--write cannot be combined with --replay-check.")
  }
  cutoff_check <- phase20_ucl_get(".ucl_out_validate_cutoff")(options$information_cutoff_utc)
  if (!isTRUE(cutoff_check$valid)) phase20_ucl_stop(cutoff_check$reason)
  options$information_cutoff_utc <- cutoff_check$value
  options$mode <- if (isTRUE(options$write)) {
    "write"
  } else if (isTRUE(options$replay_check)) {
    "replay"
  } else {
    "dry-run"
  }
  options
}

phase20_ucl_usage <- function() {
  paste(
    "Usage:",
    "  Rscript --vanilla scripts/build_uefa_champions_league_outcomes.R [options]",
    "",
    "Options:",
    "  --edition-id ID   Supported edition (default: ucl_2026_27)",
    "  --simulations N   Positive simulation count (default: 1000)",
    "  --seed N          Non-negative deterministic seed (default: 20260921)",
    "  --information-cutoff-utc TS  Required UTC information cutoff (default: 2026-09-21T00:00:00Z)",
    "  --dry-run         Validate and build without writing (default)",
    "  --replay-check    Compare normal/reversed/repeated canonical identities",
    "  --write           Publish only an eligible, source-backed candidate",
    "  --help            Show this help",
    sep = "\n"
  )
}

phase20_ucl_fixed_roots <- function() {
  list(
    accepted_root = file.path(phase20_ucl_project_root, "data/competition/accepted"),
    registry_root = file.path(phase20_ucl_project_root, "data/competition/registries"),
    release_root = phase20_ucl_get("phase19_club_release_production_root")(),
    output_root = file.path(phase20_ucl_project_root, "outputs/competition/ucl_2026_27/outcomes")
  )
}

phase20_ucl_hash_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) phase20_ucl_stop("digest is required for protected-byte checks")
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

phase20_ucl_snapshot <- function(paths, root = phase20_ucl_project_root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  result <- character()
  add <- function(name, value) result[[name]] <<- value
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
      } else {
        for (file in files) {
          rel <- substring(file, nchar(paste0(root, "/")) + 1L)
          add(rel, if (nzchar(Sys.readlink(file))) paste0("symlink:", Sys.readlink(file)) else phase20_ucl_hash_file(file))
        }
      }
    } else {
      add(relative, phase20_ucl_hash_file(absolute))
    }
  }
  result[order(names(result), method = "radix")]
}

phase20_ucl_protected_paths <- function() {
  c(
    "data/competition/accepted", "data/competition/registries",
    "outputs/releases/club", "outputs/releases/approved_release.csv",
    "outputs/competition/ucl_2026_27/outcomes"
  )
}

phase20_ucl_normalize_parent_reason <- function(reason) {
  original <- if (length(reason) && !is.na(reason[[1L]])) as.character(reason[[1L]]) else ""
  if (identical(original, "no_accepted_current_ucl")) {
    return(list(status = "production_human_needed", human_needed_reason = "phase18_authority_missing",
                production_blocked_reason = NA_character_, normalization_error = FALSE,
                original_parent_reason = original))
  }
  if (original %in% c(
    "no_accepted_club_history", "protocol_policy_not_approved", "fold_inventory_not_approved",
    "phase19_cr01_roster_mismatch", "phase19_cr02_rating_replay_unverified",
    "phase19_cr03_fold_identity_unverified", "phase19_cr04_probability_lineage_unverified",
    "phase19_cr05_unbacked_installer"
  )) {
    return(list(status = "production_human_needed", human_needed_reason = "phase19_cr01_cr05_repair_pending",
                production_blocked_reason = NA_character_, normalization_error = FALSE,
                original_parent_reason = original))
  }
  if (identical(original, "phase19_selector_not_accepted")) {
    return(list(status = "production_human_needed", human_needed_reason = "phase19_selector_not_accepted",
                production_blocked_reason = NA_character_, normalization_error = FALSE,
                original_parent_reason = original))
  }
  list(status = "production_blocked", human_needed_reason = NA_character_,
       production_blocked_reason = "unrecognized_parent_reason", normalization_error = TRUE,
       original_parent_reason = original)
}

phase20_ucl_contract <- function(status, ...) {
  contract <- phase20_ucl_get("phase20_result_contract")
  do.call(contract, c(list(status = status, exit_code = 0L), list(...)))
}

phase20_ucl_authority_error <- function(error, default = "no_accepted_current_ucl") {
  if (is.list(error) && !is.null(error$reason_code)) return(as.character(error$reason_code[[1L]]))
  if (is.list(error) && !is.null(error$error)) return(as.character(error$error[[1L]]))
  if (inherits(error, "condition") && !is.null(error$reason_code)) return(as.character(error$reason_code[[1L]]))
  default
}

phase20_ucl_read_current <- function(roots) {
  reader <- phase20_ucl_get("phase18_read_ucl_refresh_current")
  tryCatch(
    reader(accepted_root = roots$accepted_root, registry_root = roots$registry_root),
    error = function(error) list(error = phase20_ucl_authority_error(error, "no_accepted_current_ucl"),
                                 message = conditionMessage(error))
  )
}

phase20_ucl_read_authority <- function(roots) {
  current <- phase20_ucl_read_current(roots)
  if (is.null(current)) return(list(error = "no_accepted_current_ucl"))
  if (!is.null(current$error)) return(current)
  status <- if (is.null(current$pointer$accepted_status)) "" else as.character(current$pointer$accepted_status)
  if (!identical(status, "accepted") || is.null(current$accepted) || is.null(current$accepted$bundle)) {
    return(list(error = "no_accepted_current_ucl", current = current))
  }
  list(value = current$accepted, current = current)
}

phase20_ucl_parent_release <- function() {
  resolver <- phase20_ucl_get("phase19_resolve_production_club_release")
  tryCatch(
    list(value = resolver()),
    error = function(error) {
      reason <- phase20_ucl_authority_error(error, "phase19_selector_not_accepted")
      if (reason %in% c("release_root_invalid", "release_artifact_missing", "release_dependency_missing", "release_preflight_stale")) {
        reason <- "no_accepted_club_history"
      }
      list(error = reason, message = conditionMessage(error))
    }
  )
}

phase20_ucl_result_from_parent <- function(reason, mapped_threat_ids = c("T20-05-01", "T20-05-02")) {
  normalized <- phase20_ucl_normalize_parent_reason(reason)
  phase20_ucl_contract(
    normalized$status,
    mechanics_complete = TRUE,
    human_needed = identical(normalized$status, "production_human_needed"),
    human_needed_reason = normalized$human_needed_reason,
    original_parent_reason = normalized$original_parent_reason,
    production_blocked_reason = normalized$production_blocked_reason,
    normalization_error = normalized$normalization_error,
    mapped_threat_ids = mapped_threat_ids,
    production_eligible = FALSE,
    selector_changed = FALSE,
    incumbent_changed = FALSE
  )
}

phase20_ucl_source_graph <- function(accepted, rules) {
  bundle <- accepted$bundle
  tables <- accepted$tables
  if (is.null(tables) && is.list(accepted$artifacts)) tables <- accepted$artifacts
  if (!is.list(tables)) return(NULL)
  clubs <- tables$clubs %||% tables$teams
  fixtures <- tables$matches %||% tables$fixtures
  if (!is.data.frame(clubs) || !is.data.frame(fixtures)) return(NULL)
  graph <- list(
    edition_id = as.character(bundle$edition_id[[1L]]),
    source_bundle_id = as.character(bundle$bundle_id[[1L]]),
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = TRUE, selector_path = NULL, production_root = NULL,
    clubs = clubs, fixtures = fixtures
  )
  validation <- phase20_ucl_get("ucl_validate_schedule")(graph, rules = rules, require_authority = TRUE)
  if (!identical(validation$status, "ready")) return(NULL)
  validation$graph
}

phase20_ucl_reverse_semantic_input <- function(graph = NULL, release = NULL) {
  reverse_rows <- function(value) {
    if (!is.data.frame(value) || !nrow(value)) return(value)
    value[rev(seq_len(nrow(value))), , drop = FALSE]
  }
  reversed_graph <- graph
  if (is.list(reversed_graph)) {
    for (field in c("clubs", "teams", "fixtures", "matches")) {
      if (is.data.frame(reversed_graph[[field]])) reversed_graph[[field]] <- reverse_rows(reversed_graph[[field]])
    }
  }
  reversed_release <- release
  if (is.list(reversed_release)) {
    for (field in c("forecast_rows", "forecasts", "ledger")) {
      if (is.data.frame(reversed_release[[field]])) reversed_release[[field]] <- reverse_rows(reversed_release[[field]])
    }
  }
  list(graph = reversed_graph, release = reversed_release)
}

phase20_ucl_candidate_replay <- function(graph = NULL, release = NULL, rules = NULL, options) {
  builder <- phase20_ucl_get("ucl20_build_outcomes")
  first <- builder(graph = graph, release = release, simulations = options$simulations,
                  seed = options$seed, information_cutoff_utc = options$information_cutoff_utc, write = FALSE)
  if (!isTRUE(options$replay_check)) return(list(candidate = first, replay_verified = NA))
  reversed <- phase20_ucl_reverse_semantic_input(graph, release)
  second <- builder(graph = reversed$graph, release = reversed$release, simulations = options$simulations,
                    seed = options$seed, information_cutoff_utc = options$information_cutoff_utc, write = FALSE)
  hashes_present <- length(first$artifact_hashes) == 10L && length(second$artifact_hashes) == 10L
  stable <- hashes_present && identical(first$artifact_hashes, second$artifact_hashes) &&
    isTRUE(phase20_ucl_get("phase20_verify_contracts")(first)) &&
    isTRUE(phase20_ucl_get("phase20_verify_contracts")(second))
  list(candidate = first, replay_verified = stable,
       replay_failure = if (stable) character() else "normal_reverse_artifact_identity_mismatch")
}

phase20_ucl_build_fixed <- function(options) {
  roots <- phase20_ucl_fixed_roots()
  # The public builder owns the complete production order: accepted Phase 18
  # source, fixed Phase 19 release, then graph/state/pipeline construction.
  replay <- tryCatch(
    phase20_ucl_candidate_replay(NULL, NULL, NULL, options),
    error = function(error) list(error = conditionMessage(error))
  )
  if (!is.null(replay$error)) {
    return(phase20_ucl_contract(
      "unexpected_failure", exit_code = 1L, mechanics_complete = FALSE,
      failures = replay$error, unexpected_failures = replay$error,
      mapped_threat_ids = c("T20-05-03")
    ))
  }
  candidate <- replay$candidate
  if (isTRUE(options$write) && !isTRUE(candidate$production_eligible)) {
    return(phase20_ucl_contract(
      "production_blocked", mechanics_complete = FALSE,
      production_blocked_reason = "production_writer_not_authorized",
      mapped_threat_ids = c("T20-05-01", "T20-05-02")
    ))
  }
  if (isTRUE(options$write) && isTRUE(candidate$production_eligible) &&
      identical(candidate$status, "mechanics_complete")) {
    # ucl_write_outcome_candidate deliberately permits only process-temporary
    # roots.  Production publication therefore remains a separate authority
    # decision and cannot be smuggled through --write.
    return(phase20_ucl_contract(
      "production_blocked", mechanics_complete = FALSE,
      failures = "production_writer_not_authorized",
      production_blocked_reason = "production_writer_not_authorized",
      mapped_threat_ids = c("T20-05-01", "T20-05-02")
    ))
  }
  result <- phase20_ucl_contract(
    candidate$status, mechanics_complete = candidate$mechanics_complete,
    production_eligible = FALSE, human_needed = candidate$human_needed,
    human_needed_reason = candidate$human_needed_reason,
    original_parent_reason = candidate$original_parent_reason,
    production_blocked_reason = candidate$production_blocked_reason,
    normalization_error = candidate$normalization_error,
    unresolved = candidate$unresolved, failures = candidate$failures,
    warnings = candidate$warnings, skips = candidate$skips,
    unexpected_failures = candidate$unexpected_failures,
    artifact_hashes = candidate$artifact_hashes, artifacts = candidate$artifacts,
    information_cutoff_utc = candidate$information_cutoff_utc,
    selector_changed = FALSE, incumbent_changed = FALSE,
    mapped_threat_ids = c("T20-01-01", "T20-02-01", "T20-03-01", "T20-03-03", "T20-04-01", "T20-05-03")
  )
  result$replay_verified <- replay$replay_verified
  if (!isTRUE(result$replay_verified) && isTRUE(options$replay_check) &&
      length(candidate$artifact_hashes %||% character())) {
    result$status <- "unexpected_failure"
    result$exit_code <- 1L
    result$failures <- unique(c(result$failures, replay$replay_failure))
    result$unexpected_failures <- unique(c(result$unexpected_failures, replay$replay_failure))
    result$mechanics_complete <- FALSE
  }
  result
}

phase20_ucl_print_result <- function(result) {
  scalar <- function(value) {
    if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return("")
    as.character(value[[1L]])
  }
  cat(sprintf(
    "PHASE20_RESULT status=%s exit_code=%s mechanics_complete=%s production_eligible=%s human_needed=%s\n",
    scalar(result$status), scalar(result$exit_code), scalar(result$mechanics_complete),
    scalar(result$production_eligible), scalar(result$human_needed)
  ))
  for (field in c(
    "human_needed_reason", "original_parent_reason", "production_blocked_reason",
    "normalization_error", "selector_changed", "incumbent_changed", "replay_verified",
    "draw_status", "fixed_output_root", "information_cutoff_utc"
  )) {
    if (!is.null(result[[field]])) cat(sprintf("%s=%s\n", field, scalar(result[[field]])))
  }
  invisible(result)
}

phase20_ucl_cli_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- tryCatch(phase20_ucl_parse_args(args), error = function(error) error)
  if (inherits(options, "error")) {
    cat(paste0("UCL_USAGE_ERROR: ", conditionMessage(options), "\n", phase20_ucl_usage(), "\n"), file = stderr())
    return(invisible(2L))
  }
  if (isTRUE(options$help)) {
    cat(phase20_ucl_usage(), "\n")
    return(invisible(0L))
  }
  protected_before <- phase20_ucl_snapshot(phase20_ucl_protected_paths())
  result <- tryCatch(
    phase20_ucl_build_fixed(options),
    error = function(error) phase20_ucl_contract(
      "unexpected_failure", exit_code = 1L, mechanics_complete = FALSE,
      failures = conditionMessage(error), unexpected_failures = conditionMessage(error),
      mapped_threat_ids = c("T20-05-01", "T20-05-04")
    )
  )
  protected_after <- phase20_ucl_snapshot(phase20_ucl_protected_paths())
  if (!identical(protected_before, protected_after)) {
    result$status <- "unexpected_failure"
    result$exit_code <- 1L
    result$mechanics_complete <- FALSE
    result$failures <- unique(c(result$failures, "protected_bytes_changed"))
    result$unexpected_failures <- unique(c(result$unexpected_failures, "protected_bytes_changed"))
  }
  phase20_ucl_print_result(result)
  invisible(if (identical(result$status, "unexpected_failure") || length(result$failures)) 1L else 0L)
}

phase20_ucl_is_direct <- function() {
  length(phase20_ucl_file_arg) == 1L &&
    identical(normalizePath(sub("^--file=", "", phase20_ucl_file_arg[[1L]]), winslash = "/", mustWork = FALSE),
              phase20_ucl_script_path)
}

if (phase20_ucl_is_direct()) {
  status <- phase20_ucl_cli_main()
  quit(save = "no", status = as.integer(status))
}
