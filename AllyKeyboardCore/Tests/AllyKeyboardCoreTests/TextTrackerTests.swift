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

    // MARK: A picked suggestion with no space after it

    func testAPickedWordTypedOnIsCountedOnceAsTheLongerWord() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        "sta".forEach { t.handle(.character($0)) }
        t.adopt("staging")
        XCTAssertEqual(t.currentWord, "staging")
        t.handle(.character("s"))
        t.handle(.wordBoundary)
        XCTAssertEqual(completed, ["stagings"])
    }

    func testAPickedWordEndedByPunctuationOrReturnIsCountedOnce() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("x")); t.adopt("xylophone")
        t.handle(.character(","))
        t.handle(.character("y")); t.adopt("yesterday")
        t.handle(.wordBoundary)                       // Return
        XCTAssertEqual(completed, ["xylophone", "yesterday"])
    }

    func testAPickedWordLeftByAClickStillCounts() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("k")); t.adopt("kubectl")
        t.reset()                                     // a click elsewhere
        t.reset()                                     // and nothing twice
        XCTAssertEqual(completed, ["kubectl"])
    }

    func testAPickedWordBackspacedIntoIsNotCountedOnAClick() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("k")); t.adopt("kubectl")
        t.handle(.backspace)
        t.reset()
        XCTAssertEqual(completed, [])
    }

    func testATypedWordAfterAPickedOneIsNotTakenForIt() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("k")); t.adopt("kubectl")
        t.handle(.wordBoundary)
        "unfin".forEach { t.handle(.character($0)) }
        t.reset()                                     // a typed word cut short: not counted
        XCTAssertEqual(completed, ["kubectl"])
    }

    func testBackspacingIntoAPickedWordAndRetypingItIsATypedWord() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("s")); t.adopt("staging")
        t.handle(.backspace); t.handle(.character("g"))   // "stagin", then "staging" again
        t.reset()                                          // a click: a typed word cut short
        XCTAssertEqual(completed, [])
    }

    func testAPickedWordTypedOnThenLeftCountsAsPicked() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("s")); t.adopt("staging")
        t.handle(.character("s"))
        t.reset()
        XCTAssertEqual(completed, ["staging"])
    }

    func testAShortcutDropsAPickedWordUncounted() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("k")); t.adopt("kubectl")
        t.discard()                                        // ⌥⌫ or ⌘Z
        t.handle(.wordBoundary)
        XCTAssertEqual(completed, [])
        XCTAssertFalse(t.hasPartialWord)
    }

    func testOnlyShortcutsThatMayDeleteTheWordDropIt() {
        func drops(_ id: String, _ mods: Set<String>) -> Bool {
            TextTracker.shortcutMayDeleteWord(keyID: id, modifiers: mods)
        }
        XCTAssertTrue(drops("Backspace", ["Alt"]))      // ⌥⌫
        XCTAssertTrue(drops("Backspace", ["Cmd"]))      // ⌘⌫
        XCTAssertTrue(drops("Delete", ["Alt"]))
        XCTAssertTrue(drops("z", ["Cmd"]))              // undo
        XCTAssertTrue(drops("h", ["Ctrl"]))
        XCTAssertTrue(drops("w", ["Ctrl"]))
        XCTAssertTrue(drops("u", ["Ctrl"]))
        XCTAssertTrue(drops("t", ["Ctrl"]))             // transpose changes the word
        XCTAssertTrue(drops("Cmd+Z", []))               // the keyboard's Undo key
        XCTAssertTrue(drops("Cmd+Z", ["Alt"]))          // with a modifier armed too
        // Shortcuts that leave the word as it is.
        XCTAssertFalse(drops("w", ["Cmd"]))             // close window
        XCTAssertFalse(drops("h", ["Cmd"]))             // hide app
        XCTAssertFalse(drops("u", ["Cmd"]))             // underline
        XCTAssertFalse(drops("w", ["Alt"]))             // types a character
        XCTAssertFalse(drops("z", ["Ctrl"]))
        XCTAssertFalse(drops("x", ["Cmd"]))             // cut: nothing selected
        XCTAssertFalse(drops("Cmd+X", []))
        XCTAssertFalse(drops("ArrowRight", ["Cmd"]))
        XCTAssertFalse(drops("Return", ["Cmd"]))
        XCTAssertFalse(drops("s", ["Cmd"]))
        // Without a modifier nothing but the Undo key is a shortcut; a plain
        // Backspace is typed into the word.
        XCTAssertFalse(drops("Backspace", []))
        XCTAssertFalse(drops("z", []))
        XCTAssertFalse(drops("Cmd+C", []))
    }

    func testPickingOverAnOpenPickCountsOnlyTheSecond() {
        let t = TextTracker()
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        t.handle(.character("s")); t.adopt("staging")
        t.adopt("stagings")                                // picked again, word still open
        t.handle(.wordBoundary)                            // space typed after it (setting on)
        XCTAssertEqual(completed, ["stagings"])
    }

    func testTheSecretFlagCarriesThroughAPick() {
        let t = TextTracker()
        var secret: [Bool] = []
        t.onWordCompleted = { secret.append($1) }
        "pa".forEach { t.handle(.character($0)) }
        t.markSecret()
        t.adopt("password1")
        t.handle(.wordBoundary)
        "pa".forEach { t.handle(.character($0)) }
        t.markSecret()
        t.adopt("password2")
        t.reset()                                          // left open, by a click
        XCTAssertEqual(secret, [true, true])
    }

    // MARK: A picked suggestion with its space after it

    private func counting(_ t: TextTracker) -> () -> [String] {
        var completed: [String] = []
        t.onWordCompleted = { word, _ in completed.append(word) }
        return { completed }
    }

    func testBackspaceAfterAPickReopensItToBeTypedOn() {
        let t = TextTracker(); let completed = counting(t)
        t.handle(.character("s")); t.pickWithSpace("staging")
        XCTAssertFalse(t.hasPartialWord)                   // no suggestions behind the space
        t.handle(.backspace)                               // the space, not the "g"
        XCTAssertEqual(t.currentWord, "staging")
        XCTAssertTrue(t.hasPartialWord)
        t.handle(.character("s"))
        t.handle(.wordBoundary)
        XCTAssertEqual(completed(), ["stagings"])          // once, the longer word only
    }

    func testARussianCompoundFromAPick() {
        let t = TextTracker(); let completed = counting(t)
        let kogda = "\u{043A}\u{043E}\u{0433}\u{0434}\u{0430}"
        let to = "\u{0442}\u{043E}"
        t.handle(.character("\u{043A}")); t.pickWithSpace(kogda)
        t.handle(.backspace)
        t.handle(.character("-")); to.forEach { t.handle(.character($0)) }
        t.handle(.wordBoundary)
        XCTAssertEqual(completed(), [kogda + "-" + to])
    }

    func testAnyOtherKeyAfterAPickCountsItThenGoesOn() {
        let t = TextTracker(); let completed = counting(t)
        t.handle(.character("s")); t.pickWithSpace("staging")
        "is".forEach { t.handle(.character($0)) }          // the next word, typed after the space
        t.handle(.wordBoundary)
        XCTAssertEqual(completed(), ["staging", "is"])
    }

    func testPunctuationOrReturnAfterAPickCountsItOnce() {
        let t = TextTracker(); let completed = counting(t)
        t.handle(.character("s")); t.pickWithSpace("staging")
        t.handle(.character(","))                          // smart space moved it after the comma
        t.handle(.character("d")); t.pickWithSpace("deploy")
        t.handle(.wordBoundary)                            // Return
        XCTAssertEqual(completed(), ["staging", "deploy"])
    }

    func testAPickLeftBehindItsSpaceCountsOnAClickAndNotAfterUndo() {
        let t = TextTracker(); let completed = counting(t)
        t.handle(.character("s")); t.pickWithSpace("staging")
        t.reset()                                          // a click elsewhere
        t.handle(.character("d")); t.pickWithSpace("deploy")
        t.discard()                                        // the Undo key
        t.handle(.backspace)                               // nothing left to reopen
        t.handle(.wordBoundary)
        XCTAssertEqual(completed(), ["staging"])
    }

    func testBackspacingPastTheReopenedWordMakesItATypedWord() {
        let t = TextTracker(); let completed = counting(t)
        t.handle(.character("s")); t.pickWithSpace("staging")
        t.handle(.backspace)                               // reopen
        t.handle(.backspace)                               // the "g": no longer the pick
        t.reset()                                          // a typed word cut short
        XCTAssertEqual(completed(), [])
    }

    func testSmartSpace() {
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: ","), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "."), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "?"), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "!"), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: ":"), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: ";"), .moveSpaceAfter)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "\n"), .removeSpace)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "\r"), .removeSpace)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "\t"), .removeSpace)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "a"), .none)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: "-"), .none)
        XCTAssertEqual(SmartSpace.afterSuggestion(typing: " "), .none)
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
