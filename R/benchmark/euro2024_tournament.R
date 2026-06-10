#' EURO 2024 Tournament Simulation
#'
#' Dynamic tournament simulations using the same frozen model inputs as the
#' match-level EURO 2024 benchmark.

#' EURO 2024 group membership
#' @keywords internal
euro2024_groups <- function() {
  list(
    A = c("Germany", "Scotland", "Hungary", "Switzerland"),
    B = c("Spain", "Croatia", "Italy", "Albania"),
    C = c("Slovenia", "Denmark", "Serbia", "England"),
    D = c("Poland", "Netherlands", "Austria", "France"),
    E = c("Belgium", "Slovakia", "Romania", "Ukraine"),
    F = c("Turkey", "Georgia", "Portugal", "Czech Republic")
  )
}

#' EURO third-place pairing table for the four flexible R16 matches
#' @keywords internal
euro_third_place_pairing_table <- function() {
  data.frame(
    combo = c("ABCD", "ABCE", "ABCF", "ABDE", "ABDF", "ABEF", "ACDE", "ACDF", "ACEF", "ADEF", "BCDE", "BCDF", "BCEF", "BDEF", "CDEF"),
    vs_1B = c("A", "A", "A", "D", "D", "E", "E", "F", "E", "E", "E", "F", "F", "F", "F"),
    vs_1C = c("D", "E", "F", "E", "F", "F", "D", "D", "F", "F", "D", "D", "E", "E", "E"),
    vs_1E = c("B", "B", "B", "A", "A", "B", "C", "C", "C", "D", "B", "C", "C", "D", "D"),
    vs_1F = c("C", "C", "C", "B", "B", "A", "A", "A", "A", "A", "C", "B", "B", "B", "C"),
    stringsAsFactors = FALSE
  )
}

#' Actual EURO 2024 knockout outcomes
#' @keywords internal
actual_euro2024_stage <- function() {
  ro16 <- c(
    "Switzerland", "Italy", "Germany", "Denmark", "England", "Slovakia",
    "Spain", "Georgia", "France", "Belgium", "Portugal", "Slovenia",
    "Romania", "Netherlands", "Austria", "Turkey"
  )
  quarterfinal <- c("Germany", "Spain", "Portugal", "France", "England", "Switzerland", "Netherlands", "Turkey")
  semifinal <- c("Spain", "France", "Netherlands", "England")
  finalist <- c("Spain", "England")
  champion <- "Spain"
  teams <- unlist(euro2024_groups(), use.names = FALSE)
  data.frame(
    team = teams,
    actual_ro16 = teams %in% ro16,
    actual_quarterfinal = teams %in% quarterfinal,
    actual_semifinal = teams %in% semifinal,
    actual_final = teams %in% finalist,
    actual_champion = teams %in% champion,
    actual_stage = ifelse(teams == champion, "champion",
      ifelse(teams %in% setdiff(finalist, champion), "finalist",
        ifelse(teams %in% setdiff(semifinal, finalist), "semifinal",
          ifelse(teams %in% setdiff(quarterfinal, semifinal), "quarterfinal",
            ifelse(teams %in% setdiff(ro16, quarterfinal), "ro16", "group")
          )
        )
      )
    ),
    stringsAsFactors = FALSE
  )
}

