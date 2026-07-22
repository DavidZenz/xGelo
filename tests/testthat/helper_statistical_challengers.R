statistical_test_editions <- function() {
  data.frame(
    edition_id = c(
      "wc1994", "euro1996", "wc1998", "euro2000",
      "wc2002", "euro2004", "wc2006", "euro2008", "wc2010"
    ),
    competition_id = rep(c("world_cup", "euro"), length.out = 9L),
    opener_date = as.Date(c(
      "1994-06-17", "1996-06-08", "1998-06-10", "2000-06-10",
      "2002-05-31", "2004-06-12", "2006-06-09", "2008-06-07",
      "2010-06-11"
    )),
    final_date = as.Date(c(
      "1994-07-17", "1996-06-30", "1998-07-12", "2000-07-02",
      "2002-06-30", "2004-07-04", "2006-07-09", "2008-06-29",
      "2010-07-11"
    )),
    stringsAsFactors = FALSE
  )
}

synthetic_statistical_history <- function(include_outer = TRUE) {
  set.seed(1001L)
  editions <- statistical_test_editions()
  teams <- c("team_alpha", "team_beta", "team_gamma", "team_delta", "team_epsilon", "team_zeta")
  rows <- do.call(rbind, lapply(seq_len(nrow(editions)), function(i) {
    if (!include_outer && editions$edition_id[i] == "wc2010") return(NULL)
    n <- if (editions$edition_id[i] == "wc2010") 4L else 3L
    home_index <- ((seq_len(n) + i - 2L) %% 5L) + 1L
    away_index <- ((home_index + i) %% 5L) + 1L
    if (editions$edition_id[i] == "euro2008") {
      home_index[n] <- 6L
      away_index[n] <- 1L
    }
    dates <- editions$opener_date[i] + seq_len(n) - 1L
    elo_diff <- as.numeric((home_index - away_index) * 35 + i)
    data.frame(
      match_id = sprintf("%s_match_%02d", editions$edition_id[i], seq_len(n)),
      fixture_id = sprintf("%s_fixture_%02d", editions$edition_id[i], seq_len(n)),
      edition_id = editions$edition_id[i],
      tournament = if (editions$competition_id[i] == "world_cup") "FIFA World Cup" else "UEFA Euro",
      date = dates,
      actual_completion_date = dates,
      evidence_cutoff_exclusive = dates + 1L,
      home_team_id = teams[home_index],
      away_team_id = teams[away_index],
      home_goals = as.integer((seq_len(n) + i) %% 4L),
      away_goals = as.integer((2L * seq_len(n) + i) %% 3L),
      regulation_home_goals = as.integer((seq_len(n) + i) %% 4L),
      regulation_away_goals = as.integer((2L * seq_len(n) + i) %% 3L),
      venue_role = ifelse(seq_len(n) %% 3L == 0L, "home", "neutral"),
      neutral = seq_len(n) %% 3L != 0L,
      elo_diff = elo_diff,
      elo_diff__value_present = TRUE,
      elo_diff__source_present = TRUE,
      elo_diff__source_date = dates - 1L,
      elo_diff__imputed = FALSE,
      elo_diff__imputation_reason = "",
      stringsAsFactors = FALSE
    )
  }))
  rownames(rows) <- NULL
  rows
}

synthetic_statistical_folds <- function(outer_edition_id = "wc2010") {
  tournaments <- statistical_test_editions()
  outer <- tournaments[tournaments$edition_id == outer_edition_id, , drop = FALSE]
  if (nrow(outer) != 1L) stop("outer_edition_id must identify one synthetic edition", call. = FALSE)
  inner <- tournaments[tournaments$final_date < outer$opener_date, , drop = FALSE]
  tuning_editions <- data.frame(
    outer_edition_id = outer_edition_id,
    inner_edition_id = inner$edition_id,
    inner_final_date = inner$final_date,
    outer_opener_date = outer$opener_date,
    objective_track = "updating",
    eligible_match_ids_sha256 = vapply(
      seq_len(nrow(inner)),
      function(i) paste0(substr("123456789abcdef0", i, i), strrep("1", 63L)),
      character(1)
    ),
    stringsAsFactors = FALSE
  )
  tuning_grid <- rbind(
    data.frame(
      parameter_id = "team_ridge_lambda",
      value = c(0.1, 1, 10),
      selection_stage = 1L,
      tie_break = "largest_penalty",
      stringsAsFactors = FALSE
    ),
    data.frame(
      parameter_id = "elo_lasso_lambda",
      value = c(0.01, 0.1, 1),
      selection_stage = 2L,
      tie_break = "largest_penalty",
      stringsAsFactors = FALSE
    )
  )
  tracks <- data.frame(
    outer_edition_id = outer_edition_id,
    track_id = c("frozen", "updating"),
    evidence_cutoff_exclusive = outer$opener_date,
    stringsAsFactors = FALSE
  )
  list(
    tournaments = tournaments,
    tuning_editions = tuning_editions,
    tuning_grid = tuning_grid,
    tracks = tracks,
    outer = outer
  )
}

