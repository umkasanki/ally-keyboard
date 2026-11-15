import XCTest
@testable import AllyKeyboardCore

final class ShortcutTextTests: XCTestCase {

    private func parse(_ s: String) -> [Shortcut]? { Shortcut.parseSequence(s) }
    private let cmd = Shortcut(keyCode: 55, modifiers: [])

    func testOneChordInSymbols() {
        XCTAssertEqual(parse("⌘C"), [Shortcut(keyCode: 8, modifiers: [.command])])
        XCTAssertEqual(parse("⇧⌘5"), [Shortcut(keyCode: 23, modifiers: [.shift, .command])])
        XCTAssertEqual(parse("⌘→"), [Shortcut(keyCode: 124, modifiers: [.command])])
        XCTAssertEqual(parse("⌃⌥Space"), [Shortcut(keyCode: 49, modifiers: [.control, .option])])
        XCTAssertEqual(parse("F13"), [Shortcut(keyCode: 105, modifiers: [])])
    }

    func testSeveralInTurnWithOrWithoutSpaces() {
        let h = Shortcut(keyCode: 4, modifiers: [.command]), five = Shortcut(keyCode: 23, modifiers: [.shift, .command])
        XCTAssertEqual(parse("⌘H, ⇧⌘5"), [h, five])
        XCTAssertEqual(parse("⌘H,⇧⌘5"), [h, five])
        XCTAssertEqual(parse("  ⌘H ,  ⇧⌘5  "), [h, five])
    }

    func testCommandTwice() {
        XCTAssertEqual(parse("⌘⌘"), [cmd, cmd])
        XCTAssertEqual(parse("⌘, ⌘"), [cmd, cmd])
        XCTAssertEqual(parse("⌘"), [cmd])
        XCTAssertEqual(parse("right ⌘"), [Shortcut(keyCode: 54, modifiers: [])])
        XCTAssertEqual(parse("cmd, cmd"), [cmd, cmd])
    }

    func testWords() {
        XCTAssertEqual(parse("cmd+shift+5"), [Shortcut(keyCode: 23, modifiers: [.shift, .command])])
        XCTAssertEqual(parse("Ctrl+Alt+Delete"), [Shortcut(keyCode: 51, modifiers: [.control, .option])])
        XCTAssertEqual(parse("cmd+space"), [Shortcut(keyCode: 49, modifiers: [.command])])
    }

    func testWhatIsNotUnderstoodIsRefused() {
        XCTAssertNil(parse("\u{2318}\u{0436}"))
        XCTAssertNil(parse("⌘H,,⌘S"))
        XCTAssertNil(parse("cmd+banana"))
        XCTAssertNil(parse("\u{2318}+"))            // not a tap of ⌘
        XCTAssertNil(parse("cmd+"))
        XCTAssertNil(parse("+cmd"))
        XCTAssertNil(parse("cmd++c"))
        XCTAssertNil(parse("\u{2318}\u{2318}C"))     // not ⌘C
        XCTAssertNil(parse("cmd+cmd+c"))
        XCTAssertEqual(parse(""), [])
    }

    /// Whatever the field writes reads back as it was, comma key included.
    func testTextReadsBack() {
        var chords: [Shortcut] = []
        for code in Set(Shortcut.keyNames.keys).union(Shortcut.usCharacterCodes.values).union([105, 102]) {
            let tap = Shortcut.modifierKeyCodes.contains(code)
            chords.append(Shortcut(keyCode: code, modifiers: tap ? [] : [.command]))
            if !tap { chords.append(Shortcut(keyCode: code, modifiers: [.control, .option, .shift, .command])) }
        }
        for chord in chords {
            XCTAssertEqual(parse(chord.text), [chord], chord.text)
        }
        XCTAssertEqual(parse(Shortcut.text(of: chords)), chords)
        XCTAssertEqual(Shortcut(keyCode: 43, modifiers: [.command]).text, "\u{2318}Comma")
        XCTAssertEqual(Shortcut(keyCode: 8, modifiers: [.shift, .command]).text, "\u{21E7}\u{2318}C")
        XCTAssertEqual(Shortcut.text(of: [cmd, cmd]), "\u{2318}, \u{2318}")
    }
}
