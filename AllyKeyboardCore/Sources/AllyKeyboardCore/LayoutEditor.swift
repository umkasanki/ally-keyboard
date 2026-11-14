//
//  LayoutEditor.swift
//  AllyKeyboardCore
//
//  The layout editor's model: a working copy of a layout, the selected key,
//  every edit as an operation, and Undo/Redo. The editor window only calls
//  this — what an edit does is decided and tested here. See
//  docs/layouts-plan.md, "Editor".
//

import Foundation

/// A key's place in a layout: its row, and its index in that row.
public struct KeyPosition: Hashable {
    public var row: Int
    public var index: Int

    public init(row: Int, index: Int) {
        self.row = row
        self.index = index
    }
}

public final class LayoutEditor {

    public enum Problem: Equatable {
        case layout(KeyboardLayout.Problem)
        /// Rows of different widths, in key widths: the keyboard is as wide as
        /// its widest row, so the others end short of the right edge.
        case unevenRows([Double])
    }

    public static let widthRange: ClosedRange<Double> = 0.5...10
    public static let fontScaleRange: ClosedRange<Double> = 0.5...2
    /// Width and font size move in quarter steps: fine enough to line rows
    /// up, coarse enough to reach a value with a few clicks.
    public static let step = 0.25

    /// The layout as edited so far.
    public private(set) var layout: KeyboardLayout
    /// The layout as last saved (or as opened).
    public private(set) var saved: KeyboardLayout
    public private(set) var selection: KeyPosition?

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    private struct Snapshot {
        var layout: KeyboardLayout
        var selection: KeyPosition?
    }

    public init(layout: KeyboardLayout) {
        self.layout = layout
        self.saved = layout
    }

    // MARK: - State

    public var hasUnsavedChanges: Bool { layout != saved }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var selectedKey: KeySpec? {
        selection.map { layout.rows[$0.row][$0.index] }
    }

    /// Each row's width in key widths, gaps included as the keyboard draws them.
    public var rowWidths: [Double] {
        layout.rows.map { $0.reduce(0) { $0 + $1.width } }
    }

    public var problems: [Problem] {
        var all = layout.problems.map(Problem.layout)
        let widths = rowWidths.filter { $0 > 0 }
        if Set(widths).count > 1 { all.append(.unevenRows(rowWidths)) }
        return all
    }

    /// Whether the layout can be saved at all.
    public var canSave: Bool { layout.isUsable }

    // MARK: - Selection

    /// Select a key, or nothing. A position the layout has no key at selects
    /// nothing.
    public func select(_ position: KeyPosition?) {
        guard let p = position, isValid(p) else { selection = nil; return }
        selection = p
    }

    private func isValid(_ p: KeyPosition) -> Bool {
        layout.rows.indices.contains(p.row) && layout.rows[p.row].indices.contains(p.index)
    }

    // MARK: - Saving

    /// The layout has been written: it is the saved state from now on. Undo
    /// still reaches back past it.
    public func markSaved() { saved = layout }

    /// Drop every edit since the last save.
    public func revert() {
        guard hasUnsavedChanges else { return }
        change { $0 = saved }
        select(selection)
    }

    // MARK: - Undo

