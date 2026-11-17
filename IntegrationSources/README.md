# Nexa integration sources

Nexa **0.0.1** vendors a narrowly scoped upstream component at:

- `../Vendor/WQFiles/WQCore.h` and `WQCore.m` — copied from [WQFiles](https://github.com/kolbicz/WQFiles), used for read-only hex validation.

All other upstream projects are **research references**, not integrated components. See [source inventory](../Documentation/UPSTREAM_SOURCES.md). Future modules must be audited, adapted to one signing and App Group model, and verified in Xcode on supported test devices before marking them available.

Never present a module launcher or GitHub source link as evidence that a tool's functionality is compiled into Nexa.
