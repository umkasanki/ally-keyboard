//
//  KeyInspector.swift
//  AllyKeyboard
//
//  One key's action and look, in the layout editor's right-hand column — in
//  place of the keyboard's sizes while a key is being edited (Edit Key…,
//  Add Key…), as Apple's Panel Editor has its inspector. The Action list
//  says what kind of thing the key does and opens on the key's own; under it,
//  what exactly: a second list, a text, recorded chords, an app, a script.
//  Every change goes into the layout at once, one step to undo; nothing
//  reaches the file before Save.
//

import AppKit
import AllyKeyboardCore
import UniformTypeIdentifiers

final class KeyInspector: NSObject, NSTextViewDelegate, NSTextFieldDelegate {

    /// The column itself, built once; the editor shows and hides it.
    let view = NSView()
    /// Told with the key as it now is, after every change.
    var onChange: ((KeySpec) -> Void)?
    /// Done: back to the keyboard's sizes.
    var onDone: (() -> Void)?

    /// The key as shown.
    private var key = KeySpec(.blank)

    private let actionPopup = NSPopUpButton()
    private let choicePopup = NSPopUpButton()
    private let textField = NSTextField()
    /// The chords as text, editable: "⌘H, ⇧⌘5", "⌘⌘", "cmd+shift+5".
    private let keysValue = NSTextField()
    /// Set while the chords typed in `keysValue` go in.
    private var typingChords = false
    private let appValue = NSTextField(labelWithString: "")
    private let scriptView = NSTextView()
    private var scriptScroll: NSScrollView!
    private var keysRow: NSView!, appRow: NSView!, choiceRow: NSView!, textRow: NSView!, scriptRow: NSView!
    private var shortcutRow: NSView!
    private let phrasesView = NSTextView()
    private var phrasesRow: NSView!
    /// What a Show Phrases key without a list of its own shows: the list
    /// kept in Settings before keys had their own.
    var defaultPhrases: [String] = []
    private let shortcutPopup = NSPopUpButton()
    /// The user's Shortcuts, as `shortcuts list` gives them; read once, when
    /// first wanted.
    private var shortcutNames: [String]?
    private var loadingShortcuts = false
    private let labelField = NSTextField()
    private let cornerField = NSTextField()
    private let iconPopup = NSPopUpButton()
    /// The icon after every other press, for a key that starts and stops something.
    private let secondIconPopup = NSPopUpButton()
    private let iconSearch = NSSearchField()
    private let secondIconSearch = NSSearchField()
    /// The second icon's search and list, folded away until wanted.
    private let secondIconToggle = NSButton()
    private var secondIconBox: NSView!
    /// Open or folded; it opens by itself for a key with a second icon.
    private var secondIconOpened = false
    /// Where the key shown stands, and the chords its field was last given.
    private var shownPlace: KeyPosition?
    private var shownChords: [Shortcut]?

    /// The inspector opens afresh: the next key shown is a new one to it.
    func forgetShownKey() {
        shownPlace = nil
        shownChords = nil
    }
    /// Every icon, by name A to Z.
    private static let allIcons = (ActionCatalog.bundledIcons + ActionCatalog.symbolIcons)
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    private let coloredCheck = NSButton(checkboxWithTitle: "Icon keeps its colours", target: nil, action: nil)
    private let widthValue = NSTextField(labelWithString: "")
    private let fontValue = NSTextField(labelWithString: "")

    override init() {
        super.init()
        build()
    }

