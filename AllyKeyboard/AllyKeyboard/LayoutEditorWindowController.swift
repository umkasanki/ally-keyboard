//
//  LayoutEditorWindowController.swift
//  AllyKeyboard
//
//  The layout editor's window: the keyboard as a whole. Its sizes and rows
//  are edited here, and keys are moved, swapped and deleted; one key's
//  action and look are edited in a panel that slides out under them
//  (`KeyEditorPanel`), opened by New Key… and Edit Key…. Every edit goes
//  through `LayoutEditor` (Core, tested). Everything is a single click on a large button — no drag
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
    /// One key's action and look, slid out under the keys (`beginKeyEdit`).
    private let keyPanel = KeyEditorPanel()
    /// The key being edited in it: which button opened the panel, the layout
    /// it belongs to, the draft, and how Done puts it into the layout.
    private var keyEdit: (isNew: Bool, layoutID: UUID, draft: KeySpec, apply: (LayoutEditor, KeySpec) -> Void)?
    private var keyboardPanel: NSView!, keysPanel: NSView!
    private var newKeyButton: NSButton!, editKeyButton: NSButton!
    /// The line between the Keys buttons and the key panel, out with it.
    private let keyPanelRule = NSBox()
    /// Everything above the status bar, in a scroll view: the window grows
    /// with it up to the screen's visible height (above the Dock), and
    /// scrolls past that (the user's call, 2026-11-14).
    private var contentStack: NSStackView!, statusBarView: NSView!, scrollView: NSScrollView!
    private static let previewSize = NSSize(width: 820, height: 330)
    private let preview = LayoutPreviewView()
    /// The status bar's lines: the hint first, then a line per warning.
    private let statusLines = NSStackView()
    private let rowsValue = NSTextField(labelWithString: "")
    private let alignPicker = NSSegmentedControl()
    private static let alignments: [(alignment: KeyboardLayout.RowAlignment, title: String)] =
        [(.left, "Left"), (.center, "Centre"), (.stretch, "Stretch")]

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
        // An ordinary window: under the keyboard, and under another app's
        // window when that is clicked — instructions in a text editor stay
        // readable beside it (the user's call, 2026-11-14). Layout ▸ Edit
        // Layouts… brings it forward again. Its dialogs typed into are
        // ordinary too (`run(_:)`).
        window.level = AppConfig.Levels.window
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
        let topControls: [NSView] = [layoutPopup,
                       button("New", #selector(newLayout)),
                       button("Duplicate", #selector(duplicate)),
                       button("Rename\u{2026}", #selector(rename)),
                       deleteButton,
                       button("Import\u{2026}", #selector(importLayout)),
                       button("Export\u{2026}", #selector(exportLayout))]
        let top = row(topControls + [spacer, undoButton, redoButton, revertButton, saveButton])

        preview.onClick = { [weak self] position in self?.clicked(position) }
        preview.maximumSize = Self.previewSize

        keyboardPanel = makeKeyboardPanel()
        let middle = row([preview, keyboardPanel], spacing: 24)
        // The picture in the middle of the sizes' column, which is taller:
        // the same space above it as below it, down to the keys.
        middle.alignment = .centerY

        keysPanel = makeKeysPanel()
        let stack = column([top, middle, keysPanel], spacing: 16)
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = TopDownView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.horizontalScrollElasticity = .none   // up and down only; the window widens instead
        scroll.autohidesScrollers = true
        scrollView = scroll
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let statusBar = makeStatusBar()
        content.addSubview(statusBar)
        contentStack = stack
        statusBarView = statusBar
        let clip = scroll.contentView
        // Fills the visible width when the content is narrower — weaker than
        // any control's resistance to being squeezed.
        let fill = document.widthAnchor.constraint(equalTo: clip.widthAnchor)
        fill.priority = NSLayoutConstraint.Priority(NSLayoutConstraint.Priority.defaultHigh.rawValue - 10)
        fill.isActive = true
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            document.topAnchor.constraint(equalTo: clip.topAnchor),
            document.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            // At least as wide as the visible part, wider if the content
            // needs it — then the window widens to it (`widenToContent`),
            // never leaving it to scroll sideways or squeezing the insets.
            document.widthAnchor.constraint(greaterThanOrEqualTo: clip.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            top.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            // The window's width, not its content's: left to fit its buttons,
            // the row's right end (New Key…, Edit Key…) fell outside its own
            // panel when the preview grew a column of row widths — still
            // drawn there, but not clickable (found by hit-testing, 2026-11-14).
            keysPanel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        // As tall as what it holds, no taller: nothing hangs in empty space.
        content.layoutSubtreeIfNeeded()
        window?.setContentSize(NSSize(width: content.frame.width, height: wantedContentHeight))
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
        let hint = keyEdit != nil ? "The picture shows the key as it will be: Done puts it in, Cancel leaves the layout as it was."
            : swapPending ? "Click the key to swap it with."
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
    /// Never scrolled sideways: the window is at least as wide as what it
    /// holds, with room for the vertical scroller (within the screen).
    private func widenToContent() {
        guard let window, let document = scrollView.documentView else { return }
        // Measured, not estimated: how far the laid-out content overhangs
        // the visible part.
        var extra = document.frame.width - scrollView.contentView.bounds.width
        if let visible = window.screen?.visibleFrame { extra = min(extra, visible.width - window.frame.width) }
        guard extra > 0.5 else { return }
        var frame = window.frame
        frame.size.width += extra
        if let visible = window.screen?.visibleFrame, frame.maxX > visible.maxX {
            frame.origin.x = max(visible.minX, visible.maxX - frame.width)
        }
        window.setFrame(frame, display: true)
        window.contentView?.layoutSubtreeIfNeeded()
    }

    /// What the window holds, at full height: the scrolled part and the
    /// status bar under it.
    private var wantedContentHeight: CGFloat {
        contentStack.fittingSize.height + statusBarView.fittingSize.height
    }

    private func fitWindowToContent() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        widenToContent()
        var height = wantedContentHeight
        // No taller than the visible screen, title bar included; past that,
        // the content scrolls.
        if let visible = window.screen?.visibleFrame {
            height = min(height, visible.height - (window.frame.height - content.frame.height))
        }
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
        // Where a row shorter than the widest stands.
        alignPicker.segmentCount = Self.alignments.count
        for (i, a) in Self.alignments.enumerated() { alignPicker.setLabel(a.title, forSegment: i) }
        alignPicker.trackingMode = .selectOne
        alignPicker.controlSize = .large
        alignPicker.font = .systemFont(ofSize: 13)
        alignPicker.target = self
        alignPicker.action = #selector(alignmentPicked)
        rows.append(row([caption("Align rows"), alignPicker]))
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
        newKeyButton = newKey
        editKeyButton = editKey
        let buttons = row(keyButtons.dropLast() + [NSView(), newKey, editKey])
        // The key panel slides out inside this block, under its buttons: it
        // goes on from them.
        keyPanel.view.isHidden = true
        keyPanelRule.boxType = .separator
        keyPanelRule.isHidden = true
        let panel = column([heading("Keys"), buttons, keyPanelRule, keyPanel.view], spacing: 8)
        // Room above and below the line, so the panel does not run into the buttons.
        panel.setCustomSpacing(18, after: buttons)
        panel.setCustomSpacing(16, after: keyPanelRule)
        keyPanelRule.widthAnchor.constraint(equalTo: panel.widthAnchor, constant: -20).isActive = true
        // As wide as the buttons above, so its Done lines up under Edit Key….
        keyPanel.view.widthAnchor.constraint(equalTo: panel.widthAnchor, constant: -20).isActive = true
        // On the keyboard picture's own background, so the block's edge reads
        // where the picture's does — in line with the top bar.
        panel.wantsLayer = true
        panel.layer?.backgroundColor = AppConfig.Colors.keyboardBg.cgColor
        panel.layer?.cornerRadius = 10
        panel.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        buttons.widthAnchor.constraint(equalTo: panel.widthAnchor, constant: -20).isActive = true
        return panel
    }

    // MARK: - Showing the state

    private func refresh() {
        if let from = swapFrom, from.layout != editor.layout || from.selection != editor.selection { swapFrom = nil }
        reloadPopup()
        let shown = layoutWithDraft() ?? (editor.layout, editor.selection)
        preview.layout = shown.layout
        preview.selection = shown.selection
        // Another layout opened: the key being edited belonged to the last one.
        if let edit = keyEdit, edit.layoutID != editor.layout.id { closeKeyPanel() }
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
        alignPicker.selectedSegment = Self.alignments.firstIndex { $0.alignment == editor.layout.geometry.rowAlignment } ?? 1

        if editor.layout.isBuiltIn {
            deleteButton.title = "Reset to Factory"
            deleteButton.isEnabled = editor.saved != KeyboardLayout.builtIn(id: editor.layout.id) || editor.hasUnsavedChanges
        } else {
            deleteButton.title = "Delete\u{2026}"
            deleteButton.isEnabled = true
        }

        // The button that opened the key panel is dimmed while it is out.
        if let edit = keyEdit { (edit.isNew ? newKeyButton : editKeyButton)?.isEnabled = false }

        window?.title = "Layout Editor — \(editor.layout.name)" + (editor.hasUnsavedChanges ? " (edited)" : "")
        refreshStatus()
    }

    private func selectedDescription() -> String {
        guard let key = editor.selectedKey, let p = editor.selection else { return "" }
        return "Row \(p.row + 1), key \(p.index + 1): \(KeyEditorPanel.describe(key.action)), width \(key.width)"
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

    /// Show a dialog as an ordinary window (`AppConfig.Levels.window`): in
    /// front of the editor, under the keyboard and under any app clicked over
    /// it. `runModal` puts it at the modal-panel level, above every app; set
    /// back once it is up, the level stays (checked on the device, 2026-11-14).
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        settleWhenShown(alert.window)
        // Kept above the editor, as its child, whatever is clicked meanwhile.
        let attach = Timer(timeInterval: 0, repeats: false) { [weak self] _ in
            self?.window?.addChildWindow(alert.window, ordered: .above)
        }
        RunLoop.main.add(attach, forMode: .modalPanel)
        defer { window?.removeChildWindow(alert.window) }
        return alert.runModal()
    }

    /// The same for an open or save panel.
    private func run(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
        settleWhenShown(panel)
        return panel.runModal()
    }

    private func settleWhenShown(_ window: NSWindow) {
        let raise = Timer(timeInterval: 0, repeats: false) { _ in
            window.level = AppConfig.Levels.window
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        endKeyEdit(with: nil)
        return confirmLeavingEdits()
    }

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
    @objc private func alignmentPicked() {
        editor.setRowAlignment(Self.alignments[alignPicker.selectedSegment].alignment)
        refresh()
    }
    @objc private func addRow() { editor.addRow(below: true); refresh() }
    @objc private func deleteRow() { editor.deleteRow(); refresh() }

    // MARK: - Keys
    // Not named moveLeft, keyUp, deleteBackward and the like: NSResponder has those
    // for the arrow and delete keys, and these must not answer them.

    private func clicked(_ position: KeyPosition?) {
        guard keyEdit == nil else { return }       // the picture is a preview then
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

    // MARK: - The key panel

    /// The selected key in the key panel; Done replaces it, as one step to undo.
    @objc private func editKey() {
        guard let key = editor.selectedKey else { return }
        beginKeyEdit(title: "Edit Key", key: key, isNew: false) { $0.replaceSelectedKey(with: $1) }
    }

    /// A new key from the key panel — starting as a copy of the selected key,
    /// or blank with none selected — placed right of the selection, or in the
    /// first row with room for it.
    @objc private func newKey() {
        beginKeyEdit(title: "New Key", key: editor.selectedKey ?? KeySpec(.blank), isNew: true) { $0.addKey($1) }
    }

    /// Slide the key panel out, inside the Keys block, under its buttons;
    /// the rest of the window stays as it is, and scrolls when it no longer
    /// fits the screen. While the panel is out the picture shows the layout
    /// as Done would leave it, redrawn on every change. Done puts the key in
    /// at the selection of the moment — the key itself, for Edit Key, which
    /// the selection follows when it is moved.
    private func beginKeyEdit(title: String, key: KeySpec, isNew: Bool,
                              apply: @escaping (LayoutEditor, KeySpec) -> Void) {
        swapFrom = nil
        keyEdit = (isNew, editor.layout.id, key, apply)
        keyPanel.view.isHidden = false
        keyPanelRule.isHidden = false
        keyPanel.onChange = { [weak self] draft in
            guard let self, self.keyEdit != nil else { return }
            self.keyEdit?.draft = draft
            self.refresh()
        }
        keyPanel.onFinish = { [weak self] key in self?.endKeyEdit(with: key) }
        keyPanel.begin(title: title, key: key)
        fitWindowToContent()
        window?.contentView?.layoutSubtreeIfNeeded()
        keyPanel.view.scrollToVisible(keyPanel.view.bounds)
    }

    /// Done (a key) or Cancel (nil): the panel slides back in.
    private func endKeyEdit(with key: KeySpec?) {
        guard let edit = keyEdit else { return }
        if let key { edit.apply(editor, key) }
        closeKeyPanel()
        refresh()
    }

    private func closeKeyPanel() {
        keyEdit = nil
        keyPanel.view.isHidden = true
        keyPanelRule.isHidden = true
    }

    /// The layout as the key panel's draft would leave it, worked out on a
    /// copy of the editor: what the picture shows while the panel is out.
    private func layoutWithDraft() -> (layout: KeyboardLayout, selection: KeyPosition?)? {
        guard let edit = keyEdit else { return nil }
        let copy = LayoutEditor(layout: editor.layout)
        copy.select(editor.selection)
        edit.apply(copy, edit.draft)
        return (copy.layout, copy.selection)
    }
}
