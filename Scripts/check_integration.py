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
    "NexaLocalFiles.swift",
    "NexaImportMigration.swift",
    "NexaMigrationView.swift",
    "NexaWCMigratePreview.swift",
    "NexaPlistHistory.swift",
    "NexaPlistHistoryView.swift",
    "NexaWQImportName.swift",
    "NexaWQFileExport.swift",
    "NexaSafety.swift",
    "NexaImportCombine.swift",
    "NexaImportCombineView.swift",
    "BQCore.m",
    "NexaHermesGate.swift",
    "NexaFileOperationsUI.swift",
    "NexaWeChatIdentityView.swift",
    "WeChatIdentityResolver.swift",
    "NexaDatabaseReportView.swift",
    "NexaWQExplorerView.swift",
    "NexaWatchMonitor.swift",
    "NexaWQAppCatalogView.swift",
    "WQAccess.m",
    "WQHexViewer.m",
    "WQPlistEditor.m",
    "WQSQLiteViewer.m",
    "WQSQLiteSave.m",
    "WQSharing.m",
    "WQUI.m",
    "WQTheme.m",
    "NexaWQHexReadOnly.swift",
    "WQArchive.m",
    "DatabaseInspector.swift",
    "PlistValueKind.swift",
    "GXMobileGestaltImage.m",
]
errors = []
preview = (root / "Nexa/Sources/NexaWCMigratePreview.swift").read_text()
for fragment in ("import TransferCore", "TransferCore.DirectMigrationService(",
                 "service.preview(", "keepSource: true",
                 "NexaLocalFiles.validatedArchiveFolder(", "NexaWCMigratePreviewView"):
    if fragment not in preview:
        errors.append("Original WCMigrate local preview missing: " + fragment)
for fragment in ("XCLocalSwiftPackageReference", "relativePath = Packages/NexaTransferCore;",
                 "productName = TransferCore;", "TransferCore in Frameworks"):
    if fragment not in project:
        errors.append("Original pinned TransferCore package dependency missing: " + fragment)
for fragment in ("XCTContainerBridge", ".migrate(", ".resume(", "wq_grant("):
    if fragment in preview:
        errors.append("Read-only imported WCMigrate preview contains disallowed action: " + fragment)
catalog = (root / "Nexa/Sources/NexaWQAppCatalogView.swift").read_text()
explorer = (root / "Nexa/Sources/NexaWQExplorerView.swift").read_text()
file_view = (root / "Nexa/Sources/FilesView.swift").read_text()
for original_api in ("wq_load_display_names()", "wq_ls_container_paths(nil)",
                     "wq_bundle_id_for_container(", "wq_display_name(",
                     "WQAppsSupportBundleIDValid("):
    if original_api not in catalog:
        errors.append("WQApps catalog not using original upstream API: " + original_api)
for gate in ("NexaContainerAccess.ready", "agreed", "NexaContainerAccess.valid(",
             "NexaWQExplorerView(initialPath:"):
    if gate not in catalog:
        errors.append("WQApps catalog read-only or consent gate missing: " + gate)
for forbidden in ("wq_write(", "wq_delete(", "wq_purge_contents(", "wq_make_app_backup("):
    if forbidden in catalog:
        errors.append("Read-only WQApps catalog contains mutation API " + forbidden)
if "init(initialPath: String" not in explorer or "private var agreed = false" not in explorer:
    errors.append("WQApps catalog must never carry consent into the remote explorer")
if "NexaWQAppCatalogView()" not in file_view:
    errors.append("WQApps app catalog not reachable from Nexa's file workspace")
if '#import "WQAppsSupport.h"' not in (root / "Nexa/Nexa-Bridging-Header.h").read_text():
    errors.append("Original WQApps support validation missing from bridging header")
if '#import "WQHexViewer.h"' not in (root / "Nexa/Nexa-Bridging-Header.h").read_text():
    errors.append("Original WQFiles hex controller is not exposed in the Swift bridge")
if '#import "WQPlistEditor.h"' not in (root / "Nexa/Nexa-Bridging-Header.h").read_text():
    errors.append("Original WQFiles plist controller is not exposed in the Swift bridge")
if '#import "WQSQLiteViewer.h"' not in (root / "Nexa/Nexa-Bridging-Header.h").read_text():
    errors.append("Original WQFiles SQLite browser is not exposed in the Swift bridge")
wq_hex_adapter = (root / "Nexa/Sources/NexaWQHexReadOnly.swift").read_text()
if "WQHexViewController(path: file.path, readOnly: true)" not in wq_hex_adapter:
    errors.append("WQFiles original hex controller must be instantiated read-only")
if "WQPlistEditorViewController(path: file.path, readOnly: true)" not in wq_hex_adapter:
    errors.append("WQFiles original plist controller must be instantiated read-only")
if "WQSQLiteViewController(path: file.path, readOnly: true)" not in wq_hex_adapter:
    errors.append("WQFiles original SQLite controller must be instantiated read-only")
for item in ("WQHexViewer.m", "WQPlistEditor.m", "WQSQLiteViewer.m", "WQSQLiteSave.m", "WQSharing.m", "WQUI.m", "WQTheme.m"):
    if f"ThirdParty/WQFiles/{item}" not in project:
        errors.append("Original WQFiles UI dependency must come from the pinned submodule: " + item)
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
        keys = set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', path.read_text(), flags=re.MULTILINE))
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
