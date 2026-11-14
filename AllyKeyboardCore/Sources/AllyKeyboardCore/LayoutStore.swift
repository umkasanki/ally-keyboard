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
        /// Not a keyboard at all: refused.
        case noKeys
        /// Usable, but typing will be hard without it.
        case missing(SpecialKey)
    }

    /// What is wrong with the layout. `noKeys` makes it unusable; the
    /// `missing` ones are warnings, shown but not enforced — a layout for one
    /// narrow job may leave them out on purpose.
    public var problems: [Problem] {
        let actions = rows.flatMap { $0 }.map(\.action)
        guard actions.contains(where: { $0 != .spacer }) else { return [.noKeys] }
        return [SpecialKey.space, .backspace, .returnKey]
            .filter { !actions.contains(.key($0)) }
            .map { .missing($0) }
    }

    public var isUsable: Bool { !problems.contains(.noKeys) }

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
/// The built-ins (Standard, Extended) are always there: from the factory, or
/// as the user edited them (a file with a built-in's id overrides the factory
/// one; deleting that file — "Reset to factory" — brings the original back). A file that cannot be read, or that
/// has no keys, is moved aside as `<name>.unreadable.json`, never half-loaded
/// and never left to break the next launch.
public final class LayoutStore {

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".json")
    }

    /// Every layout: the built-ins first, then the user's by name.
    public func loadAll() -> [KeyboardLayout] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var builtIns = KeyboardLayout.builtIns
        var others: [KeyboardLayout] = []
        for file in files where file.pathExtension == "json" && !file.lastPathComponent.hasSuffix(".unreadable.json") {
            guard let data = try? Data(contentsOf: file),
                  let layout = try? JSONDecoder().decode(KeyboardLayout.self, from: data),
                  layout.isUsable else {
                moveAside(file)
                continue
            }
            if let i = builtIns.firstIndex(where: { $0.id == layout.id }) {
                builtIns[i] = layout
            } else {
                others.append(layout)
            }
        }
        others.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return builtIns + others
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

    /// Write a layout. Refused if it has no keys.
    @discardableResult
    public func save(_ layout: KeyboardLayout) -> Bool {
        guard layout.isUsable else { return false }
        guard let data = try? layout.encoded() else { return false }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try? data.write(to: url(for: layout.id), options: .atomic)) != nil
    }

    /// Delete a user layout. For a built-in this is "Reset to factory".
    public func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// A copy of a layout under a new id and name, saved.
    @discardableResult
    public func duplicate(_ layout: KeyboardLayout, name: String) -> KeyboardLayout {
        var copy = layout
        copy.id = UUID()
        copy.name = name
        save(copy)
        return copy
    }

    private func moveAside(_ file: URL) {
        let aside = file.deletingPathExtension().appendingPathExtension("unreadable.json")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: file, to: aside)
    }
}
