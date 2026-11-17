# Nexa upstream source inventory · 2026-11-17

This file distinguishes **vendored, compiled, and used code** from projects that are only research references. A GitHub link or an inactive feature card does **not** count as integration.

## Compiled upstream sources

| Project | Pinned upstream SHA | Files copied | License | Runtime usage |
| --- | --- | --- | --- | --- |
| [kolbicz/WQFiles](https://github.com/kolbicz/WQFiles) | `fe92ae94067983b94fd927e0b4eee52e5a99a4e7` | `WQCore.h`, `WQCore.m` → `Vendor/WQFiles/` | GPL-3.0-or-later | `WQParseHexExactly` in file inspector |

The copied WQCore files are unchanged upstream source; attribution and license headers are preserved. `Nexa/Nexa-Bridging-Header.h` and Xcode project compilation/linking settings are Nexa glue code. **No WQFiles container-access implementation is included.**

## Reviewed, not integrated

| Upstream | Latest inspected main SHA | Integration status |
| --- | --- | --- |
| [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) | `d1540e20cd82b974d891e0551ced6d6aeb570ac2` | Reference only |
| [yangokok886/WCMigrate](https://github.com/yangokok886/WCMigrate) | `55faba721fd44e04c65be481860c9d93e12f6f61` | Reference only; project already vendors selected WQFiles code |
| [MchinaMd57764/WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | `a5969d624e62c42803f1ef2973e5fd99405b0150` | Reference only; explicit repository LICENSE not found, review needed |
| [huamidev/GestaltX](https://github.com/huamidev/GestaltX) | `311f78999d9f5f062f7e3b4c6374684782be5382` | Reference only |
| [pookjw/HermesEnabler](https://github.com/pookjw/HermesEnabler) | `c0ae1666cba67ab7fbae6d3e481cc2731f5550a1` | Reference only; independent watchOS target required |
| [jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion) | `2e118f4e575b2cb745d9462ac445f023e09ec4da` | Reference only |
| [ichitaso/Regitela](https://github.com/ichitaso/Regitela) | `e1ed6597816e8ce30457607239a2216345cfd8a1` | Reference only |
| [GoldensHQ/worstgestalt](https://github.com/GoldensHQ/worstgestalt) | `1839f044e807ea203d7a1131ca16a38f123fd557` | Reference only |
| [fucknima/worsefiles-ios](https://github.com/fucknima/worsefiles-ios) | `fe10fc84137e522692ec685fb51c0cfa37378941` | Reference only |

No third-party IPA or binary has been copied into Nexa. Please examine each upstream's license and dependencies **before** copying any additional files. For reuse, retain original notices, modify with attribution, and document how code is actually invoked and tested.
