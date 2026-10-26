import importlib.util
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest

spec = importlib.util.spec_from_file_location('scale_watchdog', Path(__file__).resolve().parents[1] / 'scripts/validate_simulation_scale.py')
scale = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scale)


class ScaleWatchdogTests(unittest.TestCase):
    def pilots(self):
        return [dict(status='passed', count=n, wall_seconds=10 + n * .02,
                     peak_process_tree_rss_bytes=1000, trace_bytes=n * 100,
                     implementation_sha256='same') for n in (1000, 10000)]

    def test_conservative_time_memory_disk_and_code_gates(self):
        pilots = self.pilots()
        self.assertTrue(scale.preflight(pilots, 10000, 10**10)[0])
        slow = self.pilots(); slow[1]['wall_seconds'] = 1000
        self.assertFalse(scale.preflight(slow, 10000, 10**10)[0])
        self.assertFalse(scale.preflight(pilots, 2000, 10**10)[0])
        self.assertFalse(scale.preflight(pilots, 10000, 1000)[0])
        changed = self.pilots(); changed[1]['implementation_sha256'] = 'changed'
        self.assertFalse(scale.preflight(changed, 10000, 10**10)[0])
        bad = self.pilots(); bad[0]['status'] = 'failed'
        self.assertFalse(scale.preflight(bad, 10000, 10**10)[0])

    def test_resume_accounts_for_previous_active_time(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / 'R').mkdir(); (root / 'scripts').mkdir()
            destination = root / 'nl'; destination.mkdir()
            csv = destination / 'measurement-1000.csv'
            code = "from pathlib import Path; Path(" + repr(str(csv)) + ").write_text('validated,trace_bytes,implementation_sha256\\nTRUE,20,same\\n')"
            prior = dict(status='failed', wall_seconds=30, peak_process_tree_rss_bytes=123)
            receipt = scale.run_checked([sys.executable, '-c', code], root, destination, 'nl', 1000, 10**12, 7200, prior)
            self.assertEqual(receipt['status'], 'passed')
            self.assertGreaterEqual(receipt['wall_seconds'], 30)
            self.assertGreaterEqual(receipt['peak_process_tree_rss_bytes'], 123)
            self.assertFalse(receipt['production_certified'])
            self.assertGreater(receipt['peak_disk_bytes'], 0)
            with self.assertRaisesRegex(RuntimeError, 'exhausted'):
                scale.run_checked([], root, destination, 'nl', 1000, 10**12, 7200, dict(status='failed', wall_seconds=7200))
            with self.assertRaisesRegex(RuntimeError, 'unfinalized'):
                scale.run_checked([], root, destination, 'nl', 1000, 10**12, 7200, dict(status='running', wall_seconds=1))

    def test_snapshot_detects_code_changes_and_json_is_atomic(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / 'R').mkdir(); (root / 'scripts').mkdir()
            file = root / 'R/kernel.R'; file.write_text('first')
            before = scale.source_snapshot(root); file.write_text('second')
            self.assertNotEqual(before, scale.source_snapshot(root))
            receipt = root / 'receipt.json'; scale.atomic_json(receipt, {'status': 'passed'})
            self.assertIn('passed', receipt.read_text())
            self.assertFalse(receipt.with_suffix('.next').exists())

    def test_cleanup_reaps_an_owned_group_after_parent_exit(self):
        code = "import subprocess,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],stderr=subprocess.DEVNULL); print('ready',flush=True)"
        process = subprocess.Popen([sys.executable, '-c', code], start_new_session=True, stdout=subprocess.PIPE, text=True)
        self.assertEqual(process.stdout.readline().strip(), 'ready')
        process.wait(timeout=2)
        scale.stop_owned_group(process)
        self.assertFalse(scale.owned_group_alive(process.pid))
        process.stdout.close()


if __name__ == '__main__':
    unittest.main()
