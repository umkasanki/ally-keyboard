//
//  LayoutStore.swift
//  AllyKeyboardCore
//
//  The user's layouts on disk, one JSON file each, and the rules that keep a
//  bad file from ever leaving the user without a keyboard. See
//  docs/layouts-plan.md, "Storage" and "Never locked out".
//

import Foundation

// MARK: - Validation

extension KeyboardLayout {

    public enum Problem: Equatable {
        /// Not a keyboard at all — nothing on it does anything: refused.
        case noKeys
        /// Usable, but typing will be hard without it.
        case missing(SpecialKey)
    }

    /// What is wrong with the layout. `noKeys` makes it unusable; the
    /// `missing` ones are warnings, shown but not enforced — a layout for one
    /// narrow job may leave them out on purpose.
    public var problems: [Problem] {
        let actions = rows.flatMap { $0 }.map(\.action)
        guard actions.contains(where: { $0 != .spacer && $0 != .blank }) else { return [.noKeys] }
        return [SpecialKey.space, .backspace, .returnKey]
            .filter { !actions.contains(.key($0)) }
            .map { .missing($0) }
    }

    public var isUsable: Bool { !problems.contains(.noKeys) }

    /// Each row's width in key widths, gaps included as the keyboard draws them.
    public var rowWidths: [Double] { rows.map { $0.reduce(0) { $0 + $1.width } } }

    /// Whether rows differ in width — to a millionth of a key, so sums of
    /// fractions that are equal (1.1 + 2.2 and 3.3) count as equal.
    public var rowsAreUneven: Bool {
        Set(rowWidths.filter { $0 > 0 }.map { ($0 * 1_000_000).rounded() }).count > 1
    }

    public var isStandard: Bool { id == KeyboardLayout.standardID }
}

// MARK: - Switching

extension KeyboardLayout {

    /// The layout after `current` in `layouts`, wrapping round; Standard if
    /// `current` is not among them.
    public static func next(after current: UUID, in layouts: [KeyboardLayout]) -> KeyboardLayout {
        guard let i = layouts.firstIndex(where: { $0.id == current }) else {
            return layouts.first(where: \.isStandard) ?? .standard
        }
        return layouts[(i + 1) % layouts.count]
    }
}

// MARK: - Store

/// Layouts kept as `<id>.json` in one folder.
///
/// The built-ins (Standard, Standard Multilingual, Extended) are always there:
/// from the factory, or as the user edited them (a file with a built-in's id
/// overrides the factory one; deleting that file — "Reset to factory" — brings
/// the original back).
///
/// Files are written by hand too, so reading is forgiving and never
/// destructive: a file that cannot be read, or has no keys, is skipped —
/// never half-loaded — and set aside as `<name>.unreadable.json` only when
/// asked (`setAsideUnreadable`, at launch and on Reload), never by a read made
/// to fill a menu while someone is mid-edit. A file from a newer version of
/// the app is left alone: skipped, not set aside, never written over. Two
/// files with one id show once, the one named after the id winning; deleting
/// the id removes them all.
public final class LayoutStore {

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".json")
    }

    /// What one file in the folder holds.
    private enum Entry {
        case layout(KeyboardLayout, URL)
        case newer(UUID?, URL)
        case unreadable(URL)
    }

    /// The folder's layout files, the ones named after their id first.
    private func entries() -> [Entry] {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".unreadable.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let entries: [Entry] = files.map { file in
            guard let data = try? Data(contentsOf: file) else { return .unreadable(file) }
            if let header = try? JSONDecoder().decode(Header.self, from: data),
               (header.formatVersion ?? 0) > KeyboardLayout.currentFormatVersion {
                return .newer(header.id, file)
            }
            guard let layout = try? JSONDecoder().decode(KeyboardLayout.self, from: data), layout.isUsable
            else { return .unreadable(file) }
            return .layout(layout, file)
        }
        func canonical(_ e: Entry) -> Bool {
            if case .layout(let l, let f) = e { return f.lastPathComponent == l.id.uuidString + ".json" }
            return false
        }
        return entries.filter(canonical) + entries.filter { !canonical($0) }
    }

    private struct Header: Decodable { var id: UUID?; var formatVersion: Int? }

    /// Every layout: the built-ins first, then the user's by name.
    public func loadAll() -> [KeyboardLayout] {
        var builtIns = KeyboardLayout.builtIns
        var others: [KeyboardLayout] = []
        var seen = Set<UUID>()
        for case .layout(let layout, _) in entries() where seen.insert(layout.id).inserted {
            if let i = builtIns.firstIndex(where: { $0.id == layout.id }) {
                builtIns[i] = layout
            } else {
                others.append(layout)
            }
        }
        others.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return builtIns + others
    }

    /// Move files that cannot be read out of the way, as
    /// `<name>.unreadable.json`; the names moved.
    @discardableResult
    public func setAsideUnreadable() -> [String] {
        entries().compactMap { entry in
            guard case .unreadable(let file) = entry else { return nil }
            let aside = file.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: file, to: aside)
            return file.lastPathComponent
        }
    }

    /// Whether a built-in has been edited, so there is a factory one to go back to.
    public func isEdited(_ id: UUID) -> Bool {
        guard let factory = KeyboardLayout.builtIn(id: id) else { return false }
        return loadAll().first { $0.id == id } != factory
    }

    /// The layout with this id, or Standard when there is none — the keyboard
    /// always gets something to show.
    public func layout(id: UUID?) -> KeyboardLayout {
        let all = loadAll()
        return all.first { $0.id == id } ?? all[0]
    }

    /// Write a layout. Refused if it has no keys, or if a newer version of the
    /// app keeps a file for it, which this one would write over without what
    /// it does not know.
    @discardableResult
    public func save(_ layout: KeyboardLayout) -> Bool {
        guard layout.isUsable else { return false }
        let newer = entries().contains { if case .newer(layout.id?, _) = $0 { return true }; return false }
        guard !newer, let data = try? layout.encoded() else { return false }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try? data.write(to: url(for: layout.id), options: .atomic)) != nil
    }

    /// Delete a user layout — every file holding it. For a built-in this is
    /// "Reset to factory".
    public func delete(id: UUID) {
        let all = entries()
        for case .layout(let layout, let file) in all where layout.id == id {
            try? FileManager.default.removeItem(at: file)
        }
        // `<id>.json` once more, whatever is in it — unless a newer version
        // keeps it, which is never written over, nor deleted.
        let own = url(for: id)
        // By name: the folder's listing and `url(for:)` may spell the path differently.
        let newer = all.contains {
            if case .newer(_, let file) = $0 { return file.lastPathComponent == own.lastPathComponent }
            return false
        }
        if !newer { try? FileManager.default.removeItem(at: own) }
    }

    /// A copy of a layout under a new id and name, saved; nil if it could not be.
    @discardableResult
    public func duplicate(_ layout: KeyboardLayout, name: String) -> KeyboardLayout? {
        var copy = layout
        copy.id = UUID()
        copy.name = name
        return save(copy) ? copy : nil
    }
}
