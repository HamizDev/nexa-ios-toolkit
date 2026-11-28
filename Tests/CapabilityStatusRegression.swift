import Foundation

@main
enum CapabilityStatusRegression {
    static func main() {
        let unsupported = NexaWatchStatus(activation: .unavailable, paired: true, installed: true, reachable: true)
        precondition(unsupported.connection == .unavailable && unsupported.paired == nil && unsupported.reachable == nil)
        for phase in [NexaWatchActivation.notActivated, .inactive, .unknown] {
            let waiting = NexaWatchStatus(activation: phase, paired: true, installed: true, reachable: true)
            precondition(waiting.connection == .waiting && waiting.paired == nil && waiting.installed == nil && waiting.reachable == nil)
            let failed = NexaWatchStatus(activation: phase, activationFailed: true)
            precondition(failed.connection == .failed)
        }
        let noWatch = NexaWatchStatus(activation: .activated, installed: true, reachable: true)
        precondition(noWatch.connection == .unpaired && noWatch.paired == false && noWatch.installed == nil && noWatch.reachable == nil)
        let noApp = NexaWatchStatus(activation: .activated, paired: true, reachable: true)
        precondition(noApp.connection == .companionMissing && noApp.installed == false && noApp.reachable == nil)
        let offline = NexaWatchStatus(activation: .activated, paired: true, installed: true)
        precondition(offline.connection == .notReachable && offline.reachable == false)
        let online = NexaWatchStatus(activation: .activated, paired: true, installed: true, reachable: true)
        precondition(online.connection == .reachable && online.reachable == true)
        for risk in NexaRisk.allCases {
            precondition(!risk.title("en").isEmpty && !risk.title("zh").isEmpty && risk.title("en") != risk.title("zh"))
            precondition(!risk.detail("en").isEmpty && !risk.detail("zh").isEmpty && risk.detail("en") != risk.detail("zh"))
        }
        print("PASS: Watch status gating, activation failure, pairing, install, reachability and bilingual risk taxonomy")
    }
}
