"""Declared arithmetic fixtures; no production model or source authority."""
import copy
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).resolve().parents[2] / "scripts/ucl_public_count_qa.py"
spec = importlib.util.spec_from_file_location("ucl_public_count_qa", MODULE)
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


def declared_counts(n=10000):
    clubs = ["club_declared_%02d" % i for i in range(1, 37)]
    meta = dict(tournament_status="available", simulation_count=n, simulation_seed=15020,
                forecast_scope="unconditioned_regulations_prior",
                monte_carlo_coverage_scope="95% pointwise sampling only; model and policy uncertainty excluded",
                late_tie_prior_probability_change_bound=0.1)
    for key in ("source_bundle_sha256", "model_sha256", "calibrator_sha256",
                "ruleset_sha256", "tournament_publication_sha256"):
        meta[key] = "a" * 64
    ranks = [dict(club_id=club, rank=rank, count=n if rank == i else 0)
             for i, club in enumerate(clubs, 1) for rank in range(1, 37)]
    stages = []
    for i, club in enumerate(clubs, 1):
        for stage, total in qa.STAGE_TOTALS.items():
            qualifies = (9 <= i <= 24 if stage == "knockout_play_off" else
                         i >= 25 if stage == "eliminated" else i <= total)
            stages.append(dict(club_id=club, stage_id=stage, count=n if qualifies else 0))
    return dict(metadata=meta, sections={}, cl_tournament_evidence=dict(
        simulation_count=n, rank_counts=ranks, stage_counts=stages))


class PublicCountQA(unittest.TestCase):
    def test_exact_marginals_reconcile_without_claiming_authority(self):
        p = declared_counts()
        result = qa.validate_ucl_public_counts(p)
        self.assertEqual(result["status"], "arithmetic_valid")
        self.assertFalse(result["authority_checked"])
        self.assertEqual(result["rank_cells"], 1296)
        self.assertEqual(result["stage_cells"], 288)
        self.assertLess(result["worst_pointwise_sampling_half_width"], 0.01)
        p["cl_tournament_evidence"]["rank_counts"].reverse()
        p["cl_tournament_evidence"]["stage_counts"].reverse()
        self.assertEqual(qa.validate_ucl_public_counts(p), result)

    def test_unavailable_route_passes_but_any_outlook_claim_requires_counts(self):
        self.assertEqual(qa.validate_ucl_public_counts({})["status"], "unavailable")
        variants = [dict(metadata=dict(simulation_count=10000)),
                    dict(metadata=dict(tournament_status="available")),
                    dict(sections=dict(projected_outcomes=dict(rows=[dict(Chance="100%")]))),
                    dict(sections=dict(rank_distributions=dict(status="available")))]
        for variant in variants:
            with self.subTest(variant=variant), self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(variant)

    def test_demo_counts_and_boolean_or_fractional_counts_fail(self):
        for value in (100, 1000, 9599, True, 10000.5):
            p = declared_counts(); p["cl_tournament_evidence"]["simulation_count"] = value
            with self.subTest(value=value), self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(p)
        p = declared_counts(9600)
        self.assertLess(qa.validate_ucl_public_counts(p)["worst_pointwise_sampling_half_width"], 0.01)
        for value in (True, -1, 10001, 0.5):
            p = declared_counts(); p["cl_tournament_evidence"]["rank_counts"][0]["count"] = value
            with self.subTest(cell=value), self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(p)

    def test_missing_duplicate_and_corrupt_rank_cells_fail(self):
        for mutation in (lambda rows: rows.pop(), lambda rows: rows.__setitem__(1, copy.deepcopy(rows[0])),
                         lambda rows: rows[0].__setitem__("count", 9999),
                         lambda rows: rows[0].__setitem__("club_id", "national_team")):
            p = declared_counts(); mutation(p["cl_tournament_evidence"]["rank_counts"])
            with self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(p)

    def test_stage_inventory_totals_and_band_linkage_fail_closed(self):
        p = declared_counts(); p["cl_tournament_evidence"]["stage_counts"].pop()
        with self.assertRaisesRegex(qa.UCLPublicCountError, "288"):
            qa.validate_ucl_public_counts(p)
        p = declared_counts(); rows = p["cl_tournament_evidence"]["stage_counts"]
        for row in rows:
            if row["stage_id"] == "direct_round_of_16" and row["club_id"] in ("club_declared_01", "club_declared_09"):
                row["count"] = 10000 - row["count"]
        with self.assertRaisesRegex(qa.UCLPublicCountError, "qualification bands"):
            qa.validate_ucl_public_counts(p)
        p = declared_counts(); p["cl_tournament_evidence"]["stage_counts"][0]["count"] -= 1
        with self.assertRaisesRegex(qa.UCLPublicCountError, "participant total"):
            qa.validate_ucl_public_counts(p)

    def test_progression_must_be_nested_even_when_stage_totals_match(self):
        p = declared_counts()
        for row in p["cl_tournament_evidence"]["stage_counts"]:
            if row["stage_id"] == "champion" and row["club_id"] in ("club_declared_01", "club_declared_03"):
                row["count"] = 10000 - row["count"]
        with self.assertRaisesRegex(qa.UCLPublicCountError, "nesting"):
            qa.validate_ucl_public_counts(p)

    def test_hash_scope_and_uncertainty_disclosures_are_required(self):
        for key, value in (("model_sha256", "unbound"), ("forecast_scope", "official_draw"),
                           ("monte_carlo_coverage_scope", "95% model accuracy"),
                           ("late_tie_prior_probability_change_bound", float("nan")),
                           ("simulation_count", 10001)):
            p = declared_counts(); p["metadata"][key] = value
            with self.subTest(field=key), self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(p)

    def test_malformed_objects_fail_with_a_typed_arithmetic_error(self):
        for payload in ([], dict(metadata=[]), dict(sections=dict(structure=[]))):
            with self.subTest(payload=payload), self.assertRaises(qa.UCLPublicCountError):
                qa.validate_ucl_public_counts(payload)
        p = declared_counts(); p["cl_tournament_evidence"]["stage_counts"][0]["stage_id"] = []
        with self.assertRaises(qa.UCLPublicCountError):
            qa.validate_ucl_public_counts(p)
        p = declared_counts(); p["cl_tournament_evidence"]["rank_counts"][0]["unknown_field"] = "extra"
        with self.assertRaises(qa.UCLPublicCountError):
            qa.validate_ucl_public_counts(p)


if __name__ == "__main__":
    unittest.main()
