import XCTest
@testable import AllyKeyboardCore

final class UserVocabularyTests: XCTestCase {

    // Russian words are written as escapes: the repository takes no Cyrillic,
    // but these must be tested on the real thing.
    let naprimer = "\u{043D}\u{0430}\u{043F}\u{0440}\u{0438}\u{043C}\u{0435}\u{0440}"      // a lowercase Russian word, "for example"
    let Naprimer = "\u{041D}\u{0430}\u{043F}\u{0440}\u{0438}\u{043C}\u{0435}\u{0440}"      // the same, capitalised
    let n = "\u{043D}", na = "\u{043D}\u{0430}"
    let Tishkin = "\u{0422}\u{0438}\u{0448}\u{043A}\u{0438}\u{043D}"                        // a surname
    let tish = "\u{0442}\u{0438}\u{0448}"
    let kogdaNibud = "\u{043A}\u{043E}\u{0433}\u{0434}\u{0430}-\u{043D}\u{0438}\u{0431}\u{0443}\u{0434}\u{044C}"
    let chtoDash = "\u{0447}\u{0442}\u{043E}-"                                              // a compound cut short

    let day: TimeInterval = 24 * 60 * 60
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testAnOwnWordIsOfferedAfterTwoUses() {
        var v = UserVocabulary()
        v.record("kubeadm", isOwnWord: true, at: t0)
        XCTAssertEqual(v.suggestions(for: "ku", limit: 5, at: t0), [])
        v.record("kubeadm", isOwnWord: true, at: t0)
        XCTAssertEqual(v.suggestions(for: "ku", limit: 5, at: t0), ["kubeadm"])
    }

    func testADictionaryWordGoesFirstOnlyOnceFrequent() {
        var v = UserVocabulary()
        for _ in 0..<2 { v.record("staging", isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: "s", limit: 5, at: t0), [])
        v.record("staging", isOwnWord: false, at: t0)
        XCTAssertEqual(v.suggestions(for: "s", limit: 5, at: t0), ["staging"])   // from the first letter
    }

    func testAFrequentWordFadesWhenNoLongerUsed() {
        var v = UserVocabulary()
        for _ in 0..<4 { v.record("staging", isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: "st", limit: 5, at: t0 + 20 * day), ["staging"])   // 4 -> 2.5
        XCTAssertEqual(v.suggestions(for: "st", limit: 5, at: t0 + 30 * day), [])            // 4 -> 2
        v.forgetFaded(at: t0 + 200 * day)
        XCTAssertTrue(v.entries.isEmpty)
    }

    func testRecentUseOutranksOldUse() {
        var v = UserVocabulary()
        for _ in 0..<8 { v.record("deploy", isOwnWord: false, at: t0) }
        for _ in 0..<5 { v.record("debug", isOwnWord: false, at: t0 + 60 * day) }
        // deploy: 8 two half-lives ago = 2, below the threshold; debug: 5.
        XCTAssertEqual(v.suggestions(for: "de", limit: 5, at: t0 + 60 * day), ["debug"])
    }

    func testOnlySuggestionsThatSaveTwoLettersOrMore() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("kit", isOwnWord: true, at: t0) }
        XCTAssertEqual(v.suggestions(for: "k", limit: 5, at: t0), ["kit"])
        XCTAssertEqual(v.suggestions(for: "ki", limit: 5, at: t0), [])
    }

    func testShortAndLetterlessWordsAreNotLearned() {
        var v = UserVocabulary()
        for w in ["ok", "2026", "--"] { v.record(w, isOwnWord: true, at: t0) }
        XCTAssertTrue(v.entries.isEmpty)
    }

    func testHyphenatedWordsAreOwnWords() {
        XCTAssertTrue(UserVocabulary.isOwnWord("client-start", knownToSystem: true))
        XCTAssertFalse(UserVocabulary.isOwnWord("client", knownToSystem: true))
        XCTAssertTrue(UserVocabulary.isOwnWord("ddev", knownToSystem: false))
        var v = UserVocabulary()
        for _ in 0..<2 { v.record("ddev-client-start", isOwnWord: true, at: t0) }
        XCTAssertEqual(v.suggestions(for: "ddev-", limit: 5, at: t0), ["ddev-client-start"])
    }

    // MARK: Cyrillic

    func testRussianFrequentWordFromTheFirstLetterAnyCase() {
        var v = UserVocabulary()
        v.record(Naprimer, isOwnWord: false, at: t0)
        for _ in 0..<2 { v.record(naprimer, isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: n, limit: 5, at: t0), [Naprimer])    // first spelling kept
        XCTAssertEqual(v.suggestions(for: na, limit: 5, at: t0), [Naprimer])
        XCTAssertEqual(v.suggestions(for: "\u{041D}", limit: 5, at: t0), [Naprimer])   // capital typed
    }

    func testRussianOwnWord() {
        var v = UserVocabulary()
        for _ in 0..<2 { v.record(Tishkin, isOwnWord: true, at: t0) }
        XCTAssertEqual(v.suggestions(for: tish, limit: 5, at: t0), [Tishkin])
    }

    func testRussianCompoundsAndCutShortOnes() {
        XCTAssertTrue(UserVocabulary.isOwnWord(kogdaNibud, knownToSystem: true))
        var v = UserVocabulary()
        for _ in 0..<2 { v.record(chtoDash, isOwnWord: true, at: t0) }
        XCTAssertEqual(v.learnedWords(at: t0), ["\u{0447}\u{0442}\u{043E}"])   // the dash trimmed
    }

    // MARK: Settings list, merge, store

    func testEditingTheListPinsAndForgets() {
        var v = UserVocabulary()
        for w in ["typoo", "typoo", "keepme", "keepme"] { v.record(w, isOwnWord: true, at: t0) }
        v.record("pending", isOwnWord: true, at: t0)
        v.setLearnedWords(["keepme", "Added"], at: t0)
        XCTAssertEqual(Set(v.learnedWords(at: t0)), ["keepme", "Added"])
        XCTAssertTrue(v.contains("pending"))
        XCTAssertFalse(v.contains("typoo"))
        // Pinned words do not fade.
        XCTAssertEqual(Set(v.learnedWords(at: t0 + 365 * day)), ["keepme", "Added"])
    }

    func testMergePutsUserWordsFirstWithoutRepeats() {
        let merged = UserVocabulary.merge(user: ["Ally", "allyship"], system: ["ally", "alloy", "allow"], limit: 4)
        XCTAssertEqual(merged, ["Ally", "allyship", "alloy", "allow"])
    }

    func testReadsTheFirstVersionsFile() throws {
        let json = Data(#"{"entries":{"ddev":{"word":"ddev","uses":3}}}"#.utf8)
        let v = try JSONDecoder().decode(UserVocabulary.self, from: json)
        XCTAssertEqual(v.learnedWords(), ["ddev"])
    }

    func testStoreRoundTripsAndToleratesAMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("vocabulary.json")
        let store = UserVocabularyStore(fileURL: url)
        XCTAssertEqual(store.load(), UserVocabulary())
        var v = UserVocabulary()
        v.record(Tishkin, isOwnWord: true, at: t0)
        store.save(v)
        XCTAssertEqual(store.load(), v)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
