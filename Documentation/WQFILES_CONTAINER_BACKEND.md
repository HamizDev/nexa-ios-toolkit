# WQFiles container backend (experimental, read only)

This integration adds the **original upstream WQFiles** `WQAccess.m`, `WQLaunchServices.m` and `WQScanTask.m` source files to Nexa's iOS compilation target **by reference to the pinned submodule**. No copies have been modified. The corresponding headers are resolved through `ThirdParty/WQFiles`.

The SwiftUI `NexaWQExplorerView` explicitly requires:
1. an iOS build in the upstream reported range (and denies simulators), 
2. an App Group actually present in the signed entitlements, 
3. a fresh user acknowledgement of ownership/authorization, and 
4. an explicit folder-open request.

The UI is limited to read-only listing and a 4-KB selected-file preview inside the app-data and App Group container roots. **It performs no cross-container writes, migration, or automatic scanning.**

The sample entitlements use the build setting `NEXA_APP_GROUP_IDENTIFIER=group.com.example.Nexa`. Developers must replace both this value and the example bundle identifier with their own identifiers and configure matching provisioning in Signing & Capabilities. App Group signing is a runtime prerequisite; merely putting an entitlement in a plist does not grant access.

This feature has not been verified on a physical device; do not claim the worse_query grants work until tested on an authorized iOS version with a real development signature and complete audit log. This code is research-only and not suitable for App Store distribution.

Upstream: https://github.com/kolbicz/WQFiles — GPL-3.0-or-later, pinned source commit `fe92ae94067983b94fd927e0b4eee52e5a99a4e7`.

### Side effects and recovery

Even though the Nexa UI exposes only read-only listing and preview, the original worse_query sandbox-lease mechanism **may alter Nexa's own App Group cache** while requesting a token. Do not mistake "read-only user data" for "no filesystem changes whatsoever". Preserve the upstream repair/release semantics and validate recovery after interruption before device release. Avoid accessing another person's private app data without their authorization.
