# Nexa integration plan

**Release target:** 0.0.1 source preview. **Minimum deployment:** iOS / iPadOS 26.0.

## 0.0.1 accepted scope

- [x] New high-contrast midnight SwiftUI design with reusable components
- [x] Language preference: default Simplified Chinese, switch to English, persistent across launches
- [x] User-authorized file imports, file/folder browser and sharing
- [x] Text and hex file preview, with WQFiles' upstream `WQCore.m/h` hex validation compiled in
- [x] Local backup manifests with SHA-256 verification
- [x] Source implementation: staged local backup and verified non-overwriting restore (v1/v2 manifests; v2 covers empty directories)
- [x] Source implementation: WQFiles original ZIP writer/extractor, GestaltX imported-plist parser, WCMigrate progress/ETA and WatchConnectivity diagnostics
- [x] Regression fixture source for backup integrity and restoration (execution pending on macOS)
- [x] Offline plist history and byte-exact restoration core; Foundation regression runner passed on Linux Swift
- [ ] Verify plist history UI, XML/binary editing and restore on simulator/device
- [x] Read-only device summary, build number / capacity and conservative upstream compatibility notice
- [x] Source credits and accurate module readiness states
- [ ] Xcode and device compilation acceptance
- [ ] Signed IPA and release artifacts

## Modules not yet integrated

- WQFiles full filesystem authorization / app-data browser, cache maintenance
- GestaltX, Erosion, Regitela, WorstGestalt MobileGestalt write and rollback engines
- WCMigrate cross-app transfer, account resolution, staging and transfer journals
- WQToolkit advanced own-container maintenance features (license to review)
- HermesEnabler independent watchOS target and companion communication
- worse_query sandbox extension engine and its matching App Group signing configuration

No unverified module should be represented as available to end users. Prefer read-only diagnostics and source-backed validation before writing system files.

## Upstream compatibility reports (not tested by Nexa)

- Worse_query original README lists iOS 26.0–26.7.2 and iOS 27.2.
- WQFiles reports successful tests across portions of iOS 26/27, including iOS 27.2.1 and iOS 27.3 Beta 1.
- Erosion reports iOS 26 partial support and iOS 27.0–27.2.1 / 27.3 Beta 1, with no MobileGestalt writes on iOS 26.
- WQFiles and Erosion report the flaw patched in iOS 27.3 Beta 2 (24C5049d). Later OS compatibility must be revalidated.
- Apple skipped formal iOS 19–25 branding, naming the version after iOS 18 as iOS 26.

## Rules for future integration

1. Pin each upstream commit and review code license and target settings.
2. Compile imported source, wire a real feature, and provide a regression test before describing a module as integrated.
3. Keep user-selected data separate from privileged container access, and never infer access rights from a version string alone.
4. File operations must validate sources and targets and reject unsafe symlinks; make an original backup before mutations.
5. Keep personal chat records and app data local, and avoid processing other users' data.
6. System mutations require build-specific safeguards, explicit consent, backups, verification, and documented recovery.
7. A watchOS implementation needs its own signed target and device tests; an iOS screen alone cannot unlock watch faces.

## Acceptance requirements

- [ ] Build with current Xcode and iOS 26 SDK for a simulator and device
- [ ] Verify zh default and in-app en switching on fresh install
- [ ] Verify file import, folder navigation, hex validation and share sheet
- [ ] Run `Scripts/test-backups.sh` on macOS; verify backup consistency, legacy manifests, hash tampering, duplicate entries, missing directories, missing payloads, symlinks, non-overwriting restoration and space exhaustion handling
- [ ] Inspect Objective-C bridging headers and GPL source attribution
- [ ] Review accessibility contrast, Dynamic Type and iPad layouts
- [ ] Verify all nonintegrated tools remain inactive and clearly labeled
- [ ] Record actual model / iOS build and failure logs

Source details: [UPSTREAM_SOURCES.md](UPSTREAM_SOURCES.md).

## File library follow-up

- [x] Root file sorting and multi-selection, confirmed batch deletion, archive listing and selected ZIP creation wired at source level.
- [x] Foundation file-library regression runner passed on Linux Swift.
- [ ] Test real upstream ZIP writing/extraction and selected-item archive contents on iOS; test UI selection, filtering and deletion confirmation.
- [ ] Test large imports, low space, app interruptions and concurrent operations.

## Backup library follow-up

- [x] Source-level verified Nexa backup-folder import, staged publication, history metadata, logical-byte summary and confirmed deletion.
- [x] Foundation backup-package regression runner passed on Linux Swift (verification-boundary fixture; no CryptoKit claims).
- [ ] Run the macOS CryptoKit integration fixtures, including valid and tampered imported backups; test folder picking/sharing with local and iCloud providers.
- [x] Source-level ZIP backup transport via original WQFiles engine; root manifest.json + Payload, round-trip export verification, staged import, 2 GiB expanded limit.
- [x] Linux Swift transport regression with real system ZIP tools and fixture verifier passed.
- [ ] Run `Scripts/test-backup-zip-native.sh` on macOS for the actual Objective-C and CryptoKit bridge; test ZIP picking, sharing and archive history on iOS.

## 2026-11-28 diagnostic and safety follow-up

- [x] Source-level WatchConnectivity session lifecycle, activation gating, reachability, error and retry UI.
- [x] Bilingual risk classifications, searchable/filterable module catalog and dedicated safety/disclaimer page.
- [x] Foundation capability-status regression executed on Linux Swift 6.2.1.
- [ ] Verify actual WatchConnectivity session lifecycle (unsupported hardware, pairing changes, app installation, background/foreground and failure/retry) on iPhone and paired Watch; no native Nexa watchOS target exists yet.
- [ ] Review accessibility, source provenance and UI status accuracy during full Xcode build acceptance.
