//
//  UserVocabulary.swift
//  AllyKeyboardCore
//
//  The user's own words, learned from what is typed on the keyboard and
//  offered ahead of the system dictionary's suggestions.
//

import Foundation

/// Every word the user finishes on the keyboard, with a score of how much
/// they use it lately. Words they use often are suggested first, from the
/// first letter.
///
/// The score is not a plain count: each use adds 1, and the total halves for
/// every `halfLife` without use. A word typed every day stays at the top; one
/// from a project long finished sinks below the threshold on its own and, in
/// the end, is dropped.
///
/// Two thresholds, because two kinds of word:
/// - an *own* word — one the system dictionary does not know, or any word with
///   a hyphen inside (command names like ddev-client-start, made of dictionary
///   words, would slip through a spelling check) — is never suggested by the
///   system at all, so it is offered after about two recent uses;
/// - any other word the system already offers; it is moved to the front only
///   once it is frequent: about three recent uses.
///
/// Words are matched without regard to case and kept in the spelling they
/// were first typed in.
public struct UserVocabulary: Codable, Equatable {

    public struct Entry: Codable, Equatable {
        public var word: String
        /// Uses, decayed to `lastUsed`.
        public var score: Double
        public var lastUsed: Date
        public var isOwnWord: Bool
        /// Added by hand in Settings: offered whatever the score.
        public var isPinned: Bool

        public init(word: String, score: Double, lastUsed: Date, isOwnWord: Bool, isPinned: Bool = false) {
            self.word = word
            self.score = score
            self.lastUsed = lastUsed
            self.isOwnWord = isOwnWord
            self.isPinned = isPinned
        }

        private enum CodingKeys: String, CodingKey { case word, score, lastUsed, isOwnWord, isPinned, uses }

        // The first version kept a plain count of unknown words only.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            word = try c.decode(String.self, forKey: .word)
            let uses = try c.decodeIfPresent(Int.self, forKey: .uses) ?? 0
            score = try c.decodeIfPresent(Double.self, forKey: .score) ?? Double(uses)
            lastUsed = try c.decodeIfPresent(Date.self, forKey: .lastUsed) ?? Date()
            isOwnWord = try c.decodeIfPresent(Bool.self, forKey: .isOwnWord) ?? true
            isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(word, forKey: .word)
            try c.encode(score, forKey: .score)
            try c.encode(lastUsed, forKey: .lastUsed)
            try c.encode(isOwnWord, forKey: .isOwnWord)
            try c.encode(isPinned, forKey: .isPinned)
        }

