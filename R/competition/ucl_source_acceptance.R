#' Phase 18 football-data.org acceptance contracts.
#'
#' This module deliberately models credential *presence* only. Credential bytes,
#' request objects, and authentication headers must never cross into these
#' durable evidence contracts.

phase18_acceptance_schema_version <- function() "phase18-provider-acceptance-v1"

phase18_owner_review_dimensions <- function() {
  c(
    "application_scope", "rights", "normalized_display", "attribution",
    "raw_cache", "retention_termination", "provider_exit"
  )
}

phase18_decisions <- function() c("not_run", "accepted", "rejected", "manual_only")

phase18_reason_codes <- function() {
  c(
    "missing_credential", "application_scope", "terms", "attribution",
    "retention", "quota", "schema", "coverage", "cardinality", "stage",
    "standings", "freshness", "identity", "secret_exposure", "offline_only",
    "accepted", "blocked_concurrent_acceptance", "blocked_decision_collision",
    "interrupted", "writer_failure"
  )
}

phase18_acceptance_scalar <- function(value, name, allow_empty = FALSE) {
  if (is.null(value) || length(value) != 1L || is.na(value[[1L]])) {
    stop("Phase 18 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) {
    stop("Phase 18 ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase18_acceptance_bool <- function(value, name) {
  if (length(value) != 1L || !is.logical(value) || is.na(value[[1L]])) {
    stop("Phase 18 ", name, " must be one non-missing logical value", call. = FALSE)
  }
  isTRUE(value[[1L]])
}

phase18_canonical_scalar <- function(value) {
  if (!length(value) || is.na(value[[1L]])) return("")
  if (inherits(value, "Date")) return(format(value[[1L]], "%Y-%m-%d"))
  if (inherits(value, "POSIXt")) return(format(value[[1L]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (is.logical(value)) return(if (isTRUE(value[[1L]])) "true" else "false")
  as.character(value[[1L]])
}

phase18_sha256_text <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 18 acceptance hashes", call. = FALSE)
  }
  digest::digest(charToRaw(enc2utf8(paste(value, collapse = ""))), algo = "sha256", serialize = FALSE)
}

phase18_canonical_sha256 <- function(data, key = NULL, exclude = character()) {
  if (!is.data.frame(data) || !ncol(data)) {
    stop("Phase 18 canonical hashing requires a data frame with columns", call. = FALSE)
  }
  data <- data[, setdiff(names(data), exclude), drop = FALSE]
  if (!ncol(data)) stop("Phase 18 canonical hashing has no remaining columns", call. = FALSE)
  if (is.null(key)) key <- names(data)[[1L]]
  missing <- setdiff(key, names(data))
  if (length(missing)) stop("Phase 18 canonical hash key is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(data)) {
    ordering <- lapply(data[key], function(column) vapply(seq_along(column), function(i) phase18_canonical_scalar(column[i]), character(1)))
    data <- data[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, , drop = FALSE], phase18_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  phase18_sha256_text(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"))
}

phase18_row_sha256 <- function(data, exclude = "row_sha256") {
  if (!is.data.frame(data)) stop("Phase 18 row hashing requires a data frame", call. = FALSE)
  fields <- setdiff(names(data), exclude)
  vapply(seq_len(nrow(data)), function(index) {
    phase18_sha256_text(paste(vapply(data[index, fields, drop = FALSE], phase18_canonical_scalar, character(1)), collapse = "|"))
  }, character(1))
}

phase18_parser_commit_sha <- function(project_root = ".") {
  output <- tryCatch(
    system2("git", c("-C", normalizePath(project_root, winslash = "/", mustWork = TRUE), "rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE),
    error = function(error) character()
  )
  status <- attr(output, "status")
  if (!length(output) || (!is.null(status) && status != 0L)) {
    stop("Phase 18 parser identity requires git rev-parse HEAD", call. = FALSE)
  }
  sha <- tolower(trimws(output[[1L]]))
  if (!grepl("^[0-9a-f]{7,64}$", sha)) stop("Phase 18 parser identity is not a Git SHA", call. = FALSE)
  sha
}

phase18_hash_terms_review <- function(review) {
  if (!is.data.frame(review)) stop("Phase 18 terms review must be a data frame", call. = FALSE)
  if (!"schema_version" %in% names(review)) review$schema_version <- "phase18-provider-terms-review-v1"
  if (!"review_id" %in% names(review)) {
    seed <- phase18_canonical_sha256(review, key = intersect(c("provider_id", "dimension"), names(review)))
    review$review_id <- paste0("terms-review-", substr(seed, 1L, 16L))
  }
  review$row_sha256 <- phase18_row_sha256(review)
  review
}

phase18_validate_terms_review <- function(review) {
  rejected <- function(decision = "manual_only", reason_code = "terms", message = "Owner review is incomplete") {
    list(valid = FALSE, decision = decision, reason_code = reason_code, message = message, review_sha256 = "")
  }
  if (!is.data.frame(review) || !nrow(review)) return(rejected())
  required <- c(
    "schema_version", "review_id", "provider_id", "application_id", "dimension",
    "status", "terms_url", "terms_sha256", "reviewer", "reviewed_at_utc",
    "requirement", "disposition", "notes", "row_sha256"
  )
  if (!is.data.frame(review) || !nrow(review)) return(rejected())
  missing <- setdiff(required, names(review))
  if (length(missing)) return(rejected(message = paste("Owner review missing columns:", paste(missing, collapse = ", "))))
  dimensions <- as.character(review$dimension)
  expected <- phase18_owner_review_dimensions()
  if (!setequal(dimensions, expected) || anyDuplicated(dimensions) || nrow(review) != length(expected)) {
    return(rejected(message = "Owner review must contain exactly one row per required dimension"))
  }
  if (length(unique(as.character(review$provider_id))) != 1L ||
      length(unique(as.character(review$application_id))) != 1L ||
      length(unique(as.character(review$review_id))) != 1L ||
      length(unique(as.character(review$terms_url))) != 1L ||
      length(unique(tolower(as.character(review$terms_sha256)))) != 1L) {
    return(rejected(reason_code = "application_scope", message = "Owner review identity or terms evidence is inconsistent"))
  }
  required_text <- c("provider_id", "application_id", "review_id", "terms_url", "reviewer", "reviewed_at_utc", "requirement", "disposition")
  if (any(vapply(review[required_text], function(column) any(is.na(column) | !nzchar(as.character(column))), logical(1)))) {
    return(rejected(message = "Owner review contains blank required evidence"))
  }
  if (any(!grepl("^[0-9a-fA-F]{64}$", as.character(review$terms_sha256)))) {
    return(rejected(message = "Owner review terms SHA-256 is invalid"))
  }
  expected_rows <- phase18_row_sha256(review)
  if (any(tolower(as.character(review$row_sha256)) != expected_rows)) {
    return(rejected(decision = "rejected", message = "Owner review row hash mismatch"))
  }
  statuses <- tolower(as.character(review$status))
  if (any(!statuses %in% c("approved", "pending", "rejected"))) {
    return(rejected(decision = "rejected", message = "Owner review contains an unsupported status"))
  }
  review_hash <- phase18_canonical_sha256(review, key = "dimension")
  if (any(statuses == "rejected")) {
    return(list(valid = FALSE, decision = "rejected", reason_code = "terms", message = "Owner review rejected", review_sha256 = review_hash))
  }
  if (any(statuses != "approved")) {
    return(list(valid = FALSE, decision = "manual_only", reason_code = "terms", message = "Owner review is pending", review_sha256 = review_hash))
  }
  list(valid = TRUE, decision = "accepted", reason_code = "accepted", message = "Owner review approved", review_sha256 = review_hash)
}

phase18_hash_edition_expectations <- function(expectations) {
  if (!is.data.frame(expectations)) stop("Phase 18 edition expectations must be a data frame", call. = FALSE)
  if (!"schema_version" %in% names(expectations)) expectations$schema_version <- "phase18-edition-expectation-v1"
  expectations$row_sha256 <- phase18_row_sha256(expectations, exclude = c("row_sha256", "expectation_sha256"))
  aggregate <- phase18_canonical_sha256(expectations, key = c("edition_id", "lifecycle"), exclude = "expectation_sha256")
  expectations$expectation_sha256 <- aggregate
  expectations
}

phase18_validate_edition_expectations <- function(expectations, observed = NULL, lifecycle = NULL) {
  fail <- function(reason_code, message) list(valid = FALSE, decision = "rejected", reason_code = reason_code, message = message, expectation_sha256 = "")
  if (!is.data.frame(expectations) || !nrow(expectations)) return(fail("cardinality", "Edition expectations are absent"))
  required <- c(
    "schema_version", "edition_id", "lifecycle", "expected_club_count",
    "expected_league_phase_match_count", "allowed_stages", "standings_required",
    "expected_standings_rows", "reviewer", "reviewed_at_utc", "row_sha256",
    "expectation_sha256"
  )
  missing <- setdiff(required, names(expectations))
  if (length(missing)) return(fail("schema", paste("Edition expectations missing columns:", paste(missing, collapse = ", "))))
  if (anyDuplicated(expectations[c("edition_id", "lifecycle")])) return(fail("cardinality", "Edition expectation lifecycle rows are duplicated"))
  expected_rows <- phase18_row_sha256(expectations, exclude = c("row_sha256", "expectation_sha256"))
  if (any(tolower(as.character(expectations$row_sha256)) != expected_rows)) return(fail("schema", "Edition expectation row hash mismatch"))
  aggregate <- phase18_canonical_sha256(expectations, key = c("edition_id", "lifecycle"), exclude = "expectation_sha256")
  if (any(tolower(as.character(expectations$expectation_sha256)) != aggregate)) return(fail("schema", "Edition expectation aggregate hash mismatch"))
  league <- expectations[as.character(expectations$lifecycle) == "league_phase", , drop = FALSE]
  if (nrow(league) != 1L || as.integer(league$expected_club_count) != 36L ||
      as.integer(league$expected_league_phase_match_count) != 144L ||
      !isTRUE(as.logical(league$standings_required[[1L]])) ||
      as.integer(league$expected_standings_rows) != 36L) {
    return(fail("cardinality", "The reviewed league-phase expectation must be exactly 36 clubs, 144 matches, and 36 standings rows"))
  }
  selected <- expectations
  if (!is.null(lifecycle)) {
    lifecycle <- phase18_acceptance_scalar(lifecycle, "lifecycle")
    selected <- expectations[as.character(expectations$lifecycle) == lifecycle, , drop = FALSE]
    if (nrow(selected) != 1L) return(fail("cardinality", "Requested lifecycle expectation is missing"))
  }
  if (!is.null(observed)) {
    row <- if (is.data.frame(observed)) observed[1L, , drop = FALSE] else as.list(observed)
    value <- function(name, default = NA) {
      item <- row[[name]]
      if (is.null(item) || !length(item)) default else item[[1L]]
    }
    expected <- selected[1L, , drop = FALSE]
    if (as.integer(value("club_count")) != as.integer(expected$expected_club_count) ||
        as.integer(value("league_phase_match_count")) != as.integer(expected$expected_league_phase_match_count)) {
      return(fail("cardinality", "Observed club or schedule cardinality differs from the reviewed expectation"))
    }
    observed_stages <- as.character(value("stages", character()))
    observed_stages <- unique(trimws(unlist(strsplit(paste(observed_stages, collapse = "|"), "\\|", fixed = FALSE))))
    allowed <- unique(trimws(unlist(strsplit(as.character(expected$allowed_stages[[1L]]), "\\|", fixed = FALSE))))
    if (length(setdiff(observed_stages[nzchar(observed_stages)], allowed))) return(fail("stage", "Observed provider stage is outside the reviewed allowlist"))
    if (isTRUE(as.logical(expected$standings_required[[1L]])) &&
        as.integer(value("standings_rows")) != as.integer(expected$expected_standings_rows)) {
      return(fail("standings", "Observed standings cardinality differs from the reviewed expectation"))
    }
  }
  list(valid = TRUE, decision = "accepted", reason_code = "accepted", message = "Edition expectations validated", expectation_sha256 = aggregate)
}

phase18_hash_machine_checks <- function(machine_checks) {
  if (!is.data.frame(machine_checks)) stop("Phase 18 machine checks must be a data frame", call. = FALSE)
  machine_checks$row_sha256 <- phase18_row_sha256(machine_checks)
  machine_checks
}

phase18_validate_machine_checks <- function(machine_checks) {
  fail <- function(reason_code, message) list(valid = FALSE, reason_code = reason_code, message = message, machine_evidence_sha256 = "")
  if (!is.data.frame(machine_checks) || !nrow(machine_checks)) return(fail("coverage", "Machine evidence is absent"))
  required <- c(
    "schema_version", "capability", "decision", "execution_mode", "passed",
    "observed_count", "observed_stages", "expectation_sha256", "live_run_id",
    "real_key_evidence", "freshness_passed", "identity_passed",
    "pagination_complete", "secret_scan_passed", "checked_at_utc", "row_sha256"
  )
  missing <- setdiff(required, names(machine_checks))
  if (length(missing)) return(fail("schema", paste("Machine checks missing columns:", paste(missing, collapse = ", "))))
  if (anyDuplicated(as.character(machine_checks$capability))) return(fail("coverage", "Machine capability rows are duplicated"))
  expected_rows <- phase18_row_sha256(machine_checks)
  if (any(tolower(as.character(machine_checks$row_sha256)) != expected_rows)) return(fail("schema", "Machine evidence row hash mismatch"))
  list(
    valid = TRUE,
    reason_code = "accepted",
    message = "Machine evidence schema validated",
    machine_evidence_sha256 = phase18_canonical_sha256(machine_checks, key = "capability")
  )
}

#' Return the fail-closed decision before any transport can run.
phase18_provider_preflight <- function(token_present, now_utc) {
  token_present <- phase18_acceptance_bool(token_present, "token_present")
  now_utc <- phase18_acceptance_scalar(now_utc, "now_utc")
  row <- data.frame(
    schema_version = "phase18-provider-preflight-v1",
    decision = if (token_present) "not_run" else "not_run",
    reason_code = if (token_present) "terms" else "missing_credential",
    automation_enabled = FALSE,
    credential_status = if (token_present) "present" else "absent",
    checked_at_utc = now_utc,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- phase18_row_sha256(row)
  row
}

phase18_manifest_self_hash <- function(manifest) {
  phase18_row_sha256(manifest, exclude = "row_sha256")
}

#' Build the only manifest capable of enabling provider automation.
phase18_build_acceptance_manifest <- function(
    machine_checks,
    owner_review,
    edition_expectations,
    evidence_hashes,
    decision_id,
    now_utc,
    parser_commit_sha = NULL,
    project_root = ".") {
  decision_id <- phase18_acceptance_scalar(decision_id, "decision_id")
  now_utc <- phase18_acceptance_scalar(now_utc, "now_utc")
  review_result <- phase18_validate_terms_review(owner_review)
  expectation_result <- phase18_validate_edition_expectations(edition_expectations)
  machine_result <- phase18_validate_machine_checks(machine_checks)
  modes <- if (is.data.frame(machine_checks) && "execution_mode" %in% names(machine_checks)) unique(as.character(machine_checks$execution_mode)) else character()
  execution_mode <- if (length(modes) == 1L) modes[[1L]] else "not_run"
  required_capabilities <- c("competition_metadata", "teams", "matches", "standings")
  integrate <- if (is.data.frame(machine_checks) && all(c("decision", "capability") %in% names(machine_checks))) {
    machine_checks[as.character(machine_checks$capability) %in% required_capabilities, , drop = FALSE]
  } else machine_checks[0, , drop = FALSE]
  complete_resources <- nrow(integrate) == 4L && setequal(as.character(integrate$capability), required_capabilities)
  all_machine_pass <- complete_resources && all(as.logical(machine_checks$passed)) &&
    all(as.logical(machine_checks$freshness_passed)) && all(as.logical(machine_checks$identity_passed)) &&
    all(as.logical(machine_checks$pagination_complete)) && all(as.logical(machine_checks$secret_scan_passed))
  live_ids <- unique(as.character(integrate$live_run_id))
  live_id <- if (length(live_ids) == 1L) live_ids[[1L]] else ""
  real_key <- nrow(integrate) == 4L && all(as.logical(integrate$real_key_evidence))
  expected_hash <- expectation_result$expectation_sha256
  bound_expectation <- nzchar(expected_hash) && nrow(integrate) == 4L &&
    all(tolower(as.character(integrate$expectation_sha256)) == tolower(expected_hash))
  can_accept <- identical(execution_mode, "live_acceptance_probe") && review_result$valid &&
    expectation_result$valid && machine_result$valid && all_machine_pass && real_key &&
    nzchar(live_id) && bound_expectation
  offline_passed <- identical(execution_mode, "offline_contract_test") &&
    isTRUE(machine_result$valid) && all(as.logical(machine_checks$passed))
  if (can_accept) {
    decision <- "accepted"
    reason_code <- "accepted"
  } else if (identical(execution_mode, "not_run") && (!real_key || !nzchar(live_id))) {
    decision <- "not_run"
    reason_code <- "missing_credential"
  } else if (!review_result$valid && identical(review_result$decision, "rejected")) {
    decision <- "rejected"
    reason_code <- review_result$reason_code
  } else if (!review_result$valid) {
    decision <- "manual_only"
    reason_code <- review_result$reason_code
  } else if (identical(execution_mode, "offline_contract_test")) {
    decision <- "not_run"
    reason_code <- "offline_only"
  } else if (!real_key || !nzchar(live_id)) {
    decision <- "not_run"
    reason_code <- "missing_credential"
  } else {
    decision <- "rejected"
    reason_code <- if (!machine_result$valid) machine_result$reason_code else "coverage"
  }
  provider_id <- if (is.data.frame(owner_review) && nrow(owner_review) && "provider_id" %in% names(owner_review)) as.character(owner_review$provider_id[[1L]]) else "football_data_org_v4"
  edition_id <- if (is.data.frame(edition_expectations) && nrow(edition_expectations) && "edition_id" %in% names(edition_expectations)) as.character(edition_expectations$edition_id[[1L]]) else "ucl_2026_27"
  schema_hash <- evidence_hashes$schema_fingerprint_sha256
  if (is.null(schema_hash) || length(schema_hash) != 1L || is.na(schema_hash) || !grepl("^[0-9a-fA-F]{64}$", schema_hash)) {
    schema_hash <- phase18_sha256_text("not-observed")
  }
  parser_commit_sha <- if (is.null(parser_commit_sha)) phase18_parser_commit_sha(project_root) else tolower(phase18_acceptance_scalar(parser_commit_sha, "parser_commit_sha"))
  manifest <- data.frame(
    schema_version = phase18_acceptance_schema_version(),
    decision_id = decision_id,
    provider_id = provider_id,
    edition_id = edition_id,
    execution_mode = execution_mode,
    decision = decision,
    reason_code = reason_code,
    automation_enabled = isTRUE(can_accept),
    credential_status = if (real_key) "present" else "absent",
    offline_contract_tests_passed = isTRUE(offline_passed),
    live_provider_decision = if (can_accept) "accepted" else if (identical(execution_mode, "live_acceptance_probe")) "rejected" else "not_run",
    live_run_id = live_id,
    parser_commit_sha = parser_commit_sha,
    review_sha256 = review_result$review_sha256,
    machine_evidence_sha256 = machine_result$machine_evidence_sha256,
    expectation_sha256 = expected_hash,
    schema_fingerprint_sha256 = tolower(schema_hash),
    created_at_utc = now_utc,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest$row_sha256 <- phase18_manifest_self_hash(manifest)
  manifest
}

#' Recompute every enabling condition and reject stored-boolean tampering.
phase18_validate_acceptance_manifest <- function(manifest, machine_checks, owner_review, edition_expectations) {
  if (!is.data.frame(manifest) || nrow(manifest) != 1L) stop("Phase 18 acceptance manifest must contain one row", call. = FALSE)
  required <- c(
    "schema_version", "decision_id", "provider_id", "edition_id", "execution_mode",
    "decision", "reason_code", "automation_enabled", "credential_status",
    "offline_contract_tests_passed", "live_provider_decision", "live_run_id",
    "parser_commit_sha", "review_sha256", "machine_evidence_sha256",
    "expectation_sha256", "schema_fingerprint_sha256", "created_at_utc", "row_sha256"
  )
  missing <- setdiff(required, names(manifest))
  if (length(missing)) stop("Phase 18 acceptance manifest missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  rebuilt <- phase18_build_acceptance_manifest(
    machine_checks = machine_checks,
    owner_review = owner_review,
    edition_expectations = edition_expectations,
    evidence_hashes = list(schema_fingerprint_sha256 = as.character(manifest$schema_fingerprint_sha256[[1L]])),
    decision_id = as.character(manifest$decision_id[[1L]]),
    now_utc = as.character(manifest$created_at_utc[[1L]]),
    parser_commit_sha = as.character(manifest$parser_commit_sha[[1L]])
  )
  fields <- setdiff(required, "row_sha256")
  same <- vapply(fields, function(field) {
    identical(phase18_canonical_scalar(manifest[[field]]), phase18_canonical_scalar(rebuilt[[field]]))
  }, logical(1))
  if (any(!same)) stop("Phase 18 acceptance manifest does not match recomputed evidence: ", paste(fields[!same], collapse = ", "), call. = FALSE)
  if (!identical(tolower(as.character(manifest$row_sha256[[1L]])), phase18_manifest_self_hash(manifest)[[1L]])) {
    stop("Phase 18 acceptance manifest row hash mismatch", call. = FALSE)
  }
  invisible(manifest)
}

phase18_default_edition_expectations <- function(edition_id = "ucl_2026_27", now_utc = "1970-01-01T00:00:00Z") {
  phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v1",
    edition_id = edition_id,
    lifecycle = "league_phase",
    expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE,
    expected_standings_rows = 36L,
    reviewer = "pending_owner_review",
    reviewed_at_utc = now_utc,
    row_sha256 = "",
    expectation_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
}

phase18_default_machine_checks <- function(expectations, now_utc, reason_code = "missing_credential") {
  decisions <- phase18_capability_decisions()
  capabilities <- names(decisions)
  expectation_hash <- as.character(expectations$expectation_sha256[[1L]])
  checks <- data.frame(
    schema_version = "phase18-machine-check-v1",
    capability = capabilities,
    decision = unname(decisions),
    execution_mode = "not_run",
    passed = FALSE,
    observed_count = NA_integer_,
    observed_stages = "",
    expectation_sha256 = expectation_hash,
    live_run_id = "",
    real_key_evidence = FALSE,
    freshness_passed = FALSE,
    identity_passed = FALSE,
    pagination_complete = FALSE,
    secret_scan_passed = FALSE,
    checked_at_utc = now_utc,
    reason_code = reason_code,
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  phase18_hash_machine_checks(checks)
}

phase18_capability_decisions <- function() {
  c(
    competition_metadata = "INTEGRATE",
    teams = "INTEGRATE",
    matches = "INTEGRATE",
    standings = "INTEGRATE",
    scorers = "OPT-OUT",
    head_to_head = "OPT-OUT",
    match_detail = "OPT-OUT",
    team_detail = "OPT-OUT",
    person_detail = "OPT-OUT",
    filters = "INTEGRATE",
    pagination = "INTEGRATE",
    authenticated_headers = "INTEGRATE",
    rate_limits = "INTEGRATE",
    null_empty_semantics = "INTEGRATE",
    attribution = "INTEGRATE",
    provider_exit = "INTEGRATE"
  )
}

phase18_default_schema_fingerprint <- function(now_utc) {
  resources <- c("competition_metadata", "teams", "matches", "standings")
  rows <- data.frame(
    schema_version = "phase18-schema-fingerprint-v1",
    resource = resources,
    endpoint = c("/competitions/CL", "/competitions/CL/teams?season=2026", "/competitions/CL/matches?season=2026", "/competitions/CL/standings?season=2026"),
    observed = FALSE,
    observed_at_utc = now_utc,
    fingerprint_sha256 = vapply(resources, function(resource) phase18_sha256_text(paste("not-run", resource, sep = "|")), character(1)),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  rows$row_sha256 <- phase18_row_sha256(rows)
  rows
}

phase18_read_terms_review <- function(path) {
  path <- phase18_acceptance_scalar(path, "review_path")
  if (!file.exists(path)) return(NULL)
  review <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if ("review_set" %in% names(review)) {
    chosen <- if ("approved" %in% review$review_set) "approved" else as.character(review$review_set[[1L]])
    review <- review[as.character(review$review_set) == chosen, setdiff(names(review), "review_set"), drop = FALSE]
  }
  phase18_hash_terms_review(review)
}

phase18_write_csv_atomic <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged, force = TRUE), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 18 CSV: ", path, call. = FALSE)
  invisible(path)
}

phase18_write_text_atomic <- function(text, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged, force = TRUE), add = TRUE)
  writeLines(enc2utf8(text), staged, useBytes = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 18 text: ", path, call. = FALSE)
  invisible(path)
}

phase18_acceptance_file_names <- function() {
  c(
    "provider_terms_review.csv", "edition_expectations.csv", "coverage_matrix.csv",
    "schema_fingerprint.csv", "acceptance_manifest.csv", "ACCEPTANCE.md"
  )
}

phase18_read_acceptance_set <- function(evidence_root) {
  evidence_root <- normalizePath(evidence_root, winslash = "/", mustWork = TRUE)
  paths <- setNames(file.path(evidence_root, phase18_acceptance_file_names()), phase18_acceptance_file_names())
  missing <- names(paths)[!file.exists(paths)]
  if (length(missing)) stop("Phase 18 acceptance set is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  list(
    paths = paths,
    owner_review = utils::read.csv(paths[["provider_terms_review.csv"]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
    edition_expectations = utils::read.csv(paths[["edition_expectations.csv"]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
    machine_checks = utils::read.csv(paths[["coverage_matrix.csv"]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
    schema_fingerprint = utils::read.csv(paths[["schema_fingerprint.csv"]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
    manifest = utils::read.csv(paths[["acceptance_manifest.csv"]], stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  )
}

phase18_validate_provider_live_authority <- function(evidence_root) {
  result <- tryCatch({
    evidence <- phase18_read_acceptance_set(evidence_root)
    phase18_validate_acceptance_manifest(
      evidence$manifest,
      evidence$machine_checks,
      evidence$owner_review,
      evidence$edition_expectations,
      evidence$schema_fingerprint
    )
    authorized <- isTRUE(evidence$manifest$automation_enabled[[1L]]) &&
      identical(as.character(evidence$manifest$decision[[1L]]), "accepted") &&
      identical(as.character(evidence$manifest$execution_mode[[1L]]), "live_acceptance_probe")
    list(
      authorized = authorized,
      reason_code = if (authorized) "accepted" else as.character(evidence$manifest$reason_code[[1L]]),
      manifest = evidence$manifest
    )
  }, error = function(error) {
    list(authorized = FALSE, reason_code = "schema", message = conditionMessage(error), manifest = NULL)
  })
  result
}

phase18_probe_endpoints <- function() {
  c(
    competition_metadata = "/competitions/CL",
    teams = "/competitions/CL/teams?season=2026",
    matches = "/competitions/CL/matches?season=2026",
    standings = "/competitions/CL/standings?season=2026"
  )
}

phase18_probe_call <- function(transport_fn, endpoint, max_attempts = 3L) {
  if (!is.function(transport_fn)) stop("Phase 18 probe transport must be a function", call. = FALSE)
  max_attempts <- as.integer(max_attempts)
  if (is.na(max_attempts) || max_attempts < 1L || max_attempts > 3L) stop("Phase 18 probe attempts must be between one and three", call. = FALSE)
  last_error <- NULL
  for (attempt in seq_len(max_attempts)) {
    response <- tryCatch(
      transport_fn(endpoint = endpoint, attempt = attempt, cache = FALSE),
      error = function(error) {
        if (!isTRUE(attr(error, "retryable"))) stop(error)
        last_error <<- error
        NULL
      }
    )
    if (!is.null(response)) {
      if (!is.list(response)) stop("Phase 18 probe transport must return a list", call. = FALSE)
      if (!isTRUE(response$retryable)) return(list(response = response, attempts = attempt))
    }
  }
  if (!is.null(last_error)) stop(last_error)
  stop("Phase 18 probe exhausted its bounded retry attempts", call. = FALSE)
}

phase18_build_live_probe_evidence <- function(
    transport_fn,
    owner_review,
    edition_expectations,
    decision_id,
    now_utc) {
  review_result <- phase18_validate_terms_review(owner_review)
  if (!review_result$valid) {
    return(list(valid = FALSE, reason_code = review_result$reason_code, message = review_result$message))
  }
  expectation_result <- phase18_validate_edition_expectations(edition_expectations)
  if (!expectation_result$valid) {
    return(list(valid = FALSE, reason_code = expectation_result$reason_code, message = expectation_result$message))
  }
  endpoints <- phase18_probe_endpoints()
  responses <- list()
  attempts <- integer()
  for (capability in names(endpoints)) {
    called <- phase18_probe_call(transport_fn, capability, max_attempts = 3L)
    response <- called$response
    required <- c("count", "freshness_passed", "identity_passed", "pagination_complete", "secret_scan_passed", "fingerprint_sha256")
    missing <- setdiff(required, names(response))
    if (length(missing)) return(list(valid = FALSE, reason_code = "schema", message = paste("Probe response missing fields:", paste(missing, collapse = ", "))))
    if (!grepl("^[0-9a-fA-F]{64}$", as.character(response$fingerprint_sha256[[1L]]))) {
      return(list(valid = FALSE, reason_code = "schema", message = "Probe schema fingerprint is invalid"))
    }
    responses[[capability]] <- response
    attempts[[capability]] <- called$attempts
  }
  observed <- list(
    club_count = as.integer(responses$teams$count[[1L]]),
    league_phase_match_count = as.integer(responses$matches$count[[1L]]),
    stages = as.character(responses$matches$stages %||% ""),
    standings_rows = as.integer(responses$standings$count[[1L]])
  )
  observed_result <- phase18_validate_edition_expectations(edition_expectations, observed, "league_phase")
  if (!observed_result$valid) return(c(list(valid = FALSE), observed_result[c("reason_code", "message")]))
  if (as.integer(responses$competition_metadata$count[[1L]]) != 1L) {
    return(list(valid = FALSE, reason_code = "cardinality", message = "Competition metadata must contain exactly one object"))
  }
  resource_names <- names(endpoints)
  resource_checks <- data.frame(
    schema_version = "phase18-machine-check-v1",
    capability = resource_names,
    decision = "INTEGRATE",
    execution_mode = "live_acceptance_probe",
    passed = TRUE,
    observed_count = vapply(resource_names, function(name) as.integer(responses[[name]]$count[[1L]]), integer(1)),
    observed_stages = vapply(resource_names, function(name) as.character(responses[[name]]$stages %||% ""), character(1)),
    expectation_sha256 = expectation_result$expectation_sha256,
    live_run_id = decision_id,
    real_key_evidence = TRUE,
    freshness_passed = vapply(resource_names, function(name) isTRUE(responses[[name]]$freshness_passed), logical(1)),
    identity_passed = vapply(resource_names, function(name) isTRUE(responses[[name]]$identity_passed), logical(1)),
    pagination_complete = vapply(resource_names, function(name) isTRUE(responses[[name]]$pagination_complete), logical(1)),
    secret_scan_passed = vapply(resource_names, function(name) isTRUE(responses[[name]]$secret_scan_passed), logical(1)),
    checked_at_utc = now_utc,
    reason_code = "accepted",
    attempt_count = unname(attempts),
    logical_call_count = 1L,
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  decisions <- phase18_capability_decisions()
  auxiliary <- setdiff(names(decisions), resource_names)
  auxiliary_checks <- data.frame(
    schema_version = "phase18-machine-check-v1",
    capability = auxiliary,
    decision = unname(decisions[auxiliary]),
    execution_mode = "live_acceptance_probe",
    passed = TRUE,
    observed_count = NA_integer_,
    observed_stages = "",
    expectation_sha256 = expectation_result$expectation_sha256,
    live_run_id = decision_id,
    real_key_evidence = TRUE,
    freshness_passed = TRUE,
    identity_passed = TRUE,
    pagination_complete = TRUE,
    secret_scan_passed = TRUE,
    checked_at_utc = now_utc,
    reason_code = "accepted",
    attempt_count = 0L,
    logical_call_count = 0L,
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  machine_checks <- phase18_hash_machine_checks(rbind(resource_checks, auxiliary_checks))
  schema_fingerprint <- data.frame(
    schema_version = "phase18-schema-fingerprint-v1",
    resource = resource_names,
    endpoint = unname(endpoints),
    observed = TRUE,
    observed_at_utc = now_utc,
    fingerprint_sha256 = vapply(resource_names, function(name) tolower(as.character(responses[[name]]$fingerprint_sha256[[1L]])), character(1)),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  schema_fingerprint$row_sha256 <- phase18_row_sha256(schema_fingerprint)
  list(
    valid = TRUE,
    reason_code = "accepted",
    machine_checks = machine_checks,
    schema_fingerprint = schema_fingerprint,
    schema_fingerprint_sha256 = phase18_canonical_sha256(schema_fingerprint, key = "resource")
  )
}

phase18_acceptance_snapshot <- function(paths) {
  exists <- file.exists(paths)
  bytes <- lapply(seq_along(paths), function(index) {
    if (exists[[index]]) readBin(paths[[index]], what = "raw", n = file.info(paths[[index]])$size) else raw()
  })
  list(paths = paths, exists = exists, bytes = bytes)
}

phase18_restore_acceptance_snapshot <- function(snapshot) {
  for (index in seq_along(snapshot$paths)) {
    path <- snapshot$paths[[index]]
    if (isTRUE(snapshot$exists[[index]])) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      staged <- tempfile(paste0(".", basename(path), "-restore-"), tmpdir = dirname(path))
      writeBin(snapshot$bytes[[index]], staged)
      if (file.exists(path) || dir.exists(path)) unlink(path, recursive = TRUE, force = TRUE)
      if (!file.rename(staged, path)) stop("Could not restore Phase 18 incumbent: ", path, call. = FALSE)
    } else if (file.exists(path) || dir.exists(path)) {
      unlink(path, recursive = TRUE, force = TRUE)
    }
  }
  invisible(TRUE)
}

phase18_write_acceptance_stage <- function(stage_root, owner_review, edition_expectations, machine_checks, schema_fingerprint, manifest, markdown) {
  dir.create(stage_root, recursive = TRUE, showWarnings = FALSE)
  phase18_write_csv_atomic(owner_review, file.path(stage_root, "provider_terms_review.csv"))
  phase18_write_csv_atomic(edition_expectations, file.path(stage_root, "edition_expectations.csv"))
  phase18_write_csv_atomic(machine_checks, file.path(stage_root, "coverage_matrix.csv"))
  phase18_write_csv_atomic(schema_fingerprint, file.path(stage_root, "schema_fingerprint.csv"))
  phase18_write_csv_atomic(manifest, file.path(stage_root, "acceptance_manifest.csv"))
  phase18_write_text_atomic(markdown, file.path(stage_root, "ACCEPTANCE.md"))
  invisible(stage_root)
}

phase18_probe_result <- function(reason_code, manifest = NULL, idempotent = FALSE, message = "") {
  list(
    accepted = identical(reason_code, "accepted"),
    reason_code = reason_code,
    manifest = manifest,
    idempotent = isTRUE(idempotent),
    message = message
  )
}

#' Run the bounded first-live-acceptance transaction.
phase18_run_live_acceptance_probe <- function(
    evidence_root,
    owner_review,
    edition_expectations,
    transport_fn,
    decision_id,
    now_utc,
    failure_injector = NULL,
    parser_commit_sha = NULL) {
  evidence_root <- normalizePath(evidence_root, winslash = "/", mustWork = TRUE)
  decision_id <- phase18_acceptance_scalar(decision_id, "decision_id")
  now_utc <- phase18_acceptance_scalar(now_utc, "now_utc")
  lock_path <- file.path(evidence_root, ".phase18-acceptance.lock")
  if (file.exists(lock_path) || dir.exists(lock_path)) {
    return(phase18_probe_result("blocked_concurrent_acceptance"))
  }
  if (!dir.create(lock_path, recursive = FALSE, showWarnings = FALSE)) {
    return(phase18_probe_result("blocked_concurrent_acceptance"))
  }
  stage_root <- tempfile(".phase18-acceptance-stage-", tmpdir = dirname(evidence_root))
  backup_root <- tempfile(".phase18-acceptance-backup-", tmpdir = dirname(evidence_root))
  dir.create(stage_root, recursive = FALSE, showWarnings = FALSE)
  dir.create(backup_root, recursive = FALSE, showWarnings = FALSE)
  on.exit({
    if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
    if (dir.exists(lock_path) || file.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  incumbent <- tryCatch(phase18_read_acceptance_set(evidence_root), error = function(error) NULL)
  if (is.null(incumbent)) return(phase18_probe_result("schema", message = "Incumbent acceptance set is incomplete"))
  evidence <- tryCatch(
    phase18_build_live_probe_evidence(transport_fn, owner_review, edition_expectations, decision_id, now_utc),
    error = function(error) list(valid = FALSE, reason_code = "coverage", message = conditionMessage(error))
  )
  if (!isTRUE(evidence$valid)) return(phase18_probe_result(evidence$reason_code, message = evidence$message))
  manifest <- phase18_build_acceptance_manifest(
    evidence$machine_checks,
    owner_review,
    edition_expectations,
    evidence$schema_fingerprint,
    decision_id,
    now_utc,
    parser_commit_sha = parser_commit_sha
  )
  if (!isTRUE(manifest$automation_enabled[[1L]])) {
    return(phase18_probe_result(as.character(manifest$reason_code[[1L]]), manifest = manifest))
  }
  incumbent_id <- as.character(incumbent$manifest$decision_id[[1L]])
  if (identical(incumbent_id, decision_id)) {
    if (identical(tolower(as.character(incumbent$manifest$row_sha256[[1L]])), tolower(as.character(manifest$row_sha256[[1L]])))) {
      return(phase18_probe_result("accepted", incumbent$manifest, idempotent = TRUE))
    }
    return(phase18_probe_result("blocked_decision_collision", incumbent$manifest))
  }
  target_paths <- setNames(file.path(evidence_root, phase18_acceptance_file_names()), phase18_acceptance_file_names())
  snapshot <- phase18_acceptance_snapshot(target_paths)
  markdown <- paste0(
    "# UCL Provider Acceptance\n\nDecision: `accepted` (`accepted`).\n\n",
    "Automation enabled: `TRUE`.\n\n",
    "Acceptance was produced by the bounded four-resource live probe and remains subject to the owner-reviewed terms evidence.\n"
  )
  transaction_error <- NULL
  tryCatch({
    phase18_write_acceptance_stage(
      stage_root, owner_review, edition_expectations, evidence$machine_checks,
      evidence$schema_fingerprint, manifest, markdown
    )
    staged <- phase18_read_acceptance_set(stage_root)
    phase18_validate_acceptance_manifest(staged$manifest, staged$machine_checks, staged$owner_review, staged$edition_expectations, staged$schema_fingerprint)
    if (is.function(failure_injector)) failure_injector("before_promotion", 0L, "")
    for (index in seq_along(target_paths)) {
      target <- target_paths[[index]]
      staged_path <- file.path(stage_root, names(target_paths)[[index]])
      backup_path <- file.path(backup_root, names(target_paths)[[index]])
      if (file.exists(target)) {
        if (!file.rename(target, backup_path)) stop("Could not backup Phase 18 incumbent", call. = FALSE)
      }
      if (!file.rename(staged_path, target)) stop("Could not promote Phase 18 acceptance evidence", call. = FALSE)
      if (is.function(failure_injector)) failure_injector(paste0("after_promote_", index), index, target)
    }
    installed <- phase18_read_acceptance_set(evidence_root)
    phase18_validate_acceptance_manifest(installed$manifest, installed$machine_checks, installed$owner_review, installed$edition_expectations, installed$schema_fingerprint)
  }, error = function(error) transaction_error <<- error)
  if (!is.null(transaction_error)) {
    restore_error <- tryCatch({
      phase18_restore_acceptance_snapshot(snapshot)
      NULL
    }, error = function(error) error)
    if (!is.null(restore_error)) stop("Phase 18 acceptance rollback failed: ", conditionMessage(restore_error), call. = FALSE)
    reason <- if (grepl("interrupt", conditionMessage(transaction_error), ignore.case = TRUE)) "interrupted" else "writer_failure"
    return(phase18_probe_result(reason, incumbent$manifest, message = conditionMessage(transaction_error)))
  }
  phase18_probe_result("accepted", manifest)
}

`%||%` <- function(value, fallback) if (is.null(value)) fallback else value

# Canonical-v2 acceptance authority. These definitions intentionally replace the
# v1 constructors above while preserving the public Phase 18 API during the
# durable-evidence migration.

phase18_acceptance_schema_version <- function() "phase18-provider-acceptance-v2"

phase18_acceptance_abort <- function(kind, message) {
  condition <- simpleError(paste0("Phase 18 acceptance ", kind, " error: ", message))
  class(condition) <- c(paste0("phase18_acceptance_", gsub("-", "_", kind)), class(condition))
  stop(condition)
}

phase18_acceptance_utc <- function(value, name) {
  value <- phase18_acceptance_scalar(value, name)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)) {
    phase18_acceptance_abort("integrity", paste0(name, " must be a UTC second timestamp"))
  }
  parsed <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.na(parsed) || !identical(format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), value)) {
    phase18_acceptance_abort("integrity", paste0(name, " is not a real UTC timestamp"))
  }
  value
}

phase18_acceptance_require_schema <- function(data, schema_version, required, label) {
  if (!is.data.frame(data) || !nrow(data)) phase18_acceptance_abort("schema", paste0(label, " is absent"))
  if (!identical(names(data), required)) {
    phase18_acceptance_abort("schema", paste0(label, " columns are not exact"))
  }
  if (any(as.character(data$schema_version) != schema_version)) {
    phase18_acceptance_abort("migration-required", paste0(label, " is not canonical v2"))
  }
  if (any(as.character(data$hash_encoding_version) != phase18_canonical_encoding_v2())) {
    phase18_acceptance_abort("migration-required", paste0(label, " hash encoding is not canonical v2"))
  }
  invisible(data)
}

phase18_acceptance_hash_rows <- function(data, schema_tag, exclude = "row_sha256") {
  phase18_hash_row_v2(data, exclude = intersect(exclude, names(data)), schema_tag = schema_tag)
}

phase18_acceptance_hash_table <- function(data, key, schema_tag, exclude = character()) {
  phase18_hash_table_v2(data, key = key, exclude = intersect(exclude, names(data)), schema_tag = schema_tag)
}

phase18_hash_terms_review <- function(review) {
  if (!is.data.frame(review) || !nrow(review)) stop("Phase 18 terms review must be a non-empty data frame", call. = FALSE)
  review$schema_version <- "phase18-provider-terms-review-v2"
  review$hash_encoding_version <- phase18_canonical_encoding_v2()
  if (!"review_id" %in% names(review)) {
    seed <- phase18_acceptance_hash_table(
      review, key = c("provider_id", "dimension"),
      schema_tag = "phase18-provider-terms-review-id-v2"
    )
    review$review_id <- paste0("terms-review-", substr(seed, 1L, 16L))
  }
  preferred <- c(
    "schema_version", "hash_encoding_version", "review_id", "provider_id",
    "application_id", "dimension", "status", "terms_url", "terms_sha256",
    "reviewer", "reviewed_at_utc", "requirement", "disposition", "notes"
  )
  missing <- setdiff(preferred, names(review))
  if (length(missing)) stop("Phase 18 terms review constructor missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  review <- review[, preferred, drop = FALSE]
  review$row_sha256 <- phase18_acceptance_hash_rows(review, "phase18-provider-terms-review-row-v2")
  review
}

phase18_validate_terms_review <- function(review) {
  rejected <- function(decision = "manual_only", reason_code = "terms", message = "Owner review is incomplete", review_sha256 = "") {
    list(valid = FALSE, decision = decision, reason_code = reason_code, message = message, review_sha256 = review_sha256)
  }
  required <- c(
    "schema_version", "hash_encoding_version", "review_id", "provider_id",
    "application_id", "dimension", "status", "terms_url", "terms_sha256",
    "reviewer", "reviewed_at_utc", "requirement", "disposition", "notes", "row_sha256"
  )
  if (!is.data.frame(review) || !nrow(review)) return(rejected())
  result <- tryCatch({
    phase18_acceptance_require_schema(review, "phase18-provider-terms-review-v2", required, "owner review")
    if (nrow(review) != length(phase18_owner_review_dimensions()) || anyDuplicated(as.character(review$dimension)) ||
        !setequal(as.character(review$dimension), phase18_owner_review_dimensions())) {
      phase18_acceptance_abort("integrity", "owner review dimensions are not exact")
    }
    scoped <- c("review_id", "provider_id", "application_id", "terms_url", "terms_sha256")
    if (any(vapply(review[scoped], function(column) length(unique(as.character(column))) != 1L, logical(1)))) {
      phase18_acceptance_abort("integrity", "owner review scope is inconsistent")
    }
    if (any(!grepl("^[0-9a-fA-F]{64}$", as.character(review$terms_sha256)))) {
      phase18_acceptance_abort("integrity", "owner review terms hash is invalid")
    }
    invisible(lapply(as.character(review$reviewed_at_utc), phase18_acceptance_utc, name = "reviewed_at_utc"))
    expected <- phase18_acceptance_hash_rows(review, "phase18-provider-terms-review-row-v2")
    if (!identical(tolower(as.character(review$row_sha256)), expected)) {
      phase18_acceptance_abort("integrity", "owner review row hash mismatch")
    }
    hash <- phase18_acceptance_hash_table(review, "dimension", "phase18-provider-terms-review-table-v2")
    statuses <- tolower(as.character(review$status))
    if (any(!statuses %in% c("approved", "pending", "rejected"))) phase18_acceptance_abort("integrity", "owner review status is unsupported")
    if (any(statuses == "rejected")) return(rejected("rejected", "terms", "Owner review rejected", hash))
    if (any(statuses != "approved")) return(rejected("manual_only", "terms", "Owner review is pending", hash))
    placeholders <- c("pending_owner_review", "fixture-reviewer", "unknown", "todo", "tbd")
    if (any(tolower(trimws(as.character(review$reviewer))) %in% placeholders)) {
      return(rejected("manual_only", "terms", "Owner review requires a non-placeholder reviewer", hash))
    }
    list(valid = TRUE, decision = "accepted", reason_code = "accepted", message = "Owner review approved", review_sha256 = hash)
  }, error = function(error) error)
  if (inherits(result, "error")) {
    if (inherits(result, "phase18_acceptance_migration_required")) return(rejected(message = conditionMessage(result)))
    phase18_acceptance_abort("integrity", conditionMessage(result))
  }
  result
}

phase18_read_terms_review <- function(path) {
  path <- phase18_acceptance_scalar(path, "review_path")
  if (!file.exists(path)) return(NULL)
  review <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if ("review_set" %in% names(review)) {
    phase18_acceptance_abort("schema", "durable owner review cannot contain multiple review sets")
  }
  phase18_validate_terms_review(review)
  review
}

phase18_read_terms_review_fixture <- function(path, review_set) {
  path <- phase18_acceptance_scalar(path, "fixture review_path")
  review_set <- phase18_acceptance_scalar(review_set, "fixture review_set")
  review <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (!"review_set" %in% names(review)) stop("Phase 18 fixture review requires review_set", call. = FALSE)
  selected <- review[as.character(review$review_set) == review_set, setdiff(names(review), "review_set"), drop = FALSE]
  if (!nrow(selected)) stop("Phase 18 fixture review set is absent", call. = FALSE)
  phase18_hash_terms_review(selected)
}

phase18_hash_edition_expectations <- function(expectations) {
  if (!is.data.frame(expectations) || nrow(expectations) != 1L) stop("Phase 18 edition expectations require one row", call. = FALSE)
  expectations$schema_version <- "phase18-edition-expectation-v2"
  expectations$hash_encoding_version <- phase18_canonical_encoding_v2()
  if (!"review_state" %in% names(expectations)) {
    reviewer <- tolower(trimws(as.character(expectations$reviewer)))
    expectations$review_state <- ifelse(reviewer %in% c("pending_owner_review", "", "unknown"), "pending", "approved")
  }
  preferred <- c(
    "schema_version", "hash_encoding_version", "edition_id", "lifecycle",
    "expected_club_count", "expected_league_phase_match_count", "allowed_stages",
    "standings_required", "expected_standings_rows", "review_state", "reviewer",
    "reviewed_at_utc"
  )
  missing <- setdiff(preferred, names(expectations))
  if (length(missing)) stop("Phase 18 expectation constructor missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  expectations <- expectations[, preferred, drop = FALSE]
  expectations$row_sha256 <- phase18_acceptance_hash_rows(
    expectations, "phase18-edition-expectation-row-v2",
    exclude = c("row_sha256", "expectation_sha256")
  )
  expectations$expectation_sha256 <- phase18_acceptance_hash_table(
    expectations, c("edition_id", "lifecycle"), "phase18-edition-expectation-table-v2",
    exclude = "expectation_sha256"
  )
  expectations
}

phase18_validate_edition_expectations <- function(expectations, observed = NULL, lifecycle = NULL) {
  fail <- function(reason_code, message, expectation_sha256 = "") {
    list(valid = FALSE, decision = "rejected", reason_code = reason_code, message = message, expectation_sha256 = expectation_sha256)
  }
  required <- c(
    "schema_version", "hash_encoding_version", "edition_id", "lifecycle",
    "expected_club_count", "expected_league_phase_match_count", "allowed_stages",
    "standings_required", "expected_standings_rows", "review_state", "reviewer",
    "reviewed_at_utc", "row_sha256", "expectation_sha256"
  )
  checked <- tryCatch({
    phase18_acceptance_require_schema(expectations, "phase18-edition-expectation-v2", required, "edition expectations")
    if (nrow(expectations) != 1L || anyDuplicated(expectations[c("edition_id", "lifecycle")])) phase18_acceptance_abort("integrity", "edition expectation cardinality is not exact")
    expected_rows <- phase18_acceptance_hash_rows(
      expectations, "phase18-edition-expectation-row-v2",
      exclude = c("row_sha256", "expectation_sha256")
    )
    if (!identical(tolower(as.character(expectations$row_sha256)), expected_rows)) phase18_acceptance_abort("integrity", "edition expectation row hash mismatch")
    aggregate <- phase18_acceptance_hash_table(expectations, c("edition_id", "lifecycle"), "phase18-edition-expectation-table-v2", exclude = "expectation_sha256")
    if (any(tolower(as.character(expectations$expectation_sha256)) != aggregate)) phase18_acceptance_abort("integrity", "edition expectation aggregate hash mismatch")
    phase18_acceptance_utc(expectations$reviewed_at_utc[[1L]], "reviewed_at_utc")
    list(aggregate = aggregate)
  }, error = function(error) error)
  if (inherits(checked, "error")) return(fail("schema", conditionMessage(checked)))
  aggregate <- checked$aggregate
  exact <- identical(as.character(expectations$edition_id[[1L]]), "ucl_2026_27") &&
    identical(as.character(expectations$lifecycle[[1L]]), "league_phase") &&
    identical(as.integer(expectations$expected_club_count[[1L]]), 36L) &&
    identical(as.integer(expectations$expected_league_phase_match_count[[1L]]), 144L) &&
    isTRUE(as.logical(expectations$standings_required[[1L]])) &&
    identical(as.integer(expectations$expected_standings_rows[[1L]]), 36L)
  if (!exact) return(fail("cardinality", "Only the exact supported UCL 2026/27 league-phase expectation is authoritative", aggregate))
  placeholder <- tolower(trimws(as.character(expectations$reviewer[[1L]]))) %in% c("pending_owner_review", "fixture-reviewer", "unknown", "todo", "tbd", "")
  if (!identical(as.character(expectations$review_state[[1L]]), "approved") || placeholder) {
    return(fail("terms", "Edition expectations require explicit non-placeholder owner approval", aggregate))
  }
  if (!is.null(lifecycle) && !identical(phase18_acceptance_scalar(lifecycle, "lifecycle"), "league_phase")) return(fail("cardinality", "Requested lifecycle expectation is missing", aggregate))
  if (!is.null(observed)) {
    row <- if (is.data.frame(observed)) observed[1L, , drop = FALSE] else as.list(observed)
    value <- function(name, default = NA) if (is.null(row[[name]]) || !length(row[[name]])) default else row[[name]][[1L]]
    if (as.integer(value("club_count")) != 36L || as.integer(value("league_phase_match_count")) != 144L) return(fail("cardinality", "Observed club or schedule cardinality differs from the reviewed expectation", aggregate))
    observed_stages <- unique(trimws(unlist(strsplit(paste(as.character(value("stages", "")), collapse = "|"), "\\|"))))
    allowed <- unique(trimws(unlist(strsplit(as.character(expectations$allowed_stages[[1L]]), "\\|"))))
    if (length(setdiff(observed_stages[nzchar(observed_stages)], allowed))) return(fail("stage", "Observed provider stage is outside the reviewed allowlist", aggregate))
    if (as.integer(value("standings_rows")) != 36L) return(fail("standings", "Observed standings cardinality differs from the reviewed expectation", aggregate))
  }
  list(valid = TRUE, decision = "accepted", reason_code = "accepted", message = "Edition expectations validated", expectation_sha256 = aggregate)
}

phase18_default_edition_expectations <- function(edition_id = "ucl_2026_27", now_utc = "1970-01-01T00:00:00Z") {
  phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = edition_id, lifecycle = "league_phase", expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L,
    review_state = "pending", reviewer = "pending_owner_review", reviewed_at_utc = now_utc,
    stringsAsFactors = FALSE, check.names = FALSE
  ))
}

phase18_capability_evidence_kinds <- function() {
  c(
    competition_metadata = "resource_response", teams = "resource_response",
    matches = "resource_response", standings = "resource_response",
    scorers = "policy_opt_out", head_to_head = "policy_opt_out",
    match_detail = "policy_opt_out", team_detail = "policy_opt_out",
    person_detail = "policy_opt_out", filters = "filter_observation",
    pagination = "pagination_observation", authenticated_headers = "authentication_observation",
    rate_limits = "rate_limit_observation", null_empty_semantics = "null_empty_observation",
    attribution = "attribution_observation", provider_exit = "provider_exit_observation"
  )
}

phase18_machine_evidence_hash <- function(capability, kind, observation, check_count, live_run_id) {
  phase18_hash_sequence_v2(
    list(as.character(capability), as.character(kind), as.character(observation), as.integer(check_count), as.character(live_run_id)),
    domain = "phase18-machine-capability-evidence-v2",
    names = c("capability", "evidence_kind", "evidence_observation", "applicable_check_count", "live_run_id"),
    types = c("character", "character", "character", "integer", "character")
  )
}

phase18_hash_machine_checks <- function(machine_checks) {
  if (!is.data.frame(machine_checks)) stop("Phase 18 machine checks must be a data frame", call. = FALSE)
  machine_checks$schema_version <- "phase18-machine-check-v2"
  machine_checks$hash_encoding_version <- phase18_canonical_encoding_v2()
  preferred <- c(
    "schema_version", "hash_encoding_version", "capability", "decision", "execution_mode",
    "executed", "passed", "evidence_kind", "evidence_observation", "evidence_sha256",
    "applicable_check_count", "observed_count", "observed_stages", "expectation_sha256",
    "live_run_id", "real_key_evidence", "freshness_passed", "identity_passed",
    "pagination_complete", "secret_scan_passed", "checked_at_utc", "reason_code",
    "attempt_count", "logical_call_count"
  )
  defaults <- list(
    executed = FALSE, evidence_kind = "not_run", evidence_observation = "not_executed",
    evidence_sha256 = "not_applicable", applicable_check_count = 0L, attempt_count = 0L,
    logical_call_count = 0L, reason_code = "missing_credential"
  )
  for (name in names(defaults)) if (!name %in% names(machine_checks)) machine_checks[[name]] <- defaults[[name]]
  missing <- setdiff(preferred, names(machine_checks))
  if (length(missing)) stop("Phase 18 machine-check constructor missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  machine_checks <- machine_checks[, preferred, drop = FALSE]
  machine_checks$row_sha256 <- phase18_acceptance_hash_rows(machine_checks, "phase18-machine-check-row-v2")
  machine_checks
}

phase18_default_machine_checks <- function(expectations, now_utc, reason_code = "missing_credential") {
  decisions <- phase18_capability_decisions()
  capabilities <- names(decisions)
  checks <- data.frame(
    schema_version = "phase18-machine-check-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    capability = capabilities, decision = unname(decisions), execution_mode = "not_run",
    executed = FALSE, passed = FALSE, evidence_kind = "not_run",
    evidence_observation = paste0("not_executed:", reason_code), evidence_sha256 = "not_applicable",
    applicable_check_count = 0L, observed_count = NA_integer_, observed_stages = "not_applicable",
    expectation_sha256 = as.character(expectations$expectation_sha256[[1L]]), live_run_id = "not_run",
    real_key_evidence = FALSE, freshness_passed = FALSE, identity_passed = FALSE,
    pagination_complete = FALSE, secret_scan_passed = FALSE, checked_at_utc = now_utc,
    reason_code = reason_code, attempt_count = 0L, logical_call_count = 0L,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase18_hash_machine_checks(checks)
}

phase18_validate_machine_checks <- function(machine_checks) {
  fail <- function(reason_code, message, machine_evidence_sha256 = "") list(valid = FALSE, reason_code = reason_code, message = message, machine_evidence_sha256 = machine_evidence_sha256)
  required <- c(
    "schema_version", "hash_encoding_version", "capability", "decision", "execution_mode",
    "executed", "passed", "evidence_kind", "evidence_observation", "evidence_sha256",
    "applicable_check_count", "observed_count", "observed_stages", "expectation_sha256",
    "live_run_id", "real_key_evidence", "freshness_passed", "identity_passed",
    "pagination_complete", "secret_scan_passed", "checked_at_utc", "reason_code",
    "attempt_count", "logical_call_count", "row_sha256"
  )
  checked <- tryCatch({
    phase18_acceptance_require_schema(machine_checks, "phase18-machine-check-v2", required, "machine checks")
    integer_fields <- c("applicable_check_count", "observed_count", "attempt_count", "logical_call_count")
    logical_fields <- c(
      "executed", "passed", "real_key_evidence", "freshness_passed",
      "identity_passed", "pagination_complete", "secret_scan_passed"
    )
    for (field in integer_fields) machine_checks[[field]] <- as.integer(machine_checks[[field]])
    for (field in logical_fields) machine_checks[[field]] <- as.logical(machine_checks[[field]])
    decisions <- phase18_capability_decisions()
    if (nrow(machine_checks) != length(decisions) || anyDuplicated(as.character(machine_checks$capability)) ||
        !setequal(as.character(machine_checks$capability), names(decisions))) phase18_acceptance_abort("integrity", "machine capability set is not the exact sixteen-row matrix")
    observed_decisions <- setNames(as.character(machine_checks$decision), as.character(machine_checks$capability))
    if (!identical(unname(observed_decisions[names(decisions)]), unname(decisions))) phase18_acceptance_abort("integrity", "machine capability decisions differ from the reviewed matrix")
    expected_rows <- phase18_acceptance_hash_rows(machine_checks, "phase18-machine-check-row-v2")
    if (!identical(tolower(as.character(machine_checks$row_sha256)), expected_rows)) phase18_acceptance_abort("integrity", "machine evidence row hash mismatch")
    if (length(unique(as.character(machine_checks$execution_mode))) != 1L) phase18_acceptance_abort("integrity", "machine execution modes are mixed")
    invisible(lapply(as.character(machine_checks$checked_at_utc), phase18_acceptance_utc, name = "checked_at_utc"))
    kinds <- phase18_capability_evidence_kinds()
    if (any(as.character(machine_checks$evidence_kind) != unname(kinds[as.character(machine_checks$capability)]))) {
      not_run <- as.character(machine_checks$execution_mode) == "not_run"
      if (!all(not_run & as.character(machine_checks$evidence_kind) == "not_run")) phase18_acceptance_abort("integrity", "machine evidence kinds are capability-inappropriate")
    }
    mode <- unique(as.character(machine_checks$execution_mode))[[1L]]
    if (!identical(mode, "not_run")) {
      integrate <- as.character(machine_checks$decision) == "INTEGRATE"
      optout <- !integrate
      if (any(!as.logical(machine_checks$executed[integrate])) || any(!as.logical(machine_checks$passed[integrate])) ||
          any(as.integer(machine_checks$applicable_check_count[integrate]) < 1L) ||
          any(!nzchar(as.character(machine_checks$evidence_observation[integrate])))) phase18_acceptance_abort("integrity", "integrated capabilities require executed evidence")
      expected_evidence <- mapply(
        phase18_machine_evidence_hash,
        machine_checks$capability[integrate], machine_checks$evidence_kind[integrate],
        machine_checks$evidence_observation[integrate], machine_checks$applicable_check_count[integrate],
        machine_checks$live_run_id[integrate], USE.NAMES = FALSE
      )
      if (!identical(tolower(as.character(machine_checks$evidence_sha256[integrate])), expected_evidence)) phase18_acceptance_abort("integrity", "integrated capability evidence hash mismatch")
      if (any(as.logical(machine_checks$executed[optout])) || any(as.integer(machine_checks$applicable_check_count[optout]) != 0L) ||
          any(as.logical(machine_checks$freshness_passed[optout])) || any(as.logical(machine_checks$identity_passed[optout])) ||
          any(as.logical(machine_checks$pagination_complete[optout])) || any(as.logical(machine_checks$secret_scan_passed[optout])) ||
          any(as.character(machine_checks$evidence_observation[optout]) != "not_executed_not_applicable")) {
        phase18_acceptance_abort("integrity", "opt-out capabilities must remain explicitly unexecuted and not applicable")
      }
    } else if (any(as.logical(machine_checks$executed)) || any(as.integer(machine_checks$applicable_check_count) != 0L)) {
      phase18_acceptance_abort("integrity", "not-run machine evidence cannot claim execution")
    }
    hash <- phase18_acceptance_hash_table(machine_checks, "capability", "phase18-machine-check-table-v2")
    list(valid = TRUE, reason_code = "accepted", message = "Machine evidence validated", machine_evidence_sha256 = hash)
  }, error = function(error) error)
  if (inherits(checked, "error")) return(fail("coverage", conditionMessage(checked)))
  checked
}

phase18_hash_schema_fingerprint <- function(fingerprint) {
  fingerprint$schema_version <- "phase18-schema-fingerprint-v2"
  fingerprint$hash_encoding_version <- phase18_canonical_encoding_v2()
  preferred <- c("schema_version", "hash_encoding_version", "resource", "endpoint", "observed", "observed_at_utc", "fingerprint_sha256")
  missing <- setdiff(preferred, names(fingerprint))
  if (length(missing)) stop("Phase 18 schema-fingerprint constructor missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  fingerprint <- fingerprint[, preferred, drop = FALSE]
  fingerprint$row_sha256 <- phase18_acceptance_hash_rows(fingerprint, "phase18-schema-fingerprint-row-v2")
  fingerprint
}

phase18_default_schema_fingerprint <- function(now_utc) {
  resources <- names(phase18_probe_endpoints())
  phase18_hash_schema_fingerprint(data.frame(
    schema_version = "phase18-schema-fingerprint-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    resource = resources, endpoint = unname(phase18_probe_endpoints()), observed = FALSE,
    observed_at_utc = now_utc,
    fingerprint_sha256 = vapply(resources, function(resource) phase18_hash_sequence_v2(
      list("not-run", resource), "phase18-schema-not-run-v2", c("state", "resource"), c("character", "character")
    ), character(1)), stringsAsFactors = FALSE, check.names = FALSE
  ))
}

phase18_validate_schema_fingerprint <- function(fingerprint) {
  required <- c("schema_version", "hash_encoding_version", "resource", "endpoint", "observed", "observed_at_utc", "fingerprint_sha256", "row_sha256")
  phase18_acceptance_require_schema(fingerprint, "phase18-schema-fingerprint-v2", required, "schema fingerprint")
  endpoints <- phase18_probe_endpoints()
  if (nrow(fingerprint) != 4L || anyDuplicated(as.character(fingerprint$resource)) ||
      !setequal(as.character(fingerprint$resource), names(endpoints))) phase18_acceptance_abort("integrity", "schema fingerprint resource set is not exact")
  ordered <- fingerprint[match(names(endpoints), as.character(fingerprint$resource)), , drop = FALSE]
  if (!identical(as.character(ordered$endpoint), unname(endpoints))) phase18_acceptance_abort("integrity", "schema fingerprint endpoints are not exact")
  invisible(lapply(as.character(ordered$observed_at_utc), phase18_acceptance_utc, name = "observed_at_utc"))
  if (any(!grepl("^[0-9a-f]{64}$", tolower(as.character(ordered$fingerprint_sha256))))) phase18_acceptance_abort("integrity", "schema fingerprint digest is invalid")
  expected_rows <- phase18_acceptance_hash_rows(fingerprint, "phase18-schema-fingerprint-row-v2")
  if (!identical(tolower(as.character(fingerprint$row_sha256)), expected_rows)) phase18_acceptance_abort("integrity", "schema fingerprint row hash mismatch")
  list(
    valid = TRUE,
    schema_fingerprint_sha256 = phase18_acceptance_hash_table(fingerprint, "resource", "phase18-schema-fingerprint-table-v2")
  )
}

phase18_manifest_self_hash <- function(manifest) {
  phase18_acceptance_hash_rows(manifest, "phase18-provider-acceptance-manifest-row-v2", exclude = "row_sha256")
}

phase18_build_acceptance_manifest <- function(
    machine_checks,
    owner_review,
    edition_expectations,
    schema_fingerprint,
    decision_id,
    now_utc,
    parser_commit_sha = NULL,
    project_root = ".") {
  decision_id <- phase18_acceptance_scalar(decision_id, "decision_id")
  now_utc <- phase18_acceptance_utc(now_utc, "created_at_utc")
  review_result <- phase18_validate_terms_review(owner_review)
  expectation_result <- phase18_validate_edition_expectations(edition_expectations)
  machine_result <- phase18_validate_machine_checks(machine_checks)
  fingerprint_result <- phase18_validate_schema_fingerprint(schema_fingerprint)
  modes <- unique(as.character(machine_checks$execution_mode))
  execution_mode <- if (length(modes) == 1L) modes[[1L]] else "not_run"
  integrate <- as.character(machine_checks$decision) == "INTEGRATE"
  resources <- as.character(machine_checks$capability) %in% names(phase18_probe_endpoints())
  live_ids <- unique(as.character(machine_checks$live_run_id[integrate]))
  live_id <- if (length(live_ids) == 1L) live_ids[[1L]] else "not_run"
  real_key <- any(integrate) && all(as.logical(machine_checks$real_key_evidence[integrate]))
  bound_expectation <- nzchar(expectation_result$expectation_sha256) &&
    all(tolower(as.character(machine_checks$expectation_sha256)) == tolower(expectation_result$expectation_sha256))
  machine_pass <- isTRUE(machine_result$valid) && all(as.logical(machine_checks$passed[integrate])) &&
    all(as.logical(machine_checks$executed[integrate])) &&
    all(as.logical(machine_checks$freshness_passed[resources])) &&
    all(as.logical(machine_checks$identity_passed[resources])) &&
    all(as.logical(machine_checks$pagination_complete[resources])) &&
    all(as.logical(machine_checks$secret_scan_passed[resources]))
  can_accept <- identical(execution_mode, "live_acceptance_probe") && review_result$valid &&
    expectation_result$valid && machine_pass && real_key && nzchar(live_id) && bound_expectation &&
    all(as.logical(schema_fingerprint$observed))
  offline_passed <- identical(execution_mode, "offline_contract_test") && isTRUE(machine_result$valid) && machine_pass
  if (can_accept) {
    decision <- "accepted"; reason_code <- "accepted"
  } else if (identical(execution_mode, "not_run") && !real_key) {
    decision <- "not_run"; reason_code <- "missing_credential"
  } else if (!review_result$valid && identical(review_result$decision, "rejected")) {
    decision <- "rejected"; reason_code <- review_result$reason_code
  } else if (!review_result$valid || !expectation_result$valid) {
    decision <- "manual_only"; reason_code <- "terms"
  } else if (identical(execution_mode, "offline_contract_test")) {
    decision <- "not_run"; reason_code <- "offline_only"
  } else if (!real_key || !nzchar(live_id)) {
    decision <- "not_run"; reason_code <- "missing_credential"
  } else {
    decision <- "rejected"; reason_code <- if (!machine_result$valid) machine_result$reason_code else "coverage"
  }
  provider_id <- if (nrow(owner_review)) as.character(owner_review$provider_id[[1L]]) else "football_data_org_v4"
  edition_id <- if (nrow(edition_expectations)) as.character(edition_expectations$edition_id[[1L]]) else "ucl_2026_27"
  parser_commit_sha <- if (is.null(parser_commit_sha)) phase18_parser_commit_sha(project_root) else tolower(phase18_acceptance_scalar(parser_commit_sha, "parser_commit_sha"))
  manifest <- data.frame(
    schema_version = phase18_acceptance_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(),
    decision_id = decision_id, provider_id = provider_id, edition_id = edition_id,
    execution_mode = execution_mode, decision = decision, reason_code = reason_code,
    automation_enabled = isTRUE(can_accept), credential_status = if (real_key) "present" else "absent",
    offline_contract_tests_passed = isTRUE(offline_passed),
    live_provider_decision = if (can_accept) "accepted" else if (identical(execution_mode, "live_acceptance_probe")) "rejected" else "not_run",
    live_run_id = live_id, parser_commit_sha = parser_commit_sha,
    review_sha256 = review_result$review_sha256,
    machine_evidence_sha256 = machine_result$machine_evidence_sha256,
    expectation_sha256 = expectation_result$expectation_sha256,
    schema_fingerprint_sha256 = fingerprint_result$schema_fingerprint_sha256,
    created_at_utc = now_utc,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  manifest$row_sha256 <- phase18_manifest_self_hash(manifest)
  manifest
}

phase18_validate_acceptance_manifest <- function(manifest, machine_checks, owner_review, edition_expectations, schema_fingerprint) {
  required <- c(
    "schema_version", "hash_encoding_version", "decision_id", "provider_id", "edition_id",
    "execution_mode", "decision", "reason_code", "automation_enabled", "credential_status",
    "offline_contract_tests_passed", "live_provider_decision", "live_run_id", "parser_commit_sha",
    "review_sha256", "machine_evidence_sha256", "expectation_sha256",
    "schema_fingerprint_sha256", "created_at_utc", "row_sha256"
  )
  phase18_acceptance_require_schema(manifest, phase18_acceptance_schema_version(), required, "acceptance manifest")
  if (nrow(manifest) != 1L) phase18_acceptance_abort("integrity", "acceptance manifest must contain one row")
  rebuilt <- phase18_build_acceptance_manifest(
    machine_checks, owner_review, edition_expectations, schema_fingerprint,
    as.character(manifest$decision_id[[1L]]), as.character(manifest$created_at_utc[[1L]]),
    parser_commit_sha = as.character(manifest$parser_commit_sha[[1L]])
  )
  fields <- setdiff(required, "row_sha256")
  same <- vapply(fields, function(field) identical(
    phase18_canonical_scalar(manifest[[field]]), phase18_canonical_scalar(rebuilt[[field]])
  ), logical(1))
  if (any(!same)) phase18_acceptance_abort("integrity", paste0("manifest differs from recomputed evidence: ", paste(fields[!same], collapse = ", ")))
  if (!identical(tolower(as.character(manifest$row_sha256[[1L]])), phase18_manifest_self_hash(manifest)[[1L]])) {
    phase18_acceptance_abort("integrity", "acceptance manifest row hash mismatch")
  }
  invisible(manifest)
}

phase18_build_live_probe_evidence <- function(
    transport_fn,
    owner_review,
    edition_expectations,
    decision_id,
    now_utc) {
  review_result <- phase18_validate_terms_review(owner_review)
  if (!review_result$valid) return(list(valid = FALSE, reason_code = review_result$reason_code, message = review_result$message))
  expectation_result <- phase18_validate_edition_expectations(edition_expectations)
  if (!expectation_result$valid) return(list(valid = FALSE, reason_code = expectation_result$reason_code, message = expectation_result$message))
  endpoints <- phase18_probe_endpoints()
  responses <- list(); attempts <- integer()
  for (capability in names(endpoints)) {
    called <- phase18_probe_call(transport_fn, capability, max_attempts = 3L)
    response <- called$response
    required <- c("count", "freshness_passed", "identity_passed", "pagination_complete", "secret_scan_passed", "fingerprint_sha256")
    missing <- setdiff(required, names(response))
    if (length(missing)) return(list(valid = FALSE, reason_code = "schema", message = paste("Probe response missing fields:", paste(missing, collapse = ", "))))
    if (!grepl("^[0-9a-fA-F]{64}$", as.character(response$fingerprint_sha256[[1L]]))) return(list(valid = FALSE, reason_code = "schema", message = "Probe schema fingerprint is invalid"))
    responses[[capability]] <- response; attempts[[capability]] <- called$attempts
  }
  observed <- list(
    club_count = as.integer(responses$teams$count[[1L]]),
    league_phase_match_count = as.integer(responses$matches$count[[1L]]),
    stages = as.character(responses$matches$stages %||% ""),
    standings_rows = as.integer(responses$standings$count[[1L]])
  )
  observed_result <- phase18_validate_edition_expectations(edition_expectations, observed, "league_phase")
  if (!observed_result$valid) return(c(list(valid = FALSE), observed_result[c("reason_code", "message")]))
  if (as.integer(responses$competition_metadata$count[[1L]]) != 1L) return(list(valid = FALSE, reason_code = "cardinality", message = "Competition metadata must contain exactly one object"))
  auxiliary_names <- names(phase18_capability_decisions())[phase18_capability_decisions() == "INTEGRATE"]
  auxiliary_names <- setdiff(auxiliary_names, names(endpoints))
  auxiliary <- responses$competition_metadata$capability_evidence
  if (!is.list(auxiliary) || !setequal(names(auxiliary), auxiliary_names) ||
      any(!vapply(auxiliary[auxiliary_names], function(value) length(value) == 1L && !is.na(value) && nzchar(as.character(value)), logical(1)))) {
    return(list(valid = FALSE, reason_code = "coverage", message = "Probe must supply exact capability-specific auxiliary evidence"))
  }
  decisions <- phase18_capability_decisions(); kinds <- phase18_capability_evidence_kinds()
  capabilities <- names(decisions)
  rows <- lapply(capabilities, function(capability) {
    resource <- capability %in% names(endpoints)
    integrate <- identical(unname(decisions[[capability]]), "INTEGRATE")
    observation <- if (resource) {
      paste0("count=", as.integer(responses[[capability]]$count[[1L]]), ";stages=", as.character(responses[[capability]]$stages %||% ""))
    } else if (integrate) as.character(auxiliary[[capability]]) else "not_executed_not_applicable"
    check_count <- if (resource) 5L else if (integrate) 1L else 0L
    evidence_hash <- if (integrate) {
      phase18_machine_evidence_hash(capability, unname(kinds[[capability]]), observation, check_count, decision_id)
    } else "not_applicable"
    response <- if (resource) responses[[capability]] else NULL
    data.frame(
      schema_version = "phase18-machine-check-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
      capability = capability, decision = unname(decisions[[capability]]), execution_mode = "live_acceptance_probe",
      executed = integrate, passed = TRUE, evidence_kind = unname(kinds[[capability]]),
      evidence_observation = observation, evidence_sha256 = evidence_hash,
      applicable_check_count = check_count,
      observed_count = if (resource) as.integer(response$count[[1L]]) else NA_integer_,
      observed_stages = if (resource) {
        stages <- as.character(response$stages %||% "")
        if (nzchar(stages)) stages else "not_applicable"
      } else "not_applicable",
      expectation_sha256 = expectation_result$expectation_sha256, live_run_id = decision_id,
      real_key_evidence = integrate,
      freshness_passed = if (resource) isTRUE(response$freshness_passed) else FALSE,
      identity_passed = if (resource) isTRUE(response$identity_passed) else FALSE,
      pagination_complete = if (resource) isTRUE(response$pagination_complete) else FALSE,
      secret_scan_passed = if (resource) isTRUE(response$secret_scan_passed) else FALSE,
      checked_at_utc = now_utc, reason_code = "accepted",
      attempt_count = if (resource) as.integer(attempts[[capability]]) else 0L,
      logical_call_count = if (resource) 1L else if (integrate) 1L else 0L,
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  machine_checks <- phase18_hash_machine_checks(do.call(rbind, rows))
  schema_fingerprint <- phase18_hash_schema_fingerprint(data.frame(
    schema_version = "phase18-schema-fingerprint-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    resource = names(endpoints), endpoint = unname(endpoints), observed = TRUE, observed_at_utc = now_utc,
    fingerprint_sha256 = vapply(names(endpoints), function(name) tolower(as.character(responses[[name]]$fingerprint_sha256[[1L]])), character(1)),
    stringsAsFactors = FALSE, check.names = FALSE
  ))
  fingerprint_result <- phase18_validate_schema_fingerprint(schema_fingerprint)
  list(
    valid = TRUE, reason_code = "accepted", machine_checks = machine_checks,
    schema_fingerprint = schema_fingerprint,
    schema_fingerprint_sha256 = fingerprint_result$schema_fingerprint_sha256
  )
}
