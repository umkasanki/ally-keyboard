import XCTest
@testable import AllyKeyboardCore

final class NextWordsTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testAPairIsOfferedAfterTwoUses() {
        var m = NextWords()
        m.record("day", after: "good", at: t0)
        XCTAssertEqual(m.suggestions(after: "good", limit: 3, at: t0), [])     // once could be a slip
        m.record("day", after: "Good", at: t0)
        XCTAssertEqual(m.suggestions(after: "GOOD", limit: 3, at: t0), ["day"])
    }

    func testMostUsedFirstAndLimited() {
        var m = NextWords()
        for _ in 0..<3 { m.record("evening", after: "good", at: t0) }
        for _ in 0..<2 { m.record("day", after: "good", at: t0) }
        for _ in 0..<4 { m.record("morning", after: "good", at: t0) }
        XCTAssertEqual(m.suggestions(after: "good", limit: 2, at: t0), ["morning", "evening"])
    }

    func testPairsFadeAndAreForgotten() {
        var m = NextWords()
        for _ in 0..<2 { m.record("day", after: "good", at: t0) }
        let later = t0.addingTimeInterval(NextWords.halfLife)
        XCTAssertEqual(m.suggestions(after: "good", limit: 3, at: later), [])   // 2 → 1, below 1.5
        m.forgetFaded(at: t0.addingTimeInterval(NextWords.halfLife * 5))
        XCTAssertTrue(m.pairs.isEmpty)
    }

    func testOnlyOfferedPairsAreSaved() throws {
        var m = NextWords()
        m.record("once", after: "said", at: t0)
        for _ in 0..<2 { m.record("day", after: "good", at: t0) }
        let saved = m.persisted(at: t0)
        XCTAssertNil(saved.pairs["said"])
        let back = try JSONDecoder().decode(NextWords.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(back.suggestions(after: "good", limit: 3, at: t0), ["day"])
    }

    func testShortWordsPairButNotNumbersAlone() {
        var m = NextWords()
        for _ in 0..<2 { m.record("\u{0442}\u{043E}\u{043C}", after: "\u{0432}", at: t0) }  // a Russian one-letter word, then a short one
        XCTAssertEqual(m.suggestions(after: "\u{0432}", limit: 1, at: t0), ["\u{0442}\u{043E}\u{043C}"])
        for _ in 0..<2 { m.record("42", after: "page", at: t0) }
        XCTAssertEqual(m.suggestions(after: "page", limit: 1, at: t0), [])
    }

    func testOnlySoManyFollowersAreKept() {
        var m = NextWords()
        for i in 0..<(NextWords.keptPerWord + 5) { m.record("w\(i)x", after: "a", at: t0) }
        XCTAssertEqual(m.pairs["a"]?.count, NextWords.keptPerWord)
    }

    func testTheLowercaseSpellingWins() {
        var m = NextWords()
        m.record("Day", after: "good", at: t0)
        m.record("day", after: "good", at: t0)
        XCTAssertEqual(m.suggestions(after: "good", limit: 1, at: t0), ["day"])
    }
}

final class TextTrackerContextTests: XCTestCase {

    private func type(_ t: TextTracker, _ text: String) {
        for c in text {
            t.handle(c == " " ? .wordBoundary : .character(c))
        }
    }

    func testWordsInTurnAreReportedAsPairs() {
        let t = TextTracker()
        var pairs: [String] = []
        t.onWordFollowed = { pairs.append("\($0)>\($1)") }
        type(t, "good day to you ")
        XCTAssertEqual(pairs, ["good>day", "day>to", "to>you"])
        XCTAssertEqual(t.contextWord, "you")
    }

    func testASentenceEndBreaksTheChainACommaDoesNot() {
        let t = TextTracker()
        var pairs: [String] = []
        t.onWordFollowed = { pairs.append("\($0)>\($1)") }
        type(t, "yes,")
        XCTAssertNil(t.contextWord)             // a word picked here would stick to the comma
        type(t, " sure. then ")
        XCTAssertEqual(pairs, ["yes>sure"])
        XCTAssertEqual(t.contextWord, "then")
    }

    func testNoContextWhileAWordIsTypedOrAfterABreak() {
        let t = TextTracker()
        type(t, "good da")
        XCTAssertNil(t.contextWord)
        type(t, "y ")
        t.handle(.backspace)                    // the space
        t.handle(.backspace)                    // into the text before
        XCTAssertNil(t.contextWord)
        type(t, "x ")
        t.reset()
        XCTAssertNil(t.contextWord)
    }

    func testASecretWordIsNeverPaired() {
        let t = TextTracker()
        var pairs: [String] = []
        t.onWordFollowed = { pairs.append("\($0)>\($1)") }
        type(t, "login ")
        type(t, "hunter")
        t.markSecret()
        type(t, "2 next ")
        XCTAssertEqual(pairs, [])
    }

    /// A picked word waiting behind its space is the context; picking the
    /// next one counts it first, and pairs them.
    func testPickedWordsChain() {
        let t = TextTracker()
        var pairs: [String] = []
        t.onWordFollowed = { pairs.append("\($0)>\($1)") }
        type(t, "good ")
        t.pickWithSpace("morning")
        XCTAssertEqual(t.contextWord, "morning")
        t.finishPendingPick()
        t.pickWithSpace("everyone")
        t.finishPendingPick()
        XCTAssertEqual(pairs, ["good>morning", "morning>everyone"])
    }
}
