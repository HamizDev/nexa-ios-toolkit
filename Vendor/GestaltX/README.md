# GestaltX embedded component

Source: [GestaltX](https://github.com/huamidev/GestaltX), pinned `311f78999d9f5f062f7e3b4c6374684782be5382` (GPL-3.0-only).

`VersionSupport.swift` is an adapted copy of the upstream helper. Only the `L()` localization dependency was removed. The file is compiled into Nexa for **read-only capability gating** on the device page.

This does **not** install GestaltX's MobileGestalt file access, patching, presets, backups, entitlement configuration or system writes. The full upstream Xcode project is present separately under `ThirdParty/GestaltX`.

- `PlistValueKind.swift` is a verbatim type parser excerpt from the pinned upstream `GestaltDocument.swift` (GPL-3.0-only). It provides read-only type recognition and type-checked edits on **locally imported** plist copies. Nexa makes a backup before any change; this is not a device MobileGestalt modification.
