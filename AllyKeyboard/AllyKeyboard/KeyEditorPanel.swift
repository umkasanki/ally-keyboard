//
//  KeyEditorPanel.swift
//  AllyKeyboard
//
//  One key — what it does and how it looks — edited in a panel that slides
//  out inside the layout editor's Keys block (New Key…, Edit Key…), not in a
//  window of its own: the editor's own picture shows the key as it is
//  being made, every change at once. It works on a draft: Done hands the
//  draft back, Cancel drops it, so a whole edit of a key is one step to undo.
//

import AppKit
import AllyKeyboardCore

final class KeyEditorPanel: NSObject {

    /// The panel itself, built once; the editor shows and hides it.
    let view = NSView()
    /// Told on every change to the draft, so the editor's picture follows.
    var onChange: ((KeySpec) -> Void)?
    /// Told when the panel is done with: the key, or nil for Cancel.
    var onFinish: ((KeySpec?) -> Void)?

    /// The key as edited so far.
    private(set) var draft = KeySpec(.blank)
    /// The labels as the key came (or as the palette entry set them): an empty
    /// field keeps an empty one ("show nothing", the spacebar's) instead of
    /// turning it into no label, which shows the action's name.
    private var givenLabels: (label: String?, corner: String?) = (nil, nil)

    private let titleLabel = NSTextField(labelWithString: "")
    private let actionValue = NSTextField(wrappingLabelWithString: "")
    private let labelField = NSTextField()
    private let cornerField = NSTextField()
    private let iconPopup = NSPopUpButton()
    private let coloredCheck = NSButton(checkboxWithTitle: "Icon keeps its colours", target: nil, action: nil)
    private let widthValue = NSTextField(labelWithString: "")
    private let fontValue = NSTextField(labelWithString: "")
    private let tabs = NSTabView()
    /// The tabs' names, at the left edge: a tab view centres its own bar.
    private let tabPicker = NSSegmentedControl()

    override init() {
        super.init()
        build()
    }

    /// Start editing `key`: "New Key" or "Edit Key", on the first tab of
    /// actions.
    func begin(title: String, key: KeySpec) {
        titleLabel.stringValue = title
        draft = key
        givenLabels = (key.label, key.secondary)
        tabs.selectTabViewItem(at: 0)
        tabPicker.selectedSegment = 0
        show()
    }

    /// Done, from outside the panel (the editor asking before it closes).
    func commit() { finish() }

    @objc private func finish() {
        // A label still being typed counts, as if Return had been pressed.
        applyFields()
        onFinish?(draft)
    }

