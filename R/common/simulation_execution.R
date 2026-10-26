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
simulation_statistics_codec <- function(codec = NULL) {
  if (is.null(codec)) return(NULL) # absent legacy metadata permits header detection
  if (!is.character(codec) || length(codec) != 1L || is.na(codec) ||
      !codec %in% c("none", "gzip")) stop("Unknown simulation statistics codec", call. = FALSE)
  codec
}
simulation_statistics_read <- function(bytes, codec, expected_size = NULL, expected_crc32 = NULL) {
  codec <- simulation_statistics_codec(codec)
  if (is.null(codec)) codec <- if (length(bytes) >= 2L && identical(bytes[1:2], as.raw(c(31L, 139L)))) "gzip" else "none"
  con <- NULL
  on.exit(if (!is.null(con)) close(con))
  withCallingHandlers({
    if (identical(codec, "gzip")) {
      if (length(bytes) < 18L || !identical(bytes[1:2], as.raw(c(31L, 139L)))) stop("Corrupt simulation statistics gzip header/trailer", call. = FALSE)
      trailer <- bytes[seq.int(length(bytes) - 7L, length(bytes))]
      trailer_crc32 <- paste(sprintf("%02x", as.integer(rev(trailer[1:4]))), collapse = "")
      trailer_size <- sum(as.integer(trailer[5:8]) * 256^(0:3))
      limit <- if (is.null(expected_size)) trailer_size else expected_size
      if (!is.finite(limit) || limit < 0 || limit != floor(limit) || limit %% 2^32 != trailer_size) stop("Corrupt simulation statistics gzip size binding", call. = FALSE)
      con <- gzcon(rawConnection(bytes), allowNonCompressed = FALSE)
      blocks <- list(); total <- 0
      previous_messages <- sink.number(type = "message")
      diagnostics <- tryCatch(utils::capture.output({
        repeat {
          # The new writer binds the exact serialized size. Legacy gzip uses
          # its trailer size; block reads never allocate a corrupt claimed size.
          block <- readBin(con, "raw", n = min(1048576, limit - total + 1))
          if (!length(block)) break
          total <- total + length(block)
          if (total > limit) stop("Corrupt simulation statistics decompressed size", call. = FALSE)
          blocks[[length(blocks) + 1L]] <- block
        }
      }, type = "message"), finally = {
        # R's gzip CRC failures can use REprintf without a warning condition.
        # Capture those diagnostics and preserve an existing caller message sink.
        if (sink.number(type = "message") != previous_messages) sink(getConnection(previous_messages), type = "message")
      })
      if (length(diagnostics)) stop("Corrupt simulation statistics gzip diagnostic: ", paste(diagnostics, collapse = "; "), call. = FALSE)
      close(con); con <- NULL
      if (total != limit) stop("Corrupt simulation statistics truncated gzip size", call. = FALSE)
      payload <- if (length(blocks)) do.call(c, blocks) else raw()
      crc32 <- digest::digest(payload, algo = "crc32", serialize = FALSE)
      if (!identical(crc32, trailer_crc32) || (!is.null(expected_crc32) && !identical(crc32, expected_crc32))) stop("Corrupt simulation statistics gzip CRC32", call. = FALSE)
      rm(blocks)
    } else {
      payload <- bytes
      if ((!is.null(expected_size) && length(payload) != expected_size) ||
          (!is.null(expected_crc32) && !identical(digest::digest(payload, algo = "crc32", serialize = FALSE), expected_crc32))) stop("Corrupt simulation statistics serialization binding", call. = FALSE)
    }
    con <- rawConnection(payload)
    value <- readRDS(con)
    if (length(readBin(con, "raw", 1L))) stop("Unexpected simulation statistics records", call. = FALSE)
    value
  }, warning = function(warning) stop("Corrupt simulation statistics: ", conditionMessage(warning), call. = FALSE))
}
simulation_stream_schema_builder <- function(ids, auxiliary_fields) {
  schema <- list(schema = "simulation-trace-schema-v2", ids = ids,
    auxiliary_fields = auxiliary_fields, record_names = list(), frames = list())
  observe <- function(value, id = NULL) {
    if (!is.list(value) || is.data.frame(value) || is.null(names(value))) return(invisible(NULL))
    fields <- names(value)
    if (!any(vapply(schema$record_names, identical, logical(1), fields))) schema$record_names[[length(schema$record_names) + 1L]] <<- fields
    for (field in fields) {
      frame <- value[[field]]
      if (!is.data.frame(frame)) next
      variants <- schema$frames[[field]]
      same <- which(vapply(variants, function(x) identical(names(x), names(frame)), logical(1)))
      if (!length(same)) {
        variants[[length(variants) + 1L]] <- frame[if (nrow(frame)) 1L else integer(), , drop = FALSE]
      } else if (!nrow(variants[[same[[1L]]]]) && nrow(frame)) variants[[same[[1L]]]] <- frame[1L, , drop = FALSE]
      schema$frames[field] <<- list(variants)
    }
    invisible(NULL)
  }
  list(observe = observe, value = function() schema)
}
# Check the bytes that readers will decode. A chunk is bounded by chunk_size;
# retaining its compressed payload avoids hashing a path and then reopening a
# possibly changed file. Unselected payloads are hashed and released immediately.
simulation_stream_read_chunk <- function(path, expected_ids, fingerprint,
    keep = character(), auxiliary_fields = NULL, expected_schema = NULL,
    expected_statistics_codec = NULL) {
  marker <- file.path(path, "commit.rds")
  if (!file.exists(marker)) stop("Uncommitted simulation chunk: ", path, call. = FALSE)
  commit <- tryCatch(readRDS(marker), error = function(e) stop("Corrupt simulation chunk commit", call. = FALSE))
  if (!identical(commit$fingerprint, fingerprint) || !identical(commit$ids, expected_ids)) {
    stop("Simulation chunk identity/coverage mismatch", call. = FALSE)
  }
  version2 <- identical(commit$schema, "simulation-chunk-v2")
  statistics_codec <- simulation_statistics_codec(commit$statistics_codec)
  if (!identical(statistics_codec, simulation_statistics_codec(expected_statistics_codec))) stop("Simulation statistics codec mismatch", call. = FALSE)
  statistics_size <- commit$statistics_uncompressed_bytes; statistics_crc32 <- commit$statistics_crc32
  if (!is.null(statistics_codec) || !is.null(statistics_size) || !is.null(statistics_crc32)) {
    if (!is.numeric(statistics_size) || length(statistics_size) != 1L || !is.finite(statistics_size) ||
        statistics_size < 0 || statistics_size != floor(statistics_size) ||
        !is.character(statistics_crc32) || length(statistics_crc32) != 1L || is.na(statistics_crc32) ||
        !grepl("^[0-9a-f]{8}$", statistics_crc32)) stop("Simulation statistics serialization metadata mismatch", call. = FALSE)
  }
  if ((!is.null(commit$schema) && !version2) ||
      (!is.null(expected_schema) && !expected_schema %in% c("simulation-stream-v1", "simulation-stream-v2")) ||
      (identical(expected_schema, "simulation-stream-v2") && !version2) ||
      (identical(expected_schema, "simulation-stream-v1") && !is.null(commit$schema))) {
    stop("Simulation chunk schema/version mismatch", call. = FALSE)
  }
  auxiliary <- if (version2) commit$auxiliary_fields else character()
  if (!is.character(auxiliary) || anyNA(auxiliary) || any(!nzchar(auxiliary)) || anyDuplicated(auxiliary) ||
      (!is.null(auxiliary_fields) && !identical(auxiliary, auxiliary_fields))) stop("Simulation auxiliary field identity mismatch", call. = FALSE)
  auxiliary_files <- if (length(auxiliary)) sprintf("auxiliary-%04d.bin.gz", seq_along(auxiliary)) else character()
  payloads <- c("trace.bin.gz", "statistics.rds", if (version2) "schema.rds", auxiliary_files)
  if (!is.character(commit$hashes) || !identical(names(commit$hashes), payloads) ||
      !setequal(list.files(path, all.files = TRUE, no.. = TRUE), c(payloads, "commit.rds"))) {
    stop("Simulation chunk file inventory mismatch", call. = FALSE)
  }
  buffers <- list(); schema <- NULL
  for (name in payloads) {
    file <- file.path(path, name)
    bytes <- tryCatch(readBin(file, "raw", n = file.info(file)$size), error = function(e) NULL)
    if (is.null(bytes) || !identical(digest::digest(bytes, algo = "sha256", serialize = FALSE), commit$hashes[[name]])) {
      stop("Corrupt simulation chunk: ", file, call. = FALSE)
    }
    if (name == "statistics.rds") {
      gzip <- length(bytes) >= 2L && identical(bytes[1:2], as.raw(c(31L, 139L)))
      effective_statistics_codec <- if (gzip) "gzip" else "none"
      if (!is.null(statistics_codec) && !identical(effective_statistics_codec, statistics_codec)) stop("Simulation statistics codec/header mismatch", call. = FALSE)
    }
    if (name == "schema.rds") {
      con <- rawConnection(bytes)
      schema <- tryCatch(readRDS(con), error = function(e) stop("Corrupt simulation chunk schema", call. = FALSE), finally = close(con))
    }
    if (name %in% keep) buffers[[name]] <- bytes
  }
  if (version2 && (!is.list(schema) || !identical(schema$schema, "simulation-trace-schema-v2") ||
      !identical(schema$ids, expected_ids) || !identical(schema$auxiliary_fields, auxiliary) ||
      !is.list(schema$record_names) || !is.list(schema$frames))) stop("Simulation chunk schema identity/coverage mismatch", call. = FALSE)
  list(commit = commit, schema = schema, buffers = buffers, statistics_codec = effective_statistics_codec,
    statistics_size = statistics_size, statistics_crc32 = statistics_crc32)
}

