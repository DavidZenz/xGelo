#' Phase 18 canonical hash primitives.
#'
#' The phase18-canonical-v2 contract uses domain-separated, length-prefixed
#' frames. Character values are hashed as their exact UTF-8 bytes: no Unicode
#' normalization is performed, so byte-distinct normalization forms remain
#' distinct. Numeric values use locale-independent binary-derived text.

phase18_canonical_encoding_v2 <- function() "phase18-canonical-v2"

phase18_v2_require_text <- function(value, name) {
  if (length(value) != 1L || is.na(value[[1L]]) || !nzchar(as.character(value[[1L]]))) {
    stop("Phase 18 ", name, " must be one non-empty value", call. = FALSE)
  }
  enc2utf8(as.character(value[[1L]]))
}

phase18_v2_raw <- function(value) {
  charToRaw(enc2utf8(as.character(value)))
}

phase18_v2_uint32 <- function(value) {
  value <- as.double(value)
  if (length(value) != 1L || is.na(value) || value < 0 || value > .Machine$integer.max || value != floor(value)) {
    stop("Phase 18 canonical frame length is outside the supported range", call. = FALSE)
  }
  writeBin(as.integer(value), raw(), size = 4L, endian = "big")
}

phase18_v2_frame <- function(bytes) {
  if (!is.raw(bytes)) stop("Phase 18 canonical frames require raw bytes", call. = FALSE)
  c(phase18_v2_uint32(length(bytes)), bytes)
}

phase18_v2_text_frame <- function(value) {
  phase18_v2_frame(phase18_v2_raw(value))
}

phase18_v2_join <- function(parts) {
  if (!length(parts)) return(raw())
  if (any(!vapply(parts, is.raw, logical(1)))) {
    stop("Phase 18 canonical payload parts must be raw bytes", call. = FALSE)
  }
  do.call(c, parts)
}

phase18_v2_hex <- function(bytes) {
  paste(sprintf("%02x", as.integer(bytes)), collapse = "")
}

phase18_v2_hash <- function(bytes) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 18 canonical SHA-256 contracts", call. = FALSE)
  }
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase18_v2_type_tag <- function(value) {
  if (inherits(value, "Date")) return("date")
  if (inherits(value, "POSIXt")) return("datetime")
  if (is.ordered(value)) return("ordered-factor")
  if (is.factor(value)) return("factor")
  if (is.character(value)) return("character")
  if (is.logical(value)) return("logical")
  if (is.integer(value)) return("integer")
  if (is.double(value)) return("double")
  if (is.complex(value)) return("complex")
  if (is.raw(value)) return("raw")
  stop("Phase 18 canonical hashing does not support type: ", paste(class(value), collapse = "/"), call. = FALSE)
}

phase18_v2_double_text <- function(value) {
  value <- as.double(value[[1L]])
  if (is.nan(value)) return("nan")
  if (is.infinite(value)) return(if (value > 0) "+inf" else "-inf")
  if (value == 0) return("0000000000000000")
  phase18_v2_hex(writeBin(value, raw(), size = 8L, endian = "big"))
}

phase18_v2_scalar_text <- function(value, type_tag) {
  if (identical(type_tag, "character")) return(enc2utf8(value[[1L]]))
  if (identical(type_tag, "logical")) return(if (isTRUE(value[[1L]])) "true" else "false")
  if (identical(type_tag, "integer")) {
    return(phase18_v2_hex(writeBin(as.integer(value[[1L]]), raw(), size = 4L, endian = "big")))
  }
  if (identical(type_tag, "double")) return(phase18_v2_double_text(value))
  if (identical(type_tag, "complex")) {
    scalar <- value[[1L]]
    return(paste0(
      phase18_v2_double_text(Re(scalar)),
      phase18_v2_double_text(Im(scalar))
    ))
  }
  if (identical(type_tag, "date")) return(format(value[[1L]], "%Y-%m-%d"))
  if (identical(type_tag, "datetime")) return(phase18_v2_double_text(as.numeric(value[[1L]])))
  if (type_tag %in% c("factor", "ordered-factor")) return(enc2utf8(as.character(value[[1L]])))
  if (identical(type_tag, "raw")) return(phase18_v2_hex(value[[1L]]))
  stop("Phase 18 canonical hashing received an unsupported type tag: ", type_tag, call. = FALSE)
}

