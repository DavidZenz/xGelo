library(testthat)

nl_canonical_test_setup <- function(has_phase13) {
  root <- Sys.getenv("XGELO_CANONICAL_PROJECT_ROOT", if (basename(getwd()) == "testthat") "../.." else ".")
  module <- new.env(parent = baseenv())
  if (has_phase13) sys.source(file.path(root, "R/competition/source_contracts.R"), envir = module)
  sys.source(file.path(root, "R/competition/uefa_nations_league_rules.R"), envir = module)
  candidate <- Sys.getenv("XGELO_NL_CANONICAL_CANDIDATE", file.path(root, "R/competition/uefa_nations_league_canonical.R"))
  sys.source(candidate, envir = module)
  make_runtime <- function() {
    runtime <- new.env(parent = module)
    for (name in ls(envir = module, pattern = "^uefa_nl_")) {
      value <- get(name, envir = module)
      if (is.function(value)) { environment(value) <- runtime; assign(name, value, envir = runtime) }
    }
    # This is the frozen simulation's private canonical implementation. Keep
    # an independent runtime so candidate installation cannot mutate reference
    # finalizer lookups through a shared environment.
    scalar <- if (has_phase13) module$phase13_source_canonical_scalar else module$uefa_nl_rules_scalar
    columns <- function(data) lapply(data, function(column) vapply(column, scalar, character(1)))
    row_text <- function(data, separator) {
      cols <- columns(data)
      if (!nrow(data)) return(character())
      do.call(paste, c(cols, list(sep = separator)))
    }
    runtime$uefa_nl_rules_row_sha256 <- function(data, hash_col = "row_sha256") {
      text <- row_text(data[, setdiff(names(data), hash_col), drop = FALSE], "|")
      vapply(text, digest::digest, character(1), algo = "sha256", serialize = FALSE, USE.NAMES = FALSE)
    }
    runtime$uefa_nl_rules_canonical_sha256 <- function(data, key = NULL) {
      if (is.null(key)) key <- names(data)[[1L]]
      if (!has_phase13) data <- data[, sort(names(data)), drop = FALSE]
      order_args <- columns(data[key])
      if (nrow(data)) data <- data[do.call(order, c(order_args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
      digest::digest(paste(c(paste(names(data), collapse = "\x1f"), row_text(data, "\x1f")), collapse = "\x1e"), algo = "sha256", serialize = FALSE)
    }
    runtime$uefa_nl_sim_bind_rows <- function(frames) {
      frames <- frames[vapply(frames, function(frame) is.data.frame(frame) && nrow(frame), logical(1))]
      if (!length(frames)) return(data.frame(stringsAsFactors = FALSE, check.names = FALSE))
      fields <- unique(unlist(lapply(frames, names), use.names = FALSE))
      frames <- lapply(frames, function(frame) {
        frame <- as.data.frame(frame, stringsAsFactors = FALSE, check.names = FALSE)
        for (field in setdiff(fields, names(frame))) frame[[field]] <- rep(NA, nrow(frame))
        frame[, fields, drop = FALSE]
      })
      output <- do.call(rbind, frames)
      row.names(output) <- NULL
      output
    }
    runtime
  }
  before <- make_runtime(); after <- module$uefa_nl_sim_prepare_canonical(make_runtime())
  list(before = before, after = after, factory = module$uefa_nl_sim_prepare_canonical)
}

nl_canonical_test_frame <- function() {
  data <- data.frame(team_id = c("é", "z", "a", "b", "c", "d"), ranking_scope = "group",
    league = c("A", "A", "B", "B", "D", "D"), computed_rank = c(2L, 1L, NA_integer_, 2L, 1L, 2L),
    logical = c(TRUE, FALSE, NA, TRUE, FALSE, NA), integer = c(0L, 1L, NA_integer_, -1L, 100000L, 2L),
    numeric = c(-0, NA_real_, NaN, Inf, -Inf, 1.2345678901234567),
    text = c("", NA_character_, "x|y", "a\x1fb", "a\x1eb", "x\ny"), stringsAsFactors = FALSE)
  data$date <- as.Date(c("2026-10-01", NA, "2026-10-03", "1970-01-01", "2030-12-31", "2026-10-25"))
  data$instant <- as.POSIXct(c("2026-10-01 11:23:45", NA, "2026-10-03 00:00:00", "1970-01-01 00:00:00", "2030-12-31 23:59:59", "2026-10-25 01:30:00"), tz = "Europe/Vienna")
  data$factor <- factor(c("é", "a", NA, "b", "a", "é"), levels = c("b", "a", "é"))
  data$ordered <- ordered(c("high", NA, "low", "high", "low", "high"), levels = c("low", "high"))
  row.names(data) <- paste0("source-row-", 6:1)
  attr(data, "tiebreak_trace") <- data.frame(criterion = c("points", "head_to_head_points"), decision = c("a > b", "b > c"))
  attr(data, "trace") <- attr(data, "tiebreak_trace")
  attr(data, "note") <- list(source = "unchanged", supported = TRUE)
  data
}

nl_canonical_test_compare <- function(setup, data) {
  expect_identical(setup$after$uefa_nl_rules_row_sha256(data), setup$before$uefa_nl_rules_row_sha256(data))
  expect_identical(setup$after$uefa_nl_rules_canonical_sha256(data, key = "team_id"), setup$before$uefa_nl_rules_canonical_sha256(data, key = "team_id"))
  expect_identical(setup$after$uefa_nl_rank_finalize(data, list()), setup$before$uefa_nl_rank_finalize(data, list()))
}

test_that("vector canonical normalization preserves both private hash contracts", {
  for (has_phase13 in c(TRUE, FALSE)) {
    setup <- nl_canonical_test_setup(has_phase13)
    data <- nl_canonical_test_frame()
    nl_canonical_test_compare(setup, data)
    nl_canonical_test_compare(setup, data[6:1, ])
    nl_canonical_test_compare(setup, data[1L, , drop = FALSE])
    nl_canonical_test_compare(setup, data[FALSE, , drop = FALSE])
    nl_canonical_test_compare(setup, data[, rev(names(data)), drop = FALSE])
    data$row_sha256 <- "obsolete-row"; data$table_sha256 <- "obsolete-table"
    nl_canonical_test_compare(setup, data)
  }
})

test_that("fused finalization formats each retained column once and preserves attributes", {
  for (has_phase13 in c(TRUE, FALSE)) {
    setup <- nl_canonical_test_setup(has_phase13)
    data <- nl_canonical_test_frame(); data$row_sha256 <- "old"; data$table_sha256 <- "old"
    scope <- environment(setup$after$uefa_nl_rank_finalize)
    original <- get("normalize_column", envir = scope, inherits = FALSE)
    calls <- 0L
    assign("normalize_column", function(column) { calls <<- calls + 1L; original(column) }, envir = scope)
    actual <- setup$after$uefa_nl_rank_finalize(data, list())
    expected <- setup$before$uefa_nl_rank_finalize(data, list())
    expect_identical(actual, expected)
    expect_identical(calls, as.integer(ncol(data) - 2L))
    expect_identical(attr(actual, "tiebreak_trace"), attr(data, "tiebreak_trace"))
    expect_identical(attr(actual, "trace"), attr(data, "trace"))
    expect_identical(attr(actual, "note"), attr(data, "note"))
    expect_identical(row.names(actual), as.character(seq_len(nrow(data))))
    expect_identical(setup$factory(setup$after), setup$after)
  }
})

test_that("numeric formatting, equal-key ordering and alternative hash columns remain exact", {
  old <- options(); on.exit(options(old), add = TRUE)
  for (has_phase13 in c(TRUE, FALSE)) for (scipen in c(-9L, 0L, 999L)) {
    options(scipen = scipen, digits = 7L)
    setup <- nl_canonical_test_setup(has_phase13)
    data <- data.frame(team_id = rep("same", 8L), value = c(0, -0, .Machine$double.xmin, .Machine$double.xmax, .Machine$double.eps, 1e-7, 1e12, 1.2345678901234567), marker = 8:1,
      alternative_hash = "exclude-this", stringsAsFactors = FALSE)
    nl_canonical_test_compare(setup, data)
    expect_identical(setup$after$uefa_nl_rules_row_sha256(data, "alternative_hash"), setup$before$uefa_nl_rules_row_sha256(data, "alternative_hash"))
  }
})

test_that("private bind concatenates identical primitive schemas with exact row order and types", {
  setup <- nl_canonical_test_setup(TRUE)
  frame <- data.frame(integer = c(1L, NA_integer_), numeric = c(1, NaN), character = c("é", NA_character_),
    logical = c(TRUE, NA), complex = c(1 + 2i, NA_complex_), stringsAsFactors = FALSE)
  frame$raw <- as.raw(c(0L, 255L))
  second <- frame[2:1, ]; row.names(second) <- c("named-first", "named-second")
  for (frames in list(list(frame), list(frame, second), list(NULL, frame, data.frame(extra = integer()), second),
                      list(data.frame(), NULL), list(frame[FALSE, ], second[FALSE, ]), list(1L, "ignored", second))) {
    actual <- setup$after$uefa_nl_sim_bind_rows(frames)
    expected <- setup$before$uefa_nl_sim_bind_rows(frames)
    expect_identical(actual, expected)
    expect_identical(lapply(actual, typeof), lapply(expected, typeof))
  }
})

test_that("private bind retains generic handling for named, attributed and differing schemas", {
  setup <- nl_canonical_test_setup(FALSE)
  frame <- data.frame(team_id = c("a", "b"), value = 1:2, stringsAsFactors = FALSE)
  factor_frame <- frame; factor_frame$team_id <- factor(frame$team_id)
  list_frame <- frame; list_frame$value <- I(list(1L, 2:3))
  date_frame <- frame; date_frame$value <- as.Date(c("2026-10-01", NA))
  attributed <- frame; attr(attributed, "trace") <- data.frame(rule = "points")
  attributed_column <- frame; attr(attributed_column$value, "note") <- "custom-vector"
  named_column <- frame; names(named_column$value) <- c("first", "second")
  subclass <- frame; class(subclass) <- c("private_frame", "data.frame")
  reordered <- frame[, 2:1]
  different_type <- frame; different_type$value <- as.numeric(different_type$value)
  different_fields <- data.frame(team_id = "c", extra = TRUE)
  cases <- list(list(first = frame, second = frame), setNames(list(frame, frame), c("", "second")),
    setNames(list(frame, frame), c("deparse.level", "second")),
    setNames(list(frame, frame), c("make.row.names", "second")),
    list(frame, reordered), list(frame, different_type), list(frame, different_fields),
    list(factor_frame, factor_frame), list(list_frame, list_frame), list(date_frame, date_frame),
    list(attributed, attributed), list(attributed_column, attributed_column), list(named_column, named_column),
    list(subclass, subclass), structure(list(frame, frame), class = "private_list"))
  result <- function(callback) tryCatch(list(value = callback()), error = function(error) list(error = conditionMessage(error)))
  for (frames in cases) expect_identical(result(function() setup$after$uefa_nl_sim_bind_rows(frames)), result(function() setup$before$uefa_nl_sim_bind_rows(frames)))
})

test_that("ordinary named stage/group lists use the exact primitive bind path", {
  setup <- nl_canonical_test_setup(TRUE)
  frame <- data.frame(team_id = c("a", "b"), value = 1:2, stringsAsFactors = FALSE)
  second <- frame[2:1, ]; row.names(second) <- c("original-b", "original-a")
  scope <- environment(setup$after$uefa_nl_sim_bind_rows)
  original <- get("original_bind", envir = scope, inherits = FALSE)
  fallbacks <- 0L
  assign("original_bind", function(frames) { fallbacks <<- fallbacks + 1L; original(frames) }, envir = scope)
  for (labels in list(c("A1", "A2"), c("league_a_final", "a_b_playoff"), c("A1", "A1"),
                      c("", "league_phase"), c("", ""), c("group:1", "group-2"))) {
    frames <- setNames(list(frame, second), labels)
    expected <- setup$before$uefa_nl_sim_bind_rows(frames)
    expect_identical(setup$after$uefa_nl_sim_bind_rows(frames), expected)
    expect_identical(fallbacks, 0L)
  }
  mixed <- setNames(list(frame[FALSE, ], NULL, frame, second), c("empty", "ignored", "A1", "A1"))
  expect_identical(setup$after$uefa_nl_sim_bind_rows(mixed), setup$before$uefa_nl_sim_bind_rows(mixed))
  expect_identical(fallbacks, 0L)
})

test_that("named-list controls, ambiguous names and missing names preserve generic results/errors", {
  setup <- nl_canonical_test_setup(TRUE)
  frame <- data.frame(team_id = c("a", "b"), value = 1:2, stringsAsFactors = FALSE)
  scope <- environment(setup$after$uefa_nl_sim_bind_rows)
  original <- get("original_bind", envir = scope, inherits = FALSE)
  fallbacks <- 0L
  assign("original_bind", function(frames) { fallbacks <<- fallbacks + 1L; original(frames) }, envir = scope)
  result <- function(callback) tryCatch(list(value = callback()), error = function(error) list(error = conditionMessage(error)))
  for (label in c("deparse.level", "make.row.names", "stringsAsFactors", "factor.exclude", "...", "deparse", "make.row", ".", NA_character_, "é", "row\nname")) {
    frames <- setNames(list(frame, frame), c(label, "A1"))
    previous <- fallbacks
    expect_identical(result(function() setup$after$uefa_nl_sim_bind_rows(frames)), result(function() setup$before$uefa_nl_sim_bind_rows(frames)))
    expect_identical(fallbacks, previous + 1L)
  }
})

test_that("unsupported/custom columns and schemas retain the previous implementation", {
  result <- function(callback) tryCatch(list(value = callback()), error = function(error) list(error = conditionMessage(error)))
  for (has_phase13 in c(TRUE, FALSE)) {
    setup <- nl_canonical_test_setup(has_phase13)
    base <- data.frame(team_id = c("a", "b", "c"), value = 1:3, stringsAsFactors = FALSE)
    variants <- list(
      transform(base, value = I(value)),
      transform(base, value = as.complex(value)),
      transform(base, value = structure(value, class = "custom_score")))
    list_column <- base; list_column$value <- I(list(1L, 2:3, NA_real_)); variants[[4L]] <- list_column
    matrix_column <- base; matrix_column$value <- I(matrix(1:6, nrow = 3L)); variants[[5L]] <- matrix_column
    posixlt <- base; posixlt$value <- as.POSIXlt(as.POSIXct(c("2026-10-01", "2026-10-02", NA), tz = "UTC")); variants[[6L]] <- posixlt
    subclass <- base; class(subclass) <- c("private_frame", "data.frame"); variants[[7L]] <- subclass
    for (data in variants) {
      expect_identical(result(function() setup$after$uefa_nl_rules_row_sha256(data)), result(function() setup$before$uefa_nl_rules_row_sha256(data)))
      expect_identical(result(function() setup$after$uefa_nl_rules_canonical_sha256(data, "team_id")), result(function() setup$before$uefa_nl_rules_canonical_sha256(data, "team_id")))
      expect_identical(result(function() setup$after$uefa_nl_rank_finalize(data, list())), result(function() setup$before$uefa_nl_rank_finalize(data, list())))
    }
  }
})
