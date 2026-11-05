"""Health process observation and genuine failure signals."""
import datetime as dt
import contextlib
import errno
import io
import json
import os
import runpy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import competition_refresh as refresh

import check_competition_refresh as health
TARGET = ROOT / "scripts/check_competition_refresh.py"


class HealthObservationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / "logs/competition-refresh"
        self.base.mkdir(parents=True)
        self.now = dt.datetime(2026, 11, 5, 12, tzinfo=dt.timezone.utc)
        self.record = dict(status="running", process_id=os.getpid(), run_id="independent-test",
                           started_at_utc="2026-11-05T11:00:00Z", maximum_run_hours=12)
        self.save_record()
        self.last = dict(completed_at_utc="2026-11-05T10:00:00Z", publication="verified")
        self.save_last()
        self.validation = mock.patch.object(health, "validate_payloads", return_value={"fixture": "fresh"})
        self.validation.start()
        self.addCleanup(self.validation.stop)

    def save_record(self):
        refresh.atomic_json(self.base / "current.json", self.record)

    def save_last(self):
        refresh.atomic_json(self.base / "last-success.json", self.last)

    def inspect(self, probe=None):
        with mock.patch.object(health.os, "kill", side_effect=probe):
            return health.inspect_health(self.root, self.now)

    def assert_no_absence_claim(self, result):
        self.assertFalse(any("controller process is absent" in issue for issue in result["problems"]))

    def test_absent_pid_is_a_real_failure_even_if_lock_text_matches(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect(ProcessLookupError(errno.ESRCH, "No such process"))
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["controller_observation"]["process_state"], "absent")
        self.assertTrue(any("controller process is absent" in issue for issue in result["problems"]))

    def test_observed_pid_owned_lock_and_valid_age_are_running(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect()
        self.assertEqual(result["state"], "running")
        self.assertEqual(result["controller_observation"]["lock_state"], "held_with_matching_pid")
        self.assertEqual(result["controller_observation"]["run_age_hours"], 1)
        self.assertEqual(result["observations"], [])

    def test_permission_denied_is_an_observation_gap_with_correlated_lock_evidence(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "observation_gap")
        self.assertEqual(result["controller_observation"]["process_state"], "permission_denied")
        self.assertEqual(result["controller_observation"]["lock_state"], "held_with_matching_pid")
        self.assertEqual(result["problems"], [])
        self.assertTrue(any("cannot independently confirm" in note for note in result["observations"]))
        self.assert_no_absence_claim(result)

    def test_permission_denied_does_not_disguise_an_unheld_lock_or_reused_pid(self):
        (self.base / "refresh.lock").write_text(str(os.getpid()))
        result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["controller_observation"]["lock_state"], "unheld")
        self.assertTrue(any("does not hold" in issue for issue in result["problems"]))
        self.assert_no_absence_claim(result)

    def test_observed_unrelated_pid_with_only_stale_lock_text_fails(self):
        (self.base / "refresh.lock").write_text(str(os.getpid()))
        result = self.inspect()
        self.assertEqual(result["state"], "failed")
        self.assertTrue(any("does not hold" in issue for issue in result["problems"]))

    def test_permission_denied_does_not_disguise_a_different_lock_pid(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            (self.base / "refresh.lock").write_text(str(os.getpid() + 100000))
            result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["controller_observation"]["lock_state"], "held_by_other_pid")
        self.assertTrue(any("different process" in issue for issue in result["problems"]))
        self.assert_no_absence_claim(result)

    def test_owned_lock_cannot_hide_an_overdue_run_with_or_without_permission(self):
        self.record["started_at_utc"] = "2026-11-04T23:00:00Z"
        self.save_record()
        for probe in (None, PermissionError(errno.EPERM, "Operation not permitted")):
            with self.subTest(probe=type(probe).__name__), refresh.exclusive_lock(self.base / "refresh.lock"):
                result = self.inspect(probe)
            self.assertEqual(result["state"], "failed")
            self.assertTrue(any("maximum run age (13.0h)" in issue for issue in result["problems"]))

    def test_permission_gap_does_not_suppress_missing_success_alert(self):
        (self.base / "last-success.json").unlink()
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "failed")
        self.assertTrue(any("No successful" in issue for issue in result["problems"]))
        self.assert_no_absence_claim(result)

    def test_running_first_refresh_retains_existing_behavior_when_observed(self):
        (self.base / "last-success.json").unlink()
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect()
        self.assertEqual(result["state"], "running")
        self.assertIsNone(result["last_success_at_utc"])

    def test_permission_gap_cannot_hide_real_staleness_or_unverified_publication(self):
        self.last.update(completed_at_utc="2026-11-01T12:00:00Z", publication="local_only")
        self.save_last()
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "failed")
        self.assertTrue(any("96.0h old" in issue for issue in result["problems"]))
        self.assertTrue(any("no verified public deployment" in issue for issue in result["problems"]))
        self.assert_no_absence_claim(result)

    def test_other_probe_errors_are_not_proof_of_absence(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"):
            result = self.inspect(OSError(errno.EIO, "Independent observation failure"))
        self.assertEqual(result["state"], "observation_gap")
        self.assertEqual(result["controller_observation"]["process_state"], "observation_error")
        self.assert_no_absence_claim(result)

    def test_lock_access_error_is_not_a_missing_controller(self):
        with mock.patch.object(health.fcntl, "flock", side_effect=PermissionError(errno.EPERM, "Lock access denied")):
            result = self.inspect()
        self.assertEqual(result["state"], "failed")
        self.assertEqual(result["controller_observation"]["process_state"], "observed")
        self.assertTrue(any("Cannot inspect the refresh lock" in issue for issue in result["problems"]))
        self.assert_no_absence_claim(result)

    def test_invalid_pid_and_age_records_fail_without_signalling_process_groups(self):
        for changes in (dict(process_id=0), dict(process_id=-1), dict(process_id="bad"),
                        dict(process_id=1.5), dict(process_id=True),
                        dict(started_at_utc="2026-11-06T11:00:00Z"), dict(maximum_run_hours=float("inf"))):
            with self.subTest(changes=changes):
                record = dict(self.record, **changes)
                with mock.patch.object(health.os, "kill") as signal:
                    running, gap, evidence, problems, notes = health.observe_controller(record, self.base, self.now)
                signal.assert_not_called()
                self.assertFalse(running)
                self.assertTrue(any("record is invalid" in issue for issue in problems))

    def test_source_validation_failure_remains_a_failure_during_a_probe_gap(self):
        with refresh.exclusive_lock(self.base / "refresh.lock"), \
             mock.patch.object(health, "validate_payloads", side_effect=refresh.RefreshError("Independent stale source")):
            result = self.inspect(PermissionError(errno.EPERM, "Operation not permitted"))
        self.assertEqual(result["state"], "failed")
        self.assertIn("Independent stale source", result["problems"])
        self.assert_no_absence_claim(result)

    def test_cli_reports_gap_as_attention_without_writing_an_observation(self):
        captured = io.StringIO()
        with refresh.exclusive_lock(self.base / "refresh.lock"), \
             mock.patch.object(refresh, "ROOT", self.root), \
             mock.patch.object(refresh, "validate_payloads", return_value={}), \
             mock.patch.object(os, "kill", side_effect=PermissionError(errno.EPERM, "Operation not permitted")), \
             mock.patch.object(sys, "argv", [str(TARGET)]), \
             contextlib.redirect_stdout(captured):
            # Use the same fixed observation time in the CLI's datetime call.
            class Clock(dt.datetime):
                @classmethod
                def now(cls, tz=None):
                    return self.now
            with mock.patch.object(dt, "datetime", Clock), self.assertRaises(SystemExit) as exit:
                runpy.run_path(str(TARGET), run_name="__main__")
        self.assertEqual(exit.exception.code, 1)
        result = json.loads(captured.getvalue())
        self.assertEqual(result["state"], "observation_gap")
        self.assert_no_absence_claim(result)
        self.assertFalse((self.base / "health.json").exists())


if __name__ == "__main__":
    unittest.main()
