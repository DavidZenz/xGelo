# Deterministic execution only: callers own validation, rules and iteration seeds.
simulation_execute <- function(count, iteration, workers = 1L, batch_size = 256L,
                               progress = NULL, compact = identity) {
  integer_control <- function(value, name) {
    number <- suppressWarnings(as.numeric(value))
    if (length(number) != 1L || !is.finite(number) || number < 1 ||
        number != floor(number) || number > .Machine$integer.max) {
      stop(name, " must be a positive integer", call. = FALSE)
    }
    as.integer(number)
  }
  count <- integer_control(count, "count")
  workers <- min(integer_control(workers, "workers"), count)
  batch_size <- integer_control(batch_size, "batch_size")
  if (!(is.null(progress) || is.function(progress) ||
        (is.logical(progress) && length(progress) == 1L && !is.na(progress)))) {
    stop("progress must be NULL, logical, or a callback", call. = FALSE)
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) saved_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    if (had_seed) assign(".Random.seed", saved_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  started <- proc.time()[["elapsed"]]
  emit <- function(done) {
    event <- list(completed = as.integer(done), total = count,
                  elapsed_seconds = unname(proc.time()[["elapsed"]] - started),
                  workers = if (.Platform$OS.type == "windows") 1L else workers)
    if (is.function(progress)) progress(event)
    else if (isTRUE(progress)) message(sprintf("simulation_progress completed=%d total=%d percent=%.2f elapsed_seconds=%.3f workers=%d",
      done, count, 100 * done / count, event$elapsed_seconds, event$workers))
  }
  emit(0L)
  output <- vector("list", count)
  run <- function(id) tryCatch(list(ok = TRUE, value = compact(iteration(id))),
    error = function(error) list(ok = FALSE, error = conditionMessage(error), iteration = id))
  # Fork once per worker: run-local prepared caches survive progress batches.
  # Only compact results cross the worker boundary. Progress files are numeric
  # counters, written atomically; they are neither authority nor checkpoints.
  if (workers > 1L && .Platform$OS.type != "windows") {
    directory <- tempfile("simulation-progress-")
    dir.create(directory)
    jobs <- list()
    on.exit({
      for (job in jobs) try(tools::pskill(job$pid), silent = TRUE)
      unlink(directory, recursive = TRUE)
    }, add = TRUE)
    chunks <- split(seq_len(count), rep(seq_len(workers), length.out = count))
    for (worker in seq_along(chunks)) {
      ids <- chunks[[worker]]
      path <- file.path(directory, as.character(worker))
      jobs[[as.character(worker)]] <- parallel::mcparallel({
        values <- vector("list", length(ids))
        for (index in seq_along(ids)) {
          values[[index]] <- run(ids[[index]])
          if (!isTRUE(values[[index]]$ok)) break
          if (index %% batch_size == 0L || index == length(ids)) {
            writeLines(as.character(index), paste0(path, ".next"))
            if (!file.rename(paste0(path, ".next"), path)) stop("Progress counter write failed")
          }
        }
        list(ids = ids, values = values)
      }, mc.set.seed = FALSE)
    }
    counters <- integer(length(chunks)); delivered <- 0L
    pending <- jobs
    while (length(pending)) {
      ready <- parallel::mccollect(pending, wait = FALSE)
      if (length(ready)) for (pid in names(ready)) {
        key <- names(pending)[vapply(pending, function(job) identical(as.character(job$pid), pid), logical(1))]
        result <- ready[[pid]]
        if (!is.list(result) || is.null(result$ids)) stop("Simulation worker failed or exited without results", call. = FALSE)
        for (index in seq_along(result$ids)) {
          value <- result$values[[index]]
          if (!is.list(value) || !isTRUE(value$ok)) {
            stop("Simulation iteration ", result$ids[[index]], " failed: ",
                 if (is.list(value)) value$error else "worker returned no result", call. = FALSE)
          }
          output[result$ids[[index]]] <- list(value$value)
        }
        counters[[as.integer(key)]] <- length(result$ids)
        pending[[key]] <- NULL
        jobs[[key]] <- NULL
      }
      for (key in names(pending)) {
        path <- file.path(directory, key)
        if (file.exists(path)) {
          value <- suppressWarnings(as.integer(readLines(path, warn = FALSE)))
          if (length(value) == 1L && !is.na(value)) counters[[as.integer(key)]] <- value
        }
      }
      done <- sum(counters)
      if (done != delivered) { emit(done); delivered <- done }
      if (length(pending)) Sys.sleep(0.05)
    }
    return(output)
  }
  # Serial fallback keeps the same iteration order and caller-owned seeds.
  for (first in seq.int(1L, count, by = batch_size)) {
    ids <- seq.int(first, as.integer(min(count, as.double(first) + batch_size - 1)))
    values <- lapply(ids, run)
    for (index in seq_along(ids)) {
      value <- values[[index]]
      if (!is.list(value) || !isTRUE(value$ok)) {
        detail <- if (is.list(value)) value$error else as.character(value)
        stop("Simulation iteration ", ids[[index]], " failed: ", detail, call. = FALSE)
      }
      output[ids[[index]]] <- list(value$value)
    }
    emit(ids[[length(ids)]])
  }
  output
}
