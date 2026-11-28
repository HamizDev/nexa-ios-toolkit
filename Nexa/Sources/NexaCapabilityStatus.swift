import Foundation

// Pure presentation model; a reported capability is never an authorization.
enum NexaRisk: String, CaseIterable {
    case readOnly, localChanges, researchOnly

    func title(_ language: String) -> String {
        switch (self, language == "en") {
        case (.readOnly, true): return "Read-only diagnostics"
        case (.readOnly, false): return "只读诊断"
        case (.localChanges, true): return "Local data changes"
        case (.localChanges, false): return "本地数据操作"
        case (.researchOnly, true): return "Reference only"
        case (.researchOnly, false): return "仅研究参考"
        }
    }

    func detail(_ language: String) -> String {
        switch (self, language == "en") {
        case (.readOnly, true): return "Reads public diagnostic information. Does not change the device or watch."
        case (.readOnly, false): return "读取公开诊断信息，不修改设备或手表。"
        case (.localChanges, true): return "Works on local copies only. Edits, deletion and sharing can still cause data loss or exposure."
        case (.localChanges, false): return "仅处理本地副本。编辑、删除或分享仍可能造成数据丢失或泄露。"
        case (.researchOnly, true): return "No executable upstream feature is integrated. Source links do not imply access or compatibility."
        case (.researchOnly, false): return "尚未接入可执行的上游功能。源码链接不代表具有访问权限或系统兼容性。"
        }
    }
}

enum NexaWatchActivation: String, Equatable {
    case unavailable, notActivated, inactive, activated, unknown

    func title(_ language: String) -> String {
        let en = language == "en"
        switch self {
        case .unavailable: return en ? "Unsupported" : "不支持"
        case .notActivated: return en ? "Not activated" : "尚未激活"
        case .inactive: return en ? "Inactive" : "非活动状态"
        case .activated: return en ? "Activated" : "已激活"
        case .unknown: return en ? "Unknown" : "未知"
        }
    }
}

struct NexaWatchStatus: Equatable {
    enum Connection: Equatable {
        case unavailable, waiting, failed, unpaired, companionMissing, notReachable, reachable

        func title(_ language: String) -> String {
            let en = language == "en"
            switch self {
            case .unavailable: return en ? "WatchConnectivity unavailable" : "当前设备不支持 WatchConnectivity"
            case .waiting: return en ? "Waiting for session activation" : "等待会话激活"
            case .failed: return en ? "Session activation failed" : "会话激活失败"
            case .unpaired: return en ? "No paired Apple Watch" : "没有已配对的 Apple Watch"
            case .companionMissing: return en ? "Companion app not installed" : "未安装配套 App"
            case .notReachable: return en ? "Companion not reachable now" : "配套 App 当前不可达"
            case .reachable: return en ? "Companion reachable" : "配套 App 当前可达"
            }
        }
    }

    let activation: NexaWatchActivation
    let paired: Bool?
    let installed: Bool?
    let reachable: Bool?
    let activationFailed: Bool

    init(activation: NexaWatchActivation, paired: Bool = false, installed: Bool = false,
         reachable: Bool = false, activationFailed: Bool = false) {
        self.activation = activation
        self.activationFailed = activationFailed
        // Values on a non-activated WCSession are not reliable diagnostic evidence.
        self.paired = activation == .activated ? paired : nil
        self.installed = activation == .activated && paired ? installed : nil
        self.reachable = activation == .activated && paired && installed ? reachable : nil
    }

    var connection: Connection {
        if activation == .unavailable { return .unavailable }
        if activation != .activated { return activationFailed ? .failed : .waiting }
        if paired != true { return .unpaired }
        if installed != true { return .companionMissing }
        return reachable == true ? .reachable : .notReachable
    }
}
