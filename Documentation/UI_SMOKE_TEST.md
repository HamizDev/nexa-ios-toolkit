# CI five-tab visual smoke — Nexa 0.0.1

## Why this check exists

On 2026-11-18 the first ZIP containing five screenshots (`44232278062`) was inspected and **all five screenshots showed the Home page**, even though the filenames were different. The user-facing five-tab validation claim was incorrect. The custom iOS Debug Xcode configuration did not define `DEBUG`, so `--nexa-tab=` was ignored.

## Fixed check

- The iOS Target Debug build explicitly sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`; Release never enables this.
- `NexaRootView` accepts only `home/files/backups/explore/settings` test arguments **in Debug**, and it writes its actual current selection to `Documents/.nexa-ui-smoke-current-tab` when a test argument is present.
- GitHub Actions boots an iOS 26+ simulator in a dedicated 16-minute step. Installation and first launch, five main tabs, Hermes backup fixture, three native WQFiles viewers, App catalog gating, and original WCMigrate preview now have independent step budgets. Every later launch removes its old marker first; CI **fails** if the expected fresh marker is missing. Run 45230325746 previously captured seven screenshots before hitting the old shared seven-minute budget; the new split awaits validation.
- If no compatible simulator is available, the UI smoke step now **fails** instead of silently skipping. A green workflow therefore requires an actual compatible simulator.
- Earlier run `44296214503` captured distinct Home, Files and Backups screens but exceeded the original shared ten-minute budget after a six-minute first boot; Explore and Settings still required rerunning.

## Original Hermes iPhone companion fixture (Debug only)

After checking the five main tabs, CI now launches the same debug iPhone app
with --nexa-watch-view and --nexa-hermes-fixture and verifies both an on-disk
Watch-screen marker and a disposable original-Hermes backup test. The fixture
calls the genuine upstream HermesCompanion importBackup, verifyBackup,
exportURL and loadBackupHistory methods on synthetic MobileGestalt-shaped
plist data, checks SHA-256, duplicate and malformed-input rejection,
then captures watch-companion.png. This tests the iPhone receiver's local
storage path and screen; it does **not** simulate WCSession transport or
prove paired Watch real-device recovery.

## Original WQFiles UIKit viewer fixture (Debug only)

After five tabs and the Hermes synthetic backup fixture, CI opens **two
original WQFiles UIKit controllers**, each directly compiled from the pinned
submodule, using a temporary regular file created inside Nexa Imports:
`--nexa-wqhex-smoke` opens original paged `WQHexViewController`, and
`--nexa-wqplist-smoke` opens original `WQPlistEditorViewController`, and
`--nexa-wqsqlite-smoke` opens the original `WQSQLiteViewController` with an
app-owned synthetic SQLite database.
All three have `readOnly: true` and pass the same imported-file gate as the
production File Inspector entry. CI checks a Debug-only on-disk
`PASS: WQFiles native hex/plist` marker and saves screenshots
`wq-original-hex.png`, `wq-original-plist.png` and `wq-original-sqlite.png`.
The sample data is synthetic, not from a device system cache or other app.
Screenshot approval still requires **manual visual review** of the original
viewer's actual content, not just a generated marker.

## Confirmed nine-screen WQFiles run (2026-11-24)

Run [45223067042](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45223067042) at SHA `866fc23d` passed all four jobs. Screenshots for the five main tabs, Hermes phone companion and original WQFiles Hex/plist/SQLite viewers were manually inspected. The upstream Hex viewer shows the actual 00..FF test-byte grid and ASCII gutter; the upstream plist viewer shows typed Count, Flags and Sample values; the original SQLite viewer shows `imported_notes` with one row and its read-only snapshot notice. This visual check is **not** Dynamic Type/VoiceOver, real device hardware or remote container privilege acceptance.

## WQFiles original LaunchServices App catalog (Debug gating)

CI launches `--nexa-wqapps-smoke` and captures `wq-app-catalog.png` after the nine existing screens. On iOS Simulator, this page **must** display that the feature is unavailable without a supported physical device and its signed App Group. The app writes a Debug-only marker that fails if `NexaContainerAccess.ready` unexpectedly becomes true. This is an unavailable-state UI check; **it cannot prove real-device LaunchServices listing or sandbox grants**.

The original pinned WQApps manager contains destructive paths without a general `readOnly` switch. Nexa intentionally does **not** embed that controller. Its App catalog uses the existing upstream `WQLaunchServices` parser, the upstream `WQAppsSupport` bundle ID validator, and separately asks for user consent before read-only listing, and again before opening a selected container.

## Original WCMigrate local preview (Debug Simulator only)

The `--nexa-wcmigrate-preview-smoke` fixture creates two disposable
Nexa-imported sample folders. The upstream-derived TransferCore compatibility package preview is
called in Replace and Merge modes (keepSource=true). It must report two
source files (nine bytes, largest five bytes) and one target file;
their exact original bytes must remain unchanged, with no new copied
file. Same-root, outside Imports and nested symbolic-link selections
must all be rejected. Only then does the fresh PASS marker permit a
`wcmigrate-preview.png` screenshot. This exercises original preview
code only, not the original execution/resume API or a third-party app.
No real-device privilege is inferred from this test.

## Human review to perform on a successful five-tab ZIP

Verify that the image for each named tab actually shows its distinct UI; inspect tab selection, long Simplified Chinese/English labels, clipping on iPhone-sized screens, contrast, accessibility text sizes, overflow and empty states. Screenshot smoke only covers first-level entry and does not validate each modal, import sheet or destructive-operation flow.

A phone/debug launch marker is solely a local CI handshake; it is not a shipped product feature or any evidence of private sandbox access.
