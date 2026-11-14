import XCTest
@testable import AllyKeyboardCore

final class LayoutTransferTests: XCTestCase {

    private var dir: URL!
    private var store: LayoutStore!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = LayoutStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func mine(_ name: String = "Mine") -> KeyboardLayout {
        KeyboardLayout(name: name, rows: [[KeySpec(.character("a")), KeySpec(.key(.space), width: 3)]])
    }

    private func json(_ text: String) -> Data { Data(text.utf8) }

    private func importError(_ data: Data) -> KeyboardLayout.ImportError? {
        do { _ = try store.importLayout(from: data); return nil }
        catch let e as KeyboardLayout.ImportError { return e }
        catch { XCTFail("\(error)"); return nil }
    }

    // MARK: Round trip

    func testAnExportedLayoutImportsAsItWas() throws {
        let layout = mine()
        let imported = try store.importLayout(from: try layout.encoded())
        XCTAssertEqual(imported, layout)
        XCTAssertEqual(store.layout(id: layout.id), layout)
    }

    func testTwoExportsOfOneLayoutAreTheSameBytes() throws {
        XCTAssertEqual(try KeyboardLayout.extended.encoded(), try KeyboardLayout.extended.encoded())
    }

    // MARK: Never overwrites

    func testATakenIDAndNameGetANewIDAndANumber() throws {
        let layout = mine()
        store.save(layout)
        let first = try store.importLayout(from: try layout.encoded())
        let second = try store.importLayout(from: try layout.encoded())
        XCTAssertNotEqual(first.id, layout.id)
        XCTAssertEqual(first.name, "Mine 2")
        XCTAssertEqual(second.name, "Mine 3")
        XCTAssertEqual(first.rows, layout.rows)
        XCTAssertEqual(store.layout(id: layout.id), layout)
        XCTAssertEqual(store.loadAll().count, KeyboardLayout.builtIns.count + 3)
    }

    func testABuiltInsExportComesInAsACopy() throws {
        var edited = KeyboardLayout.standard
        edited.rows[0].removeFirst()
        let imported = try store.importLayout(from: try edited.encoded())
        XCTAssertNotEqual(imported.id, KeyboardLayout.standardID)
        XCTAssertEqual(imported.name, "Standard 2")
        XCTAssertFalse(store.isEdited(KeyboardLayout.standardID))
    }

    // MARK: Refused whole, with a reason

    func testNotJSONIsRefused() {
        XCTAssertEqual(importError(json("hello")), .unreadable(detail: "it is not valid JSON"))
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testAMissingFieldIsNamed() {
        guard case .unreadable(let detail)? = importError(json(#"{"id": "\#(UUID().uuidString)", "name": "X"}"#))
        else { return XCTFail() }
        XCTAssertTrue(detail.contains("rows"), detail)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testABadKeySaysWhichRowAndKey() throws {
        // Row 2, key 3 has a width that is not a number.
        var layout = mine()
        layout.rows = [[KeySpec(.character("a"))],
                       [KeySpec(.character("b")), KeySpec(.character("c")), KeySpec(.character("d"))]]
        var object = try JSONSerialization.jsonObject(with: try layout.encoded()) as! [String: Any]
        var rows = object["rows"] as! [[[String: Any]]]
        rows[1][2]["width"] = "wide"
        object["rows"] = rows
        let data = try JSONSerialization.data(withJSONObject: object)
        guard case .unreadable(let detail)? = importError(data) else { return XCTFail() }
        XCTAssertTrue(detail.contains("row 2, key 3"), detail)
        XCTAssertTrue(detail.contains("width"), detail)
    }

    func testANewerFormatAsksForAnUpdate() throws {
        var object = try JSONSerialization.jsonObject(with: try mine().encoded()) as! [String: Any]
        object["formatVersion"] = KeyboardLayout.currentFormatVersion + 1
        object["rows"] = "something new"
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(importError(data), .newerFormat(KeyboardLayout.currentFormatVersion + 1))
        XCTAssertTrue(KeyboardLayout.ImportError.newerFormat(2).message.contains("newer version"))
    }

    func testALayoutWithNoKeysIsRefused() throws {
        let empty = KeyboardLayout(name: "Empty", rows: [[KeySpec(.spacer)]])
        XCTAssertEqual(importError(try empty.encoded()), .noKeys)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }
}
