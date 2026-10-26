library(testthat)
source("../../R/common/simulation_execution.R")

trace_storage_reducer <- function() list(init = function() 0L,
  update = function(a, value, id) a + 1L, merge = function(a, b) a + b)
trace_storage_run <- function(path, count = 7L, workers = 1L, chunk_size = 3L, ...) {
  simulation_execute_stream(count, function(i) list(
    table = if (i == 1L) data.frame(x = integer()) else data.frame(x = i),
    optional = NULL,
    mean_records = data.frame(key = c("a", "b"), value = c(c(1e16, 1, -1e16, 3, 4, 5, 6)[[i]], if (i == 3L) NA_real_ else i))),
    trace_storage_reducer(), "trace-storage-v2", path, workers = workers,
    chunk_size = chunk_size, auxiliary_fields = "mean_records", ...)
}
trace_storage_rehash <- function(path, name) {
  commit_path <- file.path(path, "commit.rds"); commit <- readRDS(commit_path)
  commit$hashes[[name]] <- simulation_file_hash(file.path(path, name))
  saveRDS(commit, commit_path, compress = FALSE)
}

test_that("partitioned traces reconstruct every logical field and exact ordered means", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  run <- trace_storage_run(path, workers = 2L)
  values <- simulation_trace_materialize(run)
  expect_identical(names(values[[1L]]), c("table", "optional", "mean_records"))
  expect_null(values[[1L]]$optional)
  expect_identical(values[[1L]]$table, data.frame(x = integer()))
  expect_identical(values[[7L]]$table, data.frame(x = 7L))
  expect_identical(vapply(values, function(x) x$mean_records$value[[1L]], numeric(1)), c(1e16, 1, -1e16, 3, 4, 5, 6))
  means <- simulation_exact_trace_means(run)
  expect_identical(get("a", means), mean(c(1e16, 1, -1e16, 3, 4, 5, 6)))
  expect_identical(get("b", means), NA_real_)
  expect_true(simulation_trace_validate(run))
  selected <- list()
  simulation_trace_visit(run, function(x, i) selected[[i]] <<- x, fields = c("mean_records", "table"))
  expect_identical(names(selected[[1L]]), c("mean_records", "table"))
  expect_identical(selected[[7L]]$mean_records, values[[7L]]$mean_records)
  expect_error(simulation_execute_stream(7L, identity, trace_storage_reducer(), "trace-storage-v2", path,
    resume = TRUE, chunk_size = 3L), "fingerprint")
})

test_that("an opted-in auxiliary field also preserves plain-list attributes and NULL", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  value <- structure(list(before = "a", auxiliary = NULL, after = 2L), note = "logical trace")
  run <- simulation_execute_stream(2L, function(i) value, trace_storage_reducer(), "list-attributes", path,
    workers = 1L, chunk_size = 1L, auxiliary_fields = "auxiliary")
  expect_identical(simulation_trace_materialize(run), rep(list(value), 2L))
  expect_true(simulation_trace_validate(run))
})

test_that("sidecar, schema, statistics and football bytes are hash bound on every read", {
  for (name in c("trace.bin.gz", "statistics.rds", "schema.rds", "auxiliary-0001.bin.gz")) {
    path <- tempfile(); run <- trace_storage_run(path)
    chunk <- file.path(path, "chunk-000001"); con <- file(file.path(chunk, name), "ab")
    writeBin(as.raw(1L), con); close(con)
    expect_error(simulation_exact_trace_means(run), "Corrupt", info = name)
    expect_error(simulation_trace_materialize(run), "Corrupt", info = name)
    unlink(path, recursive = TRUE)
  }
})

test_that("field selection skips unrelated decoding while complete validation checks all records", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  run <- trace_storage_run(path); chunk <- file.path(path, "chunk-000001")
  con <- gzfile(file.path(chunk, "trace.bin.gz"), "wb")
  serialize(list(iteration = 99L, value = "invalid coverage"), con); close(con)
  trace_storage_rehash(chunk, "trace.bin.gz")
  # A selected sidecar reader verifies all byte hashes, but only decodes its
  # requested stream. The complete validator remains the outcome boundary.
  expect_identical(get("a", simulation_exact_trace_means(run)), mean(c(1e16, 1, -1e16, 3, 4, 5, 6)))
  expect_error(simulation_trace_validate(run), "coverage")
})

