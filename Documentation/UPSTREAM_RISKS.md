# Nexa 0.0.1 — upstream risk disclosures and functional status

**This document is a snapshot of pinned upstream source at the commits recorded in** [UPSTREAM_SOURCES.md](UPSTREAM_SOURCES.md). It distinguishes three entirely different assertions:

1. **Upstream available:** the original independent project documents/implements a feature. This is not evidence that it works on every iOS/watchOS build.
2. **Nexa integrated:** the actual implementation is compiled into Nexa and has a visible, callable workflow (not just an upstream link or a Git submodule).
3. **Nexa device validated:** the exact signed Nexa and embedded Watch build has been installed and tested on supported real hardware, including fail/rollback paths.

All four upstream projects are only **partially integrated in Nexa 0.0.1**. Simulator compilation, a screenshot, or source inclusion alone does not promote an operation to device-validated status.

| Project | Upstream features already connected to a Nexa workflow | Other features documented by the upstream and not delivered in Nexa | Risk notice visible in Nexa |
| --- | --- | --- | --- |
| WQFiles | Original ZIP/hex/typed plist/SQLite local viewers, gated read-only WQAccess preview and original LaunchServices App metadata catalog, selected-file copy into Nexa Imports; local Nexa backup/trash is independent | Cross-container full folder/file editor, file overwrites, app data clearing, cache cleanup, app backups/restores, SQLite writes, and other upstream management tools | iOS 27.3 beta 2+ patched; backup before writes/deletion; clearing/cleaning may not have per-file backup; close target app |
| WCMigrate | Original progress/ETA, SQLite quick-check, imported `LoginInfo2.dat` identity inspection; separate Nexa-only source-preserving staged copy | Upstream live cross-app Replace/Convert/Merge, app and plugin configuration transfer, original persistent migration checkpoints and actual container authorization | Replace may remove target extras; Merge overwrites namesakes; unchecked Keep Source moves data; no whole-task rollback; uninstall/staging risk; manifest/payload integrity; iOS 27.3 not device-verified in pinned README |
| GestaltX | Original typed plist parsing and loaded-library inspection; offline imported-copy edit/history are Nexa-native | Actual MobileGestalt cache edits, presets, write-side rollback on device | Nexa-derived system-modification caution: original backup and working rollback required; **not** stated as an upstream README compatibility guarantee |
| HermesEnabler 2 | Original Watch BQCore/views plus directly compiled **original iPhone HermesCompanion WatchConnectivity backup receiver**, SHA-256 backup history, verified plist import/export and transfer-to-Watch UI; version/App Group/consent gates | Actual paired Watch transfer, restore, face effects, signed device acceptance and full generated-string translations are **not** verified | Before uninstall restore MobileGestalt backup; keep stable Bundle ID/Apple ID; watchOS 26 experimental upstream, supported 27.0–27.3 beta 1 upstream, Nexa gate conservatively 27.0–27.2 |

## Important: do not invent capabilities the upstream never promised

WCMigrate's pinned README explicitly says **file merge is not SQLite chat-record row-level merge**, **Keychain/login state is not transferred**, and **there is no whole-task rollback**. Do not describe Nexa as missing a proven upstream “semantic WeChat message database merger” or promise flawless restore as if upstream shipped one. Such higher-level functionality would require a separately engineered and proven solution.

WQFiles' pinned README warns that iOS 27.3 beta 2 (24C5049d) and later patched worse_query. Its broader independent app feature set cannot be called supported in Nexa solely because the repository is present under `ThirdParty/`.

HermesEnabler's pinned README says to restore the original MobileGestalt backup **before deleting the app** and to use a fixed bundle ID/Apple ID for updates. It requires a properly provisioned paid Apple Developer App Group entitlement. The original advertises watchOS 27.0 through 27.3 beta 1 (with watchOS 26 marked experimental); Nexa restricts its experimental entry to 27.0–27.2 until tested.

GestaltX's pinned README does not give a substantial list of detailed safety guarantees; the in-app warning about system cache edits is a **Nexa safety assessment**, not invented upstream attribution.

## In-app display

- First normal launch: a bilingual disclaimer and a checkbox confirming the user has read the warnings. The app stores that the notice was acknowledged, **not** a waiver of legal rights. CI-only `DEBUG --nexa-tab=...` launches bypass this modal solely to screenshot each real tab.
- Settings: permanent `免责声明与上游风险 / Disclaimer & upstream risks` navigation entry.
- Explorer and module details: risk notices visible at the relevant workflow/feature, plus source links and actual current integration status.
- Watch: original MobileGestalt backup warning next to the experimental Hermes feature gate; no system changes become permitted just by accepting the disclaimer.

## Provenance and acceptance

- [WQFiles pinned README](https://github.com/kolbicz/WQFiles/blob/fe92ae94067983b94fd927e0b4eee52e5a99a4e7/README.md)
- [WCMigrate pinned README](https://github.com/yangokok886/WCMigrate/blob/55faba721fd44e04c65be481860c9d93e12f6f61/README.md)
- [GestaltX pinned source](https://github.com/huamidev/GestaltX/tree/311f78999d9f5f062f7e3b4c6374684782be5382)
- [HermesEnabler pinned README](https://github.com/pookjw/HermesEnabler/blob/c0ae1666cba67ab7fbae6d3e481cc2731f5550a1/README.md)

Remaining launch-blocking work is tracked in [RELEASE_READINESS.md](RELEASE_READINESS.md). Source integration is not a tested signed IPA, and a disclaimer does not replace permission checks, backups, transaction safety or rollback.

## Nexa-only file-level Merge/Replace safeguards

The imported-snapshot `NexaImportCombine` feature deliberately differs from WCMigrate's live Replace/Convert/Merge: it always creates a **new output** and retains both originals. Its warning distinguishes file-level name precedence from chat-database record merging. Do not treat the presence of this menu as completion of the original upstream live-app migration or a guarantee of system data recoverability. The source-based WCMigrate risk card remains visible on the Combine view.
