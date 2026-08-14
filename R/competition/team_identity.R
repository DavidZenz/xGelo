#' Phase 13 stable team identity and visible normalized-name fallback.

phase13_team_identity_required_columns <- function() {
  c(
    "team_id", "fifa_code", "canonical_name", "aliases",
    "uefa_source_team_id", "uefa_display_name_current"
  )
}

phase13_team_identity_registry_required_columns <- function() {
  c(
    "schema_version", "team_id", "fifa_code", "canonical_name", "aliases",
    "normalized_alias", "uefa_source_team_id", "uefa_display_name_current",
    "mapping_method", "mapping_warning", "alias_review_state", "source_bundle_id",
    "row_sha256"
  )
}

phase13_team_identity_allowed_mapping_methods <- function() {
  c("source_id", "normalized_display_name")
}

phase13_team_identity_allowed_review_states <- function() {
  c("not_required", "reviewed", "pending_review")
}

phase13_normalize_team_name <- function(value) {
  value <- as.character(value)
  output <- rep(NA_character_, length(value))
  present <- !is.na(value)
  if (any(present)) {
    transliterated <- iconv(trimws(value[present]), from = "", to = "ASCII//TRANSLIT", sub = "")
    transliterated <- tolower(transliterated)
    transliterated <- gsub("[^a-z0-9]+", " ", transliterated)
    output[present] <- trimws(gsub("[[:space:]]+", " ", transliterated))
  }
  output
}

phase13_identity_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- as.character(value[[1L]])
  if (!allow_empty && !nzchar(value)) stop("Phase 13 ", name, " must not be empty", call. = FALSE)
  value
}