#' Prepare baseline and hybrid models for EURO 2024 tournament simulations
#' @keywords internal
fit_euro2024_simulation_models <- function(
    matches_path = "data/processed/elo_matches.csv",
    elo_ratings_path = "data/processed/elo_ratings.csv",
    rolling_form_path = "data/processed/rolling_form.csv",
    squad_strength_path = "data/processed/transfermarkt_squad_strength_euro2024.csv",
    cutoff_date = as.Date("2024-06-14")
) {
  suppressPackageStartupMessages(library(MASS))
  if (!exists("select_euro2024_matches")) source("R/benchmark/euro2024.R")
  if (!exists("build_forecast_feature_table")) source("R/forecast/features.R")
  if (!exists("compute_goal_ability_features")) source("R/forecast/goal_ability.R")
  if (!exists("train_goal_model_from_features")) source("R/forecast/poisson.R")

  matches <- read.csv(matches_path, stringsAsFactors = FALSE)
  matches$date <- as.Date(matches$date)
  elo <- read.csv(elo_ratings_path, stringsAsFactors = FALSE)
  rolling <- if (file.exists(rolling_form_path)) read.csv(rolling_form_path, stringsAsFactors = FALSE) else NULL
  squad <- if (file.exists(squad_strength_path)) read.csv(squad_strength_path, stringsAsFactors = FALSE) else NULL

  training <- matches[
    matches$date < cutoff_date &
      !is.na(matches$home_score) &
      !is.na(matches$away_score) &
      !is.na(matches$home_team_canonical) &
      !is.na(matches$away_team_canonical),
    ,
    drop = FALSE
  ]
  baseline_train <- build_forecast_feature_table(training, elo, rolling_form = rolling)
  ability_train <- suppressWarnings(compute_goal_ability_features(training, matches))
  hybrid_train <- build_forecast_feature_table(
    training, elo, rolling_form = rolling, squad_strength = squad, goal_ability = ability_train
  )

  baseline_predictors <- c("elo_diff", "xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")
  hybrid_predictors <- hybrid_goal_predictors()

  bundle <- list(
    baseline = list(
      home = train_goal_model_from_features(baseline_train, "home", predictors = baseline_predictors),
      away = train_goal_model_from_features(baseline_train, "away", predictors = baseline_predictors),
      squad = NULL
    ),
    hybrid = list(
      home = train_goal_model_from_features(hybrid_train, "home", predictors = hybrid_predictors),
      away = train_goal_model_from_features(hybrid_train, "away", predictors = hybrid_predictors),
      squad = squad
    ),
    matches = matches,
    elo = elo,
    rolling = rolling,
    ability = suppressWarnings(compute_weighted_goal_ability(matches, cutoff_date)),
    cutoff_date = cutoff_date,
    fixture_predictions = list()
  )
  bundle$fixture_predictions$baseline <- precompute_euro2024_pair_forecasts(bundle, "baseline")
  bundle$fixture_predictions$hybrid <- precompute_euro2024_pair_forecasts(bundle, "hybrid")
  bundle
}

