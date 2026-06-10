#' Transfermarkt Squad Strength Features
#'
#' Helpers for leakage-safe player valuation aggregation. The raw
#' transfermarkt-datasets snapshot is local-only; these functions can also work
#' with in-memory tables for tests and experiments.

#' Normalise common Transfermarkt-like column names
#' @keywords internal
normalise_transfermarkt_columns <- function(data) {
  names(data) <- tolower(names(data))
  names(data) <- gsub("[^a-z0-9]+", "_", names(data))
  names(data) <- gsub("^_|_$", "", names(data))
  data
}

#' Collapse Transfermarkt player positions into broad squad groups
#' @keywords internal
transfermarkt_position_group <- function(position, sub_position = NULL) {
  raw <- ifelse(!is.na(position) & nzchar(position), position, sub_position)
  raw <- tolower(ifelse(is.na(raw), "", raw))
  out <- rep("other", length(raw))
  out[grepl("goalkeeper|keeper", raw)] <- "goalkeeper"
  out[grepl("defender|back", raw)] <- "defense"
  out[grepl("midfield|midfield", raw)] <- "midfield"
  out[grepl("attack|forward|winger|striker", raw)] <- "attack"
  out
}

#' Sum the largest N available values
#' @keywords internal
sum_top_n <- function(values, n) {
  values <- sort(values[!is.na(values) & values >= 0], decreasing = TRUE)
  sum(head(values, n))
}

#' Stable log-scale growth from an older value to a current value
#' @keywords internal
log_value_growth <- function(current, previous) {
  if (!is.finite(current)) current <- 0
  if (!is.finite(previous)) previous <- 0
  log1p(current) - log1p(previous)
}

