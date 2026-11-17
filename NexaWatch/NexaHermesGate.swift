import Foundation
import WatchKit

// The upstream HermesEnabler README reports watchOS 27.0–27.3 beta 1.
// Nexa deliberately allows only the narrower stable 27.0–27.2 range until
// individual beta build numbers have been independently validated.
enum NexaHermesGate {
    static var versionSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.majorVersion == 27 && v.minorVersion <= 2
        #endif
    }

    static var groupIsProvisioned: Bool {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "NexaWatchAppGroup") as? String,
              identifier.hasPrefix("group."),
              !identifier.contains("$(") else {
            return false
        }
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) != nil
    }

    static var ready: Bool { versionSupported && groupIsProvisioned }
}
