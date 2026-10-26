# Prepare the simulation's existing canonical encodings in its private runtime.
# Public rule/hash entry points are unchanged. Unsupported schemas/classes keep
# the previous private implementation, including its validation/error behavior.
uefa_nl_sim_prepare_canonical <- function(runtime) {
  if (isTRUE(runtime$uefa_nl_canonical_prepared)) return(runtime)
  scope <- environment()
  parent.env(scope) <- runtime
  original_row <- runtime$uefa_nl_rules_row_sha256
  original_table <- runtime$uefa_nl_rules_canonical_sha256
  original_finalize <- runtime$uefa_nl_rank_finalize
  original_bind <- runtime$uefa_nl_sim_bind_rows
  if (!all(vapply(list(original_row, original_table, original_finalize), is.function, logical(1)))) return(runtime)
  previous_scope <- environment(original_table)
  has_phase13 <- if (exists("has_phase13", envir = previous_scope, inherits = FALSE)) {
    get("has_phase13", envir = previous_scope, inherits = FALSE)
  } else exists("phase13_canonical_sha256", envir = runtime, mode = "function", inherits = TRUE)
  if (!is.logical(has_phase13) || length(has_phase13) != 1L || is.na(has_phase13)) return(runtime)

  normalize_column <- function(column) {
    # Restrict vector formatting to standard classes. Arbitrary S3/S4 methods,
    # matrices, list columns and POSIXlt retain scalar canonical dispatch.
    if (isS4(column) || !is.null(dim(column))) return(NULL)
    classes <- class(column)
    if (identical(classes, "Date")) {
      values <- format(column, "%Y-%m-%d")
    } else if (identical(classes, c("POSIXct", "POSIXt"))) {
      values <- format(column, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (identical(classes, "factor") || identical(classes, c("ordered", "factor"))) {
      values <- as.character(column)
    } else if (is.object(column)) {
      return(NULL)
    } else if (is.logical(column)) {
      values <- ifelse(is.na(column), "", ifelse(column, "true", "false"))
    } else if (is.character(column) || is.integer(column) || is.double(column)) {
      values <- as.character(column)
    } else return(NULL)
    values[is.na(column)] <- ""
    unname(values)
  }
  supported_frame <- function(data) {
    is.data.frame(data) && identical(class(data), "data.frame") && ncol(data) > 0L &&
      !is.null(names(data)) && !anyNA(names(data)) && !anyDuplicated(names(data)) && all(nzchar(names(data)))
  }
  normalize_columns <- function(columns, count) {
    values <- lapply(columns, normalize_column)
    if (any(vapply(values, is.null, logical(1))) || any(lengths(values) != count)) return(NULL)
    values
  }
  join_rows <- function(columns, count, separator) {
    if (!count) return(character())
    do.call(paste, c(columns, list(sep = separator)))
  }
  hash_rows <- function(columns, count) {
    vapply(join_rows(columns, count, "|"), digest::digest, character(1),
      algo = "sha256", serialize = FALSE, USE.NAMES = FALSE)
  }
  hash_table <- function(columns, count, key) {
    if (!has_phase13) columns <- columns[sort(names(columns))]
    ordering <- if (count) do.call(order, c(columns[key], list(na.last = TRUE, method = "radix"))) else integer()
    rows <- join_rows(columns, count, "\x1f")
    digest::digest(paste(c(paste(names(columns), collapse = "\x1f"), rows[ordering]), collapse = "\x1e"),
      algo = "sha256", serialize = FALSE)
  }
  runtime$uefa_nl_rules_row_sha256 <- function(data, hash_col = "row_sha256") {
    if (!supported_frame(data) || !is.character(hash_col) || length(hash_col) != 1L || is.na(hash_col)) return(original_row(data, hash_col))
    fields <- setdiff(names(data), hash_col)
    if (!length(fields)) return(original_row(data, hash_col))
    columns <- normalize_columns(unclass(data)[fields], nrow(data))
    if (is.null(columns)) return(original_row(data, hash_col))
    hash_rows(columns, nrow(data))
  }
  runtime$uefa_nl_rules_canonical_sha256 <- function(data, key = NULL) {
    if (!supported_frame(data)) return(original_table(data, key))
    if (is.null(key)) key <- names(data)[[1L]]
    if (!is.character(key) || !length(key) || anyNA(key) || any(!key %in% names(data))) return(original_table(data, key))
    columns <- normalize_columns(unclass(data), nrow(data))
    if (is.null(columns)) return(original_table(data, key))
    hash_table(columns, nrow(data), key)
  }
  runtime$uefa_nl_rank_finalize <- function(data, rules) {
    if (!supported_frame(data)) return(original_finalize(data, rules))
    count <- nrow(data)
    columns <- unclass(data)
    columns$row_sha256 <- NULL
    columns$table_sha256 <- NULL
    if (!length(columns)) return(original_finalize(data, rules))
    canonical <- normalize_columns(columns, count)
    if (is.null(canonical)) return(original_finalize(data, rules))
    row_hashes <- hash_rows(canonical, count)
    columns$row_sha256 <- row_hashes
    # Hash strings are already canonical scalars. Reuse every original
    # formatted column and append the newly computed row hash exactly where
    # the reference finalizer appends it before computing the table hash.
    canonical$row_sha256 <- row_hashes
    key <- intersect(c("ranking_scope", "league", "group_id", "interim_rank", "computed_rank", "team_id"), names(columns))
    if (!length(key)) key <- names(columns)[[1L]]
    columns$table_sha256 <- rep(hash_table(canonical, count, key), count)
    output_attributes <- attributes(data)
    output_attributes$names <- names(columns)
    output_attributes$row.names <- if (count) c(NA_integer_, -as.integer(count)) else integer()
    attributes(columns) <- output_attributes
    columns
  }
  bind_controls <- unique(c(names(formals(base::rbind)), names(formals(base::rbind.data.frame))))
  if (is.function(original_bind)) runtime$uefa_nl_sim_bind_rows <- function(frames) {
    if (!is.list(frames) || is.object(frames)) return(original_bind(frames))
    frame_names <- names(frames)
    if (!is.null(frame_names)) {
      # Ordinary group/stage names only label discarded intermediate rownames.
      # Control formals and their ambiguous prefixes retain base dispatch.
      if (anyNA(frame_names) || any(!grepl("^[A-Za-z0-9_.:-]*$", frame_names, useBytes = TRUE))) return(original_bind(frames))
      nonempty <- frame_names[nzchar(frame_names)]
      if (any(vapply(nonempty, function(name) any(startsWith(bind_controls, name)), logical(1)))) return(original_bind(frames))
    }
    frames <- frames[vapply(frames, function(frame) is.data.frame(frame) && nrow(frame), logical(1))]
    if (!length(frames)) return(structure(list(), names = character(), class = "data.frame", row.names = integer()))
    fields <- names(frames[[1L]])
    if (!length(fields) || anyNA(fields) || any(!nzchar(fields)) || anyDuplicated(fields)) return(original_bind(frames))
    types <- vapply(frames[[1L]], typeof, character(1))
    primitive <- c("logical", "integer", "double", "complex", "character", "raw")
    supported <- function(frame) {
      identical(class(frame), "data.frame") && identical(names(frame), fields) &&
        setequal(names(attributes(frame)), c("names", "row.names", "class")) &&
        identical(vapply(frame, typeof, character(1)), types) && all(types %in% primitive) &&
        all(vapply(frame, function(column) is.null(attributes(column)) && length(column) == nrow(frame), logical(1)))
    }
    if (!all(vapply(frames, supported, logical(1)))) return(original_bind(frames))
    count <- sum(vapply(frames, nrow, integer(1)))
    if (count > .Machine$integer.max) return(original_bind(frames))
    # Names must not reach c(): that would add column-vector name attributes.
    frames <- unname(frames)
    columns <- lapply(seq_along(fields), function(index) {
      do.call(c, lapply(frames, function(frame) .subset2(frame, index)))
    })
    structure(columns, names = fields, class = "data.frame", row.names = c(NA_integer_, -as.integer(count)))
  }
  runtime$uefa_nl_canonical_prepared <- TRUE
  runtime
}