simulation_stream_trace_connections <- function(chunk, fields = NULL) {
  auxiliary <- chunk$commit$auxiliary_fields
  if (is.null(auxiliary)) auxiliary <- character()
  selected <- if (is.null(fields)) auxiliary else intersect(auxiliary, fields)
  files <- if (length(selected)) stats::setNames(sprintf("auxiliary-%04d.bin.gz", match(selected, auxiliary)), selected) else character()
  need_main <- is.null(fields) || any(!fields %in% auxiliary) || !identical(chunk$commit$schema, "simulation-chunk-v2")
  if (need_main) files <- c(.main = "trace.bin.gz", files)
  lapply(files, function(file) gzcon(rawConnection(chunk$buffers[[file]])))
}

simulation_stream_visit_chunk <- function(chunk, ids, visitor, fields = NULL) {
  connections <- simulation_stream_trace_connections(chunk, fields)
  on.exit(for (con in connections) try(close(con), silent = TRUE), add = TRUE)
  for (id in ids) {
    records <- lapply(connections, function(con) {
      record <- tryCatch(unserialize(con), error = function(e) stop("Corrupt simulation trace record: ", conditionMessage(e), call. = FALSE))
      if (!is.list(record) || !identical(record$iteration, id) || !"value" %in% names(record)) stop("Simulation trace iteration/coverage mismatch", call. = FALSE)
      record
    })
    value <- if (".main" %in% names(records)) records[[".main"]]$value else list()
    for (field in setdiff(names(records), ".main")) value[field] <- list(records[[field]]$value)
    if (identical(chunk$commit$schema, "simulation-chunk-v2") && ".main" %in% names(records)) {
      original_names <- records[[".main"]]$field_names
      if (!is.null(original_names)) {
        if (!any(vapply(chunk$schema$record_names, identical, logical(1), original_names)) ||
            !setequal(names(value), if (is.null(fields)) original_names else union(setdiff(original_names, chunk$commit$auxiliary_fields), intersect(original_names, fields)))) stop("Simulation trace field/schema mismatch", call. = FALSE)
        value <- value[original_names[original_names %in% names(value)]]
        if (is.null(fields)) for (name in names(records[[".main"]]$value_attributes)) attr(value, name) <- records[[".main"]]$value_attributes[[name]]
      }
    }
    if (!is.null(fields)) {
      if (!is.list(value) || !all(fields %in% names(value))) stop("Simulation trace fields are missing", call. = FALSE)
      value <- value[fields]
    }
    visitor(value, id)
  }
  for (con in connections) if (length(readBin(con, "raw", 1L))) stop("Unexpected simulation trace records", call. = FALSE)
  invisible(TRUE)
}

