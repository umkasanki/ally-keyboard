import XCTest
@testable import AllyKeyboardCore

/// The app being typed into: keeps the text.
private final class TextSink: KeyEventSink {
    var text = ""
    func sendBackspace() { if !text.isEmpty { text.removeLast() } }
    func sendText(_ t: String) { text += t }
}

final class SuggestionSessionTests: XCTestCase {

    private var sink: TextSink!
    private var session: SuggestionSession!
    private var options = SuggestionSession.Options()
    private var learning = true

    override func setUp() {
        sink = TextSink()
        session = SuggestionSession(sink: sink)
        session.options = { [unowned self] in self.options }
        session.mayLearn = { [unowned self] in self.learning }
        session.systemSuggestions = { partial, limit in
            DictionaryPredictionEngine(words: ["hello", "help", "helmet", "good", "day", "today"])
                .suggestions(for: partial, limit: limit)
        }
    }

    /// Typed on the keyboard: sent to the app, and fed to the tracker, as the
    /// keyboard does; a picked word's space taken back by punctuation, as
    /// `SmartSpace` has it.
    private func type(_ text: String) {
        for c in text {
            if c == " " {
                sink.sendText(" ")
                session.tracker.handle(.wordBoundary)
            } else {
                sink.sendText(String(c))
                session.tracker.handle(.character(c))
            }
        }
    }

    private var shown: [String] { session.offer().words }

    func testTheWordBeingTypedIsCompletedAndReplaced() {
        type("say hel")
        XCTAssertEqual(session.offer(), .init(words: ["hello", "help", "helmet"], prefixLength: 3))
        XCTAssertTrue(session.pick("help"))
        XCTAssertEqual(sink.text, "say help ")
    }

    func testWithoutTheSpaceTheWordStaysOpen() {
        options.spaceAfterSuggestion = false
        type("hel")
        XCTAssertFalse(session.pick("hello"))
        XCTAssertEqual(sink.text, "hello")
        type("s ")
        XCTAssertEqual(sink.text, "hellos ")
    }

    func testTheUsersOwnWordsComeFirst() {
        type("helix helix helix hel")
        XCTAssertEqual(shown.first, "helix")
    }

    /// The whole of it: a phrase typed twice is offered word by word after
    /// its first word, and picking word after word finishes it.
    func testAPhraseIsFinishedByPickingNextWords() {
        type("good day to you. good day to you. ")
        type("good ")
        XCTAssertEqual(session.offer(), .init(words: ["day"], prefixLength: 0))
        session.pick("day")
        XCTAssertEqual(shown, ["to"])
        session.pick("to")
        XCTAssertEqual(shown, ["you"])
        session.pick("you")
        XCTAssertEqual(sink.text, "good day to you. good day to you. good day to you ")
    }

    /// Picked words are learned like typed ones: twice picked, a pair is offered.
    func testPickedWordsTeachPairs() {
        type("good ")
        session.pick("day")
        type(". good ")
        session.pick("day")
        type(". good ")
        XCTAssertEqual(shown, ["day"])
    }

    /// Words picked one after another are counted, and paired, as they go —
    /// each pick finishes the one waiting behind its space.
    func testAChainOfPicksIsLearnedPairByPair() {
        type("good ")
        session.pick("day")
        session.pick("to")
        XCTAssertEqual(sink.text, "good day to ")
        XCTAssertEqual(session.nextWords.pairs["good"]?["day"]?.score, 1)
        XCTAssertNil(session.nextWords.pairs["day"])     // "to" waits for the next key
        type(".")
        XCTAssertEqual(session.nextWords.pairs["day"]?["to"]?.score, 1)
        XCTAssertNotNil(session.vocabulary.entries["day"])
    }

    func testNothingIsLearnedWhereLearningIsOff() {
        learning = false
        type("good day. good day. good ")
        XCTAssertEqual(shown, [])
        XCTAssertTrue(session.vocabulary.entries.isEmpty)
    }

    func testNextWordsCanBeTurnedOff() {
        type("good day. good day. good ")
        options.suggestNextWord = false
        XCTAssertEqual(shown, [])
        options.suggestNextWord = true
        options.showSuggestions = false
        XCTAssertEqual(shown, [])
    }

    func testNoNextWordsRightAfterAComma() {
        type("yes, sure. yes, sure. yes,")
        XCTAssertEqual(shown, [])
        type(" ")
        XCTAssertEqual(shown, ["sure"])
    }
}

final class BalloonCursorTests: XCTestCase {

    private func walk(_ c: inout BalloonCursor, _ presses: String) -> [Int?] {
        presses.map { p in _ = c.arrow(down: p == "v"); return c.picked }
    }

    func testBelowTheKeyboardDownWalksFromTheTopAndRound() {
        var c = BalloonCursor()
        c.reset(rows: 3, below: true)
        XCTAssertEqual(walk(&c, "vvvv"), [0, 1, 2, 0])
        XCTAssertEqual(walk(&c, "vv^^"), [1, 2, 1, 0])
    }

    func testAboveTheKeyboardUpWalksFromTheBottomAndRound() {
        var c = BalloonCursor()
        c.reset(rows: 3, below: false)
        XCTAssertEqual(walk(&c, "^^^^"), [2, 1, 0, 2])
    }

    func testBackPastTheNearestLetsGoAndTheArrowIsTheAppsAgain() {
        var c = BalloonCursor()
        c.reset(rows: 3, below: true)
        XCTAssertFalse(c.arrow(down: false))     // towards the keyboard, nothing chosen: the app's
        XCTAssertTrue(c.arrow(down: true))
        XCTAssertTrue(c.arrow(down: false))      // back past the first: let go
        XCTAssertNil(c.picked)
        XCTAssertFalse(c.arrow(down: false))
    }

    func testNewRowsChooseNothing() {
        var c = BalloonCursor()
        c.reset(rows: 3, below: true)
        _ = c.arrow(down: true)
        c.reset(rows: 2, below: false)
        XCTAssertNil(c.picked)
        var empty = BalloonCursor()
        empty.reset(rows: 0, below: true)
        XCTAssertFalse(empty.arrow(down: true))
    }
}
