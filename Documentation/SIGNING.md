# Nexa 0.0.1 — device signing and IPA export

The public GitHub Actions artifacts are **unsigned iOS Simulator applications**, not device-installable IPA files. The Nexa 0.0.1 code remains a development candidate until entitlement and real-device checks pass.

## Requirements

Use a macOS machine with an Xcode version that supports your iOS and watchOS SDKs. Sign in to a valid Apple Developer team in Xcode, and configure automatic signing for **both Nexa (iPhone) and NexaWatch (watchOS)**. Register a unique iPhone Bundle ID, its embedded Watch bundle ID (`<iPhone ID>.watchkitapp`), and separate (or appropriately shared) App Group IDs for each target. Add the matching App Groups to the Developer portal capabilities and provisioning profiles.

Provisioning may be limited by your distribution method. A successful signature does not grant arbitrary file access or make an exploit work on an unsupported iOS/watchOS build.

## Local archive/export

Set the following values **on your own Mac** (not in a public GitHub issue, log, README, or committed file), then run the script:

```sh
export NEXA_TEAM_ID="YOURTEAMID"
export NEXA_BUNDLE_ID="dev.example.nexa"
export NEXA_PHONE_APP_GROUP="group.dev.example.nexa"
export NEXA_WATCH_APP_GROUP="group.dev.example.nexa.watch"
export NEXA_BUILD_DIR="$HOME/NexaBuilds/0.0.1-$(date +%Y%m%d%H%M%S)"
bash Scripts/archive_signed_ipa.sh
```

The script checks identifiers, archives the iPhone + embedded Watch targets with the chosen development team, verifies the Watch app is present, exports an Xcode `debugging` IPA and checks the IPA contains `Payload/Nexa.app/Watch/NexaWatch.app`. It **fails closed** if signing, provisioning, archiving or export fails. Use a fresh output directory each time.

The local private build directory contains the signed IPA and Xcode archive. Neither signing certificates nor App Store Connect API keys are required in this repository. Do not upload signing secrets or personal provisioning material to public GitHub Actions.

## Required real-device acceptance

1. Install the resulting IPA onto a provisioned iPhone on a specifically supported iOS 26/27 build and pair an eligible Apple Watch on the matching supported watchOS build.
2. Confirm both App Groups are present in the actual signed entitlements. Do not rely on `Info.plist` alone.
3. Verify iPhone + Watch WatchConnectivity responses, installed watch app and language switching.
4. Test file import, backup/hash tamper rejection, local migration, plist version undo, crash recovery and low-space errors using disposable data.
5. For WQFiles, verify the pinned upstream sandbox lease and cache recovery on the actual build, with data you own or are explicitly authorized to access.
6. For GestaltX and Hermes system writes, first verify an original backup, supported build/hardware, state changes and a successful rollback on test devices. Do not use personal production data for initial tests.

**Do not release the IPA as a fully functional or safe system modification product before these tests pass.** A simulator CI success and a signed archive alone are not a substitute for the real-device results.

Apple documentation: https://help.apple.com/xcode/mac/current/en.lproj/deva1f2ab5a2.html and https://developer.apple.com/videos/play/wwdc2021/10204/
