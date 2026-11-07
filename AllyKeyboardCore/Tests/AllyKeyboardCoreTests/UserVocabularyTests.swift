import XCTest
@testable import AllyKeyboardCore

final class UserVocabularyTests: XCTestCase {

    func testAWordIsSuggestedOnlyOnceTypedTwice() {
        var v = UserVocabulary()
        v.record("Tishkin")
        XCTAssertEqual(v.suggestions(for: "tish", limit: 5), [])
        v.record("tishkin")
        XCTAssertEqual(v.suggestions(for: "tish", limit: 5), ["Tishkin"])   // first spelling kept
    }

    func testShortAndLetterlessWordsAreNotLearned() {
        var v = UserVocabulary()
        for w in ["ok", "ok", "2026", "2026", "--", "--"] { v.record(w) }
        XCTAssertTrue(v.entries.isEmpty)
    }

    func testMostUsedComeFirstAndTheExactWordIsLeftOut() {
        var v = UserVocabulary()
        for w in ["kubectl", "kubectl", "kubeadm", "kubeadm", "kubeadm", "kube", "kube"] { v.record(w) }
        // kube and kubectl tie on uses, so they go alphabetically.
        XCTAssertEqual(v.suggestions(for: "kub", limit: 5), ["kubeadm", "kube", "kubectl"])
        XCTAssertEqual(v.suggestions(for: "kube", limit: 5), ["kubeadm", "kubectl"])
        XCTAssertEqual(v.suggestions(for: "kub", limit: 1), ["kubeadm"])
    }

    func testHyphenatedWordsAreLearnedEvenFromDictionaryWords() {
        XCTAssertTrue(UserVocabulary.shouldLearn("ddev-client-start", knownToSystem: false))
        XCTAssertTrue(UserVocabulary.shouldLearn("client-start", knownToSystem: true))
        XCTAssertFalse(UserVocabulary.shouldLearn("client", knownToSystem: true))
        XCTAssertTrue(UserVocabulary.shouldLearn("ddev", knownToSystem: false))
        XCTAssertFalse(UserVocabulary.shouldLearn("chto-", knownToSystem: true))
        var v = UserVocabulary()
        v.record("ddev-client-start"); v.record("ddev-client-start")
        XCTAssertEqual(v.suggestions(for: "ddev-", limit: 5), ["ddev-client-start"])
        XCTAssertEqual(v.suggestions(for: "ddev-client-s", limit: 5), ["ddev-client-start"])
    }

    func testEndHyphensAreTrimmed() {
        var v = UserVocabulary()
        v.record("-xyzzy-"); v.record("xyzzy")
        XCTAssertEqual(v.learnedWords, ["xyzzy"])
    }

    func testEditingTheListLearnsAndForgets() {
        var v = UserVocabulary()
        for w in ["typoo", "typoo", "keepme", "keepme", "pending"] { v.record(w) }
        v.setLearnedWords(["keepme", "Added"])
        XCTAssertEqual(Set(v.learnedWords), ["keepme", "Added"])
        XCTAssertTrue(v.contains("pending"))      // not yet learned, left alone
        XCTAssertFalse(v.contains("typoo"))
    }

    func testMergePutsUserWordsFirstWithoutRepeats() {
        let merged = UserVocabulary.merge(user: ["Ally", "allyship"], system: ["ally", "alloy", "allow"], limit: 4)
        XCTAssertEqual(merged, ["Ally", "allyship", "alloy", "allow"])
    }

    func testStoreRoundTripsAndToleratesAMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("vocabulary.json")
        let store = UserVocabularyStore(fileURL: url)
        XCTAssertEqual(store.load(), UserVocabulary())
        var v = UserVocabulary()
        v.record("Lisbon"); v.record("Lisbon")
        store.save(v)
        XCTAssertEqual(store.load(), v)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
