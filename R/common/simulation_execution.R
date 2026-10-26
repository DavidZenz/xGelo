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

# Disk-backed execution uses an explicit reducer, never a list of N results.
simulation_file_hash <- function(path) digest::digest(file = path, algo = "sha256")
simulation_atomic_rds <- function(value, path) {
  temporary <- paste0(path, ".next-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  saveRDS(value, temporary, compress = FALSE, version = 3L)
  if (!file.rename(temporary, path)) stop("Simulation atomic write failed: ", path, call. = FALSE)
}
simulation_stream_validate_chunk <- function(path, expected_ids, fingerprint) {
  marker <- file.path(path, "commit.rds")
  if (!file.exists(marker)) stop("Uncommitted simulation chunk: ", path, call. = FALSE)
  commit <- readRDS(marker)
  if (!identical(commit$fingerprint, fingerprint) || !identical(commit$ids, expected_ids)) {
    stop("Simulation chunk identity/coverage mismatch", call. = FALSE)
  }
  for (name in c("trace.bin.gz", "statistics.rds")) {
    file <- file.path(path, name)
    if (!file.exists(file) || !identical(simulation_file_hash(file), commit$hashes[[name]])) {
      stop("Corrupt simulation chunk: ", file, call. = FALSE)
    }
  }
  commit
}

simulation_execute_stream <- function(count, iteration, reducer, identity, run_dir,
    workers = 4L, chunk_size = 256L, resume = FALSE, progress = NULL,
    trace = function(value) value, budget = NULL, batch_size = 32L) {
  integer_control <- function(value, name) {
    if (length(value) != 1L || is.na(value) || !is.finite(value) || value < 1 ||
        value != floor(value) || value > .Machine$integer.max) stop(name, " must be a positive integer", call. = FALSE)
    as.integer(value)
  }
  count <- integer_control(count, "count"); chunk_size <- integer_control(chunk_size, "chunk_size")
  batch_size <- integer_control(batch_size, "batch_size")
  workers <- min(integer_control(workers, "workers"), count)
  if (.Platform$OS.type == "windows") workers <- 1L
  if (!is.logical(resume) || length(resume) != 1L || is.na(resume)) stop("Invalid resume control", call. = FALSE)
  if (!(is.null(progress) || is.function(progress) || (is.logical(progress) && length(progress) == 1L && !is.na(progress)))) stop("Invalid progress control", call. = FALSE)
  if (!all(vapply(reducer[c("init", "update", "merge")], is.function, logical(1)))) stop("Invalid simulation reducer", call. = FALSE)
  if (!is.function(trace)) stop("Invalid simulation trace writer", call. = FALSE)
  if (is.null(run_dir) || length(run_dir) != 1L || is.na(run_dir) || !nzchar(run_dir)) stop("Streaming requires run_dir", call. = FALSE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) saved_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    if (had_seed) assign(".Random.seed", saved_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(run_dir)) stop("Cannot create simulation run directory", call. = FALSE)
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  lock <- file.path(run_dir, ".lock")
  if (!dir.create(lock, showWarnings = FALSE)) {
    owner <- tryCatch(readRDS(file.path(lock, "owner.rds")), error = function(e) NULL)
    alive <- if (!is.null(owner) && identical(owner$host, Sys.info()[["nodename"]])) tryCatch(isTRUE(tools::pskill(owner$pid, 0L)), error = function(e) TRUE) else TRUE
    if (!resume || alive) stop("Simulation run is locked", call. = FALSE)
    unlink(lock, recursive = TRUE)
    if (!dir.create(lock, showWarnings = FALSE)) stop("Cannot lock simulation run", call. = FALSE)
  }
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  saveRDS(list(pid = Sys.getpid(), host = Sys.info()[["nodename"]]), file.path(lock, "owner.rds"))
  environment <- list(R = R.version.string, platform = R.version$platform, RNG = RNGkind(),
    locale = Sys.getlocale(), long_double_bytes = .Machine$sizeof.longdouble,
    formatting = options()[c("OutDec", "scipen", "digits")],
    packages = vapply(c("digest", "jsonlite"), function(p) as.character(utils::packageVersion(p)), character(1)))
  manifest <- list(schema = "simulation-stream-v1", identity = identity, count = count,
    chunk_size = chunk_size, environment = environment)
  fingerprint <- digest::digest(manifest, algo = "sha256")
  manifest$fingerprint <- fingerprint
  manifest_path <- file.path(run_dir, "manifest.rds")
  if (file.exists(manifest_path)) {
    if (!resume) stop("Simulation run already exists; use resume", call. = FALSE)
    if (!identical(readRDS(manifest_path), manifest)) stop("Simulation resume fingerprint mismatch", call. = FALSE)
  } else {
    if (length(setdiff(list.files(run_dir, all.files = TRUE, no.. = TRUE), ".lock"))) stop("Run directory is not empty", call. = FALSE)
    simulation_atomic_rds(manifest, manifest_path)
  }
  ranges <- lapply(seq.int(1L, count, by = chunk_size), function(first) seq.int(first, min(count, first + chunk_size - 1L)))
  chunk_path <- function(index) file.path(run_dir, sprintf("chunk-%06d", index))
  expected_names <- sprintf("chunk-%06d", seq_along(ranges))
  unknown <- setdiff(list.files(run_dir, pattern = "^chunk-"), expected_names)
  if (length(unknown)) stop("Unexpected/overlapping simulation chunks", call. = FALSE)
  done <- vapply(seq_along(ranges), function(index) {
    path <- chunk_path(index)
    if (!dir.exists(path)) return(FALSE)
    simulation_stream_validate_chunk(path, ranges[[index]], fingerprint)
    TRUE
  }, logical(1))
  # Interrupted staging directories never have commit authority.
  unlink(list.files(run_dir, pattern = "^\\.partial-", full.names = TRUE), recursive = TRUE)
  progress_dir <- file.path(run_dir, ".progress")
  unlink(progress_dir, recursive = TRUE)
  if (!dir.create(progress_dir)) stop("Cannot create private simulation progress directory", call. = FALSE)
  started <- proc.time()[["elapsed"]]
  initially_completed <- sum(lengths(ranges)[done])
  observed_completed <- initially_completed
  emit <- function(phase = "simulation") {
    elapsed <- unname(proc.time()[["elapsed"]] - started)
    committed <- sum(lengths(ranges)[done]); completed <- committed
    for (index in which(!done)) {
      counter <- file.path(progress_dir, as.character(index))
      if (file.exists(counter)) {
        value <- suppressWarnings(as.integer(readLines(counter, warn = FALSE)))
        if (length(value) == 1L && !is.na(value) && value >= 0L && value <= length(ranges[[index]])) completed <- completed + value
      }
    }
    observed_completed <<- completed
    newly_completed <- completed - initially_completed
    event <- list(phase = phase, completed = as.integer(completed), committed = as.integer(committed), total = count,
      elapsed_seconds = elapsed, estimated_remaining_seconds = if (newly_completed > 0) elapsed * (count - completed) / newly_completed else NA_real_, workers = workers)
    if (is.function(budget)) budget(event)
    if (is.function(progress)) progress(event)
    else if (isTRUE(progress)) message(sprintf("simulation_progress phase=%s completed=%d committed=%d total=%d elapsed_seconds=%.3f remaining_seconds=%.3f workers=%d", phase, completed, committed, count, elapsed, event$estimated_remaining_seconds, workers))
  }
  emit()
  execute_chunk <- function(index) {
    path <- file.path(run_dir, sprintf(".partial-%06d-%d", index, Sys.getpid()))
    if (!dir.create(path)) stop("Cannot stage simulation chunk", call. = FALSE)
    con <- gzfile(file.path(path, "trace.bin.gz"), "wb", compression = 1L)
    on.exit(try(close(con), silent = TRUE), add = TRUE)
    accumulator <- reducer$init()
    local_count <- 0L
    for (id in ranges[[index]]) {
      value <- iteration(id)
      accumulator <- reducer$update(accumulator, value, id)
      serialize(list(iteration = id, value = trace(value)), con, version = 3L)
      local_count <- local_count + 1L
      if (local_count %% batch_size == 0L || local_count == length(ranges[[index]])) {
        counter <- file.path(progress_dir, as.character(index)); next_path <- paste0(counter, ".next")
        writeLines(as.character(local_count), next_path)
        if (!file.rename(next_path, counter)) stop("Simulation progress counter write failed", call. = FALSE)
        if (workers == 1L) emit()
      }
    }
    close(con)
    saveRDS(accumulator, file.path(path, "statistics.rds"), compress = FALSE, version = 3L)
    hashes <- stats::setNames(vapply(c("trace.bin.gz", "statistics.rds"), function(name) simulation_file_hash(file.path(path, name)), character(1)), c("trace.bin.gz", "statistics.rds"))
    saveRDS(list(fingerprint = fingerprint, ids = ranges[[index]], hashes = hashes), file.path(path, "commit.rds"), compress = FALSE)
    simulation_stream_validate_chunk(path, ranges[[index]], fingerprint)
    if (!file.rename(path, chunk_path(index))) stop("Simulation chunk commit failed", call. = FALSE)
    index
  }
  missing <- which(!done)
  jobs <- list()
  on.exit(for (job in jobs) try(tools::pskill(job$pid), silent = TRUE), add = TRUE)
  if (workers > 1L && length(missing)) {
    assignments <- split(missing, rep(seq_len(min(workers, length(missing))), length.out = length(missing)))
    # One fork per worker. IPC carries only terminal status; committed chunks
    # remain on disk, so completed workers never send an N-sized result list.
    for (key in names(assignments)) {
      indexes <- assignments[[key]]
      jobs[[key]] <- parallel::mcparallel(tryCatch({
        for (index in indexes) execute_chunk(index)
        list(ok = TRUE)
      }, error = function(e) list(ok = FALSE, error = conditionMessage(e))), mc.set.seed = FALSE)
    }
    while (length(jobs)) {
      ready <- parallel::mccollect(jobs, wait = FALSE)
      for (pid in names(ready)) {
        result <- ready[[pid]]
        if (!is.list(result) || !isTRUE(result$ok)) stop("Simulation worker failed: ", if (is.list(result)) result$error else "no terminal result", call. = FALSE)
        key <- names(jobs)[vapply(jobs, function(job) identical(as.character(job$pid), pid), logical(1))]
        jobs[[key]] <- NULL
      }
      observed <- vapply(which(!done), function(index) file.exists(file.path(chunk_path(index), "commit.rds")), logical(1))
      if (any(observed)) done[which(!done)[observed]] <- TRUE
      previous_completed <- observed_completed
      # Read atomic per-chunk counters without treating them as checkpoints.
      counters <- vapply(which(!done), function(index) {
        path <- file.path(progress_dir, as.character(index))
        value <- if (file.exists(path)) suppressWarnings(as.integer(readLines(path, warn = FALSE))) else 0L
        if (length(value) == 1L && !is.na(value)) min(length(ranges[[index]]), max(0L, value)) else 0L
      }, integer(1))
      current_completed <- sum(lengths(ranges)[done]) + sum(counters)
      if (any(observed) || current_completed != previous_completed) emit()
      if (length(jobs)) { if (is.function(budget)) budget(NULL); Sys.sleep(.1) }
    }
  } else for (index in missing) { execute_chunk(index); done[[index]] <- TRUE; emit() }
  accumulator <- reducer$init()
  emit("aggregation")
  for (index in seq_along(ranges)) {
    simulation_stream_validate_chunk(chunk_path(index), ranges[[index]], fingerprint)
    accumulator <- reducer$merge(accumulator, readRDS(file.path(chunk_path(index), "statistics.rds")))
    if (is.function(budget)) budget(NULL)
  }
  structure(list(run_dir = run_dir, manifest = manifest, statistics = accumulator,
    complete = all(done)), class = "simulation_trace_store")
}

simulation_trace_visit <- function(store, visitor) {
  if (!inherits(store, "simulation_trace_store") || !isTRUE(store$complete)) stop("Missing complete simulation trace store", call. = FALSE)
  manifest <- readRDS(file.path(store$run_dir, "manifest.rds"))
  if (!identical(manifest, store$manifest)) stop("Simulation trace manifest changed", call. = FALSE)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  for (index in seq_along(firsts)) {
    ids <- seq.int(firsts[[index]], min(manifest$count, firsts[[index]] + manifest$chunk_size - 1L))
    path <- file.path(store$run_dir, sprintf("chunk-%06d", index))
    simulation_stream_validate_chunk(path, ids, manifest$fingerprint)
    con <- gzfile(file.path(path, "trace.bin.gz"), "rb")
    tryCatch({
      for (id in ids) {
        record <- unserialize(con)
        if (!identical(record$iteration, id)) stop("Simulation trace iteration mismatch", call. = FALSE)
        visitor(record$value, id)
      }
      if (length(readBin(con, "raw", 1L))) stop("Unexpected simulation trace records", call. = FALSE)
    }, finally = close(con))
  }
  invisible(TRUE)
}

simulation_trace_materialize <- function(store) {
  values <- vector("list", store$manifest$count)
  simulation_trace_visit(store, function(value, id) values[id] <<- list(value))
  values
}

# Reducer buckets retain the earliest row and exact value frequencies. Integer
# counts are represented as doubles to avoid integer overflow at large scales.
simulation_bucket_state <- function(names) stats::setNames(lapply(names, function(name) new.env(hash = TRUE, parent = emptyenv())), names)
simulation_bucket_key <- function(row, fields) paste(vapply(row[fields], function(x) if (is.na(x[[1L]])) "<NA>" else as.character(x[[1L]]), character(1)), collapse = "\x1f")
simulation_bucket_merge <- function(left, right) {
  before <- right$ordinal[[1L]] < left$ordinal[[1L]] ||
    (right$ordinal[[1L]] == left$ordinal[[1L]] && right$ordinal[[2L]] < left$ordinal[[2L]])
  first <- if (before) right else left
  first$n <- left$n + right$n
  first$values <- left$values
  for (field in names(right$values)) {
    a <- first$values[[field]]; b <- right$values[[field]]
    for (key in names(b)) {
      if (key %in% names(a)) a[[key]] <- a[[key]] + b[[key]] else a[[key]] <- b[[key]]
    }
    first$values[[field]] <- a
  }
  first
}
simulation_bucket_merge_state <- function(left, right) {
  for (name in names(left)) for (key in ls(right[[name]], all.names = TRUE, sorted = FALSE)) {
    b <- get(key, right[[name]])
    if (exists(key, left[[name]], inherits = FALSE)) b <- simulation_bucket_merge(get(key, left[[name]]), b)
    assign(key, b, left[[name]])
  }
  left
}
simulation_bucket_values <- function(table, sorted = TRUE) mget(ls(table, all.names = TRUE, sorted = sorted), envir = table, inherits = FALSE)
simulation_hist_quantile <- function(histogram, probabilities, type = 7L) {
  if (!type %in% c(1L, 7L)) stop("Unsupported exact histogram quantile policy", call. = FALSE)
  values <- as.numeric(names(histogram)); ordering <- order(values, method = "radix")
  values <- values[ordering]; cumulative <- cumsum(histogram[ordering]); n <- sum(histogram)
  vapply(probabilities, function(p) {
    if (type == 1L) return(values[which(cumulative >= max(1, ceiling(n * p)))[[1L]]])
    h <- (n - 1) * p + 1; lo <- floor(h); hi <- ceiling(h)
    a <- values[which(cumulative >= lo)[[1L]]]; b <- values[which(cumulative >= hi)[[1L]]]
    if (lo == hi || a == b) a else (1 - (h - lo)) * a + (h - lo) * b
  }, numeric(1))
}

simulation_trace_reference <- function(store, field) structure(list(store = store, field = field), class = "simulation_trace_reference")
simulation_trace_table <- function(reference, transform = identity) {
  if (!inherits(reference, "simulation_trace_reference")) stop("Missing simulation trace reference", call. = FALSE)
  frames <- list()
  simulation_trace_visit(reference$store, function(value, id) {
    frame <- value[[reference$field]]
    if (!is.data.frame(frame)) stop("Simulation trace table is missing: ", reference$field, call. = FALSE)
    frames[[length(frames) + 1L]] <<- transform(frame)
  })
  if (!length(frames)) return(data.frame())
  fields <- unique(unlist(lapply(frames, names)))
  frames <- lapply(frames, function(frame) { for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame)); frame[, fields, drop = FALSE] })
  result <- do.call(rbind, frames); row.names(result) <- NULL; result
}

