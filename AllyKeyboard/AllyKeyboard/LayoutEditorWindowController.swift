//
//  LayoutEditorWindowController.swift
//  AllyKeyboard
//
//  The layout editor's window. Every edit goes through `LayoutEditor` (Core,
//  tested); this file only lays out controls and calls it. Everything is a
//  single click on a large button — no drag and drop, no double clicks,
//  nothing shown only on hover — since it is used with a head mouse. See
//  docs/layouts-plan.md, "Editor".
//

import AppKit
import AllyKeyboardCore

final class LayoutEditorWindowController: NSWindowController, NSWindowDelegate {

    private let store: LayoutStore
    /// Told after a layout was saved or deleted, so the keyboard can follow.
    private let onSaved: (KeyboardLayout) -> Void
    private let onDeleted: (UUID) -> Void

    private var editor: LayoutEditor
    /// Swap was pressed: the next key clicked is swapped with the selected one.
    private var swapPending = false

    private let layoutPopup = NSPopUpButton()
    private let preview = LayoutPreviewView()
    private let problemsLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    private var undoButton: NSButton!, redoButton: NSButton!, saveButton: NSButton!, revertButton: NSButton!
    private var deleteButton: NSButton!, swapButton: NSButton!
    /// Buttons that act on the selected key, enabled only with one.
    private var keyButtons: [NSButton] = []

    init(store: LayoutStore, open layoutID: UUID,
         onSaved: @escaping (KeyboardLayout) -> Void, onDeleted: @escaping (UUID) -> Void) {
        self.store = store
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        editor = LayoutEditor(layout: store.layout(id: layoutID))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 560),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Layout Editor"
        window.isReleasedWhenClosed = false
        // Under the keyboard, over other applications' windows: the keyboard
        // stays at hand above the editor, and the editor's own dialogs go
        // above both (see `run(_:)`).
        window.level = .floating
        super.init(window: window)
        window.delegate = self
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout of the window

