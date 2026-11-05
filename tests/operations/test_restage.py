"""Render-only orchestration faults; temporary mechanical inputs, no authority claims."""
import datetime as dt
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tests/operations"))
sys.path.insert(0,str(ROOT/"scripts"))
from test_refresh_review import review_batch,seal_review_batch
import competition_refresh as refresh



class RestageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/"project";self.root.mkdir()
        subprocess.run(["git","init","--quiet",str(self.root)],check=True,capture_output=True)
        self.now=dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        review_batch(self.root,self.now)
        for relative in refresh.managed_paths(self.root):
            (self.root/relative).mkdir(parents=True,exist_ok=True)
        self.state=self.root/"outputs/competition/uefa_nations_league_2026_27/accepted-outcomes.txt"
        self.state.write_text("mechanical existing outcomes, never model authority")
        self.wc=self.root/"docs/wc2026/index.html";self.wc.parent.mkdir();self.wc.write_text("protected WC")
        self.before=refresh.file_inventory(self.root,refresh.managed_paths(self.root))
        self.commands=[]

    def command(self,run,phase,args,**kwargs):
        self.commands.append((phase,[str(a) for a in args]))
        if any(name in " ".join(map(str,args)) for name in ("acquire_uefa_snapshot.R",
                "update_ucl_live_source.R","refresh_nations_league_state.R","build_nations_league_outcomes.R")):
            raise AssertionError("Render-only retry must not reacquire or simulate")
        if phase=="dashboard_stage":
            workspace=Path(kwargs["cwd"])
            self.assertEqual((workspace/self.state.relative_to(self.root)).read_bytes(),self.state.read_bytes())
            review_batch(workspace,self.now)
            (workspace/refresh.PUBLIC/"champions-league/index.html").write_text("<!doctype html><title>re-rendered candidate</title>")
            seal_review_batch(workspace/refresh.PUBLIC,self.now)

    def execute(self,command=None):
        # Genuine R authority validation has independent production-backed tests;
        # this fixture tests only controller dispatch/install failure boundaries.
        with mock.patch.object(refresh,"discover_rscript",return_value=("/test/Rscript","mechanical test")), \
             mock.patch.object(refresh.Run,"command",autospec=True,side_effect=command or self.command):
            return refresh.refresh(refresh.parse_args(["--restage-only","--skip-push"]),self.root)

    def test_render_only_reuses_outcome_bytes_and_keeps_all_validation_and_receipts(self):
        self.assertEqual(self.execute(),0)
        self.assertEqual([p for p,_ in self.commands],["dashboard_stage","candidate_authority_qa"])
        self.assertEqual(self.state.read_text(),"mechanical existing outcomes, never model authority")
        self.assertEqual(self.wc.read_text(),"protected WC")
        run=refresh.read_json(self.root/"logs/competition-refresh/current.json")
        self.assertTrue(run["reused_accepted_outcomes"])
        self.assertEqual(run["publication"],"local_only")
        receipt=refresh.read_json(self.root/"logs/competition-refresh/validated-install.json")
        self.assertEqual(receipt["public_inventory"],refresh.validate_public_bytes(self.root/refresh.PUBLIC))

    def test_rejected_real_authority_boundary_never_installs_a_re_render(self):
        def rejected(run,phase,args,**kwargs):
            self.command(run,phase,args,**kwargs)
            if phase=="candidate_authority_qa":
                raise refresh.RefreshError("accepted model/source lineage rejected")
        self.assertEqual(self.execute(rejected),1)
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),self.before)
        self.assertEqual(self.wc.read_text(),"protected WC")

    def test_re_render_cannot_relabel_stale_sources_as_fresh(self):
        def stale(run,phase,args,**kwargs):
            self.command(run,phase,args,**kwargs)
            if phase=="dashboard_stage":
                workspace=Path(kwargs["cwd"]);p=workspace/refresh.PUBLIC/"nations-league/payload.json"
                d=refresh.read_json(p);d["metadata"]["last_refresh_at_utc"]="2026-10-08T01:12:51Z"
                refresh.atomic_json(p,d);seal_review_batch(workspace/refresh.PUBLIC,self.now)
        self.assertEqual(self.execute(stale),1)
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),self.before)

    def test_preview_precision_still_cannot_publish_through_render_only(self):
        def preview(run,phase,args,**kwargs):
            self.command(run,phase,args,**kwargs)
            if phase=="dashboard_stage":
                workspace=Path(kwargs["cwd"]);p=workspace/refresh.PUBLIC/"nations-league/payload.json"
                d=refresh.read_json(p);d["metadata"]["simulation_count"]=100
                refresh.atomic_json(p,d);seal_review_batch(workspace/refresh.PUBLIC,self.now)
        self.assertEqual(self.execute(preview),1)
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),self.before)

    def test_render_failure_preserves_the_last_success_and_existing_batch(self):
        base=self.root/"logs/competition-refresh"
        refresh.atomic_json(base/"last-success.json",{"run_id":"prior-verified-run","completed_at_utc":"2026-11-05T10:00:00Z"})
        def failed(run,phase,args,**kwargs):
            raise refresh.RefreshError("rendering failed before validation")
        self.assertEqual(self.execute(failed),1)
        self.assertEqual(refresh.read_json(base/"last-success.json")["run_id"],"prior-verified-run")
        self.assertEqual(refresh.file_inventory(self.root,refresh.managed_paths(self.root)),self.before)

    def test_real_scheduler_cannot_accidentally_take_render_only_shortcut(self):
        for extra in ("--scheduled","--publish-only","--dry-run"):
            with self.subTest(extra=extra),self.assertRaises(SystemExit):
                refresh.parse_args(["--restage-only",extra])


if __name__=="__main__":
    unittest.main()
