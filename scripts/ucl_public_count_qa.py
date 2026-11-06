"""Independent arithmetic QA for public CL counts, never model/source authority.

The fixed R persisted reader must separately authenticate every real input and
per-iteration path. Marginal public counts cannot prove those properties.
"""
import math
import re


class UCLPublicCountError(ValueError):
    pass


STAGE_TOTALS = {
    "direct_round_of_16": 8, "knockout_play_off": 16, "eliminated": 12,
    "round_of_16": 16, "quarter_final": 8, "semi_final": 4,
    "final": 2, "champion": 1,
}
SECTIONS = ("structure", "rank_distributions", "qualification_bands",
            "knockout_paths", "progression_probabilities", "projected_outcomes")


def _require(condition, reason):
    if not condition:
        raise UCLPublicCountError("CL public count QA: " + reason)


def _integer(value, minimum, maximum, name):
    _require(isinstance(value, (int, float)) and not isinstance(value, bool)
             and math.isfinite(value) and value == int(value)
             and minimum <= value <= maximum, name + " must be a bounded exact integer")
    return int(value)


def validate_ucl_public_counts(payload):
    """Validate empirical marginal arithmetic; return no eligibility flags."""
    _require(isinstance(payload, dict), "payload must be an object")
    meta, sections = payload.get("metadata", {}), payload.get("sections", {})
    _require(isinstance(meta, dict) and isinstance(sections, dict), "metadata and sections must be objects")
    _require(all(isinstance(sections.get(name, {}), dict) for name in SECTIONS),
             "tournament sections must be objects")
    evidence = payload.get("cl_tournament_evidence")
    claims = (meta.get("tournament_status") == "available" or evidence is not None
              or any(sections.get(name, {}).get("rows") or
                     sections.get(name, {}).get("status") == "available" for name in SECTIONS)
              or any(meta.get(key) is not None and meta.get(key) != "" for key in
                     ("projection_run_id", "simulation_seed", "simulation_count",
                      "tournament_publication_sha256", "forecast_scope", "monte_carlo_coverage_scope")))
    if not claims:
        return {"status": "unavailable", "authority_checked": False}
    _require(meta.get("tournament_status") == "available" and isinstance(evidence, dict),
             "populated outlooks require their exact count evidence")
    _require(meta.get("forecast_scope") == "unconditioned_regulations_prior",
             "unsupported or undisclosed conditioning scope")
    _require(meta.get("monte_carlo_coverage_scope") ==
             "95% pointwise sampling only; model and policy uncertainty excluded",
             "sampling precision must not claim model or simultaneous uncertainty")
    for field in ("source_bundle_sha256", "model_sha256", "calibrator_sha256",
                  "ruleset_sha256", "tournament_publication_sha256"):
        _require(isinstance(meta.get(field), str) and
                 re.fullmatch(r"[0-9a-f]{64}", meta[field]) is not None,
                 field + " is not an exact hash")
    _require(set(evidence) == {"simulation_count", "rank_counts", "stage_counts"}, "count evidence schema differs")
    n = _integer(evidence.get("simulation_count"), 9600, 100000, "simulation count")
    _require(_integer(meta.get("simulation_count"), 9600, 100000, "metadata simulation count") == n,
             "metadata and evidence simulation counts differ")
    _integer(meta.get("simulation_seed"), 0, 2147483647, "seed")
    rank_rows, stage_rows = evidence.get("rank_counts"), evidence.get("stage_counts")
    _require(isinstance(rank_rows, list) and len(rank_rows) == 1296, "rank inventory must have 1296 rows")
    _require(isinstance(stage_rows, list) and len(stage_rows) == 288, "stage inventory must have 288 rows")
    ranks, stages = {}, {}
    for row in rank_rows:
        _require(isinstance(row, dict) and set(row) == {"club_id", "rank", "count"},
                 "rank row schema differs")
        club = row.get("club_id")
        _require(isinstance(club, str) and re.fullmatch(r"club_[A-Za-z0-9_]+", club) is not None,
                 "rank row lacks a club identity")
        rank = _integer(row.get("rank"), 1, 36, "rank")
        key = (club, rank)
        _require(key not in ranks, "duplicate club/rank cell")
        ranks[key] = _integer(row.get("count"), 0, n, "rank count")
    clubs = sorted({club for club, _ in ranks})
    _require(len(clubs) == 36 and set(ranks) == {(c, r) for c in clubs for r in range(1, 37)},
             "rank inventory must cover all 36 clubs and ranks")
    _require(all(sum(ranks[c, r] for r in range(1, 37)) == n for c in clubs),
             "club rank mass differs from simulation count")
    _require(all(sum(ranks[c, r] for c in clubs) == n for r in range(1, 37)),
             "rank column mass differs from simulation count")
    for row in stage_rows:
        _require(isinstance(row, dict) and set(row) == {"club_id", "stage_id", "count"},
                 "stage row schema differs")
        key = (row.get("club_id"), row.get("stage_id"))
        _require(isinstance(key[0], str) and isinstance(key[1], str) and
                 key[0] in clubs and key[1] in STAGE_TOTALS and key not in stages,
                 "stage inventory has unknown or duplicate cells")
        stages[key] = _integer(row.get("count"), 0, n, "stage count")
    _require(set(stages) == {(c, s) for c in clubs for s in STAGE_TOTALS}, "incomplete stage inventory")
    for stage, participants in STAGE_TOTALS.items():
        _require(sum(stages[c, stage] for c in clubs) == participants*n,
                 stage + " participant total does not reconcile")
    for club in clubs:
        bands = (sum(ranks[club, r] for r in range(1, 9)),
                 sum(ranks[club, r] for r in range(9, 25)),
                 sum(ranks[club, r] for r in range(25, 37)))
        _require(bands == tuple(stages[club, s] for s in
                 ("direct_round_of_16", "knockout_play_off", "eliminated")),
                 "qualification bands differ from empirical rank counts")
        advance = [stages[club, s] for s in ("round_of_16", "quarter_final", "semi_final", "final", "champion")]
        _require(bands[0] <= advance[0] <= bands[0]+bands[1] and
                 all(a >= b for a, b in zip(advance, advance[1:])), "progression nesting is invalid")
    bound = meta.get("late_tie_prior_probability_change_bound")
    _require(isinstance(bound, (int, float)) and not isinstance(bound, bool) and
             math.isfinite(bound) and 0 <= bound <= 1, "late tie-break sensitivity bound is invalid")
    z = 1.959963984540054
    worst = z/(2*math.sqrt(n + z*z))
    _require(worst <= 0.01, "worst-case 95% pointwise sampling half-width exceeds 1pp")
    return {"status": "arithmetic_valid", "simulation_count": n, "club_count": 36,
            "rank_cells": len(ranks), "stage_cells": len(stages),
            "worst_pointwise_sampling_half_width": worst, "authority_checked": False}
