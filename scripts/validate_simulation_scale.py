#!/usr/bin/env python3
"""Sequential NL/CL scale checks with a process-tree resource watchdog.

Only completed R candidate validations qualify. Synthetic CL evidence never
changes production eligibility. A denied/unavailable memory measurement fails
closed. All files are private diagnostics/checkpoints; no publisher is called.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time


def physical_memory():
    if Path('/proc/meminfo').exists():
        for line in Path('/proc/meminfo').read_text().splitlines():
            if line.startswith('MemTotal:'):
                return int(line.split()[1]) * 1024
    return int(subprocess.check_output(['/usr/sbin/sysctl', '-n', 'hw.memsize'], text=True).strip())


def process_tree_rss(root_pid):
    output = subprocess.check_output(['/bin/ps', '-axo', 'pid=,ppid=,rss='], text=True)
    rows = [tuple(map(int, line.split())) for line in output.splitlines() if line.strip()]
    owned = {root_pid, os.getpid()}
    while True:
        expanded = owned | {pid for pid, parent, _ in rows if parent in owned}
        if expanded == owned:
            break
        owned = expanded
    return sum(rss * 1024 for pid, _, rss in rows if pid in owned)


def source_snapshot(root):
    files = sorted(list((root / 'R').rglob('*.R')) + list((root / 'scripts').glob('*.R')) + list((root / 'scripts').glob('*.py')))
    payload = [(str(path.relative_to(root)), hashlib.sha256(path.read_bytes()).hexdigest()) for path in files]
    return hashlib.sha256(json.dumps(payload, separators=(',', ':')).encode()).hexdigest()


def directory_bytes(directory):
    total = 0
    for path in directory.rglob('*'):
        try:
            if path.is_file():
                total += path.stat().st_size
        except FileNotFoundError:
            pass
    return total


def atomic_json(path, value):
    temporary = path.with_suffix('.next')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def preflight(previous, ram, free_disk, seconds=7200):
    if len(previous) < 2 or [r['count'] for r in previous[-2:]] != [1000, 10000]:
        return False, 'completed 1k and 10k checks are required'
    pilots = previous[-2:]
    if any(r['status'] != 'passed' for r in pilots):
        return False, 'a pilot did not pass validation'
    if pilots[0]['implementation_sha256'] != pilots[1]['implementation_sha256']:
        return False, 'implementation changed between pilots'
    if pilots[0].get('source_snapshot_sha256') != pilots[1].get('source_snapshot_sha256'):
        return False, 'source changed between pilots'
    if pilots[0].get('inputs') != pilots[1].get('inputs'):
        return False, 'accepted inputs changed between pilots'
    slope = max((pilots[1]['wall_seconds'] - pilots[0]['wall_seconds']) / 9000, pilots[1]['wall_seconds'] / 10000)
    fixed = max(0, pilots[0]['wall_seconds'] - 1000 * slope)
    projected_seconds = 1.2 * (fixed + 100000 * slope)
    projected_disk = max(max(r['trace_bytes'], r.get('peak_disk_bytes', 0)) * 100000 / r['count'] for r in pilots)
    if projected_seconds > seconds:
        return False, f'projected total {projected_seconds:.1f}s exceeds {seconds}s'
    if max(r['peak_process_tree_rss_bytes'] for r in pilots) >= ram / 2:
        return False, 'pilot memory reached half physical RAM'
    if free_disk < 2 * projected_disk + 1024**3:
        return False, 'insufficient disk for traces and temporary canonical sorting'
    return True, f'projected total {projected_seconds:.1f}s qualifies'


def owned_group_alive(group):
    output = subprocess.check_output(['/bin/ps', '-axo', 'pid=,pgid=,stat='], text=True)
    return any(int(parts[1]) == group and not parts[2].startswith('Z')
               for line in output.splitlines() if len(parts := line.split()) == 3)


def stop_owned_group(process):
    # Popen starts a new session with PGID == PID. Clean up its workers even
    # when the parent already crashed; a reaped parent is not proof of cleanup.
    for sig, grace in ((signal.SIGINT, 10), (signal.SIGTERM, 5), (signal.SIGKILL, 2)):
        if not owned_group_alive(process.pid):
            break
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            break
        except PermissionError:
            if owned_group_alive(process.pid):
                raise
            break
        deadline = time.monotonic() + grace
        while time.monotonic() < deadline and owned_group_alive(process.pid):
            process.poll()
            time.sleep(.1)
    process.wait(timeout=2)
    if owned_group_alive(process.pid):
        raise RuntimeError('owned benchmark workers did not exit')


def run_checked(command, root, destination, competition, count, ram, seconds, prior=None, frozen_source=None):
    source = source_snapshot(root)
    if frozen_source is not None and source != frozen_source:
        raise RuntimeError('source changed since staged checks started')
    if prior is not None and prior.get('status') not in ('passed', 'failed'):
        raise RuntimeError('unfinalized previous attempt cannot certify cumulative execution time')
    previous_seconds = float((prior or {}).get('wall_seconds', 0))
    if previous_seconds >= seconds:
        raise RuntimeError('cumulative active time budget is already exhausted')
    receipt = dict(competition=competition, count=count, status='running', command=command,
                   physical_memory_bytes=ram, memory_limit_bytes=ram // 2,
                   time_limit_seconds=seconds, peak_process_tree_rss_bytes=(prior or {}).get('peak_process_tree_rss_bytes', 0),
                   peak_disk_bytes=(prior or {}).get('peak_disk_bytes', 0), prior_active_seconds=previous_seconds,
                   attempt_history=(prior or {}).get('attempt_history', []) + ([{key: prior.get(key) for key in ('status', 'wall_seconds', 'source_snapshot_sha256')}] if prior else []))
    path = destination / f'resource-{count}.json'
    receipt['source_snapshot_sha256'] = source
    started = time.monotonic()
    atomic_json(path, receipt)
    with (destination / f'run-{count}.log').open('w') as log:
        process = subprocess.Popen(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        last_report = -30.0
        try:
            while process.poll() is None:
                elapsed = time.monotonic() - started
                rss = process_tree_rss(process.pid)
                receipt['peak_process_tree_rss_bytes'] = max(receipt['peak_process_tree_rss_bytes'], rss)
                receipt['wall_seconds'] = previous_seconds + elapsed
                receipt['peak_disk_bytes'] = max(receipt['peak_disk_bytes'], directory_bytes(destination))
                if rss >= ram / 2:
                    raise RuntimeError('process-tree RSS reached half physical RAM')
                if previous_seconds + elapsed >= seconds:
                    raise RuntimeError('total run time reached the two-hour budget')
                if shutil.disk_usage(destination).free < 512 * 1024**2:
                    raise RuntimeError('less than 512 MiB free disk remains')
                if elapsed - last_report >= 30:
                    print(f'{competition} count={count} elapsed={elapsed:.1f}s tree_rss={rss} peak_rss={receipt["peak_process_tree_rss_bytes"]}', flush=True)
                    atomic_json(path, receipt)
                    last_report = elapsed
                time.sleep(1)
            if previous_seconds + time.monotonic() - started >= seconds:
                raise RuntimeError("total run time reached the two-hour budget")
            if process.returncode:
                raise RuntimeError(f'benchmark exited {process.returncode}; inspect run-{count}.log')
            measurement_path = destination / (f'measurement-{count}.csv' if competition == 'nl' else f'cl-{count}-4.csv')
            with measurement_path.open() as source:
                measurements = list(csv.DictReader(source))
            if len(measurements) != 1 or measurements[0].get('validated') != 'TRUE':
                raise RuntimeError('benchmark did not write a validated candidate receipt')
            row = measurements[0]
            if receipt['source_snapshot_sha256'] != source_snapshot(root):
                raise RuntimeError('source code changed during benchmark')
            receipt['inputs'] = {key: row[key] for key in ('seed', 'source_bundle_id', 'state_manifest_sha256', 'graph_sha256', 'ledger_sha256', 'ruleset_sha256', 'information_cutoff_utc', 'algorithm_version') if key in row}
            receipt.update(status='passed', trace_bytes=int(float(row['trace_bytes'])),
                           implementation_sha256=row['implementation_sha256'],
                           authority='accepted_national' if competition == 'nl' else 'synthetic_fixture_only',
                           production_certified=competition == 'nl' and count == 100000)
        except BaseException as error:
            stop_owned_group(process)
            receipt.update(status='failed', reason=str(error) or type(error).__name__, production_certified=False)
            if isinstance(error, KeyboardInterrupt):
                raise
        finally:
            receipt['attempt_wall_seconds'] = time.monotonic() - started
            receipt['wall_seconds'] = previous_seconds + receipt['attempt_wall_seconds']
            receipt['peak_disk_bytes'] = max(receipt['peak_disk_bytes'], directory_bytes(destination))
            measurement_path = destination / (f'measurement-{count}.csv' if competition == 'nl' else f'cl-{count}-4.csv')
            if measurement_path.exists():
                receipt['measurement_sha256'] = hashlib.sha256(measurement_path.read_bytes()).hexdigest()
                atomic_json(Path(str(measurement_path) + '.resources.json'), receipt)
            atomic_json(path, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--asset-root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--competition', choices=['nl', 'cl', 'both'], default='both')
    parser.add_argument('--scales', default='1000,10000,100000')
    parser.add_argument('--rscript', default='/opt/homebrew/opt/r/bin/Rscript')
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve(); args.output.mkdir(parents=True, exist_ok=True)
    ram = physical_memory()
    scales = list(map(int, args.scales.split(',')))
    if scales != [1000, 10000, 100000] and scales != [1000, 10000] and scales != [1000]:
        parser.error('use staged scales: 1000; 1000,10000; or 1000,10000,100000')
    frozen_source = source_snapshot(root)
    if Path(__file__).resolve() != root / "scripts/validate_simulation_scale.py":
        parser.error("run the supervisor from the checkout being measured")
    exit_code = 0
    for competition in (['nl', 'cl'] if args.competition == 'both' else [args.competition]):
        destination = (args.output / competition).resolve(); destination.mkdir(exist_ok=True)
        completed = []
        for count in scales:
            if count == 100000:
                qualifies, reason = preflight(completed, ram, shutil.disk_usage(destination).free)
                if not qualifies:
                    atomic_json(destination / 'gate-100000.json', dict(status='blocked', reason=reason, production_certified=False))
                    print(f'{competition} 100k withheld: {reason}', flush=True)
                    exit_code = max(exit_code, 2)
                    break
            if competition == 'nl':
                command = [args.rscript, '--vanilla', 'scripts/benchmark_nations_league_scale.R',
                           str((args.asset_root or root).resolve()), str(count), str(destination), '4']
            else:
                command = [args.rscript, '--vanilla', 'scripts/benchmark_champions_league_scale.R', str(count), '4', str(destination)]
            if args.resume:
                os.environ['XGELO_SIM_RESUME'] = '1'
            receipt_path = destination / f'resource-{count}.json'
            prior = json.loads(receipt_path.read_text()) if receipt_path.exists() else None
            if prior is not None and not args.resume:
                print(f'{competition} count={count} already has evidence; use --resume or a new output directory', flush=True)
                return 1
            if prior is None and args.resume and (destination / f'run-{count}' / 'manifest.rds').exists():
                print('cannot certify checkpoint reuse without its previous resource receipt', flush=True)
                return 1
            try:
                result = run_checked(command, root, destination, competition, count, ram, 7200, prior, frozen_source)
            except RuntimeError as error:
                print(f'{competition} stopped before execution: {error}', flush=True)
                return 1
            if count == 100000 and completed and result.get('inputs') != completed[-1].get('inputs'):
                result.update(status='failed', reason='inputs changed after the 10k check', production_certified=False)
                atomic_json(destination / f'resource-{count}.json', result)
                measurement = destination / (f'measurement-{count}.csv' if competition == 'nl' else f'cl-{count}-4.csv')
                atomic_json(Path(str(measurement) + '.resources.json'), result)
            completed.append(result)
            if result['status'] != 'passed':
                print(f'{competition} stopped: {result["reason"]}', flush=True)
                exit_code = 1
                break
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
