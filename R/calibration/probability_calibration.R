#' Phase 12 frozen one-parameter temperature calibration for derived 1X2.

if (!exists("phase12_calibration_source_if_missing", mode = "function")) {
  calibration_root <- if (file.exists("R/calibration/inner_oof.R")) "." else file.path("..", "..")
  source(file.path(calibration_root, "R/calibration/inner_oof.R"), local = .GlobalEnv)
}

phase12_calibration_source_if_missing(
  "R/evaluation/proper_scores.R", c("validate_probability_vector")
)

phase12_calibration_recipe <- function(
    recipe_path = "data/benchmark/phase12/calibration_recipe.json",
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv"
) {
  freeze <- phase12_inner_oof_freeze(freeze_manifest)
  recipe_path <- phase12_calibration_resolve_path(recipe_path)
  if (!file.exists(recipe_path)) stop("Phase 12 calibration recipe is missing", call. = FALSE)
  recipe <- jsonlite::fromJSON(recipe_path, simplifyVector = TRUE, simplifyDataFrame = FALSE)
  recipe_sha <- phase12_file_sha256(recipe_path)
  expected_sha <- as.character(freeze$recipe_sha256[[1L]])
  if (!identical(tolower(recipe_sha), tolower(expected_sha))) stop("Phase 12 calibration recipe checksum drifted", call. = FALSE)
  if (!identical(phase12_json_bytes(recipe), phase12_json_bytes(phase12_recipe_spec()))) stop("Phase 12 calibration recipe content drifted", call. = FALSE)
  recipe$recipe_sha256 <- recipe_sha
  recipe$freeze_id <- as.character(freeze$freeze_id[[1L]])
  recipe$validated_freeze <- TRUE
  recipe
}

phase12_calibration_recipe_payload <- function(recipe) {
  if (!is.list(recipe)) stop("Phase 12 recipe must be a list", call. = FALSE)
  payload <- recipe
  payload[c("recipe_sha256", "freeze_id", "validated_freeze")] <- NULL
  payload
}

phase12_temperature_transform <- function(probabilities, temperature, epsilon = 1e-15) {
  probabilities <- validate_probability_vector(probabilities, name = "raw 1X2 probabilities")
  logits <- log(pmax(probabilities, epsilon)) / as.numeric(temperature)
  logits <- logits - max(logits)
  values <- exp(logits)
  values <- values / sum(values)
  names(values) <- names(probabilities)
  validate_probability_vector(values, name = "calibrated 1X2 probabilities")
}

phase12_calibration_source_hash <- function(inner_oof) {
  hashes <- sort(unique(as.character(inner_oof$source_prediction_sha256)), method = "radix")
  if (!length(hashes)) return(digest::digest("", algo = "sha256", serialize = FALSE))
  digest::digest(paste(hashes, collapse = "|"), algo = "sha256", serialize = FALSE)
}

phase12_calibration_support <- function(inner_oof) {
  counts <- table(factor(as.character(inner_oof$observed_class), levels = c("home", "draw", "away")))
  c(home = as.integer(counts[["home"]]), draw = as.integer(counts[["draw"]]), away = as.integer(counts[["away"]]))
}

