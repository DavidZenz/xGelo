`%||%` <- function(x, y) if (is.null(x)) y else x

phase18_identity_test_root <- normalizePath(file.path(getwd(), "../.."), mustWork = TRUE)

phase18_identity_test_load <- function() {
  source(file.path(phase18_identity_test_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase18_identity_test_root, "R/club/identity.R"), local = .GlobalEnv)
  bootstrap <- file.path(phase18_identity_test_root, "R/club/identity_bootstrap.R")
  if (file.exists(bootstrap)) source(bootstrap, local = .GlobalEnv)
}

phase18_identity_test_empty <- function() {
  schemas <- phase18_club_registry_schemas()
  lapply(schemas, function(columns) {
    as.data.frame(setNames(replicate(length(columns), character(0), simplify = FALSE), columns),
      stringsAsFactors = FALSE, check.names = FALSE)
  })
}

phase18_identity_test_registry <- function() {
  registries <- phase18_identity_test_empty()
  registries$clubs <- data.frame(
    schema_version = "phase18-club-identity-1", club_id = "club_alpha",
    entity_kind = "club", canonical_name = "Alpha FC", association_code = "AUT",
    valid_from_utc = "2000-01-01T00:00:00Z", valid_to_utc = "",
    club_status = "active", row_sha256 = "", stringsAsFactors = FALSE
  )
  registries$source_ids <- data.frame(
    schema_version = "phase18-club-identity-1", club_id = "club_alpha",
    source_system = "provider", source_club_id = "101",
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", source_bundle_id = "bundle-1", row_sha256 = "",
    stringsAsFactors = FALSE
  )
  registries$aliases <- data.frame(
    schema_version = "phase18-club-identity-1", club_id = "club_alpha",
    source_system = "provider", alias = "Alpha FC", normalized_alias = "alpha fc",
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", reviewed_by = "owner",
    reviewed_at_utc = "2026-09-19T00:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE
  )
  phase18_hash_club_registry_rows(registries)
}

testthat::test_that("club registries expose exact separate schemas", {
  phase18_identity_test_load()
  schemas <- phase18_club_registry_schemas()
  testthat::expect_named(schemas, c("clubs", "source_ids", "aliases"))
  testthat::expect_true(all(c("club_id", "entity_kind", "row_sha256") %in% schemas$clubs))
  testthat::expect_true(all(c("source_system", "source_club_id") %in% schemas$source_ids))
  testthat::expect_true(all(c("normalized_alias", "reviewed_by") %in% schemas$aliases))
  testthat::expect_false(any(grepl("team_id|fifa_code", unlist(schemas))))
})

testthat::test_that("source scoped club ID resolves with provider display evidence", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  testthat::expect_silent(phase18_validate_club_registries(registries))
  result <- phase18_resolve_club_identity(
    registries, "provider", "101", "Alpha FC", "2026-09-19T12:00:00Z"
  )
  testthat::expect_identical(result$club_id[[1L]], "club_alpha")
  testthat::expect_identical(result$resolution_method[[1L]], "source_id")
  testthat::expect_identical(result$source_display_name[[1L]], "Alpha FC")
  testthat::expect_match(result$registry_sha256[[1L]], "^[0-9a-f]{64}$")
})

testthat::test_that("empty and cross-domain inputs fail with typed reasons", {
  phase18_identity_test_load()
  empty <- phase18_identity_test_empty()
  testthat::expect_silent(phase18_validate_club_registries(empty))
  testthat::expect_error(
    phase18_resolve_club_identity(empty, "provider", "101", "Alpha FC", "2026-09-19T12:00:00Z"),
    class = "unresolved_empty_registry"
  )
  registries <- phase18_identity_test_registry()
  testthat::expect_error(
    phase18_resolve_club_identity(registries, NA_character_, "101", "Alpha FC", "2026-09-19T12:00:00Z"),
    class = "invalid_club_identity_input"
  )
  registries$clubs$club_id <- "team_alpha"
  registries$source_ids$club_id <- "team_alpha"
  registries$aliases$club_id <- "team_alpha"
  registries <- phase18_hash_club_registry_rows(registries)
  testthat::expect_error(phase18_validate_club_registries(registries), class = "cross_domain_club_identity")
})

testthat::test_that("half-open boundaries assign an instant only to the adjacent row", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  old <- registries$source_ids
  old$valid_to_utc <- "2025-01-01T00:00:00Z"
  new <- old
  new$valid_from_utc <- "2025-01-01T00:00:00Z"
  new$valid_to_utc <- ""
  registries$source_ids <- rbind(old, new)
  registries <- phase18_hash_club_registry_rows(registries)
  testthat::expect_silent(phase18_validate_club_registries(registries))
  at_boundary <- phase18_resolve_club_identity(
    registries, "provider", "101", "Alpha FC", "2025-01-01T00:00:00Z"
  )
  testthat::expect_identical(at_boundary$club_id[[1L]], "club_alpha")
})

