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
source(file.path(phase18_accept_project_root, "R/common/phase18_canonical_hash.R"), local = TRUE)
source(file.path(phase18_accept_project_root, "R/competition/ucl_source_acceptance.R"), local = TRUE)
source(file.path(phase18_accept_project_root, "R/club/identity.R"), local = TRUE)
source(file.path(phase18_accept_project_root, "R/club/identity_bootstrap.R"), local = TRUE)
source(file.path(phase18_accept_project_root, "R/competition/football_data_org_adapter.R"), local = TRUE)
source(file.path(phase18_accept_project_root, "R/competition/ucl_source_bundle.R"), local = TRUE)

phase18_accept_parse_args <- function(args) {
  required <- c("provider-id", "edition-id", "review-path", "evidence-root")
  allowed <- c(
    required, "mode", "club-registry-root", "candidate-root", "bundle-id",
    "manual-review-path", "fixture-contract-path"
  )
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
  missing <- required[!vapply(required, function(key) !is.null(output[[key]]) && nzchar(output[[key]]), logical(1))]
  if (length(missing)) stop("Phase 18 acceptance is missing options: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(output[["provider-id"]], "football_data_org_v4")) stop("Phase 18 provider ID is fixed to football_data_org_v4", call. = FALSE)
  if (is.null(output$mode)) output$mode <- "preflight"
  if (!output$mode %in% c("preflight", "offline_contract_test", "live_acceptance_probe", "provider_live", "manual_reviewed", "fixture_contract")) {
    stop("Phase 18 acceptance mode is unsupported", call. = FALSE)
  }
  adapter_modes <- c("offline_contract_test", "live_acceptance_probe", "provider_live")
  if (output$mode %in% adapter_modes && (is.null(output[["club-registry-root"]]) || !nzchar(output[["club-registry-root"]]))) {
    stop("Phase 18 adapter modes require --club-registry-root", call. = FALSE)
  }
  if (output$mode %in% c("provider_live", "manual_reviewed", "fixture_contract")) {
    candidate_missing <- c("candidate-root", "bundle-id")[!vapply(c("candidate-root", "bundle-id"), function(key) {
      !is.null(output[[key]]) && nzchar(output[[key]])
    }, logical(1))]
    if (length(candidate_missing)) stop("Phase 18 candidate mode is missing options: ", paste(candidate_missing, collapse = ", "), call. = FALSE)
  }
  if (identical(output$mode, "manual_reviewed") &&
      (is.null(output[["manual-review-path"]]) || !nzchar(output[["manual-review-path"]]))) {
    stop("Phase 18 manual_reviewed mode requires --manual-review-path", call. = FALSE)
  }
  if (identical(output$mode, "fixture_contract") &&
      (is.null(output[["fixture-contract-path"]]) || !nzchar(output[["fixture-contract-path"]]))) {
    stop("Phase 18 fixture_contract mode requires --fixture-contract-path", call. = FALSE)
  }
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
    perform_request = NULL,
    fetch_window_fn = phase18_fd_fetch_window,
    project_resources_fn = phase18_fd_project_resources,
    clock_fn = Sys.time,
    sleep_fn = Sys.sleep,
    now_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parser_commit_sha = NULL,
    candidate_input_fn = NULL) {
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
  if (options$mode %in% c("manual_reviewed", "fixture_contract")) {
    if (!is.function(candidate_input_fn)) {
      stop("Phase 18 non-provider candidate modes require an explicit local candidate input loader", call. = FALSE)
    }
    if (identical(options$mode, "manual_reviewed")) {
      review_path <- normalizePath(options[["manual-review-path"]], winslash = "/", mustWork = TRUE)
      manual_review <- utils::read.csv(review_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
      authority <- list(authority_type = "manual_source_review", manual_source_review = manual_review)
    } else {
      contract_path <- normalizePath(options[["fixture-contract-path"]], winslash = "/", mustWork = TRUE)
      fixture_contract <- utils::read.csv(contract_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
      authority <- list(authority_type = "fixture_contract", fixture_contract = fixture_contract)
    }
    validated_authority <- phase18_validate_source_authority(options$mode, authority)
    if (!identical(as.character(validated_authority$record$source_mode[[1L]]), options$mode)) {
      stop("Phase 18 candidate authority mode mismatch", call. = FALSE)
    }
    inputs <- candidate_input_fn(options, validated_authority)
    if (!is.list(inputs) || is.null(inputs$fetched) || is.null(inputs$projected)) {
      stop("Phase 18 candidate input must supply fetched bytes and projected tables", call. = FALSE)
    }
    candidate_expectations <- if (!is.null(inputs$edition_expectations)) inputs$edition_expectations else expectations
    candidate <- phase18_build_ucl_source_bundle(
      inputs$projected, inputs$fetched, authority, candidate_expectations,
      options[["bundle-id"]]
    )
    installed <- phase18_write_ucl_candidate(options[["candidate-root"]], candidate)
    promotable <- phase18_ucl_bool(installed$bundle$promotion_eligible[[1L]], "promotion_eligible")
    provider_enabled <- phase18_ucl_bool(installed$bundle$provider_automation_enabled[[1L]], "provider_automation_enabled")
    return(invisible(list(
      mode = options$mode, bundle_id = installed$bundle$bundle_id[[1L]],
      bundle_sha256 = installed$bundle$bundle_sha256[[1L]],
      manifest_self_sha256 = installed$bundle$manifest_self_sha256[[1L]],
      authority_id = installed$bundle$authority_id[[1L]],
      authority_sha256 = installed$bundle$authority_sha256[[1L]],
      promotion_eligible = promotable, provider_automation_enabled = provider_enabled,
      candidate_root = normalizePath(options[["candidate-root"]], winslash = "/", mustWork = TRUE),
      resource_count = nrow(installed$artifacts), table_count = nrow(installed$table_manifest),
      reason_code = if (promotable) "candidate_validated" else "candidate_validated_non_promotable"
    )))
  }
  if (identical(options$mode, "provider_live")) {
    if (!isTRUE(token_present)) stop("Phase 18 provider_live candidate requires FOOTBALL_DATA_API_TOKEN", call. = FALSE)
    accepted <- phase18_read_acceptance_set(target_root)
    phase18_validate_acceptance_manifest(
      accepted$manifest, accepted$machine_checks, accepted$owner_review, accepted$edition_expectations
    )
    if (!isTRUE(accepted$manifest$automation_enabled[[1L]]) ||
        !identical(as.character(accepted$manifest$decision[[1L]]), "accepted") ||
        !identical(as.character(accepted$manifest$execution_mode[[1L]]), "live_acceptance_probe")) {
      stop("Phase 18 provider_live candidate requires an accepted provider authority", call. = FALSE)
    }
    inputs <- if (is.function(candidate_input_fn)) {
      candidate_input_fn(options, accepted)
    } else {
      if (!is.function(perform_request)) perform_request <- phase18_fd_live_performer()
      fetched <- fetch_window_fn(phase18_fd_request_plan(), perform_request, clock_fn, sleep_fn)
      registries <- phase18_load_club_registries(options[["club-registry-root"]])
      projected <- project_resources_fn(
        fetched, options[["edition-id"]], registries, accepted$edition_expectations, now_utc = now_utc
      )
      list(fetched = fetched, projected = projected)
    }
    if (!is.list(inputs) || is.null(inputs$fetched) || is.null(inputs$projected)) {
      stop("Phase 18 candidate input must supply fetched bytes and projected tables", call. = FALSE)
    }
    authority <- list(authority_type = "provider_acceptance", provider_acceptance = accepted)
    candidate <- phase18_build_ucl_source_bundle(
      inputs$projected, inputs$fetched, authority, accepted$edition_expectations,
      options[["bundle-id"]]
    )
    installed <- phase18_write_ucl_candidate(options[["candidate-root"]], candidate)
    return(invisible(list(
      mode = "provider_live", bundle_id = installed$bundle$bundle_id[[1L]],
      bundle_sha256 = installed$bundle$bundle_sha256[[1L]],
      manifest_self_sha256 = installed$bundle$manifest_self_sha256[[1L]],
      authority_id = installed$bundle$authority_id[[1L]],
      authority_sha256 = installed$bundle$authority_sha256[[1L]],
      promotion_eligible = installed$bundle$promotion_eligible[[1L]],
      candidate_root = normalizePath(options[["candidate-root"]], winslash = "/", mustWork = TRUE),
      resource_count = nrow(installed$artifacts), table_count = nrow(installed$table_manifest),
      reason_code = "candidate_validated"
    )))
  }
  adapter_mode <- options$mode %in% c("offline_contract_test", "live_acceptance_probe")
  if (adapter_mode) {
    if (identical(options$mode, "live_acceptance_probe") && !isTRUE(token_present)) {
      stop("Phase 18 live_acceptance_probe requires FOOTBALL_DATA_API_TOKEN", call. = FALSE)
    }
    if (!is.function(perform_request)) {
      if (identical(options$mode, "live_acceptance_probe")) {
        perform_request <- phase18_fd_live_performer()
      } else {
        stop("Phase 18 offline adapter contract requires an injected performer", call. = FALSE)
      }
    }
    review_result <- phase18_validate_terms_review(review)
    if (!review_result$valid) {
      stop("Phase 18 adapter probe requires a complete owner review: ", review_result$message, call. = FALSE)
    }
    request_plan <- phase18_fd_request_plan()
    fetched <- fetch_window_fn(request_plan, perform_request, clock_fn, sleep_fn)
    registries <- phase18_load_club_registries(options[["club-registry-root"]])
    projected <- project_resources_fn(
      fetched, options[["edition-id"]], registries, expectations, now_utc = now_utc
    )
    current_resources <- data.frame(
      source_system = "football_data_org_v4",
      source_row = paste0("teams:", projected$clubs$provider_club_id),
      source_club_id = projected$clubs$provider_club_id,
      display_name = projected$clubs$display_name,
      event_at_utc = projected$clubs$last_updated_utc,
      stringsAsFactors = FALSE, check.names = FALSE
    )
    current_tokens <- phase18_extract_club_tokens(current_resources = current_resources)
    if (nrow(current_tokens) != nrow(projected$clubs)) {
      stop("Phase 18 current club-token evidence is incomplete", call. = FALSE)
    }
    for (index in seq_len(nrow(current_tokens))) {
      phase18_resolve_club_identity(
        registries, current_tokens$source_system[[index]], current_tokens$source_club_id[[index]],
        current_tokens$display_value[[index]], current_tokens$event_at_utc[[index]]
      )
    }
    secret <- if (isTRUE(token_present)) Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = "") else ""
    phase18_fd_assert_secret_absent(list(fetched = fetched, projected = projected, tokens = current_tokens), secret)
    resource_counts <- c(
      competition_metadata = nrow(projected$competition), teams = nrow(projected$clubs),
      matches = nrow(projected$matches), standings = nrow(projected$standings)
    )
    fingerprints <- setNames(projected$schema_fingerprint$fingerprint_sha256, projected$schema_fingerprint$resource)
    probe_transport <- function(endpoint, attempt, cache = FALSE) {
      list(
        count = as.integer(resource_counts[[endpoint]]),
        stages = if (identical(endpoint, "matches")) paste(projected$coverage$stages, collapse = "|") else "",
        freshness_passed = isTRUE(projected$coverage$freshness_passed),
        identity_passed = isTRUE(projected$coverage$identity_passed),
        pagination_complete = isTRUE(projected$coverage$pagination_complete),
        secret_scan_passed = TRUE,
        fingerprint_sha256 = unname(fingerprints[[endpoint]]),
        retryable = FALSE
      )
    }
    decision_id <- paste0(options$mode, "_", options[["edition-id"]], "_", gsub("[^0-9]", "", now_utc))
    if (identical(options$mode, "live_acceptance_probe")) {
      result <- phase18_run_live_acceptance_probe(
      evidence_root = target_root,
      owner_review = review,
      edition_expectations = expectations,
      transport_fn = probe_transport,
      decision_id = decision_id,
      now_utc = now_utc,
      parser_commit_sha = parser_commit_sha
      )
      result$projected <- projected
      result$current_club_tokens <- current_tokens
      return(invisible(result))
    }
    offline_checks <- phase18_default_machine_checks(expectations, now_utc, "offline_only")
    offline_checks$execution_mode <- "offline_contract_test"
    offline_checks$passed <- TRUE
    offline_checks$freshness_passed <- TRUE
    offline_checks$identity_passed <- TRUE
    offline_checks$pagination_complete <- TRUE
    offline_checks$secret_scan_passed <- TRUE
    offline_checks$observed_count[match(names(resource_counts), offline_checks$capability)] <- unname(resource_counts)
    offline_checks$observed_stages[offline_checks$capability == "matches"] <- paste(projected$coverage$stages, collapse = "|")
    offline_checks$row_sha256 <- ""
    offline_checks <- phase18_hash_machine_checks(offline_checks)
    offline_manifest <- phase18_build_acceptance_manifest(
      offline_checks, review, expectations,
      list(schema_fingerprint_sha256 = phase18_canonical_sha256(projected$schema_fingerprint, key = "resource")),
      decision_id, now_utc, parser_commit_sha = parser_commit_sha,
      project_root = phase18_accept_project_root
    )
    return(invisible(list(
      manifest = offline_manifest, machine_checks = offline_checks,
      projected = projected, current_club_tokens = current_tokens,
      evidence_root = target_root
    )))
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
  incumbent <- tryCatch(phase18_read_acceptance_set(target_root), error = function(error) NULL)
  if (!is.null(incumbent)) {
    return(invisible(list(
      preflight = preflight,
      owner_review = review,
      edition_expectations = expectations,
      machine_checks = machine_checks,
      schema_fingerprint = schema_fingerprint,
      manifest = manifest,
      evidence_root = target_root,
      incumbent_preserved = TRUE
    )))
  }
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
