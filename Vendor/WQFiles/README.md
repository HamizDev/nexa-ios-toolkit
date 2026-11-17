# Vendored source: WQFiles WQCore

- Upstream: https://github.com/kolbicz/WQFiles
- Pinned upstream tree: `fe92ae94067983b94fd927e0b4eee52e5a99a4e7` (main, reviewed 2026-11-17)
- Source paths: `WQCore.h`, `WQCore.m`
- Copyright: retained upstream notices in both source files
- License: **GPL-3.0-or-later**; see the project's GPL-3.0 LICENSE and [upstream LICENSE](https://github.com/kolbicz/WQFiles/blob/main/LICENSE)

These are **copied upstream source files**, not placeholders. Nexa compiles `WQCore.m` and exposes the declarations through `Nexa/Nexa-Bridging-Header.h`.

**Currently used function:** `WQParseHexExactly` in Nexa's read-only hex file inspector, for files explicitly imported by the user. Other WQCore symbols are retained unmodified but not yet used. This is **not** the full WQFiles application, cross-app access engine, App Group capability, or container manager exploit.
