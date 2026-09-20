library(testthat)

phase18_canonical_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

phase18_canonical_test_load <- function() {
  source(
    file.path(phase18_canonical_test_root, "R/common/phase18_canonical_hash.R"),
    local = .GlobalEnv
  )
  invisible(TRUE)
}

test_that("canonical v2 exports the isolated primitive API", {
  phase18_canonical_test_load()
  expect_identical(phase18_canonical_encoding_v2(), "phase18-canonical-v2")
  expect_true(all(vapply(
    c(
      "phase18_hash_scalar_v2", "phase18_hash_sequence_v2",
      "phase18_hash_row_v2", "phase18_hash_table_v2"
    ),
    exists,
    logical(1),
    mode = "function"
  )))
})

test_that("length-prefixed row encoding rejects the reproduced delimiter collision", {
  phase18_canonical_test_load()
  left <- data.frame(first = "x|y", second = "z", stringsAsFactors = FALSE)
  right <- data.frame(first = "x", second = "y|z", stringsAsFactors = FALSE)

  expect_false(identical(
    phase18_hash_row_v2(left, schema_tag = "collision-probe-v1"),
    phase18_hash_row_v2(right, schema_tag = "collision-probe-v1")
  ))
})

test_that("scalar framing distinguishes missing empty controls names types and UTF-8 bytes", {
  phase18_canonical_test_load()
  scalar <- function(value, field = "value", type = "character") {
    phase18_hash_scalar_v2(value, field_name = field, type_tag = type)
  }

  cases <- c(
    missing = scalar(NA_character_),
    empty = scalar(""),
    unit_separator = scalar("a\x1fb"),
    record_separator = scalar("a\x1eb"),
    newline = scalar("a\nb"),
    nul_equivalent = scalar("a\\0b"),
    renamed = scalar("x", field = "renamed"),
    textual_true = scalar("true"),
    logical_true = scalar(TRUE, type = "logical"),
    textual_one = scalar("1"),
    integer_one = scalar(1L, type = "integer"),
    double_one = scalar(1, type = "double"),
    composed = scalar("\u00e9"),
    decomposed = scalar("e\u0301")
  )

  expect_true(all(grepl("^[0-9a-f]{64}$", cases)))
  expect_equal(anyDuplicated(unname(cases)), 0L)
  expect_identical(scalar("same"), scalar(enc2utf8("same")))
})

test_that("row schema and table multiplicity are bound while row order is canonical", {
  phase18_canonical_test_load()
  original <- data.frame(
    id = c(2L, 1L),
    value = c("beta", "alpha"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  reordered <- original[2:1, , drop = FALSE]
  duplicate <- rbind(original, original[1L, , drop = FALSE])
  renamed <- original
  names(renamed)[[2L]] <- "label"
  retyped <- original
  retyped$id <- as.double(retyped$id)

  hash <- function(data, tag = "table-contract-v1") {
    phase18_hash_table_v2(data, key = "id", schema_tag = tag)
  }

  expect_identical(hash(original), hash(reordered))
  expect_false(identical(hash(original), hash(duplicate)))
  expect_false(identical(hash(original), hash(renamed)))
  expect_false(identical(hash(original), hash(retyped)))
  expect_false(identical(hash(original), hash(original, "table-contract-v2")))
})
