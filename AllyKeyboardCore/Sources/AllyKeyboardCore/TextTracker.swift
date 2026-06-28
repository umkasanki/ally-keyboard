//
//  TextTracker.swift
//  AllyKeyboardCore
//
//  Tracks the word currently being typed so the prediction bar can offer
//  completions and a chosen suggestion can replace the partial word.
//

/// Maintains the buffer of the word currently being typed on the virtual
/// keyboard. Fed the same keystrokes that `KeySender` sends to the system.
///
/// Limitation (v1): the tracker holds only the *current* partial word, not the
/// whole document. Backspacing past the start of the current word is a no-op
/// here — we cannot reconstruct the previous word without reading the target
/// app's text, which is out of scope for now.
public final class TextTracker {

    /// The word being typed, empty when at a word boundary.
    public private(set) var currentWord: String = ""

    private let isWordCharacter: (Character) -> Bool

    /// - Parameter isWordCharacter: decides which characters extend the word.
    ///   Defaults to letters, digits and the apostrophe (for contractions).
    public init(isWordCharacter: @escaping (Character) -> Bool = TextTracker.defaultIsWordCharacter) {
        self.isWordCharacter = isWordCharacter
    }

    /// Default rule: letters, digits, and `'` continue a word; everything else
    /// (punctuation, symbols) terminates it.
    public static let defaultIsWordCharacter: (Character) -> Bool = { char in
        char.isLetter || char.isNumber || char == "'"
    }

    /// Update the buffer for one keystroke.
    public func handle(_ input: KeyInput) {
        switch input {
        case .character(let char):
            if isWordCharacter(char) {
                currentWord.append(char)
            } else {
                // Punctuation/symbol terminates the current word.
                currentWord = ""
            }
        case .backspace:
            if !currentWord.isEmpty {
                currentWord.removeLast()
            }
        case .wordBoundary:
            currentWord = ""
        case .ignored:
            break
        }
    }

    /// Convenience: classify an app `keyID` and update in one call.
    public func handle(keyID: String, shifted: Bool = false) {
        handle(KeyInput.from(keyID: keyID, shifted: shifted))
    }

    /// Clear the buffer (e.g. when focus changes or the keyboard is hidden).
    public func reset() {
        currentWord = ""
    }

    /// Whether there is a partial word to offer suggestions for.
    public var hasPartialWord: Bool { !currentWord.isEmpty }

    /// Number of Backspaces needed to erase the current partial word when a
    /// suggestion is accepted.
    public var backspacesToClearWord: Int { currentWord.count }
}
