#' xG/Form Feature Usage Audit
#'
#' Documents whether generated rolling xG/form features are available and
#' retained by fitted goal models.

#' Default rolling xG/form predictor columns
#'
#' @return Character vector of match-level xG/form diff predictors
#' @export
xg_form_predictors <- function() {
  c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "shots_ewma_diff", "form_index_diff")
}

#' Read a data frame or CSV path
#' @keywords internal
read_audit_table <- function(data, label, required = TRUE) {
  if (is.null(data)) {
    if (required) stop(paste(label, "is required"))
    return(NULL)
  }
  if (is.character(data) && length(data) == 1) {
    if (!file.exists(data)) {
      if (required) stop(paste(label, "not found:", data))
      return(NULL)
    }
    return(read.csv(data, stringsAsFactors = FALSE))
  }
  data
}

#' Extract retained predictors from a model object or RDS path
#' @keywords internal
model_retained_predictors <- function(model) {
  if (is.null(model)) return(character())
  if (is.character(model) && length(model) == 1) {
    if (!file.exists(model)) return(character())
    model <- readRDS(model)
  }
  predictors <- attr(model, "xgelo_predictors")
  if (!is.null(predictors)) return(as.character(predictors))
  coef_names <- names(stats::coef(model))
  setdiff(coef_names, "(Intercept)")
}

#' Compute team coverage of rolling form rows
#' @keywords internal
rolling_team_coverage <- function(teams, rolling_form) {
  if (length(teams) == 0) {
    return(list(total = 0L, covered = 0L, share = NA_real_))
  }
  canonicaliser <- get0("canonicalise_feature_team_name", mode = "function")
  if (is.function(canonicaliser)) {
    teams <- canonicaliser(teams)
    rolling_teams <- canonicaliser(rolling_form$team)
  } else {
    rolling_teams <- rolling_form$team
  }
  teams <- unique(teams[!is.na(teams) & nzchar(teams)])
  rolling_teams <- unique(rolling_teams[!is.na(rolling_teams) & nzchar(rolling_teams)])
  covered <- sum(teams %in% rolling_teams)
  list(total = length(teams), covered = covered, share = if (length(teams) > 0) covered / length(teams) else NA_real_)
}

#' Audit whether xG/form predictors are active in fitted goal models
#'
#' @param feature_table Training feature table or CSV path
#' @param home_model Home goal model object or RDS path
#' @param away_model Away goal model object or RDS path
#' @param rolling_form Optional rolling-form table or CSV path
#' @param forecast_features Optional forecast feature table or CSV path
#' @param predictors Candidate xG/form predictors
#' @param output_path Optional CSV output path
#' @return Audit data frame, one row per candidate predictor
#' @export
audit_xg_feature_usage <- function(
    feature_table = "data/processed/goal_training_features_hybrid.csv",
    home_model = "models/home_goal_model_hybrid.rds",
    away_model = "models/away_goal_model_hybrid.rds",
    rolling_form = "data/processed/rolling_form.csv",
    forecast_features = "data/processed/worldcup_2026_forecast_features_hybrid.csv",
    predictors = xg_form_predictors(),
    output_path = NULL
) {
  features <- read_audit_table(feature_table, "feature_table")
  rolling <- read_audit_table(rolling_form, "rolling_form", required = FALSE)
  forecast <- read_audit_table(forecast_features, "forecast_features", required = FALSE)

  home_predictors <- model_retained_predictors(home_model)
  away_predictors <- model_retained_predictors(away_model)

  training_teams <- unique(c(features$home_team, features$away_team))
  forecast_teams <- if (!is.null(forecast) && all(c("home_team", "away_team") %in% names(forecast))) {
    unique(c(forecast$home_team, forecast$away_team))
  } else {
    character()
  }
  if (is.null(rolling) || !"team" %in% names(rolling)) {
    rolling <- data.frame(team = character(), stringsAsFactors = FALSE)
  }
  training_coverage <- rolling_team_coverage(training_teams, rolling)
  forecast_coverage <- rolling_team_coverage(forecast_teams, rolling)

  rows <- lapply(predictors, function(predictor) {
    present <- predictor %in% names(features)
    values <- if (present) suppressWarnings(as.numeric(features[[predictor]])) else rep(NA_real_, nrow(features))
    sd_value <- if (present) stats::sd(values, na.rm = TRUE) else NA_real_
    nonzero_count <- if (present) sum(abs(values) > 1e-12, na.rm = TRUE) else 0L
    retained_home <- predictor %in% home_predictors
    retained_away <- predictor %in% away_predictors
    active <- present && is.finite(sd_value) && sd_value > 0 && (retained_home || retained_away)
    data.frame(
      predictor = predictor,
      present_in_feature_table = present,
      feature_table_rows = nrow(features),
      nonzero_count = nonzero_count,
      missing_count = if (present) sum(is.na(values)) else nrow(features),
      sd = sd_value,
      retained_home_model = retained_home,
      retained_away_model = retained_away,
      retained_any_model = retained_home || retained_away,
      active_in_model = active,
      rolling_form_rows = nrow(rolling),
      rolling_form_teams = length(unique(rolling$team)),
      training_teams = training_coverage$total,
      training_teams_with_rolling_form = training_coverage$covered,
      training_team_coverage = training_coverage$share,
      forecast_teams = forecast_coverage$total,
      forecast_teams_with_rolling_form = forecast_coverage$covered,
      forecast_team_coverage = forecast_coverage$share,
      audit_note = if (active) {
        "active"
      } else if (!present) {
        "missing feature column"
      } else if (!is.finite(sd_value) || sd_value == 0) {
        "zero variance in feature table"
      } else {
        "not retained by fitted models"
      },
      stringsAsFactors = FALSE
    )
  })
  audit <- do.call(rbind, rows)
  rownames(audit) <- NULL

  if (!is.null(output_path)) {
    if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
    write.csv(audit, output_path, row.names = FALSE)
  }
  audit
}
