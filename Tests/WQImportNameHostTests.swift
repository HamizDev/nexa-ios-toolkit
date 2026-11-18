import Foundation

@main
struct NexaWQImportNameTests {
    static func check(_ value: Bool, _ message: String) {
        precondition(value, "WQ export validation: " + message)
    }

    static func main() {
        let root = "/var/mobile/Containers/Data/Application"
        check(NexaWQImportName.validRemotePath(root), "allowed container root")
        check(NexaWQImportName.validRemotePath(root + "/01234567/Documents/record.db"),
              "authorized nested path")
        for path in [
            "/etc/passwd", "/private/var/mobile/Library/Keychains",
            root + "/../System", root + "//Bad", root + "/.",
            root + "/../../etc", "relative/path", root + "/a\\b",
            root + "/a\0b", root + "/a "
        ] {
            check(!NexaWQImportName.validRemotePath(path), "refuse unsafe path: " + path)
        }
        let transaction = UUID(uuidString: "F8A7A1AD-301E-4CCB-AF37-5487DAA90AA0")!
        let plain = NexaWQImportName.importedFilename(
            remotePath: root + "/id/Documents/聊天记录.db", transaction: transaction
        )
        check(plain == "WQ-F8A7A1AD-聊天记录.db", "non-English filename preserved")
        let hostile = NexaWQImportName.importedFilename(
            remotePath: root + "/id/Documents/\"evil:cache<>.db", transaction: transaction
        )
        check(!hostile.contains(":") && !hostile.contains("<") &&
              !hostile.contains(">") && !hostile.contains("\""),
              "unsafe filename characters normalized")
        let huge = NexaWQImportName.importedFilename(
            remotePath: root + "/id/Documents/" + String(repeating: "汉", count: 1000),
            transaction: transaction
        )
        check(huge.utf8.count < 240, "bounded UTF-8 output")
        print("PASS: WQFiles remote path confinement and safe local name regression")
    }
}
