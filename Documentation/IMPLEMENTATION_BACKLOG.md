# Nexa 0.0.1 — upstream implementation backlog

**Branch:** feature/nexa-0.0.1-unified · Draft PR #3  
**Last updated:** 2026-11-24. Update after each feature milestone.

**Progress types:** PINNED upstream source, WIRED callable Nexa workflow, CI pass at current head, DEVICE signed hardware acceptance. These are separate milestones. A compiled source does not prove a privileged function is safe or usable.

## P0 — HermesEnabler 2 (active)

Original source: pookjw/HermesEnabler at c0ae1666cba67ab7fbae6d3e481cc2731f5550a1 (MIT).

- [x] PINNED original Watch BQCore, feature views, MGDefaults and MGOffsets.
- [x] WIRED original Watch core/UI in the NexaWatch target; watchOS/App Group/consent gates.
- [x] WIRED original iPhone HermesCompanion/WatchConnectivity/WatchConnectivityManager.swift directly from pinned submodule. It owns file receiving, SHA-256 backup manifest/history, backup import/export and sending to Watch.
- [x] One original app-scoped iPhone WCSession delegate, with thin Nexa Ping response extension; iPhone Watch screen calls original backup manager API.
- [x] CI: original Hermes companion source wiring passed all four jobs in run 45175725443 (iPhone/Watch Simulator, unsigned device SDK, source and original recovery fixtures).
- [x] CI: original Hermes Debug-only synthetic MG plist import, SHA-256 integrity, exact export bytes, duplicate rejection, malformed import rejection, history reload and **Nexa iPhone Watch-companion screenshot** all passed at [run 45178352719](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45178352719), code SHA `1120de7`.
- [ ] DEVICE: original Watch backup reaches iPhone even if Watch screen is closed and persists across phone relaunch with matching SHA-256.
- [x] WIRED Watch-side single-delegate routing: the original Hermes manager remains WCSession delegate on both dashboard and original tools; Nexa Watch link sends Ping/refresh without replacing the delegate.
- [ ] DEVICE: opening and closing original Hermes Watch tools does not lose WCSession file transfer, status events or Nexa Ping.
- [ ] DEVICE: iPhone sends an original-hash-verified backup as a queued candidate; Watch rejects malformed/mismatched ones; Watch import requires confirmation.
- [ ] DEVICE: verify restoration of original MobileGestalt snapshot on disposable paired hardware before considering any system write accepted.
- [ ] UI: finish original runtime translations and full VoiceOver/Dynamic Type/Watch small-screen review.

**Blocker:** signed iPhone/Watch, supported actual watchOS build, paid Apple Developer Team and provisioned App Groups.

## P1 — WQFiles

Original source: kolbicz/WQFiles at fe92ae94067983b94fd927e0b4eee52e5a99a4e7 (GPL-3.0-or-later).

- [x] WIRED original WQCore, WQArchive, selected-file wq_copy_to_local and gated read-only WQAccess preview; **physical container grant unverified**.
- [x] WIRED + CI [45223067042](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45223067042): original WQHexViewer.m, WQPlistEditor.m and WQSQLiteViewer.m plus WQUI/WQTheme/WQSQLiteSave/WQSharing dependencies compile unchanged from pinned source. All three Nexa wrappers force readOnly=true and only accept imported regular files. Original header/offset, plist type and SQLite support fixtures pass. This is **local file viewing only**.
- [x] SOURCE-WIRED (current-head CI pending): user-consented, OS/build/App Group-gated **read-only App catalog** uses the original `WQLaunchServices` APIs (`wq_load_display_names`, `wq_ls_container_paths`, `wq_bundle_id_for_container`, `wq_display_name`) and original header-only `WQAppsSupportBundleIDValid` validation. This is a metadata listing, **not** the original full `WQAppsViewController`. Selected containers open the separately consent-gated WQAccess explorer; no automatic full inode scan or file mutations.
- [ ] Reuse the remaining safe WQApps manager workflows/backup metadata only after the upstream app-control semantics can be strictly restricted. The original `WQApps.m` UIKit controller exposes destructive backup/restore/clear actions and lacks a global readOnly constructor, so it is deliberately **not** exposed by this milestone.
- [ ] DEVICE: owner-approved app catalog lists expected LaunchServices apps and opening any selected container requires fresh consent; missing grants and patched builds must refuse without writes.
- [x] CI + manual screenshot review at code SHA 866fc23d / run 45223067042: original Hex viewer displays 00..FF byte/ASCII columns, original plist viewer displays synthetic Count/Flags/Sample with read-only note, and original SQLite viewer shows imported_notes table with one row and explicit read-only snapshot notice. Nine distinct screenshots captured; no physical-device validation.
- [x] CI 45230325746: targeted original WQAppsSupportTests / WQLaunchServicesTests and both Simulator/unsigned device SDK compilation passed for the App catalog.
- [x] Full original WQFiles host suite passed unchanged in [45298981054](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45298981054), dedicated Intel runner reported four active CPUs; the previously timed-out checkpoint test and all requested host regressions passed (standalone upstream iOS link check explicitly excluded, Nexa SDK checks separate).
- [ ] Gated App catalog simulator screenshot: prior run hit the shared seven-minute UI deadline after seven screenshots. Split installation/warmup, five tabs, Hermes, original viewers, catalog and original WCMigrate preview into separate steps, deleting stale test markers before each launch. Await the new run.
- [ ] Consider original WQTrash/WQCache or write methods only with explicit scope, verified original backup, predictable restore, safe supported OS/build and actual authorized test-container device tests.
- [ ] DEVICE: verify entitlement/grant/cache recovery, sandbox refusals and patched-build disabling on test-owned data.

