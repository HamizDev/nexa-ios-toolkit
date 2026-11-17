# NexaWatch — 0.0.1 upstream Hermes integration (experimental)

NexaWatch is a genuine embedded watchOS app target. This development branch now additionally references **the original pinned HermesEnabler 2 watchOS functionality**, not only the old WatchConnectivity status shell.

- Upstream: https://github.com/pookjw/HermesEnabler (MIT license), commit `c0ae1666cba67ab7fbae6d3e481cc2731f5550a1`.
- Directly compiled source refs from `ThirdParty/HermesEnabler/HermesEnabler2/`: original `BQCore.m`, all original feature views, `ContentModel.swift`, WatchConnectivity manager, MG Defaults/Offsets plist resources. The original `@main` app entry is **excluded** to avoid a duplicate process entry point.
- Swift bridge: `NexaWatch/NexaWatch-Bridging-Header.h`.
- Watch App Group entitlement: `NexaWatch/NexaWatch.entitlements`, ID resolved from `NEXA_WATCH_APP_GROUP_IDENTIFIER`. **The example ID must be replaced with one actually provisioned for the watchOS app**.
- NexaWatch dashboard: Chinese default / English switching, two-way ping, and an additional consent-gated entry to upstream Hermes UI.
- Eligibility is deliberately narrower than the upstream README: **watchOS 27.0–27.2 only**, unavailable on simulators and on unprovisioned watch builds. Other builds remain disabled until tested.
- The original Hermes UI remains English in some screens. Full bilingual localization is **unfinished**.
- The original engine can modify watch system configuration. Its own backup and recovery logic must be tested thoroughly on a physical Watch before any distribution. Compiling its source alone does not verify a safe or supported exploit.

**Not yet validated:** paired iPhone/Watch signing, MobileGestalt read/write and rollback, original Hermes view navigation, actual face capabilities, restart behavior, and physical watchOS runs. No signed IPA is published.

The separate upstream source/License remains in the pinned Git submodule and must remain attributed on distribution.
