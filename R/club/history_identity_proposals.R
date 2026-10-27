# Deterministic identity suggestions for owner review. Nothing in this module
# approves identities, publishes registries, or changes existing assignments.
phase18_history_identity_key <- function(name) {
  key <- phase18_normalize_club_name(name)
  key <- gsub("^(1 |[0-9]+ )?(fc|cf|sc|sk|fk|afc|ac|as|ssc|rc|rsc|pae|vfb|vfl) ", "", key)
  key <- gsub(" (fc|cf|sc|sk|fk)$", "", key)
  key <- gsub(" (18|19|20)[0-9]{2}$", "", key)
  trimws(key)
}

phase18_history_identity_alias_seeds <- function() {
  base <- data.frame(association_code = c("DEU", "DEU", "DEU", "ITA", "ITA", "ITA", "POR", "UKR", "GRC", "ESP", "ESP", "FRA", "FRA", "AUT", "AUT", "AUT", "AUT", "DEU", "FRA", "FRA"),
    source_name = c("Bayern München", "Stuttgart", "RasenBallsport Leipzig", "Inter", "Napoli", "Como", "Sporting CP", "Shakhtar Donetsk", "AEK Athen", "Atlético Madrid", "Real Betis", "RC Lens", "Lens", "RB Salzburg", "FC Salzburg", "Red Bull Salzburg", "Sturm Graz", "Bayer Leverkusen", "Olympique Marseille", "Olympique Lyon"),
    canonical_name = c("FC Bayern München", "VfB Stuttgart", "RB Leipzig", "FC Internazionale Milano", "SSC Napoli", "Como 1907", "Sporting Clube de Portugal", "FK Shakhtar Donetsk", "PAE AEK", "Club Atlético de Madrid", "Real Betis Balompié", "Racing Club de Lens", "Racing Club de Lens", "FC Red Bull Salzburg", "FC Red Bull Salzburg", "FC Red Bull Salzburg", "SK Sturm Graz", "Bayer 04 Leverkusen", "Olympique de Marseille", "Olympique Lyonnais"),
    evidence_kind = "explicit_pending_alias_seed", review_state = "pending",
    stringsAsFactors = FALSE)
  bridges <- data.frame(association_code = c("AUT", "AZE", "ESP", "FRA", "ESP", "GRC", "BEL"),
    source_name = c("LASK", "Qarabağ FK", "Atlético de Madrid", "Lille", "Real Madrid C.F.", "Olympiakos Piraeus", "Union Saint-Gilloise"),
    canonical_name = c("LASK Linz", "Qarabağ Ağdam FK", "Club Atlético de Madrid", "Lille OSC", "Real Madrid CF", "PAE Olympiakos SFP", "Royale Union Saint-Gilloise"),
    evidence_kind = "explicit_pending_alias_seed", review_state = "pending", stringsAsFactors = FALSE)
  rbind(base, bridges)
}

phase18_history_identity_association <- function(paths) {
  countries <- c(england = "ENG", deutschland = "DEU", germany = "DEU", italy = "ITA",
    espana = "ESP", spain = "ESP", france = "FRA", austria = "AUT", belgium = "BEL",
    netherlands = "NLD", portugal = "POR", turkey = "TUR", greece = "GRC",
    norway = "NOR", azerbaijan = "AZE", ukraine = "UKR", `czech-republic` = "CZE",
    slovakia = "SVK", scotland = "SCO", switzerland = "CHE", denmark = "DNK",
    sweden = "SWE", poland = "POL", serbia = "SRB", croatia = "HRV", russia = "RUS",
    israel = "ISR", moldova = "MDA", belarus = "BLR", cyprus = "CYP")
  vapply(strsplit(as.character(paths), "/", fixed = TRUE), function(parts) {
    country <- parts[parts %in% names(countries)]
    if (length(country) == 1L) unname(countries[country]) else ""
  }, character(1))
}

