import XCTest
@testable import AllyKeyboardCore

final class ReplacementPlanTests: XCTestCase {

    func testKeepsCommonPrefix() {
        let plan = SuggestionApplier.plan(currentWord: "hel", suggestion: "hello")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 0, textToInsert: "lo "))
    }

    func testCaseMismatchErasesWholeWord() {
        let plan = SuggestionApplier.plan(currentWord: "HEL", suggestion: "hello")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 3, textToInsert: "hello "))
    }

    func testEmptyCurrentWordInsertsWholeSuggestion() {
        let plan = SuggestionApplier.plan(currentWord: "", suggestion: "hello")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 0, textToInsert: "hello "))
    }

    func testSuggestionEqualToCurrentWordJustAddsSpace() {
        let plan = SuggestionApplier.plan(currentWord: "hello", suggestion: "hello")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 0, textToInsert: " "))
    }

    func testSuggestionShorterThanCurrentWord() {
        // typed "hello", picked "hell" → erase 1, add space
        let plan = SuggestionApplier.plan(currentWord: "hello", suggestion: "hell")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 1, textToInsert: " "))
    }

    func testPartialDivergence() {
        // "wor" → "world": keep "wor", type "ld"
        let plan = SuggestionApplier.plan(currentWord: "wor", suggestion: "world")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 0, textToInsert: "ld "))
    }

    func testNoTrailingSpaceWhenDisabled() {
        let plan = SuggestionApplier.plan(currentWord: "hel", suggestion: "hello", appendSpace: false)
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 0, textToInsert: "lo"))
    }

    func testCompletelyDifferentWords() {
        let plan = SuggestionApplier.plan(currentWord: "abc", suggestion: "xyz")
        XCTAssertEqual(plan, ReplacementPlan(backspaces: 3, textToInsert: "xyz "))
    }
}
