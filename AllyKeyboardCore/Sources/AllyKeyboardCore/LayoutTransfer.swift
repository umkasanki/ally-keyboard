//
//  LayoutTransfer.swift
//  AllyKeyboardCore
//
//  Layouts as files to pass around: `.allykeyboard-layout`, the same JSON the
//  store keeps. A file is read whole or not at all — one that cannot be read,
//  is from a newer version of the app, or has no keys is refused with a
//  message saying why, never half-loaded. An imported layout never replaces
//  one already here: it gets a new id when its own is taken, and a numbered
//  name when its name is.
//

import Foundation

extension KeyboardLayout {

    /// The file extension for exported layouts.
    public static let fileExtension = "allykeyboard-layout"

    /// Why a file was not imported. `message` is for the person importing.
    public enum ImportError: Error, Equatable {
        /// Not JSON, or JSON that is not a layout; `detail` says where.
        case unreadable(detail: String)
        /// Written by a newer version of the app, in a format this one does not know.
        case newerFormat(Int)
        /// A layout with nothing to press.
        case noKeys
        /// Read, but it could not be written into the layouts folder.
        case couldNotSave

        public var message: String {
            switch self {
            case .unreadable(let detail): return "The file is not a keyboard layout: \(detail)."
            case .newerFormat(let v):
                return "The layout was made by a newer version of AllyKeyboard (format \(v); this version reads up to \(KeyboardLayout.currentFormatVersion)). Update the app to import it."
            case .noKeys: return "The layout has no keys."
            case .couldNotSave: return "The layout could not be saved in the layouts folder."
            }
        }
    }

    /// The layout as a file's contents: readable, stable JSON (keys sorted,
    /// so two exports of one layout are the same bytes).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// A layout read from a file's contents, checked; throws `ImportError`.
    public static func decodeForImport(_ data: Data) throws -> KeyboardLayout {
        // The version first: a newer file may not decode at all, and "update
        // the app" is the useful thing to say then, not where decoding failed.
        if let header = try? JSONDecoder().decode(Header.self, from: data),
           let version = header.formatVersion, version > currentFormatVersion {
            throw ImportError.newerFormat(version)
        }
        let layout: KeyboardLayout
        do {
            layout = try JSONDecoder().decode(KeyboardLayout.self, from: data)
        } catch let error as DecodingError {
            throw ImportError.unreadable(detail: describe(error))
        } catch {
            throw ImportError.unreadable(detail: "it could not be read")
        }
        guard layout.isUsable else { throw ImportError.noKeys }
        return layout
    }

    private struct Header: Decodable { var formatVersion: Int? }

    /// Where decoding stopped, in words: "row 3, key 2: …".
    static func describe(_ error: DecodingError) -> String {
        func place(_ path: [CodingKey]) -> String {
            var parts: [String] = []
            var i = 0
            while i < path.count {
                let key = path[i]
                if key.stringValue == "rows" {
                    if i + 1 < path.count, let r = path[i + 1].intValue {
                        parts.append("row \(r + 1)")
                        if i + 2 < path.count, let k = path[i + 2].intValue {
                            parts.append("key \(k + 1)")
                            i += 1
                        }
                        i += 1
                    } else {
                        parts.append("rows")
                    }
                } else if key.intValue == nil {
                    parts.append("\u{201C}\(key.stringValue)\u{201D}")
                }
                i += 1
            }
            return parts.joined(separator: ", ")
        }
        func at(_ path: [CodingKey]) -> String {
            let p = place(path)
            return p.isEmpty ? "" : " (\(p))"
        }
        switch error {
        case .keyNotFound(let key, let ctx):
            return "\u{201C}\(key.stringValue)\u{201D} is missing" + at(ctx.codingPath)
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
            return "a value has the wrong type" + at(ctx.codingPath)
        case .dataCorrupted(let ctx):
            return ctx.codingPath.isEmpty ? "it is not valid JSON" : "a value is not understood" + at(ctx.codingPath)
        @unknown default:
            return "it could not be read"
        }
    }
}

extension LayoutStore {

    /// Read a file's contents and keep the layout, under a new id if its own
    /// is taken (a built-in's included: an import never overwrites) and a
    /// numbered name if its name is. Throws `KeyboardLayout.ImportError`.
    @discardableResult
    public func importLayout(from data: Data) throws -> KeyboardLayout {
        var layout = try KeyboardLayout.decodeForImport(data)
        let existing = loadAll()
        if existing.contains(where: { $0.id == layout.id }) { layout.id = UUID() }
        let names = Set(existing.map(\.name))
        if names.contains(layout.name) {
            var n = 2
            while names.contains("\(layout.name) \(n)") { n += 1 }
            layout.name = "\(layout.name) \(n)"
        }
        layout.formatVersion = KeyboardLayout.currentFormatVersion
        guard save(layout) else { throw KeyboardLayout.ImportError.couldNotSave }
        return layout
    }
}