# External sort bounds canonical hashing memory. Hex UTF-8 keys preserve radix
# field ordering including prefixes/control characters; payload uses base64 so
# embedded record separators/newlines cannot affect the external sort format.
simulation_trace_nl_hashes <- function(store, fields, transform, normalize) {
  directory <- tempfile("simulation-canonical-", tmpdir = store$run_dir)
  if (!dir.create(directory)) stop("Cannot create canonical sort workspace", call. = FALSE)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  columns <- stats::setNames(vector("list", length(fields)), fields)
  simulation_trace_visit(store, function(value, id) for (field in fields) {
    frame <- transform(value[[field]])
    columns[[field]] <<- union(columns[[field]], names(frame))
  })
  connections <- stats::setNames(lapply(fields, function(field) file(file.path(directory, paste0(field, ".input")), "wb")), fields)
  on.exit(for (con in connections) try(close(con), silent = TRUE), add = TRUE)
  hex <- function(value) paste(sprintf("%02x", as.integer(charToRaw(enc2utf8(value)))), collapse = "")
  for (field in fields) columns[[field]] <- sort(columns[[field]], method = "radix")
  simulation_trace_visit(store, function(value, id) for (field in fields) {
    frame <- transform(value[[field]])
    if (!nrow(frame)) next
    for (name in setdiff(columns[[field]], names(frame))) frame[[name]] <- rep(NA, nrow(frame))
    values <- lapply(frame[, columns[[field]], drop = FALSE], normalize)
    hex_columns <- lapply(values, function(column) {
      unique_values <- unique(column)
      encoded <- vapply(unique_values, hex, character(1), USE.NAMES = FALSE)
      encoded[match(column, unique_values)]
    })
    keys <- do.call(paste, c(hex_columns, list(sep = "!")))
    text <- do.call(paste, c(values, list(sep = "\x1f")))
    payload <- vapply(text, function(row) jsonlite::base64_enc(charToRaw(row)), character(1), USE.NAMES = FALSE)
    lines <- paste0(keys, "\t", gsub("\n", "", payload, fixed = TRUE))
    writeLines(lines, connections[[field]], useBytes = TRUE)
  })
  for (con in connections) close(con)
  hashes <- stats::setNames(character(length(fields)), fields)
  for (field in fields) {
    input <- file.path(directory, paste0(field, ".input")); sorted <- paste0(input, ".sorted")
    status <- system2("/usr/bin/sort", c("-S", "16M", "-T", shQuote(directory), "-o", shQuote(sorted), shQuote(input)), env = "LC_ALL=C")
    if (!identical(status, 0L)) stop("Canonical simulation external sort failed", call. = FALSE)
    payload <- file.path(directory, paste0(field, ".canonical"))
    output <- file(payload, "wb"); source <- file(sorted, "rb")
    tryCatch({
      writeBin(charToRaw(paste(columns[[field]], collapse = "\x1f")), output)
      repeat {
        lines <- readLines(source, n = 1024L, warn = FALSE)
        if (!length(lines)) break
        for (line in lines) {
          encoded <- substring(line, regexpr("\t", line, fixed = TRUE) + 1L)
          writeBin(as.raw(30L), output); writeBin(jsonlite::base64_dec(encoded), output)
        }
      }
    }, finally = { close(output); close(source) })
    hashes[[field]] <- simulation_file_hash(payload)
  }
  hashes
}

