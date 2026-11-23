# CI five-tab visual smoke — Nexa 0.0.1

## Why this check exists

On 2026-11-18 the first ZIP containing five screenshots (`44232278062`) was inspected and **all five screenshots showed the Home page**, even though the filenames were different. The user-facing five-tab validation claim was incorrect. The custom iOS Debug Xcode configuration did not define `DEBUG`, so `--nexa-tab=` was ignored.

## Fixed check

- The iOS Target Debug build explicitly sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`; Release never enables this.
- `NexaRootView` accepts only `home/files/backups/explore/settings` test arguments **in Debug**, and it writes its actual current selection to `Documents/.nexa-ui-smoke-current-tab` when a test argument is present.
- GitHub Actions boots an iOS 26+ simulator in a dedicated 16-minute step, separating slow first-run CoreSimulator migrations from the seven-minute five-tab screenshot budget. It starts the app for each tab, checks the acknowledged tab through `simctl get_app_container`, and **fails** if the tab differs.
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
`--nexa-wqplist-smoke` opens original `WQPlistEditorViewController`.
Both have `readOnly: true` and pass the same imported-file gate as the
production File Inspector entry. CI checks a Debug-only on-disk
`PASS: WQFiles native hex/plist` marker and saves screenshots
`wq-original-hex.png` and `wq-original-plist.png`.
The sample data is synthetic, not from a device system cache or other app.
Screenshot approval still requires **manual visual review** of the original
viewer's actual content, not just a generated marker.

## Human review to perform on a successful five-tab ZIP

Verify that the image for each named tab actually shows its distinct UI; inspect tab selection, long Simplified Chinese/English labels, clipping on iPhone-sized screens, contrast, accessibility text sizes, overflow and empty states. Screenshot smoke only covers first-level entry and does not validate each modal, import sheet or destructive-operation flow.

A phone/debug launch marker is solely a local CI handshake; it is not a shipped product feature or any evidence of private sandbox access.