    private func button(_ title: String, _ action: Selector, symbol: String? = nil) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        b.font = .systemFont(ofSize: 14)
        if let symbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
            b.image = image
            b.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        }
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        return b
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.spacing = 8
        s.alignment = .centerY
        return s
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        layoutPopup.target = self
        layoutPopup.action = #selector(layoutChosen)
        layoutPopup.controlSize = .large
        layoutPopup.font = .systemFont(ofSize: 14)

        undoButton = button("Undo", #selector(undo), symbol: "arrow.uturn.backward")
        redoButton = button("Redo", #selector(redo), symbol: "arrow.uturn.forward")
        revertButton = button("Revert", #selector(revert))
        saveButton = button("Save", #selector(save))
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        deleteButton = button("Delete…", #selector(deleteOrReset))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let top = row([layoutPopup,
                       button("New", #selector(newLayout)),
                       button("Duplicate", #selector(duplicate)),
                       button("Rename…", #selector(rename)),
                       deleteButton,
                       spacer, undoButton, redoButton, revertButton, saveButton])

        preview.onClick = { [weak self] position in self?.clicked(position) }

        swapButton = button("Swap", #selector(swapKeys), symbol: "arrow.left.arrow.right")
        keyButtons = [
            button("", #selector(nudgeLeft), symbol: "arrow.left"),
            button("", #selector(nudgeRight), symbol: "arrow.right"),
            button("", #selector(nudgeUp), symbol: "arrow.up"),
            button("", #selector(nudgeDown), symbol: "arrow.down"),
            swapButton,
            button("Insert Left", #selector(insertLeft)),
            button("Insert Right", #selector(insertRight)),
            button("Delete Key", #selector(deleteSelectedKey)),
            button("Row Above", #selector(rowAbove)),
            button("Row Below", #selector(rowBelow)),
            button("Delete Row", #selector(deleteRow)),
        ]
        let structure = row(keyButtons)

        problemsLabel.textColor = .systemOrange
        problemsLabel.font = .systemFont(ofSize: 13)
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [top, preview, structure, statusLabel, problemsLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            top.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
        ])
    }

    // MARK: - Showing the state

    private func refresh() {
        reloadPopup()
        preview.layout = editor.layout
        preview.selection = editor.selection
        undoButton.isEnabled = editor.canUndo
        redoButton.isEnabled = editor.canRedo
        saveButton.isEnabled = editor.hasUnsavedChanges && editor.canSave
        revertButton.isEnabled = editor.hasUnsavedChanges
        keyButtons.forEach { $0.isEnabled = editor.selection != nil }
        swapButton.state = swapPending ? .on : .off

        if editor.layout.isBuiltIn {
            deleteButton.title = "Reset to Factory"
            deleteButton.isEnabled = store.isEdited(editor.layout.id) || editor.hasUnsavedChanges
        } else {
            deleteButton.title = "Delete…"
            deleteButton.isEnabled = true
        }

        window?.title = "Layout Editor — \(editor.layout.name)" + (editor.hasUnsavedChanges ? " (edited)" : "")
        statusLabel.stringValue = swapPending ? "Click the key to swap it with."
            : editor.selection == nil ? "Click a key to select it." : selectedDescription()
        problemsLabel.stringValue = editor.problems.map(describe).joined(separator: "   ")
    }

    private func selectedDescription() -> String {
        guard let key = editor.selectedKey, let p = editor.selection else { return "" }
        return "Row \(p.row + 1), key \(p.index + 1): \(key.action.legacyID), width \(key.width)"
    }

    private func describe(_ problem: LayoutEditor.Problem) -> String {
        switch problem {
        case .layout(.noKeys): return "The layout has no keys and cannot be saved."
        case .layout(.missing(let key)): return "No \(key.rawValue) key."
        case .unevenRows: return "Rows are not the same width (see the numbers at the right)."
        }
    }

    private func reloadPopup() {
        layoutPopup.removeAllItems()
        for layout in store.loadAll() {
            let edited = layout.isBuiltIn && store.isEdited(layout.id) ? " (edited)" : ""
            layoutPopup.addItem(withTitle: layout.name + edited)
            layoutPopup.lastItem?.representedObject = layout.id
        }
        if let i = layoutPopup.itemArray.firstIndex(where: { ($0.representedObject as? UUID) == editor.layout.id }) {
            layoutPopup.selectItem(at: i)
        }
    }

    // MARK: - Dialogs

    /// Show a dialog above the keyboard. `runModal` puts an alert at the
    /// system's modal level, under the keyboard and anything above it, so it
    /// could not be reached without moving them; raised again once it is up,
    /// it stays raised (checked on the device, 2026-11-14).
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let raise = Timer(timeInterval: 0, repeats: false) { _ in
            alert.window.level = NSWindow.Level(rawValue: AppConfig.Levels.keyboard.rawValue + 2)
        }
        RunLoop.main.add(raise, forMode: .modalPanel)
        return alert.runModal()
    }

    // MARK: - Choosing what to edit

    /// Open another layout, asking about unsaved edits first.
    private func open(_ id: UUID) {
        guard confirmLeavingEdits() else { refresh(); return }
        editor = LayoutEditor(layout: store.layout(id: id))
        swapPending = false
        refresh()
    }

    @objc private func layoutChosen() {
        guard let id = layoutPopup.selectedItem?.representedObject as? UUID, id != editor.layout.id else { return }
        open(id)
    }

    /// Save, discard, or stay. False means stay.
    private func confirmLeavingEdits() -> Bool {
        guard editor.hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "Save the changes to \u{201C}\(editor.layout.name)\u{201D}?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don\u{2019}t Save")
        alert.addButton(withTitle: "Cancel")
        switch run(alert) {
        case .alertFirstButtonReturn: return save()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { confirmLeavingEdits() }

    // MARK: - Layout actions

    @discardableResult
    @objc private func save() -> Bool {
        guard editor.canSave, store.save(editor.layout) else { NSSound.beep(); return false }
        editor.markSaved()
        onSaved(editor.layout)
        refresh()
        return true
    }

    @objc private func revert() { editor.revert(); refresh() }
    @objc private func undo() { editor.undo(); refresh() }
    @objc private func redo() { editor.redo(); refresh() }

    @objc private func newLayout() {
        guard confirmLeavingEdits() else { return }
        // A start that can already type a little: Backspace, Space, Return.
        let layout = KeyboardLayout(name: uniqueName("New Layout"), rows: [[
            KeySpec(.key(.backspace), icon: "delete.backward", width: 1.5),
            KeySpec(.key(.space), label: "", width: 4),
            KeySpec(.key(.returnKey), icon: "return", width: 1.5),
        ]])
        store.save(layout)
        editor = LayoutEditor(layout: layout)
        refresh()
    }

    @objc private func duplicate() {
        guard confirmLeavingEdits() else { return }
        let copy = store.duplicate(editor.saved, name: uniqueName(editor.saved.name + " copy"))
        editor = LayoutEditor(layout: copy)
        refresh()
    }

    private func uniqueName(_ base: String) -> String {
        let taken = Set(store.loadAll().map(\.name))
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    @objc private func rename() {
        let alert = NSAlert()
        alert.messageText = "Rename the layout"
        let field = NSTextField(string: editor.layout.name)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 28)
        field.font = .systemFont(ofSize: 15)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard run(alert) == .alertFirstButtonReturn else { return }
        editor.rename(field.stringValue)
        refresh()
    }

    @objc private func deleteOrReset() {
        let layout = editor.layout
        let alert = NSAlert()
        if layout.isBuiltIn {
            alert.messageText = "Reset \u{201C}\(layout.name)\u{201D} to how it came?"
            alert.informativeText = "Your changes to it are lost."
            alert.addButton(withTitle: "Reset")
        } else {
            alert.messageText = "Delete \u{201C}\(layout.name)\u{201D}?"
            alert.informativeText = "It cannot be brought back."
            alert.addButton(withTitle: "Delete")
        }
        alert.addButton(withTitle: "Cancel")
        guard run(alert) == .alertFirstButtonReturn else { return }
        store.delete(id: layout.id)
        onDeleted(layout.id)
        // A built-in comes back from the factory; a deleted layout gives way to Standard.
        editor = LayoutEditor(layout: store.layout(id: layout.isBuiltIn ? layout.id : KeyboardLayout.standardID))
        refresh()
    }

    // MARK: - Keys
    // Not named moveLeft, keyUp, deleteBackward and the like: NSResponder has those
    // for the arrow and delete keys, and these must not answer them.

    private func clicked(_ position: KeyPosition?) {
        if swapPending, let position {
            swapPending = false
            editor.swapSelected(with: position)
        } else {
            swapPending = false
            editor.select(position)
        }
        refresh()
    }

    @objc private func nudgeLeft() { editor.moveAlongRow(by: -1); refresh() }
    @objc private func nudgeRight() { editor.moveAlongRow(by: 1); refresh() }
    @objc private func nudgeUp() { editor.moveToRow(by: -1); refresh() }
    @objc private func nudgeDown() { editor.moveToRow(by: 1); refresh() }
    @objc private func swapKeys() { swapPending.toggle(); refresh() }
    @objc private func insertLeft() { editor.insertKey(after: false); refresh() }
    @objc private func insertRight() { editor.insertKey(after: true); refresh() }
    @objc private func deleteSelectedKey() { editor.deleteKey(); refresh() }
    @objc private func rowAbove() { editor.addRow(below: false); refresh() }
    @objc private func rowBelow() { editor.addRow(below: true); refresh() }
    @objc private func deleteRow() { editor.deleteRow(); refresh() }
}
