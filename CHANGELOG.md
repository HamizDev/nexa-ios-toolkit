# Changelog

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
