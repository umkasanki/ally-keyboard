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
        let copy = store.duplicate(.standard, name: "Standard copy")
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

    func testAnUnreadableFileIsMovedAsideAndStandardStays() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bad = dir.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{ not a layout".utf8).write(to: bad)
        XCTAssertEqual(store.loadAll(), KeyboardLayout.builtIns)
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
        XCTAssertNil(Settings().activeLayoutID)
        XCTAssertNil(try JSONDecoder().decode(Settings.self, from: Data(#"{"sizePercent":100}"#.utf8)).activeLayoutID)
        let id = UUID()
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(Settings(activeLayoutID: id)))
        XCTAssertEqual(back.activeLayoutID, id)
    }
}
