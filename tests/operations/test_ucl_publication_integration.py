"""Temporary resealed public fixtures exercise Python arithmetic dispatch only."""
import datetime as dt
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import competition_refresh as refresh
from test_refresh_review import review_batch, seal_review_batch
from test_ucl_public_count_qa import declared_counts


class PublicCountIntegration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        self.public = review_batch(self.root, self.now)
        self.path = self.public / "champions-league/payload.json"

    def replace(self, callback):
        payload = json.loads(self.path.read_text())
        callback(payload)
        self.path.write_text(json.dumps(payload))
        seal_review_batch(self.public, self.now)

    def test_facts_only_controller_report_has_no_forecast_authority(self):
        result = refresh.validate_payloads(self.public, self.now)
        self.assertEqual(result["champions-league"]["tournament_count_qa"],
                         dict(status="unavailable", authority_checked=False))

    def test_resealed_metadata_or_rows_cannot_bypass_required_count_evidence(self):
        self.replace(lambda payload: payload["metadata"].update(simulation_count=10000))
        self.assertEqual(len(refresh.validate_public_bytes(self.public)), 14)
        with self.assertRaisesRegex(refresh.RefreshError, "exact count evidence"):
            refresh.validate_payloads(self.public, self.now)

    def test_resealed_arithmetic_corruption_is_rejected_independently(self):
        def add_declared(payload):
            counts = declared_counts()
            payload["metadata"].update(counts["metadata"])
            payload["cl_tournament_evidence"] = counts["cl_tournament_evidence"]
        self.replace(add_declared)
        # Arithmetic-positive is not a source/model-positive. The production
        # controller still separately requires the genuine fixed R validator.
        result = refresh.validate_payloads(self.public, self.now)["champions-league"]["tournament_count_qa"]
        self.assertEqual(result["status"], "arithmetic_valid")
        self.assertFalse(result["authority_checked"])
        self.replace(lambda payload: payload["cl_tournament_evidence"]["stage_counts"][0].update(count=9999))
        self.assertEqual(len(refresh.validate_public_bytes(self.public)), 14)
        with self.assertRaisesRegex(refresh.RefreshError, "participant total"):
            refresh.validate_payloads(self.public, self.now)


if __name__ == "__main__":
    unittest.main()
