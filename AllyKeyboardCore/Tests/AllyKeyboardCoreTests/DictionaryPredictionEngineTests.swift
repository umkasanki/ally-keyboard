import XCTest
@testable import AllyKeyboardCore

final class DictionaryPredictionEngineTests: XCTestCase {

    private let engine = DictionaryPredictionEngine(words: [
        "hello", "help", "held", "hero",   // frequency-ordered sample
        "world", "word", "work",
        "the", "there", "these", "they",
    ])

    func testPrefixMatchReturnsExpected() {
        let result = engine.suggestions(for: "hel", limit: 5)
        XCTAssertEqual(result, ["hello", "help", "held"])
    }

    func testCaseInsensitiveMatch() {
        let result = engine.suggestions(for: "HEL", limit: 5)
        XCTAssertEqual(result, ["hello", "help", "held"])
    }

    func testExactWordExcludedFromSuggestions() {
        let result = engine.suggestions(for: "the", limit: 5)
        XCTAssertEqual(result, ["there", "these", "they"])
        XCTAssertFalse(result.contains("the"))
    }

    func testLimitRespected() {
        let result = engine.suggestions(for: "the", limit: 2)
        XCTAssertEqual(result, ["there", "these"])
    }

    func testEmptyPartialReturnsNothing() {
        XCTAssertTrue(engine.suggestions(for: "", limit: 5).isEmpty)
    }

    func testNoMatchReturnsNothing() {
        XCTAssertTrue(engine.suggestions(for: "xyz", limit: 5).isEmpty)
    }

    func testFrequencyOrderPreserved() {
        let result = engine.suggestions(for: "wor", limit: 5)
        XCTAssertEqual(result, ["world", "word", "work"])
    }

    func testDefaultLimitIsFive() {
        let many = DictionaryPredictionEngine(
            words: (0..<10).map { "test\($0)" }
        )
        XCTAssertEqual(many.suggestions(for: "test").count, 5)
    }
}
