phase12_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")
)

source(file.path(phase12_test_project_root, "R/release/release_bundle.R"), local = .GlobalEnv)
source(file.path(phase12_test_project_root, "R/release/release_install.R"), local = .GlobalEnv)
source(file.path(phase12_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)
