#!/usr/bin/env Rscript

# Keep the final source's regulation results, but bind each one to the earliest
# retained Git snapshot that actually contains that same fixture and result.
# Identity suggestions remain pending: this prepares review evidence only.
for (path in c("R/common/phase18_canonical_hash.R", "R/club/identity.R", "R/club/history_contract.R",
  "R/club/openfootball_parser.R", "R/club/history_ingestion.R")) source(path)

select_first_observed_club_history <- function(
    root = "data/club/local_raw/pin_candidates",
    proposal_path = file.path(root, "all_candidate_identity_proposals.csv")) {
  candidates <- phase18_history_read_csv(file.path(root, "candidates.csv"))
  rows <- phase18_history_read_csv(file.path(root, "candidate_rows.csv"))
  proposed <- phase18_history_read_csv(proposal_path)
  if (any(nzchar(proposed$ambiguity)) || anyDuplicated(proposed$source_club_id))
    stop("First-observation selection requires one unambiguous pending identity per source name")
  identify <- function(value) proposed$proposed_club_id[match(phase18_normalize_club_name(value), proposed$normalized_name)]
  rows$home_club_id <- identify(rows$home_name); rows$away_club_id <- identify(rows$away_name)
  if (anyNA(rows[c("home_club_id", "away_club_id")])) stop("Candidate row lacks pending identity evidence")
  parent <- match(paste(rows$source_path, rows$raw_sha256), paste(candidates$source_path, candidates$raw_sha256))
  if (anyNA(parent)) stop("Parsed candidate has no exact pinned parent")
  rows$competition_id <- candidates$competition_id[parent]; rows$season_id <- candidates$season_id[parent]
  rows$commit_utc <- candidates$commit_utc[parent]; rows$commit_sha <- candidates$commit_sha[parent]
  rows$parent_index <- parent
  stages <- c("REGULAR_SEASON", "CHAMPIONSHIP_LEAGUE_STAGE", "RELEGATION_LEAGUE_STAGE", "EUROPE_LEAGUE_STAGE")
  ucl <- rows$competition_id == "ucl"
  keep <- rows$status == "completed" & rows$score_semantics == "regulation" &
    rows$commit_utc >= paste0(rows$event_date, "T00:00:00Z") &
    ((!ucl & rows$stage %in% stages) | (ucl & rows$stage %in% c("GROUP_STAGE", "LEAGUE_STAGE")))
  rows <- rows[keep, , drop = FALSE]
  key <- function(data) do.call(paste, c(data[c("competition_id", "season_id", "event_date", "home_club_id", "away_club_id")], sep = "\037"))
  rows$fixture_key <- key(rows)
  targets <- rows[tolower(candidates$is_latest_file_bytes[rows$parent_index]) == "true", , drop = FALSE]
  if (anyDuplicated(targets$fixture_key)) stop("Latest native corpus has duplicate proposed canonical fixtures")
  j <- match(rows$fixture_key, targets$fixture_key)
  matches_final <- !is.na(j) & rows$score_text == targets$score_text[j]
  eligible <- rows[matches_final, , drop = FALSE]
  eligible <- eligible[order(eligible$commit_utc, eligible$commit_sha, eligible$source_match_id, method = "radix"), ]
  selected <- eligible[!duplicated(eligible$fixture_key), , drop = FALSE]
  if (nrow(selected) != nrow(targets) || !setequal(selected$fixture_key, targets$fixture_key))
    stop("First-observation selection must retain every final supported fixture exactly once")
  groups <- split(seq_len(nrow(selected)), selected$parent_index)
  output <- lapply(groups, function(indices) {
    row <- candidates[selected$parent_index[indices[[1L]]], , drop = FALSE]
    row$source_id <- paste(row$competition_id, row$season_id, substr(row$raw_sha256, 1L, 12L), sep = "-")
    row$selected_source_match_ids <- paste(sort(selected$source_match_id[indices], method = "radix"), collapse = "|")
    row$selected_regulation_results <- as.character(length(indices))
    row$selection_state <- "pending_first_observed_final_regulation_results"
    row
  })
  output <- do.call(rbind, output)
  output <- output[order(output$source_id, method = "radix"), , drop = FALSE]; rownames(output) <- NULL
  utils::write.csv(output, file.path(root, "first_observed_selections.csv"), row.names = FALSE)
  ledger <- selected[, c("competition_id", "season_id", "event_date", "home_club_id", "away_club_id", "home_name", "away_name",
    "score_text", "source_path", "source_match_id", "commit_sha", "commit_utc", "raw_sha256")]
  ledger$source_id <- paste(ledger$competition_id, ledger$season_id, substr(ledger$raw_sha256, 1L, 12L), sep = "-")
  ledger <- ledger[order(ledger$source_id, ledger$source_match_id, method = "radix"), ]
  utils::write.csv(ledger, file.path(root, "first_observed_match_ledger.csv"), row.names = FALSE)
  cat(sprintf("FIRST_OBSERVED_REVIEW pinned_snapshots=%d final_results=%d source_files=%d earliest_pin=%s latest_pin=%s\n",
    nrow(output), nrow(ledger), length(unique(ledger$source_path)), min(output$commit_utc), max(output$commit_utc)))
  invisible(list(selections = output, ledger = ledger))
}

if (sys.nframe() == 0L) select_first_observed_club_history()
