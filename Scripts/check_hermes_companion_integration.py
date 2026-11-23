#!/usr/bin/env python3
"""Guard the pinned Hermes iPhone receiver and single-delegate wiring."""
from pathlib import Path

base = Path(__file__).resolve().parent.parent
project = (base / "Nexa.xcodeproj/project.pbxproj").read_text()
app = (base / "Nexa/Sources/NexaApp.swift").read_text()
adapter = (base / "Nexa/Sources/NexaWatchMonitor.swift").read_text()
ui = (base / "Nexa/Sources/WatchView.swift").read_text()
upstream = base / "ThirdParty/HermesEnabler/HermesCompanion/WatchConnectivity/WatchConnectivityManager.swift"

checks = {
    "pinned HermesCompanion original source exists": upstream.is_file(),
    "original iPhone source is compiled directly from the submodule":
        "ThirdParty/HermesEnabler/HermesCompanion/WatchConnectivity/WatchConnectivityManager.swift" in project
        and "HermesCompanionWatchConnectivity.swift in Sources" in project,
    "original receiver has app-lifetime StateObject":
        "@StateObject private var hermesCompanion = WatchConnectivityManager()" in app
        and ".environmentObject(hermesCompanion)" in app,
    "no second iPhone WCSession delegate":
        "class NexaWatchMonitor" not in adapter and
        "WCSession.default.delegate =" not in adapter and
        ": WCSessionDelegate" not in adapter,
    "original backup history called from UI": "companion.backups" in ui,
    "original backup verifier called from UI": "companion.verifyBackup(" in ui,
    "original plist importer called from UI": "companion.importBackup(" in ui,
    "original backup exporter called from UI": "companion.exportURL(" in ui,
    "original Watch transfer called from UI": "companion.transferBackupToWatch(" in ui,
    "Nexa dashboard Ping adapter": "didReceiveMessage message:" in adapter
        and "nexa.pong" in adapter,
}
if upstream.is_file():
    code = upstream.read_text()
    for fragment in ("didReceive file: WCSessionFile", "didReceiveApplicationContext",
                     "func transferBackupToWatch(", "func importBackup(", "func verifyBackup("):
        checks["original Hermes backend: " + fragment] = fragment in code

for name, success in checks.items():
    print(("PASS" if success else "FAIL") + ": " + name)
if not all(checks.values()):
    raise SystemExit("Original Hermes phone companion integration is incomplete.")
