library(testthat)

test_that("Phase 19 exposes the exact adversarial probe inventory", {
  expect_true(
    exists("phase19_adversarial_probe_inventory", mode = "function"),
    info = "The final Phase 19 gate requires a named public-boundary probe inventory"
  )
})
