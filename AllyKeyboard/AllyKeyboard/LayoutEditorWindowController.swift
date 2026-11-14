//
//  LayoutEditorWindowController.swift
//  AllyKeyboard
//
//  The layout editor's window: the keyboard as a whole. Its sizes and rows
//  are edited here, and keys are moved, swapped and deleted; one key's
//  action and look are edited in a dialog of their own (`KeyEditorDialog`),
//  opened by New Key… and Edit Key…. Every edit goes through `LayoutEditor`
//  (Core, tested). Everything is a single click on a large button — no drag
//  and drop, no double clicks, nothing shown only on hover — since it is used
//  with a head mouse. See docs/layouts-plan.md, "Editor".
//

import AppKit
import AllyKeyboardCore
import UniformTypeIdentifiers

final class LayoutEditorWindowController: NSWindowController, NSWindowDelegate, NSOpenSavePanelDelegate {

    private let store: LayoutStore
    /// Told after a layout was saved or deleted, so the keyboard can follow.
    private let onSaved: (KeyboardLayout) -> Void
    private let onDeleted: (UUID) -> Void

    private var editor: LayoutEditor
    /// Swap was pressed: the next key clicked is swapped with the selected
    /// one. Kept with the layout and selection it was pressed on, and dropped
    /// as soon as either changes (Undo, Delete Key, a new row…), so a click
    /// never swaps a key other than the one that was selected.
    private var swapFrom: (layout: KeyboardLayout, selection: KeyPosition)?
    private var swapPending: Bool { swapFrom != nil }

    private let layoutPopup = NSPopUpButton()
    private let preview = LayoutPreviewView()
    /// The status bar's lines: the hint first, then a line per warning.
    private let statusLines = NSStackView()
    private let rowsValue = NSTextField(labelWithString: "")

    private var undoButton: NSButton!, redoButton: NSButton!, saveButton: NSButton!, revertButton: NSButton!
    private var deleteButton: NSButton!, swapButton: NSButton!, deleteRowButton: NSButton!
    /// Buttons that act on the selected key, enabled only with one.
    private var keyButtons: [NSButton] = []
    /// The keyboard's sizes: each value shown between its − and + buttons.
    private var geometryValues: [LayoutEditor.GeometryField: NSTextField] = [:]

    init(store: LayoutStore, open layoutID: UUID,
         onSaved: @escaping (KeyboardLayout) -> Void, onDeleted: @escaping (UUID) -> Void) {
        self.store = store
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        editor = LayoutEditor(layout: store.layout(id: layoutID))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 500),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Layout Editor"
        window.isReleasedWhenClosed = false
        // Under the keyboard, over other applications' windows: the keyboard
        // stays at hand above the editor, and the editor's own dialogs go
        // above both (see `run(_:)` and `KeyEditorDialog`).
        window.level = .floating
        super.init(window: window)
        window.delegate = self
        buildUI()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        // Where it was if it is open already; centred the first time.
        if window?.isVisible != true { window?.center() }
        // Within the visible part of the screen — above the Dock, below the
        // menu bar — however the screen is set up.
        if let window, let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            var frame = window.frame
            frame.size.height = min(frame.height, visible.height)
            frame.size.width = min(frame.width, visible.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            window.setFrame(frame, display: false)
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout of the window

    /// `name` is what an image-only button is called to VoiceOver and Voice Control.
    private func button(_ title: String, _ action: Selector, symbol: String? = nil, name: String? = nil) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        if let name { b.setAccessibilityLabel(name) }
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

    private func row(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.spacing = spacing
        s.alignment = .centerY
        return s
    }

    private func column(_ views: [NSView], spacing: CGFloat = 6) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = spacing
        return s
    }

