"""Independent operational failures; no provider requests or public mutations."""
import contextlib
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"scripts"))
import competition_refresh as refresh
import check_competition_refresh as health
from test_refresh_review import review_batch, seal_review_batch


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.good = self.root/"R installation with spaces"/"Rscript"
        self.good.parent.mkdir()
        self.good.write_text('#!/bin/bash\nprintf "Rscript (R) version 9.9.9\\n"\n')
        self.good.chmod(0o755)

    def resolve(self, extra="", **env):
        e = dict(os.environ, PATH=str(self.root/"empty"), **env)
        e["FOOTBALL_DATA_API_TOKEN"] = "private-test-sentinel"
        e.pop("XGELO_RSCRIPT", None)
        e.update(env)
        body = 'source "$1"; '+extra+'; xgelo_resolve_rscript && printf "%s\\n" "$R_SCRIPT"'
        return subprocess.run(["/bin/bash", "-c", body, "test-runtime", str(ROOT/"scripts/lib/rscript_runtime.sh")],
                              env=e, capture_output=True, text=True)

    def test_explicit_path_with_spaces_and_no_environment_dump(self):
        r = self.resolve(":", XGELO_RSCRIPT=str(self.good))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), str(self.good))
        self.assertNotIn("private-test-sentinel", r.stdout+r.stderr)

    def test_invalid_explicit_configuration_does_not_silently_fall_back(self):
        r = self.resolve('xgelo_rscript_fallbacks() { printf "%s\\n" "$GOOD"; }',
                         XGELO_RSCRIPT="/missing/configured/Rscript", GOOD=str(self.good))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Invalid XGELO_RSCRIPT", r.stderr)

    def test_minimal_launchd_path_uses_probed_fallback(self):
        r = self.resolve('xgelo_rscript_fallbacks() { printf "%s\\n" "/missing/Rscript" "$GOOD"; }', GOOD=str(self.good))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), str(self.good))

    def test_broken_candidate_is_skipped(self):
        bad = self.root/"broken"
        bad.write_text("#!/bin/bash\nexit 42\n")
        bad.chmod(0o755)
        r = self.resolve('xgelo_rscript_fallbacks() { printf "%s\\n" "$BAD" "$GOOD"; }', BAD=str(bad), GOOD=str(self.good))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), str(self.good))


class OperationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/"project"
        self.root.mkdir()
        self.now = dt.datetime(2026, 11, 5, 12, tzinfo=dt.timezone.utc)
        self.payloads(self.root)

    def payloads(self, root):
        review_batch(root,self.now)

    def test_failed_child_preserves_last_success_and_records_error(self):
        base = self.root/"logs/competition-refresh"
        refresh.atomic_json(base/"last-success.json", {"completed_at_utc":"2026-11-04T12:00:00Z"})
        run = refresh.Run(self.root, "scheduled")
        with self.assertRaises(refresh.RefreshError):
            run.command("fixture_failure", [sys.executable,"-c","raise SystemExit(42)"])
        run.finish("failed", "fixture failure")
        current = refresh.read_json(base/"current.json")
        self.assertEqual(current["status"], "failed")
        self.assertEqual(current["last_success_at_utc"], "2026-11-04T12:00:00Z")
        self.assertEqual(refresh.read_json(base/"last-success.json")["completed_at_utc"], "2026-11-04T12:00:00Z")
        self.assertEqual(refresh.read_json(base/"alert.json")["state"], "failed")

    def test_stage_timeout_terminates_the_real_child(self):
        run = refresh.Run(self.root)
        pid_file = self.root/"child.pid"
        code = 'import os,time,pathlib;pathlib.Path('+repr(str(pid_file))+').write_text(str(os.getpid()));time.sleep(30)'
        with self.assertRaisesRegex(refresh.RefreshError, "time limit"):
            run.command("timed_fixture",[sys.executable,"-c",code],timeout=.2)
        with self.assertRaises(ProcessLookupError):
            os.kill(int(pid_file.read_text()), 0)

    def test_nonoverlap_lock_preserves_current_run(self):
        lock = self.root/"logs/competition-refresh/refresh.lock"
        with refresh.exclusive_lock(lock):
            with self.assertRaises(refresh.RefreshError):
                with refresh.exclusive_lock(lock):
                    self.fail("second lock must not run")

    def test_preview_simulations_cannot_publish(self):
        p = self.root/refresh.PUBLIC/"nations-league/payload.json"
        d=json.loads(p.read_text());d["metadata"]["simulation_count"]=100;p.write_text(json.dumps(d))
        seal_review_batch(self.root/refresh.PUBLIC,self.now)
        with self.assertRaisesRegex(refresh.RefreshError,"precision"):
            refresh.validate_payloads(self.root/refresh.PUBLIC,self.now)

    def test_stale_source_cannot_publish(self):
        p=self.root/refresh.PUBLIC/"champions-league/payload.json"
        d=json.loads(p.read_text());d["metadata"]["last_refresh_at_utc"]="2026-10-27T10:00:00Z";p.write_text(json.dumps(d))
        seal_review_batch(self.root/refresh.PUBLIC,self.now)
        with self.assertRaisesRegex(refresh.RefreshError,"stale"):
            refresh.validate_payloads(self.root/refresh.PUBLIC,self.now)

    def test_expired_fixture_and_unlabelled_defaults_are_rejected(self):
        p=self.root/refresh.PUBLIC/"champions-league/payload.json";d=json.loads(p.read_text())
        d["sections"]["fixtures"]["rows"]=[{"Kickoff (UTC)":"2026-11-04T18:00:00Z"}];p.write_text(json.dumps(d))
        seal_review_batch(self.root/refresh.PUBLIC,self.now)
        with self.assertRaisesRegex(refresh.RefreshError,"Past CL"):
            refresh.validate_payloads(self.root/refresh.PUBLIC,self.now)
        d["sections"]["fixtures"]["rows"]=[]
        d["sections"]["match_forecasts"]["rows"]=[{"Kickoff (UTC)":"2026-11-06T18:00:00Z","Home win":"44%","Draw":"25%","Away win":"31%"}]*2
        p.write_text(json.dumps(d))
        seal_review_batch(self.root/refresh.PUBLIC,self.now)
        with self.assertRaisesRegex(refresh.RefreshError,"baseline"):
            refresh.validate_payloads(self.root/refresh.PUBLIC,self.now)

    def test_euro_placeholder_cannot_contain_invented_schedule(self):
        p=self.root/refresh.PUBLIC/"euro-qualifying/payload.json";d=json.loads(p.read_text())
        d["sections"]["fixtures"]["rows"]=[{"Home":"invented"}];p.write_text(json.dumps(d))
        seal_review_batch(self.root/refresh.PUBLIC,self.now)
        with self.assertRaisesRegex(refresh.RefreshError,"invented"):
            refresh.validate_payloads(self.root/refresh.PUBLIC,self.now)

    def test_install_failure_restores_every_root_and_preserves_wc(self):
        for relative in refresh.managed_paths(self.root):
            p=self.root/relative;p.mkdir(parents=True,exist_ok=True);(p/"snapshot.txt").write_text("incumbent")
        wc=self.root/"docs/wc2026/index.html";wc.parent.mkdir();wc.write_text("protected WC")
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        workspace=Path(self.temp.name)/"candidate"
        self.payloads(workspace)
        for relative in refresh.managed_paths(self.root):
            p=workspace/relative;p.mkdir(parents=True,exist_ok=True);(p/"snapshot.txt").write_text("candidate")
        run=refresh.Run(self.root)
        with mock.patch.object(refresh,"validate_payloads",side_effect=refresh.RefreshError("injected read-back failure")):
            with self.assertRaisesRegex(refresh.RefreshError,"injected"):
                refresh.install_workspace(self.root,workspace,before,run)
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),before)
        self.assertEqual(wc.read_text(),"protected WC")
        self.assertEqual(refresh.read_json(run.base/"install-journal.json")["state"],"rolled_back")

    def test_concurrent_edits_are_not_overwritten(self):
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        p=self.root/refresh.PUBLIC/"nations-league/index.html";p.write_text("concurrent edit")
        run=refresh.Run(self.root)
        with self.assertRaisesRegex(refresh.RefreshError,"concurrent edits"):
            refresh.install_workspace(self.root,self.root,before,run)
        self.assertEqual(p.read_text(),"concurrent edit")

    def test_health_observer_detects_terminal_failure_and_staleness(self):
        base=self.root/"logs/competition-refresh"
        refresh.atomic_json(base/"current.json",dict(status="failed",phase="fixture",error="bad feed"))
        refresh.atomic_json(base/"last-success.json",dict(completed_at_utc="2026-11-01T12:00:00Z"))
        report=health.inspect_health(self.root,self.now)
        self.assertEqual(report["state"],"failed")
        self.assertTrue(any("bad feed" in p for p in report["problems"]))
        self.assertTrue(any("96.0h" in p for p in report["problems"]))

    def test_existing_unrelated_pid_cannot_disguise_a_dead_controller(self):
        base=self.root/"logs/competition-refresh"
        refresh.atomic_json(base/"current.json",dict(status="running",process_id=os.getpid(),
            started_at_utc="2026-11-05T11:00:00Z"))
        report=health.inspect_health(self.root,self.now)
        self.assertEqual(report["state"],"failed")
        self.assertTrue(any("does not hold" in p for p in report["problems"]))

    def test_locked_but_overdue_controller_is_not_healthy(self):
        base=self.root/"logs/competition-refresh"
        refresh.atomic_json(base/"current.json",dict(status="running",process_id=os.getpid(),
            started_at_utc="2026-11-04T23:00:00Z",maximum_run_hours=12))
        with refresh.exclusive_lock(base/"refresh.lock"):
            report=health.inspect_health(self.root,self.now)
        self.assertEqual(report["state"],"failed")
        self.assertTrue(any("maximum run age" in p for p in report["problems"]))

    def test_local_install_does_not_claim_public_health(self):
        base=self.root/"logs/competition-refresh"
        run=refresh.Run(self.root)
        run.record["publication"]="local_only"
        run.finish("success")
        self.assertEqual(refresh.read_json(base/"alert.json")["state"],"local_only")
        self.assertFalse((base/"last-public-success.json").exists())
        report=health.inspect_health(self.root,self.now)
        self.assertTrue(any("no verified public" in p for p in report["problems"]))

    def test_index_bytes_not_mutable_worktree_are_publication_authority(self):
        subprocess.run(["git","init","--quiet",str(self.root)],check=True,capture_output=True)
        subprocess.run(["git","add","docs/competitions"],cwd=self.root,check=True,capture_output=True)
        inventory=refresh.validate_public_bytes(self.root/refresh.PUBLIC)
        refresh.validate_git_index(self.root,inventory)
        p=self.root/refresh.PUBLIC/"nations-league/index.html"
        p.write_text("changed after git add")
        inventory["nations-league/index.html"]=refresh.sha(p)
        with self.assertRaisesRegex(refresh.RefreshError,"index bytes"):
            refresh.validate_git_index(self.root,inventory)

    def test_unavailable_site_is_not_reported_as_deployed(self):
        run=refresh.Run(self.root)
        with mock.patch.object(refresh,"public_readback",side_effect=refresh.RefreshError("HTTP404")):
            with self.assertRaisesRegex(refresh.RefreshError,"did not converge"):
                refresh.verify_publication(run,{"current.json":"test"},attempts=2,interval_seconds=0)
        self.assertNotEqual(run.record.get("publication"),"verified")
        self.assertIn("HTTP404",run.record["publication_readback_error"])

    def test_successful_exchange_keeps_the_old_batch_available_until_swap(self):
        for relative in refresh.managed_paths(self.root):
            (self.root/relative).mkdir(parents=True,exist_ok=True)
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        workspace=Path(self.temp.name)/"candidate"
        self.payloads(workspace)
        for relative in refresh.managed_paths(self.root):
            (workspace/relative).mkdir(parents=True,exist_ok=True)
        run=refresh.Run(self.root)
        exchange=refresh.exchange_directories
        observed=[]
        def checked_exchange(target,stage):
            observed.append((Path(target).is_dir(),Path(stage).is_dir()))
            exchange(target,stage)
            self.assertTrue(Path(target).is_dir())
        with mock.patch.object(refresh,"exchange_directories",side_effect=checked_exchange), \
             mock.patch.object(refresh,"validate_payloads",return_value={}):
            refresh.install_workspace(self.root,workspace,before,run)
        self.assertEqual(observed,[(True,True)]*len(refresh.managed_paths(self.root)))
        self.assertEqual(refresh.read_json(run.base/"validated-install.json")["public_inventory"],
                         refresh.validate_public_bytes(self.root/refresh.PUBLIC))


if __name__ == "__main__":
    unittest.main()
