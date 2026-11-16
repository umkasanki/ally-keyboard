import XCTest
@testable import AllyKeyboardCore

final class AppleLayoutsTests: XCTestCase {

    private let l = KeyboardLayout.accessibilityKeyboard()

    func testItIsFourteenAndAHalfKeysWideInEveryRow() {
        XCTAssertEqual(l.name, "Accessibility Keyboard")
        XCTAssertEqual(l.rows.count, 6)
        for w in l.rowWidths { XCTAssertEqual(w, 14.5, accuracy: 1e-9) }
        let top = l.rows[0].map(\.width)
        XCTAssertTrue(top.allSatisfy { abs($0 - top[0]) < 1e-9 })          // all alike, as Apple's
        XCTAssertFalse(l.rowsAreUneven)
    }

    /// The top row as the Accessibility Keyboard has it, Panels last.
    func testTheTopRowIsApples() {
        XCTAssertEqual(l.rows[0].map(\.action), [
            .key(.escape), .media(.brightnessDown), .media(.brightnessUp),
            .command(.missionControl), .command(.launchpad),
            .shortcut(Shortcut(keyCode: 96, modifiers: [])), .shortcut(Shortcut(keyCode: 97, modifiers: [])),
            .media(.previous), .media(.playPause), .media(.next),
            .media(.mute), .media(.volumeDown), .media(.volumeUp),
            .command(.chooseLayout),
        ])
        XCTAssertEqual(l.rows[0][5].label, "F5")
    }

    func testEveryLetterAndUpOverDown() {
        let ids = Set(l.rows.flatMap { $0 }.map(\.action.legacyID))
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" { XCTAssertTrue(ids.contains(String(letter)), "\(letter)") }
        func start(_ key: SpecialKey) -> Double? {
            for r in l.rows.indices {
                if let i = l.rows[r].firstIndex(where: { $0.action == .key(key) }) { return l.placements(inRow: r)[i].x }
            }
            return nil
        }
        XCTAssertEqual(start(.arrowUp)!, start(.arrowDown)!, accuracy: 1e-9)
        let arrows = l.rows[5].suffix(4).map(\.half)
        XCTAssertEqual(arrows, [.bottom, .top, .bottom, .bottom])
    }

    func testItIsUsableAndSurvivesAFile() throws {
        XCTAssertTrue(l.isUsable)
        XCTAssertEqual(l.problems, [])                              // Space, Backspace and Return are there
        XCTAssertEqual(try KeyboardLayout.decodeForImport(try l.encoded()), l)
        XCTAssertFalse(l.rows.flatMap { $0 }.contains { $0.action == .blank })
        XCTAssertFalse(l.rows.flatMap { $0 }.contains { $0.action == .spacer })   // no empty place
        XCTAssertEqual(l.rows[4].map(\.width).first, 2.25)                  // both Shifts wide, as Apple's
        XCTAssertEqual(l.rows[4].map(\.width).last, 2.25)
    }

    func testFnIsTheRealModifier() {
        XCTAssertEqual(l.rows[5].first?.action, .modifier(.fn))
        XCTAssertEqual(l.rows[5][6].action, .command(.hideKeyboard))        // where the right ⌥ was
    }

    /// With fn held the top row is F1 to F12 in order, as on Apple's.
    func testWithFnTheTopRowIsF1ToF12() {
        let fKeys = l.rows[0].dropFirst().dropLast().map { key -> Int? in
            if case .shortcut(let s)? = FnLayer.variant(of: key.action) { return s.keyCode }
            if case .shortcut(let s) = key.action { return s.keyCode }
            return nil
        }
        XCTAssertEqual(fKeys, [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111])
        XCTAssertEqual(l.rows[0].dropFirst().dropLast().map { FnLayer.label(for: $0.action) ?? $0.label },
                       (1...12).map { "F\($0)" })
    }

    /// Built in, fourth in the list, under an id of its own that stays.
    func testItIsTheFourthBuiltIn() {
        XCTAssertEqual(KeyboardLayout.builtIns.map(\.name),
                       ["Standard", "Standard Multilingual", "Extended", "Accessibility Keyboard"])
        let builtIn = KeyboardLayout.builtIns[3]
        XCTAssertEqual(builtIn.id, KeyboardLayout.accessibilityKeyboardID)
        XCTAssertTrue(builtIn.isBuiltIn)
        XCTAssertEqual(builtIn.rows, l.rows)                                // the same keys as the template
        XCTAssertFalse(l.isBuiltIn)                                         // a copy from New ▸ is the user's
    }

    func testEachIsANewLayout() {
        XCTAssertNotEqual(KeyboardLayout.accessibilityKeyboard().id, KeyboardLayout.accessibilityKeyboard().id)
    }
}
