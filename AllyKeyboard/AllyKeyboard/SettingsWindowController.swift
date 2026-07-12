//
//  SettingsWindowController.swift
//  AllyKeyboard
//
//  Tabbed settings window:
//   • General     — launch-at-login + keyboard size (percent, 100% = base).
//   • Suggestions — show word predictions while typing, and the saved phrases
//                   opened by the list key (one per line).
//   • Launcher    — floating-launcher width (points) and opacity (percent).
//

import AppKit
import AllyKeyboardCore

final class SettingsWindowController: NSWindowController, NSTextViewDelegate {

    private let onPercentChange: (Int) -> Void
    private let onShowSuggestionsChange: (Bool) -> Void
    private let onSavedPhrasesChange: ([String]) -> Void
    private let onLauncherWidthChange: (Int) -> Void
    private let onLauncherOpacityChange: (Int) -> Void
    private let onTopBarHeightChange: (Int) -> Void
    private let onBottomBarShowChange: (Bool) -> Void
    private let onBottomBarHeightChange: (Int) -> Void
    private let onStartCollapsedChange: (Bool) -> Void
    private let onThemeChange: (String) -> Void
    private let step = 5
    private var percentField: NSTextField!
    private var widthField: NSTextField!
    private var widthSlider: NSSlider!
    private var opacitySlider: NSSlider!
    private var opacityValue: NSTextField!
    private var topBarField: NSTextField!
    private var bottomBarField: NSTextField!

