import XCTest
@testable import AllyKeyboardCore

final class TextTrackerTests: XCTestCase {

    func testTypingLettersBuildsWord() {
        let t = TextTracker()
        t.handle(.character("h"))
        t.handle(.character("e"))
        t.handle(.character("l"))
        XCTAssertEqual(t.currentWord, "hel")
        XCTAssertTrue(t.hasPartialWord)
        XCTAssertEqual(t.backspacesToClearWord, 3)
    }

    func testWordBoundaryResetsBuffer() {
        let t = TextTracker()
        t.handle(.character("h"))
        t.handle(.character("i"))
        t.handle(.wordBoundary)
        XCTAssertEqual(t.currentWord, "")
        XCTAssertFalse(t.hasPartialWord)
    }

    func testBackspaceRemovesLastCharacter() {
        let t = TextTracker()
        t.handle(.character("c"))
        t.handle(.character("a"))
        t.handle(.character("t"))
        t.handle(.backspace)
        XCTAssertEqual(t.currentWord, "ca")
    }

    func testBackspaceOnEmptyBufferIsNoOp() {
        let t = TextTracker()
        t.handle(.backspace)
        XCTAssertEqual(t.currentWord, "")
    }

    func testPunctuationTerminatesWord() {
        let t = TextTracker()
        t.handle(.character("h"))
        t.handle(.character("i"))
        t.handle(.character("."))
        XCTAssertEqual(t.currentWord, "")
    }

    func testApostropheStaysWithinWord() {
        let t = TextTracker()
        for c in "don't" { t.handle(.character(c)) }
        XCTAssertEqual(t.currentWord, "don't")
    }

    func testDigitsExtendWord() {
        let t = TextTracker()
        for c in "abc123" { t.handle(.character(c)) }
        XCTAssertEqual(t.currentWord, "abc123")
    }

    func testIgnoredInputHasNoEffect() {
        let t = TextTracker()
        t.handle(.character("a"))
        t.handle(.ignored)
        XCTAssertEqual(t.currentWord, "a")
    }

    func testResetClearsBuffer() {
        let t = TextTracker()
        t.handle(.character("x"))
        t.reset()
        XCTAssertEqual(t.currentWord, "")
    }

    // MARK: - keyID convenience mapping

    func testKeyIDLettersWithShift() {
        let t = TextTracker()
        t.handle(keyID: "h", shifted: true)
        t.handle(keyID: "i", shifted: false)
        XCTAssertEqual(t.currentWord, "Hi")
    }

    func testKeyIDSpaceResets() {
        let t = TextTracker()
        t.handle(keyID: "a")
        t.handle(keyID: "Space")
        XCTAssertEqual(t.currentWord, "")
    }

    func testKeyIDBackspace() {
        let t = TextTracker()
        t.handle(keyID: "a")
        t.handle(keyID: "b")
        t.handle(keyID: "Backspace")
        XCTAssertEqual(t.currentWord, "a")
    }

    func testKeyIDNavigationIgnored() {
        let t = TextTracker()
        t.handle(keyID: "a")
        t.handle(keyID: "ArrowLeft")
        t.handle(keyID: "Cmd+C")
        XCTAssertEqual(t.currentWord, "a")
    }
}
