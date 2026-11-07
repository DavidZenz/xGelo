"""Recovery mechanics with real temporary files and a deliberately fake R process.

These cases prove controller retention/dispatch/rollback behavior. The mechanical
R substitute makes no source, model, calibration or production-authority claims.
"""
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"scripts"))
import competition_refresh as refresh
from test_refresh_review import review_batch, seal_review_batch, utc


class RetainedRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/"project"
        self.root.mkdir()
        self.now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        review_batch(self.root,self.now)
        for relative in refresh.managed_paths(self.root):
            p=self.root/relative;p.mkdir(parents=True,exist_ok=True)
            (p/"mechanical-incumbent.txt").write_text("original")
        for relative in ("R/runtime_marker.txt","scripts/runtime_marker.txt",".planning/mechanical.txt",
                         "outputs/releases/approved_release.csv","outputs/releases/club/marker.txt"):
            p=self.root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_text("original")
        self.wc=self.root/"docs/wc2026/index.html";self.wc.parent.mkdir();self.wc.write_text("protected WC")
        self.config=Path(self.temp.name)/"fake-r-config.json"
        self.trace=Path(self.temp.name)/"fake-r-trace.jsonl"
        self.fake=Path(self.temp.name)/"mechanical-r"
        body = '''
import datetime as dt,json,shutil,sys
from pathlib import Path
sys.path.insert(0,TESTS)
from test_refresh_review import review_batch,seal_review_batch,utc,add_nl_forecast_input_evidence
config=json.loads(Path(CONFIG).read_text());root=Path.cwd()
script=next((Path(x).name for x in sys.argv if x.endswith(".R")),"")
with Path(TRACE).open("a") as h:h.write(json.dumps(dict(script=script,cwd=str(root),runtime=(root/"R/runtime_marker.txt").read_text()))+"\\n")
if script=="acquire_uefa_snapshot.R":
    p=root/"data/competition/mechanical-source.json";p.write_text(json.dumps(dict(at=utc(dt.datetime.now(dt.timezone.utc).replace(microsecond=0)),mechanical_only=True)))
elif script=="update_ucl_live_source.R":
    (root/"data/competition/mechanical-cl.txt").write_text("mechanical source only")
elif script=="refresh_nations_league_state.R":
    p=root/"outputs/competition/uefa_nations_league_2026_27/mechanical-state.txt";p.write_text("mechanical state only")
elif script=="build_nations_league_outcomes.R":
    p=root/"outputs/competition/uefa_nations_league_2026_27/mechanical-outcomes.json";p.write_text(json.dumps(dict(simulation_count=10000,mechanical_only=True)))
elif script=="stage_non_wc_dashboards.R":
    if config.get("fail_stage"):raise SystemExit(42)
    now=dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    shutil.rmtree(root/"docs/competitions")
    public=review_batch(root,now)
    captured=json.loads((root/"data/competition/mechanical-source.json").read_text())["at"]
    for route in ("nations-league","champions-league"):
        p=public/route/"payload.json";data=json.loads(p.read_text());data["metadata"]["last_refresh_at_utc"]=captured;data["metadata"]["source_as_of_utc"]=captured
        if route=="nations-league":add_nl_forecast_input_evidence(data,now,dt.datetime.fromisoformat(captured.replace("Z","+00:00")))
        if config.get("stale"):data["metadata"]["last_refresh_at_utc"]=utc(now-dt.timedelta(days=4))
        if config.get("preview") and route=="nations-league":data["metadata"]["simulation_count"]=100
        p.write_text(json.dumps(data))
    seal_review_batch(public,now)
elif script=="validate_non_wc_publication.R":
    if config.get("reject_authority"):raise SystemExit(65)
    if config.get("change_release_during_qa"):Path(MAIN_RELEASE).write_text("concurrent approved national release")
else:raise SystemExit("Unexpected mechanical R dispatch: "+script)
'''
        constants="\n".join("%s=%r"%(key,str(value)) for key,value in dict(
            TESTS=ROOT/"tests/operations",CONFIG=self.config,TRACE=self.trace,
            MAIN_RELEASE=self.root/"outputs/releases/approved_release.csv").items())
        self.fake.write_text("#!"+sys.executable+"\n"+constants+"\n"+body)
        self.fake.chmod(0o755)
        self.workspaces=[]
        self.addCleanup(self.cleanup_workspaces)

    def cleanup_workspaces(self):
        for path in self.workspaces:
            if path.parent.name.startswith("xgelo-refresh-"):
                shutil.rmtree(path.parent,ignore_errors=True)

    def run_refresh(self,mode=None,resume=None,push=False):
        self.config.write_text(json.dumps(mode or {}))
        flags=[] if push else ["--skip-push"]
        if resume:flags += ["--resume-failed",resume]
        args=refresh.parse_args(flags)
        def published(root,run):run.record["publication"]="verified"
        with mock.patch.object(refresh,"discover_rscript",return_value=(str(self.fake),"mechanical R only")), \
             mock.patch.object(refresh.subprocess,"check_output",return_value=str(self.root/".git")), \
             mock.patch.object(refresh,"publish_pages",side_effect=published) as publisher:
            result=refresh.refresh(args,self.root)
        record=refresh.read_json(self.root/"logs/competition-refresh/current.json")
        if record.get("private_workspace_path"):
            self.workspaces.append(Path(record["private_workspace_path"]))
        return result,record,publisher.call_count

    def failed(self):
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        result,record,_=self.run_refresh(dict(fail_stage=True))
        self.assertEqual(result,1);self.assertEqual(record["phase"],"dashboard_stage")
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),before)
        self.assertEqual(self.wc.read_text(),"protected WC")
        workspace=Path(record["private_workspace_path"])
        self.assertTrue(workspace.is_dir());self.assertTrue(record["workspace_retained"])
        self.assertTrue((workspace/"outputs/competition/uefa_nations_league_2026_27/mechanical-outcomes.json").is_file())
        return record,workspace

    def calls(self):
        return [json.loads(line) for line in self.trace.read_text().splitlines()]

    def test_stage_failure_retains_actual_completed_workspace_and_preserves_incumbent_wc(self):
        record,workspace=self.failed()
        self.assertTrue(any(x["phase"]=="nations_league_outcomes" and x["exit_code"]==0 for x in record["stages"]))
        self.assertEqual(workspace.parent.stat().st_mode & 0o777,0o700)
        self.assertEqual(workspace.parent.parent, self.root/"logs/competition-refresh/workspaces")

    def test_resume_reuses_outcomes_with_current_code_preserving_original_failed_snapshot(self):
        failed,original=self.failed()
        original_inventory=refresh.file_inventory(original,[Path("R"),Path("scripts"),Path("data"),Path("outputs/competition")])
        captured=(original/"data/competition/mechanical-source.json").read_bytes()
        (self.root/"R/runtime_marker.txt").write_text("current repaired runtime")
        (self.root/"scripts/runtime_marker.txt").write_text("current repaired scripts")
        start=len(self.calls())
        result,record,_=self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result,0)
        resumed=self.calls()[start:]
        self.assertEqual([r["script"] for r in resumed],["stage_non_wc_dashboards.R","validate_non_wc_publication.R"])
        self.assertTrue(all(r["runtime"]=="current repaired runtime" for r in resumed))
        self.assertTrue(record["reused_accepted_outcomes"])
        self.assertEqual((self.root/"data/competition/mechanical-source.json").read_bytes(),captured)
        self.assertEqual(refresh.file_inventory(original,[Path("R"),Path("scripts"),Path("data"),Path("outputs/competition")]),original_inventory)
        self.assertTrue(original.is_dir());self.assertFalse(Path(record["private_workspace_path"]).exists())
        self.assertTrue(record["workspace_installed"]);self.assertFalse(record["workspace_retained"])
        self.assertEqual(self.wc.read_text(),"protected WC")

    def test_stale_preview_and_rejected_r_authority_cannot_install(self):
        failed,original=self.failed()
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        for mode in (dict(stale=True),dict(preview=True),dict(reject_authority=True)):
            with self.subTest(mode=mode):
                result,record,published=self.run_refresh(mode,resume=failed["run_id"])
                self.assertEqual(result,1);self.assertEqual(published,0)
                self.assertFalse(record.get("workspace_installed",False));self.assertTrue(record["workspace_retained"])
                self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),before)
        self.assertTrue(original.exists())

    def test_resume_restores_exact_missing_archive_and_release_in_recovery_copy(self):
        raw = "data/competition/local_raw/archive/results.json"
        release = "outputs/releases/approved_release.csv"
        archive = self.root/raw
        archive.parent.mkdir(parents=True)
        archive.write_text("archived source bytes")
        seed = "data/processed/elo_ratings.csv"
        seed_file = self.root/seed
        seed_file.parent.mkdir(parents=True)
        seed_file.write_text("original Elo seed")
        refresh.atomic_json(self.root/"outputs/competition/uefa_nations_league_2026_27/forecast_inputs/elo_provenance.json",
                            {"seed_sha256": refresh.sha(seed_file)})
        failed, original = self.failed()
        missing = (raw, release, seed)
        for relative in missing:
            (original/relative).unlink()
        result, record, _ = self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result, 0)
        self.assertCountEqual(record["restored_recovery_inputs"], missing)
        self.assertEqual(archive.read_text(), "archived source bytes")
        self.assertTrue(all(not (original/relative).exists() for relative in missing))

    def test_resume_cannot_replace_a_missing_managed_output_with_the_old_version(self):
        failed, original = self.failed()
        missing = "outputs/competition/uefa_nations_league_2026_27/mechanical-incumbent.txt"
        (original/missing).unlink()
        result, record, _ = self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result, 1)
        self.assertIn("missing a required artifact", record["error"])
        self.assertEqual((self.root/missing).read_text(), "original")

    def test_changed_main_managed_inputs_prevent_resume(self):
        failed,original=self.failed()
        (self.root/"data/competition/mechanical-incumbent.txt").write_text("new main state")
        calls=len(self.calls())
        result,record,_=self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result,1);self.assertIn("changed",record["error"])
        self.assertEqual(len(self.calls()),calls);self.assertTrue(original.exists())
        self.assertEqual((self.root/"data/competition/mechanical-incumbent.txt").read_text(),"new main state")

    def test_changed_national_release_prevents_resume_but_disabled_club_release_does_not(self):
        failed,original=self.failed()
        (self.root/"outputs/releases/approved_release.csv").write_text("new national release")
        result,record,_=self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result,1);self.assertIn("approved releases changed",record["error"])
        (self.root/"outputs/releases/approved_release.csv").write_text("original")
        (self.root/"outputs/releases/club/marker.txt").write_text("new unrelated disabled club release")
        result,_,_=self.run_refresh(resume=failed["run_id"])
        self.assertEqual(result,0);self.assertTrue(original.exists())

    def test_national_release_changed_during_staging_prevents_install(self):
        failed,_=self.failed()
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        result,record,_=self.run_refresh(dict(change_release_during_qa=True),resume=failed["run_id"])
        self.assertEqual(result,1);self.assertIn("Approved releases changed during refresh",record["error"])
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),before)

    def test_guard_rejects_runid_record_mismatch_symlinks_and_missing_completed_outcomes(self):
        failed,workspace=self.failed()
        path=self.root/"logs/competition-refresh/runs"/(failed["run_id"]+".json")
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        releases=refresh.approved_release_inventory(self.root)
        for run_id in ("../bad","20261105T000000Z-invalid","",failed["run_id"]+"/other"):
            with self.assertRaises(refresh.RefreshError):refresh.resolve_failed_workspace(self.root,run_id,before,releases)
        for changed in (dict(run_id="different"),dict(stages=[]),dict(workspace_retained=False),dict(status="success")):
            refresh.atomic_json(path,dict(failed,**changed))
            with self.assertRaises(refresh.RefreshError):refresh.resolve_failed_workspace(self.root,failed["run_id"],before,releases)
        refresh.atomic_json(path,failed)
        alias=Path(tempfile.mkdtemp(prefix="xgelo-refresh-"+failed["run_id"]+"-"));alias.rmdir();alias.symlink_to(workspace.parent,target_is_directory=True)
        self.addCleanup(alias.unlink)
        refresh.atomic_json(path,dict(failed,private_workspace_path=str(alias/"project")))
        with self.assertRaises(refresh.RefreshError):refresh.resolve_failed_workspace(self.root,failed["run_id"],before,releases)
        direct=Path(tempfile.mkdtemp(prefix="xgelo-refresh-"+failed["run_id"]+"-"));(direct/"project").symlink_to(workspace,target_is_directory=True)
        self.workspaces.append(direct/"project")
        refresh.atomic_json(path,dict(failed,private_workspace_path=str(direct/"project")))
        with self.assertRaises(refresh.RefreshError):refresh.resolve_failed_workspace(self.root,failed["run_id"],before,releases)

    def test_guard_rejects_wrong_owner_and_nondirect_temp_location(self):
        failed,workspace=self.failed()
        before=refresh.file_inventory(self.root,refresh.managed_paths(self.root));releases=refresh.approved_release_inventory(self.root)
        real_stat=Path.stat
        def wrong_owner(path,*args,**kwargs):
            value=real_stat(path,*args,**kwargs)
            if path==workspace:
                parts=list(value);parts[4]=os.getuid()+1;return os.stat_result(parts)
            return value
        with mock.patch.object(Path,"stat",wrong_owner),self.assertRaises(refresh.RefreshError):
            refresh.resolve_failed_workspace(self.root,failed["run_id"],before,releases)
        nested=Path(self.temp.name)/("xgelo-refresh-"+failed["run_id"]+"-nested")/"project";nested.mkdir(parents=True)
        refresh.atomic_json(self.root/"logs/competition-refresh/runs"/(failed["run_id"]+".json"),dict(failed,private_workspace_path=str(nested)))
        with self.assertRaises(refresh.RefreshError):refresh.resolve_failed_workspace(self.root,failed["run_id"],before,releases)

    def test_cleanup_failure_is_soft_after_install_and_does_not_block_publication(self):
        failed,original=self.failed()
        real_rmtree=shutil.rmtree
        def cannot_clean(path,*args,**kwargs):
            path=Path(path)
            if path.name.startswith("xgelo-refresh-") and path!=original.parent:
                raise OSError("injected private-workspace cleanup failure")
            return real_rmtree(path,*args,**kwargs)
        with mock.patch.object(refresh.shutil,"rmtree",side_effect=cannot_clean):
            result,record,published=self.run_refresh(resume=failed["run_id"],push=True)
        self.assertEqual(result,0);self.assertEqual(published,1)
        self.assertTrue(record["workspace_installed"]);self.assertTrue(record["workspace_retained"])
        self.assertIn("cleanup failure",record["workspace_cleanup_error"])
        self.assertEqual(record["publication"],"verified");self.assertTrue(original.exists())


if __name__=="__main__":unittest.main()
