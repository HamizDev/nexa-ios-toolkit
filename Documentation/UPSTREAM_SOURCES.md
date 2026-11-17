# Nexa upstream source inventory · 2026-11-17

This file distinguishes **vendored, compiled, and used code** from projects that are only research references. A GitHub link or an inactive feature card does **not** count as integration.

## Compiled upstream sources

| Project | Pinned upstream SHA | Files copied | License | Runtime usage |
| --- | --- | --- | --- | --- |
| [kolbicz/WQFiles](https://github.com/kolbicz/WQFiles) | `fe92ae94067983b94fd927e0b4eee52e5a99a4e7` | `WQCore.h/m`, `WQArchive.h/m`, `WQLocalization.h/m` → `Vendor/WQFiles/` | GPL-3.0-or-later | Hex validation; ZIP writer and safe extractor on imported files |
| [yangokok886/WCMigrate](https://github.com/yangokok886/WCMigrate) | `55faba721fd44e04c65be481860c9d93e12f6f61` | Original `OperationEstimate.swift`, extracted `BackupProgress` / `DatabaseReport` models, adapted `DatabaseInspector.swift` → `Vendor/WCMigrate/` | GPL-3.0-or-later | Backup progress / ETA; SQLite quick_check on verified local backup copies (not chat recovery) |
| [huamidev/GestaltX](https://github.com/huamidev/GestaltX) | `311f78999d9f5f062f7e3b4c6374684782be5382` | Adapted `VersionSupport.swift` → `Vendor/GestaltX/` | GPL-3.0-only | Read-only version gating only |

The copied WQCore files are unchanged upstream source; attribution and license headers are preserved. `Nexa/Nexa-Bridging-Header.h` and Xcode project compilation/linking settings are Nexa glue code. **No WQFiles container-access implementation is included.**

## Complete pinned upstream source checkouts

The `ThirdParty/` folder contains four Git submodules: WQFiles, WCMigrate, GestaltX and HermesEnabler. They are **not** compiled into one Nexa app by their presence. The workspace references their original independent projects where available. See [UPSTREAM_WORKSPACE.md](UPSTREAM_WORKSPACE.md).

## Reviewed, not integrated

| Upstream | Latest inspected main SHA | Integration status |
| --- | --- | --- |
| [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) | `d1540e20cd82b974d891e0551ced6d6aeb570ac2` | Reference only |
| [yangokok886/WCMigrate](https://github.com/yangokok886/WCMigrate) | `55faba721fd44e04c65be481860c9d93e12f6f61` | Partial direct component integration; full cross-app migration still unavailable |
| [MchinaMd57764/WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | `a5969d624e62c42803f1ef2973e5fd99405b0150` | Reference only; explicit repository LICENSE not found, review needed |
| [huamidev/GestaltX](https://github.com/huamidev/GestaltX) | `311f78999d9f5f062f7e3b4c6374684782be5382` | Read-only VersionSupport component integrated; no MobileGestalt writer |
| [pookjw/HermesEnabler](https://github.com/pookjw/HermesEnabler) | `c0ae1666cba67ab7fbae6d3e481cc2731f5550a1` | Full source pinned as submodule, but no watchOS target built into Nexa |
| [jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion) | `2e118f4e575b2cb745d9462ac445f023e09ec4da` | Reference only |
| [ichitaso/Regitela](https://github.com/ichitaso/Regitela) | `e1ed6597816e8ce30457607239a2216345cfd8a1` | Reference only |
| [GoldensHQ/worstgestalt](https://github.com/GoldensHQ/worstgestalt) | `1839f044e807ea203d7a1131ca16a38f123fd557` | Reference only |
| [fucknima/worsefiles-ios](https://github.com/fucknima/worsefiles-ios) | `fe10fc84137e522692ec685fb51c0cfa37378941` | Reference only |

No third-party IPA or binary has been copied into Nexa. Please examine each upstream's license and dependencies **before** copying any additional files. For reuse, retain original notices, modify with attribution, and document how code is actually invoked and tested.

## Offline plist editing (GestaltX excerpt)

`Vendor/GestaltX/PlistValueKind.swift` preserves an exact excerpt of `GestaltDocument.swift` (`GestaltFailure` and `PlistValueKind`), from the same pinned SHA. It is compiled into Nexa's `NexaPlistInspectorView` for type detection, safe input parsing, and local plist serialization. Changes are limited to files that the user explicitly imported, with a backup of the imported copy taken before each write. This **does not** write to system MobileGestalt or access other app containers.

## Additional WQFiles original backend references

Nexa directly compiles these unchanged upstream files from `ThirdParty/WQFiles`: `WQAccess.m`, `WQLaunchServices.m`, `WQScanTask.m`, with corresponding headers from the same pinned commit. A consent-gated SwiftUI read-only container browser calls `wq_list` and bounded `wq_read`. Real-device functioning depends on the installed App Group entitlement, supported OS/build and the results of an on-device grant; no such acceptance tests have been completed. License: GPL-3.0-or-later.
