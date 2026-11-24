# Nexa

**Explore Beyond Limits.**  
**Nexa 0.0.1 — iOS 26+ · SwiftUI · 简体中文 / English**

Nexa 是一个面向 iOS 文件、备份、设备诊断和开源系统研究的原生工具箱。0.0.1 带来深色渐变工作台、中文默认界面和可切换的英文、可验证的个人文件备份，以及对上游项目能力的透明标注。

> [!IMPORTANT]
> 这是一份 **0.0.1 开发预览版源码**，不是已经实现所有 worse_query 工具的完整 IPA。尚未在 macOS Xcode 或真机上完成编译验证，不应直接视为可安装的正式 Release。

## ✨ 0.0.1 已实现 / Implemented

| 模块 | 当前实际能力 |
| --- | --- |
| UI | 全新深色玻璃质感主页、模块卡片、设备概览、五栏导航，适配 SwiftUI |
| 中文 / English | 默认简体中文；设置中可立即切换英文；内置两套完整界面词条 |
| 文件 / Files | 系统文件选择器导入、应用内文件夹浏览、文件名搜索、名称／修改时间／大小排序、多选批量删除（确认后）、分享、归档历史；**调用原版 WQFiles ZIP 引擎创建／解压归档** |
| 文件检查器 | UTF-8 文本预览、只读十六进制预览和字节验证；**直接编译并调用 WQFiles 原始的 `WQCore.m/h`** |
| 备份 / Backups | 复制用户导入的文件、生成 `manifest.json`（v2 包含目录清单，兼容 v1）、逐文件 SHA-256 校验、分享备份、校验后恢复到独立目录（不覆盖原文件） |
| 设备 / Device | 公开 API 显示设备名称、系统、Build、地区、内存、存储；上游报告范围的保守提示 |
| Apple Watch | 显示公开的基础配对状态，提供上游源码入口；**没有 watchOS Target** |
| 上游项目 | 按“部分代码已接入 / 研究中 / 未移植”展示准确状态、来源与功能边界 |

仅对**用户明确导入**的文件操作。不会自动访问微信、其他 App 私有容器或系统配置缓存。

## 📱 系统版本 / Compatibility

- **Nexa 最低部署：iOS / iPadOS 26.0**。这是产品选择，普通文件选择器本身不需要漏洞，也不要求这个最低版本。
- **worse_query 原作者声明：** iOS 26.0–26.7.2 及 iOS 27.2。
- **WQFiles / Erosion 进一步报告：** iOS 27.0–27.2.1、27.3 Beta 1（24C5037i）可用。
- **WQFiles / Erosion 报告：** iOS 27.3 Beta 2（24C5049d）修复该漏洞，后续版本不应假设可用。
- **iOS 18 后直接采用 iOS 26 命名**，不存在正式发布的 iOS 19–25。

以上是**原项目公开声明或第三方维护者报告**，不是 Nexa 的运行时漏洞测试结论。iOS 26 的文件访问能力与 iOS 27 的系统修改能力不能混为一谈。更新系统前请优先考虑 Apple 的安全修复，不建议为了依赖旧漏洞而长期停留在过时系统。

## 🧩 上游整合状态 / Upstream integration

