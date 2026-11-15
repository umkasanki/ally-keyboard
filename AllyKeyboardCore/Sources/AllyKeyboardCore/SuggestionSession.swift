//
//  SuggestionSession.swift
//  AllyKeyboardCore
//
//  The suggestions from end to end, without AppKit: what the balloon offers
//  now — the rest of the word being typed, or the words that usually follow
//  the one before — what picking one sends to the app being typed into, and
//  what is learned from it. The keyboard draws the balloon and sends the keys;
//  this decides. Tests drive it with a sink that keeps the text.
//

import Foundation

/// Where the keystrokes of a picked suggestion go: the app being typed into,
/// or, in tests, a string.
public protocol KeyEventSink: AnyObject {
    func sendBackspace()
    func sendText(_ text: String)
}

public final class SuggestionSession {

    public struct Options: Equatable {
        public var showSuggestions: Bool
        public var suggestNextWord: Bool
        public var spaceAfterSuggestion: Bool
        /// How many rows the balloon has.
        public var slots: Int

        public init(showSuggestions: Bool = true, suggestNextWord: Bool = true,
                    spaceAfterSuggestion: Bool = true, slots: Int = 5) {
            self.showSuggestions = showSuggestions
            self.suggestNextWord = suggestNextWord
            self.spaceAfterSuggestion = spaceAfterSuggestion
            self.slots = slots
        }
    }

    /// What the balloon shows, and how much of each row is typed already.
    public struct Offer: Equatable {
        public var words: [String]
        public var prefixLength: Int
        public static let none = Offer(words: [], prefixLength: 0)
    }

    public let tracker: TextTracker
    public var vocabulary = UserVocabulary()
    public var nextWords = NextWords()

    /// Read on every use: the settings as they are now.
    public var options: () -> Options = { Options() }
    /// The system dictionary's completions of a partial word.
    public var systemSuggestions: (_ partial: String, _ limit: Int) -> [String] = { _, _ in [] }
    /// Whether a finished word may be learned now: learning on, not typed
    /// into a password field. Asked as each word ends.
    public var mayLearn: () -> Bool = { true }
    /// Whether a word is the user's own (unknown to the system dictionary).
    public var isOwnWord: (String) -> Bool = { _ in false }
    /// Told after anything was learned, to save it in time.
    public var onLearned: (() -> Void)?

    private let sink: KeyEventSink

    public init(sink: KeyEventSink, tracker: TextTracker = TextTracker()) {
        self.sink = sink
        self.tracker = tracker
        tracker.onWordCompleted = { [weak self] word, wasSecret in
            guard let self, !wasSecret, self.mayLearn() else { return }
            self.vocabulary.record(word, isOwnWord: self.isOwnWord(word))
            self.onLearned?()
        }
        tracker.onWordFollowed = { [weak self] previous, word in
            guard let self, self.mayLearn() else { return }
            self.nextWords.record(word, after: previous)
            self.onLearned?()
        }
    }

    /// What to offer now: completions of the word being typed — the user's
    /// own words first — or, with nothing of a word typed yet, the words that
    /// usually follow the one before.
    public func offer() -> Offer {
        let o = options()
        guard o.showSuggestions else { return .none }
        if tracker.hasPartialWord {
            let partial = tracker.currentWord
            let words = UserVocabulary.merge(user: vocabulary.suggestions(for: partial, limit: o.slots),
                                             system: systemSuggestions(partial, o.slots),
                                             limit: o.slots)
            return Offer(words: words, prefixLength: partial.count)
        }
        if o.suggestNextWord, let previous = tracker.contextWord {
            return Offer(words: nextWords.suggestions(after: previous, limit: o.slots), prefixLength: 0)
        }
        return .none
    }

    /// Put in a picked suggestion: in place of the word being typed, or —
    /// with nothing of it typed — after the word before, which is finished
    /// first (counted now if it was a pick waiting behind its space). Then a
    /// space, or, with that off, nothing: the word stays open. True when the
    /// space was typed, so the next key may take it back (`SmartSpace`).
    @discardableResult
    public func pick(_ word: String) -> Bool {
        let withSpace = options().spaceAfterSuggestion
        let isNextWord = !tracker.hasPartialWord
        if isNextWord { tracker.finishPendingPick() }
        // After that the word being typed is empty for a next word: nothing
        // is erased.
        let plan = SuggestionApplier.plan(currentWord: tracker.currentWord,
                                          suggestion: word, appendSpace: withSpace)
        for _ in 0..<plan.backspaces { sink.sendBackspace() }
        sink.sendText(plan.textToInsert)
        // The tracker counts it, once — a word picked over is replaced, not
        // counted; see `TextTracker.adopt`.
        if withSpace { tracker.pickWithSpace(word) } else { tracker.adopt(word) }
        return withSpace
    }
}

/// The row of the balloon chosen with the arrow keys. ↑ and ↓ walk the rows
/// from the one nearest the keyboard outwards and round again; the other
/// arrow walks back and, past the nearest, lets go. Rows run top to bottom,
/// so the nearest is the first when the balloon hangs below the keyboard and
/// the last when it stands above.
public struct BalloonCursor: Equatable {
    public private(set) var picked: Int?
    public private(set) var rows = 0
    public private(set) var below = true

    public init() {}

    /// New rows: nothing is chosen.
    public mutating func reset(rows: Int, below: Bool) {
        self.rows = rows
        self.below = below
        picked = nil
    }

    /// One press of ↓ (`down`) or ↑. False when the arrow is not for the
    /// balloon — nothing chosen and it points towards the keyboard, or no
    /// rows — and should do what it always does.
    public mutating func arrow(down: Bool) -> Bool {
        guard rows > 0 else { return false }
        let outwards = down == below
        let nearest = below ? 0 : rows - 1
        let step = below ? 1 : -1
        if let i = picked {
            if outwards {
                picked = ((i + step) % rows + rows) % rows
            } else {
                picked = i == nearest ? nil : i - step
            }
            return true
        }
        guard outwards else { return false }
        picked = nearest
        return true
    }
}
