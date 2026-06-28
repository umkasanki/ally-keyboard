//
//  PredictionEngine.swift
//  AllyKeyboardCore
//
//  Abstraction over a word-completion source. On macOS the production engine
//  wraps `NSSpellChecker.completions(forPartialWordRange:…)`; on Linux (and in
//  tests) `DictionaryPredictionEngine` provides a portable implementation.
//

/// Supplies completion suggestions for a partial word.
public protocol PredictionEngine {
    /// - Parameters:
    ///   - partialWord: the word fragment typed so far.
    ///   - limit: maximum number of suggestions to return.
    /// - Returns: up to `limit` suggestions, best first.
    func suggestions(for partialWord: String, limit: Int) -> [String]
}

public extension PredictionEngine {
    /// Suggestions with the default limit of 5.
    func suggestions(for partialWord: String) -> [String] {
        suggestions(for: partialWord, limit: 5)
    }
}
