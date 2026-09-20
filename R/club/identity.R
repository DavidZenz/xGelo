#' Phase 18 club-only identity registry and resolver.

phase18_club_identity_schema_version <- function() "phase18-club-identity-1"

phase18_club_registry_schemas <- function() {
  list(
    clubs = c(
      "schema_version", "club_id", "entity_kind", "canonical_name",
      "association_code", "valid_from_utc", "valid_to_utc", "club_status",
      "row_sha256"
    ),
    source_ids = c(
      "schema_version", "club_id", "source_system", "source_club_id",
      "valid_from_utc", "valid_to_utc", "review_state", "source_bundle_id",
      "row_sha256"
    ),
    aliases = c(
      "schema_version", "club_id", "source_system", "alias",
      "normalized_alias", "valid_from_utc", "valid_to_utc", "review_state",
      "reviewed_by", "reviewed_at_utc", "row_sha256"
    )
  )
}

phase18_club_abort <- function(reason, message, data = list()) {
  condition <- structure(
    c(list(message = as.character(message), call = NULL, reason = reason), data),
    class = c(reason, "phase18_club_identity_error", "error", "condition")
  )
  stop(condition)
}

phase18_normalize_club_name <- function(value) {
  value <- as.character(value)
  output <- rep(NA_character_, length(value))
  present <- !is.na(value)
  if (any(present)) {
    normalized <- iconv(trimws(value[present]), from = "", to = "ASCII//TRANSLIT", sub = "")
    normalized <- tolower(normalized)
    normalized <- gsub("[^a-z0-9]+", " ", normalized)
    output[present] <- trimws(gsub("[[:space:]]+", " ", normalized))
  }
  output
}

