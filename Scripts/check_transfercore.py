#!/usr/bin/env python3
"""Verify exact WCMigrate source copies; permit only documented narrow delta."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
upstream = root / "ThirdParty/WCMigrate"
package = root / "Packages/NexaTransferCore"
original_guard = '''        let canonical = root.resolvingSymlinksInPath()
        let parent = url.deletingLastPathComponent()
        guard parent == canonical || parent.path.hasPrefix(canonical.path + "/") else { throw TransferError.invalidPath }
        if parent == canonical { return }'''
compat_guard = '''        let canonical = root.resolvingSymlinksInPath().standardizedFileURL
        let parent = url.deletingLastPathComponent().standardizedFileURL
        // Nexa compatibility: Foundation directory URL flags may differ for the same path.
        // Compare canonical path strings without changing the strict descendant boundary.
        guard parent.path == canonical.path || parent.path.hasPrefix(canonical.path + "/") else { throw TransferError.invalidPath }
        if parent.path == canonical.path { return }'''
expected_tests = {
    "DirectMigrationTests.swift", "RecoveryTests.swift", "DataStagingTests.swift",
    "FileOperationTests.swift", "MoveMigrationTests.swift"
}

def compare(relative):
    original = (upstream / relative).read_bytes()
    copied = (package / relative).read_bytes()
    if relative == Path("Core/DirectMigrationService.swift"):
        old = original_guard.encode()
        assert original.count(old) == 1, "Original path guard changed; review compatibility delta"
        original = original.replace(old, compat_guard.encode())
    assert copied == original, f"Unreviewed WCMigrate source change: {relative}"

for subfolder in ("Core", "CSupport"):
    original_paths = {p.relative_to(upstream) for p in (upstream / subfolder).rglob("*") if p.is_file()}
    copied_paths = {p.relative_to(package) for p in (package / subfolder).rglob("*") if p.is_file()}
    assert original_paths == copied_paths, f"Missing or extra WCMigrate source in {subfolder}"
    for relative in sorted(original_paths):
        compare(relative)
for name in sorted(expected_tests):
    compare(Path("Tests") / name)
compare(Path("LICENSE"))
assert ".iOS(.v17)" in (package / "Package.swift").read_text()
assert (package / "Tests/NexaLocalCopyCompatibilityTests.swift").is_file()
print("PASS: WCMigrate core/CSupport and original test bytes match pinned sources, except documented canonical-parent check")