#' Precompute model forecasts for every ordered team pairing
#' @keywords internal
precompute_euro2024_pair_forecasts <- function(model_bundle, model_name) {
  teams <- unlist(euro2024_groups(), use.names = FALSE)
  pairs <- expand.grid(home_team = teams, away_team = teams, stringsAsFactors = FALSE)
  pairs <- pairs[pairs$home_team != pairs$away_team, , drop = FALSE]
  pairs$venue <- ifelse(pairs$home_team == "Germany", "home", ifelse(pairs$away_team == "Germany", "away", "neutral"))
  fixtures <- data.frame(
    date = model_bundle$cutoff_date,
    home_team_canonical = pairs$home_team,
    away_team_canonical = pairs$away_team,
    home_score = 0,
    away_score = 0,
    venue = pairs$venue,
    tournament = "UEFA Euro",
    stringsAsFactors = FALSE
  )
  context <- model_bundle[[model_name]]
  ability <- if (model_name == "hybrid") {
    ability_table <- model_bundle$ability
    lookup_ability <- function(team, col) {
      rows <- ability_table[ability_table$team == team, , drop = FALSE]
      if (nrow(rows) == 0 || !col %in% names(rows)) return(1)
      value <- rows[[col]][1]
      ifelse(is.finite(value), value, 1)
    }
    home_attack <- vapply(fixtures$home_team_canonical, lookup_ability, numeric(1), col = "attack_ability")
    away_attack <- vapply(fixtures$away_team_canonical, lookup_ability, numeric(1), col = "attack_ability")
    home_defense <- vapply(fixtures$home_team_canonical, lookup_ability, numeric(1), col = "defense_ability")
    away_defense <- vapply(fixtures$away_team_canonical, lookup_ability, numeric(1), col = "defense_ability")
    data.frame(
      home_attack_ability = home_attack,
      away_attack_ability = away_attack,
      home_defense_ability = home_defense,
      away_defense_ability = away_defense,
      attack_ability_diff = home_attack - away_attack,
      defense_ability_diff = home_defense - away_defense,
      goal_ability_source_date = model_bundle$cutoff_date - 1,
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }
  features <- build_forecast_feature_table(
    fixtures,
    model_bundle$elo,
    rolling_form = model_bundle$rolling,
    squad_strength = context$squad,
    goal_ability = ability,
    cutoff_date = model_bundle$cutoff_date
  )
  probs <- predict_feature_goal_probabilities(context$home, context$away, features)
  theta_or_inf <- function(model) {
    theta <- model$theta
    if (!is.null(theta) && is.finite(theta) && theta > 0) theta else Inf
  }
  data.frame(
    home_team = pairs$home_team,
    away_team = pairs$away_team,
    venue = pairs$venue,
    home_lambda = probs$expected_home_goals,
    away_lambda = probs$expected_away_goals,
    home_win_prob = probs$home_win_prob,
    draw_prob = probs$draw_prob,
    away_win_prob = probs$away_win_prob,
    home_theta = theta_or_inf(context$home),
    away_theta = theta_or_inf(context$away),
    stringsAsFactors = FALSE
  )
}

#' Build group-stage fixture list from checked-in EURO 2024 matches
#' @keywords internal
euro2024_group_fixtures <- function(matches, cutoff_date = as.Date("2024-06-14")) {
  euro <- select_euro2024_matches(matches, start_date = cutoff_date)
  fixtures <- euro[seq_len(36), , drop = FALSE]
  groups <- euro2024_groups()
  team_to_group <- setNames(rep(names(groups), lengths(groups)), unlist(groups, use.names = FALSE))
  fixtures$group <- unname(team_to_group[fixtures$home_team_canonical])
  fixtures
}

#' Create a cached one-match score simulator
#' @keywords internal
make_euro2024_match_simulator <- function(model_bundle, model_name) {
  rows <- model_bundle$fixture_predictions[[model_name]]
  forecast_cache <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(rows))) {
    key <- paste(rows$home_team[i], rows$away_team[i], rows$venue[i], sep = "||")
    assign(key, as.list(rows[i, , drop = FALSE]), envir = forecast_cache)
  }
  predict_fixture <- function(home_team, away_team, venue) {
    key <- paste(home_team, away_team, venue, sep = "||")
    if (!exists(key, envir = forecast_cache, inherits = FALSE)) {
      stop(paste("No precomputed forecast for", home_team, "vs", away_team, venue))
    }
    get(key, envir = forecast_cache, inherits = FALSE)
  }

  function(home_team, away_team, knockout = FALSE) {
    venue <- if (home_team == "Germany") "home" else if (away_team == "Germany") "away" else "neutral"
    pars <- predict_fixture(home_team, away_team, venue)
    draw_goal <- function(lambda, theta) {
      if (is.infinite(theta)) stats::rpois(1, lambda) else stats::rnbinom(1, size = theta, mu = lambda)
    }
    home_goals <- draw_goal(pars$home_lambda, pars$home_theta)
    away_goals <- draw_goal(pars$away_lambda, pars$away_theta)
    winner <- NA_character_
    if (home_goals > away_goals) {
      winner <- home_team
    } else if (away_goals > home_goals) {
      winner <- away_team
    } else if (knockout) {
      decisive <- pars$home_win_prob + pars$away_win_prob
      home_tiebreak_prob <- if (decisive > 0) pars$home_win_prob / decisive else 0.5
      winner <- if (stats::runif(1) <= home_tiebreak_prob) home_team else away_team
    }
    list(home_goals = home_goals, away_goals = away_goals, winner = winner)
  }
}

#' Rank one EURO group from simulated match statistics
#' @keywords internal
rank_group_table <- function(table) {
  table$gd <- table$gf - table$ga
  table$tiebreak <- stats::runif(nrow(table), 0, 1e-6)
  table[order(-table$points, -table$gd, -table$gf, table$tiebreak), , drop = FALSE]
}

