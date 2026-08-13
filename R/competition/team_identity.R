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

load_phase13_team_identity_registry <- function(path = "data/competition/registries/team_identity.csv", validate = TRUE) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    stop("Phase 13 team identity registry file is missing: ", path, call. = FALSE)
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (isTRUE(validate)) phase13_validate_team_identity_registry(registry)
  attr(registry, "path") <- normalizePath(path, winslash = "/", mustWork = TRUE)
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