    /// Show `key`, at `place`, in the fields — the selected key, after any
    /// change from anywhere (Undo, a move, another key clicked).
    func show(_ key: KeySpec, at place: KeyPosition) {
        self.key = key
        // Another key: the second icon's section opens for one that has a
        // second icon and folds for one that has none.
        if place != shownPlace {
            shownPlace = place
            secondIconOpened = key.secondIcon != nil
        }
        let kind = ActionKind.of(key.action)
        actionPopup.selectItem(at: ActionKind.allCases.firstIndex(of: kind) ?? 0)
        choiceRow.isHidden = kind.choices.isEmpty || kind == .keys
        textRow.isHidden = kind != .text
        keysRow.isHidden = kind != .keys
        appRow.isHidden = kind != .openApp
        scriptRow.isHidden = kind != .appleScript
        shortcutRow.isHidden = kind != .runShortcut
        let isPhrases = key.action == .command(.phrases)
        phrasesRow.isHidden = !isPhrases
        if isPhrases, view.window?.firstResponder !== phrasesView {
            phrasesView.string = (key.phrases ?? defaultPhrases).joined(separator: "\n")
        }
        if case .runShortcut(let name) = key.action { showShortcuts(selecting: name) }
        if !kind.choices.isEmpty {
            choicePopup.removeAllItems()
            choicePopup.addItems(withTitles: kind.choices.map(\.name))
            if let i = kind.choices.firstIndex(where: { $0.key.action == key.action }) {
                choicePopup.selectItem(at: i)
            }
        }
        if case .literal(let text) = key.action, view.window?.firstResponder != textField.currentEditor() {
            textField.stringValue = text
        }
        // The field follows Record, Clear, a tap or a preset even while the
        // cursor is in it; only the change typed in it leaves it as typed.
        // Its unfinished edit is dropped, not sent: it would put back the old
        // chords. A change to anything else leaves what is being typed alone.
        if !typingChords, let chords = Self.chords(of: key.action), chords != shownChords {
            keysValue.abortEditing()
            keysValue.stringValue = Shortcut.text(of: chords)
            keysValue.textColor = .labelColor
        }
        shownChords = Self.chords(of: key.action)
        if case .openApp(let path) = key.action {
            appValue.stringValue = path.isEmpty ? "None chosen" : URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }
        if case .appleScript(let source) = key.action, view.window?.firstResponder !== scriptView {
            scriptView.string = source
        }
        if view.window?.firstResponder != labelField.currentEditor() { labelField.stringValue = key.label ?? "" }
        if view.window?.firstResponder != cornerField.currentEditor() { cornerField.stringValue = key.secondary ?? "" }
        fillIcons()
        secondIconToggle.state = secondIconOpened ? .on : .off
        secondIconBox.isHidden = !secondIconOpened
        coloredCheck.state = key.colored ? .on : .off
        widthValue.stringValue = String(key.width)
        fontValue.stringValue = String(key.fontScale)
    }

    private func emit(_ new: KeySpec) {
        guard new != key else { return }
        key = new
        onChange?(new)
    }