testthat::test_that("reviewed alias fallback is exact, normalized, and time bounded", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  result <- phase18_resolve_club_identity(
    registries, "provider", "missing", "Álpha---FC", "2026-09-19T12:00:00Z"
  )
  testthat::expect_identical(result$club_id[[1L]], "club_alpha")
  testthat::expect_identical(result$resolution_method[[1L]], "reviewed_alias")
  testthat::expect_identical(result$resolution_warning[[1L]], "reviewed_alias_fallback")

  registries$aliases$valid_to_utc <- "2024-01-01T00:00:00Z"
  registries <- phase18_hash_club_registry_rows(registries)
  testthat::expect_error(
    phase18_resolve_club_identity(registries, "provider", "missing", "Alpha FC", "2024-01-01T00:00:00Z"),
    class = "expired_club_alias"
  )
})

testthat::test_that("overlaps, exact duplicates, and pending aliases fail closed", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  duplicate <- registries
  duplicate$aliases <- rbind(duplicate$aliases, duplicate$aliases)
  duplicate <- phase18_hash_club_registry_rows(duplicate)
  testthat::expect_error(phase18_validate_club_registries(duplicate), class = "duplicate_club_identity")

  overlap <- registries
  second <- overlap$aliases
  second$valid_from_utc <- "2022-01-01T00:00:00Z"
  overlap$aliases$valid_to_utc <- "2025-01-01T00:00:00Z"
  overlap$aliases <- rbind(overlap$aliases, second)
  overlap <- phase18_hash_club_registry_rows(overlap)
  testthat::expect_error(phase18_validate_club_registries(overlap), class = "overlapping_club_identity")

  pending <- registries
  pending$aliases$review_state <- "pending"
  pending <- phase18_hash_club_registry_rows(pending)
  testthat::expect_error(phase18_validate_club_registries(pending), class = "unreviewed_club_identity")
})

testthat::test_that("source ID and reviewed name disagreement is typed", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  beta <- registries$clubs
  beta$club_id <- "club_beta"
  beta$canonical_name <- "Beta FC"
  registries$clubs <- rbind(registries$clubs, beta)
  beta_alias <- registries$aliases
  beta_alias$club_id <- "club_beta"
  beta_alias$alias <- "Beta FC"
  beta_alias$normalized_alias <- "beta fc"
  registries$aliases <- rbind(registries$aliases, beta_alias)
  registries <- phase18_hash_club_registry_rows(registries)
  testthat::expect_error(
    phase18_resolve_club_identity(registries, "provider", "101", "Beta FC", "2026-09-19T12:00:00Z"),
    class = "club_identity_disagreement"
  )
})

testthat::test_that("registry hash and resolution are invariant to row order", {
  phase18_identity_test_load()
  registries <- phase18_identity_test_registry()
  beta <- registries$clubs
  beta$club_id <- "club_beta"
  beta$canonical_name <- "Beta FC"
  beta_source <- registries$source_ids
  beta_source$club_id <- "club_beta"
  beta_source$source_club_id <- "202"
  beta_alias <- registries$aliases
  beta_alias$club_id <- "club_beta"
  beta_alias$alias <- "Beta FC"
  beta_alias$normalized_alias <- "beta fc"
  registries$clubs <- rbind(registries$clubs, beta)
  registries$source_ids <- rbind(registries$source_ids, beta_source)
  registries$aliases <- rbind(registries$aliases, beta_alias)
  registries <- phase18_hash_club_registry_rows(registries)
  reversed <- lapply(registries, function(table) table[rev(seq_len(nrow(table))), , drop = FALSE])
  testthat::expect_identical(phase18_club_registry_hash(registries), phase18_club_registry_hash(reversed))
  one <- phase18_resolve_club_identity(registries, "provider", "202", "Beta FC", "2026-09-19T12:00:00Z")
  two <- phase18_resolve_club_identity(reversed, "provider", "202", "Beta FC", "2026-09-19T12:00:00Z")
  testthat::expect_identical(one, two)
})

phase18_identity_test_tokens <- function() {
  current <- data.frame(
    source_system = "provider", source_club_id = c("101", "202"),
    display_name = c("Alpha FC", "Beta FC"),
    event_at_utc = c("2026-09-19T12:00:00Z", "2026-09-19T12:00:00Z"),
    source_row = c("clubs:1", "clubs:2"), stringsAsFactors = FALSE
  )
  history <- data.frame(
    source_system = "openfootball", source_row = "history:1",
    event_at_utc = "2020-01-01T00:00:00Z",
    home_name = "Alpha FC", away_name = "Beta FC", stringsAsFactors = FALSE
  )
  phase18_extract_club_tokens(current, history)
}

