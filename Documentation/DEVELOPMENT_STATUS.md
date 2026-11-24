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

## 2026-11-24 follow-up — offline plist history

- Added a Nexa-owned Foundation history store for explicitly imported plist copies; original GestaltX parser stays unchanged.
- Snapshots store the previous bytes and record source-relative path, timestamp, reason and size in app-private Application Support. Each restoration preserves the preceding version. No legacy association is inferred: old unlabelled PlistEditBackups remain untouched.
- Reject out-of-root and symbolic-link paths, oversized/invalid dictionary plists, stale edits, mismatched records and truncated snapshots. Snapshots are local history, not cryptographically authenticated archives.
- Added bilingual history UI, confirmation, reload action and error display; added local name search in root and nested file browsers and explicit directory/read errors.
- Linux Swift regression runner compiled and passed on the exact history core and fixture source; iOS SwiftUI and Xcode integration have not been compiled or tested.

## 2026-11-24 follow-up — file library and archives

- Root file browser shows size (regular files only) and modification date, supports sorting and selection across search filters, and requires explicit confirmation before permanent removal of imported copies.
- Original WQFiles ZIP engine remains untouched. Its Swift adapter now accepts selected top-level items, uses a hidden staging path before publishing an archive, validates imported ZIP paths, and stages extraction.
- Added persistent ZIP history with sharing and confirmed deletion of ZIP copies only; unrelated files are excluded.
- Staged imports reject symlinks and unsupported file types before and after copy. Import and extraction staging directories are siblings of Imports, so backups do not enumerate incomplete staging data. Core operations are run away from the main UI thread; Home uses the same filtered file count as the library.
- `Scripts/test-file-library.sh` compiled and passed the exact Foundation fixture on Linux Swift: sorting, metadata, hidden/symlink filtering, full batch preflight, staged import, batch removal and archive isolation.
- Actual Objective-C ZIP calls, SwiftUI compilation and device tests remain pending. The batch removal is not transactional after successful preflight; per-item failures are reported.

## 2026-11-24 follow-up — backup library

- Added local backup directory import via the system folder picker, with security-scoped coordinated reading, hidden staging and a full existing BackupManager SHA-256 verification callback before publication.
- Both v1 and v2 manifests remain readable. Packages must contain exactly manifest.json and Payload; unreadable or structurally invalid local folders are identified and can be deleted with confirmation.
- History shows the manifest timestamp, declared file count, logical file lengths and session verification status. Size totals exclude unreadable packages and are not physical allocated disk usage.
- Added off-main-thread library refresh and confirmed deletion scoped to the backup folder. The source external folder is never modified. Restore remains non-overwriting.
- `Scripts/test-backup-packages.sh` compiled and passed on Linux Swift 6.2.1: package metadata, logical sizes, verification-before-publication boundary, cleanup, v1 compatibility, malformed package rejection and scoped deletion. This fixture tests the verifier callback boundary, not SHA-256 itself.
- Extended the macOS CryptoKit integration fixture with a known SHA-256 answer, valid imported-folder round trip, same-length tamper rejection, failure cleanup and deletion scope. It has not been run here because the Linux Swift toolchain lacks CryptoKit. Unified the restore/delete confirmation dialog to avoid competing presentations.
- CryptoKit, iOS folder picker/sharing, UI and actual device integration remain unverified for that increment.

## 2026-11-24 follow-up — portable ZIP backups

- Added a Foundation transport coordinator and production adapter calling the pinned, unchanged WQFiles ZIP writer/extractor and BackupManager SHA-256 verifier.
- Export verifies the original backup, writes a staged ZIP containing manifest.json and Payload at the root, re-extracts into a fresh staging directory, compares manifest bytes and the complete relative-path/size inventory (including empty directories), verifies hashes again and publishes to Archives only on success.
- Import accepts user-picked folders or .zip files through existing security-scoped coordination. ZIP extraction is staged, rejects skipped entries, checks the package structure and verifies before publishing as a new backup.
- Portable transport is capped at 2 GiB expanded, 2.25 GiB compressed file size, and 65,535 inventory entries; directory import remains available independently. The underlying WQFiles extractor also has its own bounds. Exports are ordinary unencrypted ZIPs.
- Added bilingual ZIP export/share controls; generated archives remain managed by the existing Files → Archives screen.
- Executed `swiftc BackupZipTransport.swift BackupZipTransportRegression.swift` and the resulting runner on Linux Swift 6.2.1 using actual system zip/unzip and controlled fixture verification: round trip, empty dirs, verification ordering, same-size changed data, failure cleanup, limits and symlinks passed. These are not native WQFiles/CryptoKit tests.
- Added `Scripts/test-backup-zip-native.sh` and `Tests/BackupZipNativeRegression.swift` for actual macOS Objective-C + CryptoKit integration; execution is pending. Xcode/iOS UI and document provider behavior remain unverified.

## Remaining acceptance

- [ ] Execute the backup regression fixtures on macOS.
- [ ] Build Nexa with Xcode and the iOS 26 SDK, resolve actual compiler diagnostics.
- [ ] Test ZIP, plist editing, backup/restore, localization and WatchConnectivity on simulator/device.
- [ ] Check low disk space, interrupted operations, Dynamic Type, iPad layout and accessibility.
- [ ] Sign and verify an IPA on an authorized device.
- [ ] Review additional upstream reusable components, license requirements and actual scope. The full WQFiles, WCMigrate, GestaltX and HermesEnabler apps remain independent upstream projects, not fully embedded in Nexa.

No cross-app access, privilege escalation, MobileGestalt writes or watch-face modification is introduced. No device build, signing or IPA generation was performed. A SHA-256 manifest verifies consistency, not authenticity against an adversary able to modify both the manifest and files.