phase13_prepare_team_identity_map <- function(identity_map) {
  required <- phase13_team_identity_required_columns()
  if (!is.data.frame(identity_map)) stop("Phase 13 team identity map must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(identity_map))
  if (length(missing)) stop("Phase 13 team identity map missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(identity_map)) {
    identity_map$normalized_alias <- character(0)
    return(identity_map)
  }
  identity_map$team_id <- as.character(identity_map$team_id)
  identity_map$fifa_code <- as.character(identity_map$fifa_code)
  identity_map$canonical_name <- as.character(identity_map$canonical_name)
  identity_map$aliases <- as.character(identity_map$aliases)
  identity_map$uefa_source_team_id <- as.character(identity_map$uefa_source_team_id)
  identity_map$uefa_display_name_current <- as.character(identity_map$uefa_display_name_current)
  if (any(is.na(identity_map$team_id) | !nzchar(identity_map$team_id)) ||
      any(is.na(identity_map$fifa_code) | !nzchar(identity_map$fifa_code)) ||
      any(is.na(identity_map$canonical_name) | !nzchar(identity_map$canonical_name)) ||
      any(is.na(identity_map$uefa_source_team_id) | !nzchar(identity_map$uefa_source_team_id)) ||
      any(is.na(identity_map$uefa_display_name_current) | !nzchar(identity_map$uefa_display_name_current))) {
    stop("Phase 13 team identity map contains incomplete stable identity", call. = FALSE)
  }
  if (anyDuplicated(identity_map$team_id)) stop("Phase 13 team identity map has duplicate team IDs", call. = FALSE)
  if (anyDuplicated(identity_map$fifa_code)) stop("Phase 13 team identity map has duplicate FIFA codes", call. = FALSE)
  if (anyDuplicated(identity_map$uefa_source_team_id)) stop("Phase 13 team identity map has duplicate UEFA source IDs", call. = FALSE)

  if (!"schema_version" %in% names(identity_map)) identity_map$schema_version <- "phase13-team-identity-v1"
  if (!"source_bundle_id" %in% names(identity_map)) identity_map$source_bundle_id <- NA_character_
  if (!"mapping_method" %in% names(identity_map)) identity_map$mapping_method <- "source_id"
  if (!"mapping_warning" %in% names(identity_map)) identity_map$mapping_warning <- "none"
  if (!"alias_review_state" %in% names(identity_map)) identity_map$alias_review_state <- "not_required"
  identity_map$source_bundle_id <- as.character(identity_map$source_bundle_id)
  identity_map$mapping_method <- as.character(identity_map$mapping_method)
  identity_map$mapping_warning <- as.character(identity_map$mapping_warning)
  identity_map$alias_review_state <- as.character(identity_map$alias_review_state)

  normalized_aliases <- vapply(seq_len(nrow(identity_map)), function(index) {
    aliases <- c(
      identity_map$canonical_name[[index]],
      identity_map$uefa_display_name_current[[index]],
      if (is.na(identity_map$aliases[[index]])) character(0) else
        unlist(strsplit(identity_map$aliases[[index]], "\\|", fixed = FALSE), use.names = FALSE)
    )
    aliases <- unique(phase13_normalize_team_name(aliases))
    aliases <- aliases[!is.na(aliases) & nzchar(aliases)]
    paste(aliases, collapse = "|")
  }, character(1))
  identity_map$normalized_alias <- normalized_aliases
  identity_map
}

phase13_identity_alias_rows <- function(identity_map) {
  rows <- lapply(seq_len(nrow(identity_map)), function(index) {
    aliases <- unlist(strsplit(as.character(identity_map$normalized_alias[[index]]), "\\|", fixed = FALSE), use.names = FALSE)
    aliases <- unique(aliases[!is.na(aliases) & nzchar(aliases)])
    data.frame(
      team_id = as.character(identity_map$team_id[[index]]),
      normalized_alias = aliases,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) return(data.frame(team_id = character(0), normalized_alias = character(0), stringsAsFactors = FALSE))
  do.call(rbind, rows)
}

phase13_identity_result <- function(candidate, source_team_id, source_display_name, method, warning, review_state, normalized_alias) {
  output <- data.frame(
    schema_version = "phase13-team-identity-resolution-v1",
    team_id = as.character(candidate$team_id[[1L]]),
    fifa_code = as.character(candidate$fifa_code[[1L]]),
    canonical_name = as.character(candidate$canonical_name[[1L]]),
    aliases = as.character(candidate$aliases[[1L]]),
    uefa_source_team_id = as.character(candidate$uefa_source_team_id[[1L]]),
    uefa_display_name_current = as.character(candidate$uefa_display_name_current[[1L]]),
    source_bundle_id = if ("source_bundle_id" %in% names(candidate)) as.character(candidate$source_bundle_id[[1L]]) else NA_character_,
    source_team_id = if (is.null(source_team_id) || is.na(source_team_id)) NA_character_ else as.character(source_team_id),
    source_display_name = as.character(source_display_name),
    normalized_alias = as.character(normalized_alias),
    mapping_method = method,
    mapping_warning = warning,
    alias_review_state = review_state,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output$row_sha256 <- phase13_identity_row_hash(output)
  output
}

#' Resolve direct UEFA IDs first, then deterministic normalized aliases.
phase13_resolve_team_identity <- function(identity_map, source_team_id = NA_character_, display_name) {
  identity_map <- phase13_prepare_team_identity_map(identity_map)
  display_name <- phase13_identity_scalar(display_name, "source display name")
  source_team_id <- if (length(source_team_id) == 0L || is.na(source_team_id) || !nzchar(as.character(source_team_id))) NA_character_ else as.character(source_team_id)

  if (!nrow(identity_map)) stop("Phase 13 cannot resolve a team against an empty identity map", call. = FALSE)

  if (!is.na(source_team_id)) {
    direct <- identity_map[as.character(identity_map$uefa_source_team_id) == source_team_id, , drop = FALSE]
    if (nrow(direct) > 1L) stop("Phase 13 team identity is ambiguous for UEFA source ID: ", source_team_id, call. = FALSE)
    if (nrow(direct) == 1L) {
      return(phase13_identity_result(
        direct, source_team_id, display_name, "source_id", "none", "not_required",
        phase13_normalize_team_name(display_name)
      ))
    }
  }

  normalized <- phase13_normalize_team_name(display_name)
  if (is.na(normalized) || !nzchar(normalized)) stop("Phase 13 team identity has no usable normalized display name", call. = FALSE)
  aliases <- phase13_identity_alias_rows(identity_map)
  matches <- aliases[aliases$normalized_alias == normalized, , drop = FALSE]
  if (nrow(matches) != 1L) {
    if (nrow(matches) > 1L) stop("Phase 13 team identity is ambiguous for normalized display name: ", display_name, call. = FALSE)
    stop("Phase 13 team identity is unresolved for display name: ", display_name, call. = FALSE)
  }
  candidate <- identity_map[as.character(identity_map$team_id) == as.character(matches$team_id[[1L]]), , drop = FALSE]
  warning(
    paste0("Phase 13 team identity used normalized display-name fallback for ", display_name, "; review mapping metadata"),
    call. = FALSE
  )
  phase13_identity_result(
    candidate, source_team_id, display_name, "normalized_display_name",
    "normalized_display_name_requires_review", "pending_review", normalized
  )
}

phase13_normalized_fixture_schema <- function() {
  c(
    "schema_version", "edition_id", "fixture_id", "uefa_source_fixture_id",
    "home_team_id", "away_team_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status",
    "source_artifact_id", "home_mapping_method", "away_mapping_method",
    "home_mapping_warning", "away_mapping_warning", "row_sha256"
  )
}

phase13_empty_normalized_fixture_rows <- function() {
  output <- as.data.frame(setNames(replicate(length(phase13_normalized_fixture_schema()), character(0), simplify = FALSE), phase13_normalized_fixture_schema()), stringsAsFactors = FALSE)
  output$schema_version <- character(0)
  output
}

phase13_normalized_result_schema <- function() {
  c(
    "schema_version", "edition_id", "fixture_id", "uefa_source_fixture_id",
    "home_team_id", "away_team_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status",
    "home_goals", "away_goals", "source_artifact_id", "fixture_source_artifact_id",
    "home_mapping_method", "away_mapping_method", "home_mapping_warning", "away_mapping_warning",
    "row_sha256"
  )
}

phase13_empty_normalized_result_rows <- function() {
  schema <- phase13_normalized_result_schema()
  output <- as.data.frame(setNames(lapply(schema, function(column) {
    if (column %in% c("home_goals", "away_goals")) integer(0) else character(0)
  }), schema), stringsAsFactors = FALSE, check.names = FALSE)
  output
}

phase13_result_goal_value <- function(value, label, index) {
  if (is.null(value) || !length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) {
    return(NA_integer_)
  }
  text <- trimws(as.character(value[[1L]]))
  numeric_value <- suppressWarnings(as.numeric(text))
  if (length(numeric_value) != 1L || is.na(numeric_value) || !is.finite(numeric_value) ||
      numeric_value < 0 || numeric_value != floor(numeric_value)) {
    stop(
      "Phase 13 accepted result row ", index, " has an invalid ", label,
      "; goals must be non-negative whole numbers or both missing",
      call. = FALSE
    )
  }
  as.integer(numeric_value)
}

phase13_result_check_optional_column <- function(results, column, expected, require_present = TRUE) {
  if (!column %in% names(results)) return(invisible(TRUE))
  actual <- as.character(results[[column]])
  expected <- as.character(expected)
  if (length(actual) != length(expected)) {
    stop("Phase 13 accepted result identity column has an unexpected length: ", column, call. = FALSE)
  }
  present <- !is.na(actual) & nzchar(trimws(actual))
  if (isTRUE(require_present) && any(!present)) {
    stop("Phase 13 accepted result identity column contains missing values: ", column, call. = FALSE)
  }
  if (any(present & (is.na(expected) | actual != expected))) {
    stop("Phase 13 accepted result identity or edition mismatch in column: ", column, call. = FALSE)
  }
  invisible(TRUE)
}

#' Normalize source-shaped accepted results through the normalized fixture key.
phase13_normalize_accepted_result_rows <- function(
    results,
    normalized_fixtures,
    edition_id = NULL,
    source_artifact_id = "",
    lifecycle_state = NULL) {
  if (!is.data.frame(results)) stop("Phase 13 accepted result source table must be a data frame", call. = FALSE)
  if (!is.data.frame(normalized_fixtures)) stop("Phase 13 normalized fixture table must be a data frame", call. = FALSE)
  required_results <- c("source_fixture_id", "status", "home_goals", "away_goals")
  missing_results <- setdiff(required_results, names(results))
  if (length(missing_results)) {
    stop("Phase 13 accepted result source table missing columns: ", paste(missing_results, collapse = ", "), call. = FALSE)
  }
  missing_fixtures <- setdiff(phase13_normalized_fixture_schema(), names(normalized_fixtures))
  if (length(missing_fixtures)) {
    stop("Phase 13 normalized fixture table missing columns: ", paste(missing_fixtures, collapse = ", "), call. = FALSE)
  }

  fixture_keys <- as.character(normalized_fixtures$uefa_source_fixture_id)
  if (any(is.na(fixture_keys) | !nzchar(trimws(fixture_keys)))) {
    stop("Phase 13 normalized fixtures require non-empty source fixture keys", call. = FALSE)
  }
  if (anyDuplicated(fixture_keys)) {
    stop("Phase 13 normalized fixtures contain duplicate source fixture keys", call. = FALSE)
  }
  fixture_edition <- NULL
  if (nrow(normalized_fixtures)) {
    fixture_editions <- unique(as.character(normalized_fixtures$edition_id))
    if (!length(fixture_editions) || any(is.na(fixture_editions) | !nzchar(fixture_editions)) || length(fixture_editions) != 1L) {
      stop("Phase 13 normalized fixtures require one explicit edition_id", call. = FALSE)
    }
    fixture_edition <- fixture_editions[[1L]]
  }
  if (is.null(edition_id) && is.null(fixture_edition)) {
    stop("Phase 13 accepted results require an explicit edition_id when normalized fixtures are empty", call. = FALSE)
  }
  edition <- if (is.null(edition_id)) fixture_edition else phase13_identity_scalar(edition_id, "edition_id")
  if (!is.null(fixture_edition) && !identical(edition, fixture_edition)) {
    stop("Phase 13 accepted result edition does not match normalized fixtures", call. = FALSE)
  }
  if (!is.null(lifecycle_state)) {
    lifecycle_state <- phase13_identity_scalar(lifecycle_state, "lifecycle_state")
    if (!lifecycle_state %in% c("pre_draw", "scheduled", "in_progress", "complete")) {
      stop("Phase 13 accepted result normalization received an unsupported lifecycle state", call. = FALSE)
    }
  }

  source_artifact_id <- phase13_identity_scalar(source_artifact_id, "source_artifact_id", allow_empty = TRUE)
  if ("source_artifact_id" %in% names(results) && nrow(results)) {
    result_artifacts <- as.character(results$source_artifact_id)
    supplied_artifacts <- unique(result_artifacts[!is.na(result_artifacts) & nzchar(trimws(result_artifacts))])
    if (!nzchar(source_artifact_id) && length(supplied_artifacts) == 1L) source_artifact_id <- supplied_artifacts[[1L]]
    if (length(supplied_artifacts) > 1L) {
      stop("Phase 13 accepted results contain multiple source artifact IDs", call. = FALSE)
    }
  }

  if (!nrow(results)) return(phase13_empty_normalized_result_rows())
  source_keys <- as.character(results$source_fixture_id)
  if (any(is.na(source_keys) | !nzchar(trimws(source_keys)))) {
    stop("Phase 13 accepted results require non-empty source fixture keys", call. = FALSE)
  }
  if (anyDuplicated(source_keys)) {
    stop("Phase 13 accepted results contain duplicate source fixture keys", call. = FALSE)
  }
  matches <- match(source_keys, fixture_keys)
  if (anyNA(matches)) {
    stop("Phase 13 accepted result references an unknown normalized fixture: ", source_keys[which(is.na(matches))[[1L]]], call. = FALSE)
  }
  fixture_rows <- normalized_fixtures[matches, , drop = FALSE]

  phase13_result_check_optional_column(results, "edition_id", rep(edition, nrow(results)))
  phase13_result_check_optional_column(results, "fixture_id", as.character(fixture_rows$fixture_id))
  phase13_result_check_optional_column(results, "home_team_id", as.character(fixture_rows$home_team_id))
  phase13_result_check_optional_column(results, "away_team_id", as.character(fixture_rows$away_team_id))
  phase13_result_check_optional_column(results, "home_uefa_source_team_id", as.character(fixture_rows$home_uefa_source_team_id))
  phase13_result_check_optional_column(results, "away_uefa_source_team_id", as.character(fixture_rows$away_uefa_source_team_id))
  phase13_result_check_optional_column(results, "home_display_name", as.character(fixture_rows$home_display_name))
  phase13_result_check_optional_column(results, "away_display_name", as.character(fixture_rows$away_display_name))
  phase13_result_check_optional_column(results, "scheduled_at_utc", as.character(fixture_rows$scheduled_at_utc))
  phase13_result_check_optional_column(results, "fixture_source_artifact_id", as.character(fixture_rows$source_artifact_id))
  phase13_result_check_optional_column(results, "source_artifact_id", rep(source_artifact_id, nrow(results)))

  status <- as.character(results$status)
  if (any(is.na(status) | !nzchar(trimws(status)))) {
    stop("Phase 13 accepted results require non-empty status values", call. = FALSE)
  }
  home_goals <- vapply(seq_len(nrow(results)), function(index) {
    phase13_result_goal_value(results$home_goals[[index]], "home_goals", index)
  }, integer(1))
  away_goals <- vapply(seq_len(nrow(results)), function(index) {
    phase13_result_goal_value(results$away_goals[[index]], "away_goals", index)
  }, integer(1))
  if (any(xor(is.na(home_goals), is.na(away_goals)))) {
    stop("Phase 13 accepted result scores must provide both home_goals and away_goals or neither", call. = FALSE)
  }
  score_required_status <- tolower(trimws(status)) %in% c("complete", "completed", "final", "finished", "full_time", "played")
  if (any(score_required_status & is.na(home_goals))) {
    stop("Phase 13 completed accepted results require valid home_goals and away_goals", call. = FALSE)
  }

  output <- data.frame(
    schema_version = rep("phase13-normalized-result-v1", nrow(results)),
    edition_id = rep(edition, nrow(results)),
    fixture_id = as.character(fixture_rows$fixture_id),
    uefa_source_fixture_id = as.character(fixture_rows$uefa_source_fixture_id),
    home_team_id = as.character(fixture_rows$home_team_id),
    away_team_id = as.character(fixture_rows$away_team_id),
    home_uefa_source_team_id = as.character(fixture_rows$home_uefa_source_team_id),
    away_uefa_source_team_id = as.character(fixture_rows$away_uefa_source_team_id),
    home_display_name = as.character(fixture_rows$home_display_name),
    away_display_name = as.character(fixture_rows$away_display_name),
    scheduled_at_utc = as.character(fixture_rows$scheduled_at_utc),
    status = status,
    home_goals = home_goals,
    away_goals = away_goals,
    source_artifact_id = rep(source_artifact_id, nrow(results)),
    fixture_source_artifact_id = as.character(fixture_rows$source_artifact_id),
    home_mapping_method = as.character(fixture_rows$home_mapping_method),
    away_mapping_method = as.character(fixture_rows$away_mapping_method),
    home_mapping_warning = as.character(fixture_rows$home_mapping_warning),
    away_mapping_warning = as.character(fixture_rows$away_mapping_warning),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output$row_sha256 <- phase13_identity_row_hash(output)
  output
}

phase13_identity_row_hash <- function(data) {
  if (exists("phase13_row_sha256", mode = "function")) return(phase13_row_sha256(data))
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 identity hashes", call. = FALSE)
  fields <- setdiff(names(data), "row_sha256")
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], function(value) {
      if (length(value) == 0L || is.na(value[[1L]])) "" else as.character(value[[1L]])
    }, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

phase13_validate_team_identity_registry <- function(identity_registry, source_bundles = NULL) {
  if (!is.data.frame(identity_registry)) stop("Phase 13 team identity registry must be a data frame", call. = FALSE)
  required <- phase13_team_identity_registry_required_columns()
  missing <- setdiff(required, names(identity_registry))
  if (length(missing)) stop("Phase 13 team identity registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(identity_registry)) return(invisible(identity_registry))

  prepared <- phase13_prepare_team_identity_map(identity_registry)
  if (any(is.na(prepared$source_bundle_id) | !nzchar(prepared$source_bundle_id))) {
    stop("Phase 13 team identity registry requires source bundle identity", call. = FALSE)
  }
  if (any(!prepared$mapping_method %in% phase13_team_identity_allowed_mapping_methods())) {
    stop("Phase 13 team identity registry contains an unsupported mapping method", call. = FALSE)
  }
  if (any(!prepared$alias_review_state %in% phase13_team_identity_allowed_review_states())) {
    stop("Phase 13 team identity registry contains an unsupported alias review state", call. = FALSE)
  }
  source_id_rows <- prepared$mapping_method == "source_id"
  if (any(source_id_rows & prepared$mapping_warning != "none")) {
    stop("Phase 13 source-ID mappings must carry a none warning token", call. = FALSE)
  }
  fallback_rows <- prepared$mapping_method == "normalized_display_name"
  if (any(fallback_rows & (is.na(prepared$mapping_warning) | !nzchar(prepared$mapping_warning)))) {
    stop("Phase 13 normalized display-name mappings require visible warning metadata", call. = FALSE)
  }
  aliases <- phase13_identity_alias_rows(prepared)
  if (nrow(aliases)) {
    counts <- aggregate(team_id ~ normalized_alias, aliases, function(values) length(unique(values)))
    if (any(counts$team_id > 1L)) stop("Phase 13 team identity registry contains ambiguous normalized aliases", call. = FALSE)
  }
  if (!is.null(source_bundles)) {
    if (!is.data.frame(source_bundles) || !all(c("bundle_id", "edition_id", "bundle_status") %in% names(source_bundles))) {
      stop("Phase 13 source bundle registry is required to validate team identity provenance", call. = FALSE)
    }
    for (bundle_id in unique(prepared$source_bundle_id)) {
      match <- source_bundles[as.character(source_bundles$bundle_id) == bundle_id, , drop = FALSE]
      if (nrow(match) != 1L || as.character(match$bundle_status[[1L]]) != "accepted") {
        stop("Phase 13 team identity registry references a non-accepted source bundle: ", bundle_id, call. = FALSE)
      }
    }
  }
  actual <- tolower(as.character(identity_registry$row_sha256))
  expected <- phase13_identity_row_hash(identity_registry)
  if (any(is.na(actual) | !grepl("^[0-9a-f]{64}$", actual)) || any(actual != expected)) {
    stop("Phase 13 team identity registry row SHA-256 mismatch", call. = FALSE)
  }
  if (!identical(as.character(identity_registry$normalized_alias), as.character(prepared$normalized_alias))) {
    stop("Phase 13 team identity registry normalized aliases are stale", call. = FALSE)
  }
  invisible(identity_registry)
}

phase13_team_identity_registry_hash <- function(identity_registry) {
  if (!is.data.frame(identity_registry)) stop("Phase 13 team identity registry hash requires a data frame", call. = FALSE)
  if (exists("phase13_canonical_sha256", mode = "function")) {
    return(phase13_canonical_sha256(identity_registry, key = "team_id"))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 identity hashes", call. = FALSE)
  ordered <- identity_registry[order(as.character(identity_registry$team_id)), , drop = FALSE]
  digest::digest(paste(c(names(ordered), capture.output(utils::write.csv(ordered, stdout(), row.names = FALSE))), collapse = "\n"), algo = "sha256", serialize = FALSE)
}

load_phase13_team_identity_registry <- function(
    path = "data/competition/registries/team_identity.csv",
    validate = TRUE,
    source_bundles = NULL,
    source_bundle_path = NULL) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    stop("Phase 13 team identity registry file is missing: ", path, call. = FALSE)
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (isTRUE(validate)) {
    if (is.null(source_bundles)) {
      if (is.null(source_bundle_path)) {
        source_bundle_path <- file.path(dirname(path), "source_bundles.csv")
      }
      if (length(source_bundle_path) != 1L || is.na(source_bundle_path) || !nzchar(source_bundle_path) ||
          !file.exists(source_bundle_path)) {
        stop("Phase 13 adjacent source bundle registry file is missing: ", source_bundle_path, call. = FALSE)
      }
      source_bundles <- utils::read.csv(
        source_bundle_path,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        na.strings = ""
      )
    }
    phase13_validate_team_identity_registry(registry, source_bundles = source_bundles)
  }
  attr(registry, "path") <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!is.null(source_bundle_path)) {
    attr(registry, "source_bundle_path") <- normalizePath(source_bundle_path, winslash = "/", mustWork = TRUE)
  }
  registry
}

validate_team_identity_registry <- phase13_validate_team_identity_registry
validate_phase13_team_identity_registry <- phase13_validate_team_identity_registry
load_team_identity_registry <- load_phase13_team_identity_registry

#' Normalize source-shaped fixture rows without changing source display values.
phase13_normalize_fixture_rows <- function(
    fixtures,
    identity_map,
    edition_id,
    source_artifact_id = "",
    lifecycle_state = NULL) {
  if (!is.data.frame(fixtures)) stop("Phase 13 fixture source table must be a data frame", call. = FALSE)
  required <- c(
    "source_fixture_id", "home_uefa_source_team_id", "away_uefa_source_team_id",
    "home_display_name", "away_display_name", "scheduled_at_utc", "status"
  )
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) stop("Phase 13 fixture source table missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  edition_id <- phase13_identity_scalar(edition_id, "edition_id")
  source_artifact_id <- phase13_identity_scalar(source_artifact_id, "source_artifact_id", allow_empty = TRUE)
  identity_map <- phase13_prepare_team_identity_map(identity_map)
  if (!is.null(lifecycle_state)) {
    lifecycle_state <- phase13_identity_scalar(lifecycle_state, "lifecycle_state")
    if (!lifecycle_state %in% c("pre_draw", "scheduled", "in_progress", "complete")) {
      stop("Phase 13 fixture normalization received an unsupported lifecycle state", call. = FALSE)
    }
    if (!nrow(fixtures) && lifecycle_state != "pre_draw") {
      stop("Phase 13 empty source fixture rows are permitted only for pre_draw editions", call. = FALSE)
    }
  }
  if (!nrow(fixtures)) return(phase13_empty_normalized_fixture_rows())
  if (!nrow(identity_map)) stop("Phase 13 cannot normalize non-empty source fixture rows with an empty identity map", call. = FALSE)

  rows <- lapply(seq_len(nrow(fixtures)), function(index) {
    home <- phase13_resolve_team_identity(
      identity_map,
      fixtures$home_uefa_source_team_id[[index]],
      fixtures$home_display_name[[index]]
    )
    away <- phase13_resolve_team_identity(
      identity_map,
      fixtures$away_uefa_source_team_id[[index]],
      fixtures$away_display_name[[index]]
    )
    if (identical(home$team_id, away$team_id)) stop("Phase 13 fixture cannot contain the same home and away team", call. = FALSE)
    data.frame(
      schema_version = "phase13-normalized-fixture-v1",
      edition_id = edition_id,
      fixture_id = paste(edition_id, fixtures$source_fixture_id[[index]], sep = "-"),
      uefa_source_fixture_id = as.character(fixtures$source_fixture_id[[index]]),
      home_team_id = home$team_id,
      away_team_id = away$team_id,
      home_uefa_source_team_id = home$uefa_source_team_id,
      away_uefa_source_team_id = away$uefa_source_team_id,
      home_display_name = as.character(fixtures$home_display_name[[index]]),
      away_display_name = as.character(fixtures$away_display_name[[index]]),
      scheduled_at_utc = as.character(fixtures$scheduled_at_utc[[index]]),
      status = as.character(fixtures$status[[index]]),
      source_artifact_id = source_artifact_id,
      home_mapping_method = home$mapping_method,
      away_mapping_method = away$mapping_method,
      home_mapping_warning = home$mapping_warning,
      away_mapping_warning = away$mapping_warning,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output$row_sha256 <- phase13_identity_row_hash(output)
  output
}

#' Required source-shaped columns at the martj42 preprocessing boundary.
phase13_martj42_history_required_columns <- function() {
  c(
    "match_id", "date", "home_team", "away_team", "home_score", "away_score",
    "tournament", "neutral"
  )
}

phase13_martj42_identity_map_required_columns <- function() {
  c(
    "identity_map_version", "source_dataset", "source_version",
    "source_input_sha256", "source_artifact_id", "source_identity_key",
    "source_team_id", "source_display_name", "normalized_source_name",
    "team_id", "fifa_code", "canonical_name", "aliases", "mapping_method",
    "mapping_warning", "alias_review_state", "identity_map_sha256", "row_sha256"
  )
}

phase13_normalized_historical_result_schema <- function() {
  c(
    "schema_version", "source_result_id", "match_id", "date", "home_team", "away_team",
    "home_display_name", "away_display_name", "home_source_team_id", "away_source_team_id",
    "home_source_identity_key", "away_source_identity_key", "home_team_id", "away_team_id",
    "home_mapping_method", "away_mapping_method", "home_mapping_warning", "away_mapping_warning",
    "edition_id", "home_score", "away_score", "tournament", "city", "country", "neutral",
    "home_team_canonical", "away_team_canonical", "home_team_fifa", "away_team_fifa",
    "result", "is_home", "score_source", "source_dataset", "source_version",
    "source_input_sha256", "source_artifact_id", "identity_map_version", "identity_map_sha256",
    "edition_lookup_schema_version", "edition_lookup_sha256", "edition_lookup_row_sha256",
    "edition_mapping_method", "row_sha256"
  )
}

phase13_empty_normalized_historical_result_rows <- function() {
  schema <- phase13_normalized_historical_result_schema()
  as.data.frame(
    setNames(lapply(schema, function(column) {
      if (column %in% c("home_score", "away_score", "result")) numeric(0) else character(0)
    }), schema),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase13_martj42_scalar <- function(value, name, allow_empty = FALSE) {
  if (length(value) != 1L || is.null(value) || is.na(value)) {
    stop("Phase 13 martj42 ", name, " must be one non-missing value", call. = FALSE)
  }
  value <- trimws(as.character(value[[1L]]))
  if (!allow_empty && !nzchar(value)) {
    stop("Phase 13 martj42 ", name, " must not be empty", call. = FALSE)
  }
  value
}

phase13_martj42_hash_scalar <- function(value, name) {
  value <- phase13_martj42_scalar(value, name)
  if (!grepl("^[0-9a-fA-F]{64}$", value)) {
    stop("Phase 13 martj42 ", name, " must be a 64-character SHA-256 value", call. = FALSE)
  }
  tolower(value)
}

phase13_martj42_version_scalar <- function(value, name) {
  value <- phase13_martj42_scalar(value, name)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", value)) {
    stop("Phase 13 martj42 ", name, " has malformed version metadata", call. = FALSE)
  }
  value
}

phase13_martj42_column <- function(data, column, n = nrow(data), default = NA_character_) {
  if (column %in% names(data)) return(as.character(data[[column]]))
  rep(default, n)
}

phase13_martj42_source_team_id_column <- function(data, side) {
  candidates <- c(
    paste0(side, "_source_team_id"),
    paste0(side, "_uefa_source_team_id")
  )
  available <- candidates[candidates %in% names(data)]
  if (!length(available)) return(NA_character_)
  available[[1L]]
}

phase13_martj42_clean_optional_id <- function(value) {
  value <- as.character(value)
  value[is.na(value) | !nzchar(trimws(value))] <- NA_character_
  trimws(value)
}

phase13_martj42_source_identity_key <- function(source_team_id, source_display_name) {
  source_team_id <- phase13_martj42_clean_optional_id(source_team_id)
  normalized <- phase13_normalize_team_name(source_display_name)
  ifelse(
    is.na(normalized) | !nzchar(normalized),
    NA_character_,
    ifelse(
      is.na(source_team_id),
      paste0("name:", normalized),
      paste0("id:", source_team_id, "|name:", normalized)
    )
  )
}

phase13_martj42_validate_history_shape <- function(history) {
  if (!is.data.frame(history)) stop("Phase 13 martj42 historical input must be a data frame", call. = FALSE)
  missing <- setdiff(phase13_martj42_history_required_columns(), names(history))
  if (length(missing)) {
    stop("Phase 13 martj42 historical input missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!nrow(history)) stop("Phase 13 martj42 historical input must not be empty", call. = FALSE)
  match_ids <- as.character(history$match_id)
  if (any(is.na(match_ids) | !nzchar(trimws(match_ids)))) {
    stop("Phase 13 martj42 historical input contains missing match_id values", call. = FALSE)
  }
  if (anyDuplicated(match_ids)) {
    stop("Phase 13 martj42 historical input contains duplicate match_id values", call. = FALSE)
  }
  parsed_dates <- as.Date(as.character(history$date))
  if (any(is.na(parsed_dates))) stop("Phase 13 martj42 historical input contains malformed dates", call. = FALSE)
  for (side in c("home", "away")) {
    names_i <- as.character(history[[paste0(side, "_team")]])
    if (any(is.na(names_i) | !nzchar(trimws(names_i)))) {
      stop("Phase 13 martj42 historical input contains missing ", side, " team names", call. = FALSE)
    }
  }
  if (any(is.na(history$tournament) | !nzchar(trimws(as.character(history$tournament))))) {
    stop("Phase 13 martj42 historical input contains missing tournament values", call. = FALSE)
  }
  for (side in c("home", "away")) {
    values <- suppressWarnings(as.numeric(as.character(history[[paste0(side, "_score")]])))
    missing_scores <- is.na(values)
    invalid <- !missing_scores & (!is.finite(values) | values < 0 | values != floor(values))
    if (any(invalid)) {
      stop("Phase 13 martj42 historical input contains invalid ", side, " scores", call. = FALSE)
    }
  }
  invisible(history)
}

phase13_martj42_registry_table <- function(identity_registry) {
  if (is.character(identity_registry) && length(identity_registry) == 1L) {
    if (!file.exists(identity_registry)) {
      stop("Phase 13 martj42 identity registry file is missing: ", identity_registry, call. = FALSE)
    }
    identity_registry <- utils::read.csv(identity_registry, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  if (!is.data.frame(identity_registry)) {
    stop("Phase 13 martj42 identity registry must be a data frame or CSV path", call. = FALSE)
  }
  required <- c("team_id", "canonical_name")
  missing <- setdiff(required, names(identity_registry))
  if (length(missing)) {
    # The legacy team-name map is a valid source for stable historical IDs when
    # it has no Phase 13-specific columns. IDs are derived only from its
    # explicit FIFA code or canonical name, never from match outcomes.
    if (all(c("source_name", "canonical_name") %in% names(identity_registry))) {
      fifa <- if ("fifa_code" %in% names(identity_registry)) as.character(identity_registry$fifa_code) else rep(NA_character_, nrow(identity_registry))
      canonical <- as.character(identity_registry$canonical_name)
      slug <- phase13_normalize_team_name(canonical)
      slug <- gsub(" ", "_", slug, fixed = TRUE)
      slug <- gsub("[^a-z0-9_]+", "", slug)
      stable <- ifelse(
        !is.na(fifa) & grepl("^[A-Za-z]{3}$", fifa),
        paste0("team_", tolower(fifa)),
        paste0("team_", slug)
      )
      identity_registry$team_id <- stable
    } else {
      stop("Phase 13 martj42 identity registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
    }
  }
  identity_registry$team_id <- as.character(identity_registry$team_id)
  identity_registry$canonical_name <- as.character(identity_registry$canonical_name)
  identity_registry$fifa_code <- if ("fifa_code" %in% names(identity_registry)) as.character(identity_registry$fifa_code) else rep(NA_character_, nrow(identity_registry))
  identity_registry$aliases <- if ("aliases" %in% names(identity_registry)) as.character(identity_registry$aliases) else rep(NA_character_, nrow(identity_registry))
  if ("alt_names" %in% names(identity_registry)) {
    identity_registry$aliases <- ifelse(
      is.na(identity_registry$aliases) | !nzchar(identity_registry$aliases),
      as.character(identity_registry$alt_names),
      paste(identity_registry$aliases, identity_registry$alt_names, sep = "|")
    )
  }
  identity_registry$source_name <- if ("source_name" %in% names(identity_registry)) as.character(identity_registry$source_name) else rep(NA_character_, nrow(identity_registry))
  identity_registry$uefa_display_name_current <- if ("uefa_display_name_current" %in% names(identity_registry)) {
    as.character(identity_registry$uefa_display_name_current)
  } else {
    identity_registry$canonical_name
  }
  identity_registry$registry_source_team_id <- if ("uefa_source_team_id" %in% names(identity_registry)) {
    phase13_martj42_clean_optional_id(identity_registry$uefa_source_team_id)
  } else if ("source_team_id" %in% names(identity_registry)) {
    phase13_martj42_clean_optional_id(identity_registry$source_team_id)
  } else if ("source_id" %in% names(identity_registry)) {
    phase13_martj42_clean_optional_id(identity_registry$source_id)
  } else {
    rep(NA_character_, nrow(identity_registry))
  }
  if (any(is.na(identity_registry$team_id) | !nzchar(identity_registry$team_id)) ||
      any(is.na(identity_registry$canonical_name) | !nzchar(identity_registry$canonical_name))) {
    stop("Phase 13 martj42 identity registry contains incomplete stable identity", call. = FALSE)
  }
  if (anyDuplicated(identity_registry$team_id)) stop("Phase 13 martj42 identity registry contains duplicate team IDs", call. = FALSE)
  identity_registry$normalized_aliases <- vapply(seq_len(nrow(identity_registry)), function(index) {
    values <- c(
      identity_registry$canonical_name[[index]],
      identity_registry$uefa_display_name_current[[index]],
      identity_registry$source_name[[index]],
      if (is.na(identity_registry$aliases[[index]])) character(0) else
        unlist(strsplit(identity_registry$aliases[[index]], "\\|", fixed = FALSE), use.names = FALSE)
    )
    values <- unique(phase13_normalize_team_name(values))
    values <- values[!is.na(values) & nzchar(values)]
    if (!length(values)) stop("Phase 13 martj42 identity registry contains an identity without aliases", call. = FALSE)
    paste(values, collapse = "|")
  }, character(1))
  alias_rows <- do.call(rbind, lapply(seq_len(nrow(identity_registry)), function(index) {
    data.frame(
      normalized_alias = unlist(strsplit(identity_registry$normalized_aliases[[index]], "\\|", fixed = FALSE), use.names = FALSE),
      team_id = identity_registry$team_id[[index]],
      stringsAsFactors = FALSE
    )
  }))
  alias_counts <- aggregate(team_id ~ normalized_alias, alias_rows, function(value) length(unique(value)))
  if (any(alias_counts$team_id > 1L)) {
    aliases <- alias_counts$normalized_alias[alias_counts$team_id > 1L]
    stop("Phase 13 martj42 identity registry contains ambiguous normalized aliases: ", paste(aliases, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(identity_registry$registry_source_team_id[!is.na(identity_registry$registry_source_team_id)])) {
    stop("Phase 13 martj42 identity registry contains duplicate source team IDs", call. = FALSE)
  }
  identity_registry
}

phase13_martj42_resolve_registry_identity <- function(registry, source_team_id, source_display_name) {
  source_team_id <- phase13_martj42_clean_optional_id(source_team_id)[[1L]]
  source_display_name <- phase13_martj42_scalar(source_display_name, "source display name")
  normalized <- phase13_normalize_team_name(source_display_name)[[1L]]
  if (is.na(normalized) || !nzchar(normalized)) {
    stop("Phase 13 martj42 source display name has no usable normalized value", call. = FALSE)
  }
  if (!is.na(source_team_id)) {
    matches <- which(!is.na(registry$registry_source_team_id) & registry$registry_source_team_id == source_team_id)
    if (length(matches) != 1L) {
      stop("Phase 13 martj42 source team ID is unresolved: ", source_team_id, call. = FALSE)
    }
    aliases <- unlist(strsplit(registry$normalized_aliases[[matches]], "\\|", fixed = FALSE), use.names = FALSE)
    if (!normalized %in% aliases) {
      stop("Phase 13 martj42 source identity changed for source team ID: ", source_team_id, call. = FALSE)
    }
    return(list(
      registry_index = matches,
      normalized_source_name = normalized,
      mapping_method = "source_id",
      mapping_warning = "none",
      alias_review_state = "not_required"
    ))
  }
  alias_matches <- which(vapply(seq_len(nrow(registry)), function(index) {
    normalized %in% unlist(strsplit(registry$normalized_aliases[[index]], "\\|", fixed = FALSE), use.names = FALSE)
  }, logical(1)))
  if (!length(alias_matches)) stop("Phase 13 martj42 source identity is unresolved for display name: ", source_display_name, call. = FALSE)
  if (length(alias_matches) > 1L) stop("Phase 13 martj42 source identity is ambiguous for normalized display name: ", source_display_name, call. = FALSE)
  list(
    registry_index = alias_matches[[1L]],
    normalized_source_name = normalized,
    mapping_method = "normalized_display_name",
    mapping_warning = "normalized_display_name_requires_review",
    alias_review_state = "pending_review"
  )
}

phase13_martj42_history_identity_tokens <- function(history) {
  phase13_martj42_validate_history_shape(history)
  rows <- lapply(c("home", "away"), function(side) {
    source_name <- as.character(history[[paste0(side, "_team")]])
    source_id_column <- phase13_martj42_source_team_id_column(history, side)
    source_id <- if (is.na(source_id_column)) rep(NA_character_, nrow(history)) else phase13_martj42_clean_optional_id(history[[source_id_column]])
    normalized <- phase13_normalize_team_name(source_name)
    key <- phase13_martj42_source_identity_key(source_id, source_name)
    if (any(is.na(key) | !nzchar(key))) stop("Phase 13 martj42 historical input contains an unusable source identity", call. = FALSE)
    data.frame(
      source_identity_key = key,
      source_team_id = source_id,
      source_display_name = source_name,
      normalized_source_name = normalized,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  tokens <- unique(do.call(rbind, rows))
  tokens[order(tokens$source_identity_key), , drop = FALSE]
}

phase13_martj42_map_hash <- function(identity_map) {
  body <- identity_map[, setdiff(names(identity_map), c("identity_map_sha256", "row_sha256")), drop = FALSE]
  body <- body[order(as.character(body$source_identity_key)), , drop = FALSE]
  if (exists("phase13_canonical_sha256", mode = "function")) {
    return(phase13_canonical_sha256(body, key = "source_identity_key"))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 martj42 map hashes", call. = FALSE)
  payload <- paste(c(names(body), apply(body, 1L, function(row) paste(row, collapse = "\x1f"))), collapse = "\x1e")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}

phase13_validate_martj42_identity_map <- function(identity_map) {
  if (!is.data.frame(identity_map)) stop("Phase 13 martj42 identity map must be a data frame", call. = FALSE)
  missing <- setdiff(phase13_martj42_identity_map_required_columns(), names(identity_map))
  if (length(missing)) stop("Phase 13 martj42 identity map missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(identity_map)) stop("Phase 13 martj42 identity map must not be empty", call. = FALSE)
  metadata <- c("identity_map_version", "source_dataset", "source_version", "source_input_sha256", "source_artifact_id")
  for (column in metadata) {
    values <- as.character(identity_map[[column]])
    if (any(is.na(values) | !nzchar(trimws(values))) || length(unique(values)) != 1L) {
      stop("Phase 13 martj42 identity map has incomplete or inconsistent ", column, " metadata", call. = FALSE)
    }
  }
  phase13_martj42_version_scalar(identity_map$identity_map_version[[1L]], "identity_map_version")
  phase13_martj42_version_scalar(identity_map$source_dataset[[1L]], "source_dataset")
  phase13_martj42_version_scalar(identity_map$source_version[[1L]], "source_version")
  phase13_martj42_hash_scalar(identity_map$source_input_sha256[[1L]], "source_input_sha256")
  phase13_martj42_version_scalar(identity_map$source_artifact_id[[1L]], "source_artifact_id")
  if (any(is.na(identity_map$source_identity_key) | !nzchar(trimws(as.character(identity_map$source_identity_key))))) {
    stop("Phase 13 martj42 identity map contains missing source identity keys", call. = FALSE)
  }
  keys <- as.character(identity_map$source_identity_key)
  expected_keys <- phase13_martj42_source_identity_key(
    identity_map$source_team_id,
    identity_map$source_display_name
  )
  if (any(is.na(expected_keys) | expected_keys != keys)) {
    stop("Phase 13 martj42 identity map source identity keys do not match source IDs and display names", call. = FALSE)
  }
  duplicate_keys <- unique(keys[duplicated(keys)])
  if (length(duplicate_keys)) {
    for (key in duplicate_keys) {
      teams <- unique(as.character(identity_map$team_id[keys == key]))
      if (length(teams) > 1L) stop("Phase 13 martj42 identity map contains conflicting mappings for source identity: ", key, call. = FALSE)
    }
    stop("Phase 13 martj42 identity map contains duplicate source identity keys: ", paste(duplicate_keys, collapse = ", "), call. = FALSE)
  }
  if (any(is.na(identity_map$team_id) | !nzchar(trimws(as.character(identity_map$team_id))))) {
    stop("Phase 13 martj42 identity map contains unresolved stable team IDs", call. = FALSE)
  }
  if (any(is.na(identity_map$source_display_name) | !nzchar(trimws(as.character(identity_map$source_display_name))))) {
    stop("Phase 13 martj42 identity map contains unresolved source display names", call. = FALSE)
  }
  normalized <- as.character(identity_map$normalized_source_name)
  if (any(is.na(normalized) | !nzchar(trimws(normalized)))) stop("Phase 13 martj42 identity map contains malformed normalized aliases", call. = FALSE)
  alias_team_counts <- aggregate(team_id ~ normalized_source_name, identity_map, function(value) length(unique(value)))
  if (any(alias_team_counts$team_id > 1L)) stop("Phase 13 martj42 identity map contains ambiguous normalized aliases", call. = FALSE)
  if (any(!as.character(identity_map$mapping_method) %in% phase13_team_identity_allowed_mapping_methods())) {
    stop("Phase 13 martj42 identity map contains unsupported mapping methods", call. = FALSE)
  }
  if (any(is.na(identity_map$mapping_warning) | !nzchar(as.character(identity_map$mapping_warning))) ||
      any(is.na(identity_map$alias_review_state) | !nzchar(as.character(identity_map$alias_review_state)))) {
    stop("Phase 13 martj42 identity map requires visible mapping warning and review metadata", call. = FALSE)
  }
  map_hash <- as.character(identity_map$identity_map_sha256)
  if (any(is.na(map_hash) | !grepl("^[0-9a-fA-F]{64}$", map_hash)) || length(unique(tolower(map_hash))) != 1L) {
    stop("Phase 13 martj42 identity map contains malformed identity_map_sha256 values", call. = FALSE)
  }
  expected_map_hash <- phase13_martj42_map_hash(identity_map)
  if (!identical(tolower(map_hash[[1L]]), tolower(expected_map_hash))) {
    stop("Phase 13 martj42 identity map canonical hash mismatch", call. = FALSE)
  }
  actual_rows <- tolower(as.character(identity_map$row_sha256))
  expected_rows <- phase13_identity_row_hash(identity_map)
  if (any(is.na(actual_rows) | !grepl("^[0-9a-f]{64}$", actual_rows)) || any(actual_rows != expected_rows)) {
    stop("Phase 13 martj42 identity map row SHA-256 mismatch", call. = FALSE)
  }
  invisible(identity_map)
}

#' Require exactly one identity-map row for every historical home/away token.
phase13_validate_martj42_identity_coverage <- function(history, identity_map) {
  tokens <- phase13_martj42_history_identity_tokens(history)
  phase13_validate_martj42_identity_map(identity_map)
  map_keys <- as.character(identity_map$source_identity_key)
  missing <- setdiff(tokens$source_identity_key, map_keys)
  extra <- setdiff(map_keys, tokens$source_identity_key)
  if (length(missing)) stop("Phase 13 martj42 identity map has unresolved historical source identities: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(extra)) stop("Phase 13 martj42 identity map is not complete for the supplied historical input; unexpected source identities: ", paste(extra, collapse = ", "), call. = FALSE)
  matches <- match(tokens$source_identity_key, map_keys)
  if (anyNA(matches) || anyDuplicated(matches)) stop("Phase 13 martj42 identity coverage is not exactly one-to-one", call. = FALSE)
  invisible(identity_map)
}

#' Generate a deterministic source-identity map from complete preprocessed history.
phase13_generate_martj42_identity_map <- function(
    history,
    identity_registry,
    source_dataset,
    source_version,
    source_input_sha256,
    source_artifact_id,
    identity_map_version = "phase13-martj42-identity-map-v1",
    output_path = NULL) {
  phase13_martj42_validate_history_shape(history)
  source_dataset <- phase13_martj42_version_scalar(source_dataset, "source_dataset")
  source_version <- phase13_martj42_version_scalar(source_version, "source_version")
  source_input_sha256 <- phase13_martj42_hash_scalar(source_input_sha256, "source_input_sha256")
  source_artifact_id <- phase13_martj42_version_scalar(source_artifact_id, "source_artifact_id")
  identity_map_version <- phase13_martj42_version_scalar(identity_map_version, "identity_map_version")
  registry <- phase13_martj42_registry_table(identity_registry)
  tokens <- phase13_martj42_history_identity_tokens(history)
  rows <- lapply(seq_len(nrow(tokens)), function(index) {
    token <- tokens[index, , drop = FALSE]
    resolved <- phase13_martj42_resolve_registry_identity(
      registry,
      token$source_team_id[[1L]],
      token$source_display_name[[1L]]
    )
    candidate <- registry[resolved$registry_index, , drop = FALSE]
    data.frame(
      identity_map_version = identity_map_version,
      source_dataset = source_dataset,
      source_version = source_version,
      source_input_sha256 = source_input_sha256,
      source_artifact_id = source_artifact_id,
      source_identity_key = token$source_identity_key[[1L]],
      source_team_id = token$source_team_id[[1L]],
      source_display_name = token$source_display_name[[1L]],
      normalized_source_name = resolved$normalized_source_name,
      team_id = as.character(candidate$team_id[[1L]]),
      fifa_code = as.character(candidate$fifa_code[[1L]]),
      canonical_name = as.character(candidate$canonical_name[[1L]]),
      aliases = as.character(candidate$aliases[[1L]]),
      mapping_method = resolved$mapping_method,
      mapping_warning = resolved$mapping_warning,
      alias_review_state = resolved$alias_review_state,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  identity_map <- do.call(rbind, rows)
  identity_map$identity_map_sha256 <- ""
  identity_map$row_sha256 <- ""
  identity_map$identity_map_sha256 <- phase13_martj42_map_hash(identity_map)
  identity_map$row_sha256 <- phase13_identity_row_hash(identity_map)
  phase13_validate_martj42_identity_map(identity_map)
  attr(identity_map, "identity_map_sha256") <- identity_map$identity_map_sha256[[1L]]
  attr(identity_map, "source_input_sha256") <- source_input_sha256
  if (!is.null(output_path)) {
    if (exists("phase13_source_write_csv", mode = "function")) {
      phase13_source_write_csv(identity_map, output_path)
    } else {
      dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
      utils::write.csv(identity_map, output_path, row.names = FALSE, na = "", quote = TRUE)
    }
  }
  identity_map
}

phase13_martj42_edition_lookup_required_columns <- function() {
  c(
    "match_id", "edition_id", "source_dataset", "source_artifact_id",
    "schema_version", "edition_lookup_sha256", "row_sha256"
  )
}

phase13_martj42_edition_lookup_hash <- function(edition_lookup) {
  body <- edition_lookup[, setdiff(names(edition_lookup), c("edition_lookup_sha256", "row_sha256")), drop = FALSE]
  body <- body[order(as.character(body$match_id)), , drop = FALSE]
  if (exists("phase13_canonical_sha256", mode = "function")) {
    return(phase13_canonical_sha256(body, key = "match_id"))
  }
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 13 edition lookup hashes", call. = FALSE)
  payload <- paste(c(names(body), apply(body, 1L, function(row) paste(row, collapse = "\x1f"))), collapse = "\x1e")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}

phase13_validate_martj42_edition_lookup <- function(edition_lookup) {
  if (!is.data.frame(edition_lookup)) stop("Phase 13 martj42 edition lookup must be a data frame", call. = FALSE)
  missing <- setdiff(phase13_martj42_edition_lookup_required_columns(), names(edition_lookup))
  if (length(missing)) stop("Phase 13 martj42 edition lookup missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!nrow(edition_lookup)) stop("Phase 13 martj42 edition lookup must not be empty", call. = FALSE)
  match_ids <- as.character(edition_lookup$match_id)
  if (any(is.na(match_ids) | !nzchar(trimws(match_ids))) || anyDuplicated(match_ids)) {
    stop("Phase 13 martj42 edition lookup must contain one row per unique match_id", call. = FALSE)
  }
  for (column in c("edition_id", "source_dataset", "source_artifact_id", "schema_version")) {
    values <- as.character(edition_lookup[[column]])
    if (any(is.na(values) | !nzchar(trimws(values)))) stop("Phase 13 martj42 edition lookup contains missing ", column, " values", call. = FALSE)
  }
  if (any(!grepl("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$", as.character(edition_lookup$edition_id)))) {
    stop("Phase 13 martj42 edition lookup contains malformed edition IDs", call. = FALSE)
  }
  lookup_hash <- tolower(as.character(edition_lookup$edition_lookup_sha256))
  if (any(is.na(lookup_hash) | !grepl("^[0-9a-f]{64}$", lookup_hash)) || length(unique(lookup_hash)) != 1L) {
    stop("Phase 13 martj42 edition lookup contains malformed edition_lookup_sha256 values", call. = FALSE)
  }
  expected_lookup_hash <- phase13_martj42_edition_lookup_hash(edition_lookup)
  if (!identical(lookup_hash[[1L]], tolower(expected_lookup_hash))) {
    stop("Phase 13 martj42 edition lookup canonical hash mismatch", call. = FALSE)
  }
  actual_rows <- tolower(as.character(edition_lookup$row_sha256))
  expected_rows <- phase13_identity_row_hash(edition_lookup)
  if (any(is.na(actual_rows) | !grepl("^[0-9a-f]{64}$", actual_rows)) || any(actual_rows != expected_rows)) {
    stop("Phase 13 martj42 edition lookup row SHA-256 mismatch", call. = FALSE)
  }
  invisible(edition_lookup)
}

phase13_martj42_preserved_value <- function(data, column, n) {
  if (!column %in% names(data)) return(rep(NA_character_, n))
  as.character(data[[column]])
}

#' Normalize preprocessed historical rows through stable identity and edition maps.
phase13_normalize_historical_result_rows <- function(
    history,
    identity_map,
    edition_lookup,
    source_dataset = NULL,
    source_artifact_id = NULL,
    source_version = NULL,
    identity_map_version = NULL) {
  phase13_martj42_validate_history_shape(history)
  phase13_validate_martj42_identity_coverage(history, identity_map)
  phase13_validate_martj42_edition_lookup(edition_lookup)
  history_match_ids <- as.character(history$match_id)
  lookup_match_ids <- as.character(edition_lookup$match_id)
  if (!setequal(history_match_ids, lookup_match_ids)) {
    missing <- setdiff(history_match_ids, lookup_match_ids)
    extra <- setdiff(lookup_match_ids, history_match_ids)
    message_text <- paste(c(
      if (length(missing)) paste0("missing match IDs: ", paste(missing, collapse = ", ")) else character(0),
      if (length(extra)) paste0("unexpected match IDs: ", paste(extra, collapse = ", ")) else character(0)
    ), collapse = "; ")
    stop("Phase 13 martj42 edition lookup coverage mismatch (", message_text, ")", call. = FALSE)
  }
  map_dataset <- unique(as.character(identity_map$source_dataset))[[1L]]
  map_artifact <- unique(as.character(identity_map$source_artifact_id))[[1L]]
  map_version <- unique(as.character(identity_map$source_version))[[1L]]
  map_identity_version <- unique(as.character(identity_map$identity_map_version))[[1L]]
  source_dataset <- if (is.null(source_dataset)) map_dataset else phase13_martj42_version_scalar(source_dataset, "source_dataset")
  source_artifact_id <- if (is.null(source_artifact_id)) map_artifact else phase13_martj42_version_scalar(source_artifact_id, "source_artifact_id")
  source_version <- if (is.null(source_version)) map_version else phase13_martj42_version_scalar(source_version, "source_version")
  identity_map_version <- if (is.null(identity_map_version)) map_identity_version else phase13_martj42_version_scalar(identity_map_version, "identity_map_version")
  if (!identical(source_dataset, map_dataset) || !identical(source_artifact_id, map_artifact) ||
      !identical(source_version, map_version) || !identical(identity_map_version, map_identity_version)) {
    stop("Phase 13 martj42 normalization provenance does not match the identity map", call. = FALSE)
  }
  lookup_by_match <- edition_lookup[match(history_match_ids, lookup_match_ids), , drop = FALSE]
  source_lookup <- identity_map[match(phase13_martj42_history_identity_tokens(history)$source_identity_key, identity_map$source_identity_key), , drop = FALSE]
  source_ids <- lapply(c("home", "away"), function(side) {
    column <- phase13_martj42_source_team_id_column(history, side)
    if (is.na(column)) rep(NA_character_, nrow(history)) else phase13_martj42_clean_optional_id(history[[column]])
  })
  source_names <- lapply(c("home", "away"), function(side) as.character(history[[paste0(side, "_team")]]))
  keys <- lapply(seq_along(source_names), function(index) phase13_martj42_source_identity_key(source_ids[[index]], source_names[[index]]))
  map_rows <- lapply(keys, function(key) identity_map[match(key, identity_map$source_identity_key), , drop = FALSE])
  n <- nrow(history)
  score_values <- lapply(c("home", "away"), function(side) suppressWarnings(as.numeric(as.character(history[[paste0(side, "_score")]]))))
  output <- data.frame(
    schema_version = rep("phase13-martj42-historical-normalized-v1", n),
    source_result_id = as.character(history$match_id),
    match_id = as.character(history$match_id),
    date = as.character(history$date),
    home_team = as.character(history$home_team),
    away_team = as.character(history$away_team),
    home_display_name = as.character(history$home_team),
    away_display_name = as.character(history$away_team),
    home_source_team_id = source_ids[[1L]],
    away_source_team_id = source_ids[[2L]],
    home_source_identity_key = keys[[1L]],
    away_source_identity_key = keys[[2L]],
    home_team_id = as.character(map_rows[[1L]]$team_id),
    away_team_id = as.character(map_rows[[2L]]$team_id),
    home_mapping_method = as.character(map_rows[[1L]]$mapping_method),
    away_mapping_method = as.character(map_rows[[2L]]$mapping_method),
    home_mapping_warning = as.character(map_rows[[1L]]$mapping_warning),
    away_mapping_warning = as.character(map_rows[[2L]]$mapping_warning),
    edition_id = as.character(lookup_by_match$edition_id),
    home_score = score_values[[1L]],
    away_score = score_values[[2L]],
    tournament = as.character(history$tournament),
    city = phase13_martj42_preserved_value(history, "city", n),
    country = phase13_martj42_preserved_value(history, "country", n),
    neutral = as.character(history$neutral),
    home_team_canonical = phase13_martj42_preserved_value(history, "home_team_canonical", n),
    away_team_canonical = phase13_martj42_preserved_value(history, "away_team_canonical", n),
    home_team_fifa = phase13_martj42_preserved_value(history, "home_team_fifa", n),
    away_team_fifa = phase13_martj42_preserved_value(history, "away_team_fifa", n),
    result = phase13_martj42_preserved_value(history, "result", n),
    is_home = phase13_martj42_preserved_value(history, "is_home", n),
    score_source = phase13_martj42_preserved_value(history, "score_source", n),
    source_dataset = rep(source_dataset, n),
    source_version = rep(source_version, n),
    source_input_sha256 = as.character(identity_map$source_input_sha256[[1L]]),
    source_artifact_id = rep(source_artifact_id, n),
    identity_map_version = rep(identity_map_version, n),
    identity_map_sha256 = rep(as.character(identity_map$identity_map_sha256[[1L]]), n),
    edition_lookup_schema_version = as.character(lookup_by_match$schema_version),
    edition_lookup_sha256 = as.character(lookup_by_match$edition_lookup_sha256),
    edition_lookup_row_sha256 = as.character(lookup_by_match$row_sha256),
    edition_mapping_method = rep("explicit_lookup", n),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output$row_sha256 <- phase13_identity_row_hash(output)
  output[, phase13_normalized_historical_result_schema(), drop = FALSE]
}
