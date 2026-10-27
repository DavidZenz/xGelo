library(testthat)
history_proposal_test_root <- normalizePath(file.path(getwd(),
  if (basename(getwd()) == "testthat") "../.." else "."), winslash = "/", mustWork = TRUE)
for (path in c("R/common/phase18_canonical_hash.R", "R/club/identity.R",
    "R/club/identity_bootstrap.R", "R/club/history_identity_proposals.R"))
  source(file.path(history_proposal_test_root, path))

history_proposal_test_current <- function() data.frame(club_id = c("club_fd_5", "club_fd_108", "club_fd_57"),
  canonical_name = c("FC Bayern München", "FC Internazionale Milano", "Arsenal FC"),
  association_code = c("DEU", "ITA", "ENG"), stringsAsFactors = FALSE)

test_that("pending history proposals reuse unique current IDs and deterministically deduplicate aliases", {
  native <- data.frame(path = c("deutschland/2024-25/b.txt", "champions-league/2024-25/cl.txt",
      "italy/2024-25/i.txt", "italy/2025-26/i.txt", "england/2024-25/e.txt", "england/2025-26/e.txt"),
    raw_name = c("FC Bayern München", "Bayern München", "Inter", "FC Internazionale Milano", "Arsenal FC", "Newtown FC"),
    association_code = c("DEU", "DEU", "ITA", "ITA", "ENG", "ENG"), stringsAsFactors = FALSE)
  result <- phase18_propose_history_club_identities(native, history_proposal_test_current())
  expect_true(all(result$proposals$review_state == "pending"))
  expect_equal(result$summary$current_clubs_covered, 3L)
  expect_length(result$unresolved_current_clubs$club_id, 0L)
  expect_identical(unique(result$proposals$proposed_club_id[result$proposals$association_code == "DEU"]), "club_fd_5")
  expect_identical(unique(result$proposals$proposed_club_id[result$proposals$association_code == "ITA"]), "club_fd_108")
  expect_true("club_eng_newtown" %in% result$proposals$proposed_club_id)
  expect_identical(result, phase18_propose_history_club_identities(native[rev(seq_len(nrow(native))), ], history_proposal_test_current()))
})

test_that("country tags supply explicit CL association and source-name country collisions remain blocked", {
  root <- tempfile("native-proposals-")
  dir.create(file.path(root, "champions-league/2024-25"), recursive = TRUE)
  writeLines("    18:45  Bayern München (GER) v Inter (ITA) 2-0", file.path(root, "champions-league/2024-25/cl.txt"))
  native <- data.frame(path = "champions-league/2024-25/cl.txt", raw_name = c("Bayern München", "Inter"))
  result <- phase18_propose_history_club_identities(native, history_proposal_test_current(), root)
  expect_setequal(result$proposals$association_code, c("DEU", "ITA"))
  expect_true(all(result$proposals$association_evidence == "explicit_native_country_tag"))
  collision <- data.frame(path = c("england/a.txt", "france/b.txt"), raw_name = "United FC")
  blocked <- phase18_propose_history_club_identities(collision, history_proposal_test_current())
  expect_true(all(blocked$proposals$ambiguity == "source_name_cross_association_collision"))
  expect_true(all(blocked$proposals$confidence == "unresolved"))
  expect_equal(length(unique(blocked$proposals$proposed_club_id)), 2L)
})

