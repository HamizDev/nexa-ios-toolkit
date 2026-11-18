# CI five-tab visual smoke — Nexa 0.0.1

## Why this check exists

On 2026-11-18 the first ZIP containing five screenshots (`44232278062`) was inspected and **all five screenshots showed the Home page**, even though the filenames were different. The user-facing five-tab validation claim was incorrect. The custom iOS Debug Xcode configuration did not define `DEBUG`, so `--nexa-tab=` was ignored.

## Fixed check

- The iOS Target Debug build explicitly sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"`; Release never enables this.
- `NexaRootView` accepts only `home/files/backups/explore/settings` test arguments **in Debug**, and it writes its actual current selection to `Documents/.nexa-ui-smoke-current-tab` when a test argument is present.
- GitHub Actions starts the same app process for each requested tab, checks the file contents through `simctl get_app_container`, and **fails** if the tab differs. It then takes a screenshot.
- If there is no bootable iOS 26+ Simulator runtime, the script currently issues a warning and skips. It must not count as visual acceptance; review the job log and artifact before approval.

## Human review to perform on a successful five-tab ZIP

Verify that the image for each named tab actually shows its distinct UI; inspect tab selection, long Simplified Chinese/English labels, clipping on iPhone-sized screens, contrast, accessibility text sizes, overflow and empty states. Screenshot smoke only covers first-level entry and does not validate each modal, import sheet or destructive-operation flow.

A phone/debug launch marker is solely a local CI handshake; it is not a shipped product feature or any evidence of private sandbox access.
