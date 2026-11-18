import Foundation
import CryptoKit

// Synthetic, disposable LoginInfo2.dat samples. No real WeChat data used.
@main
struct NexaWeChatIdentityHostTests {
    static let fm = FileManager.default

    static func varint(_ input: Int) -> [UInt8] {
        var n = input
        var bytes: [UInt8] = []
        repeat {
            let part = UInt8(n & 0x7f)
            n >>= 7
            bytes.append(n == 0 ? part : part | 0x80)
        } while n != 0
        return bytes
    }

    static func field(_ id: Int, _ data: [UInt8]) -> [UInt8] {
        varint((id << 3) | 2) + varint(data.count) + data
    }

    static func md5(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
    }

    static func writeFixture(_ root: URL, wxid: String, alias: String?,
                             repeatedWXID: String? = nil) throws -> URL {
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        try fm.createDirectory(
            at: documents.appendingPathComponent(md5(wxid), isDirectory: true),
            withIntermediateDirectories: true
        )
        var record = field(1, Array(wxid.utf8))
        record += field(11, Array((repeatedWXID ?? wxid).utf8))
        if let alias { record += field(13, Array(alias.utf8)) }
        let packed = varint(record.count) + record
        let envelope = field(1, packed)
        let file = documents.appendingPathComponent("LoginInfo2.dat")
        try Data(envelope).write(to: file, options: .atomic)
        return file
    }

    static func main() throws {
        guard let path = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              path.hasPrefix("/") else {
            fatalError("NEXA_TEST_ROOT must be a disposable absolute path")
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        precondition(!fm.fileExists(atPath: root.path), "Test directory is not empty")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let id = "wxid_test_001"
        let file = try writeFixture(root, wxid: id, alias: "Alice123")
        precondition(WeChatIdentityResolver.preferredIdentifier(in: root) == "Alice123")
        precondition(WeChatIdentityResolver.diagnostic(in: root).identifier == "Alice123")
        print("PASS: WCMigrate alias and matched account ID parsed")

        _ = try writeFixture(root, wxid: id, alias: nil)
        precondition(WeChatIdentityResolver.preferredIdentifier(in: root) == id)
        print("PASS: valid wxid fallback")

        _ = try writeFixture(root, wxid: id, alias: "Alice123", repeatedWXID: "wxid_other")
        precondition(WeChatIdentityResolver.preferredIdentifier(in: root) == nil)
        print("PASS: conflicting account record rejected")

        try Data([0xff, 0xff, 0xff]).write(to: file, options: .atomic)
        precondition(WeChatIdentityResolver.preferredIdentifier(in: root) == nil)
        print("PASS: malformed protobuf rejected without a crash")

        print("PASS: WCMigrate account identity host fixtures")
    }
}
