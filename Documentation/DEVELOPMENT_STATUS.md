# Nexa 0.0.1 development status — 2026-11-24

Baseline: `4c3d03ea5e8b95c3c7b54cdf4451fa8b06d8c871` on main.

## This increment

- Implemented source-level verified restoration of Nexa's own local backups to a fresh folder; no existing import is overwritten.
- New backup manifests are format 2 and record both files and directories; legacy format 1 still verifies files but has no authenticated directory inventory.
- Duplicate manifest paths, unsupported versions, symlinks, missing payloads and enumeration errors fail rather than crash or pass as empty.
- Copy staging is removed on normal errors, and incomplete backups are hidden from the backup list.
- Kept the upstream WCMigrate progress/ETA source unchanged; this is Nexa's local backup format, not WCMigrate chat-transfer integration.
- Corrected stale module labels and workspace status. The in-app disclaimer remains under Settings.
- Added `Scripts/test-backups.sh` and fixture source. Run with macOS Xcode command-line tools; the tests have not been executed in this increment.

## Remaining acceptance

- [ ] Execute the backup regression fixtures on macOS.
- [ ] Build Nexa with Xcode and the iOS 26 SDK, resolve actual compiler diagnostics.
- [ ] Test ZIP, plist editing, backup/restore, localization and WatchConnectivity on simulator/device.
- [ ] Check low disk space, interrupted operations, Dynamic Type, iPad layout and accessibility.
- [ ] Sign and verify an IPA on an authorized device.
- [ ] Review additional upstream reusable components, license requirements and actual scope. The full WQFiles, WCMigrate, GestaltX and HermesEnabler apps remain independent upstream projects, not fully embedded in Nexa.

No cross-app access, privilege escalation, MobileGestalt writes or watch-face modification is introduced. No device build, signing or IPA generation was performed. A SHA-256 manifest verifies consistency, not authenticity against an adversary able to modify both the manifest and files.
