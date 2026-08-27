#' Separately captured Article 15 rule inputs for UEFA Nations League 2026/27.
#'
#' The Phase 13 source bundle intentionally remains the five-resource
#' fixtures/groups/standings/results/status contract.  Access-list positions
#' and discipline are a small, independently captured rules input because the
#' official match endpoint does not expose either field.  This module owns the
#' paths, compact CSV schemas, hashes, and validation for that companion input.

phase15_nl_rule_input_edition_id <- function() {
  if (exists("uefa_nl_edition_id", mode = "function", inherits = TRUE)) {
    return(uefa_nl_edition_id())
  }
  "uefa_nations_league_2026_27"
}

phase15_nl_rule_input_id <- function() {
  "nl-2026-27-article15-rule-inputs-v1"
}

phase15_nl_rule_input_access_artifact_id <- function() {
  "nl-2026-27-uefa-annex-c-access-list-v1"
}

phase15_nl_rule_input_discipline_artifact_id <- function() {
  "nl-2026-27-article15-discipline-baseline-v1"
}

phase15_nl_rule_input_access_source_url <- function() {
  paste0(
    "https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/",
    "Annex-C-2026/27-Final-UEFA-Nations-League-Access-List-and-Overall-Rankings-Online?",
    "contentId=zRQeB_Bz39M3mlLQ2VH4uw"
  )
}

phase15_nl_rule_input_article15_source_url <- function() {
  paste0(
    "https://documents.uefa.com/r/Regulations-of-the-UEFA-Nations-League-2026/27/",
    "Article-15-Equality-of-points-league-phase-Online"
  )
}

phase15_nl_rule_input_playoff_source_url <- function() {
  "https://www.uefa.com/uefanationsleague/news/0296-1d165d4a3647-4d55eede66c2-1000/"
}

phase15_nl_rule_input_retrieved_at_utc <- function() {
  "2026-08-27T00:00:00Z"
}

phase15_nl_rule_input_relative_dir <- function() {
  file.path("data", "competition", "rule_inputs", phase15_nl_rule_input_edition_id())
}

phase15_nl_rule_input_paths <- function(project_root = ".") {
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  relative <- phase15_nl_rule_input_relative_dir()
  list(
    project_root = root,
    directory = file.path(root, relative),
    access_list_relative_path = file.path(relative, "access_list.csv"),
    discipline_points_relative_path = file.path(relative, "discipline_points.csv"),
    manifest_relative_path = file.path(relative, "manifest.csv"),
    access_list_path = file.path(root, relative, "access_list.csv"),
    discipline_points_path = file.path(root, relative, "discipline_points.csv"),
    manifest_path = file.path(root, relative, "manifest.csv")
  )
}

phase15_nl_rule_input_access_schema <- function() {
  c(
    "edition_id", "team_id", "access_list_position", "league_id", "group_id",
    "draw_pot", "group_formation_status", "status", "source_artifact_id",
    "source_url", "source_url_lineage", "retrieved_at_utc", "source_note",
    "row_sha256"
  )
}

phase15_nl_rule_input_discipline_schema <- function() {
  c(
    "edition_id", "team_id", "discipline_points", "initialization_status",
    "as_of_utc", "source_artifact_id", "source_url", "source_url_lineage",
    "retrieved_at_utc", "source_note", "row_sha256"
  )
}

phase15_nl_rule_input_manifest_schema <- function() {
  c(
    "schema_version", "rule_input_id", "edition_id", "capture_status",
    "access_list_artifact_id", "discipline_points_artifact_id",
    "access_list_relative_path", "discipline_points_relative_path",
    "access_list_sha256", "discipline_points_sha256", "source_url",
    "source_url_lineage", "retrieved_at_utc", "discipline_initialization_policy",
    "parser_commit_sha", "manifest_sha256", "row_sha256"
  )
}

phase15_nl_rule_input_hash_bytes <- function(bytes) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Article 15 input hashes", call. = FALSE)
  tolower(digest::digest(bytes, algo = "sha256", serialize = FALSE))
}

phase15_nl_rule_input_file_hash <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Article 15 rule-input file is missing: ", path, call. = FALSE)
  phase15_nl_rule_input_hash_bytes(readBin(path, what = "raw", n = file.info(path)$size))
}