#' Build the durable provenance row for a Phase 12 calibrator.
#' @export
phase12_calibration_manifest_row <- function(calibrator) {
  required <- c("candidate_id", "track_id", "outer_edition_id", "inner_edition_ids", "row_count", "class_count_home", "class_count_draw", "class_count_away", "recipe_sha256", "seed", "source_prediction_sha256", "max_evidence_date", "fit_status", "fallback_reason")
  missing <- setdiff(required, names(calibrator))
  if (length(missing)) stop("Phase 12 calibrator provenance is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  data.frame(
    candidate_id = as.character(calibrator$candidate_id), track_id = as.character(calibrator$track_id),
    outer_edition_id = as.character(calibrator$outer_edition_id),
    inner_edition_ids = paste(sort(as.character(calibrator$inner_edition_ids), method = "radix"), collapse = "|"),
    row_count = as.integer(calibrator$row_count), class_count_home = as.integer(calibrator$class_count_home),
    class_count_draw = as.integer(calibrator$class_count_draw), class_count_away = as.integer(calibrator$class_count_away),
    recipe_sha256 = as.character(calibrator$recipe_sha256), seed = as.integer(calibrator$seed),
    source_prediction_sha256 = as.character(calibrator$source_prediction_sha256),
    max_evidence_date = as.character(calibrator$max_evidence_date), fit_status = as.character(calibrator$fit_status),
    fallback_reason = as.character(calibrator$fallback_reason), temperature = as.numeric(calibrator$temperature),
    optimizer_method = as.character(calibrator$optimizer_method), optimizer_convergence = as.integer(calibrator$optimizer_convergence),
    probability_view = as.character(calibrator$probability_view), score_support = as.integer(calibrator$score_support),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

#' Fit one candidate/track calibrator from strictly prior inner OOF rows.
#' @export
fit_phase12_1x2_calibrator <- function(
    inner_oof, candidate_id, track_id, outer_edition_id,
    recipe = NULL, freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv", boundaries = NULL
) {
  # The freeze and recipe gate intentionally precede every data operation that
  # could reach stats::optim.  This keeps a stale recipe from becoming a fit.
  frozen <- phase12_inner_oof_freeze(freeze_manifest)
  frozen_recipe <- phase12_calibration_recipe(freeze_manifest = freeze_manifest)
  if (is.null(recipe)) recipe <- frozen_recipe
  if (!isTRUE(recipe$validated_freeze) || !identical(tolower(as.character(recipe$recipe_sha256)), tolower(as.character(frozen$recipe_sha256[[1L]])))) {
    stop("Phase 12 calibrator requires the validated frozen recipe checksum", call. = FALSE)
  }
  validate_phase12_inner_oof_chronology(inner_oof, candidate_id, track_id, outer_edition_id, boundaries)
  payload <- phase12_calibration_recipe_payload(recipe)
  required_recipe <- c("epsilon", "initial_temperature", "minimum_class_count", "minimum_history_rows", "optimizer", "score_support", "seed", "temperature_bounds")
  if (length(setdiff(required_recipe, names(payload))) || !identical(as.character(payload$optimizer), "stats::optim-L-BFGS-B")) stop("Phase 12 calibration recipe is incomplete", call. = FALSE)
  support <- phase12_calibration_support(inner_oof)
  fallback <- function(reason) {
    object <- list(
      schema_version = "phase12-calibrator-v1", candidate_id = as.character(candidate_id), track_id = as.character(track_id),
      outer_edition_id = as.character(outer_edition_id), inner_edition_ids = sort(unique(as.character(inner_oof$inner_edition_id)), method = "radix"),
      row_count = nrow(inner_oof), class_count_home = support[["home"]], class_count_draw = support[["draw"]], class_count_away = support[["away"]],
      recipe_id = as.character(payload$recipe_id), recipe_sha256 = as.character(recipe$recipe_sha256), seed = as.integer(payload$seed),
      source_prediction_sha256 = phase12_calibration_source_hash(inner_oof), max_evidence_date = if (nrow(inner_oof)) format(max(as.Date(inner_oof$max_evidence_date)), "%Y-%m-%d") else "",
      fit_status = "raw_fallback", fallback_reason = as.character(reason), temperature = as.numeric(payload$initial_temperature),
      initial_temperature = as.numeric(payload$initial_temperature), temperature_bounds = as.numeric(payload$temperature_bounds),
      optimizer_method = as.character(payload$optimizer), optimizer_convergence = NA_integer_, optimizer_value = NA_real_,
      probability_view = "derived_1x2", score_support = as.integer(payload$score_support), distribution_unchanged = TRUE,
      freeze_id = as.character(frozen$freeze_id[[1L]])
    )
    object$manifest_row <- phase12_calibration_manifest_row(object)
    class(object) <- c("phase12_1x2_calibrator", "list")
    object
  }
  if (!nrow(inner_oof) || nrow(inner_oof) < as.integer(payload$minimum_history_rows) || any(support < as.integer(payload$minimum_class_count))) {
    return(fallback("insufficient_history_or_class_support"))
  }
  raw <- as.matrix(inner_oof[, c("p_home_raw", "p_draw_raw", "p_away_raw")])
  observed <- match(as.character(inner_oof$observed_class), c("home", "draw", "away"))
  epsilon <- as.numeric(payload$epsilon)
  objective <- function(parameter) {
    calibrated <- t(apply(raw, 1L, function(probability) {
      phase12_temperature_transform(setNames(probability, c("home", "draw", "away")), parameter[[1L]], epsilon)
    }))
    value <- -sum(log(pmax(calibrated[cbind(seq_len(nrow(calibrated)), observed)], epsilon)))
    if (!is.finite(value)) Inf else value
  }
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
  had_seed <- !is.null(old_seed)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(payload$seed), kind = "L'Ecuyer-CMRG")
  optimized <- tryCatch(
    stats::optim(par = as.numeric(payload$initial_temperature), fn = objective, method = "L-BFGS-B", lower = as.numeric(payload$temperature_bounds[[1L]]), upper = as.numeric(payload$temperature_bounds[[2L]])),
    error = function(error) error
  )
  if (inherits(optimized, "error") || length(optimized$par) != 1L || !is.finite(optimized$par[[1L]]) ||
      optimized$par[[1L]] < payload$temperature_bounds[[1L]] || optimized$par[[1L]] > payload$temperature_bounds[[2L]] ||
      !identical(as.integer(optimized$convergence), 0L) || !is.finite(optimized$value)) {
    stop("Phase 12 calibrator optimizer returned invalid state", call. = FALSE)
  }
  object <- list(
    schema_version = "phase12-calibrator-v1", candidate_id = as.character(candidate_id), track_id = as.character(track_id),
    outer_edition_id = as.character(outer_edition_id), inner_edition_ids = sort(unique(as.character(inner_oof$inner_edition_id)), method = "radix"),
    row_count = nrow(inner_oof), class_count_home = support[["home"]], class_count_draw = support[["draw"]], class_count_away = support[["away"]],
    recipe_id = as.character(payload$recipe_id), recipe_sha256 = as.character(recipe$recipe_sha256), seed = as.integer(payload$seed),
    source_prediction_sha256 = phase12_calibration_source_hash(inner_oof), max_evidence_date = format(max(as.Date(inner_oof$max_evidence_date)), "%Y-%m-%d"),
    fit_status = "fitted", fallback_reason = "", temperature = as.numeric(optimized$par[[1L]]),
    initial_temperature = as.numeric(payload$initial_temperature), temperature_bounds = as.numeric(payload$temperature_bounds),
    optimizer_method = as.character(payload$optimizer), optimizer_convergence = as.integer(optimized$convergence), optimizer_value = as.numeric(optimized$value),
    probability_view = "derived_1x2", score_support = as.integer(payload$score_support), distribution_unchanged = TRUE,
    freeze_id = as.character(frozen$freeze_id[[1L]])
  )
  object$manifest_row <- phase12_calibration_manifest_row(object)
  class(object) <- c("phase12_1x2_calibrator", "list")
  validate_phase12_calibrator(object, freeze_manifest = freeze_manifest, recipe = recipe)
  object
}

#' Validate one durable Phase 12 calibrator and its frozen provenance.
#' @export
validate_phase12_calibrator <- function(
    calibrator, freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv", recipe = NULL,
    candidate_id = NULL, track_id = NULL, outer_edition_id = NULL
) {
  if (!is.list(calibrator)) stop("Phase 12 calibrator must be a list", call. = FALSE)
  frozen <- phase12_inner_oof_freeze(freeze_manifest)
  frozen_recipe <- phase12_calibration_recipe(freeze_manifest = freeze_manifest)
  if (is.null(recipe)) recipe <- frozen_recipe
  required <- c("schema_version", "candidate_id", "track_id", "outer_edition_id", "inner_edition_ids", "row_count", "class_count_home", "class_count_draw", "class_count_away", "recipe_sha256", "seed", "source_prediction_sha256", "max_evidence_date", "fit_status", "fallback_reason", "temperature", "temperature_bounds", "optimizer_method", "optimizer_convergence", "probability_view", "score_support", "distribution_unchanged", "freeze_id")
  missing <- setdiff(required, names(calibrator))
  if (length(missing)) stop("Phase 12 calibrator missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!is.null(candidate_id) && !identical(as.character(calibrator$candidate_id), as.character(candidate_id))) stop("Phase 12 calibrator candidate identity mismatch", call. = FALSE)
  if (!is.null(track_id) && !identical(as.character(calibrator$track_id), as.character(track_id))) stop("Phase 12 calibrator track identity mismatch", call. = FALSE)
  if (!is.null(outer_edition_id) && !identical(as.character(calibrator$outer_edition_id), as.character(outer_edition_id))) stop("Phase 12 calibrator outer edition mismatch", call. = FALSE)
  if (tolower(as.character(calibrator$outer_edition_id)) == "wc2026" || any(grepl("^wc2026", tolower(as.character(calibrator$inner_edition_ids))))) stop("Phase 12 calibrator contains holdout identity", call. = FALSE)
  if (!identical(tolower(as.character(calibrator$recipe_sha256)), tolower(as.character(frozen$recipe_sha256[[1L]]))) || !identical(tolower(as.character(recipe$recipe_sha256)), tolower(as.character(frozen$recipe_sha256[[1L]])))) stop("Phase 12 calibrator recipe checksum mismatch", call. = FALSE)
  if (!identical(as.character(calibrator$freeze_id), as.character(frozen$freeze_id[[1L]]))) stop("Phase 12 calibrator freeze identity mismatch", call. = FALSE)
  if (!identical(as.character(calibrator$optimizer_method), "stats::optim-L-BFGS-B") || !identical(as.integer(calibrator$score_support), 40L) || !isTRUE(calibrator$distribution_unchanged) || !identical(as.character(calibrator$probability_view), "derived_1x2")) stop("Phase 12 calibrator frozen contract drifted", call. = FALSE)
  if (!is.finite(as.numeric(calibrator$temperature)) || length(calibrator$temperature_bounds) != 2L || any(!is.finite(as.numeric(calibrator$temperature_bounds))) || calibrator$temperature < calibrator$temperature_bounds[[1L]] || calibrator$temperature > calibrator$temperature_bounds[[2L]]) stop("Phase 12 calibrator temperature state is invalid", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(calibrator$source_prediction_sha256))) stop("Phase 12 calibrator source prediction hash is invalid", call. = FALSE)
  status <- as.character(calibrator$fit_status)
  if (identical(status, "fitted")) {
    if (as.integer(calibrator$optimizer_convergence) != 0L || !is.finite(as.numeric(calibrator$optimizer_value)) || as.numeric(calibrator$temperature) == 0) stop("Phase 12 fitted calibrator optimizer state is invalid", call. = FALSE)
    if (as.integer(calibrator$row_count) < 60L || any(c(calibrator$class_count_home, calibrator$class_count_draw, calibrator$class_count_away) < 10L)) stop("Phase 12 fitted calibrator support is insufficient", call. = FALSE)
    if (nzchar(as.character(calibrator$fallback_reason))) stop("Phase 12 fitted calibrator cannot carry a fallback reason", call. = FALSE)
  } else if (identical(status, "raw_fallback")) {
    if (!nzchar(as.character(calibrator$fallback_reason))) stop("Phase 12 raw fallback requires a reason", call. = FALSE)
  } else stop("Phase 12 calibrator fit status is invalid", call. = FALSE)
  invisible(TRUE)
}

phase12_apply_vector <- function(calibrator, probabilities) {
  if (is.null(names(probabilities)) || !setequal(names(probabilities), c("home", "draw", "away"))) stop("Phase 12 1X2 input must be named home, draw, and away", call. = FALSE)
  probabilities <- validate_probability_vector(probabilities[c("home", "draw", "away")], name = "raw 1X2 probabilities")
  if (identical(as.character(calibrator$fit_status), "raw_fallback")) return(setNames(probabilities, c("home", "draw", "away")))
  phase12_temperature_transform(setNames(probabilities, c("home", "draw", "away")), calibrator$temperature, 1e-15)
}

#' Apply calibration to a named 1X2 vector or a prediction view.
#' @export
apply_phase12_1x2_calibrator <- function(calibrator, probabilities) {
  validate_phase12_calibrator(calibrator)
  if (is.numeric(probabilities) && is.null(dim(probabilities))) return(phase12_apply_vector(calibrator, probabilities))
  if (!is.data.frame(probabilities)) stop("Phase 12 calibration input must be a named vector or data frame", call. = FALSE)
  raw <- if (all(c("p_home_raw", "p_draw_raw", "p_away_raw") %in% names(probabilities))) c("p_home_raw", "p_draw_raw", "p_away_raw") else c("p_home", "p_draw", "p_away")
  if (!all(raw %in% names(probabilities))) stop("Phase 12 prediction view lacks raw 1X2 columns", call. = FALSE)
  result <- probabilities
  calibrated <- t(vapply(seq_len(nrow(result)), function(i) unname(phase12_apply_vector(calibrator, setNames(as.numeric(result[i, raw]), c("home", "draw", "away")))), numeric(3)))
  result$p_home_calibrated <- calibrated[, 1L]; result$p_draw_calibrated <- calibrated[, 2L]; result$p_away_calibrated <- calibrated[, 3L]
  result$primary_probability_view <- if (identical(as.character(calibrator$fit_status), "fitted")) "calibrated" else "raw"
  result
}

#' Compare raw and calibrated probabilities without changing scoreline views.
#' @export
compare_phase12_raw_calibrated <- function(raw_predictions, calibrated_predictions, distributions = NULL, fixtures = NULL, expected_fixture_ids = NULL) {
  if (!is.data.frame(raw_predictions) || !is.data.frame(calibrated_predictions)) stop("Phase 12 raw/calibrated comparison requires data frames", call. = FALSE)
  if (!"fixture_id" %in% names(raw_predictions) || !"fixture_id" %in% names(calibrated_predictions) || !setequal(raw_predictions$fixture_id, calibrated_predictions$fixture_id)) stop("Phase 12 raw and calibrated views require identical fixture IDs", call. = FALSE)
  result <- data.frame(fixture_id = as.character(raw_predictions$fixture_id), stringsAsFactors = FALSE)
  if (!is.null(distributions) && !is.null(fixtures)) {
    phase12_calibration_source_if_missing("R/evaluation/benchmark_scores.R", c("score_benchmark_fixtures"))
    if (is.null(expected_fixture_ids)) expected_fixture_ids <- unique(as.character(fixtures$fixture_id))
    result$raw_scores <- list(score_benchmark_fixtures(raw_predictions, fixtures, distributions, expected_fixture_ids))
    result$calibrated_scores <- list(score_benchmark_fixtures(calibrated_predictions, fixtures, distributions, expected_fixture_ids))
  }
  result
}

#' Select the primary development probability view after explicit veto checks.
#' @export
select_phase12_primary_probability_view <- function(calibration_improves = FALSE, vetoes = character()) {
  if (isTRUE(calibration_improves) && !length(vetoes)) "calibrated" else "raw"
}

phase12_calibration_output_paths <- function(output_dir = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration") {
  c(inner_oof_predictions = file.path(output_dir, "inner_oof_predictions.csv"), calibrators = file.path(output_dir, "calibrators.rds"))
}

#' Persist and read back the calibration CSV/RDS pair.
#' @export
write_phase12_calibration_artifacts <- function(inner_oof, calibrators, output_dir = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration", freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv") {
  freeze <- phase12_inner_oof_freeze(freeze_manifest)
  paths <- phase12_calibration_output_paths(output_dir)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  inner_oof <- inner_oof[order(inner_oof$candidate_id, inner_oof$track_id, inner_oof$outer_edition_id, inner_oof$inner_edition_id, inner_oof$fixture_id, method = "radix"), , drop = FALSE]
  persisted_inner_oof <- inner_oof
  for (column in intersect(c("evidence_cutoff_exclusive", "max_evidence_date"), names(persisted_inner_oof))) {
    persisted_inner_oof[[column]] <- format(as.Date(persisted_inner_oof[[column]]), "%Y-%m-%d")
  }
  utils::write.csv(persisted_inner_oof, paths[["inner_oof_predictions"]], row.names = FALSE, na = "", quote = TRUE)
  if (!is.list(calibrators)) stop("Phase 12 calibrators must be a list", call. = FALSE)
  validated <- lapply(calibrators, function(calibrator) { validate_phase12_calibrator(calibrator, freeze_manifest = freeze_manifest); calibrator })
  manifest <- do.call(rbind, lapply(validated, phase12_calibration_manifest_row))
  payload <- list(schema_version = "phase12-calibrators-v1", freeze_id = as.character(freeze$freeze_id[[1L]]), freeze_self_sha256 = as.character(freeze$freeze_self_sha256[[1L]]), recipe_sha256 = as.character(freeze$recipe_sha256[[1L]]), inner_oof_file_sha256 = phase12_file_sha256(paths[["inner_oof_predictions"]]), inner_oof_row_count = nrow(inner_oof), manifest = manifest, calibrators = validated)
  saveRDS(payload, paths[["calibrators"]], version = 3L, compress = FALSE)
  validate_phase12_calibration_artifacts(paths[["inner_oof_predictions"]], paths[["calibrators"]], freeze_manifest)
  unname(paths)
}

#' Validate durable calibration outputs from the persisted bytes.
#' @export
validate_phase12_calibration_artifacts <- function(inner_oof_path, calibrators_path, freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv") {
  freeze <- phase12_inner_oof_freeze(freeze_manifest)
  if (!file.exists(inner_oof_path) || !file.exists(calibrators_path)) stop("Phase 12 calibration artifact is missing", call. = FALSE)
  inner_oof <- utils::read.csv(inner_oof_path, stringsAsFactors = FALSE, check.names = FALSE)
  inner_oof$evidence_cutoff_exclusive <- as.Date(inner_oof$evidence_cutoff_exclusive)
  inner_oof$max_evidence_date <- as.Date(inner_oof$max_evidence_date)
  payload <- readRDS(calibrators_path)
  if (!identical(as.character(payload$freeze_id), as.character(freeze$freeze_id[[1L]])) || !identical(tolower(as.character(payload$recipe_sha256)), tolower(as.character(freeze$recipe_sha256[[1L]]))) || !identical(as.character(payload$freeze_self_sha256), as.character(freeze$freeze_self_sha256[[1L]]))) stop("Phase 12 calibration artifact freeze identity drifted", call. = FALSE)
  if (!identical(as.character(payload$inner_oof_file_sha256), as.character(phase12_file_sha256(inner_oof_path))) || !identical(as.integer(payload$inner_oof_row_count), as.integer(nrow(inner_oof)))) stop("Phase 12 inner OOF persisted identity drifted", call. = FALSE)
  if (!is.list(payload$calibrators) || !nrow(payload$manifest) || nrow(payload$manifest) != length(payload$calibrators)) stop("Phase 12 calibrator artifact manifest is incomplete", call. = FALSE)
  invisible(lapply(payload$calibrators, function(calibrator) validate_phase12_calibrator(calibrator, freeze_manifest = freeze_manifest)))
  invisible(TRUE)
}
