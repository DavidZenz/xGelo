#!/usr/bin/env Rscript

phase18_accept_command_args <- commandArgs(trailingOnly = FALSE)
phase18_accept_file_arg <- phase18_accept_command_args[grepl("^--file=", phase18_accept_command_args)]
phase18_accept_source_file <- tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
phase18_accept_search_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
phase18_accept_upward_candidates <- character()
repeat {
  phase18_accept_upward_candidates <- c(
    phase18_accept_upward_candidates,
    file.path(phase18_accept_search_root, "scripts/accept_ucl_provider.R")
  )
  phase18_accept_parent <- dirname(phase18_accept_search_root)
  if (identical(phase18_accept_parent, phase18_accept_search_root)) break
  phase18_accept_search_root <- phase18_accept_parent
}
phase18_accept_candidates <- c(
  if (length(phase18_accept_file_arg)) sub("^--file=", "", phase18_accept_file_arg[[1L]]) else character(),
  if (!is.null(phase18_accept_source_file)) as.character(phase18_accept_source_file) else character(),
  phase18_accept_upward_candidates
)
phase18_accept_candidates <- phase18_accept_candidates[!is.na(phase18_accept_candidates) & nzchar(phase18_accept_candidates)]
phase18_accept_script <- phase18_accept_candidates[vapply(phase18_accept_candidates, file.exists, logical(1))][1L]
if (is.na(phase18_accept_script) || !nzchar(phase18_accept_script)) {
  stop("Phase 18 acceptance entrypoint could not resolve its script path", call. = FALSE)
}
phase18_accept_script <- normalizePath(phase18_accept_script, winslash = "/", mustWork = TRUE)
phase18_accept_project_root <- normalizePath(file.path(dirname(phase18_accept_script), ".."), winslash = "/", mustWork = TRUE)
source(file.path(phase18_accept_project_root, "R/competition/ucl_source_acceptance.R"), local = TRUE)

phase18_accept_parse_args <- function(args) {
  allowed <- c("provider-id", "edition-id", "review-path", "evidence-root")
  output <- list()
  index <- 1L
  while (index <= length(args)) {
    token <- args[[index]]
    if (!startsWith(token, "--")) stop("Phase 18 acceptance arguments must start with --", call. = FALSE)
    key <- gsub("_", "-", sub("^--", "", token), fixed = TRUE)
    if (!key %in% allowed) stop("Unsupported Phase 18 acceptance option: --", key, call. = FALSE)
    if (index == length(args)) stop("Phase 18 acceptance option requires a value: --", key, call. = FALSE)
    output[[key]] <- args[[index + 1L]]
    index <- index + 2L
  }
  missing <- allowed[!vapply(allowed, function(key) !is.null(output[[key]]) && nzchar(output[[key]]), logical(1))]
  if (length(missing)) stop("Phase 18 acceptance is missing options: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(output[["provider-id"]], "football_data_org_v4")) stop("Phase 18 provider ID is fixed to football_data_org_v4", call. = FALSE)
  output
}

phase18_acceptance_markdown <- function(manifest) {
  paste0(
    "# UCL Provider Acceptance\n\n",
    "Decision: `", manifest$decision[[1L]], "` (`", manifest$reason_code[[1L]], "`).\n\n",
    "Automation enabled: `", toupper(as.character(manifest$automation_enabled[[1L]])), "`.\n\n",
    "This artifact records whether the live acceptance gate ran. It is not legal advice, ",
    "and offline fixtures or a missing credential are not live provider acceptance.\n"
  )
}

phase18_accept_ucl_provider_main <- function(
    args = commandArgs(trailingOnly = TRUE),
    token_present = nzchar(Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = "")),
    transport_fn = NULL,
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parser_commit_sha = NULL) {
  options <- phase18_accept_parse_args(args)
  preflight <- phase18_provider_preflight(token_present, now_utc)
  target_root <- file.path(options[["evidence-root"]], options[["provider-id"]], options[["edition-id"]])
  review <- phase18_read_terms_review(options[["review-path"]])
  if (is.null(review)) review <- data.frame()
  expectation_path <- file.path(target_root, "edition_expectations.csv")
  expectations <- if (file.exists(expectation_path)) {
    utils::read.csv(expectation_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  } else {
    phase18_default_edition_expectations(options[["edition-id"]], now_utc)
  }
  machine_checks <- phase18_default_machine_checks(expectations, now_utc, preflight$reason_code[[1L]])
  schema_fingerprint <- phase18_default_schema_fingerprint(now_utc)
  if (isTRUE(token_present)) {
    if (!is.function(transport_fn)) {
      stop("Phase 18 live acceptance requires the injected bounded probe transport", call. = FALSE)
    }
    stop("Phase 18 live acceptance probe is implemented by the atomic probe task", call. = FALSE)
  }
  schema_hash <- phase18_canonical_sha256(schema_fingerprint, key = "resource")
  manifest <- phase18_build_acceptance_manifest(
    machine_checks,
    review,
    expectations,
    list(schema_fingerprint_sha256 = schema_hash),
    decision_id = paste0("not_run_missing_credential_", options[["edition-id"]]),
    now_utc = now_utc,
    parser_commit_sha = parser_commit_sha,
    project_root = phase18_accept_project_root
  )
  dir.create(target_root, recursive = TRUE, showWarnings = FALSE)
  phase18_write_csv_atomic(review, file.path(target_root, "provider_terms_review.csv"))
  phase18_write_csv_atomic(expectations, file.path(target_root, "edition_expectations.csv"))
  phase18_write_csv_atomic(machine_checks, file.path(target_root, "coverage_matrix.csv"))
  phase18_write_csv_atomic(schema_fingerprint, file.path(target_root, "schema_fingerprint.csv"))
  phase18_write_csv_atomic(manifest, file.path(target_root, "acceptance_manifest.csv"))
  phase18_write_text_atomic(phase18_acceptance_markdown(manifest), file.path(target_root, "ACCEPTANCE.md"))
  invisible(list(
    preflight = preflight,
    owner_review = review,
    edition_expectations = expectations,
    machine_checks = machine_checks,
    schema_fingerprint = schema_fingerprint,
    manifest = manifest,
    evidence_root = target_root
  ))
}

if (sys.nframe() == 0L) {
  tryCatch(
    {
      result <- phase18_accept_ucl_provider_main()
      message(sprintf(
        "Phase 18 provider decision: %s (%s); automation_enabled=%s",
        result$manifest$decision[[1L]],
        result$manifest$reason_code[[1L]],
        result$manifest$automation_enabled[[1L]]
      ))
    },
    error = function(error) stop("Phase 18 provider acceptance blocked: ", conditionMessage(error), call. = FALSE)
  )
}
