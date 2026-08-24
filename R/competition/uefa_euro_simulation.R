#' Deterministic EURO qualifying simulation and the Phase 15 eligibility adapter.
#'
#' Phase 16 owns the competition-specific simulation boundary.  It consumes
#' registered Phase 15 ranking evidence and the Phase 14 calibrated forecast
#' authority; it does not fit, recalibrate, or publish either parent product.

uefa_euro_sim_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function", inherits = TRUE)]
  if (!length(missing)) return(invisible(TRUE))
  root <- normalizePath(".", winslash = "/", mustWork = TRUE)
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("EURO simulation dependency is missing: ", relative_path, call. = FALSE)
  sys.source(path, envir = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function", inherits = TRUE)]
  if (length(missing)) stop("EURO simulation dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

uefa_euro_sim_source_if_missing(
  "R/competition/uefa_euro_rules.R",
  c(
    "uefa_euro_2026_28_rules", "uefa_euro_ruleset_sha256", "uefa_euro_source_bundle_id",
    "validate_euro_draw_conditions", "uefa_euro_playoff_topologies", "allocate_euro_places"
  )
)

uefa_euro_sim_coalesce <- function(left, right) {
  if (is.null(left) || !length(left)) return(right)
  if (length(left) == 1L && (is.na(left[[1L]]) || !nzchar(trimws(as.character(left[[1L]]))))) return(right)
  left
}

uefa_euro_sim_scalar <- function(value, default = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

uefa_euro_sim_hash_valid <- function(value) {
  value <- as.character(value)
  length(value) == 1L && !is.na(value) && grepl("^[0-9a-fA-F]{64}$", value)
}

uefa_euro_sim_bool <- function(value, default = FALSE) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(default)
  if (is.logical(value)) return(isTRUE(value[[1L]]))
  tolower(trimws(as.character(value[[1L]]))) %in% c("true", "1", "yes", "confirmed", "valid", "accepted")
}

uefa_euro_sim_field <- function(value, fields, default = "") {
  if (is.data.frame(value)) {
    for (field in fields) {
      if (field %in% names(value) && nrow(value)) return(uefa_euro_sim_scalar(value[[field]], default))
    }
    return(default)
  }
  if (is.list(value)) {
    for (field in fields) {
      if (!is.null(value[[field]])) return(uefa_euro_sim_scalar(value[[field]], default))
    }
  }
  default
}

uefa_euro_sim_empty <- function(columns, types = NULL) {
  if (is.null(types)) types <- rep("character", length(columns))
  if (length(types) != length(columns)) stop("EURO simulation empty schema has incompatible types", call. = FALSE)
  values <- lapply(types, function(type) {
    switch(
      type,
      character = character(), integer = integer(), numeric = numeric(), logical = logical(),
      stop("EURO simulation empty schema has unsupported type: ", type, call. = FALSE)
    )
  })
  as.data.frame(setNames(values, columns), stringsAsFactors = FALSE, check.names = FALSE)
}

uefa_euro_sim_empty_projection <- function() {
  uefa_euro_sim_empty(
    c(
      "edition_id", "team_id", "league", "group_id", "group_position", "interim_overall_rank",
      "ranking_scope", "ranking_stage", "eligibility_status", "source_bundle_id", "source_bundle_sha256",
      "source_artifact_id", "source_manifest_sha256", "source_artifact_path", "source_artifact_content_sha256",
      "ruleset_version", "ruleset_sha256", "projection_run_id"
    ),
    c(rep("character", 4L), "integer", "integer", rep("character", 12L))
  )
}

uefa_euro_sim_empty_probability <- function() {
  uefa_euro_sim_empty(
    c(
      "edition_id", "team_id", "probability", "qualification_status", "status", "reason",
      "scenario_id", "path_id", "source_bundle_id", "source_bundle_sha256", "ruleset_version",
      "ruleset_sha256", "model_release_id", "state_manifest_sha256", "draw_conditions_version",
      "draw_conditions_sha256", "simulation_seed", "simulation_count"
    ),
    c("character", "character", "numeric", rep("character", 13L), "integer", "integer")
  )
}

uefa_euro_sim_hash_column <- function(value) {
  if (inherits(value, "POSIXt")) {
    value <- format(value, "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  } else if (inherits(value, "Date")) {
    value <- format(value, "%Y-%m-%d")
  } else if (is.logical(value)) {
    value <- ifelse(is.na(value), "<NA>", ifelse(value, "TRUE", "FALSE"))
  } else {
    value <- as.character(value)
  }
  value[is.na(value)] <- "<NA>"
  value
}

uefa_euro_sim_hash_data <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for EURO simulation hashes", call. = FALSE)
  if (is.data.frame(value)) {
    fields <- sort(names(value), method = "radix")
    data <- value[, fields, drop = FALSE]
    columns <- lapply(data, uefa_euro_sim_hash_column)
    if (nrow(data) && ncol(data)) {
      ordering <- do.call(order, c(columns, list(na.last = TRUE, method = "radix")))
      data <- data[ordering, , drop = FALSE]
    }
    columns <- lapply(data, uefa_euro_sim_hash_column)
    rows <- if (!nrow(data)) character() else vapply(seq_len(nrow(data)), function(index) {
      paste(vapply(columns, `[[`, character(1), index), collapse = "\x1f")
    }, character(1))
    payload <- paste(c(paste(fields, collapse = "\x1f"), rows), collapse = "\x1e")
    return(tolower(digest::digest(payload, algo = "sha256", serialize = FALSE)))
  }
  if (is.list(value)) {
    if (!is.null(names(value))) value <- value[sort(names(value), method = "radix")]
    return(tolower(digest::digest(value, algo = "sha256", serialize = TRUE)))
  }
  value <- uefa_euro_sim_hash_column(value)
  tolower(digest::digest(paste(value, collapse = "\x1f"), algo = "sha256", serialize = FALSE))
}

# Match the Phase 15 outcomes canonical CSV hash for registered artifact checks.
uefa_euro_nl_canonical_scalar <- function(value) {
  if (!length(value) || is.na(value[[1L]])) return("")
  if (is.logical(value)) return(ifelse(value[[1L]], "true", "false"))
  value <- as.character(value[[1L]])
  if (value %in% c("TRUE", "FALSE", "True", "False", "true", "false")) return(tolower(value))
  value
}

uefa_euro_nl_table_content_hash <- function(data) {
  if (!is.data.frame(data)) stop("EURO registered artifact hash requires a data frame", call. = FALSE)
  canonical <- as.data.frame(lapply(data, function(column) {
    values <- vapply(column, uefa_euro_nl_canonical_scalar, character(1))
    values[!nzchar(values)] <- NA_character_
    values
  }), stringsAsFactors = FALSE, check.names = FALSE)
  path <- tempfile("euro-phase15-artifact-", fileext = ".csv")
  on.exit(if (file.exists(path)) unlink(path), add = TRUE)
  utils::write.csv(canonical, path, row.names = FALSE, na = "", quote = TRUE)
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  tolower(digest::digest(bytes, algo = "sha256", serialize = FALSE))
}

uefa_euro_sim_canonical_table <- function(data, key = NULL) {
  if (!is.data.frame(data)) return(data)
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  fields <- if (is.null(key)) names(data) else intersect(key, names(data))
  fields <- c(fields, setdiff(names(data), fields))
  if (nrow(data) > 1L && length(fields)) {
    columns <- lapply(data[fields], uefa_euro_sim_hash_column)
    data <- data[do.call(order, c(columns, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  row.names(data) <- NULL
  data
}

uefa_euro_sim_seed_for <- function(seed, ...) {
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("EURO simulation seed must be one non-negative integer", call. = FALSE)
  token <- paste(c(seed, ...), collapse = "\x1f")
  hash <- uefa_euro_sim_hash_data(token)
  value <- suppressWarnings(strtoi(substr(hash, 1L, 8L), base = 16L))
  if (is.na(value)) value <- 1
  as.integer((as.numeric(value) %% 2147483646) + 1)
}

uefa_euro_sim_with_seed <- function(seed, callback) {
  if (!is.function(callback)) stop("EURO simulation seeded callback must be a function", call. = FALSE)
  if (is.null(seed)) return(callback())
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("EURO simulation seed must be one non-negative integer", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE) else NULL
  set.seed(seed)
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  callback()
}

uefa_euro_sim_status_result <- function(status, reason, projection = NULL, ...) {
  if (is.null(projection)) projection <- uefa_euro_sim_empty_projection()
  list(
    valid = FALSE,
    status = as.character(status),
    reason = as.character(reason),
    eligibility_status = as.character(status),
    projection = projection,
    rows = projection,
    ...
  )
}

uefa_euro_sim_manifest_table <- function(manifest) {
  if (is.null(manifest)) return(NULL)
  if (is.data.frame(manifest)) return(as.data.frame(manifest, stringsAsFactors = FALSE, check.names = FALSE))
  if (is.list(manifest)) {
    nested <- manifest$manifest %||% manifest$outcomes_manifest
    if (is.data.frame(nested)) return(as.data.frame(nested, stringsAsFactors = FALSE, check.names = FALSE))
    scalar <- lapply(manifest, function(value) {
      if (length(value) == 0L) return(NA_character_)
      if (length(value) > 1L) return(paste(as.character(value), collapse = "|"))
      value[[1L]]
    })
    return(as.data.frame(scalar, stringsAsFactors = FALSE, check.names = FALSE))
  }
  NULL
}

uefa_euro_sim_manifest_record <- function(manifest, artifact_name = "projected_rankings.csv") {
  table <- uefa_euro_sim_manifest_table(manifest)
  if (is.null(table) || !nrow(table)) return(NULL)
  if ("artifact_path" %in% names(table)) {
    paths <- gsub("\\\\", "/", as.character(table$artifact_path))
    indexes <- which(grepl(paste0("(^|/)", artifact_name, "$"), paths))
    if (length(indexes) == 1L) return(as.list(table[indexes, , drop = FALSE]))
    if (length(indexes) > 1L) return(NULL)
  }
  if (nrow(table) == 1L) return(as.list(table[1L, , drop = FALSE]))
  NULL
}

uefa_euro_sim_manifest_failure <- function(reason, projected_rankings = NULL, manifest = NULL, ...) {
  if (is.null(projected_rankings)) projected_rankings <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  uefa_euro_sim_status_result(
    "unresolved_external_eligibility", reason,
    projection = uefa_euro_sim_empty_projection(),
    projected_rankings = projected_rankings,
    manifest = manifest,
    ...
  )
}

uefa_euro_read_registered_nl_handoff <- function(
    project_root = ".", outcomes_root = NULL, projected_rankings_path = NULL,
    rankings_path = NULL, manifest_path = NULL, projected_rankings = NULL,
    manifest = NULL, validate = TRUE) {
  root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  outcomes_root <- outcomes_root %||% file.path(
    root, "outputs", "competition", "uefa_nations_league_2026_27", "outcomes"
  )
  outcomes_root <- normalizePath(outcomes_root, winslash = "/", mustWork = FALSE)
  projected_rankings_path <- projected_rankings_path %||% rankings_path %||% file.path(outcomes_root, "projected_rankings.csv")
  manifest_path <- manifest_path %||% file.path(outcomes_root, "outcomes_manifest.csv")
  if (is.null(projected_rankings)) {
    if (!file.exists(projected_rankings_path)) {
      return(uefa_euro_sim_manifest_failure("registered_phase15_projected_rankings_missing", manifest = manifest,
        projected_rankings_path = projected_rankings_path, manifest_path = manifest_path,
        projected_rankings = data.frame(stringsAsFactors = FALSE, check.names = FALSE)))
    }
    projected_rankings <- tryCatch(
      utils::read.csv(projected_rankings_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
      error = function(error) NULL
    )
    if (is.null(projected_rankings)) {
      return(uefa_euro_sim_manifest_failure("registered_phase15_projected_rankings_unreadable", manifest = manifest,
        projected_rankings_path = projected_rankings_path, manifest_path = manifest_path))
    }
  }
  if (is.null(manifest)) {
    if (!file.exists(manifest_path)) {
      return(uefa_euro_sim_manifest_failure("registered_phase15_outcomes_manifest_missing", projected_rankings = projected_rankings,
        projected_rankings_path = projected_rankings_path, manifest_path = manifest_path))
    }
    manifest <- tryCatch(
      utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
      error = function(error) NULL
    )
    if (is.null(manifest)) {
      return(uefa_euro_sim_manifest_failure("registered_phase15_outcomes_manifest_unreadable", projected_rankings = projected_rankings,
        projected_rankings_path = projected_rankings_path, manifest_path = manifest_path))
    }
  }
  record <- uefa_euro_sim_manifest_record(manifest)
  if (is.null(record)) {
    return(uefa_euro_sim_manifest_failure("registered_phase15_projected_rankings_manifest_row_missing_or_ambiguous",
      projected_rankings = projected_rankings, manifest = manifest,
      projected_rankings_path = projected_rankings_path, manifest_path = manifest_path))
  }
  reasons <- character()
  if (!identical(uefa_euro_sim_scalar(record$edition_id), "uefa_nations_league_2026_27")) reasons <- c(reasons, "phase15_edition_mismatch")
  if (length(record$validation_status) && !uefa_euro_sim_scalar(record$validation_status) %in% c("valid", "accepted")) reasons <- c(reasons, "registered_phase15_manifest_not_valid")
  if (length(record$registered) && !uefa_euro_sim_bool(record$registered)) reasons <- c(reasons, "registered_phase15_manifest_not_registered")
  if (length(record$row_count) && suppressWarnings(as.integer(record$row_count[[1L]])) != nrow(projected_rankings)) reasons <- c(reasons, "phase15_projected_rankings_row_count_mismatch")
  content_hash <- tryCatch(uefa_euro_nl_table_content_hash(projected_rankings), error = function(error) "")
  expected_hash <- uefa_euro_sim_scalar(record$content_sha256)
  if (!uefa_euro_sim_hash_valid(expected_hash) || !identical(tolower(expected_hash), tolower(content_hash))) reasons <- c(reasons, "phase15_projected_rankings_content_hash_mismatch")
  source_bundle_id <- uefa_euro_sim_scalar(record$source_bundle_id)
  source_bundle_sha256 <- uefa_euro_sim_scalar(record$source_bundle_sha256)
  ruleset_version <- uefa_euro_sim_scalar(record$ruleset_version)
  ruleset_sha256 <- uefa_euro_sim_scalar(record$ruleset_sha256)
  if (!nzchar(source_bundle_id) || !uefa_euro_sim_hash_valid(source_bundle_sha256)) reasons <- c(reasons, "phase15_source_lineage_incomplete")
  if (!nzchar(ruleset_version) || !uefa_euro_sim_hash_valid(ruleset_sha256)) reasons <- c(reasons, "phase15_rules_lineage_incomplete")
  full_table <- uefa_euro_sim_manifest_table(manifest)
  if (isTRUE(validate) && is.data.frame(full_table) && "validation_status" %in% names(full_table)) {
    statuses <- tolower(trimws(as.character(full_table$validation_status)))
    if (any(!is.na(statuses) & nzchar(statuses) & !statuses %in% c("valid", "accepted"))) reasons <- c(reasons, "registered_phase15_manifest_contains_blocked_artifact")
  }
  output <- list(
    valid = !length(unique(reasons)),
    registered = !length(unique(reasons)),
    status = if (length(reasons)) "unresolved_external_eligibility" else "registered",
    reason = paste(unique(reasons), collapse = ";"),
    projected_rankings = projected_rankings,
    projection = projected_rankings,
    rows = projected_rankings,
    manifest = manifest,
    manifest_row = record,
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    projected_rankings_path = normalizePath(projected_rankings_path, winslash = "/", mustWork = FALSE),
    source_bundle_id = source_bundle_id,
    source_bundle_sha256 = source_bundle_sha256,
    ruleset_version = ruleset_version,
    ruleset_sha256 = ruleset_sha256,
    source_artifact_id = uefa_euro_sim_scalar(record$source_artifact_ids),
    source_artifact_content_sha256 = expected_hash,
    manifest_sha256 = uefa_euro_sim_scalar(record$manifest_sha256),
    artifact_hash = content_hash
  )
  if (length(reasons)) output$registered <- TRUE
  output
}

uefa_euro_sim_normalized_lineage <- function(handoff, manifest_record, rows) {
  source_bundle_id <- uefa_euro_sim_scalar(handoff$source_bundle_id %||% manifest_record$source_bundle_id)
  source_bundle_sha256 <- uefa_euro_sim_scalar(handoff$source_bundle_sha256 %||% manifest_record$source_bundle_sha256)
  ruleset_version <- uefa_euro_sim_scalar(handoff$ruleset_version %||% manifest_record$ruleset_version)
  ruleset_sha256 <- uefa_euro_sim_scalar(handoff$ruleset_sha256 %||% manifest_record$ruleset_sha256)
  source_artifact_id <- uefa_euro_sim_scalar(handoff$source_artifact_id %||% manifest_record$source_artifact_ids)
  list(
    edition_id = "uefa_nations_league_2026_27",
    source_bundle_id = source_bundle_id,
    source_bundle_sha256 = source_bundle_sha256,
    source_artifact_id = source_artifact_id,
    source_manifest_sha256 = uefa_euro_sim_scalar(handoff$manifest_sha256 %||% manifest_record$manifest_sha256),
    source_artifact_path = uefa_euro_sim_scalar(handoff$projected_rankings_path %||% manifest_record$artifact_path),
    source_artifact_content_sha256 = uefa_euro_sim_scalar(handoff$source_artifact_content_sha256 %||% manifest_record$content_sha256),
    ruleset_version = ruleset_version,
    ruleset_sha256 = ruleset_sha256,
    projection_hash = uefa_euro_sim_hash_data(rows)
  )
}

uefa_euro_normalize_nl_interim_projection <- function(
    handoff = NULL, projected_rankings = NULL, manifest = NULL, project_root = ".",
    outcomes_root = NULL, projected_rankings_path = NULL, manifest_path = NULL) {
  if (is.list(handoff) && !is.data.frame(handoff)) {
    if (is.null(projected_rankings)) projected_rankings <- handoff$projected_rankings %||% handoff$projection %||% handoff$rows
    if (is.null(manifest)) manifest <- handoff$manifest
  } else if (is.data.frame(handoff) && is.null(projected_rankings)) {
    projected_rankings <- handoff
  }
  registered <- handoff
  if (is.null(projected_rankings)) {
    registered <- uefa_euro_read_registered_nl_handoff(
      project_root = project_root, outcomes_root = outcomes_root,
      projected_rankings_path = projected_rankings_path, manifest_path = manifest_path,
      manifest = manifest
    )
    projected_rankings <- registered$projected_rankings %||% registered$projection
    manifest <- registered$manifest
  } else if (is.null(registered) || !is.list(registered)) {
    registered <- list(
      valid = TRUE, registered = TRUE, status = "registered", manifest = manifest,
      source_bundle_id = uefa_euro_sim_field(manifest, c("source_bundle_id")),
      source_bundle_sha256 = uefa_euro_sim_field(manifest, c("source_bundle_sha256")),
      ruleset_version = uefa_euro_sim_field(manifest, c("ruleset_version")),
      ruleset_sha256 = uefa_euro_sim_field(manifest, c("ruleset_sha256")),
      source_artifact_id = uefa_euro_sim_field(manifest, c("source_artifact_ids", "source_artifact_id")),
      source_artifact_content_sha256 = uefa_euro_sim_field(manifest, c("content_sha256")),
      manifest_sha256 = uefa_euro_sim_field(manifest, c("manifest_sha256")),
      projected_rankings_path = uefa_euro_sim_field(manifest, c("artifact_path"))
    )
  }
  if (is.null(projected_rankings) || !is.data.frame(projected_rankings)) {
    return(uefa_euro_sim_manifest_failure("phase15_projected_rankings_missing", manifest = manifest))
  }
  if (isFALSE(registered$valid) || identical(registered$status, "unresolved_external_eligibility")) {
    return(uefa_euro_sim_manifest_failure(
      registered$reason %||% "registered_phase15_handoff_invalid", projected_rankings = projected_rankings,
      manifest = manifest, source_bundle_id = registered$source_bundle_id,
      source_bundle_sha256 = registered$source_bundle_sha256,
      ruleset_version = registered$ruleset_version, ruleset_sha256 = registered$ruleset_sha256
    ))
  }
  record <- registered$manifest_row %||% uefa_euro_sim_manifest_record(manifest)
  if (is.null(record)) record <- manifest
  rows <- as.data.frame(projected_rankings, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"team_id" %in% names(rows)) return(uefa_euro_sim_manifest_failure("phase15_team_id_missing", projected_rankings = rows, manifest = manifest))
  rows$team_id <- trimws(as.character(rows$team_id))
  if (any(is.na(rows$team_id) | !nzchar(rows$team_id))) return(uefa_euro_sim_manifest_failure("phase15_team_id_missing", projected_rankings = rows, manifest = manifest))
  if ("edition_id" %in% names(rows) && any(as.character(rows$edition_id) != "uefa_nations_league_2026_27")) return(uefa_euro_sim_manifest_failure("phase15_edition_mismatch", projected_rankings = rows, manifest = manifest))
  scope <- if ("ranking_scope" %in% names(rows)) trimws(as.character(rows$ranking_scope)) else rep("", nrow(rows))
  interim_evidence <- if ("interim_ranking_stage" %in% names(rows)) trimws(as.character(rows$interim_ranking_stage)) else rep("", nrow(rows))
  stage <- if ("ranking_stage" %in% names(rows)) trimws(as.character(rows$ranking_stage)) else rep("", nrow(rows))
  if (!any(nzchar(scope))) {
    if (all(interim_evidence == "interim_overall")) scope <- rep("interim_overall", nrow(rows))
  }
  if (!any(scope == "interim_overall")) return(uefa_euro_sim_manifest_failure("phase15_interim_overall_projection_missing", projected_rankings = rows, manifest = manifest))
  relevant <- scope == "interim_overall"
  if (any(relevant & nzchar(stage) & stage != "interim_overall")) return(uefa_euro_sim_manifest_failure("phase15_ranking_stage_not_interim_overall", projected_rankings = rows, manifest = manifest))
  derived <- relevant & (!nzchar(stage) | is.na(stage)) & interim_evidence == "interim_overall"
  stage[derived] <- "interim_overall"
  if (any(relevant & stage != "interim_overall")) return(uefa_euro_sim_manifest_failure("phase15_ranking_stage_not_interim_overall", projected_rankings = rows, manifest = manifest))
  rows$ranking_scope <- scope
  rows$ranking_stage <- stage
  rows <- rows[relevant, , drop = FALSE]
  if (!nrow(rows)) return(uefa_euro_sim_manifest_failure("phase15_interim_overall_projection_missing", projected_rankings = rows, manifest = manifest))
  rank_field <- intersect(c("interim_overall_rank", "interim_rank", "rank"), names(rows))
  if (!length(rank_field)) return(uefa_euro_sim_manifest_failure("phase15_interim_overall_rank_missing", projected_rankings = rows, manifest = manifest))
  rows$interim_overall_rank <- suppressWarnings(as.integer(as.character(rows[[rank_field[[1L]]]])))
  if (any(is.na(rows$interim_overall_rank) | rows$interim_overall_rank < 1L) || anyDuplicated(rows$interim_overall_rank)) return(uefa_euro_sim_manifest_failure("phase15_interim_overall_rank_missing_or_duplicate", projected_rankings = rows, manifest = manifest))
  if (anyDuplicated(rows$team_id)) return(uefa_euro_sim_manifest_failure("phase15_team_id_duplicate", projected_rankings = rows, manifest = manifest))
  for (field in c("ranking_status", "block_status", "suppression_reason", "eligibility_status")) {
    if (!field %in% names(rows)) next
    values <- tolower(trimws(as.character(rows[[field]])))
    blocked <- values %in% c("blocked", "unresolved", "suppressed", "missing", "unresolved_external_eligibility")
    if (any(blocked)) return(uefa_euro_sim_manifest_failure(paste0("phase15_", field, "_unresolved"), projected_rankings = rows, manifest = manifest))
  }
  lineage <- uefa_euro_sim_normalized_lineage(registered, record, rows)
  if (!nzchar(lineage$source_bundle_id) || !uefa_euro_sim_hash_valid(lineage$source_bundle_sha256)) return(uefa_euro_sim_manifest_failure("phase15_source_lineage_incomplete", projected_rankings = rows, manifest = manifest))
  if (!nzchar(lineage$ruleset_version) || !uefa_euro_sim_hash_valid(lineage$ruleset_sha256)) return(uefa_euro_sim_manifest_failure("phase15_rules_lineage_incomplete", projected_rankings = rows, manifest = manifest))
  if (!nzchar(lineage$source_manifest_sha256) || !uefa_euro_sim_hash_valid(lineage$source_manifest_sha256)) return(uefa_euro_sim_manifest_failure("phase15_manifest_lineage_incomplete", projected_rankings = rows, manifest = manifest))
  if ("source_bundle_id" %in% names(rows) && any(nzchar(as.character(rows$source_bundle_id)) & as.character(rows$source_bundle_id) != lineage$source_bundle_id)) return(uefa_euro_sim_manifest_failure("phase15_source_bundle_mismatch", projected_rankings = rows, manifest = manifest))
  if ("ruleset_version" %in% names(rows) && any(nzchar(as.character(rows$ruleset_version)) & as.character(rows$ruleset_version) != lineage$ruleset_version)) return(uefa_euro_sim_manifest_failure("phase15_ruleset_mismatch", projected_rankings = rows, manifest = manifest))
  rows$edition_id <- "uefa_nations_league_2026_27"
  rows$source_bundle_id <- lineage$source_bundle_id
  rows$source_bundle_sha256 <- lineage$source_bundle_sha256
  rows$source_artifact_id <- if ("source_artifact_id" %in% names(rows)) as.character(rows$source_artifact_id) else rep("", nrow(rows))
  rows$source_artifact_id[is.na(rows$source_artifact_id) | !nzchar(rows$source_artifact_id)] <- lineage$source_artifact_id
  rows$source_manifest_sha256 <- lineage$source_manifest_sha256
  rows$source_artifact_path <- lineage$source_artifact_path
  rows$source_artifact_content_sha256 <- lineage$source_artifact_content_sha256
  rows$ruleset_version <- lineage$ruleset_version
  rows$ruleset_sha256 <- lineage$ruleset_sha256
  if (!"projection_run_id" %in% names(rows)) rows$projection_run_id <- uefa_euro_sim_field(projected_rankings, c("projection_run_id"))
  rows <- rows[order(rows$interim_overall_rank, rows$team_id, method = "radix"), , drop = FALSE]
  row.names(rows) <- NULL
  attr(rows, "handoff_status") <- "resolved"
  attr(rows, "handoff_lineage") <- lineage
  rows
}

uefa_euro_validate_nl_eligibility_handoff <- function(
    projection, required_team_ids = NULL, source_bundle_id = NULL, ruleset_version = NULL) {
  if (is.list(projection) && !is.data.frame(projection)) {
    if (identical(projection$status, "unresolved_external_eligibility") || isFALSE(projection$valid)) {
      return(uefa_euro_sim_status_result("unresolved_external_eligibility", projection$reason %||% "phase15_handoff_unresolved"))
    }
    projection <- projection$projection %||% projection$rows
  }
  if (!is.data.frame(projection) || !nrow(projection)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_interim_projection_missing"))
  rows <- as.data.frame(projection, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("team_id", "ranking_scope", "ranking_stage", "interim_overall_rank", "source_bundle_id", "source_bundle_sha256", "source_manifest_sha256", "ruleset_version", "ruleset_sha256")
  missing <- setdiff(required, names(rows))
  if (length(missing)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", paste0("phase15_handoff_missing_", paste(missing, collapse = "_"))))
  ids <- trimws(as.character(rows$team_id))
  ranks <- suppressWarnings(as.integer(as.character(rows$interim_overall_rank)))
  if (any(is.na(ids) | !nzchar(ids)) || anyDuplicated(ids)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_team_id_missing_or_duplicate"))
  if (any(as.character(rows$ranking_scope) != "interim_overall") || any(as.character(rows$ranking_stage) != "interim_overall")) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_ranking_stage_not_interim_overall"))
  if (any(is.na(ranks) | ranks < 1L) || anyDuplicated(ranks)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_interim_overall_rank_missing_or_duplicate"))
  if (any(!vapply(rows$source_bundle_sha256, uefa_euro_sim_hash_valid, logical(1))) || any(!vapply(rows$source_manifest_sha256, uefa_euro_sim_hash_valid, logical(1))) || any(!vapply(rows$ruleset_sha256, uefa_euro_sim_hash_valid, logical(1)))) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_handoff_lineage_invalid"))
  if (!is.null(source_bundle_id) && any(as.character(rows$source_bundle_id) != as.character(source_bundle_id))) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_source_bundle_mismatch"))
  if (!is.null(ruleset_version) && any(as.character(rows$ruleset_version) != as.character(ruleset_version))) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_ruleset_mismatch"))
  if (!is.null(required_team_ids) && any(!as.character(required_team_ids) %in% ids)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_required_team_missing"))
  for (field in c("eligibility_status", "ranking_status", "block_status", "suppression_reason")) {
    if (!field %in% names(rows)) next
    values <- tolower(trimws(as.character(rows[[field]])))
    if (any(values %in% c("blocked", "unresolved", "suppressed", "missing", "unresolved_external_eligibility", "missing_rule_input"))) return(uefa_euro_sim_status_result("unresolved_external_eligibility", paste0("phase15_", field, "_unresolved")))
  }
  rows <- rows[order(ranks, ids, method = "radix"), , drop = FALSE]
  lineage <- attr(projection, "handoff_lineage")
  if (is.null(lineage)) lineage <- list(
    source_bundle_id = as.character(rows$source_bundle_id[[1L]]), source_bundle_sha256 = as.character(rows$source_bundle_sha256[[1L]]),
    source_manifest_sha256 = as.character(rows$source_manifest_sha256[[1L]]), ruleset_version = as.character(rows$ruleset_version[[1L]]),
    ruleset_sha256 = as.character(rows$ruleset_sha256[[1L]])
  )
  list(
    valid = TRUE, status = "resolved", eligibility_status = "resolved", reason = "",
    projection = rows, rows = rows, team_ids = ids, qualifying_team_ids = ids,
    source_bundle_id = as.character(rows$source_bundle_id[[1L]]), source_bundle_sha256 = as.character(rows$source_bundle_sha256[[1L]]),
    source_manifest_sha256 = as.character(rows$source_manifest_sha256[[1L]]), ruleset_version = as.character(rows$ruleset_version[[1L]]),
    ruleset_sha256 = as.character(rows$ruleset_sha256[[1L]]), lineage = lineage
  )
}

uefa_euro_sim_row_value <- function(row, fields, default = NA) {
  if (is.data.frame(row)) {
    for (field in fields) {
      if (field %in% names(row) && nrow(row)) return(row[[field]][[1L]])
    }
    return(default)
  }
  if (is.list(row)) {
    for (field in fields) {
      if (!is.null(row[[field]]) && length(row[[field]])) return(row[[field]][[1L]])
    }
  }
  default
}

uefa_euro_sim_numeric_value <- function(row, fields, default = NA_real_) {
  value <- suppressWarnings(as.numeric(uefa_euro_sim_row_value(row, fields, default)))
  if (!length(value) || is.na(value[[1L]])) default else value[[1L]]
}

uefa_euro_sim_probability_vector <- function(probabilities = NULL, forecast = NULL) {
  if (is.null(probabilities)) probabilities <- forecast
  if (is.data.frame(probabilities)) {
    if (nrow(probabilities) != 1L) stop("EURO calibrated probabilities require one forecast row", call. = FALSE)
    if ("forecast_status" %in% names(probabilities) && uefa_euro_sim_scalar(probabilities$forecast_status) != "available") {
      stop("EURO calibrated forecast is unavailable", call. = FALSE)
    }
    if ("primary_probability_view" %in% names(probabilities) && uefa_euro_sim_scalar(probabilities$primary_probability_view) != "calibrated_1x2") {
      stop("EURO forecast does not expose calibrated_1x2 authority", call. = FALSE)
    }
    probabilities <- probabilities[1L, , drop = FALSE]
    if (all(c("p_home", "p_draw", "p_away") %in% names(probabilities))) {
      probabilities <- c(
        p_home = probabilities$p_home[[1L]],
        p_draw = probabilities$p_draw[[1L]],
        p_away = probabilities$p_away[[1L]]
      )
    }
  }
  if (is.list(probabilities) && !is.data.frame(probabilities)) {
    fields <- c("p_home", "p_draw", "p_away")
    if (all(fields %in% names(probabilities))) probabilities <- unlist(probabilities[fields], use.names = FALSE)
  }
  if (is.atomic(probabilities) && all(c("p_home", "p_draw", "p_away") %in% names(probabilities))) {
    probabilities <- probabilities[c("p_home", "p_draw", "p_away")]
  } else if (is.atomic(probabilities) && all(c("home", "draw", "away") %in% names(probabilities))) {
    probabilities <- probabilities[c("home", "draw", "away")]
  } else {
    probabilities <- suppressWarnings(as.numeric(probabilities))
  }
  probabilities <- suppressWarnings(as.numeric(probabilities))
  if (length(probabilities) != 3L || any(!is.finite(probabilities)) || any(probabilities < 0) || any(probabilities > 1)) {
    stop("EURO calibrated probabilities must be finite and non-negative", call. = FALSE)
  }
  if (abs(sum(probabilities) - 1) > 1e-10) stop("EURO calibrated probabilities must sum to one", call. = FALSE)
  names(probabilities) <- c("home", "draw", "away")
  probabilities
}

uefa_euro_sim_outcome_class <- function(home_goals, away_goals) {
  ifelse(home_goals > away_goals, "home", ifelse(home_goals == away_goals, "draw", "away"))
}

uefa_euro_sim_normalize_outcome <- function(value) {
  value <- tolower(trimws(as.character(value)))
  value[value %in% c("home_win", "home-win", "win", "h")] <- "home"
  value[value %in% c("away_win", "away-win", "loss", "a")] <- "away"
  value[value %in% c("tie", "d")] <- "draw"
  if (length(value) != 1L || is.na(value) || !value %in% c("home", "draw", "away")) stop("EURO outcome must be home, draw, or away", call. = FALSE)
  value
}

uefa_euro_sim_grid <- function(score_distribution, expected_fixture_id = NULL, expected_score_distribution_id = NULL) {
  if (is.list(score_distribution) && !is.data.frame(score_distribution)) {
    fields <- intersect(c("score_distributions", "score_distribution", "grid"), names(score_distribution))
    if (length(fields)) score_distribution <- score_distribution[[fields[[1L]]]]
  }
  if (!is.data.frame(score_distribution) || !nrow(score_distribution)) stop("EURO score grid must be a non-empty data frame", call. = FALSE)
  required <- c("home_goals", "away_goals", "probability")
  missing <- setdiff(required, names(score_distribution))
  if (length(missing)) stop("EURO score grid is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  grid <- as.data.frame(score_distribution, stringsAsFactors = FALSE, check.names = FALSE)
  grid$home_goals <- suppressWarnings(as.numeric(as.character(grid$home_goals)))
  grid$away_goals <- suppressWarnings(as.numeric(as.character(grid$away_goals)))
  grid$probability <- suppressWarnings(as.numeric(as.character(grid$probability)))
  if (any(!is.finite(grid$home_goals) | !is.finite(grid$away_goals) | grid$home_goals < 0 | grid$away_goals < 0 | grid$home_goals != floor(grid$home_goals) | grid$away_goals != floor(grid$away_goals))) stop("EURO score grid has invalid goal support", call. = FALSE)
  if (any(grid$home_goals > 40 | grid$away_goals > 40)) stop("EURO score grid exceeds bounded support G=40", call. = FALSE)
  if (any(!is.finite(grid$probability) | grid$probability < 0) || abs(sum(grid$probability) - 1) > 1e-10) stop("EURO score grid must be normalized", call. = FALSE)
  if ("normalized" %in% names(grid) && any(!as.logical(grid$normalized))) stop("EURO score grid is not marked normalized", call. = FALSE)
  if (anyDuplicated(paste(grid$home_goals, grid$away_goals, sep = "::"))) stop("EURO score grid has duplicate score cells", call. = FALSE)
  if (!is.null(expected_fixture_id) && "fixture_id" %in% names(grid)) {
    ids <- trimws(as.character(grid$fixture_id)); ids <- ids[!is.na(ids) & nzchar(ids)]
    if (length(ids) && any(ids != as.character(expected_fixture_id))) stop("EURO score grid has a foreign fixture identity", call. = FALSE)
  }
  if (!is.null(expected_score_distribution_id)) {
    if (!"score_distribution_id" %in% names(grid)) stop("EURO score grid is missing score_distribution_id", call. = FALSE)
    ids <- unique(trimws(as.character(grid$score_distribution_id)))
    if (length(ids) != 1L || is.na(ids[[1L]]) || ids[[1L]] != as.character(expected_score_distribution_id)) stop("EURO score grid identity does not match forecast", call. = FALSE)
  }
  grid$outcome_class <- uefa_euro_sim_outcome_class(grid$home_goals, grid$away_goals)
  grid
}

uefa_euro_sample_calibrated_outcome <- function(probabilities = NULL, n = 1L, seed = NULL, forecast = NULL) {
  probabilities <- uefa_euro_sim_probability_vector(probabilities, forecast)
  n <- suppressWarnings(as.integer(n))
  if (length(n) != 1L || is.na(n) || n < 1L) stop("EURO outcome sample size must be positive", call. = FALSE)
  uefa_euro_sim_with_seed(seed, function() sample(c("home", "draw", "away"), size = n, replace = TRUE, prob = probabilities))
}

uefa_euro_sim_condition_grid <- function(grid, outcome_class, calibrated_probabilities) {
  outcome_class <- uefa_euro_sim_normalize_outcome(outcome_class)
  calibrated_probabilities <- uefa_euro_sim_probability_vector(calibrated_probabilities)
  grid <- uefa_euro_sim_grid(grid)
  indexes <- which(grid$outcome_class == outcome_class)
  if (!length(indexes) || sum(grid$probability[indexes]) <= 0) stop("EURO score grid cannot condition the calibrated outcome", call. = FALSE)
  original_probability <- grid$probability
  grid$probability <- 0
  grid$probability[indexes] <- original_probability[indexes] / sum(original_probability[indexes])
  grid
}

uefa_euro_sim_extract_table <- function(value, candidates = character()) {
  if (is.null(value)) return(NULL)
  if (is.data.frame(value)) return(as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE))
  if (!is.list(value)) return(NULL)
  fields <- intersect(candidates, names(value))
  if (length(fields)) return(uefa_euro_sim_extract_table(value[[fields[[1L]]]], candidates))
  frames <- value[vapply(value, is.data.frame, logical(1))]
  if (length(frames)) {
    names_frames <- names(frames)
    all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
    frames <- lapply(seq_along(frames), function(index) {
      frame <- as.data.frame(frames[[index]], stringsAsFactors = FALSE, check.names = FALSE)
      if (!is.null(names_frames) && nzchar(names_frames[[index]]) && !"group_id" %in% names(frame)) frame$group_id <- names_frames[[index]]
      for (field in setdiff(all_names, names(frame))) frame[[field]] <- NA_character_
      frame[, all_names, drop = FALSE]
    })
    return(do.call(rbind, frames))
  }
  NULL
}

uefa_euro_sim_find_forecast <- function(forecasts, match) {
  table <- uefa_euro_sim_extract_table(forecasts, c("forecasts", "forecast", "rows", "table"))
  if (is.null(table) || !nrow(table)) return(NULL)
  table <- as.data.frame(table, stringsAsFactors = FALSE, check.names = FALSE)
  fixture_id <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("fixture_id", "match_id", "source_fixture_id"), ""))
  home <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("home_team_id", "team_a"), ""))
  away <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("away_team_id", "team_b"), ""))
  candidates <- seq_len(nrow(table))
  if (nzchar(fixture_id) && "fixture_id" %in% names(table)) {
    matched <- which(as.character(table$fixture_id) == fixture_id)
    if (length(matched)) candidates <- matched
  }
  if (length(candidates) > 1L && nzchar(home) && "home_team_id" %in% names(table)) candidates <- candidates[as.character(table$home_team_id[candidates]) == home]
  if (length(candidates) > 1L && nzchar(away) && "away_team_id" %in% names(table)) candidates <- candidates[as.character(table$away_team_id[candidates]) == away]
  if (!length(candidates)) {
    if (nrow(table) != 1L) return(NULL)
    candidates <- 1L
  }
  row <- table[candidates[[1L]], , drop = FALSE]
  if ("forecast_status" %in% names(row) && uefa_euro_sim_scalar(row$forecast_status) != "available") return(NULL)
  if ("primary_probability_view" %in% names(row) && uefa_euro_sim_scalar(row$primary_probability_view) != "calibrated_1x2") return(NULL)
  if (nzchar(home) && "home_team_id" %in% names(row) && !nzchar(uefa_euro_sim_scalar(row$home_team_id))) row$home_team_id <- home
  if (nzchar(away) && "away_team_id" %in% names(row) && !nzchar(uefa_euro_sim_scalar(row$away_team_id))) row$away_team_id <- away
  if (nzchar(fixture_id) && "fixture_id" %in% names(row) && !nzchar(uefa_euro_sim_scalar(row$fixture_id))) row$fixture_id <- fixture_id
  row
}

uefa_euro_sim_find_score_distribution <- function(score_distributions, match, forecast = NULL, direct = NULL) {
  table <- direct %||% uefa_euro_sim_extract_table(score_distributions, c("score_distributions", "score_distribution", "grid", "rows", "table"))
  if (is.null(table) || !is.data.frame(table) || !nrow(table)) return(NULL)
  expected_fixture <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("fixture_id", "match_id"), ""))
  expected_score_id <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(forecast, c("score_distribution_id"), ""))
  if (nzchar(expected_score_id) && "score_distribution_id" %in% names(table)) {
    matching <- table[as.character(table$score_distribution_id) == expected_score_id, , drop = FALSE]
    if (nrow(matching)) table <- matching
  }
  fixture_matched <- FALSE
  if (nzchar(expected_fixture) && "fixture_id" %in% names(table)) {
    matching <- table[as.character(table$fixture_id) == expected_fixture, , drop = FALSE]
    if (nrow(matching)) {
      table <- matching
      fixture_matched <- TRUE
    }
  }
  uefa_euro_sim_grid(table, expected_fixture_id = if (fixture_matched) expected_fixture else NULL, expected_score_distribution_id = if (nzchar(expected_score_id)) expected_score_id else NULL)
}

uefa_euro_sim_match_authority <- function(match, forecast = NULL, score_distribution = NULL, forecasts = NULL, score_distributions = NULL) {
  row <- if (!is.null(forecast)) uefa_euro_sim_find_forecast(forecast, match) else uefa_euro_sim_find_forecast(forecasts, match)
  if (is.null(row) && is.data.frame(forecast) && nrow(forecast) == 1L) row <- forecast
  if (is.null(row)) return(list(valid = FALSE, status = "blocked", reason = "forecast_authority_missing"))
  grid <- tryCatch(
    uefa_euro_sim_find_score_distribution(score_distributions, match, row, direct = score_distribution),
    error = function(error) NULL
  )
  if (is.null(grid)) return(list(valid = FALSE, status = "blocked", reason = "score_distribution_authority_missing", forecast = row))
  probabilities <- tryCatch(uefa_euro_sim_probability_vector(forecast = row), error = function(error) NULL)
  if (is.null(probabilities)) return(list(valid = FALSE, status = "blocked", reason = "calibrated_forecast_authority_missing", forecast = row, score_distribution = grid))
  list(valid = TRUE, status = "available", forecast = row, score_distribution = grid, probabilities = probabilities,
    lineage = list(
      primary_probability_view = "calibrated_1x2",
      model_release_id = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "model_release_id", "")),
      model_id = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "model_id", "")),
      model_sha256 = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "model_sha256", "")),
      release_manifest_sha256 = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "release_manifest_sha256", "")),
      model_data_cutoff = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "model_data_cutoff", "")),
      source_bundle_id = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "source_bundle_id", "")),
      source_bundle_sha256 = uefa_euro_sim_scalar(uefa_euro_sim_row_value(row, "source_bundle_sha256", ""))
    )
  )
}

