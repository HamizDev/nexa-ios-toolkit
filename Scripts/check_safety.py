#!/usr/bin/env python3
"""Fail CI if Nexa silently loses the first-launch disclaimer or risk notices.

Static tests protect required disclosure wiring. They do not certify actual
device safety, upstream compatibility or legally sufficient wording.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    p = root / path
    if not p.is_file():
        raise AssertionError(f"Missing safety source: {path}")
    return p.read_text(encoding="utf-8")


risk = source("Nexa/Sources/NexaSafety.swift")
app = source("Nexa/Sources/NexaApp.swift")
settings = source("Nexa/Sources/SettingsView.swift")
modules = source("Nexa/Sources/ModuleCatalog.swift")
wq = source("Nexa/Sources/NexaWQExplorerView.swift")
watch = source("NexaWatch/NexaWatchApp.swift")
language = source("Nexa/Sources/NexaLanguage.swift")
project = source("Nexa.xcodeproj/project.pbxproj")

assert "NexaSafety.swift in Sources" in project, "Safety views not compiled in iPhone target"

profiles = re.findall(r'\bid:\s*"(wqfiles|wcmigrate|gestaltx|hermes)"', risk)
assert sorted(profiles) == ["gestaltx", "hermes", "wcmigrate", "wqfiles"], profiles
for section in ("upstreamZh:", "upstreamEn:", "integratedZh:", "integratedEn:",
                "upstreamURL:", "severity:"):
    assert risk.count(section) >= 4, f"Missing bilingual risk data: {section}"

for text in (
    "24C5049d", "manifest.json", "payload",
    "BEFORE uninstalling", "before any high-risk operation",
    "MobileGestalt", "system", "imported"
):
    assert text in risk, f"Missing verified risk message: {text}"

assert "nexa.safety.disclaimer.read.0.0.1" in risk
assert "nexa.safety.disclaimer.read.0.0.1" in app
assert "NexaDisclaimerView(requiresAcknowledgment: true)" in app
assert "showFirstLaunchSafety" in app
assert "NexaDisclaimerView()" in settings, "No permanent settings access"
assert "NexaSafetyCatalog.entry(for: module.id)" in modules, "Missing module risks"
assert "NexaRiskNotice(risk: risk, detailed: true)" in modules
assert 'NexaSafetyCatalog.entry(for: "wqfiles")' in wq
assert "MobileGestalt backup BEFORE uninstalling" in watch
assert "App Groups" in risk
assert language.count('"settings.disclaimer"') == 2

# The simulator UI screenshot harness must bypass a first-use sheet only in
# DEBUG mode. Release builds must not silently skip safety disclosure.
assert "#if DEBUG" in app and "isScreenshotHarness" in app
assert "#else\n                showFirstLaunchSafety = true\n                #endif" in app

print("PASS: 4 pinned upstream risk profiles have zh/en notes")
print("PASS: mandatory first-use disclosure and revisit via Settings")
print("PASS: WQFiles / Watch / module risk notices and Debug-only screenshot bypass")
print("NOTE: static checks cannot validate genuine hardware compatibility or acceptance")
