# Nexa 0.0.1 — release readiness and missing functions

**Status: developer preview.** The unified development branch is `feature/nexa-0.0.1-unified`, reviewed via [Draft PR #3](https://github.com/HamizDev/nexa-ios-toolkit/pull/3). `main` remains the earlier prototype. Successful Simulator CI proves compilation and some local behavior, **not** unsupported private-system privileges.

| Area | Real, currently wired to Nexa | Missing / not accepted |
| --- | --- | --- |
| WQFiles | Original ZIP and hex utilities; gated experimental container listing/read preview and selected-file streaming copy to Nexa Imports | Real iOS device sandbox lease and clean recovery; authenticated safe writes across containers; full original file-manager workflows |
| WCMigrate | Pinned original progress/ETA, SQLite read-only inspector and `LoginInfo2.dat` identity parser; separate Nexa-only SHA-256 staging tool | Original `DirectMigrationService`, live WeChat app-to-app Replace/Convert/file-level Merge (upstream does not offer SQLite chat-row merge or whole-task rollback), plus real-device recovery acceptance |
| GestaltX | Original typed plist parsing, offline imported-file editor, private SHA-256 history/restore; read-only MobileGestalt loaded-library summary | Live MobileGestalt cache edits and presets; supported-build capability gating, on-device verified system rollback |
| HermesEnabler 2 | Original Watch BQCore engine, screens and MG resources compiled into embedded NexaWatch; connection diagnostics, watchOS/App Group consent gates and 82 bilingual fixed labels | Signed Watch device acceptance, face changes, physical-device backup and rollback, complete translated runtime messages |
| Nexa UI | Five-tab Chinese-first/English SwiftUI UI, imported file workspace, ZIP tools, backup/restore, local migration, app Watch companion; simulator screenshots uploaded | Manual screenshot review, Dynamic Type/VoiceOver assessment, running on small/large device screens, end-to-end user acceptance |
| Distribution | Xcode iOS + watchOS Simulator builds, source-pinning/provenance audit, host regression tests, unsigned ZIP preview; owner-run signed IPA archive script | Provisioned Apple Developer Team and tested iPhone+Watch IPA, signed entitlements, safe real-device release artifacts |

## Release gates (currently open)

- [ ] **Real-device WQFiles**: verify supported iOS *build*, signed App Group, authorized test container, upstream lease, repair and no incidental private-data loss.
- [ ] **WCMigrate live-data migration**: integrate upstream transaction engine only after safe source/target authorization, transaction durability, real app-data compatibility and recovery tests. Never treat local imported-file copying as a substitute.
- [ ] **GestaltX device writes**: verify original-system backup, preflight, explicit consent, per-build compatibility and successful rollback on disposable test devices.
- [ ] **Hermes device operations**: verify original state backup and actual face changes/recovery on a provisioned Watch with supported hardware/watchOS; simulator source build alone is insufficient.
- [ ] **UI and accessibility**: visually inspect five screenshots, navigation, full Chinese/English coverage, long strings, contrast and screen-reader support.
- [ ] **Signing and release**: archive, install and test the same signed IPA (embedded Watch app included); verify App Groups in the signed entitlements; publish release only after the above tests pass.

## Current executable checks

Run `python3 Scripts/check_integration.py` after recursively checking out Git submodules. GitHub Actions runs disposable host tests for backups/restores, WCMigrate identity fixtures, local migration (including malformed recovery journals), GestaltX plist history, WQFiles path validation and upstream C modules. CI also attempts to boot an iOS 26+ Simulator and take five tab screenshots; **a screenshot artifact is not evidence that every UI state has been inspected**.

Local, owner-provisioned device signing is documented in [SIGNING.md](SIGNING.md). Do not commit private signing credentials or falsely advertise an unsigned Simulator ZIP as an installable IPA.

## Screenshot smoke regression found 2026-11-18

An actual review of the screenshots from workflow `44232278062` found that `home.png`, `files.png`, `backups.png`, `explore.png` and `settings.png` all showed the Home screen, despite all five screenshot commands returning success. **This invalidates the old five-tab coverage claim.** The project’s custom iOS Debug build settings omitted the `DEBUG` Swift condition used to enable `--nexa-tab=...`.

The updated Debug target explicitly defines `DEBUG`, while release builds do not. When a test launch argument is present, Nexa writes a `.nexa-ui-smoke-current-tab` file in its own Documents directory. The screenshot workflow reads the selected tab after every launch and fails if the value is not the requested tab. Do not call UI screenshot acceptance complete until this corrected CI run actually passes and the resulting five screenshots are visually reviewed.

## Disclaimer, source risk and stable-feature audit

Nexa now includes `NexaSafety.swift` with bilingual first-run disclosure, a permanent Settings entry, actual per-module integration status, pinned upstream risk URLs and a Watch uninstall-before-restore caution. CI verifies that the warning views and both languages remain linked to the iPhone target. [UPSTREAM_RISKS.md](UPSTREAM_RISKS.md) inventories what the pinned upstream projects implement **versus** which workflows Nexa actually exposes. The presence of an upstream project inside `ThirdParty/` is not full functional integration. No blanket completion date is claimed while owner-provisioned signing and real-hardware test results are outstanding.