    public func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(Snapshot(layout: layout, selection: selection))
        layout = last.layout
        selection = last.selection
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(layout: layout, selection: selection))
        layout = next.layout
        selection = next.selection
    }

    /// Apply an edit as one undoable step; an edit that changes nothing is
    /// not recorded.
    private func change(selecting newSelection: KeyPosition?? = .none,
                        _ edit: (inout KeyboardLayout) -> Void) {
        var edited = layout
        edit(&edited)
        let selected: KeyPosition? = newSelection ?? selection
        guard edited != layout || selected != selection else { return }
        undoStack.append(Snapshot(layout: layout, selection: selection))
        redoStack.removeAll()
        layout = edited
        selection = selected
    }

    /// Edit the selected key, if there is one.
    private func changeSelected(_ edit: (inout KeySpec) -> Void) {
        guard let p = selection else { return }
        change { edit(&$0.rows[p.row][p.index]) }
    }

    // MARK: - The layout

    public func rename(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        change { $0.name = name }
    }

    // MARK: - The selected key

    public func setAction(_ action: KeyAction) {
        changeSelected { $0.action = action }
    }

    /// Give the selected key a palette entry: its action and its look —
    /// label, corner label, icon, colour — keeping the key's width and font
    /// size, which belong to where it stands.
    public func assign(_ choice: ActionChoice) {
        changeSelected {
            let width = $0.width, fontScale = $0.fontScale
            $0 = choice.key
            $0.width = width
            $0.fontScale = fontScale
        }
    }

    /// nil or empty shows the action's own name.
    public func setLabel(_ label: String?) {
        changeSelected { $0.label = (label?.isEmpty ?? true) ? nil : label }
    }

    public func setSecondary(_ text: String?) {
        changeSelected { $0.secondary = (text?.isEmpty ?? true) ? nil : text }
    }

    public func setIcon(_ icon: String?) {
        changeSelected { $0.icon = (icon?.isEmpty ?? true) ? nil : icon }
    }

    public func setColored(_ colored: Bool) {
        changeSelected { $0.colored = colored }
    }

    public func setWidth(_ width: Double) {
        changeSelected { $0.width = Self.snapped(width, to: Self.widthRange) }
    }

    /// One `step` wider (+1) or narrower (-1).
    public func adjustWidth(by steps: Int) {
        guard let key = selectedKey else { return }
        setWidth(key.width + Double(steps) * Self.step)
    }

    public func setFontScale(_ scale: Double) {
        changeSelected { $0.fontScale = Self.snapped(scale, to: Self.fontScaleRange) }
    }

    public func adjustFontScale(by steps: Int) {
        guard let key = selectedKey else { return }
        setFontScale(key.fontScale + Double(steps) * Self.step)
    }

    private static func snapped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        let quarter = (value / step).rounded() * step
        return min(max(quarter, range.lowerBound), range.upperBound)
    }

    // MARK: - Structure

    /// Move the selected key one place left (-1) or right (+1) in its row.
    public func moveAlongRow(by offset: Int) {
        guard let p = selection else { return }
        let target = KeyPosition(row: p.row, index: p.index + offset)
        guard isValid(target) else { return }
        change(selecting: target) { $0.rows[p.row].swapAt(p.index, target.index) }
    }

    /// Move the selected key to the row above (-1) or below (+1), to where it
    /// stands across the keyboard: under the key that starts nearest its own
    /// left edge.
    public func moveToRow(by offset: Int) {
        guard let p = selection else { return }
        let targetRow = p.row + offset
        guard layout.rows.indices.contains(targetRow) else { return }
        let x = start(of: p)
        let target = layout.rows[targetRow]
        var index = target.count
        var edge = 0.0
        for (i, key) in target.enumerated() {
            if edge + key.width / 2 > x { index = i; break }
            edge += key.width
        }
        // A row left empty is removed, which moves the rows below it up one.
        let sourceEmpties = layout.rows[p.row].count == 1
        let landingRow = sourceEmpties && targetRow > p.row ? targetRow - 1 : targetRow
        change(selecting: KeyPosition(row: landingRow, index: index)) {
            let key = $0.rows[p.row].remove(at: p.index)
            $0.rows[targetRow].insert(key, at: index)
            if $0.rows[p.row].isEmpty { $0.rows.remove(at: p.row) }
        }
    }

    /// Where a key starts, in key widths from the left edge.
    public func start(of p: KeyPosition) -> Double {
        layout.rows[p.row].prefix(p.index).reduce(0) { $0 + $1.width }
    }

    /// Exchange the selected key with another; the selection follows the key.
    public func swapSelected(with other: KeyPosition) {
        guard let p = selection, isValid(other), other != p else { return }
        change(selecting: other) {
            let a = $0.rows[p.row][p.index]
            $0.rows[p.row][p.index] = $0.rows[other.row][other.index]
            $0.rows[other.row][other.index] = a
        }
    }

    /// A blank key beside the selected one — to the right if `after` — selected.
    public func insertKey(after: Bool) {
        guard let p = selection else { return }
        let index = after ? p.index + 1 : p.index
        change(selecting: KeyPosition(row: p.row, index: index)) {
            $0.rows[p.row].insert(KeySpec(.blank), at: index)
        }
    }

    /// Delete the selected key; the one after it (or before, at the end) is
    /// selected. A row left empty goes with it.
    public func deleteKey() {
        guard let p = selection else { return }
        var next: KeyPosition?
        let rowCount = layout.rows[p.row].count
        if rowCount > 1 {
            next = KeyPosition(row: p.row, index: min(p.index, rowCount - 2))
        }
        change(selecting: .some(next)) {
            $0.rows[p.row].remove(at: p.index)
            if $0.rows[p.row].isEmpty { $0.rows.remove(at: p.row) }
        }
    }

    /// A new row of one blank key above or below the selected key's row (or
    /// at the bottom with nothing selected); its key is selected.
    public func addRow(below: Bool) {
        let row = selection.map { below ? $0.row + 1 : $0.row } ?? layout.rows.count
        change(selecting: KeyPosition(row: row, index: 0)) {
            $0.rows.insert([KeySpec(.blank)], at: row)
        }
    }

    /// Delete the selected key's row.
    public func deleteRow() {
        guard let p = selection else { return }
        change(selecting: .some(nil)) { $0.rows.remove(at: p.row) }
    }
}