uefa_euro_sim_sample_match_score <- function(match, authority, seed = NULL) {
  outcome <- uefa_euro_sample_calibrated_outcome(forecast = authority$forecast, seed = seed)[[1L]]
  conditional <- uefa_euro_sim_condition_grid(authority$score_distribution, outcome, authority$probabilities)
  selected <- uefa_euro_sim_with_seed(uefa_euro_sim_seed_for(seed %||% 1L, "score", uefa_euro_sim_row_value(match, c("fixture_id", "match_id"), "")), function() {
    sample.int(nrow(conditional), size = 1L, prob = conditional$probability)
  })
  row <- conditional[selected, , drop = FALSE]
  list(
    regulation_home = as.integer(row$home_goals[[1L]]), regulation_away = as.integer(row$away_goals[[1L]]),
    final_home = as.integer(row$home_goals[[1L]]), final_away = as.integer(row$away_goals[[1L]]),
    outcome = outcome, score_distribution_id = uefa_euro_sim_scalar(uefa_euro_sim_row_value(authority$forecast, "score_distribution_id", ""))
  )
}

uefa_euro_sim_resolution <- function(status = "completed", winner = NA_character_, loser = NA_character_, resolution = "unresolved", ...) {
  list(
    status = status, stage_status = status, winner_team_id = winner, loser_team_id = loser,
    winner = winner, loser = loser, resolution = resolution, resolution_method = resolution, ...
  )
}

