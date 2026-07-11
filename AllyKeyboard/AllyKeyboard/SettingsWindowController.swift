//
//  SettingsWindowController.swift
//  AllyKeyboard
//
//  Tabbed settings window:
//   • General     — launch-at-login + keyboard size (percent, 100% = base).
//   • Suggestions — show word predictions while typing, and the saved phrases
//                   opened by the list key (one per line).
//

import AppKit
import AllyKeyboardCore

final class SettingsWindowController: NSWindowController, NSTextViewDelegate {

    private let onPercentChange: (Int) -> Void
    private let onShowSuggestionsChange: (Bool) -> Void
    private let onSavedPhrasesChange: ([String]) -> Void
    private let step = 5
    private var percentField: NSTextField!

    init(currentPercent: Int,
         currentShowSuggestions: Bool,
         currentSavedPhrases: [String],
         onPercentChange: @escaping (Int) -> Void,
         onShowSuggestionsChange: @escaping (Bool) -> Void,
         onSavedPhrasesChange: @escaping ([String]) -> Void) {
        self.onPercentChange = onPercentChange
        self.onShowSuggestionsChange = onShowSuggestionsChange
        self.onSavedPhrasesChange = onSavedPhrasesChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "AllyKeyboard Settings"
        window.isReleasedWhenClosed = false
        window.level = .modalPanel   // above the keyboard panel (.statusBar)
        super.init(window: window)
        buildUI(currentPercent: currentPercent,
                currentShowSuggestions: currentShowSuggestions,
                currentSavedPhrases: currentSavedPhrases)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI(currentPercent: Int, currentShowSuggestions: Bool, currentSavedPhrases: [String]) {
        guard let content = window?.contentView else { return }

        let tabView = NSTabView(frame: content.bounds)
        tabView.autoresizingMask = [.width, .height]

        let general = NSTabViewItem(identifier: "general")
        general.label = "General"
        general.view = makeGeneralView(currentPercent: currentPercent)

        let suggestions = NSTabViewItem(identifier: "suggestions")
        suggestions.label = "Suggestions"
        suggestions.view = makeSuggestionsView(current: currentShowSuggestions,
                                               savedPhrases: currentSavedPhrases)

        [general, suggestions].forEach { tabView.addTabViewItem($0) }
        content.addSubview(tabView)
    }

    private func makeGeneralView(currentPercent: Int) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 200))

        let loginCheck = NSButton(checkboxWithTitle: "Launch at login (starts hidden)",
                                  target: self, action: #selector(loginToggled(_:)))
        loginCheck.frame = NSRect(x: 20, y: 158, width: 300, height: 22)
        loginCheck.state = LoginItem.isEnabled ? .on : .off

        let sizeLabel = NSTextField(labelWithString: "Keyboard size")
        sizeLabel.frame = NSRect(x: 20, y: 116, width: 260, height: 20)

        let minus = makeStepButton("\u{2212}", #selector(minusTapped))   // −
        minus.frame = NSRect(x: 20, y: 74, width: 34, height: 30)

        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.allowsFloats = false
        fmt.minimum = NSNumber(value: Settings.percentRange.lowerBound)
        fmt.maximum = NSNumber(value: Settings.percentRange.upperBound)

        percentField = NSTextField(frame: NSRect(x: 60, y: 77, width: 60, height: 24))
        percentField.formatter = fmt
        percentField.integerValue = currentPercent
        percentField.alignment = .center
        percentField.target = self
        percentField.action = #selector(fieldChanged(_:))

        let percentSign = NSTextField(labelWithString: "%")
        percentSign.frame = NSRect(x: 124, y: 79, width: 20, height: 20)

        let plus = makeStepButton("+", #selector(plusTapped))
        plus.frame = NSRect(x: 150, y: 74, width: 34, height: 30)

        [loginCheck, sizeLabel, minus, percentField, percentSign, plus].forEach { v.addSubview($0) }
        return v
    }

    private func makeSuggestionsView(current: Bool, savedPhrases: [String]) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 200))

        let check = NSButton(checkboxWithTitle: "Show suggestions while typing",
                             target: self, action: #selector(suggestionsToggled(_:)))
        check.frame = NSRect(x: 20, y: 170, width: 300, height: 22)
        check.state = current ? .on : .off

        let hint = NSTextField(labelWithString: "Saved phrases — one per line (opened by the list key)")
        hint.frame = NSRect(x: 20, y: 146, width: 320, height: 18)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 16, width: 300, height: 122))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let textView = NSTextView(frame: scroll.bounds)
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = savedPhrases.joined(separator: "\n")
        textView.autoresizingMask = [.width]
        textView.delegate = self
        scroll.documentView = textView

        [check, hint, scroll].forEach { v.addSubview($0) }
        return v
    }

    private func makeStepButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        return b
    }

    @objc private func minusTapped()  { applyPercent(percentField.integerValue - step) }
    @objc private func plusTapped()   { applyPercent(percentField.integerValue + step) }
    @objc private func fieldChanged(_ sender: NSTextField) { applyPercent(sender.integerValue) }

    private func applyPercent(_ raw: Int) {
        let percent = Settings.clampPercent(raw)
        percentField.integerValue = percent
        onPercentChange(percent)
    }

    @objc private func loginToggled(_ sender: NSButton) {
        LoginItem.setEnabled(sender.state == .on)
    }

    @objc private func suggestionsToggled(_ sender: NSButton) {
        onShowSuggestionsChange(sender.state == .on)
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let phrases = textView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        onSavedPhrasesChange(phrases)
    }

    func present() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
