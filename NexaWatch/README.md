# Nexa Watch companion (0.0.1)

This is a **real watchOS application target** embedded into Nexa's iPhone app, using public WatchConnectivity APIs for bidirectional connectivity diagnostics.

- Default language: Simplified Chinese; an independent English option is provided on the watch.
- Minimum watchOS: 26.0 (watchOS 27+ is required by the pinned HermesEnabler upstream for its **face modification engine**; no such code is built into this target).
- No Hermes face modifications, private Watch frameworks, boot changes or system writes are enabled.
- Source of the watch architecture: [HermesEnabler 2](https://github.com/pookjw/HermesEnabler), MIT-licensed and preserved in `ThirdParty/HermesEnabler`. This target does **not** claim to embed its unpublished or untested privileged routines.
- Testing: build both app targets on macOS Xcode and run on a **paired iPhone + Apple Watch** under a provisioned Apple developer team. Simulator compilation alone does not prove WatchConnectivity reachability.

Bundle IDs are derived from the shared `NEXA_COMPANION_BUNDLE_IDENTIFIER` build setting. Use your own unique identifier and signing team.