#' Simulate one EURO 2024 tournament
#' @keywords internal
simulate_one_euro2024_tournament <- function(model_bundle, model_name) {
  groups <- euro2024_groups()
  teams <- unlist(groups, use.names = FALSE)
  fixtures <- euro2024_group_fixtures(model_bundle$matches, model_bundle$cutoff_date)
  sim_match <- make_euro2024_match_simulator(model_bundle, model_name)

  standings <- data.frame(
    team = teams,
    group = setNames(rep(names(groups), lengths(groups)), teams)[teams],
    points = 0,
    gf = 0,
    ga = 0,
    stringsAsFactors = FALSE
  )
  rownames(standings) <- standings$team

  for (i in seq_len(nrow(fixtures))) {
    home <- fixtures$home_team_canonical[i]
    away <- fixtures$away_team_canonical[i]
    score <- sim_match(home, away, knockout = FALSE)
    standings[home, "gf"] <- standings[home, "gf"] + score$home_goals
    standings[home, "ga"] <- standings[home, "ga"] + score$away_goals
    standings[away, "gf"] <- standings[away, "gf"] + score$away_goals
    standings[away, "ga"] <- standings[away, "ga"] + score$home_goals
    if (score$home_goals > score$away_goals) {
      standings[home, "points"] <- standings[home, "points"] + 3
    } else if (score$away_goals > score$home_goals) {
      standings[away, "points"] <- standings[away, "points"] + 3
    } else {
      standings[home, "points"] <- standings[home, "points"] + 1
      standings[away, "points"] <- standings[away, "points"] + 1
    }
  }

  ranked <- lapply(names(groups), function(g) {
    out <- rank_group_table(standings[standings$group == g, , drop = FALSE])
    out$rank <- seq_len(nrow(out))
    out
  })
  names(ranked) <- names(groups)
  slots <- list()
  thirds <- list()
  for (g in names(ranked)) {
    slots[[paste0(g, "1")]] <- ranked[[g]]$team[1]
    slots[[paste0(g, "2")]] <- ranked[[g]]$team[2]
    third <- ranked[[g]][3, , drop = FALSE]
    third$third_group <- g
    thirds[[g]] <- third
  }
  third_table <- do.call(rbind, thirds)
  third_table <- rank_group_table(third_table)
  qualified_thirds <- third_table[seq_len(4), , drop = FALSE]
  combo <- paste(sort(qualified_thirds$third_group), collapse = "")
  pairing <- euro_third_place_pairing_table()
  pairing <- pairing[pairing$combo == combo, , drop = FALSE]
  if (nrow(pairing) != 1) stop(paste("Missing third-place pairing for", combo))
  third_team <- function(g) qualified_thirds$team[qualified_thirds$third_group == g][1]

  r16 <- list(
    m37 = c(slots$A2, slots$B2),
    m38 = c(slots$A1, slots$C2),
    m39 = c(slots$C1, third_team(pairing$vs_1C)),
    m40 = c(slots$B1, third_team(pairing$vs_1B)),
    m41 = c(slots$D2, slots$E2),
    m42 = c(slots$F1, third_team(pairing$vs_1F)),
    m43 = c(slots$E1, third_team(pairing$vs_1E)),
    m44 = c(slots$D1, slots$F2)
  )
  winners <- lapply(r16, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)

  qf <- list(
    qf1 = c(winners$m38, winners$m40),
    qf2 = c(winners$m42, winners$m41),
    qf3 = c(winners$m39, winners$m37),
    qf4 = c(winners$m43, winners$m44)
  )
  qf_winners <- lapply(qf, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)
  sf <- list(
    sf1 = c(qf_winners$qf1, qf_winners$qf2),
    sf2 = c(qf_winners$qf4, qf_winners$qf3)
  )
  sf_winners <- lapply(sf, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)
  final <- c(sf_winners$sf1, sf_winners$sf2)
  champion <- sim_match(final[1], final[2], knockout = TRUE)$winner

  data.frame(
    team = teams,
    ro16 = teams %in% unlist(r16),
    quarterfinal = teams %in% unlist(qf),
    semifinal = teams %in% unlist(sf),
    final = teams %in% final,
    champion = teams == champion,
    stringsAsFactors = FALSE
  )
}

