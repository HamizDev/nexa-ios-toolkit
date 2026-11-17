// Extracted verbatim from WCMigrate Core/Models.swift at commit 55faba721fd44e04c65be481860c9d93e12f6f61.
// Upstream license: GPL-3.0-or-later.
import Foundation

public struct BackupProgress: Sendable {
    public var stage: String
    public var completed: Int
    public var total: Int
    public var bytes: Int64
    public var fraction: Double?
    public init(_ stage: String, _ completed: Int, _ total: Int, _ bytes: Int64, fraction: Double? = nil) {
        self.stage = stage; self.completed = completed; self.total = total; self.bytes = bytes; self.fraction = fraction
    }
}
