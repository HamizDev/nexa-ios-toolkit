// Adapted from GestaltX/GestaltX/VersionSupport.swift at commit 311f78999d9f5f062f7e3b4c6374684782be5382.
// SPDX-License-Identifier: GPL-3.0-only
// Nexa change: remove dependency on GestaltX's global L() localization helper.
// SPDX-License-Identifier: GPL-3.0-only
import Foundation

enum VersionSupport {
    // Supported OS versions; individual capabilities still depend on device access.
    static let range = "iOS 27.x"

    static func contains(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion == 27
    }
    static var current: Bool { contains(ProcessInfo.processInfo.operatingSystemVersion) }
    static var label: String { current ? "Supported" : "Unsupported" }
}
