#' Phase 11 manually frozen external-market reference mode

.phase11_market_root <- function(path = ".") {
  if (exists(".phase11_protocol_root", mode = "function")) {
    return(.phase11_protocol_root(path))
  }
  candidate <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Could not locate the xGelo project root", call. = FALSE)
    candidate <- parent
  }
}

.phase11_market_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Manual market snapshot path must be one non-empty local path", call. = FALSE)
  }
  if (grepl("^(https?|ftp|file)://", path, ignore.case = TRUE) ||
      grepl("(^|[[:space:]_/.-])(curl|wget|scrap(e|ing)?|httr|live[_ -]?collect)", path, ignore.case = TRUE)) {
    stop("Manual market snapshot must be a local frozen file; live collection paths are forbidden", call. = FALSE)
  }
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) normalizePath(path, mustWork = FALSE) else file.path(.phase11_market_root("."), path)
}

.phase11_market_required_columns <- function() {
  if (exists(".phase11_manual_market_manifest_columns", mode = "function")) {
    return(.phase11_manual_market_manifest_columns())
  }
  c(
    "snapshot_id", "fixture_id", "home_team_id", "away_team_id", "market_date",
    "captured_at_utc", "source_name", "source_url_or_label", "license_class",
    "redistribution_allowed", "manual_freeze_operator", "p_home", "p_draw", "p_away",
    "source_sha256", "row_sha256", "active_status"
  )
}

.phase11_market_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value[value == "TRUE"] <- "true"
  value[value == "FALSE"] <- "false"
  value
}

