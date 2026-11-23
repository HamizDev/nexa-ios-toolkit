# Changelog

## Unreleased — upstream integration branch

- Extended developer handoff with unsigned iPhone and Watch Release/device-SDK CI builds, separate from Simulator Debug builds. These are compile-only; a signed, provisioned device IPA is still required for release.
- Signed IPA script now reads the actual iPhone/Watch code-signature entitlements in both Xcode archive and exported IPA and rejects mismatched Team IDs, Bundle IDs, companion mapping and App Groups. Added synthetic host regression cases that do not require signing credentials.


- Reject symlinked Nexa backup roots for listing, creation and verification; incomplete backup staging is cleaned only for UUID-shaped folders and never follows linked aliases. Added disposable host adversarial fixtures.
- Verify original imported data against the completed backup manifest before publishing a snapshot, so concurrent source-file changes abort and clean the backup rather than silently preserving stale/inconsistent data.


- Added best-effort, lock-serialized cleanup of interrupted portable-backup ZIP imports. Only UUID-named workspaces and hidden `.incoming-<UUID>` backups are removed, while symlinks and unrelated paths are skipped. Regressions cover orphan cleanup and preserved user data.


- Extended newly created backup manifests to version 2: SHA-256 files plus an exact inventory of all folders, including empty ones. Verification rejects missing/extra folders, while valid existing version-1 backups remain readable. Added compatibility and malicious tampering host fixtures.


- Added persistent recovery-copy browsing in Backups: raw pre-restore data and crash-rejected payloads can be found after app restart and individually exported as ZIP with the pinned WQFiles writer. Labels explicitly state that raw snapshots do not have an authenticated backup manifest.
- Recovery exports reject out-of-scope directories, symlinks at the recovery root or anywhere inside it, and partial ZIPs; added host regressions for discovery, aliases, and malicious nested links.
- Latest prior CI run 45012726433 passed host/WQFiles, iPhone, Watch and five distinct-tab UI screenshots. Manual screenshot review confirmed nonduplicated pages.


- Fixed CI false-negative risk from slow macOS iOS Simulator first boot: dedicated 16-minute CoreSimulator warmup, separate seven-minute five-tab assertion/screenshot step; missing iOS 26+ runtime is a CI failure, not a silent pass.
- Make Nexa-local backup publication transactional: copy and verify under a hidden `.creating-<UUID>` directory, then atomically rename into the visible backup list. Failed copies remove private staging and cannot masquerade as finished backups. Added a host fixture that forces a copy failure mid-operation.


- Added non-destructive portable Nexa backup ZIP import through the iOS Files picker. The original WQFiles archive engine extracts into private staging, skips are rejected, and the SHA-256 manifest must pass before the backup becomes visible. The current imported data is not restored or overwritten.
- Backup import publishes only completed, verified snapshots: hidden .incoming-* directories are omitted from lists. Regression checks verify hidden staging and visible final backups.

- Added a portable, verified backup ZIP flow (Backup > Prepare ZIP > Share), using WQFiles' original archive engine and exporting both manifest.json and Payload; unsafe or changed backups fail closed.
- Hardened backup verification: direct-child sandbox boundaries, symlink rejection for payload/manifest, unexpected backup items and missing payloads are rejected. Added host coverage for tampered backup layouts.
- Interrupted restore rollback now retains the rejected staged payload in private RestoreStaging/rejected-<transaction> instead of deleting it; added crash-recovery regression.

- Added user-selected imported-folder ZIP creation using the original WQFiles archive writer, with recursive symlink checks and one-tap ZIP sharing from the nested folder UI.
- Added a lock-safe, best-effort cleanup of abandoned import staging directories on Files entry. It only removes UUID-shaped work folders, skips linked directories, and preserves the original selected data; host regression fixtures cover orphan and alias handling.

- Staged user-selected file/folder imports off the main thread with an atomic commit into Nexa Imports, randomized collision-resistant names, source preservation, progress feedback, and symlink rejection. Added host fixtures for successful, repeated, nested and unsafe imports.
- Routed WQFiles ZIP extraction through the same imported-file path/symlink policy and added a direct navigation action to the extracted folder; unified nested-folder search styling with the rest of Nexa.

- Replaced low-contrast system rounded search boxes with a reusable, accessible Nexa dark search field in Files and the imported plist editor; added localized clear actions and reduce-transparency support.

- Fixed imported snapshot Merge's ancestor file/directory conflict validation: check every path component, not only lexically adjacent filenames. Added a synthetic regression for intervening filename ordering and safe Replace behavior.

- Added a visible, source-preserving Nexa-imported **file-level Merge/Replace** workflow: preview overlaps/bytes, select source-vs-target filename precedence, stage and SHA-256 verify a *new* output directory, retain originals, journal results and validate interrupted commits. Covers only imported snapshots and is not WCMigrate's live cross-app engine.

- Added a bilingual, first-launch user-read disclaimer (with consent acknowledgment but no legal-rights waiver), a permanent Settings disclosure page, precise pinned-upstream risk notes in module details, WQFiles explorer caution and original Hermes Watch backup/uninstall warnings. Added CI static checks against accidentally removing risk notices.
- Corrected upstream WCMigrate scope: the pinned README explicitly says its file-level merge is not a SQLite chat-record merge and no whole-task rollback is provided; Keychain/login state is not transferred.

- Audited the previous five-tab iOS Simulator screenshots and found all five actually displayed the Home tab. Fixed missing DEBUG compilation condition in the iOS target and added a DEBUG-only on-device tab-selection acknowledgement. Screenshot CI now verifies the actual selected tab and fails when the test silently captures Home repeatedly.

- Fixed Swift 6 migration-path warnings from the WQFiles browser by converting Objective-C errors and results to immutable Swift values before main-actor callbacks; removed redundant GestaltX downcast.
- Hardened the local-migration crash recovery ledger: validate exact generated destination names, journal path components and file SHA-256 metadata; ignore symlinked journal files, reject symlinked outputs, and mark missing/tampered records failed rather than aborting startup. Added disposable host attack/regression fixtures.

- Added an owner-run macOS Xcode archive and debugging IPA export script that validates a signed iPhone + embedded Watch bundle. All identifiers must be explicitly provisioned; no signing certificates or secrets are stored in the repo.

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

**Not completed:** full cross-app WQFiles operations, WCMigrate live WeChat migration, MobileGestalt system writes and rollback, and HermesEnabler **physical Watch face/restore verification**. iPhone/Watch Simulator and host regression CI are available; real-device signing and high-risk operations are still release blockers.

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
