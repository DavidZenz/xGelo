library(testthat)

phase18_adversarial_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_adversarial_required_critical <- sprintf("CR-%02d", seq_len(15L))
phase18_adversarial_required_warnings <- sprintf("WR-%02d", seq_len(4L))

test_that("Phase 18 adversarial probe catalog is exact", {
  catalog <- phase18_adversarial_probe_catalog()
  expect_identical(catalog$critical, phase18_adversarial_required_critical)
  expect_identical(catalog$warnings, phase18_adversarial_required_warnings)
})