uefa_euro_sim_penalty_winner <- function(home_team_id, away_team_id, row = NULL, seed = NULL, penalty_winner = NULL) {
  explicit <- penalty_winner %||% uefa_euro_sim_row_value(row, c("penalty_winner_team_id", "shootout_winner_team_id"), NA_character_)
  explicit <- uefa_euro_sim_scalar(explicit, "")
  if (explicit %in% c(home_team_id, away_team_id)) return(explicit)
  home_shootout <- uefa_euro_sim_numeric_value(row, c("penalty_shootout_home_goals", "shootout_home_goals"))
  away_shootout <- uefa_euro_sim_numeric_value(row, c("penalty_shootout_away_goals", "shootout_away_goals"))
  if (is.finite(home_shootout) && is.finite(away_shootout) && home_shootout != away_shootout) return(if (home_shootout > away_shootout) home_team_id else away_team_id)
  uefa_euro_sim_with_seed(seed, function() sample(c(home_team_id, away_team_id), size = 1L))
}

uefa_euro_resolve_single_leg <- function(
    pair = NULL, match = NULL, mode = c("extra_time_then_penalties", "penalties_without_extra_time"),
    seed = NULL, rules = uefa_euro_2026_28_rules(), penalty_winner = NULL,
    extra_time_score = NULL, tie_break_policy = NULL, forecast = NULL,
    score_distribution = NULL, forecasts = NULL, score_distributions = NULL) {
  match <- match %||% pair
  if (is.list(match) && !is.data.frame(match)) match <- as.data.frame(match, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(match) || nrow(match) != 1L) stop("EURO single-leg resolution requires one match row", call. = FALSE)
  mode <- tie_break_policy %||% mode[[1L]]
  mode <- tolower(as.character(mode[[1L]]))
  mode[mode %in% c("final", "semi_final", "semi-final", "extra_time", "extra-time-then-penalties")] <- "extra_time_then_penalties"
  mode[mode %in% c("third_place", "third-place", "direct_penalty", "direct-penalty", "penalties", "penalties-without-extra-time")] <- "penalties_without_extra_time"
  if (!mode %in% c("extra_time_then_penalties", "penalties_without_extra_time")) stop("EURO single-leg resolution mode is unsupported", call. = FALSE)
  home <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("home_team_id", "team_a"), ""))
  away <- uefa_euro_sim_scalar(uefa_euro_sim_row_value(match, c("away_team_id", "team_b"), ""))
  if (!nzchar(home) || !nzchar(away) || identical(home, away)) stop("EURO single-leg resolution requires two stable team IDs", call. = FALSE)
  authority <- uefa_euro_sim_match_authority(match, forecast, score_distribution, forecasts, score_distributions)
  regulation_home <- uefa_euro_sim_numeric_value(match, c("regulation_home_goals", "home_goals", "home_score"))
  regulation_away <- uefa_euro_sim_numeric_value(match, c("regulation_away_goals", "away_goals", "away_score"))
  sampled <- NULL
  if (!is.finite(regulation_home) || !is.finite(regulation_away)) {
    if (!isTRUE(authority$valid)) return(uefa_euro_sim_resolution("blocked", resolution = "unresolved", unresolved_reason = authority$reason, home_team_id = home, away_team_id = away))
    sampled <- uefa_euro_sim_sample_match_score(match, authority, seed)
    regulation_home <- sampled$regulation_home; regulation_away <- sampled$regulation_away
  }
  extra_home <- uefa_euro_sim_numeric_value(match, c("extra_time_home_goals", "extra_home_goals"))
  extra_away <- uefa_euro_sim_numeric_value(match, c("extra_time_away_goals", "extra_away_goals"))
  if (!is.null(extra_time_score)) {
    extra <- suppressWarnings(as.numeric(extra_time_score))
    if (length(extra) != 2L || any(!is.finite(extra)) || any(extra < 0 | extra != floor(extra))) stop("EURO extra-time score is invalid", call. = FALSE)
    extra_home <- extra[[1L]]; extra_away <- extra[[2L]]
  }
  final_home <- uefa_euro_sim_numeric_value(match, c("final_home_goals", "home_final_goals"), NA_real_)
  final_away <- uefa_euro_sim_numeric_value(match, c("final_away_goals", "away_final_goals"), NA_real_)
  resolution <- "regulation"; extra_used <- FALSE; penalty_used <- FALSE
  if (is.finite(final_home) && is.finite(final_away)) {
    outcome_home <- final_home; outcome_away <- final_away; resolution <- if (final_home == regulation_home && final_away == regulation_away) "regulation" else "provided_final"
  } else {
    outcome_home <- regulation_home; outcome_away <- regulation_away
    if (outcome_home == outcome_away && identical(mode, "extra_time_then_penalties")) {
      if (is.finite(extra_home) && is.finite(extra_away)) {
        outcome_home <- outcome_home + extra_home; outcome_away <- outcome_away + extra_away; extra_used <- TRUE; resolution <- "extra_time"
      }
    }
    if (outcome_home == outcome_away) {
      penalty_used <- TRUE
      winner <- uefa_euro_sim_penalty_winner(home, away, match, uefa_euro_sim_seed_for(seed %||% 1L, "penalties", home, away), penalty_winner)
      resolution <- "penalties"
    }
  }
  winner <- if (outcome_home > outcome_away) home else if (outcome_away > outcome_home) away else if (exists("winner", inherits = FALSE)) winner else uefa_euro_sim_penalty_winner(home, away, match, uefa_euro_sim_seed_for(seed %||% 1L, "penalties", home, away), penalty_winner)
  lineage <- if (isTRUE(authority$valid)) authority$lineage else list()
  uefa_euro_sim_resolution(
    status = "completed", winner = winner, loser = setdiff(c(home, away), winner)[[1L]], resolution = resolution,
    home_team_id = home, away_team_id = away, regulation_home_goals = as.integer(regulation_home), regulation_away_goals = as.integer(regulation_away),
    final_home_goals = as.integer(outcome_home), final_away_goals = as.integer(outcome_away), extra_time_used = extra_used,
    penalty_used = penalty_used, penalty_winner_team_id = if (penalty_used) winner else NA_character_,
    primary_probability_view = if (isTRUE(authority$valid)) "calibrated_1x2" else "", path = "single_leg",
    model_release_id = lineage$model_release_id %||% "", model_id = lineage$model_id %||% "", model_sha256 = lineage$model_sha256 %||% "",
    model_data_cutoff = lineage$model_data_cutoff %||% "", source_bundle_id = lineage$source_bundle_id %||% "", source_bundle_sha256 = lineage$source_bundle_sha256 %||% "",
    ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
  )
}