phase18_club_canonical_scalar <- function(value) {
  if (!length(value) || is.null(value) || is.na(value[[1L]])) return("<NA>")
  if (inherits(value, "POSIXt")) return(format(value[[1L]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (is.logical(value)) return(if (isTRUE(value[[1L]])) "TRUE" else "FALSE")
  enc2utf8(as.character(value[[1L]]))
}

phase18_club_row_sha256 <- function(data, hash_col = "row_sha256") {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 18 club identity SHA-256 contracts", call. = FALSE)
  }
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    values <- vapply(data[index, fields, drop = FALSE], phase18_club_canonical_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

phase18_hash_club_registry_rows <- function(registries) {
  schemas <- phase18_club_registry_schemas()
  for (name in names(schemas)) {
    if (is.null(registries[[name]]) || !is.data.frame(registries[[name]])) {
      phase18_club_abort("invalid_club_registry", paste0("Club registry table is missing: ", name))
    }
    if (!identical(names(registries[[name]]), schemas[[name]])) {
      phase18_club_abort("invalid_club_registry_schema", paste0("Club registry has wrong columns: ", name))
    }
    registries[[name]]$row_sha256 <- phase18_club_row_sha256(registries[[name]])
  }
  registries
}

phase18_club_sort_keys <- function() {
  list(
    clubs = c("club_id"),
    source_ids = c("source_system", "source_club_id", "valid_from_utc", "club_id", "row_sha256"),
    aliases = c("source_system", "normalized_alias", "valid_from_utc", "club_id", "row_sha256")
  )
}

phase18_club_canonical_table <- function(data, key) {
  if (nrow(data)) {
    args <- lapply(data[key], function(column) vapply(column, phase18_club_canonical_scalar, character(1)))
    data <- data[do.call(order, c(args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
    rownames(data) <- NULL
  }
  data
}

phase18_club_table_sha256 <- function(data, key) {
  data <- phase18_club_canonical_table(data, key)
  rows <- vapply(seq_len(nrow(data)), function(index) {
    paste(vapply(data[index, , drop = FALSE], phase18_club_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  digest::digest(
    paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"),
    algo = "sha256", serialize = FALSE
  )
}

phase18_club_registry_hash <- function(registries) {
  phase18_validate_club_registries(registries)
  keys <- phase18_club_sort_keys()
  hashes <- vapply(names(keys), function(name) {
    phase18_club_table_sha256(registries[[name]], keys[[name]])
  }, character(1))
  digest::digest(paste(names(hashes), hashes, sep = "=", collapse = "|"),
    algo = "sha256", serialize = FALSE)
}

phase18_club_parse_time <- function(value, field, allow_blank = FALSE) {
  value <- as.character(value)
  blank <- is.na(value) | !nzchar(value)
  if (any(blank) && !allow_blank) {
    phase18_club_abort("invalid_club_validity", paste0(field, " contains a missing timestamp"))
  }
  parsed <- rep(as.POSIXct(NA, tz = "UTC"), length(value))
  if (any(!blank)) {
    parsed[!blank] <- as.POSIXct(value[!blank], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (any(is.na(parsed[!blank]))) {
      phase18_club_abort("invalid_club_validity", paste0(field, " must contain UTC ISO-8601 timestamps"))
    }
  }
  parsed
}

phase18_club_require_exact_schema <- function(registries) {
  schemas <- phase18_club_registry_schemas()
  if (!is.list(registries) || !identical(sort(names(registries)), sort(names(schemas)))) {
    phase18_club_abort("invalid_club_registry_schema", "Club registries must contain exactly clubs, source_ids, and aliases")
  }
  for (name in names(schemas)) {
    if (!is.data.frame(registries[[name]]) || !identical(names(registries[[name]]), schemas[[name]])) {
      phase18_club_abort("invalid_club_registry_schema", paste0("Club registry has wrong columns: ", name))
    }
  }
  invisible(TRUE)
}

phase18_validate_nonoverlap <- function(data, group_fields, label) {
  if (nrow(data) < 2L) return(invisible(TRUE))
  group <- do.call(paste, c(lapply(data[group_fields], as.character), sep = "\x1f"))
  for (key in unique(group)) {
    rows <- data[group == key, , drop = FALSE]
    if (nrow(rows) < 2L) next
    starts <- phase18_club_parse_time(rows$valid_from_utc, "valid_from_utc")
    ends <- phase18_club_parse_time(rows$valid_to_utc, "valid_to_utc", allow_blank = TRUE)
    ends[is.na(ends)] <- as.POSIXct("9999-12-31T23:59:59Z", tz = "UTC")
    order_index <- order(starts, ends, method = "radix")
    starts <- starts[order_index]
    ends <- ends[order_index]
    start_values <- as.numeric(starts)
    end_values <- as.numeric(ends)
    if (any(start_values[-1L] < cummax(end_values)[-length(end_values)])) {
      phase18_club_abort("overlapping_club_identity", paste0(label, " contains overlapping validity assignments"))
    }
  }
  invisible(TRUE)
}

phase18_validate_club_registries <- function(registries) {
  phase18_club_require_exact_schema(registries)
  expected_version <- phase18_club_identity_schema_version()
  for (name in names(registries)) {
    table <- registries[[name]]
    if (nrow(table) && any(as.character(table$schema_version) != expected_version)) {
      phase18_club_abort("invalid_club_registry_schema", paste0(name, " has unsupported schema_version"))
    }
    if (nrow(table)) {
      expected_hash <- phase18_club_row_sha256(table)
      if (any(is.na(table$row_sha256) | table$row_sha256 != expected_hash)) {
        phase18_club_abort("club_registry_hash_mismatch", paste0(name, " row SHA-256 mismatch"))
      }
    }
  }
  clubs <- registries$clubs
  source_ids <- registries$source_ids
  aliases <- registries$aliases
  all_ids <- c(clubs$club_id, source_ids$club_id, aliases$club_id)
  if (length(all_ids) && any(is.na(all_ids) | !grepl("^club_[a-z0-9][a-z0-9_]*$", all_ids))) {
    phase18_club_abort("cross_domain_club_identity", "Club registry IDs must use the project-owned club_ namespace")
  }
  if (nrow(clubs)) {
    required <- c("canonical_name", "valid_from_utc", "club_status")
    if (any(vapply(clubs[required], function(x) any(is.na(x) | !nzchar(as.character(x))), logical(1)))) {
      phase18_club_abort("invalid_club_registry", "clubs contains empty required fields")
    }
    if (any(clubs$entity_kind != "club")) {
      phase18_club_abort("cross_domain_club_identity", "Club registry entity_kind must be club")
    }
    if (anyDuplicated(clubs$club_id)) phase18_club_abort("duplicate_club_identity", "clubs contains duplicate club_id")
  }
  if (nrow(source_ids) || nrow(aliases)) {
    foreign <- setdiff(unique(c(source_ids$club_id, aliases$club_id)), clubs$club_id)
    if (length(foreign)) phase18_club_abort("unknown_club_identity", "Registry assignment references unknown club_id")
  }
  for (name in c("source_ids", "aliases")) {
    table <- registries[[name]]
    if (!nrow(table)) next
    if (any(is.na(table$source_system) | !nzchar(table$source_system)) ||
        any(table$review_state != "approved")) {
      phase18_club_abort("unreviewed_club_identity", paste0(name, " must contain only approved source-scoped rows"))
    }
    starts <- phase18_club_parse_time(table$valid_from_utc, "valid_from_utc")
    ends <- phase18_club_parse_time(table$valid_to_utc, "valid_to_utc", allow_blank = TRUE)
    if (any(!is.na(ends) & starts >= ends)) {
      phase18_club_abort("invalid_club_validity", paste0(name, " requires positive half-open intervals"))
    }
  }
  if (nrow(source_ids)) {
    if (any(is.na(source_ids$source_club_id) | !nzchar(source_ids$source_club_id))) {
      phase18_club_abort("invalid_club_identity_input", "source_ids contains an empty source_club_id")
    }
    duplicate_key <- source_ids[c("source_system", "source_club_id", "club_id", "valid_from_utc", "valid_to_utc")]
    if (anyDuplicated(duplicate_key)) phase18_club_abort("duplicate_club_identity", "source_ids contains exact duplicate assignments")
    phase18_validate_nonoverlap(source_ids, c("source_system", "source_club_id"), "source_ids")
  }
  if (nrow(aliases)) {
    calculated <- phase18_normalize_club_name(aliases$alias)
    if (any(is.na(aliases$normalized_alias) | aliases$normalized_alias != calculated)) {
      phase18_club_abort("invalid_club_alias", "aliases normalized_alias does not match canonical normalization")
    }
    if (any(is.na(aliases$reviewed_by) | !nzchar(aliases$reviewed_by)) ||
        any(is.na(aliases$reviewed_at_utc) | !nzchar(aliases$reviewed_at_utc))) {
      phase18_club_abort("unreviewed_club_identity", "aliases requires reviewer evidence")
    }
    phase18_club_parse_time(aliases$reviewed_at_utc, "reviewed_at_utc")
    duplicate_key <- aliases[c("source_system", "normalized_alias", "club_id", "valid_from_utc", "valid_to_utc")]
    if (anyDuplicated(duplicate_key)) phase18_club_abort("duplicate_club_identity", "aliases contains exact duplicate assignments")
    phase18_validate_nonoverlap(aliases, c("source_system", "normalized_alias"), "aliases")
  }
  invisible(TRUE)
}

phase18_club_at_instant <- function(data, event_at) {
  if (!nrow(data)) return(data)
  starts <- phase18_club_parse_time(data$valid_from_utc, "valid_from_utc")
  ends <- phase18_club_parse_time(data$valid_to_utc, "valid_to_utc", allow_blank = TRUE)
  data[starts <= event_at & (is.na(ends) | event_at < ends), , drop = FALSE]
}

phase18_resolve_club_identity <- function(
  registries, source_system, source_club_id = NA_character_, display_name = NA_character_,
  event_at_utc
) {
  phase18_validate_club_registries(registries)
  if (!nrow(registries$clubs)) {
    phase18_club_abort("unresolved_empty_registry", "Cannot resolve a club against an empty registry")
  }
  if (length(source_system) != 1L || is.na(source_system) || !nzchar(as.character(source_system))) {
    phase18_club_abort("invalid_club_identity_input", "source_system must be one non-empty source scope")
  }
  if (length(event_at_utc) != 1L || is.na(event_at_utc) || !nzchar(as.character(event_at_utc))) {
    phase18_club_abort("invalid_club_identity_input", "event_at_utc must be one UTC instant")
  }
  event_at <- phase18_club_parse_time(event_at_utc, "event_at_utc")[[1L]]
  source_system <- as.character(source_system)
  source_club_id <- if (length(source_club_id) == 1L && !is.na(source_club_id) && nzchar(as.character(source_club_id))) as.character(source_club_id) else NA_character_
  display_name <- if (length(display_name) == 1L && !is.na(display_name) && nzchar(as.character(display_name))) as.character(display_name) else NA_character_
  normalized <- phase18_normalize_club_name(display_name)

  direct <- registries$source_ids[registries$source_ids$source_system == source_system &
    !is.na(source_club_id) & registries$source_ids$source_club_id == source_club_id, , drop = FALSE]
  direct <- phase18_club_at_instant(direct, event_at)
  if (nrow(direct) > 1L) phase18_club_abort("ambiguous_club_identity", "Multiple direct club identities are valid")

  alias <- registries$aliases[registries$aliases$source_system == source_system &
    !is.na(normalized) & registries$aliases$normalized_alias == normalized, , drop = FALSE]
  alias <- phase18_club_at_instant(alias, event_at)
  alias_ids <- unique(alias$club_id)
  if (length(alias_ids) > 1L) phase18_club_abort("ambiguous_club_identity", "Multiple reviewed aliases are valid")

  if (nrow(direct) == 1L) {
    if (!is.na(display_name)) {
      if (!length(alias_ids)) phase18_club_abort("unreviewed_club_display_name", "Direct source ID display name is not a reviewed alias")
      if (!identical(alias_ids[[1L]], direct$club_id[[1L]])) {
        phase18_club_abort("club_identity_disagreement", "Source ID and reviewed display alias resolve to different clubs")
      }
    }
    selected <- direct
    method <- "source_id"
    warning_value <- "none"
  } else {
    if (is.na(display_name)) phase18_club_abort("unresolved_club_identity", "No direct source ID match and no display alias supplied")
    if (!length(alias_ids)) phase18_club_abort("unresolved_club_identity", "Club identity is unresolved for the reviewed alias")
    selected <- alias[1L, , drop = FALSE]
    method <- "reviewed_alias"
    warning_value <- "reviewed_alias_fallback"
  }
  club <- registries$clubs[registries$clubs$club_id == selected$club_id[[1L]], , drop = FALSE]
  club <- phase18_club_at_instant(club, event_at)
  if (nrow(club) != 1L) phase18_club_abort("inactive_club_identity", "Resolved club is not valid at the event instant")
  data.frame(
    schema_version = "phase18-club-identity-resolution-1",
    club_id = club$club_id[[1L]], entity_kind = club$entity_kind[[1L]],
    canonical_name = club$canonical_name[[1L]], source_system = source_system,
    source_club_id = source_club_id, source_display_name = display_name,
    normalized_alias = normalized, resolution_method = method,
    resolution_warning = warning_value,
    registry_sha256 = phase18_club_registry_hash(registries),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase18_load_club_registries <- function(root = "data/club/registries") {
  schemas <- phase18_club_registry_schemas()
  files <- c(clubs = "clubs.csv", source_ids = "club_source_ids.csv", aliases = "club_aliases.csv")
  registries <- lapply(names(files), function(name) {
    path <- file.path(root, files[[name]])
    if (!file.exists(path)) phase18_club_abort("missing_club_registry", paste0("Missing club registry file: ", path))
    data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
    if (!nrow(data)) data[] <- lapply(data, as.character)
    data
  })
  names(registries) <- names(files)
  phase18_validate_club_registries(registries)
  registries
}
