#!/usr/bin/env python3
"""Run the real discovery/synchronization services against isolated test doubles."""
from pathlib import Path
import subprocess
import tempfile

directory = Path(__file__).resolve().parent
app = directory.parents[1] / "Tracker"
calendar = (app / "ViewModels/ReleaseCalendarViewModel.swift").read_text()
# Compile the original Foundation-only value types without the SwiftUI view model.
calendar_types = (
    calendar[calendar.index("struct ReleaseCalendarItem:"):calendar.index("@Observable")]
    + calendar[calendar.index("enum DateOnlyFormatter {"):]
)
sources = [
    (app / "Models/MediaType.swift").read_text(),
    (app / "Models/APIModels.swift").read_text(),
    (app / "Models/TMDBModels.swift").read_text(),
    calendar_types,
    (app / "Services/ReleaseDiscoveryService.swift").read_text(),
    (app / "Services/NotificationSyncService.swift").read_text(),
    (directory / "Probe.swift").read_text(),
]
with tempfile.TemporaryDirectory(prefix="tracker-notification-tests-") as build:
    build = Path(build)
    source = build / "Combined.swift"
    source.write_text("\n".join(sources))
    executable = build / "probe"
    subprocess.run([
        "xcrun", "swiftc", "-parse-as-library", "-swift-version", "6",
        "-default-isolation", "MainActor",
        "-module-cache-path", str(build / "ModuleCache"),
        str(source), "-o", str(executable),
    ], check=True)
    subprocess.run([str(executable)], check=True)
