import XCTest
@testable import AllyKeyboardCore

final class AppleLayoutsTests: XCTestCase {

    func testTheMagicKeyboardIsFifteenKeysWideInEveryRow() {
        let l = KeyboardLayout.magicKeyboard(numericKeypad: false)
        XCTAssertEqual(l.name, "Magic Keyboard")
        XCTAssertEqual(l.rows.count, 6)
        for w in l.rowWidths { XCTAssertEqual(w, 15, accuracy: 1e-9) }
        XCTAssertFalse(l.rowsAreUneven)
    }

    func testTheNumericKeypadOneIsTwentyThreeWideInEveryRow() {
        let l = KeyboardLayout.magicKeyboard(numericKeypad: true)
        XCTAssertEqual(l.name, "Magic Keyboard with Numeric Keypad")
        for w in l.rowWidths { XCTAssertEqual(w, 23, accuracy: 1e-9) }
    }

    func testEveryLetterAndUpOverDown() {
        for keypad in [false, true] {
            let l = KeyboardLayout.magicKeyboard(numericKeypad: keypad)
            let ids = Set(l.rows.flatMap { $0 }.map(\.action.legacyID))
            for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" { XCTAssertTrue(ids.contains(String(letter)), "\(letter)") }
            func start(_ key: SpecialKey) -> Double? {
                for r in l.rows.indices {
                    if let i = l.rows[r].firstIndex(where: { $0.action == .key(key) }) { return l.placements(inRow: r)[i].x }
                }
                return nil
            }
            XCTAssertEqual(start(.arrowUp)!, start(.arrowDown)!, accuracy: 1e-9, "keypad \(keypad)")
        }
    }

    func testTheyAreUsableAndSurviveAFile() throws {
        for keypad in [false, true] {
            let l = KeyboardLayout.magicKeyboard(numericKeypad: keypad)
            XCTAssertTrue(l.isUsable)
            XCTAssertEqual(l.problems, [])                          // Space, Backspace and Return are there
            XCTAssertEqual(try KeyboardLayout.decodeForImport(try l.encoded()), l)
        }
    }

    func testEachIsANewLayout() {
        XCTAssertNotEqual(KeyboardLayout.magicKeyboard(numericKeypad: false).id,
                          KeyboardLayout.magicKeyboard(numericKeypad: false).id)
    }

    func testNoBlankKeysInTheTopRow() {
        for keypad in [false, true] {
            let top = KeyboardLayout.magicKeyboard(numericKeypad: keypad).rows[0]
            XCTAssertFalse(top.contains { $0.action == .blank })
            XCTAssertTrue(top.contains { $0.action == .command(.hideKeyboard) })
        }
    }
}
