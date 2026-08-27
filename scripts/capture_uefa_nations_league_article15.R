#!/usr/bin/env Rscript

# Capture the independently sourced Article 15 inputs used by the Nations
# League ranking/forecasting layer.  The Phase 13 source bundle deliberately
# remains the five-resource fixtures/groups/standings/results/status contract;
# this companion capture records the official access-list order and the
# explicitly initialized pre-match discipline baseline.

capture_args <- commandArgs(trailingOnly = FALSE)
capture_file_arg <- capture_args[grepl("^--file=", capture_args)]
capture_script_path <- normalizePath(
  if (length(capture_file_arg)) sub("^--file=", "", capture_file_arg[[1L]]) else "scripts/capture_uefa_nations_league_article15.R",
  mustWork = FALSE
)
capture_root <- normalizePath(file.path(dirname(capture_script_path), ".."), mustWork = TRUE)

sys.source(file.path(capture_root, "R/competition/uefa_nations_league_rules.R"), envir = environment())
sys.source(file.path(capture_root, "R/competition/uefa_nations_league_rule_inputs.R"), envir = environment())

edition_id <- phase15_nl_rule_input_edition_id()
paths <- phase15_nl_rule_input_paths(capture_root)
access_url <- phase15_nl_rule_input_access_source_url()
article15_url <- phase15_nl_rule_input_article15_source_url()
playoff_url <- phase15_nl_rule_input_playoff_source_url()
retrieved_at <- phase15_nl_rule_input_retrieved_at_utc()

