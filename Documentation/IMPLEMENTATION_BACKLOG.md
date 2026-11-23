# Nexa 0.0.1 — upstream implementation backlog

**Branch:** feature/nexa-0.0.1-unified · Draft PR #3  
**Last updated:** 2026-11-23. Update after each feature milestone.

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
- [x] WIRED (pending current-head CI): the original `WQHexViewer.m` paged/offset/search UIKit viewer plus original `WQUI.m` and `WQTheme.m` dependencies compiled directly from pinned WQFiles sources. The Nexa SwiftUI wrapper uses `readOnly: true` and only opens a validated Nexa-imported ordinary file (rejects outside paths, symlinks and linked ancestors).
- [ ] Reuse original WQApps, SQLite/Plist viewers and further safe dependencies through SwiftUI wrappers. Avoid duplicating upstream native engines.
- [ ] Run original tests/run_all_tests.sh, preserve error/cancel/recovery handling and license notes.
- [ ] Consider original WQTrash/WQCache or write methods only with explicit scope, verified original backup, predictable restore, safe supported OS/build and actual authorized test-container device tests.
- [ ] DEVICE: verify entitlement/grant/cache recovery, sandbox refusals and patched-build disabling on test-owned data.

## P2 — WCMigrate

Original source: yangokok886/WCMigrate at 55faba721fd44e04c65be481860c9d93e12f6f61 (GPL-3.0-or-later).

- [x] Original progress/ETA, SQLite read-only checker, imported WeChat identity parser; Nexa-owned local copy and Merge/Replace are **not** cross-app WCMigrate.
- [ ] Reuse original Core/DirectMigrationService.swift actor (preview/migrate/resume), Core/Models.swift, PathSafety.swift, DurableJournal.swift, DataStaging.swift and ContainerAccess bridge.
- [ ] Run original DirectMigrationTests, RecoveryTests, DataStagingTests and low-storage/termination fixtures using disposable owned containers.
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
- [ ] Current-head CI green including original Hermes companion + static single-delegate check.
- [ ] Manual Chinese/English, Dynamic Type, VoiceOver, iPad and watchOS confirmation/error dialogs.
- [ ] Signed device IPA with verified original iPhone/Watch App Group entitlements and real paired-device logs (no secrets).
- [ ] Release 0.0.1 only for the clearly accepted scope. Keep incomplete privileged modules labeled experimental/unverified.

**Tracking principle:** never mark a feature DEVICE-accepted on source code or simulator results alone; preserve pinned original implementations instead of guessing their semantics.