test_that("sidecars reject missing, overlapping and trailing iteration records", {
  for (kind in c("missing", "overlap", "extra")) {
    path <- tempfile(); run <- trace_storage_run(path); chunk <- file.path(path, "chunk-000001")
    values <- simulation_trace_materialize(run)
    ids <- switch(kind, missing = 1:2, overlap = c(1L, 1L, 3L), extra = 1:4)
    con <- gzfile(file.path(chunk, "auxiliary-0001.bin.gz"), "wb")
    for (id in ids) serialize(list(iteration = id, value = values[[id]]$mean_records), con)
    close(con); trace_storage_rehash(chunk, "auxiliary-0001.bin.gz")
    expect_error(simulation_exact_trace_means(run), "Corrupt|coverage|Unexpected", info = kind)
    expect_error(simulation_trace_validate(run), "Corrupt|coverage|Unexpected", info = kind)
    unlink(path, recursive = TRUE)
  }
})

test_that("chunk schemas and strict payload inventories cannot silently change", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  run <- trace_storage_run(path); chunk <- file.path(path, "chunk-000001")
  schema_path <- file.path(chunk, "schema.rds"); original <- readRDS(schema_path)
  changed <- original; changed$ids <- c(1L, 1L, 3L)
  saveRDS(changed, schema_path, compress = FALSE); trace_storage_rehash(chunk, "schema.rds")
  expect_error(simulation_trace_materialize(run), "schema identity/coverage")
  changed <- original; changed$frames$table[[1L]] <- data.frame(unexpected = 1L)
  saveRDS(changed, schema_path, compress = FALSE); trace_storage_rehash(chunk, "schema.rds")
  expect_error(simulation_trace_validate(run), "schema/row mismatch")
  saveRDS(original, schema_path, compress = FALSE); trace_storage_rehash(chunk, "schema.rds")
  writeLines("orphan", file.path(chunk, "unexpected.bin"))
  expect_error(simulation_trace_validate(run), "inventory")
  unlink(file.path(chunk, "unexpected.bin"))
  unlink(file.path(chunk, "auxiliary-0001.bin.gz"))
  expect_error(simulation_trace_validate(run), "inventory")
})

test_that("partitioned unfinished chunks resume across workers and retain logical ordering", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  calls <- function(i) {
    if (i == 5L) stop("injected sidecar interruption")
    list(table = data.frame(x = i), mean_records = data.frame(key = "a", value = i))
  }
  expect_error(simulation_execute_stream(7L, calls, trace_storage_reducer(), "resume-v2", path,
    workers = 1L, chunk_size = 2L, auxiliary_fields = "mean_records"), "interruption")
  run <- simulation_execute_stream(7L, function(i) {
    if (i < 5L) stop("duplicate committed iteration")
    list(table = data.frame(x = i), mean_records = data.frame(key = "a", value = i))
  }, trace_storage_reducer(), "resume-v2", path, workers = 2L,
    chunk_size = 2L, auxiliary_fields = "mean_records", resume = TRUE)
  expect_identical(vapply(simulation_trace_materialize(run), function(x) x$table$x, integer(1)), 1:7)
  expect_identical(get("a", simulation_exact_trace_means(run)), mean(1:7))
  expect_true(simulation_trace_validate(run))
})

test_that("default traces retain generic scalar, data frame and nested list values", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  values <- list(NA_real_, NULL, list(unnamed = list(1L, NULL), frame = data.frame(x = 1L)),
    data.frame(x = c("a", "é")))
  run <- simulation_execute_stream(length(values), function(i) values[[i]],
    trace_storage_reducer(), "generic-traces", path, workers = 2L, chunk_size = 2L)
  expect_identical(simulation_trace_materialize(run), values)
  expect_true(simulation_trace_validate(run))
})