uefa_euro_resolve_two_leg_tie <- function(
    pair, seed = NULL, rules = uefa_euro_2026_28_rules(), penalty_winner = NULL,
    second_leg_extra_time = NULL, forecasts = NULL, score_distributions = NULL,
    forecast = NULL, score_distribution = NULL) {
  if (is.list(pair) && !is.data.frame(pair)) pair <- uefa_euro_sim_extract_table(pair, c("legs", "pair", "matches", "rows"))
  if (!is.data.frame(pair) || nrow(pair) != 2L) stop("EURO two-leg tie requires exactly two leg rows", call. = FALSE)
  if (!"leg_number" %in% names(pair)) pair$leg_number <- seq_len(nrow(pair))
  legs <- suppressWarnings(as.integer(as.character(pair$leg_number)))
  if (anyDuplicated(legs) || !setequal(legs, 1:2)) stop("EURO two-leg tie requires leg 1 and leg 2 exactly once", call. = FALSE)
  pair <- pair[order(legs, method = "radix"), , drop = FALSE]
  home <- trimws(as.character(pair$home_team_id)); away <- trimws(as.character(pair$away_team_id))
  if (any(is.na(home) | !nzchar(home) | is.na(away) | !nzchar(away) | home == away) || length(unique(c(home, away))) != 2L) stop("EURO two-leg tie requires two stable participants", call. = FALSE)
  if (!setequal(home, away)) stop("EURO two-leg tie must host each participant once", call. = FALSE)
  resolve_leg <- function(index) {
    row <- pair[index, , drop = FALSE]
    authority_forecast <- if (index == 1L && !is.null(forecast)) forecast else if (index == 2L && !is.null(forecast)) forecast else forecasts
    authority_grid <- if (index == 1L && !is.null(score_distribution)) score_distribution else if (index == 2L && !is.null(score_distribution)) score_distribution else score_distributions
    authority <- uefa_euro_sim_match_authority(row, authority_forecast, authority_grid, forecasts, score_distributions)
    regulation_home <- uefa_euro_sim_numeric_value(row, c("regulation_home_goals", "home_goals", "home_score"))
    regulation_away <- uefa_euro_sim_numeric_value(row, c("regulation_away_goals", "away_goals", "away_score"))
    if (!is.finite(regulation_home) || !is.finite(regulation_away)) {
      if (!isTRUE(authority$valid)) return(list(valid = FALSE, reason = authority$reason, authority = authority))
      sampled <- uefa_euro_sim_sample_match_score(row, authority, uefa_euro_sim_seed_for(seed %||% 1L, "leg", index, home[[index]], away[[index]]))
      regulation_home <- sampled$regulation_home; regulation_away <- sampled$regulation_away
    }
    final_home <- uefa_euro_sim_numeric_value(row, c("final_home_goals", "home_final_goals"), NA_real_)
    final_away <- uefa_euro_sim_numeric_value(row, c("final_away_goals", "away_final_goals"), NA_real_)
    if (!is.finite(final_home)) final_home <- regulation_home
    if (!is.finite(final_away)) final_away <- regulation_away
    list(valid = TRUE, regulation_home = regulation_home, regulation_away = regulation_away, final_home = final_home, final_away = final_away, row = row, authority = authority)
  }
  first <- resolve_leg(1L); second <- resolve_leg(2L)
  if (!isTRUE(first$valid) || !isTRUE(second$valid)) return(uefa_euro_sim_resolution("blocked", resolution = "unresolved", unresolved_reason = paste(unique(c(first$reason, second$reason)), collapse = ";"), home_team_id = home[[1L]], away_team_id = away[[1L]], path = "two_leg"))
  totals <- setNames(c(0, 0), sort(unique(c(home, away)), method = "radix"))
  totals[home[[1L]]] <- totals[home[[1L]]] + first$final_home; totals[away[[1L]]] <- totals[away[[1L]]] + first$final_away
  totals[home[[2L]]] <- totals[home[[2L]]] + second$regulation_home; totals[away[[2L]]] <- totals[away[[2L]]] + second$regulation_away
  aggregate_before_extra <- totals; resolution <- "aggregate"; extra_used <- FALSE; penalty_used <- FALSE
  if (diff(range(totals)) == 0) {
    extra <- c(uefa_euro_sim_numeric_value(pair[2L, , drop = FALSE], c("extra_time_home_goals", "extra_home_goals")), uefa_euro_sim_numeric_value(pair[2L, , drop = FALSE], c("extra_time_away_goals", "extra_away_goals")))
    if (!is.null(second_leg_extra_time)) extra <- suppressWarnings(as.numeric(second_leg_extra_time))
    if (length(extra) == 2L && all(is.finite(extra)) && all(extra >= 0) && all(extra == floor(extra))) {
      totals[home[[2L]]] <- totals[home[[2L]]] + extra[[1L]]; totals[away[[2L]]] <- totals[away[[2L]]] + extra[[2L]]; resolution <- "extra_time"; extra_used <- TRUE
    }
  }
  if (diff(range(totals)) == 0) {
    penalty_used <- TRUE; resolution <- "penalties"
    winner <- uefa_euro_sim_penalty_winner(home[[2L]], away[[2L]], pair[2L, , drop = FALSE], uefa_euro_sim_seed_for(seed %||% 1L, "two-leg-penalties", home, away), penalty_winner)
  } else winner <- names(which.max(totals))[[1L]]
  loser <- setdiff(names(totals), winner)[[1L]]
  authority <- first$authority$valid %||% FALSE
  lineage <- if (isTRUE(authority)) first$authority$lineage else list()
  uefa_euro_sim_resolution(
    status = "completed", winner = winner, loser = loser, resolution = resolution, path = "two_leg",
    first_leg = first, second_leg = second, aggregate_goals = totals, aggregate_goals_before_extra_time = aggregate_before_extra,
    extra_time_used = extra_used, penalty_used = penalty_used, penalty_winner_team_id = if (penalty_used) winner else NA_character_,
    primary_probability_view = if (isTRUE(authority)) "calibrated_1x2" else "", model_release_id = lineage$model_release_id %||% "",
    model_id = lineage$model_id %||% "", model_sha256 = lineage$model_sha256 %||% "", model_data_cutoff = lineage$model_data_cutoff %||% "",
    source_bundle_id = lineage$source_bundle_id %||% "", source_bundle_sha256 = lineage$source_bundle_sha256 %||% "",
    ruleset_version = rules$ruleset_version, ruleset_sha256 = uefa_euro_ruleset_sha256(rules)
  )
}

