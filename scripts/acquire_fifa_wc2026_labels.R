# Acquire the official FIFA World Cup 2026 results for the Phase 12 label seam.
# The local fixture file contributes only xGelo fixture identities and team names;
# all scores are read from FIFA's official calendar API.

args <- commandArgs(trailingOnly = TRUE)
output_path <- if (length(args)) args[[1L]] else "data/benchmark/phase12/wc2026_labels.csv"

fifa_calendar_url <- paste0(
  "https://api.fifa.com/api/v3/calendar/matches",
  "?from=2026-06-11&to=2026-07-20&language=en",
  "&idCompetition=17&count=200"
)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The FIFA label acquisition script requires the jsonlite package", call. = FALSE)
}

scalar_character <- function(value, default = NA_character_) {
  if (length(value) == 0L || is.null(value[[1L]])) return(default)
  as.character(value[[1L]])
}

scalar_integer <- function(value, default = NA_integer_) {
  parsed <- suppressWarnings(as.integer(scalar_character(value, NA_character_)))
  if (length(parsed) == 0L || is.na(parsed[[1L]])) default else parsed[[1L]]
}

team_key <- function(value) {
  value <- iconv(as.character(value), from = "UTF-8", to = "ASCII//TRANSLIT")
  value <- tolower(gsub("[^[:alnum:]]", "", value, perl = TRUE))
  value[value == "usa"] <- "unitedstates"
  value[value == "turkiye"] <- "turkey"
  value[value == "cotedivoire"] <- "ivorycoast"
  value[value == "caboverde"] <- "capeverde"
  value[value == "czechia"] <- "czechrepublic"
  value[value == "iriran"] <- "iran"
  value[value == "congodr"] <- "drcongo"
  value
}

cache_path <- tempfile("fifa-wc2026-calendar-", fileext = ".json")
on.exit(unlink(cache_path), add = TRUE)
download.file(fifa_calendar_url, cache_path, mode = "wb", quiet = TRUE, method = "libcurl")

payload <- jsonlite::fromJSON(cache_path, simplifyVector = FALSE)
if (length(payload$Results) != 104L) {
  stop("FIFA calendar did not return exactly 104 World Cup 2026 matches", call. = FALSE)
}

