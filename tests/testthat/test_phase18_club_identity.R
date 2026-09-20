`%||%` <- function(x, y) if (is.null(x)) y else x

phase18_identity_test_root <- normalizePath(file.path(getwd(), "../.."), mustWork = TRUE)

phase18_identity_test_load <- function() {
  source(file.path(phase18_identity_test_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase18_identity_test_root, "R/club/identity.R"), local = .GlobalEnv)
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