        /// The score as it stands at `now`.
        public func score(at now: Date) -> Double {
            let idle = max(0, now.timeIntervalSince(lastUsed))
            return score * pow(0.5, idle / UserVocabulary.halfLife)
        }
    }

    /// Unused this long, a word's score halves.
    public static let halfLife: TimeInterval = 30 * 24 * 60 * 60
    /// About two recent uses: an own word is offered.
    public static let ownWordThreshold = 1.5
    /// About three recent uses: a dictionary word is frequent and goes first.
    public static let frequentThreshold = 2.5
    /// Below this a word is as good as forgotten and is dropped.
    static let forgetBelow = 0.1
    /// Shorter words are not worth a suggestion and are mostly noise.
    public static let minimumLength = 3
    /// A suggestion that saves fewer letters than this only takes up a slot.
    public static let minimumSaving = 2

    /// Keyed by the lowercased word.
    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    /// Long enough, and more than digits and punctuation.
    public static func isLearnable(_ word: String) -> Bool {
        word.count >= minimumLength && word.contains(where: \.isLetter)
    }

    /// One the system dictionary does not know, or one with a hyphen inside.
    public static func isOwnWord(_ word: String, knownToSystem: Bool) -> Bool {
        !knownToSystem || trimmed(word).contains("-")
    }

    /// Without hyphens or apostrophes at the ends: a Russian compound cut
    /// short by a space, its first half and the hyphen, is not a word.
    static func trimmed(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet(charactersIn: "-'"))
    }

    /// Whether the word is already in the vocabulary.
    public func contains(_ word: String) -> Bool {
        entries[Self.trimmed(word).lowercased()] != nil
    }

    /// Count one use of `word` at `now`.
    public mutating func record(_ word: String, isOwnWord: Bool, at now: Date = Date()) {
        let word = Self.trimmed(word)
        guard Self.isLearnable(word) else { return }
        let key = word.lowercased()
        if var entry = entries[key] {
            entry.score = entry.score(at: now) + 1
            entry.lastUsed = now
            entry.isOwnWord = entry.isOwnWord || isOwnWord
            entries[key] = entry
        } else {
            entries[key] = Entry(word: word, score: 1, lastUsed: now, isOwnWord: isOwnWord)
        }
    }

    private static func isOffered(_ entry: Entry, at now: Date) -> Bool {
        entry.isPinned
            || entry.score(at: now) >= (entry.isOwnWord ? ownWordThreshold : frequentThreshold)
    }

    /// The words offered as suggestions, most used lately first.
    public func learnedWords(at now: Date = Date()) -> [String] {
        offered(at: now).map(\.word)
    }

    private func offered(at now: Date) -> [Entry] {
        entries.values
            .filter { Self.isOffered($0, at: now) }
            .map { ($0, $0.score(at: now)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.word < $1.0.word }
            .map(\.0)
    }

    /// Offered words starting with `partialWord` that save at least
    /// `minimumSaving` letters, most used lately first.
    public func suggestions(for partialWord: String, limit: Int, at now: Date = Date()) -> [String] {
        guard !partialWord.isEmpty, limit > 0 else { return [] }
        let prefix = partialWord.lowercased()
        return Array(offered(at: now)
            .map(\.word)
            .filter { $0.lowercased().hasPrefix(prefix) && $0.count - prefix.count >= Self.minimumSaving }
            .prefix(limit))
    }

    /// Replace the offered words with `words`, as edited by hand in Settings.
    /// A listed word is pinned, so it stays offered however rarely it is
    /// typed; an offered word left out is forgotten. Words not yet offered
    /// are kept counting.
    public mutating func setLearnedWords(_ words: [String], at now: Date = Date()) {
        let listed = Set(words.map { Self.trimmed($0).lowercased() })
        for (key, entry) in entries where Self.isOffered(entry, at: now) && !listed.contains(key) {
            entries[key] = nil
        }
        for word in words.map(Self.trimmed) where Self.isLearnable(word) {
            let key = word.lowercased()
            if var entry = entries[key] {
                entry.isPinned = true
                entries[key] = entry
            } else {
                entries[key] = Entry(word: word, score: 0, lastUsed: now, isOwnWord: true, isPinned: true)
            }
        }
    }

    /// Drop words whose score has all but run out.
    public mutating func forgetFaded(at now: Date = Date()) {
        entries = entries.filter { $0.value.isPinned || $0.value.score(at: now) >= Self.forgetBelow }
    }

    /// The user's words first, then the system's, without repeating a word,
    /// up to `limit`.
    public static func merge(user: [String], system: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for word in user + system where seen.insert(word.lowercased()).inserted {
            merged.append(word)
            if merged.count == limit { break }
        }
        return merged
    }
}

/// Keeps the vocabulary in a JSON file.
public final class UserVocabularyStore {

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The saved vocabulary, or an empty one if there is none or it is unreadable.
    public func load() -> UserVocabulary {
        guard let data = try? Data(contentsOf: fileURL),
              let vocabulary = try? JSONDecoder().decode(UserVocabulary.self, from: data) else {
            return UserVocabulary()
        }
        return vocabulary
    }

    public func save(_ vocabulary: UserVocabulary) {
        guard let data = try? JSONEncoder().encode(vocabulary) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