    private func heading(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 15, weight: .bold)
        return t
    }

    private func caption(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.textColor = .secondaryLabelColor
        t.widthAnchor.constraint(equalToConstant: 110).isActive = true
        return t
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
        deleteButton = button("Delete\u{2026}", #selector(deleteOrReset))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let top = row([layoutPopup,
                       button("New", #selector(newLayout)),
                       button("Duplicate", #selector(duplicate)),
                       button("Rename\u{2026}", #selector(rename)),
                       deleteButton,
                       button("Import\u{2026}", #selector(importLayout)),
                       button("Export\u{2026}", #selector(exportLayout)),
                       spacer, undoButton, redoButton, revertButton, saveButton])

        preview.onClick = { [weak self] position in self?.clicked(position) }
        preview.maximumSize = NSSize(width: 820, height: 330)

        let middle = row([preview, makeKeyboardPanel()], spacing: 24)
        middle.alignment = .top

        let stack = column([top, middle, makeKeysPanel()], spacing: 16)
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        let statusBar = makeStatusBar()
        content.addSubview(statusBar)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            top.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        // As tall as what it holds, no taller: nothing hangs in empty space.
        content.layoutSubtreeIfNeeded()
        window?.setContentSize(NSSize(width: content.frame.width, height: content.fittingSize.height))
    }

    /// The strip along the bottom edge, as in Finder: a column in the middle —
    /// the hint (what is selected, what to do) marked ⓘ, and under it a line
    /// per error, marked with a red circled "!", then a line per warning,
    /// marked ⚠ in orange. It grows with the warnings, and the
    /// window with it (`fitWindowToContent`).
    private func makeStatusBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(white: 0, alpha: 0.18).cgColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        let line = NSBox()
        line.boxType = .separator
        statusLines.orientation = .vertical
        statusLines.alignment = .centerX
        statusLines.spacing = 4
        for v in [line, statusLines] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(v)
        }
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: bar.topAnchor),
            line.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            statusLines.topAnchor.constraint(equalTo: bar.topAnchor, constant: 9),
            statusLines.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -9),
            statusLines.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            statusLines.leadingAnchor.constraint(greaterThanOrEqualTo: bar.leadingAnchor, constant: 18),
        ])
        return bar
    }

    /// One line of the status bar: a symbol, then the text, in one colour.
    private func statusLine(_ text: String, symbol: String, color: NSColor) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = color
        icon.symbolConfiguration = .init(pointSize: 13, weight: .regular)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return row([icon, label], spacing: 6)
    }

    private func refreshStatus() {
        let hint = swapPending ? "Click the key to swap it with."
            : editor.selection == nil ? "Click a key to select it." : selectedDescription()
        var lines = [statusLine(hint, symbol: "info.circle", color: .secondaryLabelColor)]
        // Errors (the layout cannot be saved) before warnings (it can).
        let problems = editor.problems
        lines += problems.filter(\.isError).map {
            statusLine(describe($0), symbol: "exclamationmark.circle", color: .systemRed)
        }
        lines += problems.filter { !$0.isError }.map {
            statusLine(describe($0), symbol: "exclamationmark.triangle", color: .systemOrange)
        }
        statusLines.setViews(lines, in: .top)
        fitWindowToContent()
    }

    /// As tall as what the window holds, no taller; it grows downwards, its
    /// top staying where it is.
    private func fitWindowToContent() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let height = content.fittingSize.height
        guard abs(content.frame.height - height) > 0.5 else { return }
        var frame = window.frame
        let top = frame.maxY
        frame.size.height += height - content.frame.height
        frame.origin.y = top - frame.height
        // Grown past the bottom of the screen: lifted, as far as the top allows.
        if let visible = window.screen?.visibleFrame, frame.minY < visible.minY {
            frame.origin.y = min(visible.minY, visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true)
    }

    /// The keyboard as a whole: its sizes and its rows.
    private func makeKeyboardPanel() -> NSView {
        let fields: [(LayoutEditor.GeometryField, String)] = [
            (.keyWidth, "Key width"), (.keyHeight, "Key height"),
            (.keySpacing, "Key gap"), (.rowSpacing, "Row gap"), (.padding, "Padding"),
        ]
        var rows: [NSView] = [heading("Keyboard")]
        for (i, (field, title)) in fields.enumerated() {
            let value = NSTextField(labelWithString: "")
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
            value.alignment = .center
            value.widthAnchor.constraint(equalToConstant: 44).isActive = true
            geometryValues[field] = value
            let minus = button("", #selector(geometryMinus(_:)), symbol: "minus", name: "Less \(title)")
            let plus = button("", #selector(geometryPlus(_:)), symbol: "plus", name: "More \(title)")
            minus.tag = i
            plus.tag = i
            rows.append(row([caption(title), minus, value, plus, NSTextField(labelWithString: "pt")]))
        }
        rowsValue.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        rowsValue.alignment = .center
        rowsValue.widthAnchor.constraint(equalToConstant: 44).isActive = true
        // Like the sizes: − removes the selected key's row, + adds one below it
        // (or at the bottom with nothing selected).
        deleteRowButton = button("", #selector(deleteRow), symbol: "minus", name: "Delete Row")
        rows.append(row([caption("Rows"), deleteRowButton, rowsValue, button("", #selector(addRow), symbol: "plus", name: "Add Row")]))
        return column(rows, spacing: 8)
    }

    /// What is done to keys: moving them, and the dialog for one.
    private func makeKeysPanel() -> NSView {
        swapButton = button("Swap", #selector(swapKeys), symbol: "arrow.left.arrow.right")
        let editKey = button("Edit Key\u{2026}", #selector(editKey), symbol: "pencil")
        keyButtons = [
            button("", #selector(nudgeLeft), symbol: "arrow.left", name: "Move Key Left"),
            button("", #selector(nudgeRight), symbol: "arrow.right", name: "Move Key Right"),
            button("", #selector(nudgeUp), symbol: "arrow.up", name: "Move Key Up a Row"),
            button("", #selector(nudgeDown), symbol: "arrow.down", name: "Move Key Down a Row"),
            swapButton,
            button("Delete Key", #selector(deleteSelectedKey), symbol: "trash"),
            editKey,
        ]
        let newKey = button("New Key\u{2026}", #selector(newKey), symbol: "plus.rectangle")
        let buttons = row(keyButtons.dropLast() + [NSView(), newKey, editKey])
        return column([heading("Keys"), buttons], spacing: 8)
    }

    // MARK: - Showing the state

    private func refresh() {
        if let from = swapFrom, from.layout != editor.layout || from.selection != editor.selection { swapFrom = nil }
        reloadPopup()
        preview.layout = editor.layout
        preview.selection = editor.selection
        undoButton.isEnabled = editor.canUndo
        redoButton.isEnabled = editor.canRedo
        saveButton.isEnabled = editor.hasUnsavedChanges && editor.canSave
        revertButton.isEnabled = editor.hasUnsavedChanges
        keyButtons.forEach { $0.isEnabled = editor.selection != nil }
        deleteRowButton.isEnabled = editor.selection != nil
        swapButton.state = swapPending ? .on : .off
        for (field, label) in geometryValues {
            let v = editor.value(of: field)
            label.stringValue = v == v.rounded() ? String(Int(v)) : String(v)
        }
        rowsValue.stringValue = String(editor.layout.rows.count)

        if editor.layout.isBuiltIn {
            deleteButton.title = "Reset to Factory"
            deleteButton.isEnabled = editor.saved != KeyboardLayout.builtIn(id: editor.layout.id) || editor.hasUnsavedChanges
        } else {
            deleteButton.title = "Delete\u{2026}"
            deleteButton.isEnabled = true
        }

        window?.title = "Layout Editor — \(editor.layout.name)" + (editor.hasUnsavedChanges ? " (edited)" : "")
        refreshStatus()
    }

    private func selectedDescription() -> String {
        guard let key = editor.selectedKey, let p = editor.selection else { return "" }
        return "Row \(p.row + 1), key \(p.index + 1): \(KeyEditorDialog.describe(key.action)), width \(key.width)"
    }

    private func describe(_ problem: LayoutEditor.Problem) -> String {
        switch problem {
        case .layout(.noKeys): return "The layout has no keys and cannot be saved."
        case .layout(.missing(let key)): return "No \(key.rawValue) key."
        case .unevenRows(let widths):
            let widest = widths.max() ?? 0
            let short = widths.enumerated().filter { widest - $0.element > 1e-6 }
                .map { "row \($0.offset + 1) by \(LayoutPreviewView.units(widest - $0.element))" }
            return "Rows are uneven: short \(short.joined(separator: ", ")) key widths."
        }
    }

    private func reloadPopup() {
        layoutPopup.removeAllItems()
        for layout in store.loadAll() {
            let factory = KeyboardLayout.builtIn(id: layout.id)
            let edited = factory != nil && factory != layout ? " (edited)" : ""
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
        raiseWhenShown(alert.window)
        return alert.runModal()
    }

    /// The same for an open or save panel.
    private func run(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        raiseWhenShown(panel)
        return panel.runModal()
    }

    private func raiseWhenShown(_ window: NSWindow) {
        let raise = Timer(timeInterval: 0, repeats: false) { _ in
            window.level = NSWindow.Level(rawValue: AppConfig.Levels.keyboard.rawValue + 2)
        }
        RunLoop.main.add(raise, forMode: .modalPanel)
    }

    private func tell(_ message: String, _ detail: String = "") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        _ = run(alert)
    }

    // MARK: - Choosing what to edit

    /// Open another layout, asking about unsaved edits first.
    private func open(_ id: UUID) {
        guard confirmLeavingEdits() else { refresh(); return }
        editor = LayoutEditor(layout: store.layout(id: id))
        swapFrom = nil
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
        guard editor.canSave else {
            // Nothing that can be saved: discard or stay, no Save to fail.
            alert.messageText = "Discard the changes to \u{201C}\(editor.layout.name)\u{201D}?"
            alert.informativeText = "The layout has no keys, so it cannot be saved."
            alert.addButton(withTitle: "Discard")
            alert.addButton(withTitle: "Cancel")
            return run(alert) == .alertFirstButtonReturn
        }
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

    /// Asked before the app quits: save, discard, or stay. True to quit.
    func shouldQuit() -> Bool {
        guard window?.isVisible == true else { return true }
        return confirmLeavingEdits()
    }

    /// Layouts were changed from outside the editor (the keyboard's menu:
    /// Duplicate, Reset to Factory, Reload). The list follows; so does the
    /// layout on screen unless it has edits of its own to keep.
    func layoutsChangedElsewhere() {
        if !editor.hasUnsavedChanges {
            editor = LayoutEditor(layout: store.layout(id: editor.layout.id))
            swapFrom = nil
        }
        refresh()
    }

    // MARK: - Layout actions

    @discardableResult
    @objc private func save() -> Bool {
        guard editor.canSave else { NSSound.beep(); return false }
        guard store.save(editor.layout) else {
            tell("\u{201C}\(editor.layout.name)\u{201D} could not be saved.",
                 "Its file may be from a newer version of AllyKeyboard, or the layouts folder cannot be written to.")
            return false
        }
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
        guard let copy = store.duplicate(editor.saved, name: uniqueName(editor.saved.name + " copy")) else {
            tell("The copy could not be saved.")
            return
        }
        editor = LayoutEditor(layout: copy)
        refresh()
    }

    private func uniqueName(_ base: String, except id: UUID? = nil) -> String {
        let taken = Set(store.loadAll().filter { $0.id != id }.map(\.name))
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
        // A name another layout has would make two alike in the lists.
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        editor.rename(uniqueName(name, except: editor.layout.id))
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

    // MARK: - Files

    private static let layoutFileType =
        UTType(filenameExtension: KeyboardLayout.fileExtension, conformingTo: .json) ?? .json

    /// Read a layout from a file and open it. It is added beside the others,
    /// never in place of one (`LayoutStore.importLayout`).
    @objc private func importLayout() {
        guard confirmLeavingEdits() else { return }
        let panel = NSOpenPanel()
        panel.title = "Import a Layout"
        panel.prompt = "Import"
        // Chosen by extension (`panel(_:shouldEnable:)`), not by type: the
        // app declares no type for its files, so macOS knows an exported one
        // only as "Document", and a type filter left it greyed out.
        panel.delegate = self
        panel.allowsMultipleSelection = false
        guard run(panel) == .OK, let url = panel.url else { return }
        do {
            let layout = try store.importLayout(from: try Data(contentsOf: url))
            editor = LayoutEditor(layout: layout)
            swapFrom = nil
            refresh()
        } catch let error as KeyboardLayout.ImportError {
            tell("\u{201C}\(url.lastPathComponent)\u{201D} was not imported.", error.message)
        } catch {
            tell("\u{201C}\(url.lastPathComponent)\u{201D} could not be opened.", error.localizedDescription)
        }
    }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return true }
        return [KeyboardLayout.fileExtension, "json"].contains(url.pathExtension.lowercased())
    }

    /// Write the layout as it is on screen, unsaved edits included, to a file
    /// to keep or pass on.
    @objc private func exportLayout() {
        guard editor.canSave else {
            tell("A layout with no keys cannot be exported.")
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export the Layout"
        panel.prompt = "Export"
        panel.allowedContentTypes = [Self.layoutFileType]
        panel.nameFieldStringValue = editor.layout.name + "." + KeyboardLayout.fileExtension
        guard run(panel) == .OK, let url = panel.url else { return }
        do {
            try editor.layout.encoded().write(to: url, options: .atomic)
        } catch {
            tell("The layout could not be exported.", error.localizedDescription)
        }
    }

    // MARK: - The keyboard's sizes and rows

    private static let geometryOrder: [LayoutEditor.GeometryField] = [.keyWidth, .keyHeight, .keySpacing, .rowSpacing, .padding]

    @objc private func geometryMinus(_ sender: NSButton) {
        editor.adjustGeometry(Self.geometryOrder[sender.tag], by: -1); refresh()
    }
    @objc private func geometryPlus(_ sender: NSButton) {
        editor.adjustGeometry(Self.geometryOrder[sender.tag], by: 1); refresh()
    }
    /// A row below the selected key's, or at the bottom.
    @objc private func addRow() { editor.addRow(below: true); refresh() }
    @objc private func deleteRow() { editor.deleteRow(); refresh() }

    // MARK: - Keys
    // Not named moveLeft, keyUp, deleteBackward and the like: NSResponder has those
    // for the arrow and delete keys, and these must not answer them.

    private func clicked(_ position: KeyPosition?) {
        if swapPending, let position {
            swapFrom = nil
            editor.swapSelected(with: position)
        } else {
            swapFrom = nil
            editor.select(position)
        }
        refresh()
    }

    @objc private func nudgeLeft() { editor.moveAlongRow(by: -1); refresh() }
    @objc private func nudgeRight() { editor.moveAlongRow(by: 1); refresh() }
    @objc private func nudgeUp() { editor.moveToRow(by: -1); refresh() }
    @objc private func nudgeDown() { editor.moveToRow(by: 1); refresh() }
    @objc private func swapKeys() {
        if swapPending { swapFrom = nil }
        else if let selection = editor.selection { swapFrom = (editor.layout, selection) }
        refresh()
    }
    @objc private func deleteSelectedKey() { editor.deleteKey(); refresh() }

    /// The selected key in the key dialog; Done replaces it, as one step to undo.
    @objc private func editKey() {
        guard let key = editor.selectedKey,
              let edited = KeyEditorDialog.run(title: "Edit Key", key: key) else { return }
        editor.replaceSelectedKey(with: edited)
        refresh()
    }

    /// A new key from the dialog — starting as a copy of the selected key, or
    /// blank with none selected — placed right of the selection or at the end.
    @objc private func newKey() {
        guard let key = KeyEditorDialog.run(title: "New Key", key: editor.selectedKey ?? KeySpec(.blank)) else { return }
        editor.addKey(key)
        refresh()
    }
}
