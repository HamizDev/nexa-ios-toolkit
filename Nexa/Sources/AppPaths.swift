import Foundation

enum AppPaths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var importFolder: URL {
        documents.appendingPathComponent("Imports", isDirectory: true)
    }

    static var archiveFolder: URL {
        documents.appendingPathComponent("Archives", isDirectory: true)
    }

    static var backupFolder: URL {
        documents.appendingPathComponent("Backups", isDirectory: true)
    }
}