phase18_v2_scalar_bytes <- function(value, field_name, type_tag) {
  field_name <- phase18_v2_require_text(field_name, "field_name")
  type_tag <- phase18_v2_require_text(type_tag, "type_tag")
  if (length(value) != 1L) {
    stop("Phase 18 canonical scalar hashing requires exactly one value", call. = FALSE)
  }
  inferred <- phase18_v2_type_tag(value)
  if (!identical(type_tag, inferred)) {
    stop("Phase 18 canonical type tag mismatch for ", field_name, ": expected ", inferred, call. = FALSE)
  }
  missing <- is.na(value[[1L]])
  payload <- if (missing) raw() else phase18_v2_raw(phase18_v2_scalar_text(value, type_tag))
  phase18_v2_join(list(
    phase18_v2_text_frame(phase18_canonical_encoding_v2()),
    phase18_v2_text_frame("scalar"),
    phase18_v2_text_frame(field_name),
    phase18_v2_text_frame(type_tag),
    phase18_v2_text_frame(if (missing) "missing" else "present"),
    phase18_v2_frame(payload)
  ))
}

#' Hash one explicitly named and typed scalar.
phase18_hash_scalar_v2 <- function(value, field_name, type_tag) {
  phase18_v2_hash(phase18_v2_scalar_bytes(value, field_name, type_tag))
}

phase18_v2_sequence_values <- function(values) {
  if (is.list(values) && !is.data.frame(values)) return(values)
  lapply(seq_along(values), function(index) values[index])
}

phase18_v2_sequence_bytes <- function(values, domain, names, types) {
  domain <- phase18_v2_require_text(domain, "sequence domain")
  values <- phase18_v2_sequence_values(values)
  names <- as.character(names)
  types <- as.character(types)
  if (length(values) != length(names) || length(values) != length(types)) {
    stop("Phase 18 canonical sequence values, names, and types must have equal lengths", call. = FALSE)
  }
  if (length(names) && (anyNA(names) || any(!nzchar(names)) || anyNA(types) || any(!nzchar(types)))) {
    stop("Phase 18 canonical sequence names and types must be explicit", call. = FALSE)
  }
  elements <- lapply(seq_along(values), function(index) {
    phase18_v2_frame(phase18_v2_scalar_bytes(values[[index]], names[[index]], types[[index]]))
  })
  phase18_v2_join(c(
    list(
      phase18_v2_text_frame(phase18_canonical_encoding_v2()),
      phase18_v2_text_frame("sequence"),
      phase18_v2_text_frame(domain),
      phase18_v2_text_frame(as.character(length(values)))
    ),
    elements
  ))
}

#' Hash an ordered sequence with explicit names, types, and domain.
phase18_hash_sequence_v2 <- function(values, domain, names, types) {
  phase18_v2_hash(phase18_v2_sequence_bytes(values, domain, names, types))
}

