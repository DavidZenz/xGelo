"""Sequential source-frozen NL pilots, final CL certification, then NL 100k."""
import csv, hashlib, importlib.util, json, os, shutil, subprocess, sys
from pathlib import Path
root=Path('/private/tmp/xgelo-active-dashboards')
output=Path('/private/tmp/xgelo-cpu-certification-v3')
evidence=root/'.planning/simulation-optimization/cpu-implementation'
freeze=json.loads((evidence/'frozen-source-v3.json').read_text())
gate=json.loads((evidence/'final-regressions-v3.json').read_text())
spec=importlib.util.spec_from_file_location('scale',root/'scripts/validate_simulation_scale.py')
scale=importlib.util.module_from_spec(spec);spec.loader.exec_module(scale)
ram=scale.physical_memory()
def guard():
    if not gate.get('performance_gate_valid') or gate.get('source_snapshot_sha256')!=freeze['source_snapshot_sha256'] or scale.source_snapshot(root)!=freeze['source_snapshot_sha256']:
        raise SystemExit('Regression/source freeze mismatch')
    if subprocess.check_output(['git','diff','--name-only','16f81f2','--','docs','data','outputs'],cwd=root):
        raise SystemExit('Protected bytes changed')
def supervise(competition,scales):
    guard()
    with (output/(competition+'-supervisor.log')).open('w') as log:
        code=subprocess.call([sys.executable,'-B',str(root/'scripts/validate_simulation_scale.py'),'--root',str(root),'--asset-root',str(root),'--output',str(output),'--competition',competition,'--scales',scales],cwd=root,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),stdout=log,stderr=subprocess.STDOUT)
    print(competition,'supervisor_exit',code,flush=True)
    if code: raise SystemExit(code)
def pilots():
    receipts=[]
    for count in (1000,10000):
        receipt=json.loads((output/'nl'/f'resource-{count}.json').read_text())
        measurement=output/'nl'/f'measurement-{count}.csv'
        row=list(csv.DictReader(measurement.open()))
        if receipt['status']!='passed' or receipt['count']!=count or receipt['source_snapshot_sha256']!=freeze['source_snapshot_sha256'] or receipt['implementation_sha256']!=freeze['implementation_sha256'] or hashlib.sha256(measurement.read_bytes()).hexdigest()!=receipt['measurement_sha256'] or len(row)!=1 or row[0].get('validated')!='TRUE' or int(row[0]['simulations'])!=count:
            raise SystemExit('NL pilot receipt/measurement mismatch')
        receipts.append(receipt)
    return receipts
def admit(name):
    guard(); previous=pilots()
    free=shutil.disk_usage(output/'nl').free
    ok,reason=scale.preflight(previous,ram,free)
    scale.atomic_json(output/'nl'/name,dict(status='passed' if ok else 'blocked',reason=reason,source_snapshot_sha256=freeze['source_snapshot_sha256'],physical_memory_bytes=ram,free_disk_bytes=free,production_certified=False))
    print('NL 100k admission',reason,flush=True)
    if not ok: raise SystemExit(2)
    return previous
guard();output.mkdir(exist_ok=False)
supervise('nl','1000,10000')
admit('gate-after-pilots.json')
supervise('cl','1000,10000,100000')
previous=admit('gate-before-100000.json')
destination=(output/'nl').resolve()
command=['/opt/homebrew/opt/r/bin/Rscript','--vanilla','scripts/benchmark_nations_league_scale.R',str(root),'100000',str(destination),'4']
result=scale.run_checked(command,root,destination,'nl',100000,ram,7200,frozen_source=freeze['source_snapshot_sha256'])
if result.get('inputs')!=previous[-1].get('inputs'):
    result.update(status='failed',reason='inputs changed after the 10k check',production_certified=False)
    scale.atomic_json(destination/'resource-100000.json',result)
    scale.atomic_json(Path(str(destination/'measurement-100000.csv')+'.resources.json'),result)
guard()
print('NL100K',result['status'],result.get('wall_seconds'),result.get('peak_process_tree_rss_bytes'),flush=True)
raise SystemExit(0 if result['status']=='passed' else 1)