#' Simulate one EURO 2024 tournament with a prebuilt match simulator
#' @keywords internal
simulate_one_euro2024_tournament_cached <- function(model_bundle, sim_match) {
  groups <- euro2024_groups()
  teams <- unlist(groups, use.names = FALSE)
  fixtures <- euro2024_group_fixtures(model_bundle$matches, model_bundle$cutoff_date)

  standings <- data.frame(
    team = teams,
    group = setNames(rep(names(groups), lengths(groups)), teams)[teams],
    points = 0,
    gf = 0,
    ga = 0,
    stringsAsFactors = FALSE
  )
  rownames(standings) <- standings$team

  for (i in seq_len(nrow(fixtures))) {
    home <- fixtures$home_team_canonical[i]
    away <- fixtures$away_team_canonical[i]
    score <- sim_match(home, away, knockout = FALSE)
    standings[home, "gf"] <- standings[home, "gf"] + score$home_goals
    standings[home, "ga"] <- standings[home, "ga"] + score$away_goals
    standings[away, "gf"] <- standings[away, "gf"] + score$away_goals
    standings[away, "ga"] <- standings[away, "ga"] + score$home_goals
    if (score$home_goals > score$away_goals) {
      standings[home, "points"] <- standings[home, "points"] + 3
    } else if (score$away_goals > score$home_goals) {
      standings[away, "points"] <- standings[away, "points"] + 3
    } else {
      standings[home, "points"] <- standings[home, "points"] + 1
      standings[away, "points"] <- standings[away, "points"] + 1
    }
  }

  ranked <- lapply(names(groups), function(g) {
    out <- rank_group_table(standings[standings$group == g, , drop = FALSE])
    out$rank <- seq_len(nrow(out))
    out
  })
  names(ranked) <- names(groups)
  slots <- list()
  thirds <- list()
  for (g in names(ranked)) {
    slots[[paste0(g, "1")]] <- ranked[[g]]$team[1]
    slots[[paste0(g, "2")]] <- ranked[[g]]$team[2]
    third <- ranked[[g]][3, , drop = FALSE]
    third$third_group <- g
    thirds[[g]] <- third
  }
  third_table <- do.call(rbind, thirds)
  third_table <- rank_group_table(third_table)
  qualified_thirds <- third_table[seq_len(4), , drop = FALSE]
  combo <- paste(sort(qualified_thirds$third_group), collapse = "")
  pairing <- euro_third_place_pairing_table()
  pairing <- pairing[pairing$combo == combo, , drop = FALSE]
  if (nrow(pairing) != 1) stop(paste("Missing third-place pairing for", combo))
  third_team <- function(g) qualified_thirds$team[qualified_thirds$third_group == g][1]

  r16 <- list(
    m37 = c(slots$A2, slots$B2),
    m38 = c(slots$A1, slots$C2),
    m39 = c(slots$C1, third_team(pairing$vs_1C)),
    m40 = c(slots$B1, third_team(pairing$vs_1B)),
    m41 = c(slots$D2, slots$E2),
    m42 = c(slots$F1, third_team(pairing$vs_1F)),
    m43 = c(slots$E1, third_team(pairing$vs_1E)),
    m44 = c(slots$D1, slots$F2)
  )
  winners <- lapply(r16, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)
  qf <- list(
    qf1 = c(winners$m38, winners$m40),
    qf2 = c(winners$m42, winners$m41),
    qf3 = c(winners$m39, winners$m37),
    qf4 = c(winners$m43, winners$m44)
  )
  qf_winners <- lapply(qf, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)
  sf <- list(
    sf1 = c(qf_winners$qf1, qf_winners$qf2),
    sf2 = c(qf_winners$qf4, qf_winners$qf3)
  )
  sf_winners <- lapply(sf, function(x) sim_match(x[1], x[2], knockout = TRUE)$winner)
  final <- c(sf_winners$sf1, sf_winners$sf2)
  champion <- sim_match(final[1], final[2], knockout = TRUE)$winner

  data.frame(
    team = teams,
    ro16 = teams %in% unlist(r16),
    quarterfinal = teams %in% unlist(qf),
    semifinal = teams %in% unlist(sf),
    final = teams %in% final,
    champion = teams == champion,
    stringsAsFactors = FALSE
  )
}