phase18_identity_test_review <- function(tokens) {
  data.frame(
    corpus = tokens$corpus,
    source_system = tokens$source_system,
    source_row = tokens$source_row,
    source_club_id = tokens$source_club_id,
    display_value = tokens$display_value,
    evidence_sha256 = tokens$evidence_sha256,
    club_id = ifelse(grepl("alpha", tokens$normalized_display), "club_alpha", "club_beta"),
    entity_kind = "club",
    canonical_name = ifelse(grepl("alpha", tokens$normalized_display), "Alpha FC", "Beta FC"),
    association_code = "AUT",
    valid_from_utc = "2000-01-01T00:00:00Z", valid_to_utc = "",
    reviewer = "owner", reviewed_at_utc = "2026-09-19T00:00:00Z",
    review_state = "approved", source_bundle_id = "review-fixture-v1",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

testthat::test_that("current and historical extraction emits stable evidence without identity suggestions", {
  phase18_identity_test_load()
  tokens <- phase18_identity_test_tokens()
  testthat::expect_equal(nrow(tokens), 4L)
  testthat::expect_setequal(tokens$corpus, c("current_ucl", "historical_inventory"))
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", tokens$evidence_sha256)))
  testthat::expect_false("club_id" %in% names(tokens))
  reversed <- phase18_extract_club_tokens(
    data.frame(
      source_system = "provider", source_club_id = c("202", "101"),
      display_name = c("Beta FC", "Alpha FC"),
      event_at_utc = "2026-09-19T12:00:00Z", source_row = c("clubs:2", "clubs:1")
    ),
    data.frame(
      source_system = "openfootball", source_row = "history:1",
      event_at_utc = "2020-01-01T00:00:00Z", home_name = "Alpha FC", away_name = "Beta FC"
    )
  )
  testthat::expect_identical(tokens, reversed)
})

testthat::test_that("only complete approved owner mappings update registries", {
  phase18_identity_test_load()
  tokens <- phase18_identity_test_tokens()
  review <- phase18_identity_test_review(tokens)
  empty <- phase18_identity_test_empty()
  applied <- phase18_apply_club_identity_review(tokens, review, empty)
  testthat::expect_equal(nrow(applied$registries$clubs), 2L)
  testthat::expect_equal(nrow(applied$unresolved), 0L)
  testthat::expect_silent(phase18_validate_club_registries(applied$registries))

  partial <- review[-1L, , drop = FALSE]
  blocked <- phase18_apply_club_identity_review(tokens, partial, empty)
  testthat::expect_equal(nrow(blocked$unresolved), 1L)
  testthat::expect_identical(blocked$unresolved$blocked_reason[[1L]], "missing_owner_review")

  cross_domain <- review
  cross_domain$club_id[[1L]] <- "team_alpha"
  testthat::expect_error(
    phase18_apply_club_identity_review(tokens, cross_domain, empty),
    class = "cross_domain_club_identity"
  )
})

testthat::test_that("review application is replay-safe and conflicting updates are atomic", {
  phase18_identity_test_load()
  tokens <- phase18_identity_test_tokens()
  review <- phase18_identity_test_review(tokens)
  first <- phase18_apply_club_identity_review(tokens, review, phase18_identity_test_empty())
  replay <- phase18_apply_club_identity_review(tokens, review, first$registries)
  testthat::expect_identical(
    phase18_club_registry_hash(first$registries),
    phase18_club_registry_hash(replay$registries)
  )
  conflict <- review
  conflict$club_id[conflict$source_club_id == "101"] <- "club_beta"
  testthat::expect_error(
    phase18_apply_club_identity_review(tokens, conflict, first$registries),
    class = "club_identity_review_conflict"
  )
  testthat::expect_identical(first$registries, first$registries)
})

testthat::test_that("current and historical coverage gates block independently", {
  phase18_identity_test_load()
  tokens <- phase18_identity_test_tokens()
  review <- phase18_identity_test_review(tokens)
  complete <- phase18_apply_club_identity_review(tokens, review, phase18_identity_test_empty())
  report <- phase18_validate_identity_bootstrap(
    complete,
    current_expectations = list(required = TRUE, expected_tokens = 2L),
    history_expectations = list(required = TRUE, expected_tokens = 2L)
  )
  testthat::expect_true(all(report$status == "complete"))

  partial <- phase18_apply_club_identity_review(tokens, review[-1L, , drop = FALSE], phase18_identity_test_empty())
  testthat::expect_error(
    phase18_validate_identity_bootstrap(
      partial,
      current_expectations = list(required = TRUE, expected_tokens = 2L),
      history_expectations = list(required = TRUE, expected_tokens = 2L)
    ),
    class = "club_identity_bootstrap_blocked"
  )
})

testthat::test_that("atomic registry writer preserves incumbent bytes on invalid candidate", {
  phase18_identity_test_load()
  root <- tempfile("phase18-club-registry-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  incumbent <- phase18_identity_test_registry()
  phase18_write_club_registries_atomic(incumbent, root)
  paths <- file.path(root, c("clubs.csv", "club_source_ids.csv", "club_aliases.csv"))
  before <- lapply(paths, readBin, what = "raw", n = 100000L)
  invalid <- incumbent
  invalid$aliases$club_id <- "club_unknown"
  invalid <- phase18_hash_club_registry_rows(invalid)
  testthat::expect_error(
    phase18_write_club_registries_atomic(invalid, root),
    class = "unknown_club_identity"
  )
  after <- lapply(paths, readBin, what = "raw", n = 100000L)
  testthat::expect_identical(after, before)
})
