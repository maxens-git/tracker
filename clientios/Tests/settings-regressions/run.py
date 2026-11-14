#!/usr/bin/env python3
"""Exercise the production settings load state without compiling SwiftUI."""

from pathlib import Path
import subprocess
import tempfile

directory = Path(__file__).resolve().parent
view = (directory.parents[1] / "Tracker/Views/Settings/SettingsView.swift").read_text()
state = view[view.index("private struct SettingsLoadState {"):view.index("private extension String {")]

with tempfile.TemporaryDirectory(prefix="tracker-settings-regressions-", dir="/tmp") as temporary:
    temporary = Path(temporary)
    source = temporary / "SettingsRegressions.swift"
    source.write_text("import Foundation\n" + state + (directory / "Probe.swift").read_text())
    binary = temporary / "settings-regressions"
    subprocess.run([
        "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
        "-module-cache-path", str(temporary / "module-cache"),
        str(source), "-o", str(binary),
    ], check=True)
    subprocess.run([str(binary)], check=True)
