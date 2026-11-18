# Changelog

## Unreleased — upstream integration branch

- Added a source-backed module detail action for each partially integrated upstream tool; corrected readiness labeling so compiled helpers are not presented as fully verified. Improved card contrast and Dynamic Type headers.
- Added optional iOS 26+ Simulator launch-and-screenshot smoke checks for all five main tabs. Screenshots are available as a short-lived CI artifact when a compatible simulator runtime is installed.

- Wired the original WQFiles `wq_copy_to_local` streamed copy and `wq_file_version` change check into a consent-gated, selected-file-only Nexa import action. Added remote path validation, collision-free sanitized names and standalone host path/name tests. Real-device sandbox grant is still unverified.

- Added a private, SHA-256 checked plist version history with a restore/export UI, previous-version preservation and stale-file conflict detection. Applies only to user-imported copies, not system MobileGestalt.

- Added a source-preserving **imported-folder data migration workspace**, including preview, folder enumeration, SHA-256 inventories, staging, no-overwrite destination commit, durable receipts and interrupted-commit recovery. Uses local imported files only; full upstream WeChat container migration remains blocked by real-device authorization and recovery testing.

- Unified iOS local-file, backup, WCMigrate and GestaltX sources with the original HermesEnabler watchOS BQCore engine, panels and 82 bilingual keys in a single Xcode project, to validate joint simulator builds. Physical watch system writes remain unverified.

- CI now verifies the real `Nexa.app/Watch/NexaWatch.app` embedding and uploads a seven-day **unsigned iOS Simulator preview ZIP** for UI acceptance testing. This is not a device IPA.

- Added a bounded destination-folder picker for moving files within Nexa Imports, plus a recursive symlink check before accepting security-scoped file provider imports. Included positive and negative fixture tests.

- Added usable Nexa-imported file operations: create folder, search, rename, duplicate, and recoverable trash with an optional permanent-delete confirmation. Rejects name collisions, symlink trees, unsafe names, and moves into descendant directories; includes disposable host regression tests.

- Compiled original GestaltX `GXMobileGestaltImage.m/h` read-only loaded-library inspector into Nexa's device information page. Displays only section counts/sizes, with no MobileGestalt cache writes.

- Compiled WCMigrate's original `WeChatIdentityResolver.swift` and added an on-demand identity inspector to the imported-folder UI. Bounds checking, local-only operation and synthetic parser tests protect the flow; this is **not** full WeChat data migration.

- Added a recoverable, verified **Nexa-local restore workflow**: backup SHA-256 preflight, independent staged verification, retained previous-import snapshot, confirmation UI, and disk journal for interrupted swaps. This does not read/write other apps' data.

- Linked the unmodified WQFiles WQAccess/WQLaunchServices/WQScanTask backend from the pinned submodule into Nexa, with an entitlement placeholder and consent-gated, read-only container browser. **Real-device capability is not verified**, and cross-app writes remain disabled.

- Added a true embedded `NexaWatch` watchOS app target with SwiftUI bilingual UI and two-way WatchConnectivity ping diagnostics; not the upstream Hermes face engine.

- Adapted WCMigrate's original read-only SQLite database inspector for Nexa's SHA-256 verified local backup manifests. The scanner checks disposable database copies and does not imply chat recovery.

- Compiled the original WQFiles ZIP archive engine and its localization helpers with zlib; added archive creation and safe extraction for imported files.

- Added offline user-imported plist inspection and editing using GestaltX's original value parser; each local edit creates an app-private backup of the imported copy.

- Added pinned Git submodules for WQFiles, WCMigrate, GestaltX and HermesEnabler, with a single development workspace (independent upstream targets remain separate).
- Wired WCMigrate’s original backup progress/ETA components into Nexa’s local backup UI.
- Wired GestaltX’s upstream VersionSupport helper into the read-only device diagnostics UI.
- Added real WatchConnectivity session status monitoring on iPhone. No watchOS target or watch face enabling is included.
- Added provenance and license references for newly integrated source files and clarified build blockers for a true single-app merge.

**Not completed:** cross-app WQFiles engine, full WeChat data migration, MobileGestalt writes/rollback, and HermesEnabler watchOS integration. This branch needs Xcode compilation verification before it should be merged/released.

## [0.0.1] — 2026-11-17 (source preview)

- Redesigned the main SwiftUI interface with a dark, layered, gradient visual language.
- Added persistent language switching: Simplified Chinese by default and English.
- Improved local file browsing (user-imported content), folder navigation, text and hex preview.
- Vendored upstream WQFiles `WQCore.m/h` under GPL-3.0-or-later, and wired `WQParseHexExactly` into the hex validation UI.
- Kept user-controlled SHA-256 manifest backups and integrity verification.
- Improved read-only device information, reported OS compatibility and watch pairing views.
- Added explicit module integration statuses, source attribution, and pinned upstream revision inventory.
- Set marketing version to `0.0.1`, build number to `1`, deployment minimum to iOS 26.0.

**Not included:** worse_query exploit engine, other-app container access, full WQFiles, WCMigrate cross-app migration, MobileGestalt writes, watchOS target, Hermès face enabling, a signed IPA, or verified Xcode build.