phase18_v2_row_layout <- function(data, exclude) {
  if (!is.data.frame(data)) stop("Phase 18 canonical row hashing requires a data frame", call. = FALSE)
  exclude <- unique(as.character(exclude))
  unknown <- setdiff(exclude, names(data))
  if (length(unknown)) {
    stop("Phase 18 canonical row excludes unknown columns: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  fields <- setdiff(names(data), exclude)
  if (!length(fields)) stop("Phase 18 canonical row hashing has no included fields", call. = FALSE)
  list(fields = fields, types = vapply(data[fields], phase18_v2_type_tag, character(1)))
}

phase18_v2_row_bytes <- function(data, row_index, exclude, schema_tag) {
  schema_tag <- phase18_v2_require_text(schema_tag, "row schema_tag")
  layout <- phase18_v2_row_layout(data, exclude)
  values <- lapply(data[layout$fields], function(column) column[row_index])
  fields <- lapply(seq_along(values), function(index) {
    phase18_v2_frame(phase18_v2_scalar_bytes(
      values[[index]],
      layout$fields[[index]],
      layout$types[[index]]
    ))
  })
  phase18_v2_join(c(
    list(
      phase18_v2_text_frame(phase18_canonical_encoding_v2()),
      phase18_v2_text_frame("row"),
      phase18_v2_text_frame(schema_tag),
      phase18_v2_text_frame(as.character(length(layout$fields)))
    ),
    fields
  ))
}

#' Hash every row using ordered field names, types, values, and schema metadata.
phase18_hash_row_v2 <- function(data, exclude = character(), schema_tag) {
  phase18_v2_require_text(schema_tag, "row schema_tag")
  phase18_v2_row_layout(data, exclude)
  vapply(seq_len(nrow(data)), function(index) {
    phase18_v2_hash(phase18_v2_row_bytes(data, index, exclude, schema_tag))
  }, character(1))
}

phase18_v2_key_bytes <- function(data, row_index, key, schema_tag) {
  key_values <- lapply(data[key], function(column) column[row_index])
  key_types <- vapply(data[key], phase18_v2_type_tag, character(1))
  phase18_v2_sequence_bytes(
    key_values,
    domain = paste0(schema_tag, ":table-key"),
    names = key,
    types = key_types
  )
}

#' Hash a duplicate-preserving table in deterministic key and row-byte order.
phase18_hash_table_v2 <- function(data, key, exclude = character(), schema_tag) {
  schema_tag <- phase18_v2_require_text(schema_tag, "table schema_tag")
  layout <- phase18_v2_row_layout(data, exclude)
  key <- unique(as.character(key))
  if (!length(key) || anyNA(key) || any(!nzchar(key))) {
    stop("Phase 18 canonical table hashing requires explicit stable keys", call. = FALSE)
  }
  missing_key <- setdiff(key, layout$fields)
  if (length(missing_key)) {
    stop("Phase 18 canonical table key is missing or excluded: ", paste(missing_key, collapse = ", "), call. = FALSE)
  }
  if (nrow(data) && any(vapply(data[key], anyNA, logical(1)))) {
    stop("Phase 18 canonical table keys must not be missing", call. = FALSE)
  }

  row_bytes <- lapply(seq_len(nrow(data)), function(index) {
    phase18_v2_row_bytes(data, index, exclude, schema_tag)
  })
  key_bytes <- lapply(seq_len(nrow(data)), function(index) {
    phase18_v2_key_bytes(data, index, key, schema_tag)
  })
  if (nrow(data)) {
    ordering <- order(
      vapply(key_bytes, phase18_v2_hex, character(1)),
      vapply(row_bytes, phase18_v2_hex, character(1)),
      method = "radix"
    )
    row_bytes <- row_bytes[ordering]
  }

  schema_fields <- phase18_v2_sequence_bytes(
    as.list(layout$types),
    domain = paste0(schema_tag, ":table-schema"),
    names = layout$fields,
    types = rep("character", length(layout$fields))
  )
  key_fields <- phase18_v2_sequence_bytes(
    as.list(vapply(data[key], phase18_v2_type_tag, character(1))),
    domain = paste0(schema_tag, ":table-key-schema"),
    names = key,
    types = rep("character", length(key))
  )
  payload <- phase18_v2_join(c(
    list(
      phase18_v2_text_frame(phase18_canonical_encoding_v2()),
      phase18_v2_text_frame("table"),
      phase18_v2_text_frame(schema_tag),
      phase18_v2_frame(schema_fields),
      phase18_v2_frame(key_fields),
      phase18_v2_text_frame(as.character(nrow(data)))
    ),
    lapply(row_bytes, phase18_v2_frame)
  ))
  phase18_v2_hash(payload)
}
