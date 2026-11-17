# Changelog

## Unreleased — upstream integration branch

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
