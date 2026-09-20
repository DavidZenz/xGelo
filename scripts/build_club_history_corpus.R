#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

args <- commandArgs(trailingOnly = TRUE)
options <- list()
for (argument in args) {
  if (!grepl("^--[a-z0-9-]+=[^[:cntrl:]]*$", argument)) {
    stop("Arguments must use --name=value form", call. = FALSE)
  }
  key <- sub("^--([^=]+)=.*$", "\\1", argument)
  if (!is.null(options[[key]])) stop("Duplicate option: --", key, call. = FALSE)
  options[[key]] <- sub("^--[^=]+=", "", argument)
}

project_root <- normalizePath(options$`project-root` %||% getwd(), winslash = "/", mustWork = TRUE)
source(file.path(project_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
source(file.path(project_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
source(file.path(project_root, "R/club/identity.R"), local = .GlobalEnv)
source(file.path(project_root, "R/club/identity_bootstrap.R"), local = .GlobalEnv)
source(file.path(project_root, "R/club/history_contract.R"), local = .GlobalEnv)

resolve_trusted <- function(value, default, must_exist = FALSE) {
  candidate <- value %||% default
  if (!grepl("^/", candidate)) candidate <- file.path(project_root, candidate)
  probe <- candidate
  while (!file.exists(probe) && !identical(probe, dirname(probe))) probe <- dirname(probe)
  resolved_probe <- normalizePath(probe, winslash = "/", mustWork = TRUE)
  trusted <- normalizePath(file.path(project_root, "data/club"), winslash = "/", mustWork = TRUE)
  if (!(identical(resolved_probe, trusted) || startsWith(resolved_probe, paste0(trusted, "/")))) {
    stop("Path is outside trusted data/club root: ", candidate, call. = FALSE)
  }
  if (must_exist && !file.exists(candidate)) stop("Required path does not exist: ", candidate, call. = FALSE)
  candidate
}

inventory_path <- resolve_trusted(options$inventory, "data/club/history_sources.csv", TRUE)
registry_root <- resolve_trusted(options$`registry-root`, "data/club/registries", TRUE)
review_root <- resolve_trusted(options$`identity-review-root`, "data/club/identity_reviews", TRUE)
raw_root <- resolve_trusted(options$`raw-root`, "data/club/local_raw", FALSE)
audit_root <- resolve_trusted(options$`audit-root`, "data/club/history_audits/club-history-2026-01", FALSE)
accepted_root <- resolve_trusted(options$`accepted-root`, "data/club/accepted/club-history-2026-01", FALSE)
corpus_id <- options$`corpus-id` %||% "club-history-2026-01"
cutoff_utc <- options$cutoff %||% "2026-01-01T00:00:00Z"

if (!grepl("^[a-z0-9][a-z0-9-]*$", corpus_id)) stop("corpus-id must be a safe lowercase identifier", call. = FALSE)
invisible(phase18_history_parse_utc(cutoff_utc, "cutoff"))

run <- function() {
  inventory <- phase18_history_read_csv(inventory_path)
  phase18_validate_history_sources(inventory)
  registries <- phase18_load_club_registries(registry_root)
  current_tokens <- phase18_history_read_csv(
    file.path(review_root, "current_ucl_tokens.csv"), phase18_club_token_schema()
  )
  history_tokens <- phase18_history_read_csv(
    file.path(review_root, "historical_inventory_tokens.csv"), phase18_club_token_schema()
  )
  identity_review <- phase18_history_read_csv(
    file.path(review_root, "historical_owner_review.csv"), phase18_club_review_schema()
  )
  unresolved <- phase18_history_read_csv(
    file.path(review_root, "unresolved_club_tokens.csv"), phase18_unresolved_club_token_schema()
  )
  if (nrow(history_tokens) && any(history_tokens$corpus != "historical_inventory")) {
    phase18_history_abort("invalid_history_identity_review", "Historical token ledger contains a foreign corpus")
  }
  unresolved_history <- unresolved[unresolved$corpus == "historical_inventory", , drop = FALSE]

  normalized_parts <- list()
  active <- inventory[inventory$source_status == "active", , drop = FALSE]
  if (nrow(active)) {
    invisible(tryCatch(
      phase18_validate_identity_bootstrap(
        list(registries = registries, tokens = rbind(current_tokens, history_tokens), unresolved = unresolved),
        current_expectations = list(
          required = FALSE, expected_tokens = nrow(current_tokens), not_run = !nrow(current_tokens)
        ),
        history_expectations = list(
          required = TRUE, expected_tokens = nrow(history_tokens), not_run = FALSE
        )
      ),
      error = function(error) {
        if (!inherits(error, "club_identity_bootstrap_blocked")) stop(error)
        error$report
      }
    ))
  }
  if (nrow(active) && !dir.exists(raw_root)) {
    phase18_history_abort("missing_history_raw_root", "Active inventory requires the declared local raw root")
  }
  for (index in seq_len(nrow(active))) {
    source_row <- active[index, , drop = FALSE]
    path <- phase18_verify_history_source_file(source_row, raw_root)
    rows <- phase18_history_read_csv(path)
    required <- c(
      "source_match_id", "event_date", "kickoff_utc", "stage", "status",
      "home_name", "away_name", "score_text", "score_semantics", "evidence_updated_at_utc"
    )
    if (!identical(names(rows), required)) {
      phase18_history_abort(
        "unsupported_history_source_format",
        "Pinned source is not the reviewed normalized OpenFootball exchange schema"
      )
    }
    normalized_parts[[length(normalized_parts) + 1L]] <- phase18_normalize_club_history(
      rows, source_row, registries, cutoff_utc
    )
  }
  matches <- if (length(normalized_parts)) {
    phase18_history_canonical_table(do.call(rbind, normalized_parts), c("source_id", "source_match_id", "match_id"))
  } else {
    phase18_history_empty(phase18_normalized_club_match_schema())
  }

  parser_commit <- tryCatch(
    trimws(system2("git", c("-C", project_root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))[[1L]],
    error = function(error) "working-tree"
  )
  audit <- phase18_audit_club_history(
    matches, inventory, registries, cutoff_utc,
    corpus_id = corpus_id, created_at_utc = cutoff_utc, parser_commit = parser_commit,
    identity_review = identity_review,
    unresolved_identity = unresolved_history
  )
  result <- phase18_publish_club_history_corpus(audit, audit_root, accepted_root)
  if (!isTRUE(result$accepted_for_training)) {
    message(
      "club_history_corpus status=blocked corpus_id=", corpus_id,
      " reason=", result$blocked_reasons,
      " audit_root=", result$audit_root
    )
    quit(save = "no", status = 2L)
  }
  message("club_history_corpus status=accepted corpus_id=", corpus_id, " accepted_root=", result$accepted_root)
  invisible(TRUE)
}

tryCatch(
  run(),
  error = function(error) {
    reason <- if (is.null(error$reason)) class(error)[[1L]] else error$reason
    message("club_history_corpus status=blocked reason=", reason, " message=", conditionMessage(error))
    quit(save = "no", status = 2L)
  }
)
