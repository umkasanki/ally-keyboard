import XCTest
@testable import AllyKeyboardCore

final class FnLayerTests: XCTestCase {

    func testTheArrowsAndDelete() {
        XCTAssertEqual(FnLayer.variant(of: .key(.arrowLeft)), .key(.home))
        XCTAssertEqual(FnLayer.variant(of: .key(.arrowRight)), .key(.end))
        XCTAssertEqual(FnLayer.variant(of: .key(.arrowUp)), .key(.pageUp))
        XCTAssertEqual(FnLayer.variant(of: .key(.arrowDown)), .key(.pageDown))
        XCTAssertEqual(FnLayer.variant(of: .key(.backspace)), .key(.delete))
    }

    func testOtherKeysAreLeftAsTheyAre() {
        XCTAssertNil(FnLayer.variant(of: .character("e")))
        XCTAssertNil(FnLayer.variant(of: .key(.space)))
        XCTAssertNil(FnLayer.label(for: .key(.arrowLeft)))
    }

    /// fn in a written chord, which has no symbol for it, reads back.
    func testAChordWithFnIsWrittenInWords() {
        let chord = Shortcut(keyCode: 123, modifiers: [.command, .fn])
        XCTAssertEqual(chord.text, "cmd+fn+\u{2190}")
        XCTAssertEqual(Shortcut.parseSequence(chord.text), [chord])
        XCTAssertEqual(Shortcut.parseSequence("fn+e"), [Shortcut(keyCode: 14, modifiers: [.fn])])
        XCTAssertEqual(Shortcut.parseSequence("fn"), [Shortcut(keyCode: 63, modifiers: [])])   // fn alone: a tap
    }

    func testFnSurvivesAFile() throws {
        let key = KeySpec(.modifier(.fn), label: "fn")
        XCTAssertEqual(try JSONDecoder().decode(KeySpec.self, from: JSONEncoder().encode(key)), key)
        XCTAssertEqual(KeyAction.modifier(.fn).legacyID, "Fn")
        XCTAssertEqual(KeyInput.from(keyID: "Fn"), .ignored)
    }
}
