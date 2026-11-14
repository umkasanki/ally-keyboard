import XCTest
@testable import AllyKeyboardCore

final class LayoutStoreTests: XCTestCase {

    private var dir: URL!
    private var store: LayoutStore!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = LayoutStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func layout(_ name: String, rows: [[KeySpec]] = [[KeySpec(.key(.space))]]) -> KeyboardLayout {
        KeyboardLayout(name: name, rows: rows)
    }

    // MARK: Standard is always there

    func testAnEmptyFolderHasTheBuiltInsOnly() {
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testAMissingFolderHasTheBuiltInsOnly() {
        let nowhere = LayoutStore(directory: dir.appendingPathComponent("never-made"))
        XCTAssertEqual(nowhere.loadAll(), KeyboardLayout.builtIns)
    }

    func testAnUnknownOrNoActiveIDGivesStandard() {
        XCTAssertEqual(store.layout(id: nil), .standard)
        XCTAssertEqual(store.layout(id: UUID()), .standard)
    }

    func testStandardCanBeEditedAndResetToFactory() {
        var mine = KeyboardLayout.standard
        mine.rows[0].removeFirst()                       // edited: no Esc
        XCTAssertTrue(store.save(mine))
        XCTAssertEqual(store.loadAll(), [mine, .standardMultilingual, .extended])   // the edit replaces the factory one
        XCTAssertTrue(store.isEdited(KeyboardLayout.standardID))
        XCTAssertFalse(store.isEdited(KeyboardLayout.extendedID))
        store.delete(id: KeyboardLayout.standardID)          // "Reset to factory"
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
        XCTAssertFalse(store.isEdited(KeyboardLayout.standardID))
    }

    func testExtendedCanBeEditedAndResetToo() {
        var mine = KeyboardLayout.extended
        mine.name = "My Extended"
        store.save(mine)
        XCTAssertEqual(store.loadAll().map(\.name), ["Standard", "Standard Multilingual", "My Extended"])
        store.delete(id: KeyboardLayout.extendedID)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    // MARK: User layouts

    func testLayoutsComeBackStandardFirstThenByName() {
        let b = layout("Coding"), a = layout("arrows only")
        store.save(b); store.save(a)
        XCTAssertEqual(store.loadAll().map(\.name), ["Standard", "Standard Multilingual", "Extended", "arrows only", "Coding"])
        XCTAssertEqual(store.layout(id: b.id), b)
    }

    func testDuplicateMakesANewLayoutUnderANewID() {
        let copy = store.duplicate(.standard, name: "Standard copy")!
        XCTAssertNotEqual(copy.id, KeyboardLayout.standardID)
        XCTAssertEqual(copy.rows, KeyboardLayout.standard.rows)
        XCTAssertEqual(store.loadAll().map(\.name), ["Standard", "Standard Multilingual", "Extended", "Standard copy"])
    }

    func testDeleteRemovesAUserLayout() {
        let l = layout("Gone"); store.save(l)
        store.delete(id: l.id)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    // MARK: Never locked out

    func testALayoutWithNoKeysIsRefused() {
        XCTAssertFalse(store.save(layout("Empty", rows: [])))
        XCTAssertFalse(store.save(layout("Gaps", rows: [[KeySpec(.spacer)]])))
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testAnUnreadableFileIsSkippedAndMovedAsideOnlyWhenAsked() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bad = dir.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{ not a layout".utf8).write(to: bad)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
        // A read leaves it where it is: it may be mid-edit by hand.
        XCTAssertTrue(FileManager.default.fileExists(atPath: bad.path))
        XCTAssertEqual(store.setAsideUnreadable(), [bad.lastPathComponent])
        XCTAssertFalse(FileManager.default.fileExists(atPath: bad.path))
        let aside = bad.deletingPathExtension().appendingPathExtension("unreadable.json")
        XCTAssertEqual(try String(contentsOf: aside, encoding: .utf8), "{ not a layout")
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)     // and is not tried again
    }

    func testAKeylessFileWrittenByHandIsMovedAsideToo() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let l = layout("Hand-made", rows: [[]])
        let file = dir.appendingPathComponent(l.id.uuidString + ".json")
        try JSONEncoder().encode(l).write(to: file)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
        store.setAsideUnreadable()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testAnEditedStandardThatGoesBadFallsBackToTheFactoryOne() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(KeyboardLayout.standardID.uuidString + ".json")
        try Data("garbage".utf8).write(to: file)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    // MARK: Problems

    func testProblems() {
        XCTAssertEqual(KeyboardLayout.standard.problems, [])
        XCTAssertEqual(layout("x", rows: []).problems, [.noKeys])
        XCTAssertEqual(layout("x", rows: [[KeySpec(.character("Q"))]]).problems,
                       [.missing(.space), .missing(.backspace), .missing(.returnKey)])
        XCTAssertTrue(layout("x", rows: [[KeySpec(.character("Q"))]]).isUsable)
    }

    // MARK: Switching

    func testNextLayoutWrapsRound() {
        let a = layout("A"), b = layout("B")
        let all = KeyboardLayout.builtIns + [a, b]
        XCTAssertEqual(KeyboardLayout.next(after: KeyboardLayout.standardID, in: all), .standardMultilingual)
        XCTAssertEqual(KeyboardLayout.next(after: KeyboardLayout.extendedID, in: all), a)
        XCTAssertEqual(KeyboardLayout.next(after: b.id, in: all), .standard)
        XCTAssertEqual(KeyboardLayout.next(after: UUID(), in: all), .standard)
    }

    // MARK: Settings

    func testActiveLayoutIsStandardByDefaultAndRemembered() throws {
        // A new install: Standard, and saved as such, so it reads back as Standard.
        XCTAssertEqual(Settings().activeLayoutID, KeyboardLayout.standardID)
        let fresh = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(Settings()))
        XCTAssertEqual(fresh.activeLayoutID, KeyboardLayout.standardID)
        // Settings from before layouts (no field): the keyboard they had, Extended.
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: Data(#"{"sizePercent":100}"#.utf8)).activeLayoutID,
                       KeyboardLayout.extendedID)
        let id = UUID()
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(Settings(activeLayoutID: id)))
        XCTAssertEqual(back.activeLayoutID, id)
    }

    // MARK: Review 2026-11-14

    private func write(_ layout: KeyboardLayout, as name: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try layout.encoded().write(to: dir.appendingPathComponent(name))
    }

    func testTwoFilesWithOneIDShowOnceAndResetRemovesBoth() throws {
        var mine = KeyboardLayout.standard
        mine.rows[0].removeFirst()
        // Named to sort before the file named after the id, so only the rule
        // that the id's own file wins — not the alphabet — picks "Other".
        try write(mine, as: "0-my-standard.json")
        var other = mine
        other.name = "Other"
        try write(other, as: KeyboardLayout.standardID.uuidString + ".json")
        let all = store.loadAll()
        XCTAssertEqual(all.filter { $0.id == KeyboardLayout.standardID }.count, 1)
        XCTAssertEqual(all.count, KeyboardLayout.builtIns.count)
        XCTAssertEqual(all[0].name, "Other")                 // the file named after the id wins
        store.delete(id: KeyboardLayout.standardID)
        XCTAssertFalse(store.isEdited(KeyboardLayout.standardID))
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testAFileFromANewerVersionIsLeftAloneAndNotWrittenOver() throws {
        let l = layout("Future")
        var object = try JSONSerialization.jsonObject(with: try l.encoded()) as! [String: Any]
        object["formatVersion"] = KeyboardLayout.currentFormatVersion + 1
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(l.id.uuidString + ".json")
        let bytes = try JSONSerialization.data(withJSONObject: object)
        try bytes.write(to: file)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
        XCTAssertEqual(store.setAsideUnreadable(), [])
        XCTAssertFalse(store.save(l))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        // Nor deleted, even when an older copy of it under another name is.
        try write(l, as: "copy.json")
        XCTAssertEqual(store.loadAll().last?.id, l.id)
        store.delete(id: l.id)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
    }

    func testADuplicateThatCannotBeSavedIsNil() throws {
        // The folder's place is taken by a file: nothing can be written.
        try Data().write(to: dir)
        XCTAssertNil(store.duplicate(.standard, name: "Copy"))
    }

    func testBlankKeysAloneAreNoKeys() {
        XCTAssertEqual(layout("x", rows: [[KeySpec(.blank), KeySpec(.spacer)]]).problems, [.noKeys])
        XCTAssertFalse(store.save(layout("x", rows: [[KeySpec(.blank)]])))
    }

    func testRowsEqualToAMillionthAreEven() {
        let l = layout("x", rows: [[KeySpec(.character("a"), width: 1.1), KeySpec(.character("b"), width: 2.2)],
                                   [KeySpec(.character("c"), width: 3.3)]])
        XCTAssertFalse(l.rowsAreUneven)
        XCTAssertTrue(layout("y", rows: [[KeySpec(.character("a"))], [KeySpec(.character("b"), width: 1.25)]]).rowsAreUneven)
    }

    func testAMalformedLayoutIDCostsOnlyTheLayoutChoice() throws {
        var settings = Settings()
        settings.hideFromCapture = !settings.hideFromCapture
        var object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(settings)) as! [String: Any]
        object["activeLayoutID"] = "not-a-uuid"
        let decoded = try JSONDecoder().decode(Settings.self, from: try JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.activeLayoutID, KeyboardLayout.standardID)
        XCTAssertEqual(decoded.hideFromCapture, settings.hideFromCapture)
        // And it stays Standard after a save — not mistaken for settings from
        // before layouts, which would bring Extended.
        let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(decoded))
        XCTAssertEqual(again.activeLayoutID, KeyboardLayout.standardID)
    }
}