groups_path <- file.path(capture_root, "data/competition/accepted", edition_id, "groups.csv")
fixtures_path <- file.path(capture_root, "data/competition/accepted", edition_id, "fixtures.csv")
groups <- utils::read.csv(groups_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
fixtures <- utils::read.csv(fixtures_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")

group_map <- setNames(as.character(groups$league), as.character(groups$source_group_id))
team_group <- unique(rbind(
  data.frame(team_id = as.character(fixtures$home_team_id), group_id = as.character(fixtures$group_id), stringsAsFactors = FALSE),
  data.frame(team_id = as.character(fixtures$away_team_id), group_id = as.character(fixtures$group_id), stringsAsFactors = FALSE)
))
team_group <- team_group[order(team_group$team_id, team_group$group_id, method = "radix"), , drop = FALSE]
if (anyDuplicated(team_group$team_id)) stop("Fixture source does not assign each team to exactly one group", call. = FALSE)
team_group$league_id <- unname(group_map[team_group$group_id])
if (any(is.na(team_group$league_id))) stop("Fixture source has a group absent from groups.csv", call. = FALSE)

# Resolved Annex C order for the 2026/27 league phase.  Positions whose final
# identity depended on the C/D playoffs use the published UEFA playoff result:
# Latvia over Gibraltar and Luxembourg over Malta.
access_order <- c(
  "team_por", "team_esp", "team_fra", "team_deu", "team_ita", "team_ned", "team_den", "team_cro",
  "team_srb", "team_bel", "team_eng", "team_nor", "team_wal", "team_cze", "team_gre", "team_tur",
  "team_scotland", "team_hun", "team_pol", "team_isr", "team_sui", "team_bih", "team_aut", "team_ukr",
  "team_svn", "team_geo", "team_republic_of_ireland", "team_rou", "team_swe", "team_mkd", "team_nir", "team_kvx",
  "team_isl", "team_alb", "team_mne", "team_kaz", "team_fin", "team_svk", "team_bul", "team_arm",
  "team_blr", "team_fro", "team_cyp", "team_est", "team_lva", "team_lux", "team_mda", "team_smr",
  "team_aze", "team_ltu", "team_gibraltar", "team_mlt", "team_lie", "team_and"
)
if (length(access_order) != 54L || anyDuplicated(access_order) || !setequal(access_order, team_group$team_id)) {
  stop("Article 15 access order does not cover the 54 accepted topology teams", call. = FALSE)
}

league_start <- c(A = 1L, B = 17L, C = 33L, D = 49L)
league_for_position <- function(position) {
  names(league_start)[max(which(league_start <= position))]
}
pot_for_position <- function(position, league) {
  if (identical(league, "D")) {
    # UEFA's League D draw has four teams in Pot 1 (positions 49–52)
    # and two teams in Pot 2 (positions 53–54); each group receives two
    # Pot 1 teams and one Pot 2 team.
    if (position <= 52L) 1L else 2L
  } else {
    floor((position - league_start[[league]]) / 4L) + 1L
  }
}

access <- data.frame(
  edition_id = edition_id,
  team_id = access_order,
  access_list_position = seq_along(access_order),
  league_id = vapply(seq_along(access_order), function(position) league_for_position(position), character(1)),
  group_id = as.character(team_group$group_id[match(access_order, team_group$team_id)]),
  draw_pot = vapply(seq_along(access_order), function(position) {
    league <- league_for_position(position)
    paste0(league, "-pot-", pot_for_position(position, league))
  }, character(1)),
  group_formation_status = "validated",
  status = "admitted",
  source_artifact_id = phase15_nl_rule_input_access_artifact_id(),
  source_url = access_url,
  source_url_lineage = paste(access_url, playoff_url, sep = "|"),
  retrieved_at_utc = retrieved_at,
  source_note = "UEFA Annex C 2026/27 access list; playoff-dependent C/D identities resolved from the official UEFA playoff result.",
  row_sha256 = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
access$row_sha256 <- phase15_nl_rule_input_row_hash(access)
access <- phase15_nl_rule_input_validate_access_list(access, teams = team_group)

discipline <- data.frame(
  edition_id = edition_id,
  team_id = sort(access_order, method = "radix"),
  discipline_points = 0L,
  initialization_status = "initialized_pre_match",
  as_of_utc = retrieved_at,
  source_artifact_id = phase15_nl_rule_input_discipline_artifact_id(),
  source_url = article15_url,
  source_url_lineage = article15_url,
  retrieved_at_utc = retrieved_at,
  source_note = "Pre-match baseline: no 2026/27 league-phase matches have been played; discipline points are initialized to zero until official card totals are captured.",
  row_sha256 = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
discipline$row_sha256 <- phase15_nl_rule_input_row_hash(discipline)
discipline <- phase15_nl_rule_input_validate_discipline_points(discipline, teams = team_group)

dir.create(paths$directory, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(access, paths$access_list_path, row.names = FALSE, quote = TRUE, na = "")
utils::write.csv(discipline, paths$discipline_points_path, row.names = FALSE, quote = TRUE, na = "")

parser_commit <- tryCatch(
  trimws(system2("git", c("-C", capture_root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)[[1L]]),
  error = function(error) "manual-2026-08-27"
)
if (!nzchar(parser_commit)) parser_commit <- "manual-2026-08-27"

manifest <- data.frame(
  schema_version = "phase15-article15-rule-inputs-v1",
  rule_input_id = phase15_nl_rule_input_id(),
  edition_id = edition_id,
  capture_status = "accepted",
  access_list_artifact_id = phase15_nl_rule_input_access_artifact_id(),
  discipline_points_artifact_id = phase15_nl_rule_input_discipline_artifact_id(),
  access_list_relative_path = paths$access_list_relative_path,
  discipline_points_relative_path = paths$discipline_points_relative_path,
  access_list_sha256 = phase15_nl_rule_input_file_hash(paths$access_list_path),
  discipline_points_sha256 = phase15_nl_rule_input_file_hash(paths$discipline_points_path),
  source_url = access_url,
  source_url_lineage = paste(access_url, article15_url, playoff_url, sep = "|"),
  retrieved_at_utc = retrieved_at,
  discipline_initialization_policy = "zero_before_first_league_phase_match",
  parser_commit_sha = parser_commit,
  manifest_sha256 = "",
  row_sha256 = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
manifest$manifest_sha256 <- phase15_nl_rule_input_manifest_hash(manifest)
manifest$row_sha256 <- phase15_nl_rule_input_row_hash(manifest)
utils::write.csv(manifest, paths$manifest_path, row.names = FALSE, quote = TRUE, na = "")

validated <- phase15_nl_read_rule_inputs(capture_root, teams = team_group)
message(sprintf(
  "Captured %d access-list rows and %d initialized discipline rows (%s)",
  nrow(validated$access_list), nrow(validated$discipline_points), validated$manifest_sha256
))
