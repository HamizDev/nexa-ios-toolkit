# Nexa

**Explore Beyond Limits.**  
**Nexa 0.0.1 — iOS 26+ · SwiftUI · 简体中文 / English**

Nexa 是一个面向 iOS 文件、备份、设备诊断和开源系统研究的原生工具箱。0.0.1 带来深色渐变工作台、中文默认界面和可切换的英文、可验证的个人文件备份，以及对上游项目能力的透明标注。

> [!IMPORTANT]
> 这是一份 **0.0.1 开发预览版源码**，不是四个上游工具所有功能齐全的 IPA。macOS GitHub Actions 已通过 iPhone 和 Watch 模拟器编译及离线测试，但尚未经过开发者签名和实体设备验收，不能作为正式 Release。

## ✨ 0.0.1 已实现 / Implemented

| 模块 | 当前实际能力 |
| --- | --- |
| UI | 全新深色玻璃质感主页、模块卡片、设备概览、五栏导航，适配 SwiftUI |
| 中文 / English | 默认简体中文；设置中可立即切换英文；内置两套完整界面词条 |
| 文件 / Files | 文件选择器导入、嵌套文件夹浏览、**新建文件夹、搜索、重命名、复制副本、跨导入文件夹移动、恢复误删文件**、分享；调用原版 WQFiles ZIP 引擎压缩／解压；可手动检查导入的微信账号身份（WCMigrate 原版解析器） |
| 文件检查器 | UTF-8 文本预览、只读十六进制预览和字节验证；**直接编译并调用 WQFiles 原始的 `WQCore.m/h`** |
| 备份 / Backups | 创建和导入／导出便携备份 ZIP；v2 SHA-256 清单校验文件与空文件夹（兼容旧 v1）；**恢复到 Nexa 导入文件区（保留旧数据并记录中断恢复日志）**；重启后可以查看／打包恢复前和异常回滚的数据（原始恢复副本不属于经清单校验的正式备份）；基于 WCMigrate 原始 SQLite 诊断代码检查已校验备份副本 |
| 设备 / Device | 公开 API 显示设备名称、系统、Build、地区、内存、存储；上游报告范围的保守提示 |
| Apple Watch | **真实 watchOS Target 已加入 Nexa 工程**，支持手机/手表双向连接检测；**已链接 HermesEnabler 上游原版 Watch 功能源码**，但需要实际 Watch App Group 签名与特定 watchOS 版本，系统修改尚未经过真机验证 |
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
| [WQFiles](https://github.com/kolbicz/WQFiles) | ✅ **部分真实源码接入**：`WQCore.m/h` + Hex 校验，`WQArchive.m/h` + ZIP 压缩／解压；原版 WQAccess 授权引擎源码已链接，增加需用户明确同意的实验性只读容器入口；尚未通过真机验证，且没有跨容器写入 |
| [WQToolkit](https://github.com/MchinaMd57764/WQToolkit) | 源码研究；上游公开说明功能面向自身容器 / App Group，需核对授权 |
| [GestaltX](https://github.com/huamidev/GestaltX) | ✅ **部分源码接入**：`VersionSupport.swift` 与 `PlistValueKind.swift`。可在 Nexa 内离线查看/编辑用户导入的 plist 副本，并在保存前自动备份；无系统 MobileGestalt 写入 |
| [WCMigrate](https://github.com/yangokok886/WCMigrate) | ✅ **部分真实源码接入**：`OperationEstimate.swift`、`BackupProgress.swift` 已用于 Nexa 本地备份进度；移植 `DatabaseInspector` 只读检查已校验数据库副本，并直接复用 `WeChatIdentityResolver` 解析用户导入的 LoginInfo2.dat；无微信跨容器迁移 |
| [Erosion](https://github.com/jailbreakdotparty/Erosion)、[Regitela](https://github.com/ichitaso/Regitela)、[WorstGestalt](https://github.com/GoldensHQ/worstgestalt)、[WorseFiles](https://github.com/fucknima/worsefiles-ios) | 已核对仓库和候选模块，未实际移植 |
| [HermesEnabler 2](https://github.com/pookjw/HermesEnabler) | 上游完整源码固定为子模块；**NexaWatch 是嵌入 Nexa iPhone App 的真实 watchOS Target**，支持双向 WatchConnectivity 测试，已在 Watch Target 中直接编译原版 HermesEnabler 2 引擎、功能面板与恢复组件。**表盘修改及系统缓存恢复尚未通过真机验收** |
| [worse_query](https://github.com/forcequitOS/worse_query) | 仅研究参考；**尚未集成漏洞利用代码或跨 App 沙盒授权** |

四个完整上游项目的源码已通过固定 Git submodule 引用纳入开发仓库，组成 [Nexa.xcworkspace](Nexa.xcworkspace/contents.xcworkspacedata) 的多个独立工程。**Workspace 中有完整源码 ≠ 这些功能已嵌入 Nexa 主程序。** 详细配置见 [上游整合工作区](Documentation/UPSTREAM_WORKSPACE.md)；源码出处、许可与 SHA 见 [上游代码清单](Documentation/UPSTREAM_SOURCES.md)，开发路线见 [整合计划](Documentation/INTEGRATION_PLAN.md)。

## 🛠️ 编译 / Build

需要 **macOS + 支持 iOS 26 SDK 的 Xcode**。

1. 使用 `git clone --recurse-submodules https://github.com/HamizDev/nexa-ios-toolkit.git` 获取代码，再打开 `Nexa.xcworkspace`（或仅打开 `Nexa.xcodeproj` 构建 Nexa 主 App）。
2. 选择 `Nexa` Target，在 Signing & Capabilities 中设置开发团队和**自己的** Bundle Identifier（默认仅为 `com.example.Nexa` 示例）。
3. 选择 iOS 26+ 的模拟器或已签名的受控测试设备，编译运行。
4. 主工程编译 `Vendor/WQFiles/WQCore.m`、`WQArchive.m`、`WQLocalization.m`（链接 zlib）、`Vendor/WCMigrate/*.swift`（链接 SQLite3）和 `Vendor/GestaltX/*.swift`。原始上游工程在 Workspace 中仍为**独立 Target**，不能直接用一个 Nexa IPA 安装全部上游应用。

**目前未生成 IPA，也没有 Xcode 真机编译验收结果。** 编译成功不意味着 worse_query 在该设备可用。

## 🔐 隐私与风险 / Safety

- 默认不收集个人信息，没有联网上传或分析服务。
- 复制导入数据而非直接修改外部文件；备份含 SHA-256 校验清单。
- 系统修改、地区及型号伪装、聊天记录迁移、爱马仕表盘修改均不是 0.0.1 的可执行功能。
- 对未来高风险操作应先进行签名、版本、备份、差异预览和失败恢复验证。

## 📄 开源许可 / Licensing

Nexa 源代码以 [GPL-3.0](LICENSE) 提供；直接编译的 WQFiles/WCMigrate/GestaltX 来源文件分别保留 GPL-3.0-or-later / GPL-3.0-only 的版权许可说明，原始完整仓库在 `ThirdParty/` 下以子模块固定 SHA 引用。HermesEnabler 原项目采用 MIT 许可证，其 Watch 功能源码已在 NexaWatch Target 中直接编译，尚未通过真机验收。具体文件与许可见 [上游清单](Documentation/UPSTREAM_SOURCES.md)。未经授权不要复制 Apple、Hermès 或第三方 App 的受保护素材或数据。

[Changelog](CHANGELOG.md) · [Source inventory](Documentation/UPSTREAM_SOURCES.md) · [Integration plan](Documentation/INTEGRATION_PLAN.md)

---

**Nexa 0.0.1 — Explore Beyond Limits.**

## ⚠️ 跨容器实验性入口 / Advanced access

Nexa 的开发分支已链接 WQFiles 原版 `WQAccess.m` / `WQLaunchServices.m` / `WQScanTask.m`，并在文件页提供**用户明确选择目录、只读浏览**的入口。该功能只有在设备系统构建号处于上游报告的区间、应用签名含有效 App Group，且用户确认有权访问数据时才会尝试使用。

必须先在 Xcode Signing & Capabilities 中把示例 Bundle ID `com.example.Nexa` 和 `NEXA_APP_GROUP_IDENTIFIER=group.com.example.Nexa` 改为本人实际签名的标识。模拟器、漏洞已报告修复的系统以及未签入有效 App Group 的 App 都会拒绝使用。**这只是带保护的候选集成，尚未通过真机授权测试，不应宣称已可浏览其他 App。** 更多见 [WQFiles 容器后端说明](Documentation/WQFILES_CONTAINER_BACKEND.md)。

## 🧰 Nexa 本地恢复与数据安全（开发分支）

每个本地备份恢复操作必须先通过 SHA-256 校验、再次验证暂存副本，并由用户确认。恢复之前，原 Nexa 导入文件夹会移动至 `Application Support/Nexa/RestoreSafety/`，不会直接删除。异常中断会留下日志，后续启动会尝试安全恢复；若原文件和安全快照均缺失，将报告错误，而不是静默清空。此功能**仅恢复 Nexa 的已导入文件**，不是 WCMigrate 的微信迁移或其他 App 沙盒迁移。详见 [恢复安全说明](Documentation/RESTORE_SAFETY.md)。

## GestaltX 只读系统库诊断（开发分支）

设备信息页新增“检查已加载的 MobileGestalt 系统库”，直接编译和调用固定版本 GestaltX 上游的 `GXMobileGestaltImage.m/h`。只显示从当前进程读取到的系统库字符串段/常量段大小，不显示原始字节或序列化系统数据；不会修改系统缓存、启动越狱服务或获取跨应用权限。模拟器等不可用环境会显示“快照不可用”。这不是 MobileGestalt 更改或启用设备功能。

## Nexa 本地文件管理（开发分支）

在 **Nexa 自身的已导入文件区**，可以创建文件夹、重命名、复制文件或文件夹、将项目移动到其他已导入文件夹、浏览子文件夹、搜索当前层级，并将文件移入可恢复的私有回收站。重命名和恢复不会覆盖同名文件；复制和删除会拒绝符号链接及不安全的目录结构；移动操作拒绝将文件夹移动到其自身子目录。回收站保留在应用的 Application Support 文件夹内，也会随卸载 Nexa 一起删除。

这些功能**不是跨 App 系统文件管理**，不需要利用漏洞，也不能绕过 iOS 其他 App 的沙盒权限。详见 [本地文件操作安全设计](Documentation/LOCAL_FILE_MANAGEMENT.md)。

此外，导入时会检查源文件树中的符号链接，避免把不安全的链接复制到 Nexa 的工作区；“移动到文件夹”只列出应用自己导入区中符合条件的目标目录，不会覆盖同名文件或允许将文件夹移动进其子目录。

## GitHub Actions 模拟器预览包（非 IPA）

开发分支的 GitHub Actions 构建成功后，会将 **Nexa iPhone App（内含 NexaWatch）** 打包为 `Nexa-0.0.1-simulator-<run-id>` 工件，保留 7 天。可进入对应构建记录的 Artifacts 下载 ZIP，并在具备 iOS 26+ 模拟器的 macOS Xcode 上测试：

```sh
unzip Nexa-simulator-0.0.1.zip
xcrun simctl boot 'iPhone 17 Pro'  # 或改为本机已安装的 iOS 26+ 模拟器
xcrun simctl install booted Nexa.app
xcrun simctl launch booted com.example.Nexa
```

该压缩包**只针对模拟器**，并非已签名 IPA，不能直接安装到实体 iPhone 或 Apple Watch；高级漏洞权限在模拟器上禁用。正式可安装 IPA 需要符合签名能力的 Apple 开发者证书、App Group 和真机测试，不能由无签名的模拟器产物代替。

## HermesEnabler Watch 实验性集成

NexaWatch 直接引用固定版本的 HermesEnabler 2 原始 `BQCore.m/h`、各功能面板、恢复验证头文件与配置资源，且新增 **82 条中文／英文界面字符串**。仅在真实 Apple Watch、受支持的 watchOS 27.0～27.2、有效签名 App Group 且用户确认操作风险时，才开放实验功能入口。该范围比上游公布的部分 Beta 范围更保守。**这不是已验证安全的 Watch 系统修改应用；模拟器禁用系统写入，真实设备仍需完成原始配置备份、恢复及表盘变化测试。** 配置见 [NexaWatch 说明](NexaWatch/README.md)。

## 本地迁移工作台（WCMigrate 思路，源码已接入）

新版“备份”页添加 **本地数据迁移**：在用户事先导入 Nexa 的文件夹之间选择来源与目标，预检文件数量和 SHA-256 摘要，然后先复制至专用暂存目录，核对每个文件，最后用独立名称提交到目标文件夹。原始数据不会被删除、覆盖或自动修改。迁移记录存储于 Nexa 私有 Application Support；因进程中断而留下的记录可在再次打开页面时检查并标记为完成或失败。

这项功能是 **Nexa 自己实现的授权导入文件迁移**，借鉴 WCMigrate 的保留源文件、暂存和持久记录设计；与已接入的 WCMigrate 原版进度估算、SQLite 检查和账号识别代码配套。**它不是 WCMigrate 原版跨应用迁移引擎，不包含微信数据合并，也不能向微信的私有容器直接写入。** 详情见 [安全与恢复说明](Documentation/LOCAL_MIGRATION.md)。

## GestaltX plist 历史版本与恢复（已实现源码）

Nexa 的离线 plist 编辑器现在支持**版本历史、原文件恢复、SHA-256 完整性校验与导出旧版本**。每次修改前都会将当前已导入的 plist 写入私有历史仓库；恢复历史版本之前同样会先保留当前文件，允许撤销恢复。若文件在打开后被其他操作修改，编辑器会拒绝覆盖并要求重新加载。历史版本只对应 Nexa 导入区内的副本，**不能修改设备系统 MobileGestalt**。

## WQFiles 已授权文件导入（实验性）

在“文件 → 实验性容器浏览”中，用户明确选择可读的单个文件后，可以将它**流式复制到 Nexa 自己的 Imports**。该功能直接调用上游原版 `wq_copy_to_local`，并在复制前后检查 `wq_file_version`，若来源发生变化则丢弃本地副本。新文件始终使用随机化且经过清理的文件名，不覆盖已有文件，也不修改来源 App 容器。

**前提是**已取得目标文件的合法访问授权、符合上游报告范围的特定系统构建号，并正确签名 App Group。模拟器及无权限设备无法使用；没有任何真机权限测试可以由模拟器构建结果替代。访问其他人的应用数据须征得授权。

## 交互与前端验收

Nexa 0.0.1 的基础深色 SwiftUI 设计已继续优化：卡片描边与透明度对比度提高，标题采用支持动态字体的系统字号，减少透明度的辅助功能设置会使用更实的卡片背景。探索模块详情现在直接通往已编译的文件工作台、备份、本地迁移、设备诊断或 Watch 状态页，不再仅有上游 GitHub 链接；研究中/未移植组件仍不会显示虚假的操作按钮。

在 CI 运行器具备 **iOS 26+ 模拟器运行时**时，GitHub Actions 会依次启动首页、文件、备份、探索、设置 5 个页面，保存 `Nexa-0.0.1-ui-screens-<run-id>` 截图工件，保留七天。运行时缺失会使 UI 验收失败；首次启动与五页验证分为独立步骤。2026-11-22 的 [CI 45012726433](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45012726433) 已通过五页验证，截图也经过人工检查。所有页面还需要检查不同尺寸、动态字体、辅助功能及真机状态栏/手势。

## 真机签名与 IPA 导出（需要开发者账户）

仓库新增 `Scripts/archive_signed_ipa.sh`，可以在你自己已配置 Apple Developer 签名的 Mac 上，使用实际 Team ID、iPhone/Watch Bundle ID 和 App Group 编译 Nexa + NexaWatch，并通过 Xcode 导出 **调试分发方式的签名 IPA**。脚本会检查两个 App 是否被签名、Watch App 是否嵌入和 IPA 是否真正生成；不会上传证书、私钥或自动发布 Release。

具体参数及真机验收清单见 [Documentation/SIGNING.md](Documentation/SIGNING.md)。**目前还没有用你的证书执行过签名，更没有经过真机功能验收**；仅添加归档脚本不代表 IPA 已经制作成功。

## Release status

当前仍处于 **0.0.1 开发预览**：五个主页面已在 iOS 模拟器中逐页启动并截图，已有便携 ZIP 备份、恢复副本导出、文件管理、本地迁移和离线 plist 历史等可操作功能；但四个上游 App 的私有系统能力**尚未全部实现或完成真机验证**。详细缺口、验收条件和当前交付范围见 [0.0.1 发布准备清单](Documentation/RELEASE_READINESS.md)。

### UI 截图校验修复

2026-11-18 对旧 CI 工件的实际截图审查发现：此前生成的 `home/files/backups/explore/settings` 五张 PNG **全部停留在首页**，不能作为五页视觉验收。原因是自定义 Xcode Target 的 Debug 构建未设置 `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`，导致用于测试的 `--nexa-tab` 参数处理被编译排除。新 CI 已为 Debug 配置显式定义 `DEBUG`，且应用会向测试沙盒写入当前选中页面的标记；截屏前必须读取该标记并与目标页面一致，否则该检查失败。2026-11-22 已重新核对 [45012726433](https://github.com/HamizDev/nexa-ios-toolkit/actions/runs/45012726433) 的五张实际截图：分别为首页、文件、备份、探索与设置，不再重复首页。无障碍、不同屏幕尺寸及真机交互仍需单独验收。

## ⚠️ 免责声明与上游风险（0.0.1）

首次正常启动 Nexa 会显示**中英文免责声明**，需要用户确认已阅读风险后方可进入；之后可以在“设置 → 免责声明与上游风险”重新查看。每个已接入模块详情提供该上游具体风险说明、对应源码链接，以及 Nexa 当前**实际接入且已验证的功能范围**；实验性 WQFiles 浏览页和 NexaWatch 手表操作入口也会明确显示操作风险。免责声明不替代原始数据备份、权限检查及可验证的恢复机制，也不要求用户放弃法律权利。

**特别注意：** WQFiles 的跨容器功能在上游声明的修复版本中不可用；WCMigrate 的替换和文件级合并可能覆盖数据，并不提供 SQLite 聊天记录行级合并或整任务回滚；HermesEnabler 上游要求在卸载前先恢复 MobileGestalt 备份，并保持固定签名身份；GestaltX 的系统写入在 Nexa 中尚未实现。具体风险、来源和未移植功能见 [上游风险与功能状态清单](Documentation/UPSTREAM_RISKS.md)。

## 已导入数据的文件级合并／替换（新增候选功能）

在“备份 → 本地数据迁移 → 文件级合并／替换”中，可选择两个 **已经导入 Nexa 的独立文件夹**。合并结果保留目标独有文件，同名文件选择来源版本；替换结果只保留来源文件。两种模式**都只生成新结果文件夹，绝不会删除或覆盖来源、目标原件**。

执行前比较文件数和 SHA-256，复制到私有暂存目录后再次核对来源与目标，并逐文件验证新结果。会记录历史，进程中断后重新检查提交结果。阻止目录嵌套、符号链接、文件与目录同路径冲突、过期预览。功能只处理 Nexa 的 **本地导入副本**，不执行微信私有容器迁移，也不代表已移植 WCMigrate 上游的 `DirectMigrationService`。不提供聊天数据库逐条记录合并或系统级回滚。
