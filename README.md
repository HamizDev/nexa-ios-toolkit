# Nexa

**Explore Beyond Limits.**

> 中文优先 · SwiftUI · 模块化 iOS 工具箱

Nexa 是一个开源的 iOS 探索与设备管理项目，目标是将文件管理、个人数据备份、设备诊断与实验性系统定制统一到清晰、可扩展的界面中。

**English:** Nexa is an open-source, modular iOS exploration toolkit built with SwiftUI. It focuses on user-controlled file management, verifiable backups, device diagnostics, and carefully scoped customization research.

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-informational) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue) ![Status](https://img.shields.io/badge/status-early%20development-orange)

## ✨ 当前已实现 · Implemented

- **中文 SwiftUI 界面**：首页、文件、备份、设备、手表五个页面。
- **我的文件**：通过系统文件选择器导入用户主动选择的文件／文件夹，可分享或删除应用内副本。
- **备份与校验**：对已导入的文件创建本地备份、生成 SHA-256 清单并核验完整性。
- **设备信息**：读取公开的系统、设备及地区信息。
- **模块目录**：展示候选上游项目与接入状态，方便后续分模块开发。

## 🧩 规划模块 · Roadmap

| 方向 | 参考项目 | 当前状态 |
| --- | --- | --- |
| 文件与容器管理 | [WQFiles](https://github.com/kolbicz/WQFiles)、[WorseFiles](https://github.com/fucknima/worsefiles-ios) | 仅用户主动导入的文件 |
| 系统维护 | [WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | 接口规划 |
| MobileGestalt 研究 | [GestaltX](https://github.com/huamidev/GestaltX)、[WorstGestalt](https://github.com/GoldensHQ/worstgestalt) | 未接入系统写入 |
| 数据备份与迁移 | [WCMigrate](https://github.com/yangokok886/WCMigrate) | 仅普通文件备份；未读取微信数据 |
| 系统外观与配置 | [Erosion](https://github.com/jailbreakdotparty/Erosion)、[Regitela](https://github.com/ichitaso/Regitela) | 研究候选 |
| Apple Watch | [HermesEnabler](https://github.com/pookjw/HermesEnabler) | 尚无 watchOS App target |
| iOS 安全研究 | [worse_query](https://github.com/forcequitOS/worse_query) | 未集成漏洞利用代码 |

> **项目状态：Alpha / 基础工程。** 上表所列项目是研究与集成候选，**并不表示这些项目的代码或完整功能已经移植到 Nexa**。当前没有跨 App 容器读取、微信聊天数据库迁移、MobileGestalt 写入、Apple Watch 表盘解锁或已签名的 IPA。

## 📱 iOS 版本兼容性 · Compatibility

Apple 在 iOS 18 之后直接采用了 **iOS 26** 的命名。**iOS 19–25（包括 iOS 25）并不是正式发布过的系统版本**，不应出现在兼容性区间中。

> **更新时间：2026-11-17。** 本表描述的是 **worse_query 及其第三方衍生工具公开报告的兼容范围**，不是 Nexa 已实现或已在真机验证的功能。实际可用性还取决于 iOS 构建号、应用签名、权限、硬件和具体模块。

| iOS / iPadOS | worse_query 相关能力 | 证据与说明 |
| --- | --- | --- |
| iOS 18 及更早版本 | **不在 Nexa 的目标支持范围** | 系统文件选择器不等于跨 App 容器访问；worse_query 不支持这些旧版系统 |
| 26.0–26.7.2 | 原作者声明的支持区间 | **部分功能受限**；某些 MobileGestalt 写入在 iOS 26 不可用 |
| 26.7.3 及之后的 26.x | 未经确认 | 不能直接按 26.7.2 的结果推断 |
| 27.0–27.2 | 公开衍生项目声明支持 | worse_query 原作者明确列出 27.2；不同设备/构建仍需验证 |
| 27.2.1 | 第三方工具实测支持 | WQFiles 维护者公布了测试设备，Erosion 也列入支持范围 |
| 27.3 Beta 1（24C5037i） | 第三方工具报告支持 | 不能等同于 Apple 官方确认 |
| 27.3 Beta 2（24C5049d）及之后 | 第三方维护者报告漏洞已修复 | 不应把依赖此漏洞的模块标为可用；未来是否存在新方法需重新评估 |

**区分两个版本概念：**

- **Nexa App 最低部署版本：iOS 26.0。** 这是为了与 worse_query 原作者公布的最低支持版本对齐，而不是因为系统文件选择器必须从 iOS 26 才能使用。基础文件导入、SHA-256 校验和设备诊断仍然采用公开 API，**不需要漏洞、巨魔或越狱**。
- **未来的 worse_query 实验性模块：仅能考虑已验证的系统与构建号。** 即使漏洞在某个版本可用，也不意味着 MobileGestalt、微信数据迁移或手表功能自动可用；这些功能目前**没有集成或真机验证**。
- **不要仅靠系统主版本号启用写入。** 应按具体构建号与模块能力进行检查，未验证时保持只读/禁用状态，并提供备份及恢复方案。

**上游证据：** [原始 worse_query README](https://github.com/forcequitOS/worse_query#readme) · [WQFiles 测试设备及修复说明](https://github.com/kolbicz/WQFiles#readme) · [Erosion 支持范围与限制](https://github.com/jailbreakdotparty/Erosion#readme)。上述为各维护者公开说明，不是 Apple 的官方漏洞公告。

详见 [兼容性与测试策略](Documentation/INTEGRATION_PLAN.md)。

## 🛠️ 构建 · Build

1. 使用 macOS 上的 Xcode 打开 `Nexa.xcodeproj`。
2. 在 Nexa Target 的 **Signing & Capabilities** 中选择自己的开发团队，并将示例 Bundle Identifier 修改为唯一值。
3. 选择 iPhone 模拟器或自己的测试设备，运行 **Build / Run**。

项目最低部署版本为 **iOS 26.0**；该设置仅控制安装所需的最低系统版本，**不保证所有 iOS 26/27 构建均可使用 worse_query**。跨 App 容器访问不是普通文件选择器的功能，也尚未在 Nexa 中集成。实际 SDK、签名与兼容性需以你的 Xcode 和设备为准。**当前尚未完成真实 Xcode 编译和真机测试**，可能需要适配。

## 🔐 安全与隐私 · Safety & Privacy

- 默认只处理用户主动导入的文件，不会自动收集、上传聊天记录或读取其他应用容器。
- 涉及系统配置的未来功能需要版本检查、备份、风险提示与回滚设计。
- 不建议在主力设备上测试尚未验证的系统修改；请提前完成完整备份。
- 本项目仅用于合法授权的安全研究和个人设备管理，不隶属于 Apple、微信或任何上游项目。

## 📚 文档与贡献

- [整合计划](Documentation/INTEGRATION_PLAN.md)
- [上游项目与许可证说明](IntegrationSources/README.md)
- 欢迎提交 Issues 和 Pull Requests；请说明系统版本、复现过程，以及是否可在公开测试数据上复现。

## 📄 License / Third-party credits

当前 Nexa 原型由独立代码组成，不包含上述第三方工具的实现。仓库当前采用 **GPL-3.0** 许可证（见 `LICENSE`）。后续引入上游代码时会保留版权声明、履行相应许可证义务，并逐一审查兼容性。上游仓库名称和链接仅用于署名及研究参考。

---

**Nexa — Explore Beyond Limits.**
