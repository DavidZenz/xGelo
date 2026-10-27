import json
import os
from pathlib import Path
import subprocess
import sys
import time

name, *arguments = sys.argv[1:]
root = Path("/private/tmp/xgelo-active-dashboards")
workspace = Path("/private/tmp/xgelo-authority-manifest-repair")
log = workspace / (name + ".log")
environment = dict(os.environ)
environment["PATH"] = "/opt/homebrew/opt/r/bin:" + environment.get("PATH", "")
environment["FOOTBALL_DATA_API_TOKEN"] = ""
environment["PYTHONDONTWRITEBYTECODE"] = "1"
command = ["/opt/homebrew/opt/r/bin/Rscript", "--vanilla", *arguments]
started = time.monotonic()
with log.open("w") as output:
    process = subprocess.run(command, cwd=root, env=environment,
                             stdout=output, stderr=subprocess.STDOUT)
receipt = dict(name=name, exit_code=process.returncode, wall_seconds=time.monotonic()-started,
               command=command, credential_environment_cleared=True,
               output=log.read_text())
(workspace / (name + ".json")).write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({k:v for k,v in receipt.items() if k != "output"}, indent=2))
print(receipt["output"])
raise SystemExit(process.returncode)