    init(currentPercent: Int,
         currentShowSuggestions: Bool,
         currentSavedPhrases: [String],
         currentLauncherWidth: Int,
         currentLauncherOpacity: Int,
         currentTopBarHeight: Int,
         currentBottomBarShow: Bool,
         currentBottomBarHeight: Int,
         currentStartCollapsed: Bool,
         currentTheme: String,
         onPercentChange: @escaping (Int) -> Void,
         onShowSuggestionsChange: @escaping (Bool) -> Void,
         onSavedPhrasesChange: @escaping ([String]) -> Void,
         onLauncherWidthChange: @escaping (Int) -> Void,
         onLauncherOpacityChange: @escaping (Int) -> Void,
         onTopBarHeightChange: @escaping (Int) -> Void,
         onBottomBarShowChange: @escaping (Bool) -> Void,
         onBottomBarHeightChange: @escaping (Int) -> Void,
         onStartCollapsedChange: @escaping (Bool) -> Void,
         onThemeChange: @escaping (String) -> Void) {
        self.onPercentChange = onPercentChange
        self.onShowSuggestionsChange = onShowSuggestionsChange
        self.onSavedPhrasesChange = onSavedPhrasesChange
        self.onLauncherWidthChange = onLauncherWidthChange
        self.onLauncherOpacityChange = onLauncherOpacityChange
        self.onTopBarHeightChange = onTopBarHeightChange
        self.onBottomBarShowChange = onBottomBarShowChange
        self.onBottomBarHeightChange = onBottomBarHeightChange
        self.onStartCollapsedChange = onStartCollapsedChange
        self.onThemeChange = onThemeChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "AllyKeyboard Settings"
        window.isReleasedWhenClosed = false
        window.level = .modalPanel   // above the keyboard panel (.statusBar)
        super.init(window: window)
        buildUI(currentPercent: currentPercent,
                currentShowSuggestions: currentShowSuggestions,
                currentSavedPhrases: currentSavedPhrases,
                currentLauncherWidth: currentLauncherWidth,
                currentLauncherOpacity: currentLauncherOpacity,
                currentTopBarHeight: currentTopBarHeight,
                currentBottomBarShow: currentBottomBarShow,
                currentBottomBarHeight: currentBottomBarHeight,
                currentStartCollapsed: currentStartCollapsed,
                currentTheme: currentTheme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI(currentPercent: Int, currentShowSuggestions: Bool, currentSavedPhrases: [String],
                         currentLauncherWidth: Int, currentLauncherOpacity: Int, currentTopBarHeight: Int,
                         currentBottomBarShow: Bool, currentBottomBarHeight: Int,
                         currentStartCollapsed: Bool, currentTheme: String) {
        guard let content = window?.contentView else { return }

        let tabView = NSTabView(frame: content.bounds)
        tabView.autoresizingMask = [.width, .height]

        let general = NSTabViewItem(identifier: "general")
        general.label = "General"
        general.view = makeGeneralView(currentPercent: currentPercent,
                                       currentStartCollapsed: currentStartCollapsed,
                                       currentTheme: currentTheme)

        let bars = NSTabViewItem(identifier: "bars")
        bars.label = "Bars"
        bars.view = makeBarsView(topBarHeight: currentTopBarHeight,
                                 bottomBarShow: currentBottomBarShow,
                                 bottomBarHeight: currentBottomBarHeight)

        let suggestions = NSTabViewItem(identifier: "suggestions")
        suggestions.label = "Suggestions"
        suggestions.view = makeSuggestionsView(current: currentShowSuggestions,
                                               savedPhrases: currentSavedPhrases)

        let launcher = NSTabViewItem(identifier: "launcher")
        launcher.label = "Launcher"
        launcher.view = makeLauncherView(width: currentLauncherWidth, opacity: currentLauncherOpacity)

        let about = NSTabViewItem(identifier: "about")
        about.label = "About"
        about.view = makeAboutView()

        [general, bars, suggestions, launcher, about].forEach { tabView.addTabViewItem($0) }
        content.addSubview(tabView)
    }

    private func makeAboutView() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 270))
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info?["CFBundleVersion"] as? String) ?? ""

        let icon = NSImageView(frame: NSRect(x: 138, y: 178, width: 64, height: 64))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown

        let name = NSTextField(labelWithString: "AllyKeyboard")
        name.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        name.alignment = .center
        name.frame = NSRect(x: 20, y: 148, width: 300, height: 24)

        let ver = NSTextField(labelWithString: "Version \(version)" + (build.isEmpty ? "" : " (\(build))"))
        ver.textColor = .secondaryLabelColor
        ver.alignment = .center
        ver.frame = NSRect(x: 20, y: 126, width: 300, height: 18)

        let desc = NSTextField(labelWithString: "On-screen keyboard for head-tracker users.")
        desc.textColor = .secondaryLabelColor
        desc.alignment = .center
        desc.frame = NSRect(x: 20, y: 100, width: 300, height: 18)

        let link = NSButton(title: "View on GitHub", target: self, action: #selector(openRepo))
        link.bezelStyle = .rounded
        link.frame = NSRect(x: 110, y: 56, width: 120, height: 28)

        [icon, name, ver, desc, link].forEach { v.addSubview($0) }
        return v
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/umkasanki/ally-keyboard") {
            NSWorkspace.shared.open(url)
        }
    }

    private func makeGeneralView(currentPercent: Int, currentStartCollapsed: Bool, currentTheme: String) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 270))

        let loginCheck = NSButton(checkboxWithTitle: "Launch at login (starts hidden)",
                                  target: self, action: #selector(loginToggled(_:)))
        loginCheck.frame = NSRect(x: 20, y: 236, width: 320, height: 22)
        loginCheck.state = LoginItem.isEnabled ? .on : .off

        let collapsedCheck = NSButton(checkboxWithTitle: "Launch collapsed (keyboard hidden)",
                                      target: self, action: #selector(startCollapsedToggled(_:)))
        collapsedCheck.frame = NSRect(x: 20, y: 208, width: 320, height: 22)
        collapsedCheck.state = currentStartCollapsed ? .on : .off

        let sizeLabel = NSTextField(labelWithString: "Keyboard size")
        sizeLabel.frame = NSRect(x: 20, y: 170, width: 260, height: 20)

        let minus = makeStepButton("\u{2212}", #selector(minusTapped))   // −
        minus.frame = NSRect(x: 20, y: 128, width: 34, height: 30)

        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.allowsFloats = false
        fmt.minimum = NSNumber(value: Settings.percentRange.lowerBound)
        fmt.maximum = NSNumber(value: Settings.percentRange.upperBound)

        percentField = NSTextField(frame: NSRect(x: 60, y: 131, width: 60, height: 24))
        percentField.formatter = fmt
        percentField.integerValue = currentPercent
        percentField.alignment = .center
        percentField.target = self
        percentField.action = #selector(fieldChanged(_:))

        let percentSign = NSTextField(labelWithString: "%")
        percentSign.frame = NSRect(x: 124, y: 133, width: 20, height: 20)

        let plus = makeStepButton("+", #selector(plusTapped))
        plus.frame = NSRect(x: 150, y: 128, width: 34, height: 30)

        let themeLabel = NSTextField(labelWithString: "Theme")
        themeLabel.frame = NSRect(x: 20, y: 92, width: 120, height: 20)

        let themePopup = NSPopUpButton(frame: NSRect(x: 20, y: 60, width: 200, height: 26))
        for t in AppConfig.Theme.allCases {
            themePopup.addItem(withTitle: t.displayName)
            themePopup.lastItem?.representedObject = t.rawValue
        }
        if let idx = AppConfig.Theme.allCases.firstIndex(where: { $0.rawValue == currentTheme }) {
            themePopup.selectItem(at: idx)
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))

        [loginCheck, collapsedCheck, sizeLabel, minus, percentField, percentSign, plus,
         themeLabel, themePopup].forEach { v.addSubview($0) }
        return v
    }

    private func makeBarsView(topBarHeight: Int, bottomBarShow: Bool, bottomBarHeight: Int) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 270))

        // --- Top bar ---
        let topBarLabel = NSTextField(labelWithString: "Top bar height")
        topBarLabel.frame = NSRect(x: 20, y: 228, width: 260, height: 20)

        let tbMinus = makeStepButton("\u{2212}", #selector(topBarMinusTapped))
        tbMinus.frame = NSRect(x: 20, y: 186, width: 34, height: 30)
        topBarField = makeBarField(value: topBarHeight, range: Settings.topBarHeightRange,
                                   action: #selector(topBarFieldChanged(_:)))
        topBarField.frame = NSRect(x: 60, y: 189, width: 60, height: 24)
        let tbPt = NSTextField(labelWithString: "pt")
        tbPt.frame = NSRect(x: 124, y: 191, width: 24, height: 20)
        let tbPlus = makeStepButton("+", #selector(topBarPlusTapped))
        tbPlus.frame = NSRect(x: 152, y: 186, width: 34, height: 30)

        // --- Bottom bar ---
        let showCheck = NSButton(checkboxWithTitle: "Show bottom bar",
                                 target: self, action: #selector(bottomShowToggled(_:)))
        showCheck.frame = NSRect(x: 20, y: 132, width: 300, height: 22)
        showCheck.state = bottomBarShow ? .on : .off

        let bottomBarLabel = NSTextField(labelWithString: "Bottom bar height")
        bottomBarLabel.frame = NSRect(x: 20, y: 96, width: 260, height: 20)

        let bbMinus = makeStepButton("\u{2212}", #selector(bottomBarMinusTapped))
        bbMinus.frame = NSRect(x: 20, y: 54, width: 34, height: 30)
        bottomBarField = makeBarField(value: bottomBarHeight, range: Settings.bottomBarHeightRange,
                                      action: #selector(bottomBarFieldChanged(_:)))
        bottomBarField.frame = NSRect(x: 60, y: 57, width: 60, height: 24)
        let bbPt = NSTextField(labelWithString: "pt")
        bbPt.frame = NSRect(x: 124, y: 59, width: 24, height: 20)
        let bbPlus = makeStepButton("+", #selector(bottomBarPlusTapped))
        bbPlus.frame = NSRect(x: 152, y: 54, width: 34, height: 30)

        [topBarLabel, tbMinus, topBarField, tbPt, tbPlus,
         showCheck, bottomBarLabel, bbMinus, bottomBarField, bbPt, bbPlus].forEach { v.addSubview($0) }
        return v
    }

    private func makeBarField(value: Int, range: ClosedRange<Int>, action: Selector) -> NSTextField {
        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.allowsFloats = false
        fmt.minimum = NSNumber(value: range.lowerBound)
        fmt.maximum = NSNumber(value: range.upperBound)
        let field = NSTextField()
        field.formatter = fmt
        field.integerValue = value
        field.alignment = .center
        field.target = self
        field.action = action
        return field
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

    private func makeLauncherView(width: Int, opacity: Int) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 200))

        // --- Width row: −  [slider]  +   [field] pt ---
        let widthLabel = NSTextField(labelWithString: "Launcher width")
        widthLabel.frame = NSRect(x: 20, y: 168, width: 260, height: 20)

        let wMinus = makeStepButton("\u{2212}", #selector(widthMinusTapped))
        wMinus.frame = NSRect(x: 20, y: 128, width: 34, height: 30)

        widthSlider = NSSlider(value: Double(width),
                               minValue: Double(Settings.launcherWidthRange.lowerBound),
                               maxValue: Double(Settings.launcherWidthRange.upperBound),
                               target: self, action: #selector(widthSliderChanged(_:)))
        widthSlider.frame = NSRect(x: 62, y: 132, width: 150, height: 24)

        let wPlus = makeStepButton("+", #selector(widthPlusTapped))
        wPlus.frame = NSRect(x: 220, y: 128, width: 34, height: 30)

        let wfmt = NumberFormatter()
        wfmt.numberStyle = .none
        wfmt.allowsFloats = false
        wfmt.minimum = NSNumber(value: Settings.launcherWidthRange.lowerBound)
        wfmt.maximum = NSNumber(value: Settings.launcherWidthRange.upperBound)

        widthField = NSTextField(frame: NSRect(x: 262, y: 130, width: 46, height: 24))
        widthField.formatter = wfmt
        widthField.integerValue = width
        widthField.alignment = .center
        widthField.target = self
        widthField.action = #selector(widthFieldChanged(_:))

        let pt = NSTextField(labelWithString: "pt")
        pt.frame = NSRect(x: 312, y: 132, width: 20, height: 20)

        // --- Opacity row: [slider]  NN% ---
        let opacityLabel = NSTextField(labelWithString: "Opacity")
        opacityLabel.frame = NSRect(x: 20, y: 84, width: 260, height: 20)

        opacitySlider = NSSlider(value: Double(opacity),
                                 minValue: Double(Settings.launcherOpacityRange.lowerBound),
                                 maxValue: Double(Settings.launcherOpacityRange.upperBound),
                                 target: self, action: #selector(opacitySliderChanged(_:)))
        opacitySlider.frame = NSRect(x: 20, y: 48, width: 250, height: 24)

        opacityValue = NSTextField(labelWithString: "\(opacity)%")
        opacityValue.frame = NSRect(x: 278, y: 50, width: 50, height: 20)
        opacityValue.alignment = .left

        [widthLabel, wMinus, widthSlider, wPlus, widthField, pt,
         opacityLabel, opacitySlider, opacityValue].forEach { v.addSubview($0) }
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

    @objc private func widthMinusTapped() { applyWidth(widthField.integerValue - step) }
    @objc private func widthPlusTapped()  { applyWidth(widthField.integerValue + step) }
    @objc private func widthFieldChanged(_ sender: NSTextField) { applyWidth(sender.integerValue) }
    @objc private func widthSliderChanged(_ sender: NSSlider) { applyWidth(sender.integerValue) }

    private func applyWidth(_ raw: Int) {
        let width = Settings.clampLauncherWidth(raw)
        widthField.integerValue = width
        widthSlider.integerValue = width
        onLauncherWidthChange(width)
    }

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        let percent = Settings.clampLauncherOpacity(sender.integerValue)
        opacityValue.stringValue = "\(percent)%"
        onLauncherOpacityChange(percent)
    }

    @objc private func topBarMinusTapped() { applyTopBar(topBarField.integerValue - 1) }
    @objc private func topBarPlusTapped()  { applyTopBar(topBarField.integerValue + 1) }
    @objc private func topBarFieldChanged(_ sender: NSTextField) { applyTopBar(sender.integerValue) }

    private func applyTopBar(_ raw: Int) {
        let pt = Settings.clampTopBarHeight(raw)
        topBarField.integerValue = pt
        onTopBarHeightChange(pt)
    }

    @objc private func bottomShowToggled(_ sender: NSButton) { onBottomBarShowChange(sender.state == .on) }
    @objc private func bottomBarMinusTapped() { applyBottomBar(bottomBarField.integerValue - 1) }
    @objc private func bottomBarPlusTapped()  { applyBottomBar(bottomBarField.integerValue + 1) }
    @objc private func bottomBarFieldChanged(_ sender: NSTextField) { applyBottomBar(sender.integerValue) }

    private func applyBottomBar(_ raw: Int) {
        let pt = Settings.clampBottomBarHeight(raw)
        bottomBarField.integerValue = pt
        onBottomBarHeightChange(pt)
    }

    @objc private func loginToggled(_ sender: NSButton) {
        LoginItem.setEnabled(sender.state == .on)
    }

    @objc private func startCollapsedToggled(_ sender: NSButton) {
        onStartCollapsedChange(sender.state == .on)
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        if let raw = sender.selectedItem?.representedObject as? String { onThemeChange(raw) }
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
