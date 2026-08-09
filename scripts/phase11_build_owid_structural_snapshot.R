#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

project_root <- normalizePath(".", mustWork = TRUE)
source(file.path(project_root, "R", "forecast", "structural_prior.R"), local = .GlobalEnv)

if (!requireNamespace("digest", quietly = TRUE)) {
  stop("digest is required to build the OWID structural snapshot", call. = FALSE)
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
}

source_dir <- file.path(project_root, "data", "benchmark", "phase11", "owid_sources")
snapshot_path <- file.path(project_root, "data", "benchmark", "phase11", "structural_sources.csv")
metadata_path <- file.path(project_root, "data", "benchmark", "phase11", "structural_sources_metadata.csv")
checksums_path <- file.path(project_root, "data", "benchmark", "phase11", "structural_sources_checksums.csv")
mapping_path <- file.path(project_root, "data", "benchmark", "phase11", "structural_source_country_mapping.csv")

gdp_path <- file.path(source_dir, "gdp-per-capita-maddison-project-database.csv")
population_path <- file.path(source_dir, "population.csv")
if (!all(file.exists(c(gdp_path, population_path)))) {
  stop("Frozen OWID source snapshots are missing", call. = FALSE)
}

teams <- read_csv(file.path(project_root, "data", "benchmark", "phase09", "teams.csv"))
required_team_columns <- c("fifa_code", "canonical_name")
if (!all(required_team_columns %in% names(teams))) {
  stop("Phase 09 team registry is missing required columns", call. = FALSE)
}

owid_entities <- c(
  ALB = "Albania", ALG = "Algeria", ANG = "Angola", ARG = "Argentina",
  AUS = "Australia", AUT = "Austria", BEL = "Belgium", BIH = "Bosnia and Herzegovina",
  BRA = "Brazil", BUL = "Bulgaria", CMR = "Cameroon", CAN = "Canada",
  CHI = "Chile", CHN = "China", COL = "Colombia", CRC = "Costa Rica",
  CRO = "Croatia", CZE = "Czechia", DEN = "Denmark", ECU = "Ecuador",
  EGY = "Egypt", ENG = "United Kingdom", FIN = "Finland", FRA = "France",
  GEO = "Georgia", GER = "Germany", GHA = "Ghana", GRE = "Greece",
  HON = "Honduras", HUN = "Hungary", ISL = "Iceland", IRN = "Iran",
  NIR = "United Kingdom", ITA = "Italy", CIV = "Cote d'Ivoire", JPN = "Japan",
  PRK = "North Korea", KOR = "South Korea", LVA = "Latvia", MKD = "North Macedonia",
  MEX = "Mexico", MAR = "Morocco", NED = "Netherlands", NZL = "New Zealand",
  NGA = "Nigeria", PAN = "Panama", PAR = "Paraguay", PER = "Peru",
  POL = "Poland", POR = "Portugal", QAT = "Qatar", IRL = "Ireland",
  ROU = "Romania", RUS = "Russia", KSA = "Saudi Arabia", SCO = "United Kingdom",
  SEN = "Senegal", SRB = "Serbia", SVK = "Slovakia", SVN = "Slovenia",
  RSA = "South Africa", ESP = "Spain", SWE = "Sweden", SUI = "Switzerland",
  TOG = "Togo", TRI = "Trinidad and Tobago", TUN = "Tunisia", TUR = "Turkey",
  UKR = "Ukraine", USA = "United States", URU = "Uruguay", WAL = "United Kingdom"
)

teams$fifa_code <- toupper(trimws(as.character(teams$fifa_code)))
if (anyDuplicated(teams$fifa_code) || !setequal(teams$fifa_code, names(owid_entities))) {
  stop("OWID structural mapping does not match the exact 72-team panel", call. = FALSE)
}

gdp <- read_csv(gdp_path)
population <- read_csv(population_path)
required_gdp <- c("Entity", "Code", "Year", "GDP per capita")
required_population <- c("Entity", "Code", "Year", "Population")
if (!all(required_gdp %in% names(gdp)) || !all(required_population %in% names(population))) {
  stop("OWID source snapshot schema is not recognized", call. = FALSE)
}

