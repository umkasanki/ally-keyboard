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

    /// Called with a word the moment it is finished — by a space, Return, Tab
    /// or punctuation — so it can be learned, and whether it was marked secret
    /// while typed. A word left by `reset()` (navigation, a click, another
    /// application, a shortcut that cannot delete it) is not reported, as it
    /// may not be the word that was meant — except a picked suggestion left
    /// open (see `adopt(_:)`). `discard()` reports nothing at all.
    public var onWordCompleted: ((_ word: String, _ wasSecret: Bool) -> Void)?

    /// Whether any part of the current word was typed somewhere secret.
    /// Cleared when the word ends, by `reset()` and `discard()`, and when a new
    /// one starts.
    public private(set) var currentWordIsSecret = false

    /// The suggestion picked into the buffer, while the word it began is still
    /// being typed — set by `adopt(_:)`; cleared when the word ends, when a
    /// Backspace cuts into it, and by `reset()` and `discard()`.
    public private(set) var adoptedWord: String?

    /// Take a picked suggestion as the word being typed. It is counted once,
    /// when it ends, like a typed one: at once if the caller ends it with
    /// `.wordBoundary` (a space typed after it), or later — the user may type
    /// on ("staging" → "stagings"). Left before it ends — `reset()`: a click,
    /// an arrow, another application, a shortcut — the picked word still
    /// counts: it was chosen, not cut short. Not once a Backspace has cut into
    /// it (then it is a word being retyped), nor after a shortcut that may
    /// have deleted it (`discard()`; see `shortcutMayDeleteWord`).
    /// A word picked over an open one replaces it; the first is not counted.
    public func adopt(_ word: String) {
        currentWord = word
        adoptedWord = word.isEmpty ? nil : word
    }

    /// Mark the word being typed as secret — typed into a password field or
    /// under secure input. It stays so until it ends, however the focus moves.
    public func markSecret() {
        if hasPartialWord { currentWordIsSecret = true }
    }

    /// - Parameter isWordCharacter: decides which characters extend the word.
    ///   Defaults to letters, digits, the apostrophe (for contractions) and the
    ///   hyphen (for compounds).
    public init(isWordCharacter: @escaping (Character) -> Bool = TextTracker.defaultIsWordCharacter) {
        self.isWordCharacter = isWordCharacter
    }

    /// Default rule: letters, digits, `'` and `-` continue a word; everything
    /// else (punctuation, symbols) terminates it.
    ///
    /// The hyphen earns its place: Russian is full of compounds built with one —
    /// когда-нибудь, что-то, кто-либо — and the system dictionary completes them
    /// from a hyphenated stem, so "когда-" offers когда-нибудь, когда-то,
    /// когда-либо. Without it the buffer emptied the instant the hyphen was
    /// typed, and the suggestions went out exactly where they were worth most:
    /// the user had typed the easy half of the word and was facing the long half.
    ///
    /// It is the ordinary hyphen-minus, U+002D. That is both what the key sends
    /// and what the dictionary returns (checked, 2026-10-04), so the two line up
    /// for the common-prefix comparison in `SuggestionApplier` and accepting a
    /// suggestion costs no Backspaces at all.
    public static let defaultIsWordCharacter: (Character) -> Bool = { char in
        char.isLetter || char.isNumber || char == "'" || char == "-"
    }

    /// Update the buffer for one keystroke.
    public func handle(_ input: KeyInput) {
        switch input {
        case .character(let char):
            if isWordCharacter(char) {
                if currentWord.isEmpty { currentWordIsSecret = false; adoptedWord = nil }
                currentWord.append(char)
            } else {
                // Punctuation/symbol terminates the current word.
                completeWord()
            }
        case .backspace:
            if !currentWord.isEmpty {
                currentWord.removeLast()
            }
            if let picked = adoptedWord, currentWord.count < picked.count { adoptedWord = nil }
        case .wordBoundary:
            completeWord()
        case .ignored:
            break
        }
    }

    /// Convenience: classify an app `keyID` and update in one call.
    public func handle(keyID: String, shifted: Bool = false) {
        handle(KeyInput.from(keyID: keyID, shifted: shifted))
    }

    private func completeWord() {
        let word = currentWord
        currentWord = ""
        if !word.isEmpty { onWordCompleted?(word, currentWordIsSecret) }
        currentWordIsSecret = false
        adoptedWord = nil
    }

    /// Whether a key may delete the word before the caret, as a shortcut —
    /// which drops even a picked word uncounted, since what it did to it
    /// cannot be known. `modifiers` are the keyboard's own modifier keys held
    /// for it: "Cmd", "Alt", "Ctrl".
    ///
    /// - ⌫ or forward delete with any modifier (⌥⌫ a word, ⌘⌫ a line);
    /// - ⌘Z, undo — the chord, or the keyboard's own Undo key ("Cmd+Z");
    /// - ⌃H, delete backward (text fields and shells); ⌃T, transpose the two
    ///   letters at the caret (text fields); ⌃W and ⌃U, delete a word and the
    ///   line (shells, Emacs).
    ///
    /// Not cut: while a picked word is open nothing is selected (selecting
    /// takes Shift-arrows, ⌘A or a click, each of which ends the word), so ⌘X
    /// leaves it in place in a standard text field. Nor ⌘W, ⌘H, ⌥ letters:
    /// they leave the word as it is.
    ///
    /// `keyID` is the keyboard's own key identifier, the same in every layout.
    /// The shortcut a letter key sends follows the US positions: right for US
    /// and Russian, not for QWERTZ or AZERTY, where Z and Y or W move.
    public static func shortcutMayDeleteWord(keyID: String, modifiers: Set<String>) -> Bool {
        let id = keyID.lowercased()
        if id == "cmd+z" { return true }
        guard !modifiers.isEmpty else { return false }
        if id == "backspace" || id == "delete" { return true }
        if modifiers.contains("Cmd"), id == "z" { return true }
        if modifiers.contains("Ctrl"), ["h", "t", "w", "u"].contains(id) { return true }
        return false
    }

    /// Drop the word without counting it, even a picked one: for a shortcut
    /// that may have deleted it (see `shortcutMayDeleteWord`).
    public func discard() {
        adoptedWord = nil
        currentWord = ""
        currentWordIsSecret = false
    }

    /// End the word without counting it — a click elsewhere, an arrow, another
    /// application — except a picked word left open, which counts (see
    /// `adopt(_:)`).
    public func reset() {
        if let picked = adoptedWord {
            onWordCompleted?(picked, currentWordIsSecret)
        }
        adoptedWord = nil
        currentWord = ""
        currentWordIsSecret = false
    }

    /// Whether there is a partial word to offer suggestions for.
    public var hasPartialWord: Bool { !currentWord.isEmpty }

    /// Number of Backspaces needed to erase the current partial word when a
    /// suggestion is accepted.
    public var backspacesToClearWord: Int { currentWord.count }
}
