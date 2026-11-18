import Foundation
import CoreFoundation

// Host-only tests of GestaltX's unmodified type parser used by Nexa's
// imported-plist editor. Never touches MobileGestalt or system files.
@main
struct GestaltPlistHostTests {
    static func check(_ condition: Bool, _ reason: String) {
        precondition(condition, reason)
    }

    static func rejects(_ name: String, _ operation: () throws -> Any) {
        do {
            _ = try operation()
            fatalError("Should have rejected \(name)")
        } catch {
            print("PASS: rejected \(name)")
        }
    }

    static func main() throws {
        check(PlistValueKind.detect(NSNumber(value: true)) == .boolean, "Bool detection")
        check(PlistValueKind.detect(NSNumber(value: Int64(42))) == .integer, "Integer detection")
        check(PlistValueKind.detect(NSNumber(value: Double(3.25))) == .real, "Real detection")
        check(PlistValueKind.detect(Data([1, 2, 3])) == .data, "Data detection")
        check(PlistValueKind.detect(Date()) == .date, "Date detection")
        check(PlistValueKind.detect(["foo": "bar"]) == .dictionary, "Dictionary detection")
        check(PlistValueKind.detect([1, 2]) == .array, "Array detection")

        let maxID = try PlistValueKind.integer.parse("18446744073709551615") as! NSNumber
        check(maxID.uint64Value == UInt64.max, "Unsigned 64-bit identifier overflow")
        rejects("invalid integer") { try PlistValueKind.integer.parse("3.14") }
        rejects("infinite real") { try PlistValueKind.real.parse("inf") }
        rejects("NaN real") { try PlistValueKind.real.parse("nan") }
        rejects("invalid bool") { try PlistValueKind.boolean.parse("perhaps") }
        rejects("date with trailing text") {
            try PlistValueKind.date.parse("2026-11-17T12:00:00Zignored")
        }
        rejects("invalid Base64") { try PlistValueKind.data.parse("%%%") }

        let bool = try PlistValueKind.boolean.parse(" TRUE ") as! NSNumber
        check(bool.boolValue && PlistValueKind.boolean.text(for: bool) == "true",
              "Boolean roundtrip")
        let data = Data([0, 12, 255])
        let converted = try PlistValueKind.data.parse(PlistValueKind.data.text(for: data)) as! Data
        check(converted == data, "Binary data roundtrip")

        let root: [String: Any] = [
            "enabled": NSNumber(value: true),
            "value": NSNumber(value: 123),
            "array": ["hello", NSNumber(value: 4)]
        ]
        let text = PlistValueKind.dictionary.text(for: root)
        let decoded = try PlistValueKind.dictionary.parse(text) as! [String: Any]
        check((decoded["enabled"] as? NSNumber)?.boolValue == true, "Dictionary Bool lost")
        check((decoded["value"] as? NSNumber)?.intValue == 123, "Dictionary Int lost")
        check((decoded["array"] as? [Any])?.count == 2, "Array lost")
        print("PASS: GestaltX typed plist host parser regression suite")
    }
}