official <- do.call(rbind, lapply(payload$Results, function(match_row) {
  data.frame(
    match_number = scalar_integer(match_row$MatchNumber),
    source_match_id = scalar_character(match_row$IdMatch),
    fifa_match_date = substr(scalar_character(match_row$Date), 1L, 10L),
    fifa_home_team = scalar_character(match_row$Home$ShortClubName),
    fifa_away_team = scalar_character(match_row$Away$ShortClubName),
    fifa_home_team_id = scalar_character(match_row$Home$IdTeam),
    fifa_away_team_id = scalar_character(match_row$Away$IdTeam),
    final_home_goals = scalar_integer(match_row$HomeTeamScore),
    final_away_goals = scalar_integer(match_row$AwayTeamScore),
    home_penalty_score = scalar_integer(match_row$HomeTeamPenaltyScore),
    away_penalty_score = scalar_integer(match_row$AwayTeamPenaltyScore),
    winner_team_id = scalar_character(match_row$Winner),
    result_type = scalar_integer(match_row$ResultType),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}))

group_fixtures_path <- "data/raw/worldcup_2026_group_fixtures.csv"
if (!file.exists(group_fixtures_path)) {
  stop("Missing xGelo group-fixture identity file: ", group_fixtures_path, call. = FALSE)
}
group_fixtures <- utils::read.csv(group_fixtures_path, stringsAsFactors = FALSE, check.names = FALSE)
required_group <- c("match_id", "home_team", "away_team")
missing_group <- setdiff(required_group, names(group_fixtures))
if (length(missing_group)) {
  stop("Group-fixture identity file is missing: ", paste(missing_group, collapse = ", "), call. = FALSE)
}
if (nrow(group_fixtures) != 72L || anyDuplicated(group_fixtures$match_id)) {
  stop("xGelo group-fixture identity file must contain 72 unique rows", call. = FALSE)
}

group_key <- paste(team_key(group_fixtures$home_team), team_key(group_fixtures$away_team), sep = "|")
official_group_key <- paste(team_key(official$fifa_home_team), team_key(official$fifa_away_team), sep = "|")
group_index <- match(official_group_key, group_key)
official$fixture_id <- ifelse(
  official$match_number <= 72L,
  group_fixtures$match_id[group_index],
  paste0("M", official$match_number)
)
if (anyNA(official$fixture_id) || anyDuplicated(official$fixture_id)) {
  stop("FIFA match rows could not be mapped to unique xGelo fixture identities", call. = FALSE)
}

expected_group_ids <- as.character(group_fixtures$match_id)
if (!setequal(official$fixture_id[official$match_number <= 72L], expected_group_ids)) {
  stop("FIFA group matches do not cover the xGelo group-fixture identity set", call. = FALSE)
}

# FIFA's calendar scores are regulation scores for ordinary and shootout matches,
# but are after extra time for ResultType 3. These five regulation scores are
# reconstructed from the corresponding official FIFA post-match reports.
extra_time_regulation <- data.frame(
  match_number = c(82L, 86L, 99L, 100L, 104L),
  regulation_home_goals = c(2L, 1L, 1L, 1L, 0L),
  regulation_away_goals = c(2L, 1L, 1L, 1L, 0L),
  stringsAsFactors = FALSE
)

report_urls <- c(
  `74` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M74-GER-V-PAR.pdf",
  `75` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M75-NED-V-MAR.pdf",
  `82` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M82-BEL-V-SEN.pdf",
  `86` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M86-ARG-V-CPV.pdf",
  `88` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M88-AUS-V-EGY.pdf",
  `96` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M96-SUI-V-COL.pdf",
  `99` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M99-NOR-V-ENG.pdf",
  `100` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M100-ARG-V-SUI.pdf",
  `104` = "https://www.fifatrainingcentre.com/media/native/tournaments/fifa-world-cup/2026/PMSR-M104-ESP-V-ARG.pdf"
)

official$regulation_home_goals <- official$final_home_goals
official$regulation_away_goals <- official$final_away_goals
extra_time_index <- match(official$match_number, extra_time_regulation$match_number)
has_extra_time_override <- !is.na(extra_time_index)
official$regulation_home_goals[has_extra_time_override] <- extra_time_regulation$regulation_home_goals[extra_time_index[has_extra_time_override]]
official$regulation_away_goals[has_extra_time_override] <- extra_time_regulation$regulation_away_goals[extra_time_index[has_extra_time_override]]

official$edition_id <- "wc2026"
official$went_extra_time <- official$result_type %in% c(2L, 3L)
official$went_penalties <- !is.na(official$home_penalty_score) | !is.na(official$away_penalty_score)
official$source_url <- fifa_calendar_url
official$regulation_score_source_url <- fifa_calendar_url
official$regulation_score_basis <- ifelse(
  official$result_type == 1L,
  "FIFA calendar score (regulation time)",
  ifelse(
    official$result_type == 2L,
    "FIFA calendar score before penalty shootout",
    "FIFA official post-match report goal timeline before extra time"
  )
)
report_index <- match(as.character(official$match_number), names(report_urls))
official$regulation_score_source_url[!is.na(report_index)] <- unname(report_urls[report_index[!is.na(report_index)]])
official$source_retrieval_date <- as.character(Sys.Date())

output <- official[, c(
  "fixture_id", "edition_id", "regulation_home_goals", "regulation_away_goals",
  "final_home_goals", "final_away_goals", "went_extra_time", "went_penalties",
  "match_number", "source_match_id", "fifa_match_date", "fifa_home_team", "fifa_away_team",
  "fifa_home_team_id", "fifa_away_team_id", "winner_team_id", "result_type",
  "home_penalty_score", "away_penalty_score", "regulation_score_basis",
  "source_url", "regulation_score_source_url", "source_retrieval_date"
)]
output <- output[order(output$match_number), , drop = FALSE]
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(output, output_path, row.names = FALSE, na = "", quote = TRUE)
cat("Wrote", nrow(output), "official FIFA WC2026 labels to", output_path, "\n")
