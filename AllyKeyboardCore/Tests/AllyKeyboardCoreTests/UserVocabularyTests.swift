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
        XCTAssertEqual(v.suggestions(for: n, limit: 5, at: t0), [naprimer])    // lowercase use wins
        XCTAssertEqual(v.suggestions(for: na, limit: 5, at: t0), [naprimer])
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

    func testListEditForgetsRemovedAndPinsOnlyNewWords() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("staging", isOwnWord: false, at: t0) }
        for _ in 0..<2 { v.record("typoo", isOwnWord: true, at: t0) }
        v.record("pending", isOwnWord: true, at: t0)
        v.applyListEdit(added: ["Added", "pending"], removed: ["typoo"], at: t0)
        XCTAssertFalse(v.contains("typoo"))
        XCTAssertEqual(Set(v.learnedWords(at: t0)), ["staging", "Added", "pending"])
        // Hand-added words are pinned; a word already offered is not, and fades.
        XCTAssertEqual(Set(v.learnedWords(at: t0 + 365 * day)), ["Added", "pending"])
    }

    func testListEditLeavesWordsItDidNotMention() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("kubectl", isOwnWord: false, at: t0) }   // learned while Settings was open
        v.applyListEdit(added: [], removed: ["other"], at: t0)
        XCTAssertEqual(v.learnedWords(at: t0), ["kubectl"])
    }

    func testACapitalTypedFirstIsKept() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("staging", isOwnWord: false, at: t0) }
        for _ in 0..<3 { v.record(naprimer, isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: "S", limit: 5, at: t0), ["Staging"])
        XCTAssertEqual(v.suggestions(for: "s", limit: 5, at: t0), ["staging"])
        XCTAssertEqual(v.suggestions(for: "\u{041D}", limit: 5, at: t0), [Naprimer])
        // A word learned capitalised is not lowered for a lowercase start.
        for _ in 0..<2 { v.record(Tishkin, isOwnWord: true, at: t0) }
        XCTAssertEqual(v.suggestions(for: tish, limit: 5, at: t0), [Tishkin])
    }

    func testRecordDecaysTheOldScoreBeforeAdding() {
        var v = UserVocabulary()
        for _ in 0..<2 { v.record("staging", isOwnWord: false, at: t0) }
        v.record("staging", isOwnWord: false, at: t0 + 60 * day)   // 2 -> 0.5, +1
        XCTAssertEqual(v.entries["staging"]!.score, 1.5, accuracy: 1e-9)
        XCTAssertEqual(v.suggestions(for: "s", limit: 5, at: t0 + 60 * day), [])
    }

    func testASentenceStartCapitalIsNotKept() {
        var v = UserVocabulary()
        v.record(Naprimer, isOwnWord: false, at: t0)
        for _ in 0..<2 { v.record(naprimer, isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: na, limit: 5, at: t0), [naprimer])
        XCTAssertEqual(v.suggestions(for: "\u{041D}", limit: 5, at: t0), [Naprimer])
        v.record("STAGING", isOwnWord: false, at: t0)              // Caps Lock
        for _ in 0..<2 { v.record("staging", isOwnWord: false, at: t0) }
        XCTAssertEqual(v.suggestions(for: "st", limit: 5, at: t0), ["staging"])
    }

    func testRespellingInTheListKeepsHistoryAndDoesNotPin() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("Staging", isOwnWord: false, at: t0) }
        let edit = UserVocabulary.listEdit(from: ["Staging"], to: ["staging"])
        XCTAssertEqual(edit.added, ["staging"])
        XCTAssertEqual(edit.removed, [])               // still listed, in another case
        v.applyListEdit(added: edit.added, removed: edit.removed, at: t0)
        XCTAssertEqual(v.entries["staging"]?.word, "staging")
        XCTAssertEqual(v.entries["staging"]?.isPinned, false)
        XCTAssertEqual(v.entries["staging"]!.score, 3, accuracy: 1e-9)
    }

    func testAWordStillListedInAnotherCaseIsNotForgotten() {
        var v = UserVocabulary()
        for _ in 0..<3 { v.record("staging", isOwnWord: false, at: t0) }
        // A duplicate line in another case deleted: the word is still there.
        let edit = UserVocabulary.listEdit(from: ["Staging", "staging"], to: ["Staging"])
        XCTAssertEqual(edit.removed, [])
        v.applyListEdit(added: edit.added, removed: edit.removed, at: t0)
        XCTAssertTrue(v.contains("staging"))
    }

    func testAddingByHandAWordKnownInAnotherCasePinsIt() {
        var v = UserVocabulary()
        v.record("Ansible", isOwnWord: true, at: t0)        // once, at a sentence start
        let edit = UserVocabulary.listEdit(from: [], to: ["ansible"])
        v.applyListEdit(added: edit.added, removed: edit.removed, at: t0)
        XCTAssertEqual(v.entries["ansible"]?.isPinned, true)
        XCTAssertEqual(v.learnedWords(at: t0), ["ansible"])    // written as added
    }

    func testASpellingWrittenInTheListSurvivesTyping() {
        var v = UserVocabulary()
        v.applyListEdit(added: ["GitLab"], removed: [], at: t0)
        v.record("gitlab", isOwnWord: true, at: t0)
        XCTAssertEqual(v.suggestions(for: "gi", limit: 5, at: t0), ["GitLab"])
    }

    func testListEditDiff() {
        let edit = UserVocabulary.listEdit(from: ["a1x", "keep", "gone"], to: ["keep", "new", "a1x"])
        XCTAssertEqual(edit.added, ["new"])
        XCTAssertEqual(edit.removed, ["gone"])
    }

    func testAnUnreadableFileIsMovedAsideNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("vocabulary.json")
        try Data("not json".utf8).write(to: url)
        let store = UserVocabularyStore(fileURL: url)
        XCTAssertEqual(store.load(), UserVocabulary())
        let aside = dir.appendingPathComponent("vocabulary.unreadable.json")
        XCTAssertEqual(try String(contentsOf: aside, encoding: .utf8), "not json")
        try? FileManager.default.removeItem(at: dir)
    }

    func testOnlyOfferedWordsAreWrittenToDisk() {
        var v = UserVocabulary()
        v.record("onceonly", isOwnWord: true, at: t0)
        for _ in 0..<2 { v.record("kubeadm", isOwnWord: true, at: t0) }
        v.applyListEdit(added: ["pinnedword"], removed: [], at: t0)
        XCTAssertEqual(Set(v.persisted(at: t0).entries.keys), ["kubeadm", "pinnedword"])
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