simulation_stream_validate_chunk <- function(path, expected_ids, fingerprint, auxiliary_fields = NULL,
    decode = FALSE, expected_schema = NULL, expected_statistics_codec = NULL) {
  marker <- tryCatch(readRDS(file.path(path, "commit.rds")), error = function(e) NULL)
  files <- if (!decode || is.null(marker)) character() else names(marker$hashes)
  chunk <- simulation_stream_read_chunk(path, expected_ids, fingerprint, keep = files,
    auxiliary_fields = auxiliary_fields, expected_schema = expected_schema,
    expected_statistics_codec = expected_statistics_codec)
  if (decode) simulation_statistics_read(chunk$buffers[["statistics.rds"]], chunk$statistics_codec,
    chunk$statistics_size, chunk$statistics_crc32)
  if (decode && identical(chunk$commit$schema, "simulation-chunk-v2")) {
    schema <- simulation_stream_schema_builder(expected_ids, chunk$commit$auxiliary_fields)
    simulation_stream_visit_chunk(chunk, expected_ids, schema$observe)
    if (!identical(chunk$schema, schema$value())) stop("Simulation chunk schema/row mismatch", call. = FALSE)
  } else if (decode) simulation_stream_visit_chunk(chunk, expected_ids, function(value, id) NULL)
  chunk$commit
}