test_that("legacy v1 committed stores remain readable without resumable format ambiguity", {
  path <- tempfile(); dir.create(path); on.exit(unlink(path, recursive = TRUE))
  manifest <- list(schema = "simulation-stream-v1", count = 3L, chunk_size = 2L,
    fingerprint = "legacy-committed-fingerprint")
  saveRDS(manifest, file.path(path, "manifest.rds"))
  for (index in 1:2) {
    ids <- if (index == 1L) 1:2 else 3L
    chunk <- file.path(path, sprintf("chunk-%06d", index)); dir.create(chunk)
    con <- gzfile(file.path(chunk, "trace.bin.gz"), "wb")
    for (id in ids) serialize(list(iteration = id, value = list(table = data.frame(x = id))), con)
    close(con); saveRDS(length(ids), file.path(chunk, "statistics.rds"))
    files <- c("trace.bin.gz", "statistics.rds")
    hashes <- stats::setNames(vapply(files, function(name) simulation_file_hash(file.path(chunk, name)), character(1)), files)
    saveRDS(list(fingerprint = manifest$fingerprint, ids = ids, hashes = hashes), file.path(chunk, "commit.rds"))
  }
  run <- structure(list(run_dir = path, manifest = manifest, complete = TRUE), class = "simulation_trace_store")
  expect_identical(vapply(simulation_trace_materialize(run), function(x) x$table$x, integer(1)), 1:3)
  expect_true(simulation_trace_validate(run))
  expect_error(simulation_execute_stream(3L, identity, trace_storage_reducer(), "legacy", path,
    chunk_size = 2L, resume = TRUE), "fingerprint")
})

test_that("a v2 manifest rejects downgraded or unknown chunk formats without auxiliary fields", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  run <- simulation_execute_stream(3L, function(i) list(table = data.frame(x = i)),
    trace_storage_reducer(), "format-bound", path, workers = 1L, chunk_size = 2L)
  chunk <- file.path(path, "chunk-000001"); marker <- file.path(chunk, "commit.rds")
  original <- readRDS(marker)
  unknown <- original; unknown$schema <- "simulation-chunk-v99"
  saveRDS(unknown, marker, compress = FALSE)
  expect_error(simulation_trace_validate(run), "schema/version")
  expect_error(simulation_trace_materialize(run), "schema/version")
  downgraded <- original; downgraded$schema <- NULL; downgraded$auxiliary_fields <- NULL
  downgraded$hashes <- downgraded$hashes[c("trace.bin.gz", "statistics.rds")]
  saveRDS(downgraded, marker, compress = FALSE); unlink(file.path(chunk, "schema.rds"))
  expect_error(simulation_trace_validate(run), "schema/version")
  expect_error(simulation_trace_materialize(run), "schema/version")
  expect_error(simulation_trace_visit(run, function(x, i) NULL, fields = "table"), "schema/version")
  expect_error(simulation_trace_schema_visit(run, function(schema) NULL), "schema/version")
  expect_error(simulation_trace_nl_hashes(run, "table", identity, as.character), "schema/version")
  expect_error(simulation_execute_stream(3L, function(i) stop("must not rerun"),
    trace_storage_reducer(), "format-bound", path, workers = 2L, chunk_size = 2L, resume = TRUE), "schema/version")
})

test_that("schema exemplars preserve empty and changing-column canonical unions", {
  source("../../R/competition/uefa_nations_league_rules.R", local = TRUE)
  source("../../R/competition/uefa_nations_league_simulation.R", local = TRUE)
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  frames <- list(data.frame(z = character()), data.frame(z = "a\x1fz", a = "x\ny"),
    data.frame(z = "é", a = NA_character_), data.frame(z = "a", extra = "<NA>"))
  run <- simulation_execute_stream(4L, function(i) list(table = frames[[i]], mean_records = data.frame(key = "x", value = i)),
    trace_storage_reducer(), "schema-union-v2", path, workers = 2L, chunk_size = 3L,
    auxiliary_fields = "mean_records")
  transform_calls <- 0L
  transformed <- function(frame) { transform_calls <<- transform_calls + 1L; frame$constant <- rep("stable", nrow(frame)); frame }
  actual <- simulation_trace_nl_hashes(run, "table", transformed, uefa_nl_sim_hash_column)
  union <- unique(unlist(lapply(frames, names)))
  expanded <- lapply(frames, function(frame) {
    for (field in setdiff(union, names(frame))) frame[[field]] <- rep(NA, nrow(frame))
    frame[, union, drop = FALSE]
  })
  expected <- do.call(rbind, expanded); expected$constant <- rep("stable", nrow(expected))
  expect_identical(unname(actual[[1L]]), uefa_nl_sim_hash_data(expected))
  expect_identical(transform_calls, 7L) # three schema variants and one row pass
  expect_true(simulation_trace_validate(run))
})

