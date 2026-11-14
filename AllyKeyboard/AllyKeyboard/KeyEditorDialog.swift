//
//  KeyEditorDialog.swift
//  AllyKeyboard
//
//  The dialog for one key — what it does and how it looks — opened from the
//  layout editor by New Key… and Edit Key…. It works on a draft: Done hands
//  the draft back, Cancel drops it, so a whole edit of a key is one step to
//  undo in the editor. Above the keyboard, so it can be reached.
//

import AppKit
import AllyKeyboardCore

final class KeyEditorDialog: NSObject {

    /// The key as edited so far.
    private(set) var draft: KeySpec
    private let window: NSWindow
    private var done = false

    private let actionValue = NSTextField(wrappingLabelWithString: "")
    private let labelField = NSTextField()
    private let cornerField = NSTextField()
    private let iconPopup = NSPopUpButton()
    private let coloredCheck = NSButton(checkboxWithTitle: "Icon keeps its colours", target: nil, action: nil)
    private let widthValue = NSTextField(labelWithString: "")
    private let fontValue = NSTextField(labelWithString: "")

    /// Run the dialog; the edited key, or nil if it was cancelled.
    static func run(title: String, key: KeySpec) -> KeySpec? {
        let dialog = KeyEditorDialog(title: title, key: key)
        return dialog.runModal()
    }

