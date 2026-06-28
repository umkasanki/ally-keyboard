//
//  ReplacementPlan.swift
//  AllyKeyboardCore
//
//  Computes the keystrokes needed to replace the partial word currently being
//  typed with a chosen suggestion. Pure logic — `KeySender` executes the plan
//  on macOS; here it is fully unit-testable.
//

/// The keystrokes required to turn the current partial word into a suggestion.
public struct ReplacementPlan: Equatable {
    /// How many Backspaces to send first.
    public let backspaces: Int
    /// The text to type afterwards (already includes a trailing space if asked).
    public let textToInsert: String

    public init(backspaces: Int, textToInsert: String) {
        self.backspaces = backspaces
        self.textToInsert = textToInsert
    }
}

public enum SuggestionApplier {

    /// Builds the minimal plan to replace `currentWord` with `suggestion`.
    ///
    /// Only the diverging tail is erased: the longest common prefix is kept, so
    /// "hel" → "hello" costs 0 Backspaces and types "lo". The prefix comparison
    /// is case-sensitive, so "HEL" → "hello" correctly erases all three letters
    /// rather than producing "HELlo".
    ///
    /// - Parameters:
    ///   - currentWord: the partial word from `TextTracker`.
    ///   - suggestion: the word the user picked.
    ///   - appendSpace: append a trailing space after the word (default true).
    public static func plan(
        currentWord: String,
        suggestion: String,
        appendSpace: Bool = true
    ) -> ReplacementPlan {
        let keep = commonPrefixCount(currentWord, suggestion)
        let backspaces = currentWord.count - keep
        var insert = String(suggestion.dropFirst(keep))
        if appendSpace { insert += " " }
        return ReplacementPlan(backspaces: backspaces, textToInsert: insert)
    }

    /// Number of leading characters `a` and `b` share, compared case-sensitively.
    private static func commonPrefixCount(_ a: String, _ b: String) -> Int {
        var count = 0
        var i = a.startIndex
        var j = b.startIndex
        while i < a.endIndex, j < b.endIndex, a[i] == b[j] {
            count += 1
            a.formIndex(after: &i)
            b.formIndex(after: &j)
        }
        return count
    }
}
