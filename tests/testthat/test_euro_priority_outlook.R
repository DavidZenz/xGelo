library(testthat)

euro_priority_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
euro_priority_api <- function() {
  api <- new.env(parent = globalenv())
  for (file in c("R/competition/publication_hashes.R", "R/competition/source_contracts.R",
                 "R/competition/uefa_euro_priority.R", "R/competition/uefa_nations_league_rules.R",
                 "R/competition/standings.R", "R/competition/uefa_nations_league_simulation.R",
                 "R/competition/uefa_nations_league_outcomes.R", "R/dashboard/payload_contract.R",
                 "R/dashboard/payload_nations_league.R", "R/dashboard/renderer.R", "R/dashboard/publication.R")) sys.source(file.path(euro_priority_root, file), api)
  api
}
euro_priority_interim <- function() {
  rank <- 1:54
  league <- ifelse(rank <= 16, "A", ifelse(rank <= 32, "B", ifelse(rank <= 48, "C", "D")))
  data.frame(team_id = paste0("team_", rank), league = league,
    group_id = paste0(league, ifelse(rank <= 48, (rank - 1) %% 4 + 1, (rank - 49) %% 2 + 1)),
    group_position = ifelse(rank <= 48, ((rank - 1) %% 16) %/% 4 + 1, (rank - 49) %/% 2 + 1),
    interim_rank = rank, final_overall_rank = rev(rank), ordering_status = "ready", stringsAsFactors = FALSE)
}

test_that("Article 16 policy is pinned separately and mirrors evidence", {
  api <- euro_priority_api()
  evidence <- jsonlite::fromJSON(file.path(euro_priority_root, "data/competition/rules/euro_2028_nl_priority_policy_v1.json"))
  expect_equal(evidence, api$uefa_euro_priority_policy())
  expect_match(api$uefa_euro_priority_policy_sha256(), "^[0-9a-f]{64}$")
  changed <- evidence; changed$ranking_scope <- "final_overall"
  expect_false(identical(api$uefa_euro_priority_policy_sha256(changed), api$uefa_euro_priority_policy_sha256()))
})

test_that("each joint queue is a complete permutation using interim rankings", {
  api <- euro_priority_api(); interim <- euro_priority_interim()
  set.seed(23); rng <- .Random.seed
  rows <- api$uefa_euro_priority_capture(interim, interim, 1L)
  expect_identical(.Random.seed, rng)
  expect_identical(sort(rows$expected_queue_position), as.numeric(1:54))
  expect_equal(sum(rows$p_group_winner), 14)
  expect_equal(sum(rows$p_winner_priority), 13)
  ordered <- rows[order(rows$expected_queue_position), ]
  expect_identical(ordered$team_id[1:13], paste0("team_", c(1:4,17:20,33:36,49)))
  expect_equal(rows$p_group_winner[rows$team_id == "team_50"], 1)
  expect_equal(rows$p_winner_priority[rows$team_id == "team_50"], 0)
  expect_gt(rows$expected_queue_position[rows$team_id == "team_50"], rows$expected_queue_position[rows$team_id == "team_5"])
  expect_identical(api$uefa_euro_priority_capture(interim[54:1,], interim[54:1,], 1L), rows)
})

test_that("summary uses correlated finishes and queues, not ranks averaged first", {
  api <- euro_priority_api(); one <- euro_priority_interim(); two <- one
  two$team_id[c(1,5)] <- two$team_id[c(5,1)]
  captures <- rbind(api$uefa_euro_priority_capture(one, one, 1L), api$uefa_euro_priority_capture(two, one, 2L))
  rows <- api$uefa_euro_priority_aggregate(captures, one, 2L)
  expect_equal(rows$p_group_winner[rows$team_id == "team_1"], .5)
  expect_equal(rows$p_winner_priority[rows$team_id == "team_1"], .5)
  expect_equal(rows$expected_interim_rank[rows$team_id == "team_1"], 3)
  expect_equal(rows$expected_queue_position[rows$team_id == "team_1"], 7.5)
  expect_equal(rows$queue_position_p10[rows$team_id == "team_1"], 1)
  expect_equal(rows$queue_position_p90[rows$team_id == "team_1"], 14)
  expect_silent(api$uefa_euro_validate_priority(rows, one))
  workers <- parallel::mclapply(1:2, function(i) api$uefa_euro_priority_capture(if (i == 1) one else two, one, i), mc.cores=2, mc.set.seed=FALSE)
  expect_identical(rows, api$uefa_euro_priority_aggregate(do.call(rbind, workers), one, 2L))
})