uefa_euro_sim_topology_row <- function(topology, current_only = TRUE) {
  if (is.null(topology)) return(NULL)
  if (is.list(topology) && !is.data.frame(topology)) {
    candidate <- topology$topology %||% topology$rows %||% topology$current_topology
    if (!is.null(candidate) && !identical(candidate, topology)) return(uefa_euro_sim_topology_row(candidate, current_only))
  }
  if (!is.data.frame(topology) || !nrow(topology)) return(NULL)
  rows <- as.data.frame(topology, stringsAsFactors = FALSE, check.names = FALSE)
  if (current_only && "current_topology" %in% names(rows)) {
    current <- rows[as.logical(rows$current_topology), , drop = FALSE]
    if (nrow(current)) rows <- current
  }
  rows[1L, , drop = FALSE]
}

uefa_euro_sim_invalid_topology <- function(allocation = NULL, reason = "unsupported_topology", status = "unsupported_topology", ...) {
  topology <- if (is.list(allocation)) allocation$topology else NULL
  list(
    valid = FALSE, status = status, reason = reason, topology_status = "unsupported_topology",
    pool = data.frame(stringsAsFactors = FALSE, check.names = FALSE), playoff_pool = data.frame(stringsAsFactors = FALSE, check.names = FALSE),
    allocation = allocation, topology = topology, pots = data.frame(stringsAsFactors = FALSE, check.names = FALSE), ...
  )
}

uefa_euro_allocate_playoff_pool <- function(
    allocation = NULL, group_rankings = NULL, standings = NULL, runner_ups = NULL,
    hosts = NULL, host_ids = NULL, draw_conditions = NULL, rules = uefa_euro_2026_28_rules(),
    source_bundle_id = NULL, source_artifact_id = NULL) {
  if (is.null(allocation)) {
    rankings <- group_rankings %||% standings
    if (is.list(rankings) && !is.data.frame(rankings)) rankings <- rankings$groups %||% rankings$standings %||% rankings$rows
    if (is.null(rankings)) rankings <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    if (is.null(runner_ups) && is.data.frame(rankings) && nrow(rankings)) {
      rank_field <- intersect(c("group_position", "rank"), names(rankings))
      if (length(rank_field)) {
        runner_ups <- rankings[suppressWarnings(as.integer(as.character(rankings[[rank_field[[1L]]]]))) == 2L, , drop = FALSE]
        if (nrow(runner_ups)) {
          runner_ups$ranking_scope <- "overall"
          runner_ups$ranking_stage <- "article23_best_runners_up"
          runner_ups$article23_rank <- seq_len(nrow(runner_ups))
          runner_ups$overall_rank <- runner_ups$article23_rank
          runner_ups$rank <- runner_ups$article23_rank
          runner_ups$qualification_eligibility_status <- "available"
        }
      }
    }
    allocation <- allocate_euro_places(
      group_rankings = rankings,
      host_ids = hosts %||% host_ids,
      runner_ups = runner_ups,
      draw_conditions = draw_conditions,
      rules = rules
    )
  }
  topology <- uefa_euro_sim_topology_row(allocation$topology)
  draw <- allocation$draw_conditions
  draw_valid <- !is.null(draw) && isTRUE(draw$valid)
  if (!draw_valid) {
    reason <- if (is.null(draw)) "unresolved_draw_conditions;unsupported_topology" else paste(unique(c(draw$reasons, draw$reason, "unsupported_topology")), collapse = ";")
    return(uefa_euro_sim_invalid_topology(allocation, reason = reason, status = "unresolved_draw_conditions", draw_conditions = draw))
  }
  if (is.null(topology) || !isTRUE(allocation$status == "resolved") || !isTRUE(topology$status[[1L]] %in% c("available", "resolved")) || !isTRUE(topology$current_topology[[1L]] %||% TRUE)) {
    reason <- paste(unique(c(allocation$scenario_status, topology$reason %||% "host_place_unresolved", "scenario_preserved")), collapse = ";")
    return(uefa_euro_sim_invalid_topology(allocation, reason = reason, status = "scenario_preserved", draw_conditions = draw))
  }
  ledger <- allocation$qualification_ledger
  pool <- allocation$remaining_playoff_entries
  if (is.null(pool) || !is.data.frame(pool) || !nrow(pool)) {
    pool <- if (is.data.frame(ledger) && nrow(ledger) && "qualification_status" %in% names(ledger)) ledger[as.character(ledger$qualification_status) == "playoff_eligible", , drop = FALSE] else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!is.data.frame(pool)) pool <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(pool)) {
    if (!"team_id" %in% names(pool)) stop("EURO playoff ledger requires stable team_id", call. = FALSE)
    pool$team_id <- trimws(as.character(pool$team_id))
    if (any(is.na(pool$team_id) | !nzchar(pool$team_id)) || anyDuplicated(pool$team_id)) stop("EURO playoff ledger has missing or duplicate team_id", call. = FALSE)
    pool$eligibility_source <- "runner_up"
    pool$fallback_order <- 1L
    pool$path_source <- "best_runner_up_remainder"
    pool <- pool[order(pool$team_id, method = "radix"), , drop = FALSE]
    row.names(pool) <- NULL
  }
  list(
    valid = TRUE, status = "ready", reason = "", topology_status = "available", allocation = allocation,
    topology = topology, pool = pool, playoff_pool = pool, draw_conditions = draw,
    expected_entrant_count = as.integer(topology$entrant_count[[1L]]), places = as.integer(topology$places[[1L]]),
    structure = as.character(topology$structure[[1L]]), reserved_slots_used = as.integer(topology$reserved_slots_used[[1L]]),
    scenario_id = uefa_euro_sim_scalar(allocation$scenario_id, ""), scenario_status = uefa_euro_sim_scalar(allocation$scenario_status, "resolved"),
    source_bundle_id = uefa_euro_sim_scalar(allocation$source_bundle_id, uefa_euro_source_bundle_id()), source_artifact_id = uefa_euro_sim_scalar(allocation$source_artifact_id, ""),
    ruleset_version = uefa_euro_sim_scalar(allocation$ruleset_version, rules$ruleset_version), ruleset_sha256 = uefa_euro_sim_scalar(allocation$ruleset_sha256, uefa_euro_ruleset_sha256(rules))
  )
}