    /// Another action and its look; the key keeps its width and font size.
    private func take(_ spec: KeySpec) {
        var new = spec
        new.width = key.width
        new.fontScale = key.fontScale
        emit(new)
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

    /// "▸ Second icon, every other press": the triangle or the words open it.
    private func secondIconHeader() -> NSView {
        secondIconToggle.bezelStyle = .disclosure
        secondIconToggle.setButtonType(.pushOnPushOff)
        secondIconToggle.title = ""
        secondIconToggle.target = self
        secondIconToggle.action = #selector(secondIconToggled)
        let words = caption("Second icon, every other press")
        words.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(secondIconWordsClicked)))
        return row([secondIconToggle, words], spacing: 4)
    }

    @objc private func secondIconWordsClicked() {
        secondIconToggle.state = secondIconToggle.state == .on ? .off : .on
        secondIconToggled()
    }

    /// Folding it away leaves the second icon as it is.
    @objc private func secondIconToggled() {
        secondIconOpened = secondIconToggle.state == .on
        secondIconBox.isHidden = !secondIconOpened
    }

    private func caption(_ text: String) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: 13, weight: .semibold)
        t.textColor = .secondaryLabelColor
        return t
    }

    private func popup(_ p: NSPopUpButton, _ action: Selector) {
        p.target = self
        p.action = action
        p.controlSize = .large
        p.font = .systemFont(ofSize: 14)
        p.widthAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func field(_ f: NSTextField, placeholder: String, _ action: Selector) {
        f.font = .systemFont(ofSize: 15)
        f.placeholderString = placeholder
        f.target = self
        f.action = action
        f.cell?.sendsActionOnEndEditing = true
        f.widthAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func build() {
        let heading = NSTextField(labelWithString: "Key")
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let done = button("Done", #selector(doneClicked))
        done.keyEquivalent = "\r"
        let header = row([heading, spacer, done])

        popup(actionPopup, #selector(kindPicked))
        actionPopup.addItems(withTitles: ActionKind.allCases.map(\.title))
        popup(choicePopup, #selector(choicePicked))
        choiceRow = choicePopup
        field(textField, placeholder: "The text this key types", #selector(textEdited))
        textRow = textField

        field(keysValue, placeholder: "\u{2318}C, or \u{2318}H, \u{21E7}\u{2318}5", #selector(chordsEdited))
        keysValue.font = .systemFont(ofSize: 15, weight: .medium)
        keysValue.delegate = self
        let presets = NSPopUpButton()
        presets.pullsDown = true
        presets.addItem(withTitle: "Common")
        presets.addItems(withTitles: ActionKind.keys.choices.map(\.name))
        presets.target = self
        presets.action = #selector(presetPicked(_:))
        presets.controlSize = .large
        let taps = NSPopUpButton()
        taps.pullsDown = true
        taps.addItems(withTitles: ["Add Tap", "\u{2318} Command", "\u{2325} Option", "\u{2303} Control", "\u{21E7} Shift"])
        taps.target = self
        taps.action = #selector(addTap(_:))
        taps.controlSize = .large
        keysRow = column([keysValue, caption("Comma between shortcuts; \u{2318}\u{2318} is \u{2318} twice"),
                          row([button("Record\u{2026}", #selector(recordChord)), button("Clear", #selector(clearChords))]),
                          row([taps, presets])], spacing: 6)

        popup(shortcutPopup, #selector(shortcutPicked))
        shortcutRow = column([shortcutPopup, button("Open Shortcuts", #selector(openShortcutsApp))], spacing: 6)

        appValue.font = .systemFont(ofSize: 15, weight: .medium)
        appRow = row([appValue, button("Choose\u{2026}", #selector(chooseApp))])

        phrasesRow = column([caption("Phrases, one a line"), textArea(phrasesView, height: 120)], spacing: 4)

        scriptView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        scriptView.isRichText = false
        scriptView.isAutomaticQuoteSubstitutionEnabled = false
        scriptView.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = scriptView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scriptView.minSize = NSSize(width: 0, height: 0)
        scriptView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        scriptView.isVerticallyResizable = true
        scriptView.autoresizingMask = [.width]
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 260).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 90).isActive = true
        scriptScroll = scroll
        scriptRow = scroll

        field(labelField, placeholder: "The action's own name", #selector(labelsEdited))
        field(cornerField, placeholder: "None", #selector(labelsEdited))
        popup(iconPopup, #selector(iconChosen))
        popup(secondIconPopup, #selector(iconChosen))
        secondIconBox = column([secondIconSearch, secondIconPopup], spacing: 6)
        secondIconBox.isHidden = true
        for search in [iconSearch, secondIconSearch] {
            search.placeholderString = "Find an icon"
            search.font = .systemFont(ofSize: 15)
            search.controlSize = .large
            search.sendsSearchStringImmediately = true
            search.target = self
            search.action = #selector(iconSearched(_:))
            search.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }
        fillIcons()
        coloredCheck.target = self
        coloredCheck.action = #selector(coloredToggled)
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
        ], spacing: 18)

        let stack = column([
            header,
            caption("Action"), actionPopup, choiceRow, phrasesRow, textRow, keysRow, appRow, shortcutRow, scriptRow,
            caption("Label"), labelField,
            caption("Corner label"), cornerField,
            caption("Icon"), iconSearch, iconPopup,
            secondIconHeader(), secondIconBox, coloredCheck,
            sizes,
        ], spacing: 6)
        stack.setCustomSpacing(12, after: header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// A plain-text area, in its scroll view, the width of the fields.
    private func textArea(_ text: NSTextView, height: CGFloat) -> NSScrollView {
        text.font = .systemFont(ofSize: 14)
        text.isRichText = false
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.delegate = self
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        let scroll = NSScrollView()
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 260).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        return scroll
    }

    // MARK: - Editing

    @objc private func doneClicked() {
        view.window?.makeFirstResponder(nil)          // a field being typed in counts
        onDone?()
    }

    @objc private func kindPicked() {
        let kind = ActionKind.allCases[actionPopup.indexOfSelectedItem]
        guard kind != ActionKind.of(key.action) else { return }
        take(kind.start)
    }

    @objc private func choicePicked() {
        let kind = ActionKind.of(key.action)
        let i = choicePopup.indexOfSelectedItem
        guard kind.choices.indices.contains(i) else { return }
        take(kind.choices[i].key)
    }

    @objc private func presetPicked(_ sender: NSPopUpButton) {
        let i = sender.indexOfSelectedItem - 1                // the first item is the pull-down's title
        let presets = ActionKind.keys.choices
        guard presets.indices.contains(i) else { return }
        take(presets[i].key)
    }

    @objc private func textEdited() {
        guard case .literal(let old) = key.action, textField.stringValue != old else { return }
        var new = key
        new.action = .literal(textField.stringValue)
        if key.label == nil || key.label == old { new.label = textField.stringValue }
        emit(new)
    }

    func textDidEndEditing(_ notification: Notification) {
        if (notification.object as? NSTextView) === phrasesView {
            guard key.action == .command(.phrases) else { return }
            let lines = phrasesView.string.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard lines != (key.phrases ?? defaultPhrases) else { return }
            var new = key
            new.phrases = lines
            emit(new)
            return
        }
        guard case .appleScript(let old) = key.action, scriptView.string != old else { return }
        var new = key
        new.action = .appleScript(scriptView.string)
        emit(new)
    }

    @objc private func labelsEdited() {
        var new = key
        // An empty field is no label — the action's own name shows — unless
        // the label was the empty one ("show nothing", the spacebar's).
        new.label = labelField.stringValue.isEmpty ? (key.label == "" ? "" : nil) : labelField.stringValue
        new.secondary = cornerField.stringValue.isEmpty ? (key.secondary == "" ? "" : nil) : cornerField.stringValue
        emit(new)
    }

    /// Each list: "No icon" and the icons whose name has its own search
    /// field's text, A to Z; the key's own icon stays in it.
    private func fillIcons() {
        for (popup, search, current, none) in [(iconPopup, iconSearch, key.icon, "No icon"),
                                               (secondIconPopup, secondIconSearch, key.secondIcon, "None")] {
            let query = search.stringValue.trimmingCharacters(in: .whitespaces)
            popup.removeAllItems()
            popup.addItem(withTitle: none)
            for name in Self.allIcons where query.isEmpty || name.localizedCaseInsensitiveContains(query) || name == current {
                popup.addItem(withTitle: name)
                // A copy: `NSImage(named:)` is shared, and the keyboard sizes
                // its icons from the image's own size.
                let image = (NSImage(named: name)?.copy() as? NSImage)
                    ?? NSImage(systemSymbolName: name, accessibilityDescription: nil)
                image?.size = NSSize(width: 18, height: 18)
                popup.lastItem?.image = image
                popup.lastItem?.representedObject = name
            }
            Self.select(current, in: popup)
        }
    }

    /// The icon's item, added if the list has none (an icon written into the file by hand).
    private static func select(_ icon: String?, in popup: NSPopUpButton) {
        guard let icon else { popup.selectItem(at: 0); return }
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == icon }) {
            popup.select(item)
        } else {
            popup.addItem(withTitle: icon)
            popup.lastItem?.representedObject = icon
            popup.select(popup.lastItem)
        }
    }

    /// The list narrows as the name is typed; Return takes the first match.
    @objc private func iconSearched(_ sender: NSSearchField) {
        fillIcons()
        let popup = sender === secondIconSearch ? secondIconPopup : iconPopup
        let query = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, NSApp.currentEvent?.keyCode == 36 || NSApp.currentEvent?.keyCode == 76,
              let first = popup.itemArray.dropFirst().first(where: {
                  ($0.representedObject as? String)?.localizedCaseInsensitiveContains(query) == true
              }) else { return }
        popup.select(first)
        iconChosen()
    }

    @objc private func iconChosen() {
        var new = key
        new.icon = iconPopup.selectedItem?.representedObject as? String
        new.secondIcon = secondIconPopup.selectedItem?.representedObject as? String
        emit(new)
    }

    @objc private func coloredToggled() {
        var new = key
        new.colored = coloredCheck.state == .on
        emit(new)
    }

    private func step(_ value: Double, by steps: Int, in range: ClosedRange<Double>) -> Double {
        let next = ((value + Double(steps) * LayoutEditor.step) / LayoutEditor.step).rounded() * LayoutEditor.step
        return min(max(next, range.lowerBound), range.upperBound)
    }
    @objc private func narrower() { var k = key; k.width = step(k.width, by: -1, in: LayoutEditor.widthRange); emit(k) }
    @objc private func wider() { var k = key; k.width = step(k.width, by: 1, in: LayoutEditor.widthRange); emit(k) }
    @objc private func smallerFont() { var k = key; k.fontScale = step(k.fontScale, by: -1, in: LayoutEditor.fontScaleRange); emit(k) }
    @objc private func largerFont() { var k = key; k.fontScale = step(k.fontScale, by: 1, in: LayoutEditor.fontScaleRange); emit(k) }

    /// Record one more chord: the first makes a shortcut, each after it is
    /// pressed in turn after the ones before ("⌘H, ⇧⌘5").
    @objc private func recordChord() {
        guard let (chord, _) = recorded() else { return }
        append(chord)
    }

    /// One more modifier tap — ⌘ ⌥ ⌃ ⇧ alone — at the end. The on-screen ⌘
    /// only arms the next key and sends nothing by itself, so a tap cannot be
    /// recorded from it; this is how "⌘, ⌘" is made with a head mouse.
    @objc private func addTap(_ sender: NSPopUpButton) {
        let codes = [55, 58, 59, 56]                        // ⌘ ⌥ ⌃ ⇧, the left ones
        let i = sender.indexOfSelectedItem - 1              // the first item is the pull-down's title
        guard codes.indices.contains(i) else { return }
        append(Shortcut(keyCode: codes[i], modifiers: []))
    }

    /// A chord at the end: the first makes a shortcut, each after it is
    /// pressed in turn after the ones before ("⌘H, ⇧⌘5", "⌘, ⌘").
    private func append(_ chord: Shortcut) {
        setChords((Self.chords(of: key.action) ?? []) + [chord])
    }

    @objc private func clearChords() { setChords([]) }

    /// The chords typed in the field; what is not understood turns red and
    /// changes nothing.
    @objc private func chordsEdited() {
        // The key no longer presses shortcuts (another action picked while
        // the field had the cursor): what was typed is not for it.
        guard Self.chords(of: key.action) != nil else { return }
        guard let chords = Shortcut.parseSequence(keysValue.stringValue) else {
            keysValue.textColor = .systemRed
            NSSound.beep()
            return
        }
        keysValue.textColor = .labelColor
        guard chords != Self.chords(of: key.action) else { return }
        typingChords = true
        defer { typingChords = false }
        setChords(chords)
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSTextField) === keysValue { keysValue.textColor = .labelColor }
    }

    /// One chord is a shortcut, more are pressed in turn, none is "None yet".
    /// The label follows the chords unless it was written by hand.
    private func setChords(_ chords: [Shortcut]) {
        var new = key
        new.action = chords.count == 1 ? .shortcut(chords[0]) : .keySequence(chords)
        let oldAuto = Self.chords(of: key.action).map(Self.label(for:))
        if key.label == nil || key.label == "" || key.label == oldAuto || Self.chords(of: key.action) == nil {
            new.label = chords.isEmpty ? nil : Self.label(for: chords)
        }
        emit(new)
    }

    private static func chords(of action: KeyAction) -> [Shortcut]? {
        switch action {
        case .shortcut(let s): return [s]
        case .keySequence(let s): return s
        default: return nil
        }
    }

    private static func label(for chords: [Shortcut]) -> String {
        chords.map { chordName($0) }.joined(separator: " ")
    }

    @objc private func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        let raise = Timer(timeInterval: 0, repeats: false) { _ in panel.level = AppConfig.Levels.window }
        RunLoop.main.add(raise, forMode: .modalPanel)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var new = key
        new.action = .openApp(url.path)
        new.label = url.deletingPathExtension().lastPathComponent
        new.icon = nil
        emit(new)
    }

    // MARK: - Shortcuts (the app)

    /// The list of the user's Shortcuts, the key's own selected — added if it
    /// is not (renamed or deleted since, or from someone else's file).
    private func showShortcuts(selecting name: String) {
        // Read in the background — `shortcuts list` can take a second or
        // more — and shown when it comes, if this key still runs a shortcut.
        if shortcutNames == nil, !loadingShortcuts {
            loadingShortcuts = true
            DispatchQueue.global(qos: .userInitiated).async {
                let names = Self.listShortcuts()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.loadingShortcuts = false
                    self.shortcutNames = names
                    if case .runShortcut(let current) = self.key.action { self.showShortcuts(selecting: current) }
                }
            }
        }
        shortcutPopup.removeAllItems()
        shortcutPopup.addItem(withTitle: "Choose a shortcut\u{2026}")
        shortcutPopup.addItems(withTitles: shortcutNames ?? [])
        if !name.isEmpty {
            if shortcutPopup.indexOfItem(withTitle: name) < 0 { shortcutPopup.addItem(withTitle: name) }
            shortcutPopup.selectItem(withTitle: name)
        } else {
            shortcutPopup.selectItem(at: 0)
        }
    }

    /// `shortcuts list`: the names, one a line.
    private static func listShortcuts() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init).filter { !$0.isEmpty }.sorted()
    }

    @objc private func shortcutPicked() {
        guard shortcutPopup.indexOfSelectedItem > 0, let name = shortcutPopup.titleOfSelectedItem else { return }
        var new = key
        new.action = .runShortcut(name)
        new.label = name
        new.icon = nil
        emit(new)
    }

    /// To make a new one — Do Not Disturb with the Set Focus action, say;
    /// the list is read again next time.
    @objc private func openShortcutsApp() {
        shortcutNames = nil
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
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
        case .keySequence(let chords): return "Keys " + chords.map { chordName($0) }.joined(separator: ", ")
        case .openApp(let path): return "Opens " + URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        case .appleScript: return "Runs an AppleScript"
        case .runShortcut(let name): return "Runs the shortcut \u{201C}\(name)\u{201D}"
        default: return action.legacyID
        }
    }

    // MARK: - Recording a chord

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
    private func recorded() -> (Shortcut, String)? {
        let alert = NSAlert()
        alert.messageText = "Record a shortcut"
        alert.informativeText = "Press it now: choose the modifiers on the keyboard (\u{2318} \u{2325} \u{2303} \u{21E7}), then the key. A modifier pressed and let go alone (\u{2318} on a real keyboard) records as a tap of it."
        let shown = NSTextField(labelWithString: "Waiting\u{2026}")
        shown.font = .systemFont(ofSize: 22, weight: .medium)
        shown.frame = NSRect(x: 0, y: 0, width: 320, height: 34)
        alert.accessoryView = shown
        alert.addButton(withTitle: "Use")
        alert.addButton(withTitle: "Cancel")
        var result: (Shortcut, String)?
        // A modifier pressed and let go with nothing in between: a tap of it.
        // Any key pressed meanwhile makes it a chord's modifier instead.
        var downModifier: UInt16?
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            downModifier = nil
            var mods: [Modifier] = []
            if event.modifierFlags.contains(.control) { mods.append(.control) }
            if event.modifierFlags.contains(.option) { mods.append(.option) }
            if event.modifierFlags.contains(.shift) { mods.append(.shift) }
            if event.modifierFlags.contains(.command) { mods.append(.command) }
            let chord = Shortcut(keyCode: Int(event.keyCode), modifiers: mods)
            let name = Self.chordName(chord, key: event.charactersIgnoringModifiers)
            result = (chord, name)
            shown.stringValue = name
            return nil                                      // recorded, not acted on
        }
        let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let code = Int(event.keyCode)
            guard Shortcut.modifierKeyCodes.contains(code) else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty, downModifier == event.keyCode {
                let chord = Shortcut(keyCode: code, modifiers: [])
                result = (chord, Self.chordName(chord))
                shown.stringValue = Self.chordName(chord)
                downModifier = nil
            } else if !flags.isEmpty {
                downModifier = event.keyCode
            }
            return event
        }
        let response = run(alert)
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        return response == .alertFirstButtonReturn ? result : nil
    }
}

/// A container that lays out from the top.
final class TopDownView: NSView {
    override var isFlipped: Bool { true }
}
