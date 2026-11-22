# CI five-tab visual smoke — Nexa 0.0.1

## Why this check exists

On 2026-11-18 the first ZIP containing five screenshots (`44232278062`) was inspected and **all five screenshots showed the Home page**, even though the filenames were different. The user-facing five-tab validation claim was incorrect. The custom iOS Debug Xcode configuration did not define `DEBUG`, so `--nexa-tab=` was ignored.

## Fixed check

- The iOS Target Debug build explicitly sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`; Release never enables this.
- `NexaRootView` accepts only `home/files/backups/explore/settings` test arguments **in Debug**, and it writes its actual current selection to `Documents/.nexa-ui-smoke-current-tab` when a test argument is present.
- GitHub Actions boots an iOS 26+ simulator in a dedicated 16-minute step, separating slow first-run CoreSimulator migrations from the seven-minute five-tab screenshot budget. It starts the app for each tab, checks the acknowledged tab through `simctl get_app_container`, and **fails** if the tab differs.
- If no compatible simulator is available, the UI smoke step now **fails** instead of silently skipping. A green workflow therefore requires an actual compatible simulator.
- Earlier run `44296214503` captured distinct Home, Files and Backups screens but exceeded the original shared ten-minute budget after a six-minute first boot; Explore and Settings still required rerunning.

## Human review to perform on a successful five-tab ZIP

Verify that the image for each named tab actually shows its distinct UI; inspect tab selection, long Simplified Chinese/English labels, clipping on iPhone-sized screens, contrast, accessibility text sizes, overflow and empty states. Screenshot smoke only covers first-level entry and does not validate each modal, import sheet or destructive-operation flow.

A phone/debug launch marker is solely a local CI handshake; it is not a shipped product feature or any evidence of private sandbox access.
