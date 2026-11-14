#!/usr/bin/env python3
"""Run the iOS model/service regressions without contacting any live server."""
from pathlib import Path
import subprocess
import sys

directory = Path(__file__).resolve().parent
for suite in ("settings-regressions", "list-regressions", "loading-regressions", "notification-regressions"):
    runner = directory / suite / "run.py"
    command = [sys.executable, str(runner)] if runner.exists() else ["sh", str(runner.with_suffix(".sh"))]
    print(f"\n{suite}", flush=True)
    subprocess.run(command, check=True)
