# Nexa

**Explore Beyond Limits.**

> 中文优先 · SwiftUI · 模块化 iOS 工具箱

Nexa 是一个开源的 iOS 探索与设备管理项目，目标是将文件管理、个人数据备份、设备诊断与实验性系统定制统一到清晰、可扩展的界面中。

**English:** Nexa is an open-source, modular iOS exploration toolkit built with SwiftUI. It focuses on user-controlled file management, verifiable backups, device diagnostics, and carefully scoped customization research.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-informational) ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue) ![Status](https://img.shields.io/badge/status-early%20development-orange)

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

## 🛠️ 构建 · Build

1. 使用 macOS 上的 Xcode 打开 `Nexa.xcodeproj`。
2. 在 Nexa Target 的 **Signing & Capabilities** 中选择自己的开发团队，并将示例 Bundle Identifier 修改为唯一值。
3. 选择 iPhone 模拟器或自己的测试设备，运行 **Build / Run**。

项目目标部署版本为 iOS 17 或更新版本；实际 SDK、签名与兼容性需以你的 Xcode 和设备为准。**当前尚未完成真实 Xcode 编译和真机测试**，可能需要适配。

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