uefa_euro_sim_normalized_handoff <- function(nl_eligibility) {
  if (is.null(nl_eligibility)) return(uefa_euro_sim_status_result("unresolved_external_eligibility", "phase15_handoff_missing"))
  if (is.data.frame(nl_eligibility)) return(uefa_euro_validate_nl_eligibility_handoff(nl_eligibility))
  if (is.list(nl_eligibility) && isTRUE(nl_eligibility$valid) && identical(nl_eligibility$status, "resolved")) {
    return(uefa_euro_validate_nl_eligibility_handoff(nl_eligibility$projection %||% nl_eligibility$rows))
  }
  normalized <- uefa_euro_normalize_nl_interim_projection(handoff = nl_eligibility)
  if (is.data.frame(normalized)) return(uefa_euro_validate_nl_eligibility_handoff(normalized))
  normalized
}

uefa_euro_sim_pool_frame <- function(pool, source = "runner_up", fallback_order = 1L) {
  if (is.null(pool) || !is.data.frame(pool) || !nrow(pool)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  output <- as.data.frame(pool, stringsAsFactors = FALSE, check.names = FALSE)
  if (!"team_id" %in% names(output)) stop("EURO playoff candidate requires team_id", call. = FALSE)
  output$team_id <- trimws(as.character(output$team_id))
  output$eligibility_source <- source
  output$fallback_order <- as.integer(fallback_order)
  if (!"interim_overall_rank" %in% names(output)) {
    rank_field <- intersect(c("rank", "overall_rank", "article23_rank"), names(output))
    output$interim_overall_rank <- if (length(rank_field)) suppressWarnings(as.integer(as.character(output[[rank_field[[1L]]]]))) else seq_len(nrow(output))
  }
  output$interim_overall_rank <- suppressWarnings(as.integer(as.character(output$interim_overall_rank)))
  output
}

uefa_euro_sim_bind_rows <- function(frames) {
  frames <- frames[vapply(frames, function(frame) is.data.frame(frame) && nrow(frame), logical(1))]
  if (!length(frames)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    frame <- as.data.frame(frame, stringsAsFactors = FALSE, check.names = FALSE)
    for (field in setdiff(all_names, names(frame))) frame[[field]] <- NA
    frame[, all_names, drop = FALSE]
  })
  output <- do.call(rbind, frames)
  row.names(output) <- NULL
  output
}

uefa_euro_build_playoff_pots <- function(
    pool = NULL, nl_eligibility = NULL, allocation = NULL, topology = NULL,
    qualified_team_ids = NULL, host_team_ids = NULL, rules = uefa_euro_2026_28_rules(), draw_conditions = NULL) {
  if (is.null(pool) && !is.null(allocation)) pool <- uefa_euro_allocate_playoff_pool(allocation = allocation, draw_conditions = draw_conditions, rules = rules)
  allocation_result <- if (is.list(pool) && !is.data.frame(pool) && !is.null(pool$pool)) pool else NULL
  if (!is.null(allocation_result)) {
    if (!isTRUE(allocation_result$valid)) return(uefa_euro_sim_invalid_topology(allocation_result$allocation, reason = allocation_result$reason, status = allocation_result$status, draw_conditions = allocation_result$draw_conditions))
    allocation <- allocation_result$allocation
    topology <- allocation_result$topology
    pool <- allocation_result$pool
  } else if (is.null(pool) && !is.null(allocation)) {
    allocation_result <- uefa_euro_allocate_playoff_pool(allocation = allocation, draw_conditions = draw_conditions, rules = rules)
    if (!isTRUE(allocation_result$valid)) return(uefa_euro_sim_invalid_topology(allocation, reason = allocation_result$reason, status = allocation_result$status, draw_conditions = allocation_result$draw_conditions))
    topology <- allocation_result$topology; pool <- allocation_result$pool
  }
  if (is.null(topology) && !is.null(allocation)) topology <- uefa_euro_sim_topology_row(allocation$topology)
  topology <- uefa_euro_sim_topology_row(topology)
  if (is.null(topology)) return(uefa_euro_sim_invalid_topology(allocation, reason = "unsupported_topology", status = "unsupported_topology"))
  draw <- if (!is.null(allocation$draw_conditions)) allocation$draw_conditions else if (!is.null(draw_conditions)) validate_euro_draw_conditions(draw_conditions, rules = rules) else NULL
  if (is.null(draw) || !isTRUE(draw$valid)) return(uefa_euro_sim_invalid_topology(allocation, reason = "unresolved_draw_conditions;unsupported_topology", status = "unresolved_draw_conditions", draw_conditions = draw))
  handoff <- uefa_euro_sim_normalized_handoff(nl_eligibility)
  if (!isTRUE(handoff$valid)) return(uefa_euro_sim_invalid_topology(allocation, reason = handoff$reason %||% "phase15_handoff_unresolved", status = "unresolved_external_eligibility", draw_conditions = draw, eligibility = handoff))
  qualified <- unique(trimws(as.character(c(qualified_team_ids, if (is.list(allocation)) allocation$direct_qualifiers$team_id else character()))))
  hosts <- unique(trimws(as.character(c(host_team_ids, if (is.list(allocation) && is.data.frame(allocation$host_slots) && "consumes_capacity" %in% names(allocation$host_slots)) allocation$host_slots$team_id[allocation$host_slots$consumes_capacity %in% TRUE] else character()))))
  excluded <- unique(c(qualified[nzchar(qualified)], hosts[nzchar(hosts)]))
  runner <- uefa_euro_sim_pool_frame(pool, "runner_up", 1L)
  if (nrow(runner)) runner <- runner[!runner$team_id %in% excluded, , drop = FALSE]
  nl <- as.data.frame(handoff$projection, stringsAsFactors = FALSE, check.names = FALSE)
  nl$team_id <- trimws(as.character(nl$team_id))
  if ("group_position" %in% names(nl)) position <- suppressWarnings(as.integer(as.character(nl$group_position))) else position <- rep(1L, nrow(nl))
  league <- if ("league" %in% names(nl)) toupper(trimws(as.character(nl$league))) else rep("", nrow(nl))
  is_group_winner <- is.na(position) | position == 1L
  candidate_sets <- list(
    uefa_euro_sim_pool_frame(nl[league %in% c("A", "B", "C") & is_group_winner, , drop = FALSE], "nations_league_a_c_group_winner", 2L),
    uefa_euro_sim_pool_frame(nl[league == "D" & is_group_winner, , drop = FALSE], "nations_league_d_group_winner", 3L),
    uefa_euro_sim_pool_frame(nl, "nations_league_overall_fallback", 4L)
  )
  candidates <- runner
  for (candidate in candidate_sets) {
    if (!nrow(candidate)) next
    candidate <- candidate[!candidate$team_id %in% excluded & !candidate$team_id %in% candidates$team_id, , drop = FALSE]
    candidates <- uefa_euro_sim_bind_rows(list(candidates, candidate))
  }
  candidates <- uefa_euro_sim_canonical_table(candidates, key = c("fallback_order", "interim_overall_rank", "team_id"))
  entrant_count <- suppressWarnings(as.integer(topology$entrant_count[[1L]]))
  if (nrow(candidates) > entrant_count) candidates <- candidates[seq_len(entrant_count), , drop = FALSE]
  if (nrow(candidates) < entrant_count) return(list(
    valid = FALSE, status = "playoff_pool_incomplete", reason = paste0("playoff_entrant_count_", nrow(candidates), "_of_", entrant_count),
    topology_status = "available", topology = topology, pool = candidates, playoff_pool = candidates, pots = data.frame(stringsAsFactors = FALSE, check.names = FALSE),
    draw_conditions = draw, eligibility = handoff, allocation = allocation
  ))
  if (as.character(topology$stage_format[[1L]] %||% topology$structure[[1L]]) %in% c("home_and_away_tie", "home-and-away", "two_leg", "two_leg_tie") || as.integer(topology$reserved_slots_used[[1L]]) == 0L) {
    candidates$pot <- rep(c("pot_1", "pot_2"), each = entrant_count / 2L)
    candidates$path_id <- c(seq_len(entrant_count / 2L), seq_len(entrant_count / 2L))
  } else {
    paths <- as.integer(topology$places[[1L]])
    candidates$path_id <- rep(seq_len(paths), each = 4L)
    candidates$pot <- rep(rep(c("pot_1", "pot_2"), each = 2L), paths)
  }
  candidates$eligibility_status <- "available"
  candidates$scenario_id <- uefa_euro_sim_scalar(allocation$scenario_id %||% "", "")
  candidates$scenario_status <- uefa_euro_sim_scalar(allocation$scenario_status %||% "resolved", "resolved")
  row.names(candidates) <- NULL
  list(
    valid = TRUE, status = "ready", reason = "", topology_status = "available", topology = topology,
    pool = candidates, playoff_pool = candidates, pots = candidates, draw_conditions = draw, eligibility = handoff, allocation = allocation,
    scenario_id = uefa_euro_sim_scalar(allocation$scenario_id %||% "", ""), scenario_status = uefa_euro_sim_scalar(allocation$scenario_status %||% "resolved", "resolved"),
    entrant_count = entrant_count, places = as.integer(topology$places[[1L]]), path_format = as.character(topology$stage_format[[1L]] %||% topology$structure[[1L]])
  )
}

uefa_euro_sim_activation_gate <- function(activation, fixtures = NULL) {
  if (!is.null(activation) && !is.list(activation)) return(list(valid = FALSE, status = "suppressed", reason = "invalid_activation_state"))
  state <- uefa_euro_sim_scalar(activation$lifecycle_state %||% activation$activation_status %||% "", "")
  competition_status <- tolower(uefa_euro_sim_scalar(activation$competition_status %||% activation$status %||% "", ""))
  if (identical(state, "pre_draw") || identical(competition_status, "pre_draw")) return(list(valid = FALSE, status = "suppressed", reason = "pre_draw"))
  if (nzchar(state) && !state %in% c("scheduled", "active", "in_progress", "complete")) return(list(valid = FALSE, status = "suppressed", reason = "invalid_activation_state"))
  if (nzchar(competition_status) && !competition_status %in% c("active", "scheduled", "in_progress", "complete", "available")) return(list(valid = FALSE, status = "suppressed", reason = "invalid_activation_state"))
  if (is.null(fixtures)) return(list(valid = TRUE, status = "active", reason = ""))
  if (!is.data.frame(fixtures) || !nrow(fixtures)) return(list(valid = FALSE, status = "suppressed", reason = "missing_confirmed_kickoff"))
  fixture_ids <- if ("fixture_id" %in% names(fixtures)) trimws(as.character(fixtures$fixture_id)) else rep("", nrow(fixtures))
  confirmed <- if ("kickoff_confirmed" %in% names(fixtures)) vapply(fixtures$kickoff_confirmed, uefa_euro_sim_bool, logical(1)) else rep(FALSE, nrow(fixtures))
  kickoff <- if ("confirmed_kickoff_at_utc" %in% names(fixtures)) trimws(as.character(fixtures$confirmed_kickoff_at_utc)) else rep("", nrow(fixtures))
  if (any(is.na(fixture_ids) | !nzchar(fixture_ids) | !confirmed | is.na(kickoff) | !nzchar(kickoff))) return(list(valid = FALSE, status = "suppressed", reason = "missing_confirmed_kickoff"))
  list(valid = TRUE, status = "active", reason = "")
}

