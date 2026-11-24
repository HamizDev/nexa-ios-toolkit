// Extracted unchanged from WCMigrate Core/Models.swift,
// pinned SHA 55faba721fd44e04c65be481860c9d93e12f6f61
// GPL-3.0-or-later.
import Foundation

public struct DatabaseReport: Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var bytes: Int64
    public var hasWAL: Bool
    public var hasSHM: Bool
    public var tables: [String]
    public var indexCount: Int
    public var result: String
}