gdp2000 <- gdp[gdp$Year == 2000L, c("Entity", "Code", "Year", "GDP per capita"), drop = FALSE]
population2000 <- population[population$Year == 2000L, c("Entity", "Code", "Year", "Population"), drop = FALSE]

resolve_source <- function(data, entity, value_column) {
  rows <- data[data$Entity == entity, , drop = FALSE]
  if (nrow(rows) != 1L || is.na(rows[[value_column]][[1L]]) || !is.finite(as.numeric(rows[[value_column]][[1L]])) ||
      as.numeric(rows[[value_column]][[1L]]) <= 0) {
    stop("OWID source is missing one positive 2000 value for entity: ", entity, call. = FALSE)
  }
  rows[1L, , drop = FALSE]
}

mapping <- teams[, c("fifa_code", "canonical_name"), drop = FALSE]
names(mapping) <- c("project_fifa_code", "project_team_name")
mapping$owid_entity <- unname(owid_entities[mapping$project_fifa_code])
mapping$owid_code <- vapply(mapping$owid_entity, function(entity) {
  rows <- gdp2000[gdp2000$Entity == entity, , drop = FALSE]
  if (nrow(rows) != 1L) stop("OWID GDP source has no unique entity code for: ", entity, call. = FALSE)
  as.character(rows$Code[[1L]])
}, character(1))
mapping$mapping_rule <- "Project FIFA code joins to OWID entity; England, Northern Ireland, Scotland, and Wales use United Kingdom country-level structural values."
mapping$source_url_or_label <- "https://ourworldindata.org/grapher/gdp-per-capita-maddison-project-database"
mapping$parent_source_sha256 <- digest::digest(mapping, algo = "sha256", serialize = TRUE)
mapping$row_sha256 <- .structural_prior_row_hash(mapping, "row_sha256")
write_csv(mapping, mapping_path)
mapping_sha256 <- digest::digest(mapping_path, algo = "sha256", file = TRUE)

vintage_id <- "owid_maddison2023_wpp2024_2000_v1"
snapshot_date <- as.Date("2024-07-15")
retrieved_at <- "2026-08-09T00:00:00Z"
gdp_parent_sha256 <- digest::digest(gdp_path, algo = "sha256", file = TRUE)
population_parent_sha256 <- digest::digest(population_path, algo = "sha256", file = TRUE)