    @objc private func cancel() {
        onFinish?(nil)
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
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        actionValue.font = .systemFont(ofSize: 14, weight: .medium)
        actionValue.preferredMaxLayoutWidth = 240
        for value in [widthValue, fontValue] {
            value.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
            value.alignment = .center
            value.widthAnchor.constraint(equalToConstant: 56).isActive = true
        }

        // One above the other: the panel sits inside the Keys block, and side
        // by side they would push it past the window's width.
        let sizes = column([
            column([caption("Width"), row([button("", #selector(narrower), symbol: "minus"), widthValue,
                                           button("", #selector(wider), symbol: "plus")])]),
            column([caption("Font size"), row([button("", #selector(smallerFont), symbol: "minus"), fontValue,
                                               button("", #selector(largerFont), symbol: "plus")])]),
        ], spacing: 10)

        let cancelButton = button("Cancel", #selector(cancel))
        // No Esc for Cancel: Esc in the label's field would drop the whole key.
        let doneButton = button("Done", #selector(finish))
        doneButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Cancel and Done on the title's line, at the right, under New Key…
        // and Edit Key… — not left hanging under the fields.
        let header = row([titleLabel, spacer, cancelButton, doneButton])

        let inspector = column([
            caption("Action"), actionValue,
            caption("Label"), labelField,
            caption("Corner label"), cornerField,
            caption("Icon"), iconPopup, coloredCheck,
            sizes,
        ])

        let main = row([makePalette(), inspector], spacing: 24)
        main.alignment = .top
        // The tabs' bar sits inside the tab view's frame, nearer its title than
        // a button would; 12 gives the same gap as "Keys" over its buttons.
        let stack = column([header, main], spacing: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    // MARK: - Palette

    private func makePalette() -> NSView {
        tabs.tabViewType = .noTabsBezelBorder
        for group in ActionCatalog.groups {
            var buttons: [NSButton] = group.choices.enumerated().map { i, choice in
                let b = button(choice.name, #selector(choicePicked(_:)))
                b.tag = i
                b.identifier = NSUserInterfaceItemIdentifier(group.title)
                return b
            }
            // Two cells wide, so their names show whole.
            if group.title == "Shortcuts" { buttons.append(wide(button("Record Shortcut\u{2026}", #selector(recordShortcut)))) }
            if group.title == "Text" { buttons.append(wide(button("Type Text\u{2026}", #selector(typeText)))) }
            let item = NSTabViewItem(identifier: group.title)
            item.label = group.title
            item.view = grid(of: buttons, columns: 8)
            tabs.addTabViewItem(item)
        }
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.heightAnchor.constraint(equalToConstant: 270).isActive = true
        tabs.widthAnchor.constraint(equalToConstant: 790).isActive = true

        tabPicker.segmentCount = ActionCatalog.groups.count
        for (i, group) in ActionCatalog.groups.enumerated() { tabPicker.setLabel(group.title, forSegment: i) }
        tabPicker.trackingMode = .selectOne
        tabPicker.controlSize = .large
        tabPicker.font = .systemFont(ofSize: 13)
        tabPicker.selectedSegment = 0
        tabPicker.target = self
        tabPicker.action = #selector(tabPicked)
        return column([tabPicker, tabs], spacing: 8)
    }

    @objc private func tabPicked() { tabs.selectTabViewItem(at: tabPicker.selectedSegment) }

    private static let wideTag = -1
    private func wide(_ b: NSButton) -> NSButton { b.tag = Self.wideTag; return b }

    /// Buttons in rows of `columns`; every tab fits with no scrolling.
    private func grid(of buttons: [NSButton], columns: Int) -> NSView {
        var rows: [NSView] = []
        var start = 0
        while start < buttons.count {
            let slice = Array(buttons[start..<min(start + columns, buttons.count)])
            slice.forEach { $0.widthAnchor.constraint(equalToConstant: $0.tag == Self.wideTag ? 2 * 88 + 8 : 88).isActive = true }
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
        onChange?(draft)
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
        // Done on an unchanged key must change nothing (`givenLabels`).
        draft.label = labelField.stringValue.isEmpty ? (givenLabels.label == "" ? "" : nil) : labelField.stringValue
        draft.secondary = cornerField.stringValue.isEmpty ? (givenLabels.corner == "" ? "" : nil) : cornerField.stringValue
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
        givenLabels = (key.label, key.secondary)
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

    /// "⇧⌘S" for a chord, the modifiers in macOS's order.
    /// The key: its name if it types nothing (→, ↩, F1), else the character
    /// it was typed as, else the one it types in the current input source.
    static func chordName(_ chord: Shortcut, key: String? = nil) -> String {
        let symbols: [(Modifier, String)] = [(.control, "\u{2303}"), (.option, "\u{2325}"),
                                             (.shift, "\u{21E7}"), (.command, "\u{2318}")]
        return symbols.filter { chord.modifiers.contains($0.0) }.map(\.1).joined() + keyName(chord.keyCode, typed: key)
    }

    private static func keyName(_ code: Int, typed: String?) -> String {
        if let name = Shortcut.keyNames[code] { return name }
        // A function-key character (U+F700…) or a control character shows as nothing.
        func printable(_ s: String?) -> String? {
            guard let s, !s.isEmpty, !s.unicodeScalars.contains(where: {
                (0xF700...0xF8FF).contains($0.value) || $0.properties.generalCategory == .control
            }) else { return nil }
            return s.uppercased()
        }
        if let typed = printable(typed) { return typed }
        if let code16 = UInt16(exactly: code),
           let ch = printable(InputSourceSwitcher.character(forKeyCode: code16, shift: false,
                                                            from: InputSourceSwitcher.currentSource())) {
            return ch
        }
        return "key \(code)"
    }

    /// A dialog in front of the editor, as its child; both ordinary windows,
    /// under the keyboard.
    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let host = view.window
        let raise = Timer(timeInterval: 0, repeats: false) { _ in
            alert.window.level = AppConfig.Levels.window
            host?.addChildWindow(alert.window, ordered: .above)
        }
        RunLoop.main.add(raise, forMode: .modalPanel)
        defer { host?.removeChildWindow(alert.window) }
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
            let name = Self.chordName(chord, key: event.charactersIgnoringModifiers)
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