#' Validate a local Transfermarkt DuckDB snapshot
#'
#' @param snapshot_path Path to local transfermarkt-datasets DuckDB file
#' @return Metadata list with table names and file details
#' @export
validate_transfermarkt_snapshot <- function(snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb") {
  if (!file.exists(snapshot_path)) {
    stop(paste("Transfermarkt snapshot not found:", snapshot_path))
  }
  if (!requireNamespace("duckdb", quietly = TRUE) || !requireNamespace("DBI", quietly = TRUE)) {
    stop("Packages 'duckdb' and 'DBI' are required to read Transfermarkt snapshots")
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = snapshot_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  tables <- DBI::dbListTables(con)
  required <- c("players", "player_valuations")
  missing <- setdiff(required, tables)
  if (length(missing) > 0) {
    stop(paste("Transfermarkt snapshot missing required tables:", paste(missing, collapse = ", ")))
  }

  info <- file.info(snapshot_path)
  list(
    snapshot_path = snapshot_path,
    size_bytes = unname(info$size),
    modified_time = as.character(info$mtime),
    tables = tables
  )
}

#' Write local Transfermarkt snapshot metadata
#'
#' @param snapshot_path Path to local DuckDB snapshot
#' @param output_path Metadata CSV path
#' @return Metadata data frame
#' @export
write_transfermarkt_snapshot_metadata <- function(
    snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb",
    output_path = "data/raw/transfermarkt/SNAPSHOT-METADATA.csv"
) {
  meta <- validate_transfermarkt_snapshot(snapshot_path)
  checksum <- if (requireNamespace("tools", quietly = TRUE)) {
    unname(tools::md5sum(snapshot_path))
  } else {
    NA_character_
  }
  out <- data.frame(
    snapshot_path = meta$snapshot_path,
    size_bytes = meta$size_bytes,
    modified_time = meta$modified_time,
    md5 = checksum,
    tables = paste(meta$tables, collapse = "|"),
    generated_at = as.character(Sys.time()),
    stringsAsFactors = FALSE
  )
  if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
  write.csv(out, output_path, row.names = FALSE)
  out
}

#' Remove current-only profile columns that are unsafe for historical benchmarks
#' @keywords internal
drop_current_transfermarkt_profile_fields <- function(players) {
  current_cols <- c(
    "international_caps", "international_goals", "current_national_team_id",
    "market_value_in_eur", "highest_market_value_in_eur",
    "current_club_name", "current_club_id", "current_club_domestic_competition_id"
  )
  players[setdiff(names(players), intersect(current_cols, names(players)))]
}

#' Compute squad-strength features from a local DuckDB snapshot
#'
#' @param snapshot_path Local Transfermarkt DuckDB file
#' @param as_of_date Feature cutoff
#' @param output_path Optional CSV output path
#' @return Squad-strength feature data frame
#' @export
compute_transfermarkt_squad_strength_snapshot <- function(
    snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb",
    as_of_date = Sys.Date(),
    output_path = "data/processed/transfermarkt_squad_strength.csv"
) {
  validate_transfermarkt_snapshot(snapshot_path)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = snapshot_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  players <- DBI::dbReadTable(con, "players")
  valuations <- DBI::dbReadTable(con, "player_valuations")
  players <- normalise_transfermarkt_columns(players)
  valuations <- normalise_transfermarkt_columns(valuations)

  team_col <- intersect(
    c("current_national_team_name", "current_national_team", "country_of_citizenship", "country_name", "country"),
    names(players)
  )[1]
  if (is.na(team_col)) {
    stop("Could not find a national-team/country column in Transfermarkt players table")
  }
  value_col <- intersect(c("market_value_in_eur", "market_value", "market_value_eur"), names(valuations))[1]
  if (is.na(value_col)) {
    stop("Could not find a market-value column in Transfermarkt player_valuations table")
  }

  features <- compute_squad_strength_as_of(
    squad_players = players,
    valuations = valuations,
    as_of_date = as_of_date,
    team_col = team_col,
    player_id_col = "player_id",
    value_col = value_col
  )
  if (!is.null(output_path)) {
    if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
    write.csv(features, output_path, row.names = FALSE)
  }
  features
}

#' Compute squad-strength features for multiple historical cutoffs
#'
#' @param snapshot_path Local Transfermarkt DuckDB file
#' @param as_of_dates Cutoff dates to materialize
#' @param output_path Optional CSV output path
#' @param exclude_current_profile_fields Drop current-only player profile fields
#' @return Squad-strength feature data frame with one row per team/cutoff
#' @export
compute_transfermarkt_squad_strength_snapshots <- function(
    snapshot_path = "data/raw/transfermarkt/transfermarkt-datasets.duckdb",
    as_of_dates = NULL,
    output_path = "data/processed/transfermarkt_squad_strength.csv",
    exclude_current_profile_fields = TRUE
) {
  validate_transfermarkt_snapshot(snapshot_path)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = snapshot_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  players <- normalise_transfermarkt_columns(DBI::dbReadTable(con, "players"))
  valuations <- normalise_transfermarkt_columns(DBI::dbReadTable(con, "player_valuations"))

  if (exclude_current_profile_fields) {
    players <- drop_current_transfermarkt_profile_fields(players)
  }
  if (!"country_of_citizenship" %in% names(players)) {
    stop("Transfermarkt players table must contain country_of_citizenship")
  }
  players$country_of_citizenship[players$country_of_citizenship == "Türkiye"] <- "Turkey"

  if (is.null(as_of_dates)) {
    as_of_dates <- sort(unique(c(seq(as.Date("2000-01-01"), Sys.Date(), by = "6 months"), Sys.Date())))
  }
  as_of_dates <- sort(unique(as.Date(as_of_dates)))
  rows <- vector("list", length(as_of_dates))
  for (i in seq_along(as_of_dates)) {
    rows[[i]] <- compute_squad_strength_as_of(
      squad_players = players,
      valuations = valuations,
      as_of_date = as_of_dates[i],
      team_col = "country_of_citizenship",
      player_id_col = "player_id",
      value_col = "market_value_in_eur"
    )
  }
  features <- do.call(rbind, rows)
  features <- features[!is.na(features$team) & features$team != "", , drop = FALSE]
  rownames(features) <- NULL
  if (!is.null(output_path)) {
    if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
    write.csv(features, output_path, row.names = FALSE)
  }
  features
}

#' Select each player's latest valuation strictly before a cutoff
#'
#' @param valuations Data frame with player ID, valuation date, and value
#' @param as_of_date Date. Rows on or after this date are unavailable.
#' @param player_id_col Player identifier column
#' @param date_col Valuation date column
#' @param value_col Market value column in euros
#' @return Data frame with one latest pre-cutoff valuation per player
#' @export
latest_player_valuations_as_of <- function(
    valuations,
    as_of_date,
    player_id_col = "player_id",
    date_col = "date",
    value_col = "market_value_in_eur"
) {
  if (missing(valuations) || is.null(valuations)) stop("valuations is required")
  valuations <- normalise_transfermarkt_columns(valuations)
  player_id_col <- tolower(player_id_col)
  date_col <- tolower(date_col)
  value_col <- tolower(value_col)

  required_cols <- c(player_id_col, date_col, value_col)
  missing_cols <- setdiff(required_cols, names(valuations))
  if (length(missing_cols) > 0) {
    stop(paste("Valuations missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  as_of_date <- as.Date(as_of_date)
  valuations[[date_col]] <- as.Date(valuations[[date_col]])
  valuations[[value_col]] <- suppressWarnings(as.numeric(valuations[[value_col]]))

  available <- valuations[
    !is.na(valuations[[player_id_col]]) &
      !is.na(valuations[[date_col]]) &
      valuations[[date_col]] < as_of_date,
    ,
    drop = FALSE
  ]
  if (nrow(available) == 0) return(available[0, , drop = FALSE])

  available <- available[order(available[[player_id_col]], available[[date_col]]), , drop = FALSE]
  latest_idx <- ave(seq_len(nrow(available)), available[[player_id_col]], FUN = function(idx) tail(idx, 1))
  available[seq_len(nrow(available)) %in% as.integer(latest_idx), , drop = FALSE]
}

#' Aggregate squad-strength features for each team as of a cutoff
#'
#' @param squad_players Data frame with team/player rows
#' @param valuations Data frame with dated player valuations
#' @param as_of_date Feature cutoff; source rows must be before this date
#' @param team_col Team name column in squad_players
#' @param player_id_col Player identifier column
#' @param squad_date_col Optional dated squad-membership column
#' @param value_col Market value column in valuations
#' @return Data frame with one squad-strength row per team
#' @export
compute_squad_strength_as_of <- function(
    squad_players,
    valuations,
    as_of_date,
    team_col = "team",
    player_id_col = "player_id",
    squad_date_col = NULL,
    value_col = "market_value_in_eur"
) {
  if (missing(squad_players) || is.null(squad_players)) stop("squad_players is required")
  squad_players <- normalise_transfermarkt_columns(squad_players)
  valuations <- normalise_transfermarkt_columns(valuations)
  team_col <- tolower(team_col)
  player_id_col <- tolower(player_id_col)
  value_col <- tolower(value_col)
  as_of_date <- as.Date(as_of_date)

  required_cols <- c(team_col, player_id_col)
  missing_cols <- setdiff(required_cols, names(squad_players))
  if (length(missing_cols) > 0) {
    stop(paste("Squad table missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  if (!is.null(squad_date_col)) {
    squad_date_col <- tolower(squad_date_col)
    if (!squad_date_col %in% names(squad_players)) {
      stop(paste("Squad date column not found:", squad_date_col))
    }
    squad_players[[squad_date_col]] <- as.Date(squad_players[[squad_date_col]])
    squad_players <- squad_players[
      !is.na(squad_players[[squad_date_col]]) & squad_players[[squad_date_col]] < as_of_date,
      ,
      drop = FALSE
    ]
  }

  latest_values <- latest_player_valuations_as_of(
    valuations = valuations,
    as_of_date = as_of_date,
    player_id_col = player_id_col,
    date_col = "date",
    value_col = value_col
  )
  values_6m_ago <- latest_player_valuations_as_of(
    valuations = valuations,
    as_of_date = as_of_date - 183,
    player_id_col = player_id_col,
    date_col = "date",
    value_col = value_col
  )
  values_12m_ago <- latest_player_valuations_as_of(
    valuations = valuations,
    as_of_date = as_of_date - 365,
    player_id_col = player_id_col,
    date_col = "date",
    value_col = value_col
  )

  if (nrow(squad_players) == 0) {
    return(data.frame())
  }

  valuation_join <- data.frame(
    player_id = latest_values[[player_id_col]],
    valuation_value = latest_values[[value_col]],
    valuation_date = latest_values$date,
    stringsAsFactors = FALSE
  )
  names(valuation_join)[names(valuation_join) == "player_id"] <- player_id_col
  value_6m_join <- data.frame(
    player_id = values_6m_ago[[player_id_col]],
    valuation_value_6m_ago = values_6m_ago[[value_col]],
    stringsAsFactors = FALSE
  )
  names(value_6m_join)[names(value_6m_join) == "player_id"] <- player_id_col
  value_12m_join <- data.frame(
    player_id = values_12m_ago[[player_id_col]],
    valuation_value_12m_ago = values_12m_ago[[value_col]],
    stringsAsFactors = FALSE
  )
  names(value_12m_join)[names(value_12m_join) == "player_id"] <- player_id_col

  enriched <- merge(
    squad_players,
    valuation_join,
    by = player_id_col,
    all.x = TRUE,
    suffixes = c("", "_valuation")
  )
  enriched <- merge(enriched, value_6m_join, by = player_id_col, all.x = TRUE)
  enriched <- merge(enriched, value_12m_join, by = player_id_col, all.x = TRUE)

  enriched$valuation_value <- suppressWarnings(as.numeric(enriched$valuation_value))
  enriched$valuation_value_6m_ago <- suppressWarnings(as.numeric(enriched$valuation_value_6m_ago))
  enriched$valuation_value_12m_ago <- suppressWarnings(as.numeric(enriched$valuation_value_12m_ago))

  age_col <- intersect(c("age", "player_age"), names(enriched))[1]
  birth_col <- intersect(c("date_of_birth", "birth_date", "dob"), names(enriched))[1]
  if (is.na(age_col) && !is.na(birth_col)) {
    enriched$age <- as.numeric(as_of_date - as.Date(enriched[[birth_col]])) / 365.25
    age_col <- "age"
  }
  caps_col <- intersect(c("international_caps", "caps"), names(enriched))[1]
  goals_col <- intersect(c("international_goals", "national_team_goals", "goals"), names(enriched))[1]
  position_col <- intersect(c("position"), names(enriched))[1]
  sub_position_col <- intersect(c("sub_position"), names(enriched))[1]
  enriched$position_group <- transfermarkt_position_group(
    if (!is.na(position_col)) enriched[[position_col]] else NA_character_,
    if (!is.na(sub_position_col)) enriched[[sub_position_col]] else NA_character_
  )

  aggregate_team <- function(team_rows) {
    values <- team_rows$valuation_value
    present_values <- values[!is.na(values) & values >= 0]
    sorted_values <- sort(present_values, decreasing = TRUE)
    total_value <- sum(present_values)
    top11_value <- sum(head(sorted_values, 11))
    top15_value <- sum(head(sorted_values, 15))
    top23_value <- sum(head(sorted_values, 23))
    top5_value <- sum(head(sorted_values, 5))
    top11_mean <- if (length(sorted_values) > 0) mean(head(sorted_values, 11)) else 0
    reserve_values <- sorted_values[12:min(23, length(sorted_values))]
    reserve_mean <- if (length(reserve_values) > 0) mean(reserve_values) else 0
    values_6m <- team_rows$valuation_value_6m_ago
    values_12m <- team_rows$valuation_value_12m_ago
    total_value_6m <- sum(values_6m[!is.na(values_6m) & values_6m >= 0])
    total_value_12m <- sum(values_12m[!is.na(values_12m) & values_12m >= 0])
    top11_value_6m <- sum_top_n(values_6m, 11)
    top11_value_12m <- sum_top_n(values_12m, 11)

    position_value <- function(group) {
      sum(team_rows$valuation_value[team_rows$position_group == group & !is.na(team_rows$valuation_value)], na.rm = TRUE)
    }
    position_top_value <- function(group, n) {
      sum_top_n(team_rows$valuation_value[team_rows$position_group == group], n)
    }
    age_values <- if (!is.na(age_col)) suppressWarnings(as.numeric(team_rows[[age_col]])) else rep(NA_real_, nrow(team_rows))
    weighted_age <- if (sum(present_values) > 0 && any(is.finite(age_values) & !is.na(values) & values > 0)) {
      stats::weighted.mean(age_values[!is.na(values) & values > 0], values[!is.na(values) & values > 0], na.rm = TRUE)
    } else {
      NA_real_
    }
    top11_idx <- if (length(values) > 0) order(ifelse(is.na(values), -Inf, values), decreasing = TRUE)[seq_len(min(11, length(values)))] else integer(0)
    top11_age <- if (length(top11_idx) > 0) age_values[top11_idx] else numeric(0)
    top11_values <- if (length(top11_idx) > 0) values[top11_idx] else numeric(0)
    top11_positive <- !is.na(top11_values) & top11_values > 0

    data.frame(
      team = team_rows[[team_col]][1],
      as_of_date = as_of_date,
      feature_source_date = as_of_date - 1,
      squad_size = nrow(team_rows),
      num_players_with_value = length(present_values),
      squad_value = total_value,
      log_squad_value = log1p(total_value),
      top11_value = top11_value,
      log_top11_value = log1p(top11_value),
      top15_value = top15_value,
      log_top15_value = log1p(top15_value),
      top23_value = top23_value,
      log_top23_value = log1p(top23_value),
      median_player_value = if (length(present_values) > 0) median(present_values) else NA_real_,
      squad_value_concentration = if (total_value > 0) top11_value / total_value else NA_real_,
      top5_value_share = if (total_value > 0) top5_value / total_value else NA_real_,
      top11_to_top23_ratio = if (top23_value > 0) top11_value / top23_value else NA_real_,
      value_drop_11_to_23 = if (top11_mean > 0) (top11_mean - reserve_mean) / top11_mean else NA_real_,
      avg_age = if (!is.na(age_col)) mean(suppressWarnings(as.numeric(team_rows[[age_col]])), na.rm = TRUE) else NA_real_,
      value_weighted_avg_age = weighted_age,
      top11_avg_age = if (length(top11_age) > 0) mean(top11_age, na.rm = TRUE) else NA_real_,
      top11_u24_value_share = if (sum(top11_values[top11_positive]) > 0) {
        sum(top11_values[top11_positive & top11_age < 24], na.rm = TRUE) / sum(top11_values[top11_positive], na.rm = TRUE)
      } else {
        NA_real_
      },
      top11_over30_value_share = if (sum(top11_values[top11_positive]) > 0) {
        sum(top11_values[top11_positive & top11_age > 30], na.rm = TRUE) / sum(top11_values[top11_positive], na.rm = TRUE)
      } else {
        NA_real_
      },
      goalkeeper_value = position_value("goalkeeper"),
      log_goalkeeper_value = log1p(position_value("goalkeeper")),
      defense_value = position_value("defense"),
      log_defense_value = log1p(position_value("defense")),
      midfield_value = position_value("midfield"),
      log_midfield_value = log1p(position_value("midfield")),
      attack_value = position_value("attack"),
      log_attack_value = log1p(position_value("attack")),
      top1_goalkeeper_value = position_top_value("goalkeeper", 1),
      log_top1_goalkeeper_value = log1p(position_top_value("goalkeeper", 1)),
      top4_defense_value = position_top_value("defense", 4),
      log_top4_defense_value = log1p(position_top_value("defense", 4)),
      top4_midfield_value = position_top_value("midfield", 4),
      log_top4_midfield_value = log1p(position_top_value("midfield", 4)),
      top3_attack_value = position_top_value("attack", 3),
      log_top3_attack_value = log1p(position_top_value("attack", 3)),
      defense_value_share = if (total_value > 0) position_value("defense") / total_value else NA_real_,
      midfield_value_share = if (total_value > 0) position_value("midfield") / total_value else NA_real_,
      attack_value_share = if (total_value > 0) position_value("attack") / total_value else NA_real_,
      squad_value_momentum_6m = log_value_growth(total_value, total_value_6m),
      squad_value_momentum_12m = log_value_growth(total_value, total_value_12m),
      top11_value_momentum_6m = log_value_growth(top11_value, top11_value_6m),
      top11_value_momentum_12m = log_value_growth(top11_value, top11_value_12m),
      total_caps = if (!is.na(caps_col)) sum(suppressWarnings(as.numeric(team_rows[[caps_col]])), na.rm = TRUE) else NA_real_,
      total_goals = if (!is.na(goals_col)) sum(suppressWarnings(as.numeric(team_rows[[goals_col]])), na.rm = TRUE) else NA_real_,
      missing_value_share = mean(is.na(values)),
      stringsAsFactors = FALSE
    )
  }

  team_groups <- split(enriched, enriched[[team_col]])
  result <- do.call(rbind, lapply(team_groups, aggregate_team))
  numeric_cols <- names(result)[vapply(result, is.numeric, logical(1))]
  for (col in numeric_cols) result[[col]][!is.finite(result[[col]])] <- NA_real_
  rownames(result) <- NULL
  result
}
