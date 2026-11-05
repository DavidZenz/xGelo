#!/usr/bin/env python3
"""Install/reload only the non-WC LaunchAgent; preserve all WC services."""
import argparse
import datetime as dt
import os
from pathlib import Path
import plistlib
import subprocess
import sys
from competition_refresh import ROOT, discover_rscript, parse_args


def definition(root=ROOT, verification_at=None):
    root = Path(root).resolve()
    calendar = {"Hour":3,"Minute":0}
    if verification_at:
        calendar = [calendar,{"Month":verification_at.month,"Day":verification_at.day,
                              "Hour":verification_at.hour,"Minute":verification_at.minute}]
    return dict(Label="com.xgelo.competition-dashboards",WorkingDirectory=str(root),
        ProgramArguments=["/bin/bash",str(root/"scripts/auto_update_competition_dashboards.sh"),"--scheduled"],
        RunAtLoad=False,StartCalendarInterval=calendar,
        EnvironmentVariables={"PATH":"/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"},
        StandardOutPath=str(root/"logs/competition-dashboard-update.out"),
        StandardErrorPath=str(root/"logs/competition-dashboard-update.err"))


def install(verification_minutes=None, directory=None):
    executable, diagnostic = discover_rscript(ROOT)
    resources = parse_args([])
    print(diagnostic)
    domain = "gui/"+str(os.getuid())
    label = domain+"/com.xgelo.competition-dashboards"
    current = subprocess.run(["launchctl","print",label],capture_output=True,text=True)
    # A live controller must finish/roll back through its own transaction.
    for line in current.stdout.splitlines():
        if line.strip().startswith("pid ="):
            raise RuntimeError("The scheduled refresh is active; retry installation after it finishes")
    verify = None
    if verification_minutes is not None:
        verify = dt.datetime.now().astimezone()+dt.timedelta(minutes=verification_minutes)
    config = definition(ROOT,verify)
    config["EnvironmentVariables"].update(XGELO_NL_SIMULATIONS=str(resources.simulations),
                                          XGELO_NL_WORKERS=str(resources.workers))
    if os.environ.get("XGELO_RSCRIPT"):
        config["EnvironmentVariables"]["XGELO_RSCRIPT"] = executable
    if os.environ.get("XGELO_PYTHON"):
        config["EnvironmentVariables"]["XGELO_PYTHON"] = os.environ["XGELO_PYTHON"]
    directory = Path(directory or os.environ.get("XGELO_LAUNCH_AGENT_DIR",str(Path.home()/"Library/LaunchAgents")))
    directory.mkdir(parents=True,exist_ok=True)
    target = directory/"com.xgelo.competition-dashboards.plist"
    before = target.read_bytes() if target.exists() else None
    temp = target.with_suffix(".plist.tmp")
    temp.write_bytes(plistlib.dumps(config))
    temp.chmod(0o644)
    os.replace(temp,target)
    (ROOT/"logs").mkdir(exist_ok=True)
    try:
        if current.returncode == 0:
            subprocess.run(["launchctl","bootout",label],check=True,capture_output=True,text=True)
        subprocess.run(["launchctl","bootstrap",domain,str(target)],check=True,capture_output=True,text=True)
        subprocess.run(["launchctl","print",label],check=True,capture_output=True,text=True)
    except BaseException:
        subprocess.run(["launchctl","bootout",label],capture_output=True,text=True)
        if before is not None:
            temp.write_bytes(before)
            os.replace(temp,target)
            subprocess.run(["launchctl","bootstrap",domain,str(target)],capture_output=True,text=True)
        else:
            target.unlink(missing_ok=True)
        raise
    print("Installed non-WC refresh at03:00 local time; Rscript="+executable)
    if verify:
        print("Additional real calendar verification run scheduled for "+verify.isoformat(timespec="minutes"))
        print("After verifying that run, reinstall without --verify-in-minutes to remove the extra calendar entry.")
    return config


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-in-minutes",type=int)
    args=parser.parse_args()
    if args.verify_in_minutes is not None and not 2 <= args.verify_in_minutes <= 60:
        parser.error("--verify-in-minutes must be between2 and60")
    try:
        install(args.verify_in_minutes)
    except Exception as error:
        print("Scheduler installation failed: "+str(error),file=sys.stderr)
        raise SystemExit(1)