make_rows <- function(source, value_column, indicator_id, indicator_name, indicator_definition,
                      source_vintage, source_date, source_url, parent_hash) {
  rows <- lapply(seq_len(nrow(mapping)), function(index) {
    source_row <- resolve_source(source, mapping$owid_entity[[index]], value_column)
    data.frame(
      country_iso3 = mapping$project_fifa_code[[index]],
      country_name = mapping$project_team_name[[index]],
      indicator_id = indicator_id,
      indicator_name = indicator_name,
      indicator_definition = indicator_definition,
      source_year = 2000L,
      snapshot_year = 2000L,
      source_date = source_date,
      vintage_id = vintage_id,
      value = as.numeric(source_row[[value_column]][[1L]]),
      transformation = "log_then_cross_country_z_score_in_prior",
      source_name = "Our World in Data",
      source_url_or_label = source_url,
      source_vintage = source_vintage,
      license_class = "open-or-derived-open",
      retrieved_at_utc = retrieved_at,
      parent_source_sha256 = parent_hash,
      row_sha256 = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  output$row_sha256 <- .structural_prior_row_hash(output, "row_sha256")
  output
}

snapshot <- rbind(
  make_rows(
    gdp2000, "GDP per capita", "OWID.MADDISON.GDP.PCAP",
    "GDP per capita (constant 2011 international $)",
    "GDP per capita from the Maddison Project Database 2023, expressed in constant 2011 international dollars.",
    "Maddison Project Database 2023", snapshot_date,
    "https://ourworldindata.org/grapher/gdp-per-capita-maddison-project-database",
    gdp_parent_sha256
  ),
  make_rows(
    population2000, "Population", "OWID.UN.WPP.POP",
    "Population, total",
    "Total population from the United Nations World Population Prospects 2024 series published by Our World in Data.",
    "UN World Population Prospects 2024", snapshot_date,
    "https://ourworldindata.org/grapher/population",
    population_parent_sha256
  )
)
snapshot <- snapshot[order(snapshot$country_iso3, snapshot$indicator_id), , drop = FALSE]
row.names(snapshot) <- NULL
write_csv(snapshot, snapshot_path)

metadata <- data.frame(
  vintage_id = vintage_id,
  snapshot_year = 2000L,
  source_date = snapshot_date,
  source_name = "Our World in Data",
  source_url_or_label = "https://ourworldindata.org/grapher/",
  license_class = "open-or-derived-open",
  indicator_definition = "OWID Maddison Project Database 2023 GDP per capita plus OWID UN World Population Prospects 2024 population; both are used only as HGR-inspired structural prior inputs.",
  transformation_policy = "Retain 2000 values; prior computes log values, cross-country z-scores, and exp(0.15 * mean z).",
  acquisition_note = paste(
    "Frozen local OWID Grapher CSV snapshots; GDP chart metadata last updated 2024-04-26 and population chart metadata last updated 2024-07-15.",
    "Project FIFA aliases are mapped explicitly in structural_source_country_mapping.csv; UK constituent teams use United Kingdom country-level values.",
    "Source CSV SHA-256 parents:", gdp_parent_sha256, population_parent_sha256,
    "Mapping SHA-256:", mapping_sha256,
    "Benchmark execution reads only these committed local artifacts and performs no network access.",
    sep = " "
  ),
  source_gdp_sha256 = gdp_parent_sha256,
  source_population_sha256 = population_parent_sha256,
  mapping_sha256 = mapping_sha256,
  row_sha256 = "",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
metadata$row_sha256 <- .structural_prior_row_hash(metadata, "row_sha256")
write_csv(metadata, metadata_path)

snapshot_read <- read_csv(snapshot_path)
metadata_read <- read_csv(metadata_path)
checksums <- data.frame(
  artifact_path = c(
    "structural_sources.csv", "structural_sources_metadata.csv", "structural_sources_rows",
    "structural_source_country_mapping.csv",
    "owid_sources/gdp-per-capita-maddison-project-database.csv", "owid_sources/population.csv",
    "owid_sources/gdp-per-capita-maddison-project-database.metadata.json", "owid_sources/population.metadata.json"
  ),
  artifact_kind = c(
    "snapshot", "metadata", "canonical_row_set", "mapping",
    "upstream_source_snapshot", "upstream_source_snapshot", "upstream_source_metadata", "upstream_source_metadata"
  ),
  sha256 = c(
    digest::digest(snapshot_path, algo = "sha256", file = TRUE),
    digest::digest(metadata_path, algo = "sha256", file = TRUE),
    .structural_prior_checksum_row_set(snapshot_read),
    mapping_sha256,
    gdp_parent_sha256,
    population_parent_sha256,
    digest::digest(file.path(source_dir, "gdp-per-capita-maddison-project-database.metadata.json"), algo = "sha256", file = TRUE),
    digest::digest(file.path(source_dir, "population.metadata.json"), algo = "sha256", file = TRUE)
  ),
  vintage_id = vintage_id,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
write_csv(checksums, checksums_path)

loaded <- load_structural_prior_snapshots(
  snapshot_path = snapshot_path,
  metadata_path = metadata_path,
  checksums_path = checksums_path,
  evidence_cutoff_exclusive = as.Date("2026-06-05"),
  registered_vintage_id = vintage_id
)
stopifnot(
  nrow(loaded) == 144L,
  length(unique(loaded$country_iso3)) == 72L,
  length(unique(loaded$indicator_id)) == 2L,
  !anyNA(loaded$value),
  all(loaded$license_class == "open-or-derived-open"),
  any(loaded$country_iso3 == "PRK")
)

cat("Built and validated OWID structural snapshot:\n")
cat("  vintage:", vintage_id, "\n")
cat("  teams:", length(unique(loaded$country_iso3)), "\n")
cat("  rows:", nrow(loaded), "\n")
cat("  indicators:", paste(unique(loaded$indicator_id), collapse = ", "), "\n")
cat("  PRK GDP:", loaded$value[loaded$country_iso3 == "PRK" & loaded$indicator_id == "OWID.MADDISON.GDP.PCAP"], "\n")
cat("  PRK population:", loaded$value[loaded$country_iso3 == "PRK" & loaded$indicator_id == "OWID.UN.WPP.POP"], "\n")
