//
//  UserVocabulary.swift
//  AllyKeyboardCore
//
//  The user's own words: ones the system dictionary does not know, learned
//  from what is typed on the keyboard and offered among the suggestions.
//

import Foundation

/// Words the user has typed that the system dictionary lacks — names, jargon,
/// slang — with how often each was typed.
///
/// A word is only *offered* once it has been typed `minimumUses` times, so a
/// one-off typo is remembered but never suggested. Words are matched without
/// regard to case and kept in the spelling they were first typed in.
public struct UserVocabulary: Codable, Equatable {

    public struct Entry: Codable, Equatable {
        public var word: String
        public var uses: Int
    }

    /// Typed this many times before it is suggested.
    public static let minimumUses = 2
    /// Shorter words are not worth a suggestion and are mostly noise.
    public static let minimumLength = 3

    /// Keyed by the lowercased word.
    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    /// Whether `word` is worth remembering at all: long enough, and more than
    /// digits and punctuation.
    public static func isLearnable(_ word: String) -> Bool {
        word.count >= minimumLength && word.contains(where: \.isLetter)
    }

    /// Whether a finished word should be counted: one the system dictionary
    /// does not know, or any word with a hyphen inside — command names like
    /// ddev-client-start are made of dictionary words and would slip through a
    /// spelling check, and they are exactly the ones worth not typing twice.
    public static func shouldLearn(_ word: String, knownToSystem: Bool) -> Bool {
        let word = trimmed(word)
        return isLearnable(word) && (!knownToSystem || word.contains("-"))
    }

    /// Without hyphens or apostrophes at the ends: a Russian compound cut
    /// short by a space, its first half and the hyphen, is not a word.
    static func trimmed(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet(charactersIn: "-'"))
    }

    /// Whether the word is already in the vocabulary, learned or not yet.
    public func contains(_ word: String) -> Bool {
        entries[word.lowercased()] != nil
    }

    /// Count one more use of `word`.
    public mutating func record(_ word: String) {
        let word = Self.trimmed(word)
        guard Self.isLearnable(word) else { return }
        let key = word.lowercased()
        if var entry = entries[key] {
            entry.uses += 1
            entries[key] = entry
        } else {
            entries[key] = Entry(word: word, uses: 1)
        }
    }

    /// The words that are offered as suggestions, most used first.
    public var learnedWords: [String] {
        entries.values
            .filter { $0.uses >= Self.minimumUses }
            .sorted { $0.uses != $1.uses ? $0.uses > $1.uses : $0.word < $1.word }
            .map(\.word)
    }

    /// Learned words starting with `partialWord`, most used first, leaving out
    /// the word exactly as typed.
    public func suggestions(for partialWord: String, limit: Int) -> [String] {
        guard !partialWord.isEmpty, limit > 0 else { return [] }
        let prefix = partialWord.lowercased()
        return Array(learnedWords.filter {
            let lower = $0.lowercased()
            return lower.hasPrefix(prefix) && lower != prefix
        }.prefix(limit))
    }

    /// Replace the learned words with `words`, as edited by hand in Settings.
    /// A listed word becomes learned at once; a learned word left out is
    /// forgotten. Words still on their way to being learned are kept.
    public mutating func setLearnedWords(_ words: [String]) {
        let listed = Set(words.map { $0.lowercased() })
        for (key, entry) in entries where entry.uses >= Self.minimumUses && !listed.contains(key) {
            entries[key] = nil
        }
        for word in words where Self.isLearnable(word) {
            let key = word.lowercased()
            if var entry = entries[key] {
                entry.uses = max(entry.uses, Self.minimumUses)
                entries[key] = entry
            } else {
                entries[key] = Entry(word: word, uses: Self.minimumUses)
            }
        }
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
