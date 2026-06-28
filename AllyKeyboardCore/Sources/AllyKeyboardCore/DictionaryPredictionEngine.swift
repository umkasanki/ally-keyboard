//
//  DictionaryPredictionEngine.swift
//  AllyKeyboardCore
//
//  A portable prediction engine backed by an in-memory word list. Used on
//  Linux and in tests, and as a fallback wherever NSSpellChecker is absent.
//

/// Prefix-matches a partial word against a fixed vocabulary.
///
/// The word list is treated as frequency-ordered: more frequent words come
/// first, and that order is preserved among matches.
public struct DictionaryPredictionEngine: PredictionEngine {

    /// Original spelling paired with its lowercased form, computed once so the
    /// hot path (called on every keystroke) never re-lowercases the vocabulary.
    private let words: [(original: String, lowercased: String)]

    /// - Parameter words: vocabulary, ordered by descending frequency.
    public init(words: [String]) {
        self.words = words.map { ($0, $0.lowercased()) }
    }

    public func suggestions(for partialWord: String, limit: Int) -> [String] {
        guard !partialWord.isEmpty, limit > 0 else { return [] }

        let prefix = partialWord.lowercased()
        var matches: [String] = []
        for word in words {
            // Prefix match, but skip the exact word the user already typed.
            guard word.lowercased.hasPrefix(prefix), word.lowercased != prefix else { continue }
            matches.append(word.original)
            if matches.count == limit { break }
        }
        return matches
    }
}
