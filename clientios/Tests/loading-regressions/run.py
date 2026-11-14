#!/usr/bin/env python3
"""Compile the production view models with a deterministic, suspended fake API."""

from pathlib import Path
import subprocess
import tempfile

directory = Path(__file__).resolve().parent
clientios = directory.parents[1]
sources = [
    directory / "Probe.swift",
    clientios / "Tracker/Models/ShowtimesModels.swift",
    clientios / "Tracker/ViewModels/ShowtimesViewModel.swift",
    clientios / "Tracker/ViewModels/LogsViewModel.swift",
]

with tempfile.TemporaryDirectory(prefix="tracker-loading-regressions-", dir="/tmp") as temporary:
    temporary = Path(temporary)
    source = temporary / "LoadingRegressions.swift"
    source.write_text("\n".join(path.read_text() for path in sources))
    binary = temporary / "loading-regressions"
    subprocess.run([
        "swiftc", "-swift-version", "6", "-parse-as-library",
        "-module-cache-path", str(temporary / "module-cache"),
        str(source), "-o", str(binary),
    ], check=True)
    subprocess.run([str(binary)], check=True)
