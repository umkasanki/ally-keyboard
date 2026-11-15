//
//  NextWords.swift
//  AllyKeyboardCore
//
//  Which word the user writes after which: learned from the words they finish
//  on the keyboard, and offered, before a letter of the next one is typed, as
//  the words likely to come next — so a phrase used often can be finished by
//  picking word after word. Statistics, not meaning: only the word before
//  counts, as in Hot Virtual Keyboard's and KeyStrokes' next-word prediction.
//

import Foundation

public struct NextWords: Codable, Equatable {

    public struct Entry: Codable, Equatable {
        /// The next word, in the spelling it was last typed in lowercase, or
        /// as first typed.
        public var word: String
        /// Uses, decayed to `lastUsed`, as `UserVocabulary` scores them.
        public var score: Double
        public var lastUsed: Date

        public init(word: String, score: Double, lastUsed: Date) {
            self.word = word
            self.score = score
            self.lastUsed = lastUsed
        }

        public func score(at now: Date) -> Double {
            let idle = max(0, now.timeIntervalSince(lastUsed))
            return score * pow(0.5, idle / NextWords.halfLife)
        }
    }

    /// Unused this long, a pair's score halves.
    public static let halfLife = UserVocabulary.halfLife
    /// About two recent uses: the pair is offered. Once could be a slip.
    public static let offerAt = 1.5
    /// Below this a pair is as good as forgotten and is dropped.
    static let forgetBelow = 0.1
    /// The most next words kept after one word; the weakest go first.
    static let keptPerWord = 30

    /// Keyed by the lowercased word before, then by the lowercased next word.
    public private(set) var pairs: [String: [String: Entry]] = [:]

    public init() {}

    /// A word worth pairing: it has a letter. Short words count — "I am",
    /// "in it" — they are much of what a phrase is made of.
    public static func isPairable(_ word: String) -> Bool {
        word.contains(where: \.isLetter)
    }

    private static func key(_ word: String) -> String {
        UserVocabulary.trimmed(word).lowercased()
    }

    /// Count `next` once after `previous`.
    public mutating func record(_ next: String, after previous: String, at now: Date = Date()) {
        let next = UserVocabulary.trimmed(next)
        guard Self.isPairable(previous), Self.isPairable(next) else { return }
        let before = Self.key(previous), key = next.lowercased()
        var followers = pairs[before] ?? [:]
        if var entry = followers[key] {
            entry.score = entry.score(at: now) + 1
            entry.lastUsed = now
            if next.first?.isLowercase == true { entry.word = next }
            followers[key] = entry
        } else {
            followers[key] = Entry(word: next, score: 1, lastUsed: now)
        }
        if followers.count > Self.keptPerWord {
            let weakest = followers.min { $0.value.score(at: now) < $1.value.score(at: now) }!.key
            followers[weakest] = nil
        }
        pairs[before] = followers
    }

    /// The words offered after `previous`, most used lately first.
    public func suggestions(after previous: String, limit: Int, at now: Date = Date()) -> [String] {
        guard limit > 0, let followers = pairs[Self.key(previous)] else { return [] }
        let scored: [(word: String, score: Double)] = followers.values
            .map { (word: $0.word, score: $0.score(at: now)) }
            .filter { $0.score >= Self.offerAt }
        let sorted = scored.sorted { a, b in a.score != b.score ? a.score > b.score : a.word < b.word }
        return sorted.prefix(limit).map(\.word)
    }

    /// What is written to disk: only the pairs offered now. A pair met once —
    /// which may be anything at all — lives in memory only.
    public func persisted(at now: Date = Date()) -> NextWords {
        var copy = self
        copy.pairs = pairs.compactMapValues { followers in
            let kept = followers.filter { $0.value.score(at: now) >= Self.offerAt }
            return kept.isEmpty ? nil : kept
        }
        return copy
    }

    /// Drop pairs whose score has all but run out.
    public mutating func forgetFaded(at now: Date = Date()) {
        pairs = pairs.compactMapValues { followers in
            let kept = followers.filter { $0.value.score(at: now) >= Self.forgetBelow }
            return kept.isEmpty ? nil : kept
        }
    }

    /// How many pairs are offered now — for Settings.
    public func offeredCount(at now: Date = Date()) -> Int {
        pairs.values.reduce(0) { $0 + $1.values.filter { $0.score(at: now) >= Self.offerAt }.count }
    }
}

/// Keeps a value as a JSON file. One that cannot be read is moved aside, not
/// overwritten by the next save, as `UserVocabularyStore` does.
public final class JSONFileStore<Value: Codable> {

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> Value? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        if let value = try? JSONDecoder().decode(Value.self, from: data) { return value }
        let aside = fileURL.deletingPathExtension().appendingPathExtension("unreadable.json")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: fileURL, to: aside)
        return nil
    }

    public func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
