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

    // The inspector: the selected key's look.
    private let labelField = NSTextField()
    private let cornerField = NSTextField()
    private let iconPopup = NSPopUpButton()
    private let coloredCheck = NSButton(checkboxWithTitle: "Icon keeps its colours", target: nil, action: nil)
    private let widthValue = NSTextField(labelWithString: "")
    private let fontValue = NSTextField(labelWithString: "")
    private let actionValue = NSTextField(wrappingLabelWithString: "")
    /// Controls that edit the selected key: the inspector and the palette.
    private var selectionControls: [NSControl] = []

    init(store: LayoutStore, open layoutID: UUID,
         onSaved: @escaping (KeyboardLayout) -> Void, onDeleted: @escaping (UUID) -> Void) {
        self.store = store
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        editor = LayoutEditor(layout: store.layout(id: layoutID))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 700),
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

        let middle = row([preview, makeInspector()])
        middle.alignment = .top
        middle.spacing = 18

        let footer = row([statusLabel, problemsLabel])
        footer.spacing = 24
        let stack = NSStackView(views: [top, middle, structure, makePalette(), footer])
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

    // MARK: - Inspector

    private func caption(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.textColor = .secondaryLabelColor
        return t
    }

    private func column(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 6
        return s
    }

    private func makeInspector() -> NSView {
        for field in [labelField, cornerField] {
            field.font = .systemFont(ofSize: 15)
            field.target = self
            field.widthAnchor.constraint(equalToConstant: 240).isActive = true
        }
        labelField.action = #selector(labelEdited)
        labelField.placeholderString = "The action's own name"
        cornerField.action = #selector(cornerEdited)
        cornerField.placeholderString = "None"

        iconPopup.target = self
        iconPopup.action = #selector(iconChosen)
        iconPopup.controlSize = .large
        iconPopup.addItem(withTitle: "No icon")
        for name in ActionCatalog.bundledIcons + ActionCatalog.symbolIcons {
            iconPopup.addItem(withTitle: name)
            let image = NSImage(named: name) ?? NSImage(systemSymbolName: name, accessibilityDescription: nil)
            image?.size = NSSize(width: 18, height: 18)
            iconPopup.lastItem?.image = image
            iconPopup.lastItem?.representedObject = name
        }
        coloredCheck.target = self
        coloredCheck.action = #selector(coloredToggled)
        actionValue.font = .systemFont(ofSize: 13)
        actionValue.preferredMaxLayoutWidth = 240
        for value in [widthValue, fontValue] {
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
            value.alignment = .center
            value.widthAnchor.constraint(equalToConstant: 56).isActive = true
        }

        let widthMinus = button("", #selector(narrower), symbol: "minus")
        let widthPlus = button("", #selector(wider), symbol: "plus")
        let fontMinus = button("", #selector(smallerFont), symbol: "minus")
        let fontPlus = button("", #selector(largerFont), symbol: "plus")
        selectionControls = [labelField, cornerField, iconPopup, coloredCheck,
                             widthMinus, widthPlus, fontMinus, fontPlus]

        let sizes = row([column([caption("Width"), row([widthMinus, widthValue, widthPlus])]),
                         column([caption("Font size"), row([fontMinus, fontValue, fontPlus])])])
        sizes.spacing = 32
        let inspector = NSStackView(views: [
            caption("Action"), actionValue,
            caption("Label"), labelField,
            caption("Corner label"), cornerField,
            caption("Icon"), iconPopup, coloredCheck,
            // Side by side, so the inspector is no taller than the preview,
            // with room between them: two − and + pairs must not run together.
            sizes,
        ])
        inspector.orientation = .vertical
        inspector.alignment = .leading
        inspector.spacing = 6
        return inspector
    }

    @objc private func labelEdited() { editor.setLabel(labelField.stringValue); refresh() }
    @objc private func cornerEdited() { editor.setSecondary(cornerField.stringValue); refresh() }
    @objc private func iconChosen() { editor.setIcon(iconPopup.selectedItem?.representedObject as? String); refresh() }
    @objc private func coloredToggled() { editor.setColored(coloredCheck.state == .on); refresh() }
    @objc private func narrower() { editor.adjustWidth(by: -1); refresh() }
    @objc private func wider() { editor.adjustWidth(by: 1); refresh() }
    @objc private func smallerFont() { editor.adjustFontScale(by: -1); refresh() }
    @objc private func largerFont() { editor.adjustFontScale(by: 1); refresh() }

    private func refreshInspector() {
        let key = editor.selectedKey
        selectionControls.forEach { $0.isEnabled = key != nil }
        actionValue.stringValue = key.map { describe($0.action) } ?? "Select a key in the picture."
        labelField.stringValue = key?.label ?? ""
        cornerField.stringValue = key?.secondary ?? ""
        if let icon = key?.icon, let i = iconPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == icon }) {
            iconPopup.selectItem(at: i)
        } else if let icon = key?.icon {
            // An icon written into the file that the list does not offer: shown, kept.
            iconPopup.addItem(withTitle: icon)
            iconPopup.lastItem?.representedObject = icon
            iconPopup.select(iconPopup.lastItem)
        } else {
            iconPopup.selectItem(at: 0)
        }
        coloredCheck.state = key?.colored == true ? .on : .off
        widthValue.stringValue = key.map { String($0.width) } ?? ""
        fontValue.stringValue = key.map { String($0.fontScale) } ?? ""
    }

    /// The palette entry's name for an action, or what the action is.
    private func describe(_ action: KeyAction) -> String {
        for group in ActionCatalog.groups {
            if let choice = group.choices.first(where: { $0.key.action == action }) {
                return "\(choice.name) — \(group.title)"
            }
        }
        switch action {
        case .literal(let text): return "Types \u{201C}\(text)\u{201D}"
        case .shortcut(let chord): return "Shortcut \(Self.chordName(chord))"
        default: return action.legacyID
        }
    }

    // MARK: - Palette

    private func makePalette() -> NSView {
        let tabs = NSTabView()
        tabs.font = .systemFont(ofSize: 13)
        for group in ActionCatalog.groups {
            var buttons: [NSButton] = group.choices.enumerated().map { i, choice in
                let b = button(choice.name, #selector(choicePicked(_:)))
                b.tag = i
                b.identifier = NSUserInterfaceItemIdentifier(group.title)
                return b
            }
            if group.title == "Shortcuts" { buttons.append(button("Record Shortcut\u{2026}", #selector(recordShortcut))) }
            if group.title == "Text" { buttons.append(button("Type Text\u{2026}", #selector(typeText))) }
            selectionControls += buttons
            let item = NSTabViewItem(identifier: group.title)
            item.label = group.title
            // Twelve to a row: the longest tab, Letters & Digits, fits in four
            // rows with no scrolling, which a head mouse makes hard.
            item.view = grid(of: buttons, columns: 12)
            tabs.addTabViewItem(item)
        }
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.heightAnchor.constraint(equalToConstant: 214).isActive = true
        tabs.widthAnchor.constraint(equalToConstant: 1140).isActive = true
        return tabs
    }

    /// Buttons in rows of `columns`. No scroll view: every tab fits (the
    /// longest, Letters & Digits, in four rows of twelve), and scrolling is
    /// hard with a head mouse — and with "always show scroll bars" set, a
    /// scroller showed even with nothing to scroll.
    private func grid(of buttons: [NSButton], columns: Int) -> NSView {
        var rows: [NSView] = []
        var start = 0
        while start < buttons.count {
            let slice = Array(buttons[start..<min(start + columns, buttons.count)])
            slice.forEach { $0.widthAnchor.constraint(equalToConstant: 86).isActive = true }
            rows.append(row(slice))
            start += columns
        }
        let column = NSStackView(views: rows)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6
        column.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let container = FlippedView()
        column.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: container.topAnchor),
            column.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        ])
        return container
    }

    @objc private func choicePicked(_ sender: NSButton) {
        guard let title = sender.identifier?.rawValue,
              let group = ActionCatalog.groups.first(where: { $0.title == title }),
              group.choices.indices.contains(sender.tag) else { return }
        editor.assign(group.choices[sender.tag])
        refresh()
    }

    // MARK: - Recording a shortcut, typing text

    /// "⌘⇧S" for a chord.
    static func chordName(_ chord: Shortcut, key: String? = nil) -> String {
        let symbols: [(Modifier, String)] = [(.control, "\u{2303}"), (.option, "\u{2325}"),
                                             (.shift, "\u{21E7}"), (.command, "\u{2318}")]
        let mods = symbols.filter { chord.modifiers.contains($0.0) }.map(\.1).joined()
        return mods + (key ?? "key \(chord.keyCode)")
    }

    /// Wait for a chord — typed on this keyboard (⌘, then S) or on a real
    /// one — and give it to the selected key.
    @objc private func recordShortcut() {
        guard editor.selection != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Record a shortcut"
        alert.informativeText = "Press it now: choose the modifiers on the keyboard (\u{2318} \u{2325} \u{2303} \u{21E7}), then the key."
        let shown = NSTextField(labelWithString: "Waiting\u{2026}")
        shown.font = .systemFont(ofSize: 22, weight: .medium)
        shown.frame = NSRect(x: 0, y: 0, width: 320, height: 34)
        alert.accessoryView = shown
        alert.addButton(withTitle: "Use")
        alert.addButton(withTitle: "Cancel")
        var recorded: (Shortcut, String)?
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var mods: [Modifier] = []
            if event.modifierFlags.contains(.control) { mods.append(.control) }
            if event.modifierFlags.contains(.option) { mods.append(.option) }
            if event.modifierFlags.contains(.shift) { mods.append(.shift) }
            if event.modifierFlags.contains(.command) { mods.append(.command) }
            let chord = Shortcut(keyCode: Int(event.keyCode), modifiers: mods)
            let key = (event.charactersIgnoringModifiers ?? "").uppercased()
            let name = Self.chordName(chord, key: key.isEmpty ? nil : key)
            recorded = (chord, name)
            shown.stringValue = name
            return nil                                      // the chord is recorded, not acted on
        }
        let response = run(alert)
        if let monitor { NSEvent.removeMonitor(monitor) }
        guard response == .alertFirstButtonReturn, let (chord, name) = recorded else { return }
        editor.assign(ActionChoice(name, KeySpec(.shortcut(chord), label: name)))
        refresh()
    }

    /// Give the selected key a text to type as it is.
    @objc private func typeText() {
        guard editor.selection != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Text the key types"
        alert.informativeText = "Typed exactly as written, whatever the input language."
        let field = NSTextField(string: "")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 28)
        field.font = .systemFont(ofSize: 15)
        alert.accessoryView = field
        alert.addButton(withTitle: "Use")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard run(alert) == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return }
        let text = field.stringValue
        editor.assign(ActionChoice(text, KeySpec(.literal(text), label: text)))
        refresh()
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
        refreshInspector()
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

/// A container that lays out from the top, so a tab's grid starts there.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
