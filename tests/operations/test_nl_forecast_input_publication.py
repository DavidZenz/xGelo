"""Independent stale-rating and causal-provenance cases for the public boundary."""
import datetime as dt
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import competition_refresh as refresh
import check_competition_refresh as health
from test_refresh_review import review_batch, seal_review_batch, utc, write_json


class NlForecastInputPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        self.now = dt.datetime(2026, 11, 6, 1, tzinfo=dt.timezone.utc)
        self.public = review_batch(self.root, self.now)
        self.path = self.public / "nations-league/payload.json"
        self.original = json.loads(self.path.read_text())

    def mutate(self, callback):
        payload = json.loads(json.dumps(self.original))
        callback(payload)
        write_json(self.path, payload)
        # Semantic checks must still reject a mechanically re-sealed batch.
        seal_review_batch(self.public, self.now)
        return payload

    def reject(self, callback, reason):
        self.mutate(callback)
        with self.assertRaisesRegex(refresh.RefreshError, "Nations League forecast inputs: .*" + reason):
            refresh.validate_payloads(self.public, self.now)

    def test_current_source_bound_inputs_are_visible_to_the_monitor(self):
        dates = refresh.validate_payloads(self.public, self.now)["nations-league"]
        self.assertEqual(dates["forecast_input_completed_result_count"], 1)
        self.assertEqual(dates["forecast_input_team_count"], 2)
        self.assertEqual(dates["forecast_input_latest_evidence_at_utc"], "2026-11-06T00:00:00Z")
        self.assertEqual(dates["projection_generated_at_utc"], utc(self.now))

    def test_input_subcontract_alone_cannot_certify_projection_or_page_readiness(self):
        def change(payload):
            payload["metadata"].pop("projection_generated_at_utc")
            payload["metadata"].pop("generated_at_utc")
        payload = self.mutate(change)
        self.assertEqual(refresh.validate_nl_forecast_input_evidence(payload, self.now)["forecast_input_status"], "validated")
        with self.assertRaisesRegex(refresh.RefreshError, "projection_generated_at_utc must be canonical UTC"):
            refresh.validate_payloads(self.public, self.now)

    def test_fresh_feed_and_validated_word_do_not_replace_actual_input_evidence(self):
        for missing in ("forecast_input_contract", "forecast_input_status", "forecast_input_evidence"):
            with self.subTest(missing=missing):
                def change(payload):
                    target = payload if missing == "forecast_input_evidence" else payload["metadata"]
                    target.pop(missing)
                self.reject(change, "evidence")

    def test_all_six_parent_hashes_are_required_and_cross_checked(self):
        fields = ("forecast_input_sha256", "forecast_input_provenance_sha256", "forecast_input_seed_sha256",
                  "forecast_input_results_sha256", "forecast_input_source_bundle_sha256", "forecast_input_policy_sha256")
        for field in fields:
            with self.subTest(field=field):
                self.reject(lambda p: p["forecast_input_evidence"].update({field: "f" * 64}), "hash")
                self.reject(lambda p: p["metadata"].update({field: None}), "hash")

    def test_matching_internal_hashes_cannot_point_to_a_different_current_source(self):
        def change(payload):
            for target in (payload["metadata"], payload["forecast_input_evidence"]):
                target["forecast_input_source_bundle_sha256"] = "e" * 64
        self.reject(change, "different accepted source")

    def test_current_source_check_cannot_disguise_old_rating_capture(self):
        self.reject(lambda p: p["metadata"].update(forecast_input_as_of_utc="2026-11-05T01:00:00Z"),
                    "not synchronized")

    def test_per_team_roster_must_be_complete_and_unique(self):
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"].pop(), "complete roster")
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][1].update(team_id="team_aaa"), "duplicate")
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][1].update(team_id="club_example"), "identity")
        self.reject(lambda p: p["current_standings"][1].update(team_id="team_ccc"), "roster differ")

    def test_completed_result_accounting_rejects_partial_or_impossible_replay(self):
        self.reject(lambda p: p["metadata"].update(forecast_input_completed_result_count=2), "participant accounting")
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(consumed_result_count=2), "participant accounting")
        for invalid in (True, -1, 1.5, None, "1"):
            with self.subTest(invalid=invalid):
                self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(consumed_result_count=invalid), "integer")

    def test_an_unplayed_team_can_retain_its_genuine_seed_date(self):
        def change(payload):
            row = dict(team_id="team_ccc", seed_evidence_at_utc="2026-11-01T01:00:00Z",
                       latest_evidence_at_utc="2026-11-01T01:00:00Z", consumed_result_count=0)
            payload["forecast_input_evidence"]["per_team"].append(row)
            payload["current_standings"].append(dict(team_id="team_ccc"))
            payload["metadata"].update(forecast_input_team_count=3,
                                       forecast_input_earliest_team_evidence_at_utc=row["latest_evidence_at_utc"])
        self.mutate(change)
        self.assertEqual(refresh.validate_payloads(self.public, self.now)["nations-league"]["forecast_input_team_count"], 3)

    def test_zero_consumed_results_cannot_claim_a_newer_evidence_date(self):
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(consumed_result_count=0),
                    "agree with its consumed results")

    def test_seed_and_consumed_evidence_respect_exclusive_causal_boundary(self):
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(seed_evidence_at_utc="2026-11-04T01:00:00Z"),
                    "causal window")
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(latest_evidence_at_utc="2026-11-06T02:00:00Z"),
                    "causal window")
        self.reject(lambda p: p["forecast_input_evidence"]["per_team"][0].update(latest_evidence_at_utc="2026-11-03T02:00:00Z"),
                    "agree with its consumed results")

    def test_aggregate_dates_must_be_derived_from_individual_teams(self):
        self.reject(lambda p: p["metadata"].update(forecast_input_earliest_team_evidence_at_utc="2026-11-05T23:00:00Z"),
                    "aggregate evidence dates")
        self.reject(lambda p: p["metadata"].update(forecast_input_base_latest_evidence_at_utc="2026-11-02T02:00:00Z"),
                    "aggregate evidence dates")

    def test_generation_dates_cannot_use_legacy_fallback_or_relabel_the_source(self):
        self.reject(lambda p: p["metadata"].update(projection_generated_at_utc="2026-08-25T00:00:00Z"), "chronology")
        self.reject(lambda p: p["metadata"].update(generated_at_utc="2026-11-05T23:30:00Z"), "chronology")
        self.reject(lambda p: p["metadata"].update(generated_at_utc="2026-11-06T01:06:00Z"), "chronology")
        self.reject(lambda p: p["metadata"].update(projection_generated_at_utc=None), "canonical UTC")
        self.reject(lambda p: p["metadata"].update(projection_generated_at_utc="2026-02-30T00:00:00Z"), "valid UTC")

    def test_missing_rating_evidence_is_an_alert_even_with_recent_public_success(self):
        self.mutate(lambda p: p.pop("forecast_input_evidence"))
        base = self.root / "logs/competition-refresh"
        refresh.atomic_json(base / "current.json", dict(status="success", run_id="mechanical-only"))
        refresh.atomic_json(base / "last-success.json", dict(completed_at_utc=utc(self.now), publication="verified"))
        result = health.inspect_health(self.root, self.now)
        self.assertEqual(result["state"], "failed")
        self.assertTrue(any("local rating evidence" in problem for problem in result["problems"]))

    def test_zero_consumption_cannot_conceal_accepted_completed_results(self):
        def change(payload):
            evidence = payload["forecast_input_evidence"]["per_team"]
            for row in evidence:
                row["consumed_result_count"] = 0
                row["latest_evidence_at_utc"] = row["seed_evidence_at_utc"]
            payload["metadata"].update(forecast_input_completed_result_count=0,
                forecast_input_earliest_team_evidence_at_utc=evidence[0]["seed_evidence_at_utc"],
                forecast_input_latest_evidence_at_utc=evidence[1]["seed_evidence_at_utc"])
        self.reject(change, "differs from accepted result evidence")

    def test_individual_consumption_dates_must_match_actual_participation(self):
        def change(payload):
            payload["forecast_input_evidence"]["per_team"][0]["latest_evidence_at_utc"] = "2026-11-05T23:00:00Z"
            payload["metadata"]["forecast_input_earliest_team_evidence_at_utc"] = "2026-11-05T23:00:00Z"
        self.reject(change, "did not consume their accepted completed results")

    def test_result_evidence_cannot_be_duplicated_unconfirmed_or_future_dated(self):
        self.reject(lambda p: p["sections"]["results"]["rows"].append(p["sections"]["results"]["rows"][0]), "duplicated")
        self.reject(lambda p: p["sections"]["results"]["rows"][0].update(match_status="scheduled"), "unconfirmed")
        self.reject(lambda p: p["sections"]["results"]["rows"][0].update(evidence_completed_at_utc="2026-11-06T02:00:00Z"), "later than the source")

    def test_a_result_captured_exactly_at_source_as_of_is_admissible(self):
        def change(payload):
            payload["sections"]["results"]["rows"][0]["evidence_completed_at_utc"] = utc(self.now)
            for row in payload["forecast_input_evidence"]["per_team"]:
                row["latest_evidence_at_utc"] = utc(self.now)
            payload["metadata"].update(forecast_input_earliest_team_evidence_at_utc=utc(self.now),
                                       forecast_input_latest_evidence_at_utc=utc(self.now))
        self.mutate(change)
        self.assertEqual(refresh.validate_payloads(self.public, self.now)["nations-league"]["forecast_input_completed_result_count"], 1)


if __name__ == "__main__":
    unittest.main()
