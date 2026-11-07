//
//  SpellCheckerPredictionEngine.swift
//  AllyKeyboard
//
//  macOS adapter that backs the platform-independent `PredictionEngine`
//  protocol with `NSSpellChecker` word completions.
//

import AppKit
import AllyKeyboardCore

final class SpellCheckerPredictionEngine: PredictionEngine {

    /// Language for completions (BCP-47, e.g. "en", "ru"). nil = spell checker's default.
    var language: String?

    func suggestions(for partialWord: String, limit: Int) -> [String] {
        guard !partialWord.isEmpty, limit > 0 else { return [] }
        let checker = NSSpellChecker.shared
        let ns = partialWord as NSString
        let lang = language ?? checker.language()
        let completions = checker.completions(
            forPartialWordRange: NSRange(location: 0, length: ns.length),
            in: partialWord,
            language: lang,
            inSpellDocumentWithTag: 0) ?? []
        return Array(completions.prefix(limit))
    }

    /// Whether the spell checker accepts `word` in the current language.
    func knows(_ word: String) -> Bool {
        let checker = NSSpellChecker.shared
        let misspelled = checker.checkSpelling(of: word, startingAt: 0,
                                               language: language ?? checker.language(),
                                               wrap: false, inSpellDocumentWithTag: 0,
                                               wordCount: nil)
        return misspelled.location == NSNotFound
    }
}