    private init(title: String, key: KeySpec) {
        draft = key
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 420),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.title = title
        super.init()
        build()
        show()
    }

    // MARK: - Running

    private func runModal() -> KeySpec? {
        window.center()
        // Above the keyboard; runModal would otherwise put the window at the
        // system's modal level, under it (as with the editor's alerts).
        let raise = Timer(timeInterval: 0, repeats: false) { [window] _ in
            window.level = NSWindow.Level(rawValue: AppConfig.Levels.keyboard.rawValue + 1)
        }
        RunLoop.main.add(raise, forMode: .modalPanel)
        NSApp.runModal(for: window)
        window.orderOut(nil)
        return done ? draft : nil
    }

    @objc private func finish() {
        // A label still being typed counts, as if Return had been pressed.
        applyFields()
        done = true
        NSApp.stopModal()
    }

    @objc private func cancel() {
        NSApp.stopModal()
    }

    // MARK: - Layout

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

    private func caption(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.textColor = .secondaryLabelColor
        return t
    }

    private func build() {
        guard let content = window.contentView else { return }

        for field in [labelField, cornerField] {
            field.font = .systemFont(ofSize: 15)
            field.target = self
            field.action = #selector(fieldsEdited)
            field.widthAnchor.constraint(equalToConstant: 240).isActive = true
        }
        labelField.placeholderString = "The action's own name"
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
        actionValue.font = .systemFont(ofSize: 14, weight: .medium)
        actionValue.preferredMaxLayoutWidth = 240
        for value in [widthValue, fontValue] {
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
            value.alignment = .center
            value.widthAnchor.constraint(equalToConstant: 56).isActive = true
        }

        let sizes = row([
            column([caption("Width"), row([button("", #selector(narrower), symbol: "minus"), widthValue,
                                           button("", #selector(wider), symbol: "plus")])]),
            column([caption("Font size"), row([button("", #selector(smallerFont), symbol: "minus"), fontValue,
                                               button("", #selector(largerFont), symbol: "plus")])]),
        ], spacing: 32)

        let inspector = column([
            caption("Action"), actionValue,
            caption("Label"), labelField,
            caption("Corner label"), cornerField,
            caption("Icon"), iconPopup, coloredCheck,
            sizes,
        ])

        let cancelButton = button("Cancel", #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let doneButton = button("Done", #selector(finish))
        doneButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = row([spacer, cancelButton, doneButton])

        let main = row([makePalette(), inspector], spacing: 24)
        main.alignment = .top
        let stack = column([main, footer], spacing: 18)
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
        ])
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
            let item = NSTabViewItem(identifier: group.title)
            item.label = group.title
            item.view = grid(of: buttons, columns: 9)
            tabs.addTabViewItem(item)
        }
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.heightAnchor.constraint(equalToConstant: 300).isActive = true
        tabs.widthAnchor.constraint(equalToConstant: 900).isActive = true
        return tabs
    }

    /// Buttons in rows of `columns`; every tab fits with no scrolling.
    private func grid(of buttons: [NSButton], columns: Int) -> NSView {
        var rows: [NSView] = []
        var start = 0
        while start < buttons.count {
            let slice = Array(buttons[start..<min(start + columns, buttons.count)])
            slice.forEach { $0.widthAnchor.constraint(equalToConstant: 88).isActive = true }
            rows.append(row(slice))
            start += columns
        }
        let grid = column(rows)
        grid.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let container = TopDownView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        ])
        return container
    }

    // MARK: - Editing the draft

    private func show() {
        actionValue.stringValue = Self.describe(draft.action)
        labelField.stringValue = draft.label ?? ""
        cornerField.stringValue = draft.secondary ?? ""
        if let icon = draft.icon {
            if let i = iconPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == icon }) {
                iconPopup.selectItem(at: i)
            } else {
                // An icon from a file the list does not offer: shown, kept.
                iconPopup.addItem(withTitle: icon)
                iconPopup.lastItem?.representedObject = icon
                iconPopup.select(iconPopup.lastItem)
            }
        } else {
            iconPopup.selectItem(at: 0)
        }
        coloredCheck.state = draft.colored ? .on : .off
        widthValue.stringValue = String(draft.width)
        fontValue.stringValue = String(draft.fontScale)
    }

    private func applyFields() {
        draft.label = labelField.stringValue.isEmpty ? nil : labelField.stringValue
        draft.secondary = cornerField.stringValue.isEmpty ? nil : cornerField.stringValue
    }

    @objc private func fieldsEdited() { applyFields(); show() }
    @objc private func iconChosen() { draft.icon = iconPopup.selectedItem?.representedObject as? String; show() }
    @objc private func coloredToggled() { draft.colored = coloredCheck.state == .on; show() }

    private func step(_ value: Double, by steps: Int, in range: ClosedRange<Double>) -> Double {
        let next = ((value + Double(steps) * LayoutEditor.step) / LayoutEditor.step).rounded() * LayoutEditor.step
        return min(max(next, range.lowerBound), range.upperBound)
    }
    @objc private func narrower() { draft.width = step(draft.width, by: -1, in: LayoutEditor.widthRange); show() }
    @objc private func wider() { draft.width = step(draft.width, by: 1, in: LayoutEditor.widthRange); show() }
    @objc private func smallerFont() { draft.fontScale = step(draft.fontScale, by: -1, in: LayoutEditor.fontScaleRange); show() }
    @objc private func largerFont() { draft.fontScale = step(draft.fontScale, by: 1, in: LayoutEditor.fontScaleRange); show() }

    /// A palette entry: its action and look, keeping this key's width and font.
    @objc private func choicePicked(_ sender: NSButton) {
        guard let title = sender.identifier?.rawValue,
              let group = ActionCatalog.groups.first(where: { $0.title == title }),
              group.choices.indices.contains(sender.tag) else { return }
        take(group.choices[sender.tag].key)
    }

    private func take(_ key: KeySpec) {
        let width = draft.width, font = draft.fontScale
        draft = key
        draft.width = width
        draft.fontScale = font
        show()
    }

    /// The palette entry's name for an action, or what the action is.
    static func describe(_ action: KeyAction) -> String {
        for group in ActionCatalog.groups {
            if let choice = group.choices.first(where: { $0.key.action == action }) {
                return "\(choice.name) — \(group.title)"
            }
        }
        switch action {
        case .literal(let text): return "Types \u{201C}\(text)\u{201D}"
        case .shortcut(let chord): return "Shortcut \(chordName(chord))"
        default: return action.legacyID
        }
    }

    // MARK: - Recording a shortcut, typing text

    /// "⌘⇧S" for a chord.
    static func chordName(_ chord: Shortcut, key: String? = nil) -> String {
        let symbols: [(Modifier, String)] = [(.control, "\u{2303}"), (.option, "\u{2325}"),
                                             (.shift, "\u{21E7}"), (.command, "\u{2318}")]
        return symbols.filter { chord.modifiers.contains($0.0) }.map(\.1).joined() + (key ?? "key \(chord.keyCode)")
    }

    /// A dialog above this one, and above the keyboard.
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let raise = Timer(timeInterval: 0, repeats: false) { _ in
            alert.window.level = NSWindow.Level(rawValue: AppConfig.Levels.keyboard.rawValue + 2)
        }
        RunLoop.main.add(raise, forMode: .modalPanel)
        return alert.runModal()
    }

    /// Wait for a chord — typed on this keyboard (⌘, then S) or on a real one.
    @objc private func recordShortcut() {
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
            return nil                                      // recorded, not acted on
        }
        let response = run(alert)
        if let monitor { NSEvent.removeMonitor(monitor) }
        guard response == .alertFirstButtonReturn, let (chord, name) = recorded else { return }
        take(KeySpec(.shortcut(chord), label: name))
    }

    /// A text the key types as it is.
    @objc private func typeText() {
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
        take(KeySpec(.literal(field.stringValue), label: field.stringValue))
    }
}

/// A container that lays out from the top, so a tab's grid starts there.
final class TopDownView: NSView {
    override var isFlipped: Bool { true }
}
