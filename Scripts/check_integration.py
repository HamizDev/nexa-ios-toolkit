#!/usr/bin/env python3
"""Static integration/provenance checks, not a runtime security audit."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
project = (root / "Nexa.xcodeproj/project.pbxproj").read_text()
required_sources = [
    "NexaBackupRestore.swift",
    "BQCore.m",
    "NexaHermesGate.swift",
    "NexaWeChatIdentityView.swift",
    "WeChatIdentityResolver.swift",
    "NexaDatabaseReportView.swift",
    "NexaWQExplorerView.swift",
    "NexaWatchMonitor.swift",
    "WQAccess.m",
    "WQArchive.m",
    "DatabaseInspector.swift",
    "PlistValueKind.swift",
]
errors = []
for item in required_sources:
    if f"{item} in Sources" not in project:
        errors.append(f"Not linked into Nexa target: {item}")

for item in ["Embed Watch Content", "NexaWatch.app", "watchos", "Nexa/Nexa.entitlements"]:
    if item not in project:
        errors.append(f"Missing watch/signing configuration: {item}")

if project.count("MARKETING_VERSION = 0.0.1;") < 4:
    errors.append("Expected 0.0.1 across iPhone and Watch targets")
if project.count("IPHONEOS_DEPLOYMENT_TARGET = 26.0;") != 4:
    errors.append("Expected iOS 26 deployment setting in 4 project/target configurations")
if project.count("WATCHOS_DEPLOYMENT_TARGET = 26.0;") != 2:
    errors.append("Expected watchOS 26 deployment setting in 2 Watch configurations")

languages = (root / "Nexa/Sources/NexaLanguage.swift").read_text()
parts = languages.split("static let zh: [String: String] = [")
if len(parts) != 2 or "static let en: [String: String] = [" not in parts[1]:
    errors.append("Missing Chinese or English dictionary")
else:
    zh_block, en_block = parts[1].split("static let en: [String: String] = [", 1)
    get_keys = lambda s: set(re.findall(r'^\s*"([^"]+)":\s*"', s, flags=re.MULTILINE))
    zh = get_keys(zh_block)
    en = get_keys(en_block)
    if zh != en:
        errors.append(f"Locale key mismatch: missing en={sorted(zh - en)}, missing zh={sorted(en - zh)}")

pinned = {
    "WQFiles": "fe92ae94067983b94fd927e0b4eee52e5a99a4e7",
    "WCMigrate": "55faba721fd44e04c65be481860c9d93e12f6f61",
    "GestaltX": "311f78999d9f5f062f7e3b4c6374684782be5382",
    "HermesEnabler": "c0ae1666cba67ab7fbae6d3e481cc2731f5550a1",
}
for name, expected in pinned.items():
    path = root / "ThirdParty" / name
    try:
        found = subprocess.check_output(
            ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
        ).strip()
        if found != expected:
            errors.append(f"{name} submodule changed: {found}")
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        errors.append(f"{name} submodule is not checked out: {exc}")

for name in ["WQCore.h", "WQCore.m", "WQArchive.h", "WQArchive.m",
             "WQLocalization.h", "WQLocalization.m"]:
    a = root / "Vendor/WQFiles" / name
    b = root / "ThirdParty/WQFiles" / name
    if not (a.is_file() and b.is_file() and a.read_bytes() == b.read_bytes()):
        errors.append(f"Vendored WQFiles source differs from pinned upstream: {name}")

# Localized Watch resources: both languages must contain the same fixed keys.
localized = []
for locale in ["zh-Hans", "en"]:
    path = root / "NexaWatch/Localization" / (locale + ".lproj/Localizable.strings")
    if path.is_file():
        keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\\s*=', path.read_text(), flags=re.MULTILINE))
        localized.append(keys)
        if len(keys) < 82:
            errors.append(f"Missing Hermes watch translations: {locale}")
    else:
        errors.append(f"Missing Watch strings file: {locale}")
if len(localized) == 2 and localized[0] != localized[1]:
    errors.append("Watch zh-Hans and English translation keys differ")

if errors:
    for error in errors:
        print("FAIL:", error, file=sys.stderr)
    sys.exit(1)
print("PASS: Target membership, version settings, locales, pinned submodules, and vendored WQFiles hashes.")