phase18_history_identity_country_tags <- function(path) {
  if (!file.exists(path)) return(data.frame(source_name = character(), association_code = character()))
  text <- readLines(path, warn = FALSE, encoding = "UTF-8")
  pattern <- "^\\s*(?:[0-9]{1,2}[:.][0-9]{2}\\s+)?(.+?)\\s+\\(([A-Z]{3})\\)\\s+v\\s+(.+?)\\s+\\(([A-Z]{3})\\)"
  parts <- regmatches(text, regexec(pattern, text, perl = TRUE))
  parts <- Filter(function(x) length(x) == 5L, parts)
  if (!length(parts)) return(data.frame(source_name = character(), association_code = character()))
  result <- unique(do.call(rbind, lapply(parts, function(x) data.frame(
    source_name = trimws(c(x[2L], x[4L])), association_code = c(x[3L], x[5L]), stringsAsFactors = FALSE))))
  codes <- c(GER = "DEU", NED = "NLD", SUI = "CHE", CRO = "HRV", GRE = "GRC", DEN = "DNK", MCO = "FRA")
  convert <- result$association_code %in% names(codes)
  result$association_code[convert] <- unname(codes[result$association_code[convert]])
  result
}

phase18_propose_history_club_identities <- function(native_names, current_clubs,
    raw_root = NULL, alias_seeds = phase18_history_identity_alias_seeds()) {
  if (!is.data.frame(native_names) || !all(c("path", "raw_name") %in% names(native_names)) ||
      !is.data.frame(current_clubs) || !all(c("club_id", "canonical_name", "association_code") %in% names(current_clubs)))
    stop("Native name/path inventory and canonical current clubs are required", call. = FALSE)
  if (anyNA(native_names[c("path", "raw_name")]) || any(!nzchar(native_names$raw_name)))
    stop("Native club names and source paths must be non-empty", call. = FALSE)
  native_names$raw_name <- enc2utf8(as.character(native_names$raw_name))
  current_clubs$canonical_name <- enc2utf8(as.character(current_clubs$canonical_name))
  alias_seeds$canonical_name <- enc2utf8(as.character(alias_seeds$canonical_name))
  input <- unique(native_names[c("path", "raw_name")])
  input <- input[order(input$path, input$raw_name, method = "radix"), , drop = FALSE]
  input$association_code <- phase18_history_identity_association(input$path)
  input$association_evidence <- ifelse(nzchar(input$association_code), "domestic_source_country", "")
  if ("association_code" %in% names(native_names)) {
    j <- match(paste(input$path, input$raw_name), paste(native_names$path, native_names$raw_name))
    declared <- as.character(native_names$association_code[j])
    use <- !is.na(declared) & nzchar(declared)
    input$association_code[use] <- declared[use]
    input$association_evidence[use] <- "native_inventory_country"
  }
  if (!is.null(raw_root)) for (source_path in unique(input$path[!nzchar(input$association_code)])) {
    tags <- phase18_history_identity_country_tags(file.path(raw_root, source_path))
    j <- which(input$path == source_path)
    for (i in j) {
      country <- unique(tags$association_code[tags$source_name == input$raw_name[i]])
      if (length(country) == 1L) {
        input$association_code[i] <- country
        input$association_evidence[i] <- "explicit_native_country_tag"
      }
    }
  }
  input$normalized_name <- phase18_normalize_club_name(input$raw_name)
  # Exact aliases observed in domestic files can supply missing CL country tags.
  for (i in which(!nzchar(input$association_code))) {
    countries <- unique(input$association_code[input$normalized_name == input$normalized_name[i] & nzchar(input$association_code)])
    if (length(countries) == 1L) {
      input$association_code[i] <- countries
      input$association_evidence[i] <- "same_native_name_domestic_evidence"
    }
  }
  input$key <- phase18_history_identity_key(input$raw_name)
  seed_key <- paste(alias_seeds$association_code, phase18_normalize_club_name(alias_seeds$source_name), sep = ":")
  seed <- match(paste(input$association_code, input$normalized_name, sep = ":"), seed_key)
  input$target_name <- input$raw_name
  seeded <- !is.na(seed)
  input$target_name[seeded] <- alias_seeds$canonical_name[seed[seeded]]
  input$target_key <- phase18_history_identity_key(input$target_name)
  current_key <- phase18_history_identity_key(current_clubs$canonical_name)
  groups <- split(seq_len(nrow(input)), paste(input$association_code, input$normalized_name, sep = ":"))
  proposals <- lapply(groups, function(indices) {
    row <- input[indices[1L], , drop = FALSE]
    same_country <- as.character(current_clubs$association_code) == row$association_code
    exact <- which(same_country & phase18_normalize_club_name(current_clubs$canonical_name) == phase18_normalize_club_name(row$target_name))
    candidates <- if (length(exact)) exact else which(same_country & current_key == row$target_key)
    evidence <- if (any(seeded[indices])) "explicit_pending_alias_seed" else if (length(exact) == 1L) "exact_canonical_name" else "conservative_club_affix_key"
    ambiguity <- if (!nzchar(row$association_code)) "association_missing" else if (length(candidates) > 1L) "multiple_existing_canonical_candidates" else ""
    club_id <- canonical <- ""
    if (!nzchar(ambiguity) && length(candidates) == 1L) {
      club_id <- as.character(current_clubs$club_id[candidates])
      canonical <- as.character(current_clubs$canonical_name[candidates])
    } else if (!nzchar(ambiguity)) {
      club_id <- paste0("club_", tolower(row$association_code), "_", gsub(" ", "_", row$target_key, fixed = TRUE))
      # All observed aliases sharing this country/key receive one stable name.
      aliases <- input$target_name[input$association_code == row$association_code & input$target_key == row$target_key]
      canonical <- sort(unique(aliases), method = "radix")[[1L]]
      evidence <- if (any(seeded[indices])) evidence else "new_project_club_from_source_name"
    }
    data.frame(source_name = sort(unique(input$raw_name[indices]), method = "radix")[[1L]],
      normalized_name = row$normalized_name, source_system = "openfootball",
      source_club_id = paste0("name:", gsub(" ", "_", row$normalized_name, fixed = TRUE)),
      association_code = row$association_code,
      association_evidence = paste(sort(unique(input$association_evidence[indices])), collapse = "|"),
      source_paths = paste(sort(unique(input$path[indices])), collapse = "|"),
      proposed_club_id = club_id, proposed_canonical_name = canonical,
      mapping_evidence = evidence, existing_canonical_candidates = paste(current_clubs$club_id[candidates], collapse = "|"),
      confidence = if (nzchar(ambiguity)) "unresolved" else if (length(candidates) == 1L && length(exact)) "high" else "review_required",
      ambiguity = ambiguity, review_state = "pending", stringsAsFactors = FALSE)
  })
  proposals <- do.call(rbind, proposals)
  rownames(proposals) <- NULL
  # Current resolver IDs are namespaced by source, not association: two clubs
  # with the same normalized name cannot be safely activated as-is.
  for (id in unique(proposals$source_club_id)) {
    index <- which(proposals$source_club_id == id)
    countries <- unique(proposals$association_code[index][nzchar(proposals$association_code[index])])
    if (length(countries) > 1L) {
      proposals$ambiguity[index] <- "source_name_cross_association_collision"
      proposals$confidence[index] <- "unresolved"
    }
  }
  proposals <- proposals[order(proposals$association_code, proposals$source_club_id, method = "radix"), , drop = FALSE]
  rownames(proposals) <- NULL
  mapped <- proposals$proposed_club_id[!nzchar(proposals$ambiguity)]
  missing <- current_clubs[!current_clubs$club_id %in% mapped, c("club_id", "canonical_name", "association_code"), drop = FALSE]
  list(proposals = proposals, unresolved_current_clubs = missing,
    summary = list(native_file_count = length(unique(input$path)), native_name_count = length(unique(input$normalized_name)),
      proposal_count = nrow(proposals), proposed_club_count = length(unique(mapped[nzchar(mapped)])),
      unresolved_proposal_count = sum(nzchar(proposals$ambiguity)),
      current_club_count = nrow(current_clubs), current_clubs_covered = nrow(current_clubs) - nrow(missing)))
}

