#' Visualizations for the World Cup 2026 retrospective

retrospective_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "#4B5563"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}

save_retrospective_plot <- function(plot, path, width = 9, height = 5.5) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = 160, bg = "white")
  normalizePath(path, mustWork = TRUE)
}

#' Plot forecast evidence coverage
#' @export
plot_forecast_coverage <- function(coverage, output_path) {
  plot_data <- data.frame(
    sample = c("Strict verified", "Exploratory documented", "No eligible strict forecast"),
    fixtures = c(sum(coverage$strict), sum(coverage$exploratory), sum(!coverage$strict)),
    stringsAsFactors = FALSE
  )
  plot_data$sample <- factor(plot_data$sample, levels = rev(plot_data$sample))
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(fixtures, sample, fill = sample)) +
    ggplot2::geom_col(width = 0.66, show.legend = FALSE) +
    ggplot2::geom_text(ggplot2::aes(label = paste0(fixtures, " / 104")), hjust = -0.08, size = 3.6) +
    ggplot2::scale_fill_manual(values = c(
      "Strict verified" = "#166534", "Exploratory documented" = "#2563EB",
      "No eligible strict forecast" = "#B91C1C"
    )) +
    ggplot2::scale_x_continuous(limits = c(0, 112), expand = c(0, 0)) +
    ggplot2::labs(
      title = "Forecast evidence coverage", subtitle = "Eligible pre-kickoff fixtures by evidence tier",
      x = "Official fixtures", y = NULL
    ) + retrospective_theme()
  save_retrospective_plot(p, output_path)
}

#' Plot cumulative fixture RPS
#' @export
plot_cumulative_rps <- function(match_scores, fixtures, output_path) {
  data <- match_scores[
    match_scores$metric == "rps" & match_scores$view == "latest_valid" & is.finite(match_scores$value), ,
    drop = FALSE
  ]
  data$kickoff_utc <- fixtures$kickoff_utc[match(data$match_id, fixtures$match_id)]
  data <- data[order(data$sample, parse_utc_time(data$kickoff_utc), data$match_id), , drop = FALSE]
  data$cumulative_rps <- ave(data$value, data$sample, FUN = function(x) cumsum(x) / seq_along(x))
  data$fixture_number <- ave(data$value, data$sample, FUN = seq_along)
  p <- ggplot2::ggplot(data, ggplot2::aes(fixture_number, cumulative_rps, color = sample)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::scale_color_manual(values = c(strict = "#166534", exploratory = "#2563EB")) +
    ggplot2::labs(
      title = "Cumulative regulation-time RPS", subtitle = "Latest valid forecast within each evidence sample",
      x = "Scored fixture", y = "Cumulative mean RPS", color = "Sample"
    ) + retrospective_theme()
  save_retrospective_plot(p, output_path)
}

#' Plot one-vs-rest outcome calibration
#' @export
plot_outcome_calibration <- function(calibration_bins, output_path) {
  data <- calibration_bins[calibration_bins$view == "latest_valid", , drop = FALSE]
  p <- ggplot2::ggplot(data, ggplot2::aes(mean_probability, observed_frequency, color = class, shape = sparse)) +
    ggplot2::geom_abline(intercept = 0, slope = 1, color = "#9CA3AF", linetype = "dashed") +
    ggplot2::geom_point(ggplot2::aes(size = n), alpha = 0.9) +
    ggplot2::facet_wrap(~sample) +
    ggplot2::scale_color_manual(values = c(home = "#166534", draw = "#D97706", away = "#2563EB")) +
    ggplot2::scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1)) +
    ggplot2::coord_equal(xlim = c(0, 0.75), ylim = c(0, 0.75)) +
    ggplot2::labs(
      title = "Outcome calibration", subtitle = "Quantile bins; hollow markers identify sparse bins",
      x = "Mean forecast probability", y = "Observed frequency", color = "Outcome", shape = "Sparse", size = "Fixtures"
    ) + retrospective_theme()
  save_retrospective_plot(p, output_path, width = 9, height = 5.8)
}