test_that("pinned tokens produce exact pending review rows without approving or changing identities", {
  inventory <- data.frame(source_system = "openfootball", source_row = "match:1",
    event_at_utc = "2024-06-01T00:00:00Z", home_name = "Bayern München", away_name = "Inter")
  tokens <- phase18_extract_history_tokens(inventory)
  sources <- data.frame(evidence_sha256 = tokens$evidence_sha256,
    path = c("deutschland/2023-24/b.txt", "italy/2023-24/i.txt"))
  result <- phase18_propose_history_club_identities_from_tokens(tokens, history_proposal_test_current(), sources)
  review <- phase18_history_identity_pending_review(tokens, result$proposals, "pinned-history-1", "2026-10-27T00:00:00Z")
  expect_identical(names(review), phase18_club_review_schema())
  expect_true(all(review$review_state == "pending"))
  expect_true(all(review$reviewer == "pending_owner_review"))
  expect_identical(review$evidence_sha256, tokens$evidence_sha256)
  expect_silent(phase18_validate_club_identity_review(tokens, review))
  expect_error(phase18_propose_history_club_identities_from_tokens(tokens,
    history_proposal_test_current(), sources[-1L, ]), "missing")
  approved <- result$proposals
  approved$review_state <- "approved"
  expect_error(phase18_history_identity_pending_review(tokens, approved, "pinned", "2026-10-27T00:00:00Z"), "pending")
})

test_that("pending bridge seeds join LASK, Qarabag and current club spelling variants", {
  native <- data.frame(path = c("austria/2024-25/b.txt", "austria/2025-26/b.txt",
    "europe/azerbaijan/2024-25_az1.txt", "champions-league/2025-26/cl.txt",
    "espana/2025-26/b.txt", "france/2025-26/b.txt", "espana/2024-25/b.txt"),
    raw_name = c("LASK", "LASK Linz", "Qarabağ FK", "Qarabağ Ağdam FK", "Atlético de Madrid", "Lille", "Real Madrid C.F."),
    association_code = c("AUT", "AUT", "AZE", "AZE", "ESP", "FRA", "ESP"))
  current <- data.frame(club_id = c("club_fd_2016", "club_fd_78", "club_fd_521", "club_fd_86"),
    canonical_name = c("LASK Linz", "Club Atlético de Madrid", "Lille OSC", "Real Madrid CF"),
    association_code = c("AUT", "ESP", "FRA", "ESP"))
  result <- phase18_propose_history_club_identities(native, current)
  expect_equal(result$summary$current_clubs_covered, 4L)
  expect_identical(unique(result$proposals$proposed_club_id[result$proposals$association_code == "AUT"]), "club_fd_2016")
  expect_equal(length(unique(result$proposals$proposed_club_id[result$proposals$association_code == "AZE"])), 1L)
  expect_true(all(result$proposals$review_state == "pending"))
})

history_proposal_test_fixture_versions <- function() {
  modern <- data.frame(source_match_id = paste0("line_", 1:3), event_date = c("2024-05-01", "2024-05-08", "2024-05-15"),
    stage = "REGULAR_SEASON", status = "completed", home_name = c("Borussia Dortmund", "FC Bayern München", "Borussia Dortmund"),
    away_name = c("FC Bayern München", "Borussia Dortmund", "FC Bayern München"),
    score_text = c("1-0", "2-1", "0-0"), score_semantics = "regulation", stringsAsFactors = FALSE)
  old <- modern
  old$source_match_id <- paste0("old_line_", 1:3)
  old$home_name <- sub("Borussia Dortmund", "Bor. Dortmund", old$home_name, fixed = TRUE)
  old$away_name <- sub("Borussia Dortmund", "Bor. Dortmund", old$away_name, fixed = TRUE)
  list(old = old, modern = modern)
}

history_proposal_test_compare <- function(old, modern) phase18_history_fixture_alias_evidence(old, modern,
  "deutschland/2023-24/1-bundesliga.txt", paste(rep("a",64L), collapse=""), paste(rep("b",64L),collapse=""), "DEU")

test_that("old localized names gain pending evidence only from consistent uniquely matched fixtures", {
  versions <- history_proposal_test_fixture_versions()
  result <- history_proposal_test_compare(versions$old, versions$modern)
  expect_identical(result$aliases$source_name, "Bor. Dortmund")
  expect_identical(result$aliases$canonical_name, "Borussia Dortmund")
  expect_identical(result$aliases$unique_fixture_support, 3L)
  expect_true(all(result$evidence$review_state == "pending"))
  expect_identical(result$aliases$review_state, "pending")
  expect_setequal(result$evidence$side, c("home", "away"))
  expect_true(all(grepl("^[0-9a-f]{64}$", result$evidence$old_raw_sha256)))
  reordered <- history_proposal_test_compare(versions$old[3:1, ], versions$modern[c(2,1,3), ])
  expect_identical(result, reordered)
})

