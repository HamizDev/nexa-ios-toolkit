# Nexa upstream integration workspace

This branch contains **real, pinned upstream source repositories** as Git submodules, rather than duplicated or fabricated app logic. **This is an integration workspace, not yet a single functioning merged IPA.**

## Initial source checkout

```sh
git clone --recurse-submodules https://github.com/HamizDev/nexa-ios-toolkit.git
cd nexa-ios-toolkit
git submodule status
```

For an existing checkout:

```sh
git submodule update --init --recursive
```

Open `Nexa.xcworkspace` with a current macOS Xcode that supports the iOS 26 SDK. The workspace includes:

| Project | Folder | Project structure | Status in Nexa |
|---|---|---|---|
| WQFiles | `ThirdParty/WQFiles` | Clang/`build.sh`, **no .xcodeproj** | WQCore already compiled into Nexa. Full browser NOT merged |
| WCMigrate | `ThirdParty/WCMigrate` | `XChatTransfer.xcodeproj` | Independent Xcode target; not installed as Nexa submodule |
| GestaltX | `ThirdParty/GestaltX` | `GestaltX.xcodeproj` | Independent Xcode target; writes NOT wired to Nexa |
| HermesEnabler | `ThirdParty/HermesEnabler` | `HermesEnabler2.xcodeproj`, includes watchOS | Independent signed watch app/companion; NOT bundled in Nexa |

Do not assume a workspace reference embeds another App target or grants its capabilities. All upstream Bundle IDs, App Groups, bridging headers, build settings and watch extension provisioning must be reviewed and reconciled before distributing a unified app.

## Working functional integration in Nexa

- WQFiles' `WQCore.m/h`: read-only hex parsing on imported files.
- [Next] WCMigrate's standalone progress estimator and app-local staging (no third-party private container access).
- [Next] GestaltX's OS version helper (read-only gating; no system modifications).
- [Next] Apple Watch connectivity status (no watch-face modification).

## Build blockers for an actual unified IPA

1. **WQFiles** requires its container/extension backend, special entitlements, and integration of C/ObjC source dependencies.
2. **WCMigrate** brings its own `@main` app, C/ObjC bridge, App Group identity and migration state machine; those cannot coexist unchanged in Nexa's single app target.
3. **GestaltX** expects a separate configuration database and its own signed access environment; do not enable system writes until backup and rollback behavior is verified.
4. **HermesEnabler** depends on a real watchOS target, paired Apple Watch, watch app installation, and matching companion identities. An iPhone-only UI cannot enable watch faces.
5. **Signing**: Only one bundle identity per app, explicit App Group entitlements and a compatible Xcode toolchain. No macOS/Xcode build has been performed for this integration.

The actual policy is to keep upstream projects pinned and credited, build verifiable read-only functionality first, then reconcile target/product structures on a macOS host. Never mark cross-app, system-write or watch modification capabilities as working solely because submodules are checked out.

## Licenses

- WQFiles: GPL-3.0-or-later.
- WCMigrate: GPL-3.0-or-later.
- GestaltX: GPL-3.0-only (individual upstream source headers).
- HermesEnabler: MIT (see its LICENSE).

The full sources and respective LICENSE files stay inside their original submodule folders. Vendored portions of WQFiles already present in Nexa maintain their original notices. Preserve original notices and comply with the license of each component in any combined distribution.

## Pinned commits

| Source | Commit SHA |
|---|---|
| WQFiles | `fe92ae94067983b94fd927e0b4eee52e5a99a4e7` |
| WCMigrate | `55faba721fd44e04c65be481860c9d93e12f6f61` |
| GestaltX | `311f78999d9f5f062f7e3b4c6374684782be5382` |
| HermesEnabler | `c0ae1666cba67ab7fbae6d3e481cc2731f5550a1` |

## Local plist editing added to this branch

Nexa can now open a **user-imported** .plist via its file inspector. A typed editor uses GestaltX's original `PlistValueKind` parser, stages a modified property list, makes a backup under the app's Application Support, and atomically saves the imported local copy. No system cache path, exploit, or arbitrary external file mutation is involved. Xcode/device compilation and a test of these edits remain outstanding.

## WQFiles original ZIP engine integrated

The original `WQArchive.h/m` and `WQLocalization.h/m` from the pinned upstream commit are compiled directly into the Nexa main target and linked against system zlib. Nexa uses the upstream ZIP writer to archive app-imported files into `Documents/Archives`, and the upstream ZIP extractor for explicitly imported ZIP archives with an extraction size cap and a fresh, app-local destination directory. The underlying engine rejects unsafe paths and special archive entries. ZIP operations do **not** access other app sandboxes. As always, Xcode compilation and runtime regression tests must pass before release.

## WCMigrate database validation integrated

The original read-only WCMigrate `DatabaseInspector.swift` was adapted to the Nexa backup manifest and its PascalCase `Payload` directory. It verifies each backup before reading, then copies databases and SQLite sidecars to a temporary isolated location and performs a bounded `quick_check(1)`. Its `DatabaseReport` model is extracted from WCMigrate's `Core/Models.swift`. This is a **file integrity and schema diagnostic**, not WeChat record restoration or a semantic database merge.

## NexaWatch companion target

Nexa now defines **two linked native targets in a single Xcode project**: `Nexa` for iOS and `NexaWatch` for watchOS. The iOS target embeds `NexaWatch.app` into its Watch bundle and depends on the watch target; both derive their IDs from `NEXA_COMPANION_BUNDLE_IDENTIFIER` in Xcode Build Settings. The included watch app implements bilingual SwiftUI and a two-way WatchConnectivity ping. It **does not** embed HermesEnabler's watch-face modification engine; the full original source remains pinned in `ThirdParty/HermesEnabler` for licensed integration. Real Watch pairing, provisioning, signing and device execution remain acceptance requirements.

## WQFiles container access (experimental)

The original `WQAccess.m`, `WQLaunchServices.m`, and `WQScanTask.m` are now added directly to Nexa's Xcode target by reference to the pinned submodule. The SwiftUI explorer allows only user-initiated, read-only listing and a bounded preview, checks an OS/build allowlist and verifies a signed App Group. No broad scan, privileged write or silent access is enabled. See [WQFILES_CONTAINER_BACKEND.md](WQFILES_CONTAINER_BACKEND.md) for build and provisioning details. This is **not yet a verified working sandbox-escape integration on device**.