simulation_execute_stream <- function(count, iteration, reducer, identity, run_dir,
    workers = 4L, chunk_size = 256L, resume = FALSE, progress = NULL,
    trace = function(value) value, budget = NULL, batch_size = 32L,
    auxiliary_fields = character(), statistics_codec = "gzip") {
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
  if (!is.null(reducer$finalize) && !is.function(reducer$finalize)) stop("Invalid simulation reducer finalizer", call. = FALSE)
  if (!is.function(trace)) stop("Invalid simulation trace writer", call. = FALSE)
  statistics_codec <- simulation_statistics_codec(statistics_codec)
  if (is.null(statistics_codec)) stop("New simulation runs require an explicit statistics codec", call. = FALSE)
  if (!is.character(auxiliary_fields) || anyNA(auxiliary_fields) || any(!nzchar(auxiliary_fields)) || anyDuplicated(auxiliary_fields) || ".main" %in% auxiliary_fields) stop("Invalid simulation auxiliary fields", call. = FALSE)
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
  manifest <- list(schema = "simulation-stream-v2", identity = identity, count = count,
    chunk_size = chunk_size, auxiliary_fields = auxiliary_fields,
    statistics_codec = statistics_codec, environment = environment)
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
    simulation_stream_validate_chunk(path, ranges[[index]], fingerprint, auxiliary_fields,
      expected_schema = manifest$schema, expected_statistics_codec = manifest$statistics_codec)
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
    auxiliary_files <- if (length(auxiliary_fields)) sprintf("auxiliary-%04d.bin.gz", seq_along(auxiliary_fields)) else character()
    connections <- list()
    on.exit(for (con in connections) try(close(con), silent = TRUE), add = TRUE)
    files <- stats::setNames(c("trace.bin.gz", auxiliary_files), c(".main", auxiliary_fields))
    for (field in names(files)) connections[[field]] <- gzfile(file.path(path, files[[field]]), "wb", compression = 1L)
    schema <- simulation_stream_schema_builder(ranges[[index]], auxiliary_fields)
    accumulator <- reducer$init()
    local_count <- 0L
    for (id in ranges[[index]]) {
      value <- iteration(id)
      accumulator <- reducer$update(accumulator, value, id)
      logical_trace <- trace(value)
      schema$observe(logical_trace)
      record <- list(iteration = id, value = logical_trace)
      if (length(auxiliary_fields)) {
        if (!is.list(logical_trace) || is.data.frame(logical_trace) || is.object(logical_trace) ||
            is.null(names(logical_trace)) || anyNA(names(logical_trace)) || anyDuplicated(names(logical_trace)) || any(!nzchar(names(logical_trace))) ||
            !all(auxiliary_fields %in% names(logical_trace))) stop("Auxiliary traces require complete, uniquely named plain lists", call. = FALSE)
        record$field_names <- names(logical_trace)
        record$value_attributes <- attributes(logical_trace)[setdiff(names(attributes(logical_trace)), "names")]
        record$value <- logical_trace[!names(logical_trace) %in% auxiliary_fields]
        for (field in auxiliary_fields) serialize(list(iteration = id, value = logical_trace[[field]]), connections[[field]], version = 3L)
      }
      serialize(record, connections[[".main"]], version = 3L)
      local_count <- local_count + 1L
      if (local_count %% batch_size == 0L || local_count == length(ranges[[index]])) {
        counter <- file.path(progress_dir, as.character(index)); next_path <- paste0(counter, ".next")
        writeLines(as.character(local_count), next_path)
        if (!file.rename(next_path, counter)) stop("Simulation progress counter write failed", call. = FALSE)
        if (workers == 1L) emit()
      }
    }
    for (con in connections) close(con)
    if (!identical(local_count, length(ranges[[index]]))) stop("Simulation emitted iteration coverage mismatch", call. = FALSE)
    # Some reducers use compact numeric state during the hot loop and convert
    # it to their merge representation only once for the completed chunk.
    if (is.function(reducer$finalize)) accumulator <- reducer$finalize(accumulator)
    statistics_path <- file.path(path, "statistics.rds")
    statistics_payload <- serialize(accumulator, NULL, version = 3L)
    statistics_size <- length(statistics_payload)
    statistics_crc32 <- digest::digest(statistics_payload, algo = "crc32", serialize = FALSE)
    if (identical(statistics_codec, "gzip")) {
      statistics_con <- gzfile(statistics_path, "wb", compression = 1L)
      tryCatch(writeBin(statistics_payload, statistics_con), finally = close(statistics_con))
    } else {
      statistics_con <- file(statistics_path, "wb")
      tryCatch(writeBin(statistics_payload, statistics_con), finally = close(statistics_con))
    }
    rm(statistics_payload)
    saveRDS(schema$value(), file.path(path, "schema.rds"), compress = FALSE, version = 3L)
    payloads <- c("trace.bin.gz", "statistics.rds", "schema.rds", auxiliary_files)
    hashes <- stats::setNames(vapply(payloads, function(name) simulation_file_hash(file.path(path, name)), character(1)), payloads)
    saveRDS(list(schema = "simulation-chunk-v2", fingerprint = fingerprint, ids = ranges[[index]],
      auxiliary_fields = auxiliary_fields, statistics_codec = statistics_codec,
      statistics_uncompressed_bytes = statistics_size, statistics_crc32 = statistics_crc32,
      hashes = hashes), file.path(path, "commit.rds"), compress = FALSE)
    simulation_stream_validate_chunk(path, ranges[[index]], fingerprint, auxiliary_fields,
      expected_schema = manifest$schema, expected_statistics_codec = manifest$statistics_codec)
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
    chunk <- simulation_stream_read_chunk(chunk_path(index), ranges[[index]], fingerprint,
      keep = "statistics.rds", auxiliary_fields = auxiliary_fields, expected_schema = manifest$schema,
      expected_statistics_codec = manifest$statistics_codec)
    statistics <- simulation_statistics_read(chunk$buffers[["statistics.rds"]], chunk$statistics_codec,
      chunk$statistics_size, chunk$statistics_crc32)
    accumulator <- reducer$merge(accumulator, statistics)
    if (is.function(budget)) budget(NULL)
  }
  structure(list(run_dir = run_dir, manifest = manifest, statistics = accumulator,
    complete = all(done)), class = "simulation_trace_store")
}