test_that("availability is per metric and never renormalizes incomplete iterations", {
  api <- euro_priority_api(); one <- euro_priority_interim(); blocked <- one
  blocked$ordering_status[1] <- "blocked"; blocked$interim_rank[1] <- NA
  complete <- api$uefa_euro_priority_capture(one, one, 1L)
  incomplete <- api$uefa_euro_priority_capture(blocked, one, 2L, group_rankings=one)
  rows <- api$uefa_euro_priority_aggregate(rbind(complete,incomplete), one, 2L)
  expect_true(all(is.finite(rows$p_group_winner)))
  expect_true(all(is.finite(rows$p_winner_priority)))
  expect_true(all(is.na(rows$expected_queue_position)))
  expect_true(is.na(rows$expected_interim_rank[rows$team_id == "team_1"]))
  expect_true(all(is.finite(rows$expected_interim_rank[rows$team_id != "team_1"])))
  expect_silent(api$uefa_euro_validate_priority(rows, one))
  unavailable <- api$uefa_euro_priority_capture(one, one, 2L, unresolved_groups="A1")
  rows <- api$uefa_euro_priority_aggregate(rbind(complete,unavailable), one, 2L)
  expect_true(all(is.na(rows$p_group_winner[rows$group_id == "A1"])))
  expect_true(all(is.finite(rows$p_group_winner[rows$group_id != "A1"])))
  expect_true(all(is.na(rows$expected_queue_position)))
  expect_silent(api$uefa_euro_validate_priority(rows, one))
  missing <- api$uefa_euro_priority_aggregate(complete, one, 2L)
  expect_true(all(is.na(missing$expected_queue_position)))
  expect_true(all(is.na(missing$p_group_winner)))
  d_blocked <- one; d_blocked$ordering_status[49] <- "blocked"
  d <- api$uefa_euro_priority_capture(d_blocked, one, 1L, group_rankings=one)
  expect_true(all(is.na(d$p_winner_priority[d$league == "D"])))
  expect_true(all(is.finite(d$p_group_winner)))
  d_loser_blocked <- one; d_loser_blocked$ordering_status[51] <- "blocked"
  d <- api$uefa_euro_priority_capture(d_loser_blocked, one, 1L, group_rankings=one)
  expect_true(all(is.finite(d$p_winner_priority)))
  expect_true(all(is.na(d$expected_queue_position)))
})

test_that("priority validator rejects malformed policy, roster, ranges and conservation", {
  api <- euro_priority_api(); one <- euro_priority_interim()
  rows <- api$uefa_euro_priority_aggregate(api$uefa_euro_priority_capture(one,one,1L),one,1L)
  bad <- rows; bad$priority_policy_sha256[1] <- paste(rep("a",64),collapse="")
  expect_error(api$uefa_euro_validate_priority(bad,one), "policy")
  bad <- rows; bad$p_group_winner[1] <- 2
  expect_error(api$uefa_euro_validate_priority(bad,one), "range")
  bad <- rows; bad$expected_queue_position[1] <- 5
  expect_error(api$uefa_euro_validate_priority(bad,one), "conserved")
  bad <- rows; bad$queue_position_p90[1] <- 0
  expect_error(api$uefa_euro_validate_priority(bad,one), "percentile")
  expect_error(api$uefa_euro_validate_priority(rows[-1,],one), "roster")
})

test_that("current artifact inventory is required while exact archived inventory is recognized", {
  api <- euro_priority_api()
  expect_length(api$phase15_nl_outcomes_expected_inventory(),10L)
  old <- setNames(lapply(api$phase15_nl_outcomes_expected_inventory(TRUE), function(path) data.frame()), api$phase15_nl_outcomes_expected_inventory(TRUE))
  expect_identical(api$phase15_nl_bundle_inventory(old), api$phase15_nl_outcomes_expected_inventory(TRUE))
  old[["outcomes/simulation_metadata.csv"]]$outcomes_inventory_version <- character()
  expect_error(api$phase15_nl_bundle_inventory(old), "inventory")
})

test_that("optional safety-net payload preserves sections and binds policy to batch identity", {
  api <- euro_priority_api()
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  payload <- api$phase17_payload_nations_league(bundle)
  expect_identical(names(payload$sections), api$phase17_section_ids())
  expect_identical(payload$euro_safety_net$status,"unavailable")
  expect_length(payload$euro_safety_net$rows,0)
  original <- api$phase17_batch_identity(bundles=list(bundle))
  bundle$priority_policy_version <- "uefa-euro-2028-nl-priority-v1"
  bundle$priority_policy_sha256 <- api$uefa_euro_priority_policy_sha256()
  policy_batch <- api$phase17_batch_identity(bundles=list(bundle))
  expect_false(identical(original,policy_batch))
  bundle$priority_policy_sha256 <- paste(rep("a",64),collapse="")
  expect_false(identical(policy_batch,api$phase17_batch_identity(bundles=list(bundle))))
})

test_that("dashboard sorts unrounded means, exposes ranges and keeps filter namespaces separate", {
  api <- euro_priority_api()
  rows <- list(
    list(team="Alpha",league="A",group_id="A1",p_group_winner=0,p_winner_priority=.0005,expected_interim_rank=3,expected_queue_position=2.049,queue_position_p10=1,queue_position_p90=5),
    list(team="Zulu",league="B",group_id="B1",p_group_winner=.5,p_winner_priority=.5,expected_interim_rank=17,expected_queue_position=2.041,queue_position_p10=2,queue_position_p90=4),
    list(team="Missing",league="D",group_id="D1",expected_queue_position=NA_real_))
  payload <- list(euro_safety_net=list(status="projected",rows=rows,metadata=list(simulation_count=1000,cutoff_utc="2026-10-03T01:00:32Z")),metadata=list(),sections=list())
  html <- api$phase17_nl_render_euro_safety_net(payload,list(teams=character(),groups=character()))
  document <- xml2::read_html(html)
  expect_identical(xml2::xml_attr(xml2::xml_find_all(document,"//tr[@class='euro-priority-row']"),"data-euro-team"),c("Zulu","Alpha","Missing"))
  expect_match(html,"0.0%",fixed=TRUE); expect_match(html,"&lt;0.1%",fixed=TRUE)
  expect_match(html,"10–90% range: 1–5",fixed=TRUE)
  expect_match(html,"Unavailable:",fixed=TRUE)
  expect_match(html,'id="euro-team-search"',fixed=TRUE)
  expect_false(grepl('id="nl-team-search"',html,fixed=TRUE))
  expect_match(html,"not a play-off entry probability",fixed=TRUE)
  expect_match(html,"League D receives special fallback priority",fixed=TRUE)
})