#' Simulate EURO 2024 tournament paths for baseline and hybrid models
#'
#' @param n_sim Number of tournament simulations per model
#' @param seed Random seed
#' @param output_dir Output directory for CSV diagnostics
#' @return List with team probabilities and actual-outcome comparison
#' @export
simulate_euro2024_tournament_models <- function(
    n_sim = 5000,
    seed = 20240614,
    output_dir = "outputs/benchmarks/euro2024_tournament",
    ...
) {
  if (!exists("predict_feature_goal_probabilities")) source("R/benchmark/euro2024.R")
  model_bundle <- fit_euro2024_simulation_models(...)
  actual <- actual_euro2024_stage()

  simulate_model <- function(model_name, seed_offset) {
    set.seed(seed + seed_offset)
    sim_match <- make_euro2024_match_simulator(model_bundle, model_name)
    teams <- unlist(euro2024_groups(), use.names = FALSE)
    counts <- data.frame(
      team = teams,
      ro16 = 0,
      quarterfinal = 0,
      semifinal = 0,
      final = 0,
      champion = 0,
      stringsAsFactors = FALSE
    )
    rownames(counts) <- counts$team
    for (i in seq_len(n_sim)) {
      sim <- simulate_one_euro2024_tournament_cached(model_bundle, sim_match)
      rownames(sim) <- sim$team
      stage_cols <- c("ro16", "quarterfinal", "semifinal", "final", "champion")
      counts[sim$team, stage_cols] <- counts[sim$team, stage_cols] + sim[sim$team, stage_cols]
      if (n_sim >= 5000 && i %% 1000 == 0) {
        cat(model_name, "simulated", i, "of", n_sim, "tournaments\n")
      }
    }
    counts[, c("ro16", "quarterfinal", "semifinal", "final", "champion")] <-
      counts[, c("ro16", "quarterfinal", "semifinal", "final", "champion")] / n_sim
    rownames(counts) <- NULL
    counts
  }

  baseline <- simulate_model("baseline", 0)
  baseline$model <- "baseline"
  hybrid <- simulate_model("hybrid", 100000)
  hybrid$model <- "hybrid"
  team_probs <- rbind(baseline, hybrid)
  names(team_probs)[names(team_probs) == "ro16"] <- "ro16_prob"
  names(team_probs)[names(team_probs) == "quarterfinal"] <- "quarterfinal_prob"
  names(team_probs)[names(team_probs) == "semifinal"] <- "semifinal_prob"
  names(team_probs)[names(team_probs) == "final"] <- "final_prob"
  names(team_probs)[names(team_probs) == "champion"] <- "champion_prob"
  team_probs <- merge(team_probs, actual, by = "team", all.x = TRUE)
  team_probs <- team_probs[order(team_probs$model, -team_probs$champion_prob, team_probs$team), , drop = FALSE]

  comparison <- do.call(rbind, lapply(split(team_probs, team_probs$model), function(rows) {
    data.frame(
      model = rows$model[1],
      actual_champion_probability = rows$champion_prob[rows$actual_champion][1],
      actual_champion_rank = rank(-rows$champion_prob, ties.method = "min")[rows$actual_champion][1],
      mean_actual_finalist_probability = mean(rows$final_prob[rows$actual_final]),
      mean_actual_semifinalist_probability = mean(rows$semifinal_prob[rows$actual_semifinal]),
      mean_actual_quarterfinalist_probability = mean(rows$quarterfinal_prob[rows$actual_quarterfinal]),
      mean_actual_ro16_probability = mean(rows$ro16_prob[rows$actual_ro16]),
      most_likely_champion = rows$team[which.max(rows$champion_prob)],
      most_likely_champion_probability = max(rows$champion_prob),
      n_sim = n_sim,
      stringsAsFactors = FALSE
    )
  }))
  rownames(comparison) <- NULL

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  write.csv(team_probs, file.path(output_dir, "euro2024_tournament_team_probs.csv"), row.names = FALSE)
  write.csv(comparison, file.path(output_dir, "euro2024_tournament_actual_comparison.csv"), row.names = FALSE)
  list(team_probs = team_probs, comparison = comparison, n_sim = n_sim, output_dir = output_dir)
}