simulation_trace_manifest <- function(store) {
  if (!inherits(store, "simulation_trace_store") || !isTRUE(store$complete)) stop("Missing complete simulation trace store", call. = FALSE)
  manifest <- readRDS(file.path(store$run_dir, "manifest.rds"))
  if (!identical(manifest, store$manifest)) stop("Simulation trace manifest changed", call. = FALSE)
  if (!(identical(manifest$schema, "simulation-stream-v1") || identical(manifest$schema, "simulation-stream-v2"))) stop("Unknown simulation trace schema", call. = FALSE)
  simulation_statistics_codec(manifest$statistics_codec)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  paths <- sprintf("chunk-%06d", seq_along(firsts))
  if (!setequal(list.files(store$run_dir, pattern = "^chunk-"), paths)) stop("Simulation trace chunk inventory mismatch", call. = FALSE)
  manifest
}

simulation_trace_visit <- function(store, visitor, fields = NULL) {
  if (!is.function(visitor)) stop("Invalid simulation trace visitor", call. = FALSE)
  if (!is.null(fields) && (!is.character(fields) || anyNA(fields) || any(!nzchar(fields)) || anyDuplicated(fields))) stop("Invalid simulation trace field selection", call. = FALSE)
  manifest <- simulation_trace_manifest(store)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  auxiliary <- manifest$auxiliary_fields
  if (is.null(auxiliary)) auxiliary <- character()
  selected <- if (is.null(fields)) auxiliary else intersect(auxiliary, fields)
  keep <- if (is.null(fields) || any(!fields %in% auxiliary) || identical(manifest$schema, "simulation-stream-v1")) "trace.bin.gz" else character()
  if (length(selected)) keep <- c(keep, sprintf("auxiliary-%04d.bin.gz", match(selected, auxiliary)))
  for (index in seq_along(firsts)) {
    ids <- seq.int(firsts[[index]], min(manifest$count, firsts[[index]] + manifest$chunk_size - 1L))
    path <- file.path(store$run_dir, sprintf("chunk-%06d", index))
    chunk <- simulation_stream_read_chunk(path, ids, manifest$fingerprint, keep, auxiliary,
      expected_schema = manifest$schema, expected_statistics_codec = manifest$statistics_codec)
    simulation_stream_visit_chunk(chunk, ids, visitor, fields)
  }
  invisible(TRUE)
}