# Construct exact future review-schema rows only after tokens are evidence-bound
# to the parsed history corpus. Pending rows cannot pass the activation gate.
phase18_history_identity_pending_review <- function(tokens, proposals, source_bundle_id,
    generated_at_utc, valid_from_utc = NULL, valid_to_utc = "") {
  phase18_validate_club_tokens(tokens)
  if (is.null(valid_from_utc)) valid_from_utc <- min(as.character(tokens$event_at_utc))
  if (any(proposals$review_state != "pending")) stop("Identity suggestions must remain pending", call. = FALSE)
  output <- lapply(seq_len(nrow(tokens)), function(i) {
    token <- tokens[i, , drop = FALSE]
    matches <- proposals[proposals$source_club_id == token$source_club_id & !nzchar(proposals$ambiguity), , drop = FALSE]
    if (nrow(matches) != 1L || !nzchar(matches$proposed_club_id))
      stop("Every token requires one unambiguous pending identity proposal", call. = FALSE)
    data.frame(schema_version = "phase18-club-review-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
      corpus = token$corpus, source_system = token$source_system, source_row = token$source_row,
      source_club_id = token$source_club_id, display_value = token$display_value, evidence_sha256 = token$evidence_sha256,
      club_id = matches$proposed_club_id, entity_kind = "club", canonical_name = matches$proposed_canonical_name,
      association_code = matches$association_code, valid_from_utc = valid_from_utc, valid_to_utc = valid_to_utc,
      reviewer = "pending_owner_review", reviewed_at_utc = generated_at_utc, review_state = "pending",
      source_bundle_id = source_bundle_id, row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  })
  review <- if (length(output)) do.call(rbind, output) else phase18_empty_table(phase18_club_review_schema())
  review <- phase18_hash_club_review_rows(review)
  phase18_validate_club_identity_review(tokens, review)
  review
}

phase18_propose_history_club_identities_from_tokens <- function(tokens, current_clubs,
    token_sources, raw_root = NULL, alias_seeds = phase18_history_identity_alias_seeds()) {
  phase18_validate_club_tokens(tokens)
  if (any(tokens$source_system != "openfootball") ||
      any(tokens$corpus != "historical_inventory"))
    stop("Historical proposals accept only OpenFootball historical identity tokens", call. = FALSE)
  if (!is.data.frame(token_sources) || !all(c("evidence_sha256", "path") %in% names(token_sources)) ||
      anyDuplicated(token_sources$evidence_sha256))
    stop("Every history token requires one evidence-keyed pinned source path", call. = FALSE)
  index <- match(tokens$evidence_sha256, token_sources$evidence_sha256)
  if (anyNA(index)) stop("Pinned source evidence is missing for a history token", call. = FALSE)
  names <- data.frame(path = as.character(token_sources$path[index]),
    raw_name = as.character(tokens$display_value), stringsAsFactors = FALSE)
  if ("association_code" %in% names(token_sources)) names$association_code <- token_sources$association_code[index]
  phase18_propose_history_club_identities(names, current_clubs, raw_root, alias_seeds)
}

# Corroborate spelling changes between two pinned versions of the same source
# file using uniquely identified actual fixtures. Repeated date/score/stage keys
# and inconsistent old-name mappings are excluded from automatic suggestions.
phase18_history_fixture_alias_evidence <- function(old_rows, new_rows, source_path,
    old_raw_sha256, new_raw_sha256, association_code = NULL,
    association_by_name = NULL, minimum_fixture_support = 2L,
    alias_seeds = phase18_history_identity_alias_seeds()) {
  required <- c("source_match_id", "event_date", "stage", "status", "home_name", "away_name", "score_text", "score_semantics")
  if (!is.data.frame(old_rows) || !is.data.frame(new_rows) ||
      !all(required %in% names(old_rows)) || !all(required %in% names(new_rows)))
    stop("Both pinned versions require the parsed native fixture schema", call. = FALSE)
  if (!all(grepl("^[0-9a-f]{64}$", c(old_raw_sha256, new_raw_sha256))) ||
      length(source_path) != 1L || !nzchar(source_path) || minimum_fixture_support < 1L)
    stop("Alias comparison requires source path, two immutable hashes and positive support", call. = FALSE)
  key <- function(rows) paste(rows$event_date, rows$stage, rows$score_text, rows$score_semantics, sep = "|")
  eligible <- function(rows) rows[rows$status == "completed" & rows$score_semantics == "regulation", , drop = FALSE]
  old <- eligible(old_rows); new <- eligible(new_rows)
  old_key <- key(old); new_key <- key(new)
  old_unique <- !duplicated(old_key) & !duplicated(old_key, fromLast = TRUE)
  new_unique <- !duplicated(new_key) & !duplicated(new_key, fromLast = TRUE)
  common <- sort(intersect(old_key[old_unique], new_key[new_unique]), method = "radix")
  old <- old[match(common, old_key), , drop = FALSE]
  new <- new[match(common, new_key), , drop = FALSE]
  if (!length(common)) return(list(aliases = data.frame(), evidence = data.frame(), conflicts = data.frame(),
    summary = list(unique_fixture_count = 0L, alias_count = 0L, ambiguous_old_fixture_count = sum(!old_unique), ambiguous_new_fixture_count = sum(!new_unique))))
  index <- rep(seq_along(common), each = 2L)
  evidence <- data.frame(source_path = source_path, old_raw_sha256 = old_raw_sha256, new_raw_sha256 = new_raw_sha256,
    old_source_match_id = old$source_match_id[index], new_source_match_id = new$source_match_id[index],
    fixture_key = common[index], event_date = old$event_date[index], stage = old$stage[index], score_text = old$score_text[index],
    side = rep(c("home", "away"), length(common)), source_name = as.vector(rbind(old$home_name, old$away_name)),
    modern_name = as.vector(rbind(new$home_name, new$away_name)), stringsAsFactors = FALSE)
  evidence$source_name <- enc2utf8(as.character(evidence$source_name))
  evidence$modern_name <- enc2utf8(as.character(evidence$modern_name))
  evidence$association_code <- if (is.null(association_code)) phase18_history_identity_association(source_path) else association_code
  if (!is.null(association_by_name)) {
    if (!all(c("source_name", "association_code") %in% names(association_by_name)))
      stop("Association evidence must contain source_name and association_code", call. = FALSE)
    country_names <- phase18_normalize_club_name(association_by_name$source_name)
    countries <- split(as.character(association_by_name$association_code), country_names)
    countries <- lapply(countries, function(value) unique(value[!is.na(value) & nzchar(value)]))
    countries <- countries[lengths(countries) == 1L]
    country_map <- setNames(unlist(countries, use.names = FALSE), names(countries))
    found <- unname(country_map[phase18_normalize_club_name(evidence$modern_name)])
    use <- !is.na(found) & nzchar(found)
    evidence$association_code[use] <- found[use]
  }
  evidence$canonical_name <- evidence$modern_name
  seed_key <- paste(alias_seeds$association_code, phase18_normalize_club_name(alias_seeds$source_name), sep = ":")
  for (iteration in seq_len(nrow(alias_seeds) + 1L)) {
    candidate <- match(paste(evidence$association_code, phase18_normalize_club_name(evidence$canonical_name), sep = ":"), seed_key)
    next_name <- evidence$canonical_name
    matched <- !is.na(candidate)
    next_name[matched] <- enc2utf8(alias_seeds$canonical_name[candidate[matched]])
    if (identical(next_name, evidence$canonical_name)) break
    evidence$canonical_name <- next_name
  }
  evidence$old_normalized <- phase18_normalize_club_name(evidence$source_name)
  evidence$new_normalized <- phase18_normalize_club_name(evidence$canonical_name)
  evidence$review_state <- "pending"
  groups <- split(seq_len(nrow(evidence)), paste(evidence$association_code, evidence$old_normalized, sep = ":"))
  aliases <- conflicts <- list()
  for (indices in groups) {
    part <- evidence[indices, , drop = FALSE]
    targets <- unique(part$new_normalized)
    support <- length(unique(part$fixture_key))
    conflict <- if (!all(nzchar(part$association_code))) "association_missing" else if (length(targets) != 1L) "inconsistent_fixture_side_identity" else if (support < minimum_fixture_support) "insufficient_unique_fixture_support" else ""
    if (nzchar(conflict)) {
      part$reason_code <- conflict
      conflicts[[length(conflicts) + 1L]] <- part
      next
    }
    if (identical(part$old_normalized[1L], targets)) next
    aliases[[length(aliases) + 1L]] <- data.frame(association_code = part$association_code[1L],
      source_name = sort(unique(part$source_name), method = "radix")[1L],
      canonical_name = sort(unique(part$canonical_name), method = "radix")[1L],
      evidence_kind = "same_fixture_date_score_stage_unique_consistent_sides",
      review_state = "pending", unique_fixture_support = support, source_path = source_path,
      old_raw_sha256 = old_raw_sha256, new_raw_sha256 = new_raw_sha256, stringsAsFactors = FALSE)
  }
  list(aliases = if (length(aliases)) do.call(rbind, aliases) else data.frame(),
    evidence = evidence, conflicts = if (length(conflicts)) do.call(rbind, conflicts) else data.frame(),
    summary = list(unique_fixture_count = length(common), alias_count = length(aliases),
      ambiguous_old_fixture_count = sum(!old_unique), ambiguous_new_fixture_count = sum(!new_unique)))
}

# Inspect all error-free candidate source versions, preserving every alias proof
# before reducing the corpus to first-observed fixtures. Inputs remain pending.
phase18_history_candidate_alias_proposals <- function(candidate_rows, current_clubs,
    association_by_name = NULL, raw_blob_root = NULL, minimum_fixture_support = 2L) {
  required <- c("source_path", "raw_sha256", "commit_utc", "is_latest_file_bytes",
    "source_match_id", "event_date", "stage", "status", "home_name", "away_name", "score_text", "score_semantics")
  if (!is.data.frame(candidate_rows) || !all(required %in% names(candidate_rows)))
    stop("Complete parsed candidate rows with immutable version metadata are required", call. = FALSE)
  metadata <- unique(candidate_rows[c("source_path", "raw_sha256", "commit_utc", "is_latest_file_bytes")])
  metadata <- metadata[order(metadata$source_path, metadata$commit_utc, metadata$raw_sha256, method = "radix"), , drop = FALSE]
  metadata <- metadata[!duplicated(metadata[c("source_path", "raw_sha256")]), , drop = FALSE]
  version_key <- paste(candidate_rows$source_path, candidate_rows$raw_sha256, sep = "|")
  versions <- split(seq_len(nrow(candidate_rows)), version_key)
  base <- phase18_history_identity_alias_seeds()
  proofs <- aliases <- conflicts <- list()
  latest_names <- all_names <- list()
  for (path in unique(metadata$source_path)) {
    versions_meta <- metadata[metadata$source_path == path, , drop = FALSE]
    marked <- tolower(as.character(versions_meta$is_latest_file_bytes)) %in% c("true", "1")
    latest <- if (any(marked)) versions_meta[which(marked)[1L], , drop = FALSE] else versions_meta[nrow(versions_meta), , drop = FALSE]
    modern <- candidate_rows[versions[[paste(path, latest$raw_sha256, sep = "|")]], , drop = FALSE]
    latest_names[[length(latest_names) + 1L]] <- unique(c(as.character(modern$home_name), as.character(modern$away_name)))
    domestic <- phase18_history_identity_association(path)
    for (j in seq_len(nrow(versions_meta))) {
      version <- versions_meta[j, , drop = FALSE]
      old <- candidate_rows[versions[[paste(path, version$raw_sha256, sep = "|")]], , drop = FALSE]
      names <- unique(c(as.character(old$home_name), as.character(old$away_name)))
      observed <- data.frame(path = path, raw_name = names, association_code = domestic, stringsAsFactors = FALSE)
      if (!nzchar(domestic) && !is.null(raw_blob_root)) {
        tags <- phase18_history_identity_country_tags(file.path(raw_blob_root, paste0(version$raw_sha256, ".txt")))
        found <- tags$association_code[match(phase18_normalize_club_name(names), phase18_normalize_club_name(tags$source_name))]
        observed$association_code <- ifelse(is.na(found), "", found)
      }
      all_names[[length(all_names) + 1L]] <- observed
      if (identical(as.character(version$raw_sha256), as.character(latest$raw_sha256))) next
      compared <- phase18_history_fixture_alias_evidence(old, modern, path,
        version$raw_sha256, latest$raw_sha256, if (nzchar(domestic)) domestic else NULL,
        association_by_name, minimum_fixture_support, base)
      if (nrow(compared$aliases)) aliases[[length(aliases) + 1L]] <- compared$aliases
      if (nrow(compared$aliases)) {
        accepted_keys <- paste(compared$aliases$association_code,
          phase18_normalize_club_name(compared$aliases$source_name), sep = "|")
        evidence_keys <- paste(compared$evidence$association_code, compared$evidence$old_normalized, sep = "|")
        proofs[[length(proofs) + 1L]] <- compared$evidence[evidence_keys %in% accepted_keys, , drop = FALSE]
      }
      if (nrow(compared$conflicts)) conflicts[[length(conflicts) + 1L]] <- compared$conflicts
    }
  }
  learned <- if (length(aliases)) do.call(rbind, aliases) else data.frame()
  proof_rows <- if (length(proofs)) do.call(rbind, proofs) else data.frame()
  conflict_rows <- if (length(conflicts)) do.call(rbind, conflicts) else data.frame()
  edges <- base[c("association_code", "source_name", "canonical_name", "evidence_kind", "review_state")]
  if (nrow(learned)) edges <- rbind(edges, learned[names(edges)])
  edges$old_node <- paste(edges$association_code, phase18_normalize_club_name(edges$source_name), sep = "|")
  edges$new_node <- paste(edges$association_code, phase18_normalize_club_name(edges$canonical_name), sep = "|")
  edges <- unique(edges)
  adjacency <- split(c(edges$new_node, edges$old_node), c(edges$old_node, edges$new_node))
  remaining <- sort(unique(c(edges$old_node, edges$new_node)), method = "radix")
  stable_seeds <- components <- list()
  ambiguous_nodes <- character()
  modern_names <- unique(enc2utf8(unlist(latest_names, use.names = FALSE)))
  while (length(remaining)) {
    component <- queue <- remaining[1L]
    while (length(queue)) {
      neighbors <- unique(unlist(adjacency[queue], use.names = FALSE))
      queue <- setdiff(neighbors, component)
      component <- unique(c(component, queue))
    }
    remaining <- setdiff(remaining, component)
    country <- strsplit(component[1L], "|", fixed = TRUE)[[1L]][1L]
    normalized <- substring(component, nchar(country) + 2L)
    node_rows <- edges[edges$old_node %in% component | edges$new_node %in% component, , drop = FALSE]
    display <- unique(enc2utf8(c(node_rows$source_name, node_rows$canonical_name)))
    current <- current_clubs[current_clubs$association_code == country &
      (phase18_normalize_club_name(current_clubs$canonical_name) %in% normalized |
       phase18_history_identity_key(current_clubs$canonical_name) %in% phase18_history_identity_key(display)), , drop = FALSE]
    ambiguity <- if (nrow(current) > 1L) "fixture_component_multiple_current_clubs" else ""
    if (nrow(current) == 1L) canonical <- enc2utf8(as.character(current$canonical_name)) else {
      preferred <- modern_names[phase18_normalize_club_name(modern_names) %in% normalized]
      if (!length(preferred)) preferred <- display
      preferred <- preferred[order(-nchar(phase18_normalize_club_name(preferred)), preferred, method = "radix")]
      canonical <- preferred[1L]
    }
    components[[length(components) + 1L]] <- data.frame(association_code = country,
      canonical_name = canonical, names = paste(sort(display, method = "radix"), collapse = "|"),
      current_club_ids = paste(current$club_id, collapse = "|"), ambiguity = ambiguity,
      review_state = "pending", stringsAsFactors = FALSE)
    if (nzchar(ambiguity)) {
      ambiguous_nodes <- c(ambiguous_nodes, component)
      next
    }
    evidence_kind <- if (any(node_rows$evidence_kind == "same_fixture_date_score_stage_unique_consistent_sides"))
      "fixture_supported_alias_component_pending" else "explicit_pending_alias_seed"
    stable_seeds[[length(stable_seeds) + 1L]] <- data.frame(association_code = country,
      source_name = display, canonical_name = canonical, evidence_kind = evidence_kind,
      review_state = "pending", stringsAsFactors = FALSE)
  }
  seeds <- do.call(rbind, stable_seeds)
  seeds <- seeds[order(seeds$association_code, seeds$source_name, method = "radix"), , drop = FALSE]
  inventory <- unique(do.call(rbind, all_names))
  country_evidence <- data.frame(source_name = seeds$source_name, association_code = seeds$association_code,
    stringsAsFactors = FALSE)
  if (!is.null(association_by_name)) country_evidence <- rbind(country_evidence,
    association_by_name[c("source_name", "association_code")])
  countries <- split(as.character(country_evidence$association_code), phase18_normalize_club_name(country_evidence$source_name))
  countries <- lapply(countries, function(value) unique(value[!is.na(value) & nzchar(value)]))
  countries <- countries[lengths(countries) == 1L]
  country_map <- setNames(unlist(countries, use.names = FALSE), names(countries))
  missing_country <- !nzchar(inventory$association_code)
  inferred <- unname(country_map[phase18_normalize_club_name(inventory$raw_name[missing_country])])
  inventory$association_code[missing_country] <- ifelse(is.na(inferred), "", inferred)
  proposed <- phase18_propose_history_club_identities(inventory, current_clubs, alias_seeds = seeds)
  component_table <- do.call(rbind, components)
  if (length(ambiguous_nodes)) {
    blocked <- paste(proposed$proposals$association_code, proposed$proposals$normalized_name, sep = "|") %in% ambiguous_nodes
    proposed$proposals$ambiguity[blocked] <- "fixture_component_multiple_current_clubs"
    proposed$proposals$confidence[blocked] <- "unresolved"
    supported <- proposed$proposals$proposed_club_id[!nzchar(proposed$proposals$ambiguity)]
    proposed$unresolved_current_clubs <- current_clubs[!current_clubs$club_id %in% supported,
      c("club_id", "canonical_name", "association_code"), drop = FALSE]
    proposed$summary$unresolved_proposal_count <- sum(nzchar(proposed$proposals$ambiguity))
    proposed$summary$current_clubs_covered <- nrow(current_clubs) - nrow(proposed$unresolved_current_clubs)
  }
  proposed$candidate_alias_evidence <- proof_rows
  proposed$candidate_alias_proposals <- learned
  proposed$candidate_alias_conflicts <- conflict_rows
  proposed$alias_components <- component_table
  proposed$alias_seeds <- seeds
  proposed$summary$candidate_version_count <- nrow(metadata)
  proposed$summary$fixture_alias_count <- nrow(learned)
  proposed$summary$alias_component_conflict_count <- sum(nzchar(component_table$ambiguity))
  proposed
}
