import XCTest
import Foundation
@testable import TransferCore

/// Nexa-specific test data lives only inside a disposable host directory.
/// Original upstream test files remain byte-identical.
final class NexaLocalCopyCompatibilityTests: XCTestCase {
    func testDistinctDirectoryURLRepresentationsAndIsolatedResults() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let originals = root.appendingPathComponent("Originals", isDirectory: true)
        let left = originals.appendingPathComponent("source", isDirectory: true)
        let right = originals.appendingPathComponent("target", isDirectory: true)
        for folder in [left, right] {
            try fm.createDirectory(at: folder.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        }
        let incoming = Data("source".utf8)
        let old = Data("target only".utf8)
        try incoming.write(to: left.appendingPathComponent("Documents/shared.txt"))
        try old.write(to: right.appendingPathComponent("Documents/old.txt"))

        for mode in [TransferMode.replace, .merge] {
            let work = root.appendingPathComponent(mode.rawValue, isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let sourceCopy = work.appendingPathComponent("Source")
            let targetCopy = work.appendingPathComponent("Target")
            try fm.copyItem(at: left, to: sourceCopy)
            try fm.copyItem(at: right, to: targetCopy)
            let source = AppInstance(displayName: "Local source copy", bundleIdentifier: "test.nexa.source",
                root: URL(fileURLWithPath: sourceCopy.path, isDirectory: false), origin: "fixture")
            let target = AppInstance(displayName: "Local target copy", bundleIdentifier: "test.nexa.target",
                root: URL(fileURLWithPath: targetCopy.path, isDirectory: true), origin: "fixture")
            let engine = DirectMigrationService(store: work.appendingPathComponent("Tasks"))
            let preferences = PreferencesService(store: work.appendingPathComponent("Preferences"))
            let mapping = [DirectoryMapping(source: "Documents", target: "Documents")]
            let summary = try await engine.preview(source: source, target: target, mappings: mapping,
                mode: mode, keepSource: true)
            XCTAssertEqual(summary.files, 1)
            let receipt = try await engine.migrate(source: source, target: target, mappings: mapping,
                mode: mode, keepSource: true, preferences: preferences,
                systemVersion: "fixture", deviceModel: "fixture", allowOverwrite: true, progress: { _ in })
            XCTAssertEqual(receipt.state, "filesVerified")
            XCTAssertEqual(try Data(contentsOf: targetCopy.appendingPathComponent("Documents/shared.txt")), incoming)
            XCTAssertEqual(try Data(contentsOf: sourceCopy.appendingPathComponent("Documents/shared.txt")), incoming)
            XCTAssertEqual(fm.fileExists(atPath: targetCopy.appendingPathComponent("Documents/old.txt").path), mode == .merge)
            XCTAssertEqual(try Data(contentsOf: left.appendingPathComponent("Documents/shared.txt")), incoming)
            XCTAssertEqual(try Data(contentsOf: right.appendingPathComponent("Documents/old.txt")), old)
            XCTAssertFalse(fm.fileExists(atPath: right.appendingPathComponent("Documents/shared.txt").path))
            let persisted = try await engine.history()
            XCTAssertEqual(persisted.first?.id, receipt.id)
            XCTAssertEqual(persisted.first?.state, "filesVerified")
        }
    }
}