test_that("writers and merges decode zero streams; selected means and hashing decode once", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  scope <- environment(simulation_stream_trace_connections)
  original <- get("simulation_stream_trace_connections", scope)
  opened <- list()
  assign("simulation_stream_trace_connections", function(chunk, fields = NULL) {
    connections <- original(chunk, fields)
    opened[[length(opened) + 1L]] <<- names(connections)
    connections
  }, scope)
  on.exit(assign("simulation_stream_trace_connections", original, scope), add = TRUE)
  run <- trace_storage_run(path)
  expect_length(opened, 0L) # commit verification and statistics merge only hash
  simulation_exact_trace_means(run)
  expect_identical(opened, rep(list("mean_records"), 3L))
  opened <- list()
  simulation_trace_nl_hashes(run, "table", identity, function(x) as.character(x))
  expect_identical(opened, rep(list(".main"), 3L))
  opened <- list()
  simulation_trace_validate(run)
  expect_identical(opened, rep(list(c(".main", "mean_records")), 3L))
})

test_that("a reducer finalizes each completed chunk once before persistence and resume", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  finalized_sizes <- integer()
  reducer <- list(
    init = function() list(total = 0L, pending = integer(), chunk_sizes = integer()),
    update = function(a, value, id) { a$pending <- c(a$pending, id); a },
    finalize = function(a) {
      finalized_sizes <<- c(finalized_sizes, length(a$pending))
      list(total = sum(a$pending), pending = integer(), chunk_sizes = length(a$pending))
    },
    merge = function(a, b) {
      stopifnot(!length(b$pending))
      list(total = a$total + b$total, pending = integer(), chunk_sizes = c(a$chunk_sizes, b$chunk_sizes))
    })
  run <- simulation_execute_stream(7L, identity, reducer, "chunk-finalizer", path,
    workers = 1L, chunk_size = 3L)
  expect_identical(finalized_sizes, c(3L, 3L, 1L))
  expect_identical(run$statistics, list(total = 28L, pending = integer(), chunk_sizes = c(3L, 3L, 1L)))
  for (index in 1:3) {
    stored <- readRDS(file.path(path, sprintf("chunk-%06d", index), "statistics.rds"))
    expect_length(stored$pending, 0L)
    expect_identical(stored$chunk_sizes, c(3L, 3L, 1L)[[index]])
  }
  expect_true(simulation_trace_validate(run))
  reducer$finalize <- function(a) stop("committed statistics must not finalize again")
  resumed <- simulation_execute_stream(7L, function(i) stop("must not rerun"), reducer,
    "chunk-finalizer", path, workers = 2L, chunk_size = 3L, resume = TRUE)
  expect_identical(resumed, run)
  expect_true(simulation_trace_validate(resumed))
})