synthetic_sparse_teams <- function() {
  history <- synthetic_statistical_history(include_outer = FALSE)
  registered_team_ids <- c(
    "team_alpha", "team_beta", "team_gamma", "team_delta",
    "team_epsilon", "team_zeta", "team_unseen_one", "team_unseen_two"
  )
  fixtures <- data.frame(
    fixture_id = c(
      "known_neutral", "known_neutral_reversed", "one_unseen_home",
      "one_unseen_away", "two_unseen", "sparse_known"
    ),
    edition_id = "wc2010",
    boundary_id = "wc2010__frozen",
    actual_completion_date = as.Date("2010-06-11"),
    evidence_cutoff_exclusive = as.Date("2010-06-11"),
    home_team_id = c(
      "team_alpha", "team_beta", "team_unseen_one",
      "team_alpha", "team_unseen_one", "team_zeta"
    ),
    away_team_id = c(
      "team_beta", "team_alpha", "team_beta",
      "team_unseen_one", "team_unseen_two", "team_alpha"
    ),
    venue_role = c("neutral", "neutral", "neutral", "neutral", "neutral", "home"),
    elo_diff = c(70, -70, 0, 0, 0, -25),
    elo_diff__value_present = TRUE,
    elo_diff__source_present = TRUE,
    elo_diff__source_date = as.Date("2010-06-10"),
    elo_diff__imputed = FALSE,
    elo_diff__imputation_reason = "",
    stringsAsFactors = FALSE
  )
  list(
    history = history,
    registered_team_ids = registered_team_ids,
    fixtures = fixtures,
    sparse_team_id = "team_zeta",
    unseen_team_ids = c("team_unseen_one", "team_unseen_two")
  )
}

statistical_pmf_oracles <- function() {
  grid <- expand.grid(home_goals = 0:2, away_goals = 0:2)
  independent <- stats::dpois(grid$home_goals, lambda = 1.2) *
    stats::dpois(grid$away_goals, lambda = 0.8)
  independent <- independent / sum(independent)
  data.frame(
    oracle_id = "independent_mu_1_2_0_8",
    home_goals = grid$home_goals,
    away_goals = grid$away_goals,
    probability = independent,
    mu_home = 1.2,
    mu_away = 0.8,
    support_max = 2L,
    stringsAsFactors = FALSE
  )
}

synthetic_phase10_registries <- function(candidate_id = "poisson_team_ridge_elo") {
  tournament_counts <- data.frame(
    edition_id = c(
      paste0("wc", c(2002, 2006, 2010, 2014, 2018, 2022)),
      paste0("euro", c(2004, 2008, 2012, 2016, 2020, 2024))
    ),
    competition_id = rep(c("world_cup", "euro"), each = 6L),
    expected_fixture_count = c(rep(64L, 6L), rep(31L, 3L), rep(51L, 3L)),
    headline_weight = 1 / 12,
    stringsAsFactors = FALSE
  )
  fixture_ids <- unlist(lapply(seq_len(nrow(tournament_counts)), function(i) {
    sprintf("%s_%03d", tournament_counts$edition_id[i], seq_len(tournament_counts$expected_fixture_count[i]))
  }), use.names = FALSE)
  edition_ids <- rep(tournament_counts$edition_id, tournament_counts$expected_fixture_count)
  open_panel <- data.frame(
    panel_id = "open_core",
    edition_id = edition_ids,
    fixture_id = fixture_ids,
    eligible = TRUE,
    output_coverage_required = TRUE,
    stringsAsFactors = FALSE
  )
  rich_eligible <- seq_along(fixture_ids) <= 609L
  rich_panel <- data.frame(
    panel_id = "feature_rich",
    edition_id = edition_ids,
    fixture_id = fixture_ids,
    eligible = rich_eligible,
    output_coverage_required = rich_eligible,
    stringsAsFactors = FALSE
  )
  model_registry <- data.frame(
    model_id = c(
      "uniform_1x2", "expanding_1x2", "elo_goal_nb",
      "open_nb_incumbent", "production_hybrid_nb"
    ),
    panel_id = c(rep("open_core", 4L), "feature_rich"),
    stringsAsFactors = FALSE
  )
  comparison_keys <- do.call(rbind, lapply(seq_len(nrow(model_registry)), function(i) {
    baseline_id <- model_registry$model_id[i]
    ids <- if (model_registry$panel_id[i] == "feature_rich") fixture_ids[rich_eligible] else fixture_ids
    data.frame(
      candidate_id = candidate_id,
      baseline_id = baseline_id,
      comparison_panel_id = model_registry$panel_id[i],
      fixture_id = ids,
      stringsAsFactors = FALSE
    )
  }))
  list(
    tournaments = tournament_counts,
    panel_fixtures = rbind(open_panel, rich_panel),
    model_registry = model_registry,
    comparison_keys = comparison_keys,
    score_support_max = 40L,
    track_ids = c("frozen", "updating"),
    parent_hashes = c(
      phase09_bundle_sha256 = "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069",
      phase09_model_registry_sha256 = "a3d21b90568aec86f44cefe2964555cb5565e1ab4e205489f42009a3ec489255",
      phase09_checksum_self_sha256 = "4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309",
      phase09_parent_graph_sha256 = "19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584"
    )
  )
}