# Frame exemplars are committed with each chunk. Column discovery can therefore
# apply the same schema-preserving transform without decoding every football row.
# A separate row visit still verifies and decodes the exact bytes being hashed.
simulation_trace_schema_visit <- function(store, visitor) {
  manifest <- simulation_trace_manifest(store)
  if (!identical(manifest$schema, "simulation-stream-v2")) return(FALSE)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  for (index in seq_along(firsts)) {
    ids <- seq.int(firsts[[index]], min(manifest$count, firsts[[index]] + manifest$chunk_size - 1L))
    chunk <- simulation_stream_read_chunk(file.path(store$run_dir, sprintf("chunk-%06d", index)),
      ids, manifest$fingerprint, auxiliary_fields = manifest$auxiliary_fields, expected_schema = manifest$schema,
      expected_statistics_codec = manifest$statistics_codec)
    visitor(chunk$schema)
  }
  TRUE
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
  }, fields = reference$field)
  if (!length(frames)) return(data.frame())
  fields <- unique(unlist(lapply(frames, names)))
  frames <- lapply(frames, function(frame) { for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame)); frame[, fields, drop = FALSE] })
  result <- do.call(rbind, frames); row.names(result) <- NULL; result
}

# Resolve both ordinary repo calls and modules sourced into a private namespace
# before the caller changes directory. No path under the simulation run is code.
simulation_canonical_helper_path <- local({
  sources <- Filter(function(path) is.character(path) && length(path) == 1L &&
    basename(path) == "simulation_execution.R", lapply(sys.frames(), function(frame) frame$ofile))
  source_root <- if (length(sources)) dirname(dirname(dirname(normalizePath(sources[[length(sources)]], mustWork = TRUE)))) else NULL
  function() {
    for (start in unique(c(source_root, getwd()))) {
      root <- normalizePath(start, mustWork = TRUE)
      repeat {
        helper <- file.path(root, "scripts", "hash_simulation_canonical.py")
        if (file.exists(helper)) return(normalizePath(helper, mustWork = TRUE))
        parent <- dirname(root)
        if (identical(parent, root)) break
        root <- parent
      }
    }
    stop("Canonical simulation merge helper is missing", call. = FALSE)
  }
})

