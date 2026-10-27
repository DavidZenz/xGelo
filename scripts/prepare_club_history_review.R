#!/usr/bin/env Rscript

# Read-only with respect to accepted history, registries, model selectors and
# owner decisions. Materialize exact proposed pins, scope and identity evidence.
for (dependency in c("R/common/phase18_canonical_hash.R", "R/club/identity.R",
  "R/club/identity_bootstrap.R", "R/club/history_contract.R", "R/club/openfootball_parser.R",
  "R/club/history_ingestion.R", "R/club/history_identity_proposals.R")) source(dependency)

prepare_club_history_review <- function(
    index_path = "data/club/local_raw/pin_candidates/first_observed_selections.csv",
    review_root = "data/club/identity_reviews/history-2026-10-27",
    generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  pins <- phase18_history_read_csv(index_path)
  all_proposals <- phase18_history_read_csv("data/club/local_raw/pin_candidates/all_candidate_identity_proposals.csv")
  required <- c("source_id", "repository_url", "relative_path", "commit_sha", "commit_utc",
    "raw_sha256", "bytes", "local_path", "license_sha256", "license_local_path", "license_url",
    "competition_id", "season_id")
  if (length(setdiff(required, names(pins))) || anyDuplicated(pins$source_id)) stop("Pin selection index is incomplete")
  dir.create(review_root, recursive = TRUE, showWarnings = FALSE)
  inventory <- scopes <- details <- names <- match_parts <- list()
  for (i in seq_len(nrow(pins))) {
    pin <- pins[i, , drop = FALSE]
    if (!identical(digest::digest(file = pin$local_path, algo = "sha256", serialize = FALSE), pin$raw_sha256[[1L]]) ||
        !identical(digest::digest(file = pin$license_local_path, algo = "sha256", serialize = FALSE), pin$license_sha256[[1L]]))
      stop("Pin or license bytes differ from acquisition evidence")
    original <- phase18_read_openfootball_source(pin$local_path, pin, strict = TRUE)
    membership <- if ("selected_source_match_ids" %in% names(pin)) pin$selected_source_match_ids[[1L]] else NULL
    selection <- phase18_select_openfootball_history(original, pin$competition_id[[1L]], membership)
    if (!nrow(selection$rows)) stop("Selected source has no supported regulation results: ", pin$source_id)
    target <- file.path("data/club/local_raw", pin$source_id, pin$commit_sha, pin$relative_path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(pin$local_path, target, overwrite = TRUE)) stop("Cannot materialize pinned bytes")
    license_target <- file.path("data/club/local_raw", pin$source_id, pin$commit_sha, "LICENSE.evidence")
    if (!file.copy(pin$license_local_path, license_target, overwrite = TRUE)) stop("Cannot retain license evidence")
    row <- as.list(setNames(rep("", length(phase18_history_source_schema())), phase18_history_source_schema()))
    for (field in intersect(names(row), names(pin))) row[[field]] <- pin[[field]][[1L]]
    row$schema_version <- "phase18-club-history-source-v2"
    row$hash_encoding_version <- phase18_canonical_encoding_v2()
    row$license_id <- "CC0-1.0"; row$license_review_state <- "pending"
    row$retrieval_utc <- generated_at_utc
    row$expected_completed_matches <- as.character(nrow(selection$rows))
    row$source_status <- "blocked_pending_review"; row$blocked_reason <- "pending_owner_source_license_scope_review"
    row <- as.data.frame(row, stringsAsFactors = FALSE)
    row$row_sha256 <- phase18_history_row_sha256(row)
    inventory[[i]] <- row
    scopes[[i]] <- phase18_history_source_scope(original, row, membership)
    details[[i]] <- data.frame(source_id = row$source_id, competition_id = row$competition_id,
      season_id = row$season_id, commit_utc = row$commit_utc, parsed_rows = nrow(original),
      completed_results = sum(original$status == "completed"), selected_regulation_results = nrow(selection$rows),
      scheduled_missing_results = sum(original$status == "scheduled"), awarded_results = sum(original$status == "awarded"),
      excluded_rows = nrow(selection$excluded), first_match = min(selection$rows$event_date),
      last_match = max(selection$rows$event_date), selection_policy = selection$policy,
      source_url = paste0(sub("$", "/blob/", row$repository_url), row$commit_sha, "/", row$relative_path))
    utils::write.csv(attr(original, "diagnostics"), file.path(review_root, paste0(row$source_id, "-parser.csv")), row.names = FALSE)
    utils::write.csv(selection$excluded, file.path(review_root, paste0(row$source_id, "-exclusions.csv")), row.names = FALSE)
    selected <- selection$rows
    match_parts[[i]] <- data.frame(source_id = row$source_id, selected[, c("source_match_id", "event_date", "home_name", "away_name")])
    evidence <- rbind(data.frame(display_name = selected$home_name, event_date = selected$event_date,
      native_line = selected$source_match_id), data.frame(display_name = selected$away_name,
      event_date = selected$event_date, native_line = selected$source_match_id))
    evidence$path <- substring(target, nchar("data/club/local_raw/") + 1L)
    evidence$source_row <- paste(row$source_id, row$raw_sha256, evidence$native_line, sep = ":")
    country <- phase18_history_identity_association(paste0(sub("https://github.com/openfootball/", "", pin$repository_url),
      "/", pin$relative_path))
    evidence$association_code <- country
    if (!nzchar(country)) {
      tags <- phase18_history_identity_country_tags(target)
      evidence$association_code <- tags$association_code[match(evidence$display_name, tags$source_name)]
      missing_tags <- is.na(evidence$association_code)
      evidence$association_code[missing_tags] <- all_proposals$association_code[match(
        phase18_normalize_club_name(evidence$display_name[missing_tags]), all_proposals$normalized_name)]
      if (anyNA(evidence$association_code)) stop("Pinned CL name lacks explicit country tag")
    }
    names[[i]] <- evidence
  }
  inventory <- do.call(rbind, inventory); scopes <- do.call(rbind, scopes); details <- do.call(rbind, details)
  phase18_validate_history_sources(inventory)
  evidence <- do.call(rbind, names)
  evidence <- evidence[order(evidence$event_date, evidence$source_row, evidence$display_name, method = "radix"), ]
  evidence <- evidence[!duplicated(evidence$display_name), ]
  tokens <- phase18_token_rows("historical_inventory", "openfootball", evidence$source_row,
    paste0("name:", gsub(" ", "_", phase18_normalize_club_name(evidence$display_name), fixed = TRUE)),
    evidence$display_name, paste0(evidence$event_date, "T00:00:00Z"))
  token_sources <- data.frame(evidence_sha256 = tokens$evidence_sha256, path = evidence$path,
    association_code = evidence$association_code)
  registries <- phase18_load_club_registries()
  proposal_rows <- all_proposals[all_proposals$source_club_id %in% tokens$source_club_id, , drop = FALSE]
  missing <- registries$clubs[!registries$clubs$club_id %in% proposal_rows$proposed_club_id,
    c("club_id", "canonical_name", "association_code"), drop = FALSE]
  proposed <- list(proposals = proposal_rows, unresolved_current_clubs = missing,
    summary = list(native_file_count = length(unique(paste(pins$competition_id, pins$season_id))),
      native_name_count = length(unique(tokens$normalized_display)),
      proposal_count = nrow(proposal_rows), proposed_club_count = length(unique(proposal_rows$proposed_club_id)),
      unresolved_proposal_count = sum(nzchar(proposal_rows$ambiguity)),
      current_club_count = nrow(registries$clubs), current_clubs_covered = nrow(registries$clubs) - nrow(missing)))
  review <- phase18_history_identity_pending_review(tokens, proposed$proposals,
    "club-history-2026-10-27", generated_at_utc, "2021-01-01T00:00:00Z", "2027-07-01T00:00:00Z")
  pairs <- do.call(rbind, match_parts)
  proposal <- proposed$proposals
  identify <- function(value) proposal$proposed_club_id[match(phase18_normalize_club_name(value), proposal$normalized_name)]
  pairs$home_club_id <- identify(pairs$home_name); pairs$away_club_id <- identify(pairs$away_name)
  if (anyNA(pairs[c("home_club_id", "away_club_id")])) stop("Selected match has an unresolved proposed identity")
  reached <- registries$clubs$club_id[[1L]]
  repeat {
    next_reached <- unique(c(reached, pairs$away_club_id[pairs$home_club_id %in% reached],
      pairs$home_club_id[pairs$away_club_id %in% reached]))
    if (length(next_reached) == length(reached)) break
    reached <- next_reached
  }
  coverage <- registries$clubs[, c("club_id", "canonical_name", "association_code")]
  coverage$selected_historical_matches <- vapply(coverage$club_id,
    function(id) sum(pairs$home_club_id == id | pairs$away_club_id == id), integer(1))
  coverage$in_common_historical_component <- coverage$club_id %in% reached
  files <- list(proposed_history_sources = inventory, proposed_history_scopes = scopes,
    proposed_history_tokens = tokens, proposed_history_owner_review = review,
    proposed_historical_club_identities = proposed$proposals, source_coverage_summary = details,
    token_sources = token_sources, missing_current_clubs = proposed$unresolved_current_clubs,
    current_club_history_coverage = coverage)
  for (name in names(files)) utils::write.csv(files[[name]], file.path(review_root, paste0(name, ".csv")), row.names = FALSE)
  proof_files <- c("first_observed_match_ledger.csv", "candidate_alias_evidence.csv", "candidate_alias_proposals.csv")
  for (name in proof_files) {
    source <- file.path("data/club/local_raw/pin_candidates", name)
    if (file.exists(source)) file.copy(source, file.path(review_root, name), overwrite = TRUE)
  }
  jsonlite::write_json(c(proposed$summary, list(source_count = nrow(inventory),
    selected_regulation_results = sum(as.integer(scopes$selected_rows)),
    excluded_source_rows = sum(as.integer(scopes$excluded_rows)), generated_at_utc = generated_at_utc,
    current_clubs_with_played_history = sum(coverage$selected_historical_matches > 0L),
    current_clubs_in_common_component = sum(coverage$in_common_historical_component),
    acceptance_state = "pending_owner_review", accepted_authority_mutated = FALSE)),
    file.path(review_root, "summary.json"), pretty = TRUE, auto_unbox = TRUE)
  writeLines(c("# Proposed club historical training and model policy review", "",
    sprintf("Prepared %s. Acceptance remains pending.", generated_at_utc), "",
    sprintf("- %d pinned source snapshots; %d selected regulation results; %d other source rows, including repeated snapshots.",
      nrow(inventory), sum(as.integer(scopes$selected_rows)), sum(as.integer(scopes$excluded_rows))),
    sprintf("- %d proposed name mappings; %d canonical clubs.", nrow(review), proposed$summary$proposed_club_count),
    sprintf("- Current roster: %d/36 clubs have played history; %d/36 share one historical component.",
      sum(coverage$selected_historical_matches > 0L), sum(coverage$in_common_historical_component)), "",
    "The source inventory binds full Git commits, original repository paths, raw bytes and pinned CC0 license evidence.",
    "Each final regulation result is retained once, from the earliest successfully parsed retained snapshot containing that same canonical fixture and final score.",
    "Later result or date corrections use their own later first-observed evidence; publication is never backdated.",
    "The scope inventory binds the exact selected rows: domestic league stages and UCL group/league stages only.",
    "Missing results, awarded matches and knockout stages remain in the exclusion reports and never become training results.",
    "Incomplete season files contribute only their explicitly counted played subset; they are not represented as complete seasons.",
    "Date-only results become usable no earlier than the next UTC day and the pinned commit timestamp.", "",
    "Identity approval covers the exact proposed mappings and the stated 2021-01-01 to 2027-07-01 validity interval.",
    "Existing current club IDs are preserved; compatible canonical validity intervals extend to cover approved history.", "",
    "The frozen model policy compares club Elo plus negative-binomial goals against the venue-only negative-binomial incumbent.",
    "Calibration fitting, primary-view selection and outer assessment use separate chronological rows.",
    "Promotion requires all predeclared proper-score, breadth, uncertainty, coverage and integrity gates.",
    "The venue incumbent can be retained only when all absolute coverage and integrity gates pass.",
    "All 36 current clubs must have connected history before any forecasts are enabled.",
    "This review authorizes the source/mapping/policy inputs. Exact derived folds require their existing separate owner review before production fitting.", "",
    "Inspect source_coverage_summary.csv, current_club_history_coverage.csv and proposed_historical_club_identities.csv first.",
    "The exact acceptance payloads are proposed_history_sources.csv, proposed_history_scopes.csv and proposed_history_owner_review.csv.",
    "Frozen model inputs are data/club/model_protocol/{candidate,gate,seed}_registry.csv and data/club/production_protocol/production_recipe_v2.json."),
    file.path(review_root, "README.md"))
  policy_files <- c(file.path("data/club/model_protocol", c("candidate_registry.csv", "gate_registry.csv",
    "seed_registry.csv", "feature_contract.csv")),
    "data/club/production_protocol/production_recipe_v2.json")
  file.copy("data/club/model_protocol/policy_review.json", file.path(review_root, "policy_review_before.json"), overwrite = TRUE)
  package_files <- c(setdiff(list.files(review_root, full.names = TRUE),
    file.path(review_root, "review_manifest.json")), policy_files)
  manifest <- list(schema_version = "club-history-review-package-v1", decision = "pending",
    generated_at_utc = generated_at_utc, files = lapply(sort(package_files), function(path)
      list(path = path, sha256 = digest::digest(file = path, algo = "sha256", serialize = FALSE))))
  jsonlite::write_json(manifest, file.path(review_root, "review_manifest.json"), pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("HISTORY_REVIEW sources=%d regulation_results=%d aliases=%d current_clubs=%d/%d accepted_authority_mutated=false\n",
    nrow(inventory), sum(as.integer(scopes$selected_rows)), nrow(review),
    proposed$summary$current_clubs_covered, proposed$summary$current_club_count))
  invisible(files)
}

if (sys.nframe() == 0L) prepare_club_history_review()
