// swift-tools-version: 6.0
// Derived from WCMigrate 55faba721fd44e04c65be481860c9d93e12f6f61.
// The upstream host-test manifest declares only macOS; the upstream app's
// project.yml declares iOS 17.0. Keep the same core/CSupport module names.
import PackageDescription

let package = Package(
    name: "NexaTransferCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "TransferCore", targets: ["TransferCore"])],
    targets: [
        .target(name: "CSupport", path: "CSupport", publicHeadersPath: "include"),
        .target(name: "TransferCore", dependencies: ["CSupport"], path: "Core",
                linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "TransferCoreTests", dependencies: ["TransferCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
