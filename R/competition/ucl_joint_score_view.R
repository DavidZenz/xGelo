# Packed, endian-fixed numeric payload inside the canonical-v2 envelope.
# Sorting binds every score cell while avoiding per-cell R hash dispatch.
.ucl_joint_grid_hash <- function(grid, schema_tag) {
  grid <- grid[order(grid$home_goals, grid$away_goals), , drop = FALSE]
  payload <- list(
    rows = as.character(nrow(grid)),
    home_integer32_be = phase18_v2_hex(writeBin(as.integer(grid$home_goals), raw(), size = 4L, endian = "big")),
    away_integer32_be = phase18_v2_hex(writeBin(as.integer(grid$away_goals), raw(), size = 4L, endian = "big")),
    probability_float64_be = phase18_v2_hex(writeBin(as.double(grid$probability), raw(), size = 8L, endian = "big")))
  phase18_hash_sequence_v2(payload, paste0(schema_tag, ":packed-cells-v1"), names = names(payload), types = rep("character", length(payload)))
}

# Tournament-only joint view. The released NB grid and its non-1X2 markets
# remain unchanged. Sampling this grid is exactly: draw the approved 1X2 outcome,
# then draw a score from the released NB grid conditional on that outcome.
ucl_tournament_score_view <- function(raw_grid, primary_1x2, fixture_id, model_release_id,
    primary_probability_view, source_score_distribution_sha256, support_max = 40L) {
  if (!is.data.frame(raw_grid) || !all(c("home_goals", "away_goals", "probability") %in% names(raw_grid)))
    stop("Tournament joint view requires the retained raw score grid", call. = FALSE)
  support <- as.integer(support_max)
  if (length(support) != 1L || is.na(support) || support < 1L || support > 40L)
    stop("Tournament joint score support is invalid", call. = FALSE)
  home <- as.numeric(raw_grid$home_goals); away <- as.numeric(raw_grid$away_goals); raw <- as.numeric(raw_grid$probability)
  if (any(!is.finite(c(home, away, raw))) || any(home != floor(home) | away != floor(away)) ||
      any(home < 0 | away < 0 | home > support | away > support) || any(raw < 0) ||
      anyDuplicated(paste(home, away, sep = ":")) || nrow(raw_grid) != (support + 1L)^2 || abs(sum(raw) - 1) > 1e-10)
    stop("Tournament joint view requires a complete normalized score rectangle", call. = FALSE)
  primary <- as.numeric(primary_1x2)
  if (length(primary) != 3L || any(!is.finite(primary)) || any(primary < 0 | primary > 1) || abs(sum(primary) - 1) > 1e-10)
    stop("Tournament joint view requires approved normalized 1X2 probabilities", call. = FALSE)
  for (value in list(fixture_id, model_release_id, primary_probability_view, source_score_distribution_sha256))
    if (length(value) != 1L || is.na(value) || !nzchar(as.character(value))) stop("Tournament joint view lineage is incomplete", call. = FALSE)
  if (!primary_probability_view %in% c("raw_1x2", "calibrated_1x2") ||
      !grepl("^[0-9a-f]{64}$", source_score_distribution_sha256)) stop("Tournament joint view lineage is invalid", call. = FALSE)
  outcome <- ifelse(home > away, 1L, ifelse(home == away, 2L, 3L))
  raw_mass <- vapply(1:3, function(k) sum(raw[outcome == k]), numeric(1))
  if (any(primary > 0 & raw_mass <= 0)) stop("Approved outcome has no raw conditional score support", call. = FALSE)
  probability <- numeric(length(raw))
  conditional_error <- numeric(3L)
  for (k in 1:3) {
    index <- which(outcome == k)
    if (raw_mass[[k]] > 0) probability[index] <- primary[[k]] * raw[index] / raw_mass[[k]]
    if (primary[[k]] > 0) conditional_error[[k]] <- max(abs(probability[index] / primary[[k]] - raw[index] / raw_mass[[k]]))
  }
  grid <- data.frame(home_goals = as.integer(home), away_goals = as.integer(away), probability = probability)
  grid <- grid[order(grid$home_goals, grid$away_goals), , drop = FALSE]
  rownames(grid) <- NULL
  actual <- vapply(1:3, function(k) sum(probability[outcome == k]), numeric(1))
  if (max(abs(actual - primary)) > 1e-12 || max(conditional_error) > 1e-12 || abs(sum(probability) - 1) > 1e-12)
    stop("Tournament joint-view 1X2/conditional-score QA failed", call. = FALSE)
  source <- data.frame(home_goals = as.integer(home), away_goals = as.integer(away), probability = raw)
  provenance <- data.frame(
    view_version = "ucl-outcome-conditional-nb-v1", grid_encoding = "phase18-envelope-packed-cells-v1", fixture_id = as.character(fixture_id),
    model_release_id = as.character(model_release_id), primary_probability_view = as.character(primary_probability_view),
    source_score_distribution_sha256 = as.character(source_score_distribution_sha256),
    raw_grid_canonical_sha256 = .ucl_joint_grid_hash(source, "ucl-raw-nb-grid-parent-v1"),
    joint_grid_sha256 = .ucl_joint_grid_hash(grid, "ucl-tournament-joint-grid-v1"),
    primary_home = primary[[1L]], primary_draw = primary[[2L]], primary_away = primary[[3L]],
    raw_home = raw_mass[[1L]], raw_draw = raw_mass[[2L]], raw_away = raw_mass[[3L]],
    max_1x2_error = max(abs(actual - primary)), max_conditional_error = max(conditional_error), stringsAsFactors = FALSE)
  provenance$view_sha256 <- phase18_hash_row_v2(provenance, schema_tag = "ucl-tournament-joint-view-v1")
  list(grid = grid, provenance = provenance, scope = "tournament_sampling_only",
    released_grid_unchanged = TRUE, non_1x2_market_authority = "released_raw_nb_view_only")
}