# Hex UTF-8 keys preserve radix field ordering, including prefixes and control
# characters. Bounded sorted gzip runs avoid whole-history plaintext copies.
# The stdlib helper merges <=32 streams and hashes the original framing directly.
simulation_trace_nl_hashes <- function(store, fields, transform, normalize,
    run_size = 4096L, fan_in = 32L) {
  if (length(run_size) != 1L || is.na(run_size) || !is.finite(run_size) || run_size < 1L || run_size > 4096L || run_size != floor(run_size)) stop("Invalid canonical run size", call. = FALSE)
  if (length(fan_in) != 1L || is.na(fan_in) || !is.finite(fan_in) || fan_in < 2L || fan_in > 32L || fan_in != floor(fan_in)) stop("Invalid canonical merge fan-in", call. = FALSE)
  run_size <- as.integer(run_size); fan_in <- as.integer(fan_in)
  helper <- simulation_canonical_helper_path()
  python <- Sys.which("python3")
  if (!nzchar(python)) stop("python3 is required for bounded canonical simulation hashing", call. = FALSE)
  directory <- tempfile("simulation-canonical-", tmpdir = store$run_dir)
  if (!dir.create(directory)) stop("Cannot create canonical sort workspace", call. = FALSE)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  columns <- stats::setNames(vector("list", length(fields)), fields)
  schemas <- simulation_trace_schema_visit(store, function(schema) for (field in fields) {
    frames <- schema$frames[[field]]
    if (is.null(frames)) stop("Simulation trace table schema is missing: ", field, call. = FALSE)
    for (frame in frames) columns[[field]] <<- union(columns[[field]], names(transform(frame)))
  })
  if (!schemas) simulation_trace_visit(store, function(value, id) for (field in fields) {
    columns[[field]] <<- union(columns[[field]], names(transform(value[[field]])))
  }, fields = fields)
  hex <- function(value) paste(sprintf("%02x", as.integer(charToRaw(enc2utf8(value)))), collapse = "")
  for (field in fields) columns[[field]] <- sort(columns[[field]], method = "radix")
  runs <- buffers <- column_cache <- stats::setNames(vector("list", length(fields)), fields)
  buffered <- totals <- stats::setNames(integer(length(fields)), fields)
  flush <- function(field) {
    if (!buffered[[field]]) return(invisible(NULL))
    lines <- sort(unlist(buffers[[field]], use.names = FALSE), method = "radix")
    if (length(lines) != buffered[[field]] || length(lines) > run_size) stop("Canonical sorted run coverage/bound mismatch", call. = FALSE)
    name <- sprintf("field-%04d-run-%08d.gz", match(field, fields), length(runs[[field]]) + 1L)
    path <- file.path(directory, name); con <- gzfile(path, "wb", compression = 1L)
    tryCatch(writeLines(lines, con, useBytes = TRUE), finally = close(con))
    runs[[field]][[length(runs[[field]]) + 1L]] <<- list(path = name, rows = length(lines), sha256 = simulation_file_hash(path))
    buffers[[field]] <<- list(); buffered[[field]] <<- 0L
    invisible(NULL)
  }
  append_lines <- function(field, lines) {
    first <- 1L
    while (first <= length(lines)) {
      take <- min(length(lines) - first + 1L, run_size - buffered[[field]])
      buffers[[field]][[length(buffers[[field]]) + 1L]] <<- lines[seq.int(first, first + take - 1L)]
      buffered[[field]] <<- buffered[[field]] + take
      totals[[field]] <<- totals[[field]] + take
      first <- first + take
      if (buffered[[field]] == run_size) flush(field)
    }
    invisible(NULL)
  }
  simulation_trace_visit(store, function(value, id) for (field in fields) {
    frame <- transform(value[[field]])
    if (!nrow(frame)) next
    if (length(setdiff(names(frame), columns[[field]]))) stop("Canonical trace transform changed its schema", call. = FALSE)
    for (name in setdiff(columns[[field]], names(frame))) frame[[name]] <- rep(NA, nrow(frame))
    values <- hex_columns <- vector("list", length(columns[[field]])); cache <- column_cache[[field]]
    for (index in seq_along(columns[[field]])) {
      name <- columns[[field]][[index]]; raw <- frame[[name]]; previous <- cache[[name]]
      if (!is.null(previous) && identical(raw, previous$raw)) {
        values[[index]] <- previous$values; hex_columns[[index]] <- previous$hex
        next
      }
      column <- enc2utf8(normalize(raw))
      if (!is.character(column) || length(column) != nrow(frame) || anyNA(column)) stop("Invalid canonical column normalization", call. = FALSE)
      unique_values <- unique(column)
      encoded <- if (!is.null(previous) && identical(unique_values, previous$unique)) previous$encoded else vapply(unique_values, hex, character(1), USE.NAMES = FALSE)
      values[[index]] <- column; hex_columns[[index]] <- encoded[match(column, unique_values)]
      # Retain only the last bounded column and its unique encoding. There is
      # no cumulative per-value cache as new tournament results arrive.
      cache[name] <- list(if (length(raw) <= 4096L && sum(nchar(column, type = "bytes")) <= 65536L)
        list(raw = raw, values = column, hex = hex_columns[[index]], unique = unique_values, encoded = encoded) else NULL)
    }
    column_cache[field] <<- list(cache)
    keys <- if (length(hex_columns)) do.call(paste, c(hex_columns, list(sep = "!"))) else rep("", nrow(frame))
    text <- if (length(values)) do.call(paste, c(values, list(sep = "\x1f"))) else rep("", nrow(frame))
    payload <- vapply(text, function(row) jsonlite::base64_enc(charToRaw(row)), character(1), USE.NAMES = FALSE)
    append_lines(field, paste0(keys, "\t", gsub("\n", "", payload, fixed = TRUE)))
  }, fields = fields)
  for (field in fields) flush(field)
  manifest <- list(schema = "simulation-canonical-runs-v1", fan_in = fan_in,
    fields = unname(lapply(fields, function(field) list(field = field, columns = length(columns[[field]]),
      rows = totals[[field]], header_base64 = gsub("\n", "", jsonlite::base64_enc(charToRaw(enc2utf8(paste(columns[[field]], collapse = "\x1f")))), fixed = TRUE),
      runs = if (length(runs[[field]])) runs[[field]] else list()))))
  manifest_path <- file.path(directory, "runs.json"); output_path <- file.path(directory, "hashes.json")
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, digits = NA)
  output <- suppressWarnings(system2(python, c(shQuote(helper), "--manifest", shQuote(manifest_path), "--output", shQuote(output_path)), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")
  if ((!is.null(status) && status != 0L) || !file.exists(output_path)) stop("Canonical simulation compressed merge failed: ", paste(output, collapse = "\n"), call. = FALSE)
  result <- tryCatch(jsonlite::read_json(output_path, simplifyVector = FALSE), error = function(e) NULL)
  if (!identical(result$schema, "simulation-canonical-hashes-v1") || !identical(as.integer(result$fan_in), fan_in) ||
      length(result$fields) != length(fields) || !identical(vapply(result$fields, `[[`, character(1), "field"), fields)) stop("Invalid canonical merge receipt", call. = FALSE)
  hashes <- stats::setNames(character(length(fields)), fields)
  for (field in fields) {
    receipt <- result$fields[[match(field, fields)]]
    if (length(receipt$rows) != 1L || !identical(as.double(receipt$rows), as.double(totals[[field]])) ||
        !is.character(receipt$sha256) || length(receipt$sha256) != 1L || !grepl("^[0-9a-f]{64}$", receipt$sha256)) stop("Canonical merge hash/coverage receipt mismatch", call. = FALSE)
    hashes[[field]] <- receipt$sha256
  }
  hashes
}

simulation_trace_validate <- function(store) {
  manifest <- simulation_trace_manifest(store)
  firsts <- seq.int(1L, manifest$count, by = manifest$chunk_size)
  paths <- sprintf("chunk-%06d", seq_along(firsts))
  if (!setequal(list.files(store$run_dir, pattern = "^chunk-"), paths)) stop("Simulation trace chunk inventory mismatch", call. = FALSE)
  for (index in seq_along(firsts)) simulation_stream_validate_chunk(file.path(store$run_dir, paths[[index]]),
    seq.int(firsts[[index]], min(manifest$count, firsts[[index]] + manifest$chunk_size - 1L)), manifest$fingerprint,
    manifest$auxiliary_fields, decode = TRUE, expected_schema = manifest$schema,
    expected_statistics_codec = manifest$statistics_codec)
  invisible(TRUE)
}

simulation_repository_identity <- function(root = ".") {
  paths <- sort(c(list.files(file.path(root, "R"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
    file.path(root, c("scripts/build_nations_league_outcomes.R", "scripts/build_uefa_champions_league_outcomes.R", "scripts/hash_simulation_canonical.py"))), method = "radix")
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
  }, fields = "mean_records")
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