test_that("duplicate fixture keys, inconsistent sides and insufficient evidence do not yield aliases", {
  versions <- history_proposal_test_fixture_versions()
  old <- rbind(versions$old[1:2, ], versions$old[1L, ])
  result <- history_proposal_test_compare(old, versions$modern[1:2, ])
  expect_equal(result$summary$ambiguous_old_fixture_count, 2L)
  expect_equal(nrow(result$aliases), 0L)
  expect_true("insufficient_unique_fixture_support" %in% result$conflicts$reason_code)
  changed <- versions$modern
  changed$away_name[2L] <- "Another Club"
  result <- history_proposal_test_compare(versions$old, changed)
  expect_false("Bor. Dortmund" %in% result$aliases$source_name)
  expect_true("inconsistent_fixture_side_identity" %in% result$conflicts$reason_code)
  changed <- versions$modern
  changed$stage <- "PLAYOFFS"
  result <- history_proposal_test_compare(versions$old, changed)
  expect_equal(nrow(result$aliases), 0L)
  expect_equal(result$summary$unique_fixture_count, 0L)
})

test_that("all candidate versions coalesce legacy names through consistent latest-fixture evidence", {
  versions <- history_proposal_test_fixture_versions()
  make <- function(rows, hash, date, latest) {
    rows$source_path <- "deutschland/2023-24/1-bundesliga.txt"
    rows$raw_sha256 <- paste(rep(hash, 64L), collapse = "")
    rows$commit_utc <- date
    rows$is_latest_file_bytes <- latest
    rows
  }
  other <- versions$old
  other$home_name <- sub("Bor. Dortmund", "Dortmund BVB", other$home_name, fixed = TRUE)
  other$away_name <- sub("Bor. Dortmund", "Dortmund BVB", other$away_name, fixed = TRUE)
  rows <- rbind(make(versions$old, "a", "2024-05-20T00:00:00Z", FALSE),
    make(other, "b", "2024-06-01T00:00:00Z", FALSE),
    make(versions$modern, "c", "2026-01-01T00:00:00Z", TRUE))
  current <- data.frame(club_id = c("club_fd_4", "club_fd_5"),
    canonical_name = c("Borussia Dortmund", "FC Bayern München"), association_code = "DEU")
  result <- phase18_history_candidate_alias_proposals(rows, current)
  expect_equal(result$summary$candidate_version_count, 3L)
  expect_equal(result$summary$current_clubs_covered, 2L)
  expect_equal(result$summary$unresolved_proposal_count, 0L)
  expect_identical(unique(result$proposals$proposed_club_id[grepl("Dortmund", result$proposals$source_name)]), "club_fd_4")
  expect_true(all(result$candidate_alias_proposals$review_state == "pending"))
  expect_true(all(result$candidate_alias_evidence$review_state == "pending"))
  expect_identical(result, phase18_history_candidate_alias_proposals(rows[nrow(rows):1, ], current))
})

test_that("explicit pending cross-competition bridges preserve Greek and Belgian club identity", {
  native <- data.frame(path = c("europe/greece/a.txt", "champions-league/a.txt", "belgium/a.txt", "champions-league/b.txt"),
    raw_name = c("Olympiakos Piraeus", "PAE Olympiakos SFP", "Union Saint-Gilloise", "Royale Union Saint-Gilloise"),
    association_code = c("GRC", "GRC", "BEL", "BEL"))
  result <- phase18_propose_history_club_identities(native, history_proposal_test_current())
  expect_equal(length(unique(result$proposals$proposed_club_id[result$proposals$association_code == "GRC"])), 1L)
  expect_equal(length(unique(result$proposals$proposed_club_id[result$proposals$association_code == "BEL"])), 1L)
  expect_true(all(result$proposals$review_state == "pending"))
})
