import Foundation

enum AppPaths {
    static var documents: URL {
        #if NEXA_LOCAL_TEST
        // Host-only test root; this branch is never compiled for an iOS release.
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("Documents")
        }
        #endif
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var importFolder: URL {
        documents.appendingPathComponent("Imports", isDirectory: true)
    }

    static var backupFolder: URL {
        documents.appendingPathComponent("Backups", isDirectory: true)
    }
}