uefa_euro_sim_standings_table <- function(standings) {
  table <- uefa_euro_sim_extract_table(standings, c("groups", "standings", "group_rankings", "rows", "table"))
  if (is.null(table)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
  as.data.frame(table, stringsAsFactors = FALSE, check.names = FALSE)
}

uefa_euro_sim_standings_ready <- function(standings, rules) {
  table <- uefa_euro_sim_standings_table(standings)
  if (!nrow(table) || !all(c("team_id", "group_id") %in% names(table))) return(FALSE)
  ids <- trimws(as.character(table$team_id)); groups <- trimws(as.character(table$group_id))
  if (any(is.na(ids) | !nzchar(ids) | is.na(groups) | !nzchar(groups)) || anyDuplicated(ids)) return(FALSE)
  if ("ordering_status" %in% names(table) && any(tolower(as.character(table$ordering_status)) %in% c("blocked", "unresolved", "suppressed"))) return(FALSE)
  if ("standing_status" %in% names(table) && any(tolower(as.character(table$standing_status)) %in% c("blocked", "unresolved", "suppressed"))) return(FALSE)
  length(unique(groups)) >= min(1L, as.integer(rules$qualifying_group_count))
}

uefa_euro_sim_topology_output <- function(allocation = NULL, rules = uefa_euro_2026_28_rules(), draw_conditions = NULL, status = "scenario_preserved", reason = "") {
  rows <- if (is.list(allocation)) allocation$topology else NULL
  if (is.null(rows) || !is.data.frame(rows) || !nrow(rows)) {
    rows <- tryCatch(
      if (is.null(draw_conditions)) uefa_euro_playoff_topologies(rules = rules, draw_conditions = NULL) else uefa_euro_playoff_topologies(rules = rules, draw_conditions = draw_conditions),
      error = function(error) data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    )
  }
  rows <- as.data.frame(rows, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(rows)) return(rows)
  if (!"simulation_status" %in% names(rows)) rows$simulation_status <- status
  else rows$simulation_status <- status
  if (!"simulation_reason" %in% names(rows)) rows$simulation_reason <- reason
  else rows$simulation_reason <- reason
  if (!"scenario_status" %in% names(rows)) rows$scenario_status <- if (status == "available") "resolved" else "preserved"
  rows
}

uefa_euro_sim_metadata <- function(
    status, reason, seed, simulation_count, source_bundle_id, source_bundle_sha256,
    rules, model_release_id = "", state_manifest_sha256 = "", draw_conditions = NULL,
    scenario_id = "", scenario_status = "", model_lineage = list()) {
  data.frame(
    edition_id = rules$edition_id, status = status, reason = reason, simulation_seed = as.integer(seed), simulation_count = as.integer(simulation_count),
    source_bundle_id = source_bundle_id, source_bundle_sha256 = source_bundle_sha256, ruleset_version = rules$ruleset_version,
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules), model_release_id = model_release_id, model_id = uefa_euro_sim_scalar(model_lineage$model_id %||% "", ""),
    model_data_cutoff = uefa_euro_sim_scalar(model_lineage$model_data_cutoff %||% "", ""), state_manifest_sha256 = state_manifest_sha256,
    draw_conditions_version = uefa_euro_sim_scalar(draw_conditions$draw_conditions_version %||% "", ""), draw_conditions_sha256 = uefa_euro_sim_scalar(draw_conditions$draw_conditions_sha256 %||% "", ""),
    scenario_id = scenario_id, scenario_status = scenario_status, score_conditioning_policy = "calibrated_1x2_conditional_score_grid",
    penalty_policy = "seeded_bernoulli_0.5", topology_policy = "official_host_capacity_and_fallback_v1",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_euro_sim_empty_result <- function(
    status, reason, seed, simulation_count, rules, source_bundle_id = "", source_bundle_sha256 = "",
    model_release_id = "", state_manifest_sha256 = "", draw_conditions = NULL, allocation = NULL,
    topology = NULL, scenario_id = "", scenario_status = "", eligibility = NULL) {
  topology_output <- if (!is.null(topology)) uefa_euro_sim_topology_output(list(topology = topology), rules, draw_conditions, status, reason) else uefa_euro_sim_topology_output(allocation, rules, draw_conditions, status, reason)
  metadata <- uefa_euro_sim_metadata(status, reason, seed, simulation_count, source_bundle_id, source_bundle_sha256, rules, model_release_id, state_manifest_sha256, draw_conditions, scenario_id, scenario_status)
  probabilities <- uefa_euro_sim_empty_probability()
  stage_slots <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  stage_resolutions <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  counts <- data.frame(stringsAsFactors = FALSE, check.names = FALSE)
  output_hashes <- list(
    probabilities = uefa_euro_sim_hash_data(probabilities), topology = uefa_euro_sim_hash_data(topology_output),
    stage_slots = uefa_euro_sim_hash_data(stage_slots), stage_resolutions = uefa_euro_sim_hash_data(stage_resolutions),
    simulation_metadata = uefa_euro_sim_hash_data(metadata)
  )
  output_hashes$replay_hash <- uefa_euro_sim_hash_data(output_hashes)
  list(
    status = status, reason = reason, suppression_reason = if (status %in% c("suppressed", "unavailable")) reason else "",
    probabilities = probabilities, qualification_probabilities = probabilities, qualification_counts = counts,
    topology = topology_output, stage_slots = stage_slots, stage_resolutions = stage_resolutions,
    simulation_metadata = metadata, metadata = metadata, output_hashes = output_hashes,
    allocation = allocation, playoff_pool = if (is.list(allocation)) allocation$remaining_playoff_entries else data.frame(stringsAsFactors = FALSE, check.names = FALSE),
    playoff_pots = data.frame(stringsAsFactors = FALSE, check.names = FALSE), eligibility = eligibility,
    scenario_id = scenario_id, scenario_status = scenario_status, valid = FALSE
  )
}

uefa_euro_sim_resolution_row <- function(result, iteration, stage_id, path_id, leg_number = 1L) {
  data.frame(
    simulation_iteration = as.integer(iteration), stage_id = as.character(stage_id), path_id = as.character(path_id), leg_number = as.integer(leg_number),
    status = as.character(result$status %||% result$stage_status %||% "unresolved"), winner_team_id = as.character(result$winner_team_id %||% NA_character_),
    loser_team_id = as.character(result$loser_team_id %||% NA_character_), resolution = as.character(result$resolution %||% "unresolved"),
    primary_probability_view = as.character(result$primary_probability_view %||% ""), model_release_id = as.character(result$model_release_id %||% ""),
    source_bundle_id = as.character(result$source_bundle_id %||% ""), ruleset_version = as.character(result$ruleset_version %||% ""),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_euro_sim_match_row <- function(fixture_id, home_team_id, away_team_id, leg_number = 1L) {
  data.frame(fixture_id = fixture_id, match_id = fixture_id, leg_number = as.integer(leg_number), home_team_id = home_team_id, away_team_id = away_team_id, stringsAsFactors = FALSE, check.names = FALSE)
}

uefa_euro_sim_probabilities <- function(counts, candidates, direct_ids, host_ids, seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_conditions, scenario_id, status = "available") {
  ids <- names(counts)
  if (!length(ids)) return(uefa_euro_sim_empty_probability())
  source <- if (is.data.frame(candidates) && nrow(candidates)) candidates[match(ids, candidates$team_id), , drop = FALSE] else data.frame(team_id = ids, stringsAsFactors = FALSE)
  probability <- as.numeric(counts[ids]) / simulation_count
  data.frame(
    edition_id = rules$edition_id, team_id = ids, probability = probability,
    qualification_status = ifelse(ids %in% direct_ids, "direct", ifelse(ids %in% host_ids, "host_reserved", "playoff_candidate")),
    status = status, reason = "", scenario_id = scenario_id, path_id = if ("path_id" %in% names(source)) as.character(source$path_id) else "",
    source_bundle_id = source_bundle_id, source_bundle_sha256 = source_bundle_sha256, ruleset_version = rules$ruleset_version,
    ruleset_sha256 = uefa_euro_ruleset_sha256(rules), model_release_id = model_release_id, state_manifest_sha256 = state_manifest_sha256,
    draw_conditions_version = uefa_euro_sim_scalar(draw_conditions$draw_conditions_version %||% "", ""), draw_conditions_sha256 = uefa_euro_sim_scalar(draw_conditions$draw_conditions_sha256 %||% "", ""),
    simulation_seed = as.integer(seed), simulation_count = as.integer(simulation_count), stringsAsFactors = FALSE, check.names = FALSE
  )
}

uefa_euro_simulate_qualification <- function(
    canonical_matches = NULL, completed_results = NULL, forecast_status = NULL,
    forecasts = NULL, score_distributions = NULL, score_distribution = NULL,
    groups = NULL, standings = NULL, hosts = NULL, nl_eligibility = NULL,
    allocation = NULL, draw_conditions = NULL, rules = uefa_euro_2026_28_rules(),
    simulation_count = 1000L, seed = 16017L, source_bundle_id = NULL,
    source_bundle_sha256 = NULL, model_release_id = NULL, model_lineage = list(),
    state_manifest_sha256 = NULL, activation = NULL, fixtures = NULL,
    runner_ups = NULL, playoff_pool = NULL, topology = NULL, host_ids = NULL,
    ...
) {
  simulation_count <- suppressWarnings(as.integer(simulation_count))
  if (length(simulation_count) != 1L || is.na(simulation_count) || simulation_count < 1L) stop("EURO simulation_count must be a positive integer", call. = FALSE)
  seed <- suppressWarnings(as.integer(seed))
  if (length(seed) != 1L || is.na(seed) || seed < 0L) stop("EURO simulation seed must be one non-negative integer", call. = FALSE)
  uefa_euro_sim_with_seed(seed, function() {
    activation_input <- activation
    fixtures_input <- fixtures %||% if (is.list(activation_input)) activation_input$fixtures else NULL
    activation_gate <- uefa_euro_sim_activation_gate(activation_input, fixtures_input)
    if (!isTRUE(activation_gate$valid)) {
      return(uefa_euro_sim_empty_result(activation_gate$status, activation_gate$reason, seed, simulation_count, rules, source_bundle_id %||% "", source_bundle_sha256 %||% "", model_release_id %||% "", state_manifest_sha256 %||% "", draw_conditions, scenario_id = "", scenario_status = "suppressed"))
    }
    draw_validation <- tryCatch(
      validate_euro_draw_conditions(draw_conditions, rules = rules),
      error = function(error) list(valid = FALSE, status = "unresolved_draw_conditions", topology_status = "unsupported_topology", reasons = "unresolved_draw_conditions;unsupported_topology", reason = conditionMessage(error))
    )
    if (!isTRUE(draw_validation$valid)) {
      reason <- paste(unique(c(draw_validation$reasons, draw_validation$reason, "unresolved_draw_conditions", "unsupported_topology")), collapse = ";")
      return(uefa_euro_sim_empty_result("suppressed", reason, seed, simulation_count, rules, source_bundle_id %||% "", source_bundle_sha256 %||% "", model_release_id %||% "", state_manifest_sha256 %||% "", draw_validation, scenario_id = "", scenario_status = "preserved"))
    }
    standings_input <- standings %||% groups %||% if (is.list(activation_input)) activation_input$standings else NULL
    if (!uefa_euro_sim_standings_ready(standings_input, rules)) {
      topology_output <- uefa_euro_sim_topology_output(NULL, rules, draw_validation, "scenario_preserved", "completed_standings_required")
      return(uefa_euro_sim_empty_result("scenario_preserved", "completed_standings_required", seed, simulation_count, rules, source_bundle_id %||% "", source_bundle_sha256 %||% "", model_release_id %||% "", state_manifest_sha256 %||% "", draw_validation, topology = topology_output, scenario_id = "euro-qualifying-scenario-unresolved", scenario_status = "preserved"))
    }
    handoff <- uefa_euro_sim_normalized_handoff(nl_eligibility)
    if (!isTRUE(handoff$valid)) {
      return(uefa_euro_sim_empty_result("unresolved_external_eligibility", handoff$reason %||% "phase15_handoff_unresolved", seed, simulation_count, rules, source_bundle_id %||% "", source_bundle_sha256 %||% "", model_release_id %||% "", state_manifest_sha256 %||% "", draw_validation, scenario_id = "", scenario_status = "resolved", eligibility = handoff))
    }
    forecast_table <- forecasts %||% forecast_status
    score_table <- score_distributions %||% score_distribution
    if (is.null(forecast_table)) return(uefa_euro_sim_empty_result("unavailable", "forecast_authority_missing", seed, simulation_count, rules, source_bundle_id %||% "", source_bundle_sha256 %||% "", model_release_id %||% "", state_manifest_sha256 %||% "", draw_validation, scenario_id = "", scenario_status = "resolved"))
    source_bundle_id <- uefa_euro_sim_scalar(source_bundle_id %||% if (is.list(activation_input)) activation_input$source_bundle_id else "", uefa_euro_source_bundle_id())
    source_bundle_sha256 <- uefa_euro_sim_scalar(source_bundle_sha256 %||% "", "")
    state_manifest_sha256 <- uefa_euro_sim_scalar(state_manifest_sha256 %||% "", "")
    model_release_id <- uefa_euro_sim_scalar(model_release_id %||% uefa_euro_sim_row_value(uefa_euro_sim_extract_table(forecast_table, c("forecasts", "forecast", "rows")), "model_release_id", ""), "")
    if (!nzchar(source_bundle_id) || !uefa_euro_sim_hash_valid(source_bundle_sha256) || !nzchar(model_release_id) || !uefa_euro_sim_hash_valid(state_manifest_sha256)) {
      return(uefa_euro_sim_empty_result("unavailable", "simulation_lineage_incomplete", seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_validation, scenario_id = "", scenario_status = "resolved"))
    }
    pool_result <- if (!is.null(playoff_pool) && is.list(playoff_pool) && !is.data.frame(playoff_pool) && isTRUE(playoff_pool$valid)) playoff_pool else uefa_euro_allocate_playoff_pool(
      allocation = allocation, group_rankings = standings_input, standings = standings_input, runner_ups = runner_ups,
      hosts = hosts, host_ids = host_ids, draw_conditions = draw_conditions, rules = rules,
      source_bundle_id = source_bundle_id
    )
    if (!isTRUE(pool_result$valid)) {
      return(uefa_euro_sim_empty_result(pool_result$status %||% "unsupported_topology", pool_result$reason %||% "unsupported_topology", seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_validation, allocation = pool_result$allocation, topology = pool_result$topology, scenario_id = pool_result$scenario_id %||% "", scenario_status = pool_result$scenario_status %||% "preserved"))
    }
    pots_result <- uefa_euro_build_playoff_pots(pool = pool_result, nl_eligibility = handoff$projection, allocation = pool_result$allocation, topology = topology %||% pool_result$topology, rules = rules, draw_conditions = draw_conditions)
    if (!isTRUE(pots_result$valid)) {
      return(uefa_euro_sim_empty_result(pots_result$status %||% "unavailable", pots_result$reason %||% "playoff_pool_incomplete", seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_validation, allocation = pool_result$allocation, topology = pots_result$topology, scenario_id = pots_result$scenario_id %||% "", scenario_status = pots_result$scenario_status %||% "resolved", eligibility = handoff))
    }
    candidates <- as.data.frame(pots_result$pool, stringsAsFactors = FALSE, check.names = FALSE)
    direct <- if (is.data.frame(pool_result$allocation$direct_qualifiers)) trimws(as.character(pool_result$allocation$direct_qualifiers$team_id)) else character()
    hosts_selected <- if (is.data.frame(pool_result$allocation$host_slots) && "consumes_capacity" %in% names(pool_result$allocation$host_slots)) trimws(as.character(pool_result$allocation$host_slots$team_id[pool_result$allocation$host_slots$consumes_capacity %in% TRUE])) else character()
    hosts_selected <- hosts_selected[!is.na(hosts_selected) & nzchar(hosts_selected)]
    all_ids <- unique(c(direct, hosts_selected, as.character(candidates$team_id)))
    counts <- setNames(integer(length(all_ids)), all_ids)
    resolution_rows <- list(); resolution_index <- 0L
    blocked_reason <- ""
    topology_row <- pots_result$topology
    two_leg <- as.integer(topology_row$reserved_slots_used[[1L]]) == 0L || grepl("away|home_and_away|two_leg", tolower(as.character(topology_row$stage_format[[1L]] %||% topology_row$structure[[1L]])))
    for (iteration in seq_len(simulation_count)) {
      if (length(direct)) counts[direct] <- counts[direct] + 1L
      if (length(hosts_selected)) counts[hosts_selected] <- counts[hosts_selected] + 1L
      if (two_leg) {
        path_ids <- sort(unique(as.character(candidates$path_id)), method = "radix")
        for (path_id in path_ids) {
          path <- candidates[as.character(candidates$path_id) == path_id, , drop = FALSE]
          seeded <- path[path$pot == "pot_1", , drop = FALSE]; unseeded <- path[path$pot == "pot_2", , drop = FALSE]
          if (nrow(seeded) != 1L || nrow(unseeded) != 1L) { blocked_reason <- "playoff_pot_assignment_invalid"; break }
          tie <- rbind(
            uefa_euro_sim_match_row(paste0("euro-playoff-", path_id, "-leg-1"), unseeded$team_id[[1L]], seeded$team_id[[1L]], 1L),
            uefa_euro_sim_match_row(paste0("euro-playoff-", path_id, "-leg-2"), seeded$team_id[[1L]], unseeded$team_id[[1L]], 2L)
          )
          result <- uefa_euro_resolve_two_leg_tie(tie, seed = uefa_euro_sim_seed_for(seed, "path", path_id, iteration), rules = rules, forecasts = forecast_table, score_distributions = score_table)
          if (!identical(result$status, "completed")) { blocked_reason <- result$unresolved_reason %||% "two_leg_resolution_unavailable"; break }
          counts[result$winner_team_id] <- counts[result$winner_team_id] + 1L
          resolution_index <- resolution_index + 1L
          resolution_rows[[resolution_index]] <- uefa_euro_sim_resolution_row(result, iteration, "playoff_two_leg", path_id, 0L)
        }
      } else {
        path_ids <- sort(unique(as.character(candidates$path_id)), method = "radix")
        for (path_id in path_ids) {
          path <- candidates[as.character(candidates$path_id) == path_id, , drop = FALSE]
          path <- path[order(as.integer(path$fallback_order), as.integer(path$interim_overall_rank), as.character(path$team_id), method = "radix"), , drop = FALSE]
          if (nrow(path) != 4L) { blocked_reason <- "single_leg_path_requires_four_entrants"; break }
          semi_one <- uefa_euro_resolve_single_leg(uefa_euro_sim_match_row(paste0("euro-playoff-", path_id, "-semi-1"), path$team_id[[1L]], path$team_id[[4L]]), seed = uefa_euro_sim_seed_for(seed, "path", path_id, iteration, "semi-1"), rules = rules, forecasts = forecast_table, score_distributions = score_table)
          semi_two <- uefa_euro_resolve_single_leg(uefa_euro_sim_match_row(paste0("euro-playoff-", path_id, "-semi-2"), path$team_id[[2L]], path$team_id[[3L]]), seed = uefa_euro_sim_seed_for(seed, "path", path_id, iteration, "semi-2"), rules = rules, forecasts = forecast_table, score_distributions = score_table)
          if (!identical(semi_one$status, "completed") || !identical(semi_two$status, "completed")) { blocked_reason <- "single_leg_resolution_unavailable"; break }
          final <- uefa_euro_resolve_single_leg(uefa_euro_sim_match_row(paste0("euro-playoff-", path_id, "-final"), semi_one$winner_team_id, semi_two$winner_team_id), seed = uefa_euro_sim_seed_for(seed, "path", path_id, iteration, "final"), rules = rules, forecasts = forecast_table, score_distributions = score_table)
          if (!identical(final$status, "completed")) { blocked_reason <- "single_leg_final_resolution_unavailable"; break }
          counts[final$winner_team_id] <- counts[final$winner_team_id] + 1L
          resolution_index <- resolution_index + 1L
          resolution_rows[[resolution_index]] <- uefa_euro_sim_resolution_row(final, iteration, "playoff_single_leg_final", path_id, 1L)
        }
      }
      if (nzchar(blocked_reason)) break
    }
    if (nzchar(blocked_reason)) return(uefa_euro_sim_empty_result("unavailable", blocked_reason, seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_validation, allocation = pool_result$allocation, topology = topology_row, scenario_id = pool_result$scenario_id %||% "", scenario_status = "resolved", eligibility = handoff))
    scenario_id <- uefa_euro_sim_scalar(pool_result$scenario_id %||% "", paste0("euro-qualifying-scenario-host-", topology_row$reserved_slots_used[[1L]]))
    scenario_status <- uefa_euro_sim_scalar(pool_result$scenario_status %||% "resolved", "resolved")
    probabilities <- uefa_euro_sim_probabilities(counts, candidates, direct, hosts_selected, seed, simulation_count, rules, source_bundle_id, source_bundle_sha256, model_release_id, state_manifest_sha256, draw_validation, scenario_id)
    topology_output <- uefa_euro_sim_topology_output(pool_result$allocation, rules, draw_validation, "available", "")
    topology_output$scenario_id <- scenario_id
    topology_output$scenario_status <- scenario_status
    topology_output$simulation_seed <- as.integer(seed)
    topology_output$simulation_count <- as.integer(simulation_count)
    stage_slots <- candidates[, intersect(c("team_id", "pot", "path_id", "eligibility_source", "fallback_order", "scenario_id", "scenario_status"), names(candidates)), drop = FALSE]
    if (nrow(stage_slots)) {
      stage_slots$stage_id <- if (two_leg) "playoff_two_leg" else "playoff_single_leg"
      stage_slots <- stage_slots[, c("stage_id", setdiff(names(stage_slots), "stage_id")), drop = FALSE]
    }
    stage_resolutions <- if (length(resolution_rows)) uefa_euro_sim_canonical_table(do.call(rbind, resolution_rows), key = c("simulation_iteration", "stage_id", "path_id", "leg_number")) else data.frame(stringsAsFactors = FALSE, check.names = FALSE)
    metadata <- uefa_euro_sim_metadata("available", "", seed, simulation_count, source_bundle_id, source_bundle_sha256, rules, model_release_id, state_manifest_sha256, draw_validation, scenario_id, scenario_status, model_lineage)
    qualification_counts <- probabilities
    qualification_counts$count <- as.integer(round(qualification_counts$probability * simulation_count))
    output_hashes <- list(
      probabilities = uefa_euro_sim_hash_data(probabilities), qualification_counts = uefa_euro_sim_hash_data(qualification_counts),
      topology = uefa_euro_sim_hash_data(topology_output), stage_slots = uefa_euro_sim_hash_data(stage_slots),
      stage_resolutions = uefa_euro_sim_hash_data(stage_resolutions), simulation_metadata = uefa_euro_sim_hash_data(metadata),
      allocation_ledger = uefa_euro_sim_hash_data(pool_result$allocation$qualification_ledger), playoff_pots = uefa_euro_sim_hash_data(candidates)
    )
    output_hashes$replay_hash <- uefa_euro_sim_hash_data(output_hashes)
    list(
      valid = TRUE, status = "available", reason = "", suppression_reason = "", probabilities = probabilities,
      qualification_probabilities = probabilities, qualification_counts = qualification_counts, topology = topology_output,
      allocation = pool_result$allocation, playoff_pool = pool_result$pool, playoff_pots = candidates,
      stage_slots = stage_slots, stage_resolutions = stage_resolutions, simulation_metadata = metadata, metadata = metadata,
      output_hashes = output_hashes, input_hashes = list(standings = uefa_euro_sim_hash_data(standings_input), eligibility = uefa_euro_sim_hash_data(handoff$projection), forecasts = uefa_euro_sim_hash_data(forecast_table)),
      scenario_id = scenario_id, scenario_status = scenario_status, eligibility = handoff
    )
  })
}

uefa_euro_run_simulation <- function(
    canonical_matches = NULL, completed_results = NULL, forecast_status = NULL,
    forecasts = NULL, score_distributions = NULL, groups = NULL, standings = NULL,
    hosts = NULL, nl_eligibility = NULL, allocation = NULL, draw_conditions = NULL,
    rules = uefa_euro_2026_28_rules(), simulation_count = 1000L, seed = 16017L,
    source_bundle_id = NULL, source_bundle_sha256 = NULL, model_release_id = NULL,
    model_lineage = list(), state_manifest_sha256 = NULL, activation = NULL, fixtures = NULL,
    runner_ups = NULL, playoff_pool = NULL, topology = NULL, host_ids = NULL, ...
) {
  uefa_euro_simulate_qualification(
    canonical_matches = canonical_matches, completed_results = completed_results, forecast_status = forecast_status,
    forecasts = forecasts, score_distributions = score_distributions, groups = groups, standings = standings,
    hosts = hosts, nl_eligibility = nl_eligibility, allocation = allocation, draw_conditions = draw_conditions,
    rules = rules, simulation_count = simulation_count, seed = seed, source_bundle_id = source_bundle_id,
    source_bundle_sha256 = source_bundle_sha256, model_release_id = model_release_id, model_lineage = model_lineage,
    state_manifest_sha256 = state_manifest_sha256, activation = activation, fixtures = fixtures, runner_ups = runner_ups,
    playoff_pool = playoff_pool, topology = topology, host_ids = host_ids, ...
  )
}