#' Plot first-to-latest forecast changes
#' @export
plot_forecast_revision_changes <- function(match_scores, output_path) {
  data <- match_scores[match_scores$metric == "rps", c("sample", "view", "match_id", "value")]
  first <- data[data$view == "first_valid", c("sample", "match_id", "value")]
  latest <- data[data$view == "latest_valid", c("sample", "match_id", "value")]
  paired <- merge(first, latest, by = c("sample", "match_id"), suffixes = c("_first", "_latest"))
  paired$delta <- paired$value_latest - paired$value_first
  p <- ggplot2::ggplot(paired, ggplot2::aes(delta, fill = sample)) +
    ggplot2::geom_histogram(position = "identity", alpha = 0.55, bins = 24) +
    ggplot2::geom_vline(xintercept = 0, color = "#111827", linetype = "dashed") +
    ggplot2::facet_wrap(~sample, ncol = 1, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(strict = "#166534", exploratory = "#2563EB")) +
    ggplot2::labs(
      title = "Forecast revision changes", subtitle = "Latest minus first valid RPS; negative values improved",
      x = "Paired RPS change", y = "Fixtures", fill = "Sample"
    ) + retrospective_theme()
  save_retrospective_plot(p, output_path, width = 9, height = 6.5)
}

#' Plot available goal forecast diagnostics and coverage
#' @export
plot_goal_distribution_diagnostics <- function(aggregate_scores, output_path) {
  metrics <- c(
    over_2_5_brier = "Over 2.5 Brier", btts_brier = "BTTS Brier",
    home_xg_absolute_error = "Home xG MAE", away_xg_absolute_error = "Away xG MAE",
    joint_scoreline_log_loss = "Joint score log loss"
  )
  data <- aggregate_scores[
    aggregate_scores$view == "latest_valid" & aggregate_scores$cut_type == "overall" &
      aggregate_scores$metric %in% names(metrics), , drop = FALSE
  ]
  data$label <- unname(metrics[data$metric])
  data$label <- factor(data$label, levels = rev(unname(metrics)))
  data$coverage_label <- paste0(data$n_scored, "/", data$n_official)
  p <- ggplot2::ggplot(data, ggplot2::aes(estimate, label, color = sample)) +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = lower, xmax = upper), orientation = "y", width = 0.18, na.rm = TRUE
    ) +
    ggplot2::geom_point(size = 2.5, na.rm = TRUE) +
    ggplot2::geom_text(
      ggplot2::aes(x = 0, label = coverage_label), color = "#4B5563", hjust = -0.1,
      nudge_y = -0.2, size = 3
    ) +
    ggplot2::facet_wrap(~sample) +
    ggplot2::scale_color_manual(values = c(strict = "#166534", exploratory = "#2563EB")) +
    ggplot2::labs(
      title = "Goal forecast diagnostics", subtitle = "Intervals use available fixtures; labels show metric-specific coverage",
      x = "Mean score or error", y = NULL, color = "Sample"
    ) + retrospective_theme()
  save_retrospective_plot(p, output_path, width = 10, height = 6)
}

#' Generate all core retrospective figures
#' @export
generate_worldcup_retrospective_figures <- function(output_dir = "outputs/evaluation/wc2026") {
  figure_dir <- file.path(output_dir, "figures")
  coverage <- read.csv(file.path(output_dir, "forecast_coverage.csv"), stringsAsFactors = FALSE)
  fixtures <- read.csv(file.path(output_dir, "fixture_results.csv"), stringsAsFactors = FALSE)
  match_scores <- read.csv(file.path(output_dir, "match_scores.csv"), stringsAsFactors = FALSE)
  calibration <- read.csv(file.path(output_dir, "calibration_bins.csv"), stringsAsFactors = FALSE)
  aggregates <- read.csv(file.path(output_dir, "aggregate_scores.csv"), stringsAsFactors = FALSE)
  c(
    coverage = plot_forecast_coverage(coverage, file.path(figure_dir, "forecast_coverage.png")),
    cumulative_rps = plot_cumulative_rps(match_scores, fixtures, file.path(figure_dir, "cumulative_rps.png")),
    calibration = plot_outcome_calibration(calibration, file.path(figure_dir, "outcome_calibration.png")),
    revisions = plot_forecast_revision_changes(match_scores, file.path(figure_dir, "forecast_revisions.png")),
    goals = plot_goal_distribution_diagnostics(aggregates, file.path(figure_dir, "goal_diagnostics.png"))
  )
}
