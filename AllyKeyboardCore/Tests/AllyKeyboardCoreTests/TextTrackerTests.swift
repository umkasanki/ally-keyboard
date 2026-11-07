import XCTest
@testable import AllyKeyboardCore

final class TextTrackerTests: XCTestCase {

    func testFinishedWordsAreReported() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        "hi there, you".forEach { t.handle($0 == " " ? .wordBoundary : .character($0)) }
        t.handle(.wordBoundary)
        t.handle(.wordBoundary)          // a second space finishes nothing
        XCTAssertEqual(completed, ["hi", "there", "you"])
    }

    func testASecretWordStaysSecretToItsEndAndTheNextIsNot() {
        let t = TextTracker()
        var completed: [(String, Bool)] = []
        t.onWordCompleted = { completed.append(($0, $1)) }
        "pa".forEach { t.handle(.character($0)) }
        t.markSecret()                        // focus was on a password field
        "ss".forEach { t.handle(.character($0)) }
        t.handle(.wordBoundary)               // Return: focus may have moved by now
        "next".forEach { t.handle(.character($0)) }
        t.handle(.wordBoundary)
        XCTAssertEqual(completed.map(\.0), ["pass", "next"])
        XCTAssertEqual(completed.map(\.1), [true, false])
    }

    func testTheSecretFlagIsNotLeftStandingBetweenWords() {
        let t = TextTracker()
        "pw".forEach { t.handle(.character($0)) }
        t.markSecret()
        t.handle(.wordBoundary)
        XCTAssertFalse(t.currentWordIsSecret)      // read by a suggestion picked next
        t.markSecret()                             // no word: nothing to mark
        XCTAssertFalse(t.currentWordIsSecret)
        "pw".forEach { t.handle(.character($0)) }
        t.markSecret()
        t.reset()                                  // a click or an arrow drops it
        XCTAssertFalse(t.currentWordIsSecret)
    }

    func testMarkingSecretBetweenWordsDoesNotLeakIntoTheNext() {
        let t = TextTracker()
        var secret: [Bool] = []
        t.onWordCompleted = { secret.append($1) }
        t.markSecret()                        // no word yet
        "word".forEach { t.handle(.character($0)) }
        t.handle(.wordBoundary)
        XCTAssertEqual(secret, [false])
    }

    func testResetDoesNotReportTheWord() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        "unfin".forEach { t.handle(.character($0)) }
        t.reset()
        XCTAssertEqual(completed, [])
    }

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

    // The hyphen used to terminate the word, so typing the hyphen of
    // "когда-нибудь" threw the buffer away and the suggestions went out just as
    // the user reached the long half of the word.
    func testHyphenStaysWithinWord() {
        let t = TextTracker()
        for c in "когда-нибудь" { t.handle(.character(c)) }
        XCTAssertEqual(t.currentWord, "когда-нибудь")
    }

    func testWordEndingInAHyphenIsStillPartial() {
        let t = TextTracker()
        for c in "когда-" { t.handle(.character(c)) }
        XCTAssertEqual(t.currentWord, "когда-")
        XCTAssertTrue(t.hasPartialWord)
        XCTAssertEqual(t.backspacesToClearWord, 6)
    }

    func testBackspaceOverAHyphenLeavesTheStem() {
        let t = TextTracker()
        for c in "что-" { t.handle(.character(c)) }
        t.handle(.backspace)
        XCTAssertEqual(t.currentWord, "что")
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
