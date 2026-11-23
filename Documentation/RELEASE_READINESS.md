# Nexa 0.0.1 — release readiness and missing functions

**Status: developer preview.** The unified development branch is `feature/nexa-0.0.1-unified`, reviewed via [Draft PR #3](https://github.com/HamizDev/nexa-ios-toolkit/pull/3). `main` remains the earlier prototype. Successful Simulator CI proves compilation and some local behavior, **not** unsupported private-system privileges.

| Area | Real, currently wired to Nexa | Missing / not accepted |
| --- | --- | --- |
| WQFiles | Original ZIP/core hex; newly wired original UIKit paged WQHexViewer.m with WQUI.m and WQTheme.m in forced read-only mode for Nexa-imported regular files; gated experimental container listing/read preview and streamed import | Verify new viewer on current simulator CI, real-device sandbox lease and recovery, authenticated cross-container changes, and remaining original app browser/SQLite/plist/cache workflows |
| WCMigrate | Pinned original progress/ETA, SQLite read-only inspector and `LoginInfo2.dat` identity parser; Nexa-only SHA-256 staging and independent file-level Merge/Replace output tools | Original `DirectMigrationService`, live WeChat app-to-app Replace/Convert/file-level Merge (upstream does not offer SQLite chat-row merge or whole-task rollback), plus real-device recovery acceptance |
| GestaltX | Original typed plist parsing, offline imported-file editor, private SHA-256 history/restore; read-only MobileGestalt loaded-library summary | Live MobileGestalt cache edits and presets; supported-build capability gating, on-device verified system rollback |
| HermesEnabler 2 | Original Watch BQCore and UI plus **original iPhone HermesCompanion WatchConnectivity receiver**, SHA-256 backup history, plist import/export and queued transfer-to-Watch, with one iPhone delegate and Nexa Ping adapter | Actual paired Watch backup receiving, Watch delegate handoff, restore/rollback, physical face effects, signed App Groups and complete translations remain unverified |
| Nexa UI | Five-tab Chinese-first/English SwiftUI UI, imported file workspace, ZIP tools, backup/restore, local migration, recovery-snapshot browsing/export and Watch companion; latest five-tab simulator screenshots captured and visually checked | Dynamic Type/VoiceOver assessment, running on small/large devices, end-to-end user acceptance |
| Distribution | Xcode iOS/watchOS Simulator builds, unsigned generic device-Release build CI, source-pinning audit, host regression tests, unsigned preview and owner-run signed IPA export script with actual signature/App Group checks | Provisioned Apple Developer Team, signed entitlements verified on owner hardware and real iPhone+Watch installation/acceptance |

## Release gates (currently open)

- [ ] **Real-device WQFiles**: verify supported iOS *build*, signed App Group, authorized test container, upstream lease, repair and no incidental private-data loss.
- [ ] **WCMigrate live-data migration**: integrate upstream transaction engine only after safe source/target authorization, transaction durability, real app-data compatibility and recovery tests. Never treat local imported-file copying as a substitute.
- [ ] **GestaltX device writes**: verify original-system backup, preflight, explicit consent, per-build compatibility and successful rollback on disposable test devices.
- [ ] **Hermes paired-device acceptance**: original iPhone Companion backup transport/history/import/export is now source-wired. Verify a real Watch backup reaches the phone even when its page is closed, survives restart, passes SHA-256; verify Watch delegate handoff and queued phone-to-Watch import, original-state rollback and face changes on supported hardware. Simulator compilation alone is insufficient.
- [ ] **UI and accessibility**: visually inspect five screenshots, navigation, full Chinese/English coverage, long strings, contrast and screen-reader support.
- [ ] **Signing and release**: archive, install and test the same signed IPA (embedded Watch app included); verify App Groups in the signed entitlements; publish release only after the above tests pass.

## Hermes upstream iPhone companion milestone (2026-11-23)

The iPhone target directly references the **unchanged pinned HermesCompanion WatchConnectivityManager.swift**, and Nexa initializes that manager for the whole app lifetime as the only phone WCSession delegate. The Watch page calls its original backup receiving/history, verification, plist import/export and transfer-to-Watch APIs. The former Nexa-only delegate was replaced by an optional Ping adapter. This is a **source-wired milestone**, not proven real Watch backup transfer, import confirmation or recovery. Track remaining evidence in [IMPLEMENTATION_BACKLOG.md](IMPLEMENTATION_BACKLOG.md).

## Pinned upstream reuse audit (2026-11-23)

See [UPSTREAM_REUSE_AUDIT_2026-11-23.md](UPSTREAM_REUSE_AUDIT_2026-11-23.md) for actual source entry points, missing call chains and the recommended original-code reuse sequence. At pinned head `fffb48a`, CI [45155034638](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45155034638) passed all four jobs, including unsigned iPhone and Watch Release device-SDK compilation. The original Hermes recovery/layout host fixtures were subsequently added as a separate gate; review their own run before marking them passed.

## Verification update (2026-11-22)

- CI run [45012726433](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45012726433) **passed all three jobs**, including five distinct tab launches and the original upstream WQFiles regression.
- The five PNG screenshots were downloaded and manually reviewed. All tabs have their intended titles and distinct content; remaining accessibility and longer text testing is not covered.
- Nexa-local backup creation now publishes only after complete SHA-256 validation. The new version-2 manifest also inventories empty directories; existing version-1 backups remain readable. Incomplete staging is hidden; failed copies clean staging. A new recoverable-copy list exposes retained pre-restore and rejected data after restart, with a raw ZIP export that is clearly not a verified backup.
- Hardware signing, OS-specific system operations and actual Watch face modifications remain unverified and are **not** release-accepted.

## Current executable checks

Run `python3 Scripts/check_integration.py` after recursively checking out Git submodules. GitHub Actions runs disposable host tests for backups/restores, WCMigrate identity fixtures, local migration (including malformed recovery journals), GestaltX plist history, WQFiles path validation and upstream C modules. CI also attempts to boot an iOS 26+ Simulator and take five tab screenshots; **a screenshot artifact is not evidence that every UI state has been inspected**.

Local, owner-provisioned device signing is documented in [SIGNING.md](SIGNING.md). Do not commit private signing credentials or falsely advertise an unsigned Simulator ZIP as an installable IPA.

## Screenshot smoke regression found 2026-11-18

An actual review of the screenshots from workflow `44232278062` found that `home.png`, `files.png`, `backups.png`, `explore.png` and `settings.png` all showed the Home screen, despite all five screenshot commands returning success. **This invalidates the old five-tab coverage claim.** The project’s custom iOS Debug build settings omitted the `DEBUG` Swift condition used to enable `--nexa-tab=...`.

The updated Debug target explicitly defines `DEBUG`, while release builds do not. When a test launch argument is present, Nexa writes a `.nexa-ui-smoke-current-tab` file in its own Documents directory. The screenshot workflow reads the selected tab after every launch and fails if the value is not the requested tab. Do not call UI screenshot acceptance complete until this corrected CI run actually passes and the resulting five screenshots are visually reviewed.

## Disclaimer, source risk and stable-feature audit

Nexa now includes `NexaSafety.swift` with bilingual first-run disclosure, a permanent Settings entry, actual per-module integration status, pinned upstream risk URLs and a Watch uninstall-before-restore caution. CI verifies that the warning views and both languages remain linked to the iPhone target. [UPSTREAM_RISKS.md](UPSTREAM_RISKS.md) inventories what the pinned upstream projects implement **versus** which workflows Nexa actually exposes. The presence of an upstream project inside `ThirdParty/` is not full functional integration. No blanket completion date is claimed while owner-provisioned signing and real-hardware test results are outstanding.

### Local Merge/Replace acceptance (development branch)

- [x] Nexa-native Merge/Replace on **imported copies only**, with a visible preview, unique output directory and no mutations to either original.
- [x] macOS fixture suite for source precedence, target-only preservation, replace exclusion, source mutation, unsafe links and journal recovery passed at run 45012726433; rerun for subsequent changes.
- [ ] Signed iPhone testing with real imported file-provider folders, storage pressure and forced app termination.
- [ ] Full upstream `DirectMigrationService` live WeChat transfer and its device-specific authorization — **not integrated**.
