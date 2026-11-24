# Nexa upstream source inventory · 2026-11-17

This file distinguishes **vendored, compiled, and used code** from projects that are only research references. A GitHub link or an inactive feature card does **not** count as integration.

## Compiled upstream sources

| Project | Pinned upstream SHA | Files copied | License | Runtime usage |
| --- | --- | --- | --- | --- |
| [kolbicz/WQFiles](https://github.com/kolbicz/WQFiles) | `fe92ae94067983b94fd927e0b4eee52e5a99a4e7` | `WQCore.h/m`, `WQArchive.h/m`, `WQLocalization.h/m` → `Vendor/WQFiles/` | GPL-3.0-or-later | Hex validation; ZIP writer and safe extractor on imported files |
| [yangokok886/WCMigrate](https://github.com/yangokok886/WCMigrate) | `55faba721fd44e04c65be481860c9d93e12f6f61` | Original `OperationEstimate.swift`, extracted `BackupProgress` / `DatabaseReport` models, adapted `DatabaseInspector.swift`, original `WeChatIdentityResolver.swift` → `Vendor/WCMigrate/` | GPL-3.0-or-later | Backup progress / ETA; SQLite quick_check on verified local backup copies (not chat recovery) |
| [huamidev/GestaltX](https://github.com/huamidev/GestaltX) | `311f78999d9f5f062f7e3b4c6374684782be5382` | Adapted `VersionSupport.swift` → `Vendor/GestaltX/` | GPL-3.0-only | Read-only version gating only |

The copied WQCore files are unchanged upstream source; attribution and license headers are preserved. `Nexa/Nexa-Bridging-Header.h` and Xcode project compilation/linking settings are Nexa glue code. **The pinned original WQAccess/LaunchServices/ScanTask sources are also compiled directly from `ThirdParty/WQFiles`, but their Nexa UI remains experimental read-only and no real-device grant has been validated.** See the later direct integration section and [the source-by-source reuse audit](UPSTREAM_REUSE_AUDIT_2026-11-23.md).

## Complete pinned upstream source checkouts

The `ThirdParty/` folder contains four Git submodules: WQFiles, WCMigrate, GestaltX and HermesEnabler. They are **not** compiled into one Nexa app by their presence. The workspace references their original independent projects where available. See [UPSTREAM_WORKSPACE.md](UPSTREAM_WORKSPACE.md).

## Reviewed, not integrated

| Upstream | Latest inspected main SHA | Integration status |
| --- | --- | --- |
| [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) | `d1540e20cd82b974d891e0551ced6d6aeb570ac2` | Reference only |
| [yangokok886/WCMigrate](https://github.com/yangokok886/WCMigrate) | `55faba721fd44e04c65be481860c9d93e12f6f61` | Partial direct component integration; full cross-app migration still unavailable |
| [MchinaMd57764/WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | `a5969d624e62c42803f1ef2973e5fd99405b0150` | Reference only; explicit repository LICENSE not found, review needed |
| [huamidev/GestaltX](https://github.com/huamidev/GestaltX) | `311f78999d9f5f062f7e3b4c6374684782be5382` | Read-only VersionSupport component integrated; no MobileGestalt writer |
| [pookjw/HermesEnabler](https://github.com/pookjw/HermesEnabler) | `c0ae1666cba67ab7fbae6d3e481cc2731f5550a1` | Source pinned as submodule; original BQCore/feature views and resources directly compiled into embedded NexaWatch |
| [jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion) | `2e118f4e575b2cb745d9462ac445f023e09ec4da` | Reference only |
| [ichitaso/Regitela](https://github.com/ichitaso/Regitela) | `e1ed6597816e8ce30457607239a2216345cfd8a1` | Reference only |
| [GoldensHQ/worstgestalt](https://github.com/GoldensHQ/worstgestalt) | `1839f044e807ea203d7a1131ca16a38f123fd557` | Reference only |
| [fucknima/worsefiles-ios](https://github.com/fucknima/worsefiles-ios) | `fe10fc84137e522692ec685fb51c0cfa37378941` | Reference only |

No third-party IPA or binary has been copied into Nexa. Please examine each upstream's license and dependencies **before** copying any additional files. For reuse, retain original notices, modify with attribution, and document how code is actually invoked and tested.

## Offline plist editing (GestaltX excerpt)

`Vendor/GestaltX/PlistValueKind.swift` preserves an exact excerpt of `GestaltDocument.swift` (`GestaltFailure` and `PlistValueKind`), from the same pinned SHA. It is compiled into Nexa's `NexaPlistInspectorView` for type detection, safe input parsing, and local plist serialization. Changes are limited to files that the user explicitly imported, with a backup of the imported copy taken before each write. This **does not** write to system MobileGestalt or access other app containers.

## Additional WQFiles original backend references

Nexa directly compiles these unchanged upstream files from `ThirdParty/WQFiles`: `WQAccess.m`, `WQLaunchServices.m`, `WQScanTask.m`, with corresponding headers from the same pinned commit. A consent-gated SwiftUI read-only container browser calls `wq_list` and bounded `wq_read`. Real-device functioning depends on the installed App Group entitlement, supported OS/build and the results of an on-device grant; no such acceptance tests have been completed. License: GPL-3.0-or-later.

## WQFiles original hex, typed-plist and SQLite viewers

Nexa's iPhone target directly compiles the **unchanged pinned originals**
`ThirdParty/WQFiles/WQHexViewer.m`, `WQPlistEditor.m`,
`WQSQLiteViewer.m`, `WQSQLiteSave.m`, `WQSharing.m`, `WQUI.m`
and `WQTheme.m`, with existing WQAccess/ScanTask/Localization/Archive sources.
The SwiftUI `NexaWQHexReadOnly.swift` adapter hosts the original
`WQHexViewController`, `WQPlistEditorViewController` and
`WQSQLiteViewController`, all explicitly constructed with **readOnly=true**.
Only an explicitly imported regular file passing
`NexaLocalFiles.validatedImportedRegularFile` is accepted; external paths,
symlinks, linked ancestors and directories are rejected. The SQLite entry is
displayed only if original `wq_is_sqlite_header` recognizes the file header.
Original SQLite viewer works on a private database snapshot and does not
offer save-to-App in read-only mode. The dependency compilation is not an
endorsement of destructive upstream APIs; no external writes are exposed.
Pinned original `tests/WQHexViewerHelpersTests.m`,
`tests/WQPlistEditorSupportTests.m` and
`tests/WQSQLiteSupportTests.m` are included in host regression.
Source compilation and runtime UI acceptance are separate gates in
[IMPLEMENTATION_BACKLOG.md](IMPLEMENTATION_BACKLOG.md).

## WQFiles original LaunchServices-based App metadata catalog

The new Nexa `NexaWQAppCatalogView.swift` calls the unchanged pinned
`WQLaunchServices.m` (already in the Nexa target) and original inline
`WQAppsSupportBundleIDValid` from the pinned `WQAppsSupport.h`. It
uses original `wq_load_display_names`, `wq_ls_container_paths`,
`wq_bundle_id_for_container` and `wq_display_name` for an explicitly
requested, bounded **metadata** list; never manually re-parses the database,
scans whole app containers, or exposes app-data writes.

Both `NexaContainerAccess.ready` (reported OS/build and signed App Group)
and an explicit user-owned-data consent are required **before loading**. On
a selected entry, `NexaWQExplorerView(initialPath:)` requires a separate
consent toggle before any permitted, read-only folder operation.
A LaunchServices record is not proof of access rights. No device grants or
actual private container access have yet passed physical tests.

**Why the original WQAppsViewController is not used:** pinned `WQApps.m`
provides App backup, restore, data clearing and deletion without a global
read-only entry point. Exposing that controller in Nexa would surface
high-risk mutations without established backups/rollback and real-device
authorization. The safe original components are reused, but the complete
original App manager remains a separate unchecked release gate.
This milestone adds pinned `WQAppsSupportTests.m`,
`WQLaunchServicesTests.m` and attempts the upstream full host suite
in CI. Source and device acceptance are distinct.

## WCMigrate original TransferCore package (local read-only preview)

The iPhone target references the local pinned submodule
`ThirdParty/WCMigrate/Package.swift` and links its original `TransferCore`
product. The existing Nexa progress/database adapters remain separate;
original package models are qualified with the TransferCore module name.
`NexaWCMigratePreview.swift` calls the original
`DirectMigrationService.preview`, `AppInstance`, `DirectoryMapping`
and `TransferMode`, without copying or modifying upstream migration
code. Inputs are distinct, validated top-level imported folders,
with fixed Documents/Library mappings and source-preserving Replace/Merge
preview. The access callback is explicitly a no-op. Neither migration
execution nor resume nor the private container-access bridge is exposed.

A separate macOS CI job invokes the original DirectMigrationTests,
RecoveryTests, DataStagingTests, FileOperationTests and MoveMigrationTests.
A Debug-only simulator fixture calls the actual original preview and checks
synthetic source/target contents remain unchanged, counts and sizes,
and same-root/outside-import/symlink rejection. These new gates await CI.
Original migration writes to other applications are not implemented or
validated. This is a read-only planning milestone, not full migration.

## WCMigrate account identity parsing

`Vendor/WCMigrate/WeChatIdentityResolver.swift` copies the original parser from pinned commit `55faba721fd44e04c65be481860c9d93e12f6f61` (GPL-3.0-or-later) with only a provenance comment prepended. `NexaImportedWeChatIdentity.detect(in:)` validates a path inside Nexa's imported folder, disallows symlink traversals, caps inspected account folders and LoginInfo2.dat size, then invokes the upstream parser only on explicit user action. It only identifies a probable WeChat account identity; **it does not migrate, decrypt or restore chat data**. Synthetic host fixtures test valid and invalid parser records.

## GestaltX loaded-library read-only helper

The unmodified `ThirdParty/GestaltX/GestaltX/GXMobileGestaltImage.m/h` files from pinned commit `311f78999d9f5f062f7e3b4c6374684782be5382` (GPL-3.0-only) compile directly into the Nexa iOS target and are declared in its Swift bridging header. Device diagnostics invoke `GXCopyMobileGestaltImage()` only on user request to summarize the **loaded system library**'s string and constant section byte counts. The raw section bytes are never displayed, saved or uploaded. This is **not** an exploit or on-disk MobileGestalt cache modification.

## HermesEnabler 2 direct watch integration in unified build

The embedded NexaWatch target directly compiles the pinned original `ThirdParty/HermesEnabler/HermesEnabler2/BQCore.m`, `BQRecoveryValidation.h`, feature SwiftUI views and original WatchConnectivity manager. Both MGDefaults and MGOffsets resources are included; original upstream `@main` is intentionally excluded. NexaWatch's entry requires a provisioned Watch App Group, an explicit warning acknowledgement and watchOS 27.0–27.2 on real hardware. 82 matching Chinese/English Watch translation keys are bundled. License MIT; original source remains unchanged. No real-watch write or rollback verification has been completed.

## Hermes original iPhone companion source integration

The iPhone Nexa target now builds the **unchanged, pinned original** ThirdParty/HermesEnabler/HermesCompanion/WatchConnectivity/WatchConnectivityManager.swift. It owns WatchConnectivity file reception, SHA-256 backup manifests/history, imported plist validation, export and queued transfer-to-Watch. The original backend is created once at app startup; a thin Nexa Ping extension does not replace its WCSession delegate. iPhone simulator source compilation is separate from actual signed Watch backup delivery and rollback acceptance. See [IMPLEMENTATION_BACKLOG.md](IMPLEMENTATION_BACKLOG.md).

## WQFiles selected-file read-only export

`NexaWQFileExport.swift` invokes pinned upstream `wq_copy_to_local` and `wq_file_version` directly from the unchanged WQAccess Objective-C implementation. It streams a single user-selected, readable regular file into a uniquely named Nexa Imports copy, then verifies the remote file's version did not change. The UI requires explicit user authorization, signed App Group, supported OS/build gate and an individual preview/selection. It never overwrites, deletes, renames or modifies the remote file. `NexaWQImportName.swift` and its host tests reject traversal and unsafe local naming. **True availability remains device and entitlement dependent.** License GPL-3.0-or-later.