phase15_nl_rule_input_scalar <- function(value) {
  if (length(value) == 0L || is.na(value[[1L]])) return("")
  if (is.logical(value)) return(ifelse(value[[1L]], "true", "false"))
  as.character(value[[1L]])
}

phase15_nl_rule_input_row_hash <- function(data) {
  if (!is.data.frame(data)) stop("Article 15 rule-input row hash requires a data frame", call. = FALSE)
  fields <- setdiff(names(data), "row_sha256")
  if (!length(fields)) return(character(nrow(data)))
  vapply(seq_len(nrow(data)), function(index) {
    phase15_nl_rule_input_hash_bytes(charToRaw(enc2utf8(paste(
      vapply(data[index, fields, drop = FALSE], phase15_nl_rule_input_scalar, character(1)),
      collapse = "|"
    ))))
  }, character(1))
}

phase15_nl_rule_input_table_hash <- function(data) {
  if (!is.data.frame(data)) stop("Article 15 rule-input table hash requires a data frame", call. = FALSE)
  fields <- sort(names(data), method = "radix")
  canonical <- data[, fields, drop = FALSE]
  if (nrow(canonical)) {
    ordering <- lapply(canonical, function(column) vapply(column, phase15_nl_rule_input_scalar, character(1)))
    canonical <- canonical[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- if (!nrow(canonical)) character() else vapply(seq_len(nrow(canonical)), function(index) {
    paste(vapply(canonical[index, , drop = FALSE], phase15_nl_rule_input_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  phase15_nl_rule_input_hash_bytes(charToRaw(enc2utf8(paste(c(paste(fields, collapse = "\x1f"), rows), collapse = "\x1e"))))
}

phase15_nl_rule_input_manifest_hash <- function(manifest_row) {
  body <- manifest_row
  body$manifest_sha256 <- ""
  body$row_sha256 <- ""
  phase15_nl_rule_input_table_hash(body)
}

phase15_nl_rule_input_require_schema <- function(data, schema, name) {
  if (!is.data.frame(data) || !identical(names(data), schema)) {
    stop("Article 15 ", name, " schema mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase15_nl_rule_input_validate_row_hashes <- function(data, name) {
  if (!nrow(data)) stop("Article 15 ", name, " must not be empty", call. = FALSE)
  if (any(is.na(data$row_sha256) | !grepl("^[0-9a-fA-F]{64}$", as.character(data$row_sha256)))) {
    stop("Article 15 ", name, " requires canonical row hashes", call. = FALSE)
  }
  expected <- phase15_nl_rule_input_row_hash(data)
  if (any(tolower(as.character(data$row_sha256)) != tolower(expected))) {
    stop("Article 15 ", name, " row hash mismatch", call. = FALSE)
  }
  invisible(TRUE)
}

phase15_nl_rule_input_validate_access_list <- function(
    access_list,
    teams = NULL,
    groups = NULL,
    edition_id = phase15_nl_rule_input_edition_id()) {
  phase15_nl_rule_input_require_schema(access_list, phase15_nl_rule_input_access_schema(), "access list")
  values <- as.data.frame(access_list, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(values) != 54L) stop("Article 15 access list must contain 54 teams", call. = FALSE)
  if (any(as.character(values$edition_id) != as.character(edition_id))) stop("Article 15 access list has a foreign edition", call. = FALSE)
  if (anyDuplicated(as.character(values$team_id))) stop("Article 15 access list contains duplicate teams", call. = FALSE)
  positions <- suppressWarnings(as.integer(as.character(values$access_list_position)))
  if (any(is.na(positions)) || !setequal(positions, seq_len(nrow(values)))) stop("Article 15 access-list positions must be the complete 1:54 universe", call. = FALSE)
  values$access_list_position <- positions
  if (any(is.na(values$league_id) | !toupper(as.character(values$league_id)) %in% c("A", "B", "C", "D"))) stop("Article 15 access list contains an unknown league", call. = FALSE)
  values$league_id <- toupper(as.character(values$league_id))
  for (field in c("team_id", "group_id", "draw_pot", "group_formation_status", "status", "source_artifact_id", "source_url", "source_url_lineage", "retrieved_at_utc", "source_note")) {
    text <- trimws(as.character(values[[field]]))
    if (any(is.na(text) | !nzchar(text))) stop("Article 15 access list has missing ", field, call. = FALSE)
    values[[field]] <- text
  }
  if (any(values$group_formation_status != "validated") || any(values$status != "admitted")) stop("Article 15 access list must be admitted and validated", call. = FALSE)
  if (any(!grepl("^https://", values$source_url)) || any(!grepl("^https://", values$source_url_lineage))) stop("Article 15 access list source lineage must use HTTPS", call. = FALSE)
  expected_league <- if (exists("uefa_nl_access_band", mode = "function", inherits = TRUE)) {
    vapply(values$access_list_position, uefa_nl_access_band, character(1))
  } else {
    ifelse(values$access_list_position <= 16L, "A", ifelse(values$access_list_position <= 32L, "B", ifelse(values$access_list_position <= 48L, "C", "D")))
  }
  if (any(expected_league != values$league_id)) stop("Article 15 access list positions do not match Article 13 league bands", call. = FALSE)
  phase15_nl_rule_input_validate_row_hashes(values, "access list")
  if (!is.null(teams)) {
    team_ids <- trimws(as.character(teams$team_id))
    if (!setequal(team_ids, values$team_id)) stop("Article 15 access list does not cover the topology team set", call. = FALSE)
  }
  if (!is.null(groups)) {
    if (!exists("uefa_nl_validate_group_formation", mode = "function", inherits = TRUE)) stop("Nations League group-formation validator is unavailable", call. = FALSE)
    formation <- uefa_nl_validate_group_formation(values, groups, edition_id = edition_id)
    values <- formation$rows
  } else {
    values <- values[order(values$access_list_position, values$team_id, method = "radix"), , drop = FALSE]
  }
  row.names(values) <- NULL
  values
}

phase15_nl_rule_input_validate_discipline_points <- function(
    discipline_points,
    teams = NULL,
    edition_id = phase15_nl_rule_input_edition_id()) {
  phase15_nl_rule_input_require_schema(discipline_points, phase15_nl_rule_input_discipline_schema(), "discipline points")
  values <- as.data.frame(discipline_points, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(values) != 54L) stop("Article 15 discipline baseline must contain 54 teams", call. = FALSE)
  if (any(as.character(values$edition_id) != as.character(edition_id))) stop("Article 15 discipline baseline has a foreign edition", call. = FALSE)
  if (anyDuplicated(as.character(values$team_id))) stop("Article 15 discipline baseline contains duplicate teams", call. = FALSE)
  points <- suppressWarnings(as.integer(as.character(values$discipline_points)))
  if (any(is.na(points) | points < 0L)) stop("Article 15 discipline points must be non-negative integers", call. = FALSE)
  values$discipline_points <- points
  for (field in c("team_id", "initialization_status", "as_of_utc", "source_artifact_id", "source_url", "source_url_lineage", "retrieved_at_utc", "source_note")) {
    text <- trimws(as.character(values[[field]]))
    if (any(is.na(text) | !nzchar(text))) stop("Article 15 discipline baseline has missing ", field, call. = FALSE)
    values[[field]] <- text
  }
  if (any(values$initialization_status != "initialized_pre_match")) stop("Article 15 discipline baseline must be explicitly initialized_pre_match", call. = FALSE)
  if (any(points != 0L)) stop("Pre-match Article 15 discipline baseline must initialize every team to zero", call. = FALSE)
  if (any(!grepl("^https://", values$source_url)) || any(!grepl("^https://", values$source_url_lineage))) stop("Article 15 discipline source lineage must use HTTPS", call. = FALSE)
  phase15_nl_rule_input_validate_row_hashes(values, "discipline points")
  if (!is.null(teams) && !setequal(trimws(as.character(teams$team_id)), values$team_id)) stop("Article 15 discipline baseline does not cover the topology team set", call. = FALSE)
  values <- values[order(values$team_id, method = "radix"), , drop = FALSE]
  row.names(values) <- NULL
  values
}

phase15_nl_rule_input_validate_manifest <- function(manifest, paths, access_list, discipline_points) {
  phase15_nl_rule_input_require_schema(manifest, phase15_nl_rule_input_manifest_schema(), "rule-input manifest")
  if (nrow(manifest) != 1L) stop("Article 15 rule-input manifest must contain one row", call. = FALSE)
  row <- manifest[1L, , drop = FALSE]
  if (as.character(row$schema_version[[1L]]) != "phase15-article15-rule-inputs-v1") stop("Article 15 rule-input manifest has an unknown schema version", call. = FALSE)
  if (as.character(row$rule_input_id[[1L]]) != phase15_nl_rule_input_id()) stop("Article 15 rule-input manifest has an unknown input ID", call. = FALSE)
  if (as.character(row$edition_id[[1L]]) != phase15_nl_rule_input_edition_id()) stop("Article 15 rule-input manifest has a foreign edition", call. = FALSE)
  if (as.character(row$capture_status[[1L]]) != "accepted") stop("Article 15 rule-input manifest is not accepted", call. = FALSE)
  for (field in c("access_list_relative_path", "discipline_points_relative_path")) {
    value <- as.character(row[[field]][[1L]])
    if (is.na(value) || !nzchar(value) || grepl("^/|(^|/)\\.\\.?(/|$)|//", value)) stop("Article 15 rule-input manifest has an unsafe path", call. = FALSE)
  }
  if (!identical(as.character(row$access_list_relative_path[[1L]]), paths$access_list_relative_path) ||
      !identical(as.character(row$discipline_points_relative_path[[1L]]), paths$discipline_points_relative_path)) stop("Article 15 rule-input manifest paths do not match registered inputs", call. = FALSE)
  for (field in c("access_list_sha256", "discipline_points_sha256", "manifest_sha256", "row_sha256")) {
    if (!grepl("^[0-9a-fA-F]{64}$", as.character(row[[field]][[1L]]))) stop("Article 15 rule-input manifest has an invalid ", field, call. = FALSE)
  }
  if (!identical(tolower(as.character(row$access_list_sha256[[1L]])), phase15_nl_rule_input_file_hash(paths$access_list_path))) stop("Article 15 access-list file hash mismatch", call. = FALSE)
  if (!identical(tolower(as.character(row$discipline_points_sha256[[1L]])), phase15_nl_rule_input_file_hash(paths$discipline_points_path))) stop("Article 15 discipline file hash mismatch", call. = FALSE)
  if (!identical(tolower(as.character(row$manifest_sha256[[1L]])), phase15_nl_rule_input_manifest_hash(row))) stop("Article 15 rule-input manifest self-hash mismatch", call. = FALSE)
  if (!identical(tolower(as.character(row$row_sha256[[1L]])), phase15_nl_rule_input_row_hash(row)[[1L]])) stop("Article 15 rule-input manifest row hash mismatch", call. = FALSE)
  if (nrow(access_list) != 54L || nrow(discipline_points) != 54L) stop("Article 15 rule-input manifest requires complete 54-team companions", call. = FALSE)
  invisible(TRUE)
}

phase15_nl_validate_rule_inputs <- function(access_list, discipline_points, teams = NULL, groups = NULL, edition_id = phase15_nl_rule_input_edition_id()) {
  access <- phase15_nl_rule_input_validate_access_list(access_list, teams = teams, groups = groups, edition_id = edition_id)
  discipline <- phase15_nl_rule_input_validate_discipline_points(discipline_points, teams = teams, edition_id = edition_id)
  list(access_list = access, discipline_points = discipline, status = "validated", rule_input_id = phase15_nl_rule_input_id())
}

phase15_nl_read_rule_inputs <- function(project_root = ".", groups = NULL, teams = NULL) {
  paths <- phase15_nl_rule_input_paths(project_root)
  required <- c(paths$access_list_path, paths$discipline_points_path, paths$manifest_path)
  if (any(!file.exists(required))) stop("Registered Article 15 rule-input path is missing", call. = FALSE)
  access <- utils::read.csv(paths$access_list_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  discipline <- utils::read.csv(paths$discipline_points_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  manifest <- utils::read.csv(paths$manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  access <- phase15_nl_rule_input_validate_access_list(access, teams = teams, groups = groups)
  discipline <- phase15_nl_rule_input_validate_discipline_points(discipline, teams = teams)
  phase15_nl_rule_input_validate_manifest(manifest, paths, access, discipline)
  list(
    rule_input_id = phase15_nl_rule_input_id(),
    access_list = access,
    discipline_points = discipline,
    manifest = manifest,
    paths = paths,
    access_list_sha256 = phase15_nl_rule_input_file_hash(paths$access_list_path),
    discipline_points_sha256 = phase15_nl_rule_input_file_hash(paths$discipline_points_path),
    manifest_sha256 = tolower(as.character(manifest$manifest_sha256[[1L]]))
  )
}