## P2 — WCMigrate

Original source: yangokok886/WCMigrate at 55faba721fd44e04c65be481860c9d93e12f6f61 (GPL-3.0-or-later).

- [x] Original progress/ETA, SQLite read-only checker, imported WeChat identity parser; Nexa-owned local copy and Merge/Replace are **not** cross-app WCMigrate.
- [x] SOURCE-WIRED (current CI pending): original TransferCore preview for two distinct imported folders. Direct use of upstream macOS-only Package.swift failed both iPhone builds in run 45298981054. Now use Packages/NexaTransferCore with explicit upstream app iOS 17 deployment, original Core/CSupport/test bytes and GPL license, audited by Scripts/check_transfercore.py. Only documented source delta is canonical parent path comparison in createParents; no migration execution or resume is exposed to the UI.
- [x] Baseline original host results (run 45298981054): DirectMigrationTests 12/12, FileOperationTests 17/17 and MoveMigrationTests 8/8 passed.
- [ ] Original DataStagingTests failed four cases with invalidPath (17/21 passed); the compatibility package uses the original createParents implementation with a narrowly scoped path-string equality correction. Verify it against the unchanged original fixtures and the new Nexa isolated-copy fixture before using staging.
- [ ] Original Debug RecoveryTests crashed with signal 10 at testDeepTreeStopsWithDiagnosticInsteadOfUnboundedRecursion. Keep this required case in its own CI step so it cannot prevent other recovery tests from running. Root cause remains unconfirmed. Until verified, the Nexa preview refuses imported trees beyond 32 levels; this is a conservative wrapper limit, not an upstream fix.
- [ ] Verify all original migration/staging/recovery fixtures against the compatibility package, plus the new NexaLocalCopyCompatibilityTests (original Replace/Merge on independent temporary copies; original data and receipt history checked). No fixture disabled.
- [ ] Verify the new Debug-only Simulator fixture (actual TransferCore preview of synthetic local imports; checks file counts/bytes, both modes, unchanged originals and same-root/outside-import/symlink rejection) and preview screenshot.
- [ ] Remaining original WCMigrate staging, migration execution and resume UI are not wired. Any future local execution must use isolated copies, explicit scope and tested recovery; the full live app-to-app workflow is not available.
- [ ] DEVICE: verify user-authorized source/target access, original file-level Replace/Convert/Merge and checkpoint recovery.
- [ ] Upstream does not implement SQLite chat-record row merging, Keychain/login transfer or whole-task rollback; do not invent these as upstream-stable features.

## P3 — GestaltX

Original source: GestaltX at 311f78999d9f5f062f7e3b4c6374684782be5382 (GPL-3.0-only).

- [x] Version helper, typed plist parser and original read-only GXMobileGestaltImage; Nexa-owned offline edit/history.
- [ ] Reuse original GestaltDocument/GestaltFileStore, GestaltManager, Capabilities, DeviceCacheOptions, MobileGestaltCacheLayout and cache-access support.
- [ ] Test original device-cache layout detection, baseline backup, staged diff/commit and recovery using synthetic/offline fixtures.
- [ ] DEVICE: verify exact supported build and real recovery from original baseline on disposable hardware; no guessed cache offsets or unsupported system writes.

## Shared release gates

- [x] First-launch bilingual disclaimer, module-specific warnings, source/license inventory and Nexa-local SHA-256 backup/restore.
- [x] Earlier baseline CI run 45155034638 passes provenance, Watch, iPhone and unsigned device Release builds.
- [x] Feature-code SHA 866fc23d / CI 45223067042 passed all four jobs: host+upstream regression, iPhone/Watch Simulator builds, unsigned iPhone/Watch device Release builds, and nine-page UI smoke. This documents that code commit; subsequent documentation commits have independent workflow runs.
- [ ] Manual Chinese/English, Dynamic Type, VoiceOver, iPad and watchOS confirmation/error dialogs.
- [ ] Signed device IPA with verified original iPhone/Watch App Group entitlements and real paired-device logs (no secrets).
- [ ] Release 0.0.1 only for the clearly accepted scope. Keep incomplete privileged modules labeled experimental/unverified.

**Tracking principle:** never mark a feature DEVICE-accepted on source code or simulator results alone; preserve pinned original implementations instead of guessing their semantics.
