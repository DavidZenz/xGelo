# One fixed-root facade for the CL CLI, targets and persisted outcome consumer.
# It grants no source/model/policy authority and accepts no caller-selected roots.
.ucl_runtime_bound_root <- local({
  script <- "ucl_production_runtime.R"
  candidates <- character()
  for (frame in rev(sys.frames())) {
    for (field in c("ofile", "file")) {
      if (!base::exists(field, envir = frame, inherits = FALSE)) next
      value <- get(field, envir = frame, inherits = FALSE)
      if (!is.character(value) || length(value) != 1L || is.na(value) ||
          !identical(basename(value), script)) next
      if (!grepl("^/", value) && base::exists("owd", envir = frame, inherits = FALSE))
        candidates <- c(candidates, file.path(get("owd", envir = frame, inherits = FALSE), value))
      candidates <- c(candidates, value)
    }
  }
  candidates <- candidates[file.exists(candidates)]
  if (!length(candidates)) stop("Cannot bind the fixed CL runtime module path", call. = FALSE)
  path <- normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
  root <- normalizePath(file.path(dirname(path), "../.."), winslash = "/", mustWork = TRUE)
  if (!identical(path, file.path(root, "R/competition", script)) ||
      !file.exists(file.path(root, "scripts/build_uefa_champions_league_outcomes.R")))
    stop("Invalid fixed CL runtime module location", call. = FALSE)
  root
})
.ucl_runtime_cache <- new.env(parent = emptyenv())
.ucl_runtime_dependencies <- function() {
  cli <- "scripts/build_uefa_champions_league_outcomes.R"
  lines <- readLines(file.path(.ucl_runtime_bound_root, cli), warn = FALSE)
  selected <- grepl('^phase20_ucl_source\\("[A-Za-z0-9_./]+"\\)$', lines)
  modules <- sub('^phase20_ucl_source\\("([A-Za-z0-9_./]+)"\\)$', '\\1', lines[selected])
  required <- c("R/club/production_runner.R", "R/club/live_predictions.R",
    "R/competition/ucl_joint_score_view.R", "R/competition/ucl_live_bridge.R",
    "R/competition/ucl_live_outcomes.R", "R/competition/ucl_future_matchups.R")
  if (!all(required %in% modules) || anyDuplicated(modules) ||
      any(grepl("(^|/)\\.\\.(/|$)", modules)))
    stop("Fixed CL CLI dependency inventory is incomplete", call. = FALSE)
  c(cli, modules, "R/competition/ucl_live_outcome_reader.R",
    "R/competition/ucl_production_runtime.R")
}
.ucl_runtime_binding <- function() {
  paths <- .ucl_runtime_dependencies()
  absolute <- file.path(.ucl_runtime_bound_root, paths)
  if (any(!file.exists(absolute) | dir.exists(absolute)) || any(nzchar(Sys.readlink(absolute))))
    stop("Fixed CL runtime dependency is missing or unsafe", call. = FALSE)
  stats::setNames(vapply(absolute, function(path)
    digest::digest(file = path, algo = "sha256", serialize = FALSE), character(1)), paths)
}
.ucl_runtime_in_project <- function(callback) {
  previous <- getwd()
  on.exit(setwd(previous), add = TRUE)
  setwd(.ucl_runtime_bound_root)
  callback()
}
.ucl_runtime_load <- function() {
  binding <- .ucl_runtime_binding()
  if (base::exists("runtime", envir = .ucl_runtime_cache, inherits = FALSE) &&
      identical(.ucl_runtime_cache$binding, binding)) return(.ucl_runtime_cache$runtime)
  loaded <- .ucl_runtime_in_project(function() {
    namespace <- new.env(parent = baseenv())
    sys.source(file.path(.ucl_runtime_bound_root,
      "scripts/build_uefa_champions_league_outcomes.R"), envir = namespace)
    runtime <- namespace$phase20_ucl_runtime
    if (!is.environment(runtime) || !identical(parent.env(runtime), baseenv()) ||
        !identical(namespace$phase20_ucl_project_root, .ucl_runtime_bound_root) ||
        !identical(runtime$.phase19_club_project_root, .ucl_runtime_bound_root))
      stop("Fixed CL runtime namespace is not isolated or root-bound", call. = FALSE)
    # The direct CLI's corresponding imports are also part of the independently
    # sealed normalization repair. These imports support the shared facade only.
    runtime$tail <- utils::tail
    runtime$capture.output <- utils::capture.output
    sys.source(file.path(.ucl_runtime_bound_root,
      "R/competition/ucl_live_outcome_reader.R"), envir = runtime)
    required <- c("ucl20_build_outcomes", "ucl20_build_live_outcomes",
      "ucl_future_production_context", "ucl_read_live_outcomes",
      "ucl_validate_live_outcomes_read_result")
    if (!all(vapply(required, function(name)
        base::exists(name, envir = runtime, inherits = FALSE) &&
          is.function(get(name, envir = runtime, inherits = FALSE)), logical(1))))
      stop("Fixed CL live runtime is incomplete", call. = FALSE)
    namespace
  })
  if (!identical(binding, .ucl_runtime_binding()))
    stop("CL runtime dependencies changed during loading", call. = FALSE)
  .ucl_runtime_cache$runtime <- loaded
  .ucl_runtime_cache$binding <- binding
  loaded
}

ucl_build_production_outcomes <- function(simulations = 10000L, seed = 20260921L,
    information_cutoff_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    write = FALSE, replay_check = FALSE) {
  if (!is.numeric(simulations) || length(simulations) != 1L || !is.finite(simulations) ||
      simulations != floor(simulations) || simulations < 1 || simulations > 100000 ||
      !is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      seed != floor(seed) || seed < 0 || seed > .Machine$integer.max ||
      !is.character(information_cutoff_utc) || length(information_cutoff_utc) != 1L ||
      is.na(information_cutoff_utc) ||
      !is.logical(write) || length(write) != 1L || is.na(write) ||
      !is.logical(replay_check) || length(replay_check) != 1L || is.na(replay_check) ||
      (write && replay_check)) stop("Invalid CL production run controls", call. = FALSE)
  namespace <- .ucl_runtime_load()
  arguments <- c(paste0("--simulations=", simulations), paste0("--seed=", seed),
    paste0("--information-cutoff-utc=", information_cutoff_utc),
    if (write) "--write" else if (replay_check) "--replay-check" else "--dry-run")
  options <- namespace$phase20_ucl_parse_args(arguments)
  .ucl_runtime_in_project(function() namespace$phase20_ucl_build_fixed(options))
}

ucl_read_production_outcomes <- function(now_utc = NULL) {
  tryCatch({
    namespace <- .ucl_runtime_load()
    .ucl_runtime_in_project(function() namespace$phase20_ucl_runtime$ucl_read_live_outcomes(now_utc))
  }, error = function(error) list(schema_version = "ucl-live-outcome-read-result-v1",
    status = "blocked", reason_code = "fixed_runtime_unavailable", message = conditionMessage(error),
    production_eligible = FALSE, fixture_authority = FALSE, authority_mode = "production", tables = list()))
}

ucl_validate_production_outcome_read_result <- function(result, now_utc = NULL) {
  tryCatch({
    namespace <- .ucl_runtime_load()
    .ucl_runtime_in_project(function()
      namespace$phase20_ucl_runtime$ucl_validate_live_outcomes_read_result(result, now_utc))
  }, error = function(error) FALSE)
}