test_that("compressed multipass hashing matches legacy rows across schemas and encodings", {
  source("../../R/competition/uefa_nations_league_rules.R", local = TRUE)
  source("../../R/competition/uefa_nations_league_simulation.R", local = TRUE)
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  latin <- iconv("é", to = "latin1"); Encoding(latin) <- "latin1"
  labels <- c("", "a", "aa", "a!", "a\x1fz", "é", "𝛼", "x\ny", "x\ry", "\t", "\x1e", latin)
  frames <- lapply(seq_len(17L), function(i) {
    rows <- if (i %% 5L == 0L) 0L else if (i %% 3L == 0L) 3L else 1L
    frame <- data.frame(z = rep(labels[[1L + i %% length(labels)]], rows), a = rep(if (i %% 2L) "prefix" else "prefix-more", rows), stringsAsFactors = FALSE)
    if (i %% 4L == 0L) frame$extra <- rep(NA_character_, rows)
    frame
  })
  values <- lapply(seq_along(frames), function(i) list(changing = frames[[i]],
    empty = data.frame(a = character(), z = character()), zero = data.frame(row.names = seq_len(i %% 3L))))
  run <- simulation_execute_stream(length(values), function(i) values[[i]], trace_storage_reducer(),
    "compressed-canonical-multipass", path, workers = 2L, chunk_size = 3L)
  actual <- simulation_trace_nl_hashes(run, c("changing", "empty", "zero"), identity,
    uefa_nl_sim_hash_column, run_size = 2L, fan_in = 2L)
  fields <- unique(unlist(lapply(frames, names)))
  expanded <- lapply(frames, function(frame) {
    for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame))
    frame[, fields, drop = FALSE]
  })
  expect_identical(actual[["changing"]], uefa_nl_sim_hash_data(do.call(rbind, expanded)))
  expect_identical(actual[["empty"]], uefa_nl_sim_hash_data(values[[1L]]$empty))
  zeros <- data.frame(row.names = seq_len(sum(vapply(values, function(x) nrow(x$zero), integer(1)))))
  expect_identical(actual[["zero"]], uefa_nl_sim_hash_data(zeros))
  expect_length(list.files(path, pattern = "^simulation-canonical-"), 0L)
  expect_identical(simulation_trace_materialize(run), values)
})

test_that("canonical helper resolution survives cwd changes and its bytes bind run identity", {
  helper <- simulation_canonical_helper_path()
  expect_true(file.exists(helper))
  identity <- simulation_repository_identity(dirname(dirname(helper)))
  expect_identical(identity[["scripts/hash_simulation_canonical.py"]], simulation_file_hash(helper))
  previous <- getwd(); path <- tempfile(); dir.create(path)
  on.exit({ setwd(previous); unlink(path, recursive = TRUE) })
  setwd(path)
  expect_identical(simulation_canonical_helper_path(), helper)
})

test_that("canonical helper failures and invalid receipts fail closed and clean private runs", {
  path <- tempfile(); on.exit(unlink(path, recursive = TRUE))
  run <- simulation_execute_stream(3L, function(i) list(table = data.frame(x = i)),
    trace_storage_reducer(), "canonical-helper-errors", path, workers = 1L)
  helper <- tempfile(fileext = ".py"); on.exit(unlink(helper), add = TRUE)
  scope <- environment(simulation_trace_nl_hashes); original <- get("simulation_canonical_helper_path", scope)
  assign("simulation_canonical_helper_path", function() helper, scope)
  on.exit(assign("simulation_canonical_helper_path", original, scope), add = TRUE)
  writeLines("raise SystemExit('injected canonical helper failure')", helper)
  expect_error(simulation_trace_nl_hashes(run, "table", identity, as.character), "merge failed:.*injected")
  writeLines(c("import argparse,json", "p=argparse.ArgumentParser();p.add_argument('--manifest');p.add_argument('--output');a=p.parse_args()",
    "m=json.load(open(a.manifest));f=m['fields'][0]",
    "json.dump({'schema':'simulation-canonical-hashes-v1','fan_in':m['fan_in'],'fields':[{'field':f['field'],'rows':f['rows']+1,'sha256':'0'*64}]},open(a.output,'w'))"), helper)
  expect_error(simulation_trace_nl_hashes(run, "table", identity, as.character), "hash/coverage receipt")
  writeLines(c("import argparse", "p=argparse.ArgumentParser();p.add_argument('--manifest');p.add_argument('--output');a=p.parse_args()",
    "open(a.output,'w').write('invalid json')"), helper)
  expect_error(simulation_trace_nl_hashes(run, "table", identity, as.character), "Invalid canonical merge receipt")
  expect_length(list.files(path, pattern = "^simulation-canonical-"), 0L)
  expect_true(simulation_trace_validate(run))
})