simulation_trace_validate <- function(store) {
  if (!inherits(store, "simulation_trace_store") || !isTRUE(store$complete)) stop("Missing complete simulation trace store", call. = FALSE)
  manifest <- readRDS(file.path(store$run_dir, "manifest.rds"))
  if (!identical(store$manifest, manifest)) stop("Simulation trace manifest mismatch", call. = FALSE)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  paths <- sprintf("chunk-%06d", seq_along(firsts))
  if (!setequal(list.files(store$run_dir, pattern = "^chunk-"), paths)) stop("Simulation trace chunk inventory mismatch", call. = FALSE)
  for (index in seq_along(firsts)) simulation_stream_validate_chunk(file.path(store$run_dir, paths[[index]]),
    seq.int(firsts[[index]], min(manifest$count, firsts[[index]] + manifest$chunk_size - 1L)), manifest$fingerprint)
  invisible(TRUE)
}

simulation_repository_identity <- function(root = ".") {
  paths <- sort(c(list.files(file.path(root, "R"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
    file.path(root, c("scripts/build_nations_league_outcomes.R", "scripts/build_uefa_champions_league_outcomes.R"))), method = "radix")
  # list.files can preserve a relative root; normalize before assigning names.
  paths <- normalizePath(paths, mustWork = TRUE)
  relative <- substring(paths, nchar(normalizePath(root, mustWork = TRUE)) + 2L)
  stats::setNames(vapply(paths, simulation_file_hash, character(1)), relative)
}

# R's two-pass mean can depend on observation order. Preserve that exact result
# without retaining tournament histories: spool one scalar series per metric,
# in iteration order, and materialize at most one <=100k scalar column (0.8 MB).
simulation_exact_trace_means <- function(store) {
  if (store$manifest$count > 100000L) stop("Exact streamed means support at most 100000 iterations", call. = FALSE)
  directory <- tempfile("simulation-means-", tmpdir = store$run_dir)
  dir.create(directory); on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  files <- new.env(hash = TRUE, parent = emptyenv()); frames <- list(); serial <- 0L
  flush <- function() {
    frame <- do.call(rbind, frames)
    frames <<- list()
    if (is.null(frame) || !nrow(frame)) return(invisible(NULL))
    grouped <- split(frame$value, frame$key, drop = TRUE)
    for (key in names(grouped)) {
      if (!exists(key, files, inherits = FALSE)) { serial <<- serial + 1L; assign(key, file.path(directory, as.character(serial)), files) }
      con <- file(get(key, files), "ab")
      tryCatch(writeBin(as.double(grouped[[key]]), con, size = 8L), finally = close(con))
    }
  }
  simulation_trace_visit(store, function(value, id) {
    if (!is.data.frame(value$mean_records)) stop("Exact mean trace records are missing", call. = FALSE)
    frames[[length(frames) + 1L]] <<- value$mean_records
    if (id %% store$manifest$chunk_size == 0L || id == store$manifest$count) flush()
  })
  values <- new.env(hash = TRUE, parent = emptyenv())
  for (key in ls(files, all.names = TRUE, sorted = FALSE)) {
    path <- get(key, files); n <- file.info(path)$size / 8
    if (n > 100000L || n != floor(n)) stop("Exact mean scalar-series bound exceeded", call. = FALSE)
    con <- file(path, "rb")
    series <- tryCatch(readBin(con, "double", n = n, size = 8L), finally = close(con))
    assign(key, if (anyNA(series)) NA_real_ else mean(series), values)
  }
  values
}

simulation_bucket_keys <- function(rows, fields) {
  if (!nrow(rows)) return(character())
  columns <- lapply(rows[fields], function(x) { value <- as.character(x); value[is.na(value)] <- "<NA>"; value })
  if (!length(columns)) return(rep("<empty>", nrow(rows)))
  do.call(paste, c(columns, list(sep = "\x1f")))
}
simulation_bucket_observe <- function(table, rows, fields, numeric_fields, iteration,
                                      histogram_fields = numeric_fields) {
  keys <- simulation_bucket_keys(rows, fields)
  for (index in seq_along(keys)) {
    key <- keys[[index]]
    if (exists(key, table, inherits = FALSE)) {
      bucket <- get(key, table, inherits = FALSE); bucket$n <- bucket$n + 1
    } else {
      bucket <- list(row = rows[index, , drop = FALSE], ordinal = c(iteration, index), n = 1,
        values = stats::setNames(lapply(numeric_fields, function(field) numeric()), numeric_fields))
    }
    for (field in histogram_fields) {
      value <- as.numeric(rows[[field]][[index]])
      token <- if (is.na(value)) "<NA>" else as.character(value)
      histogram <- bucket$values[[field]]
      if (token %in% names(histogram)) histogram[[token]] <- histogram[[token]] + 1 else histogram[[token]] <- 1
      bucket$values[[field]] <- histogram
    }
    assign(key, bucket, table)
  }
  invisible(NULL)
}