.phase11_market_row_hash <- function(data, hash_col = "row_sha256") {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    if (exists("benchmark_contract_sha256", mode = "function")) {
      return(benchmark_contract_sha256(vapply(
        data[index, fields, drop = FALSE], .phase11_market_scalar, character(1)
      )))
    }
    if (!requireNamespace("digest", quietly = TRUE)) {
      stop("digest is required for manual market validation", call. = FALSE)
    }
    digest::digest(
      paste(vapply(data[index, fields, drop = FALSE], .phase11_market_scalar, character(1)), collapse = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
}

.phase11_market_empty_snapshot <- function() {
  result <- as.data.frame(
    setNames(lapply(.phase11_market_required_columns(), function(...) character()), .phase11_market_required_columns()),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  attr(result, "active_status") <- "inactive"
  attr(result, "inactive_reason") <- "manual market snapshot absent; external mode remains inactive"
  class(result) <- c("phase11_manual_market_snapshot", class(result))
  result
}

.phase11_market_bool <- function(value, label) {
  if (is.logical(value)) parsed <- value else {
    normalized <- tolower(trimws(as.character(value)))
    parsed <- ifelse(normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA))
  }
  if (length(parsed) != 1L || is.na(parsed)) stop(label, " must be true or false", call. = FALSE)
  parsed
}

.phase11_market_timestamp <- function(value) {
  value <- trimws(as.character(value))
  value <- sub("Z$", "", value, ignore.case = TRUE)
  parsed <- suppressWarnings(as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
  if (is.na(parsed)) parsed <- suppressWarnings(as.POSIXct(value, tz = "UTC"))
  parsed
}

.phase11_market_live_text <- function(value) {
  grepl(
    "(^|[^a-z])(curl|wget|scrap(e|ing)?|live([_-]|[[:space:]])*(market|odds|collect|feed)|automated([_-]|[[:space:]])*(collect|scrap)|httr|websocket|json([_-]|[[:space:]])*endpoint)([^a-z]|$)",
    as.character(value), ignore.case = TRUE
  )
}

.phase11_market_normalize <- function(snapshot) {
  snapshot <- as.data.frame(snapshot, stringsAsFactors = FALSE, check.names = FALSE)
  if ("market_date" %in% names(snapshot)) snapshot$market_date <- suppressWarnings(as.Date(snapshot$market_date))
  if ("redistribution_allowed" %in% names(snapshot)) {
    normalized <- tolower(trimws(as.character(snapshot$redistribution_allowed)))
    snapshot$redistribution_allowed <- ifelse(
      normalized == "true", TRUE, ifelse(normalized == "false", FALSE, NA)
    )
  }
  snapshot
}

#' Validate a manually frozen 1X2 market snapshot.
#'
#' The validator accepts only local, manually supplied probabilities and
#' metadata.  It never follows URLs, invokes a collector, or reconstructs
#' implied team ability.  Empty snapshots are a valid inactive state.
#' @export
validate_manual_market_snapshot <- function(
    snapshot,
    fixture_cutoffs = NULL,
    snapshot_path = NULL,
    allow_empty = TRUE,
    cutoff_date = NULL
) {
  if (!is.data.frame(snapshot)) stop("Manual market snapshot must be a data frame", call. = FALSE)
  required <- .phase11_market_required_columns()
  missing <- setdiff(required, names(snapshot))
  if (length(missing)) stop("Manual market snapshot missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(snapshot)) {
    if (!isTRUE(allow_empty)) stop("Manual market snapshot has no rows", call. = FALSE)
    return(invisible(snapshot))
  }

  forbidden_columns <- setdiff(
    names(snapshot)[grepl("(^|[_-])raw|bookmaker[_ -]?row|(^|[_-])(odds|price)|(^|[_-])player|payload|html|json", names(snapshot), ignore.case = TRUE)],
    c("source_sha256", "row_sha256")
  )
  if (length(forbidden_columns)) {
    stop("Manual market snapshot contains raw or restricted source fields: ", paste(forbidden_columns, collapse = ", "), call. = FALSE)
  }
  character_fields <- names(snapshot)[vapply(snapshot, function(value) is.character(value), logical(1))]
  if (length(character_fields) && any(vapply(
    snapshot[character_fields], function(value) any(.phase11_market_live_text(value)), logical(1)
  ))) {
    stop("Manual market snapshot contains a live collection or scraping path", call. = FALSE)
  }

  snapshot <- .phase11_market_normalize(snapshot)
  key_fields <- c("snapshot_id", "fixture_id", "home_team_id", "away_team_id", "source_name", "source_url_or_label", "license_class", "manual_freeze_operator", "active_status")
  for (field in key_fields) {
    values <- trimws(as.character(snapshot[[field]]))
    if (any(is.na(values) | !nzchar(values))) stop("Manual market snapshot has missing ", field, call. = FALSE)
  }
  if (anyDuplicated(snapshot[c("snapshot_id", "fixture_id")])) {
    stop("Manual market snapshot contains duplicate snapshot/fixture keys", call. = FALSE)
  }
  if (any(!tolower(as.character(snapshot$active_status)) %in% c("active", "inactive"))) {
    stop("Manual market snapshot active_status must be active or inactive", call. = FALSE)
  }
  if (any(!is.finite(as.numeric(snapshot$market_date)))) stop("Manual market snapshot has missing market_date", call. = FALSE)
  captured <- do.call(c, lapply(snapshot$captured_at_utc, .phase11_market_timestamp))
  if (length(captured) != nrow(snapshot) || any(is.na(captured))) {
    stop("Manual market snapshot has a missing or invalid captured timestamp", call. = FALSE)
  }
  redistribution <- vapply(snapshot$redistribution_allowed, .phase11_market_bool, logical(1), label = "redistribution_allowed")
  snapshot$redistribution_allowed <- redistribution
  probabilities <- lapply(snapshot[c("p_home", "p_draw", "p_away")], function(value) suppressWarnings(as.numeric(value)))
  if (any(vapply(probabilities, function(value) any(!is.finite(value) | value < 0 | value > 1), logical(1)))) {
    stop("Manual market probabilities must be finite values between 0 and 1", call. = FALSE)
  }
  probability_sum <- probabilities[[1L]] + probabilities[[2L]] + probabilities[[3L]]
  if (any(abs(probability_sum - 1) > 1e-8)) stop("Manual market probabilities must be normalized to sum to one", call. = FALSE)
  if (any(!grepl("^[0-9a-f]{64}$", tolower(as.character(snapshot$source_sha256)))) ||
      any(!grepl("^[0-9a-f]{64}$", tolower(as.character(snapshot$row_sha256))))) {
    stop("Manual market source and row checksums must be canonical SHA-256", call. = FALSE)
  }
  if (!is.null(snapshot_path)) {
    path <- .phase11_market_path(snapshot_path)
    if (!file.exists(path)) stop("Manual market snapshot file is missing: ", path, call. = FALSE)
    if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for manual market checksums", call. = FALSE)
    expected_source <- digest::digest(path, algo = "sha256", file = TRUE)
    if (any(tolower(as.character(snapshot$source_sha256)) != tolower(expected_source))) {
      stop("Manual market source checksum mismatch", call. = FALSE)
    }
  }

  if (!is.null(fixture_cutoffs)) {
    if (!is.data.frame(fixture_cutoffs) || !all(c("fixture_id", "evidence_cutoff_exclusive") %in% names(fixture_cutoffs))) {
      stop("fixture_cutoffs must contain fixture_id and evidence_cutoff_exclusive", call. = FALSE)
    }
    fixture_cutoffs$fixture_id <- as.character(fixture_cutoffs$fixture_id)
    fixture_cutoffs$evidence_cutoff_exclusive <- suppressWarnings(as.Date(fixture_cutoffs$evidence_cutoff_exclusive))
    if (anyDuplicated(fixture_cutoffs$fixture_id) || any(is.na(fixture_cutoffs$evidence_cutoff_exclusive))) {
      stop("fixture_cutoffs contains duplicate or invalid cutoff rows", call. = FALSE)
    }
    matched <- match(as.character(snapshot$fixture_id), fixture_cutoffs$fixture_id)
    if (anyNA(matched)) stop("Manual market snapshot contains a fixture without a registered cutoff", call. = FALSE)
    cutoffs <- fixture_cutoffs$evidence_cutoff_exclusive[matched]
    if (any(as.Date(snapshot$market_date) >= cutoffs) || any(as.Date(captured) >= cutoffs)) {
      stop("Manual market snapshot contains post-cutoff market evidence", call. = FALSE)
    }
  } else if (!is.null(cutoff_date)) {
    cutoff <- as.POSIXct(suppressWarnings(as.Date(cutoff_date)), tz = "UTC")
    if (length(cutoff) != 1L || is.na(cutoff) || any(as.Date(snapshot$market_date) >= as.Date(cutoff)) || any(captured >= cutoff)) {
      stop("Manual market snapshot contains post-cutoff market evidence", call. = FALSE)
    }
  }

  expected_rows <- .phase11_market_row_hash(snapshot)
  if (any(tolower(as.character(snapshot$row_sha256)) != expected_rows)) {
    stop("Manual market row checksum mismatch", call. = FALSE)
  }
  invisible(snapshot)
}

#' Read the optional local manual market snapshot.
#' @export
read_manual_market_snapshot <- function(
    snapshot_path = "data/manual/bookmaker/phase11_manual_market_snapshot.csv",
    fixture_cutoffs = NULL,
    allow_missing = TRUE
) {
  path <- .phase11_market_path(snapshot_path)
  if (!file.exists(path)) {
    if (isTRUE(allow_missing)) return(.phase11_market_empty_snapshot())
    stop("Manual market snapshot file is missing: ", path, call. = FALSE)
  }
  snapshot <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"
  )
  snapshot <- .phase11_market_normalize(snapshot)
  validate_manual_market_snapshot(snapshot, fixture_cutoffs = fixture_cutoffs, snapshot_path = path, allow_empty = FALSE)
  attr(snapshot, "active_status") <- if (nrow(snapshot)) "active" else "inactive"
  attr(snapshot, "inactive_reason") <- if (nrow(snapshot)) "" else "manual market snapshot contains no active rows"
  class(snapshot) <- c("phase11_manual_market_snapshot", class(snapshot))
  snapshot
}

#' Validate the durable manual-market manifest.
#' @export
validate_manual_market_manifest <- function(manifest) {
  if (!is.data.frame(manifest)) stop("Manual market manifest must be a data frame", call. = FALSE)
  required <- .phase11_market_required_columns()
  missing <- setdiff(required, names(manifest))
  if (length(missing)) stop("Manual market manifest missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(manifest)) return(invisible(manifest))
  status <- tolower(as.character(manifest$active_status))
  if (any(!status %in% c("active", "inactive"))) stop("Manual market manifest active_status is invalid", call. = FALSE)
  active <- manifest[status == "active", , drop = FALSE]
  if (nrow(active)) validate_manual_market_snapshot(active, allow_empty = FALSE)
  inactive <- manifest[status == "inactive", , drop = FALSE]
  if (nrow(inactive)) {
    nonempty <- vapply(seq_len(nrow(inactive)), function(index) {
      any(nzchar(trimws(as.character(inactive[index, setdiff(required, "active_status"), drop = TRUE]))))
    }, logical(1))
    if (any(nonempty)) validate_manual_market_snapshot(inactive[nonempty, , drop = FALSE], allow_empty = FALSE)
  }
  invisible(manifest)
}

.phase11_empty_market_predictions <- function() {
  result <- data.frame(
    schema_version = character(), model_id = character(), mode_id = character(), panel_id = character(),
    fixture_id = character(), home_team_id = character(), away_team_id = character(), market_date = as.Date(character()),
    captured_at_utc = character(), p_home = numeric(), p_draw = numeric(), p_away = numeric(),
    source_name = character(), source_url_or_label = character(), license_class = character(),
    redistribution_allowed = logical(), manual_freeze_operator = character(), source_sha256 = character(),
    source_row_sha256 = character(), active_status = character(), open_mode_compatible = logical(),
    promotion_boundary = character(), prediction_status = character(), research_only = logical(),
    wc2026_sealed = logical(), stringsAsFactors = FALSE, check.names = FALSE
  )
  attr(result, "active_status") <- "inactive"
  attr(result, "inactive_reason") <- "manual market snapshot absent; external mode remains inactive"
  result
}

#' Convert manually frozen market probabilities into labelled reference rows.
#'
#' The output intentionally has no score distribution or implied-ability fields:
#' it is a 1X2 external reference, never an open-mode candidate.
#' @export
market_probabilities_to_benchmark_predictions <- function(
    snapshot,
    fixture_cutoffs = NULL,
    cutoff_date = NULL
) {
  validate_manual_market_snapshot(
    snapshot,
    fixture_cutoffs = fixture_cutoffs,
    cutoff_date = cutoff_date
  )
  if (!nrow(snapshot)) return(.phase11_empty_market_predictions())
  snapshot <- .phase11_market_normalize(snapshot)
  active <- tolower(as.character(snapshot$active_status)) == "active"
  snapshot <- snapshot[active, , drop = FALSE]
  if (!nrow(snapshot)) return(.phase11_empty_market_predictions())
  data.frame(
    schema_version = "phase11-external-market-reference-v1",
    model_id = "external_market_manual_consensus_v1",
    mode_id = "external_market",
    panel_id = "external_reference",
    fixture_id = as.character(snapshot$fixture_id),
    home_team_id = as.character(snapshot$home_team_id),
    away_team_id = as.character(snapshot$away_team_id),
    market_date = as.Date(snapshot$market_date),
    captured_at_utc = as.character(snapshot$captured_at_utc),
    p_home = as.numeric(snapshot$p_home),
    p_draw = as.numeric(snapshot$p_draw),
    p_away = as.numeric(snapshot$p_away),
    source_name = as.character(snapshot$source_name),
    source_url_or_label = as.character(snapshot$source_url_or_label),
    license_class = as.character(snapshot$license_class),
    redistribution_allowed = as.logical(snapshot$redistribution_allowed),
    manual_freeze_operator = as.character(snapshot$manual_freeze_operator),
    source_sha256 = as.character(snapshot$source_sha256),
    source_row_sha256 = as.character(snapshot$row_sha256),
    active_status = "active",
    open_mode_compatible = FALSE,
    promotion_boundary = "external_reference_only",
    prediction_status = "reference_only",
    research_only = TRUE,
    wc2026_sealed = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}