| 项目 | 0.0.1 实际状态 |
| --- | --- |
| [WQFiles](https://github.com/kolbicz/WQFiles) | ✅ **部分真实源码接入**：`WQCore.m/h` + Hex 校验，`WQArchive.m/h` + ZIP 压缩／解压；跨容器管理仍未集成 |
| [WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | 源码研究；上游公开说明功能面向自身容器 / App Group，需核对授权 |
| [GestaltX](https://github.com/huamidev/GestaltX) | ✅ **部分源码接入**：`VersionSupport.swift` 与 `PlistValueKind.swift`。可在 Nexa 内离线查看/编辑用户导入的 plist 副本，并提供逐文件版本历史及恢复（每次恢复前也保留当前版本）；无系统 MobileGestalt 写入 |
| [WCMigrate](https://github.com/yangokok886/WCMigrate) | ✅ **部分真实源码接入**：`OperationEstimate.swift`、`BackupProgress.swift` 已用于 Nexa 本地备份进度；无微信跨容器迁移 |
| [Erosion](https://github.com/jailbreakdotparty/Erosion)、[Regitela](https://github.com/ichitaso/Regitela)、[WorstGestalt](https://github.com/GoldensHQ/worstgestalt)、[WorseFiles](https://github.com/fucknima/worsefiles-ios) | 已核对仓库和候选模块，未实际移植 |
| [HermesEnabler 2](https://github.com/pookjw/HermesEnabler) | 上游完整源码固定为子模块；Nexa 已接入 Apple Watch 会话/配对状态诊断，仍无 Nexa watchOS Target 或表盘修改 |
| [worse_query](https://github.com/forcequitOS/worse_query) | 仅研究参考；**尚未集成漏洞利用代码或跨 App 沙盒授权** |

四个完整上游项目的源码已通过固定 Git submodule 引用纳入开发仓库，组成 [Nexa.xcworkspace](Nexa.xcworkspace/contents.xcworkspacedata) 的多个独立工程。**Workspace 中有完整源码 ≠ 这些功能已嵌入 Nexa 主程序。** 详细配置见 [上游整合工作区](Documentation/UPSTREAM_WORKSPACE.md)；源码出处、许可与 SHA 见 [上游代码清单](Documentation/UPSTREAM_SOURCES.md)，开发路线见 [整合计划](Documentation/INTEGRATION_PLAN.md)。

## 🛠️ 编译 / Build

需要 **macOS + 支持 iOS 26 SDK 的 Xcode**。

1. 使用 `git clone --recurse-submodules https://github.com/HamizDev/nexa-ios-toolkit.git` 获取代码，再打开 `Nexa.xcworkspace`（或仅打开 `Nexa.xcodeproj` 构建 Nexa 主 App）。
2. 选择 `Nexa` Target，在 Signing & Capabilities 中设置开发团队和**自己的** Bundle Identifier（默认仅为 `com.example.Nexa` 示例）。
3. 选择 iOS 26+ 的模拟器或已签名的受控测试设备，编译运行。
4. 主工程编译 `Vendor/WQFiles/WQCore.m`、`WQArchive.m`、`WQLocalization.m`（链接 zlib）、`Vendor/WCMigrate/*.swift` 和 `Vendor/GestaltX/*.swift`。原始上游工程在 Workspace 中仍为**独立 Target**，不能直接用一个 Nexa IPA 安装全部上游应用。

**目前未生成 IPA，也没有 Xcode 真机编译验收结果。** 编译成功不意味着 worse_query 在该设备可用。

## 🔐 隐私与风险 / Safety

- 默认不收集个人信息，没有联网上传或分析服务。
- 复制导入数据而非直接修改外部文件；备份含 SHA-256 校验清单。
- 系统修改、地区及型号伪装、聊天记录迁移、爱马仕表盘修改均不是 0.0.1 的可执行功能。
- 对未来高风险操作应先进行签名、版本、备份、差异预览和失败恢复验证。

## 📄 开源许可 / Licensing

Nexa 源代码以 [GPL-3.0](LICENSE) 提供；直接编译的 WQFiles/WCMigrate/GestaltX 来源文件分别保留 GPL-3.0-or-later / GPL-3.0-only 的版权许可说明，原始完整仓库在 `ThirdParty/` 下以子模块固定 SHA 引用。HermesEnabler 原项目采用 MIT 许可证，但其源码尚未作为 Nexa Watch Target 编译。具体文件与许可见 [上游清单](Documentation/UPSTREAM_SOURCES.md)。未经授权不要复制 Apple、Hermès 或第三方 App 的受保护素材或数据。

[Changelog](CHANGELOG.md) · [Source inventory](Documentation/UPSTREAM_SOURCES.md) · [Integration plan](Documentation/INTEGRATION_PLAN.md)

---

**Nexa 0.0.1 — Explore Beyond Limits.**
