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
    private let onTopBarShowChange: (Bool) -> Void
    private let onBottomBarShowChange: (Bool) -> Void
    private let onDragToMoveChange: (Bool) -> Void
    private let onDragCooldownChange: (Int) -> Void
    private var cooldownField: NSTextField!
    private var cooldownRows: [NSGridRow] = []   // shown only when drag-to-move is on
    private let onBottomBarHeightChange: (Int) -> Void
    private let onStartCollapsedChange: (Bool) -> Void
    private let onThemeChange: (String) -> Void
    private let onAppPanelIconChange: (Int) -> Void
    private let onAppPanelOpacityChange: (Int) -> Void
    private let onAppPanelHiddenChange: ([String]) -> Void
    private let onAppPanelAutoHideChange: (Int) -> Void
    private let onAppPanelHoverZoomChange: (Bool) -> Void
    private let onAppPanelOutlineWidthChange: (Int) -> Void
    private let onAppPanelOutlineGapChange: (Int) -> Void
    private var appOutlineWidthValue: NSTextField!
    private var appOutlineGapValue: NSTextField!
    private var appIconSlider: NSSlider!
    private var appOpacitySlider: NSSlider!
    private var appAutoHideSlider: NSSlider!
    private var appOutlineWidthSlider: NSSlider!
    private var appOutlineGapSlider: NSSlider!
    private var appIconSpacingSlider: NSSlider!
    private var appIconSpacingValue: NSTextField!
    private var appEdgeSpacingSlider: NSSlider!
    private var appEdgeSpacingValue: NSTextField!
    private let onAppPanelIconSpacingChange: (Int) -> Void
    private let onAppPanelEdgeSpacingChange: (Int) -> Void
    private var appIconField: NSTextField!
    private var appOpacityValue: NSTextField!
    private var appAutoHideValue: NSTextField!
    private var appHiddenView: NSTextView!
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
         currentTopBarShow: Bool,
         currentTopBarHeight: Int,
         currentBottomBarShow: Bool,
         currentBottomBarHeight: Int,
         currentDragToMove: Bool,
         currentDragCooldownMs: Int,
         currentStartCollapsed: Bool,
         currentTheme: String,
         currentAppPanelIcon: Int,
         currentAppPanelOpacity: Int,
         currentAppPanelHidden: [String],
         currentAppPanelAutoHide: Int,
         currentAppPanelHoverZoom: Bool,
         currentAppPanelOutlineWidth: Int,
         currentAppPanelOutlineGap: Int,
         currentAppPanelIconSpacing: Int,
         currentAppPanelEdgeSpacing: Int,
         onPercentChange: @escaping (Int) -> Void,
         onShowSuggestionsChange: @escaping (Bool) -> Void,
         onSavedPhrasesChange: @escaping ([String]) -> Void,
         onLauncherWidthChange: @escaping (Int) -> Void,
         onLauncherOpacityChange: @escaping (Int) -> Void,
         onTopBarHeightChange: @escaping (Int) -> Void,
         onTopBarShowChange: @escaping (Bool) -> Void,
         onBottomBarShowChange: @escaping (Bool) -> Void,
         onDragToMoveChange: @escaping (Bool) -> Void,
         onDragCooldownChange: @escaping (Int) -> Void,
         onBottomBarHeightChange: @escaping (Int) -> Void,
         onStartCollapsedChange: @escaping (Bool) -> Void,
         onThemeChange: @escaping (String) -> Void,
         onAppPanelIconChange: @escaping (Int) -> Void,
         onAppPanelOpacityChange: @escaping (Int) -> Void,
         onAppPanelHiddenChange: @escaping ([String]) -> Void,
         onAppPanelAutoHideChange: @escaping (Int) -> Void,
         onAppPanelHoverZoomChange: @escaping (Bool) -> Void,
         onAppPanelOutlineWidthChange: @escaping (Int) -> Void,
         onAppPanelOutlineGapChange: @escaping (Int) -> Void,
         onAppPanelIconSpacingChange: @escaping (Int) -> Void,
         onAppPanelEdgeSpacingChange: @escaping (Int) -> Void) {
        self.onPercentChange = onPercentChange
        self.onShowSuggestionsChange = onShowSuggestionsChange
        self.onSavedPhrasesChange = onSavedPhrasesChange
        self.onLauncherWidthChange = onLauncherWidthChange
        self.onLauncherOpacityChange = onLauncherOpacityChange
        self.onTopBarHeightChange = onTopBarHeightChange
        self.onTopBarShowChange = onTopBarShowChange
        self.onBottomBarShowChange = onBottomBarShowChange
        self.onDragToMoveChange = onDragToMoveChange
        self.onDragCooldownChange = onDragCooldownChange
        self.onBottomBarHeightChange = onBottomBarHeightChange
        self.onStartCollapsedChange = onStartCollapsedChange
        self.onThemeChange = onThemeChange
        self.onAppPanelIconChange = onAppPanelIconChange
        self.onAppPanelOpacityChange = onAppPanelOpacityChange
        self.onAppPanelHiddenChange = onAppPanelHiddenChange
        self.onAppPanelAutoHideChange = onAppPanelAutoHideChange
        self.onAppPanelHoverZoomChange = onAppPanelHoverZoomChange
        self.onAppPanelOutlineWidthChange = onAppPanelOutlineWidthChange
        self.onAppPanelOutlineGapChange = onAppPanelOutlineGapChange
        self.onAppPanelIconSpacingChange = onAppPanelIconSpacingChange
        self.onAppPanelEdgeSpacingChange = onAppPanelEdgeSpacingChange
        // Roomy on purpose. The panes are read and aimed at with a head
        // tracker, so a control that has to be hunted for costs far more here
        // than the screen space it saves.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "AllyKeyboard Settings"
        window.isReleasedWhenClosed = false
        window.level = AppConfig.Levels.settings   // genuinely above the keyboard
        super.init(window: window)
        buildUI(currentPercent: currentPercent,
                currentShowSuggestions: currentShowSuggestions,
                currentSavedPhrases: currentSavedPhrases,
                currentLauncherWidth: currentLauncherWidth,
                currentLauncherOpacity: currentLauncherOpacity,
                currentTopBarShow: currentTopBarShow,
                currentTopBarHeight: currentTopBarHeight,
                currentBottomBarShow: currentBottomBarShow,
                currentBottomBarHeight: currentBottomBarHeight,
                currentDragToMove: currentDragToMove,
                currentDragCooldownMs: currentDragCooldownMs,
                currentStartCollapsed: currentStartCollapsed,
                currentTheme: currentTheme,
                currentAppPanelIcon: currentAppPanelIcon,
                currentAppPanelOpacity: currentAppPanelOpacity,
                currentAppPanelHidden: currentAppPanelHidden,
                currentAppPanelAutoHide: currentAppPanelAutoHide,
                currentAppPanelHoverZoom: currentAppPanelHoverZoom,
                currentAppPanelOutlineWidth: currentAppPanelOutlineWidth,
                currentAppPanelOutlineGap: currentAppPanelOutlineGap,
                currentAppPanelIconSpacing: currentAppPanelIconSpacing,
                currentAppPanelEdgeSpacing: currentAppPanelEdgeSpacing)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI(currentPercent: Int, currentShowSuggestions: Bool, currentSavedPhrases: [String],
                         currentLauncherWidth: Int, currentLauncherOpacity: Int,
                         currentTopBarShow: Bool, currentTopBarHeight: Int,
                         currentBottomBarShow: Bool, currentBottomBarHeight: Int,
                         currentDragToMove: Bool, currentDragCooldownMs: Int,
                         currentStartCollapsed: Bool, currentTheme: String,
                         currentAppPanelIcon: Int, currentAppPanelOpacity: Int,
                         currentAppPanelHidden: [String], currentAppPanelAutoHide: Int,
                         currentAppPanelHoverZoom: Bool,
                         currentAppPanelOutlineWidth: Int, currentAppPanelOutlineGap: Int,
                         currentAppPanelIconSpacing: Int, currentAppPanelEdgeSpacing: Int) {
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
        bars.view = makeBarsView(topBarShow: currentTopBarShow,
                                 topBarHeight: currentTopBarHeight,
                                 bottomBarShow: currentBottomBarShow,
                                 bottomBarHeight: currentBottomBarHeight,
                                 dragToMove: currentDragToMove,
                                 dragCooldownMs: currentDragCooldownMs)

        let suggestions = NSTabViewItem(identifier: "suggestions")
        suggestions.label = "Suggestions"
        suggestions.view = makeSuggestionsView(current: currentShowSuggestions,
                                               savedPhrases: currentSavedPhrases)

        let launcher = NSTabViewItem(identifier: "launcher")
        launcher.label = "Launcher"
        launcher.view = makeLauncherView(width: currentLauncherWidth, opacity: currentLauncherOpacity)

        let apps = NSTabViewItem(identifier: "apps")
        // Apple's own name for it, from the system's voice-control strings:
        // `System.ShowApplicationSwitcher` is "App Switcher" in English and
        // "переключатель программ" in Russian. Worth borrowing rather than
        // inventing — the user already knows the thing by that name.
        apps.label = "App Switcher"
        apps.view = makeAppsView(iconSize: currentAppPanelIcon,
                                 opacity: currentAppPanelOpacity,
                                 hidden: currentAppPanelHidden,
                                 autoHide: currentAppPanelAutoHide,
                                 hoverZoom: currentAppPanelHoverZoom,
                                 outlineWidth: currentAppPanelOutlineWidth,
                                 outlineGap: currentAppPanelOutlineGap,
                                 iconSpacing: currentAppPanelIconSpacing,
                                 edgeSpacing: currentAppPanelEdgeSpacing)

        let about = NSTabViewItem(identifier: "about")
        about.label = "About"
        about.view = makeAboutView()

        // Each pane was laid out for a 340-point window, with positions measured
        // from the bottom — AppKit's origin — so in a taller window its controls
        // sat in the lower half under a field of nothing. Autoresizing masks do
        // not fix it: the pane is stretched once, before any mask is set, and
        // never resized again. Lifting the content here is not subject to that
        // order of events.
        [general, bars, suggestions, launcher, apps, about].forEach { tabView.addTabViewItem($0) }
        content.addSubview(tabView)
    }

    // MARK: - Apps tab (the running-applications panel)

    // MARK: - Form building
    //
    // Every pane is an NSGridView under constraints. Nothing here is positioned
    // by hand, which is the whole point: fixed frames measured from AppKit's
    // bottom-left origin are what put the controls in the wrong half of the
    // window each time it was resized, and no amount of shifting them
    // afterwards could survive NSTabView laying the pane out again.
    //
    // The shape follows System Settings: labels right-aligned in the first
    // column, controls left-aligned in the second, one set of margins for the
    // whole application.

    private enum Metrics {
        static let margin: CGFloat = 24
        static let rowGap: CGFloat = 12
        static let columnGap: CGFloat = 12
        static let sliderWidth: CGFloat = 220
        static let sectionGap: CGFloat = 10
    }

    private enum FormRow {
        case setting(String, NSView)      // label | control
        case tall(String, NSView)         // same, with the label at the top
        case wide(NSView)                 // no label: sits in the control column
        case note(String)                 // secondary text under a setting
        case gap
    }

    @discardableResult
    private func pane(_ rows: [FormRow], keep: ((String, NSGridRow) -> Void)? = nil) -> NSView {
        let grid = NSGridView(numberOfColumns: 2, rows: 0)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = Metrics.rowGap
        grid.columnSpacing = Metrics.columnGap
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        for row in rows {
            switch row {
            case .setting(let title, let control):
                let label = NSTextField(labelWithString: title)
                let r = grid.addRow(with: [label, control])
                r.yPlacement = .center
                keep?(title, r)
            case .tall(let title, let control):
                let label = NSTextField(labelWithString: title)
                let r = grid.addRow(with: [label, control])
                // A label beside a tall box belongs at its top edge, not
                // floating in the middle of it.
                r.yPlacement = .top
                keep?(title, r)
            case .wide(let view):
                // In the control column, not across both: a merged cell takes
                // the first column's alignment, and that one is right-aligned
                // because it holds the labels — which is how every standalone
                // checkbox ended up hugging the right edge.
                let r = grid.addRow(with: [NSGridCell.emptyContentView, view])
                keep?("", r)
            case .note(let text):
                let label = NSTextField(wrappingLabelWithString: text)
                label.font = .systemFont(ofSize: 11)
                label.textColor = .secondaryLabelColor
                label.preferredMaxLayoutWidth = 380
                let r = grid.addRow(with: [NSGridCell.emptyContentView, label])
                keep?(text, r)
            case .gap:
                let r = grid.addRow(with: [NSGridCell.emptyContentView])
                r.height = Metrics.sectionGap
            }
        }

        let container = NSView()
        grid.setContentHuggingPriority(.defaultHigh, for: .vertical)
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: Metrics.margin),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.margin),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor,
                                           constant: -Metrics.margin),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor,
                                         constant: -Metrics.margin),
        ])
        return container
    }

    /// A slider with its readout beside it — the shape most settings here take.
    private func sliderRow(value: Int, range: ClosedRange<Int>, action: Selector)
        -> (NSSlider, NSTextField, NSView) {
        let slider = NSSlider(value: Double(value),
                              minValue: Double(range.lowerBound),
                              maxValue: Double(range.upperBound),
                              target: self, action: action)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: Metrics.sliderWidth).isActive = true

        let readout = NSTextField(labelWithString: "\(value)")
        readout.alignment = .left
        readout.translatesAutoresizingMaskIntoConstraints = false
        readout.widthAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true

        let stack = NSStackView(views: [slider, readout])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        return (slider, readout, stack)
    }

    /// − [slider] + [field] unit — the shape every numeric setting takes.
    ///
    /// The stepper buttons are not decoration here: a head tracker hits a
    /// button far more easily than it drags a slider, so the buttons are the
    /// reliable way in and the slider is for a quick sweep.
    private func sliderWithSteppers(slider: NSSlider, field: NSTextField, unit: String,
                                    sliderWidth: CGFloat = 150,
                                    minus: Selector, plus: Selector) -> NSView {
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: sliderWidth).isActive = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let stack = NSStackView(views: [makeStepButton("\u{2212}", minus),
                                        slider,
                                        makeStepButton("+", plus),
                                        field,
                                        NSTextField(labelWithString: unit)])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    /// − [field] unit + — the stepper shape.
    private func stepperRow(field: NSTextField, unit: String,
                            minus: Selector, plus: Selector) -> NSView {
        let minusButton = makeStepButton("\u{2212}", minus)
        let plusButton = makeStepButton("+", plus)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 62).isActive = true
        let unitLabel = NSTextField(labelWithString: unit)
        let stack = NSStackView(views: [minusButton, field, unitLabel, plusButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func textArea(_ contents: [String], height: CGFloat) -> (NSTextView, NSView) {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.widthAnchor.constraint(equalToConstant: 420).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true

        let text = NSTextView()
        text.isEditable = true
        text.isRichText = false
        text.font = .systemFont(ofSize: 13)
        text.string = contents.joined(separator: "\n")
        text.autoresizingMask = [.width]
        text.delegate = self
        scroll.documentView = text
        return (text, scroll)
    }

    private func makeAppsView(iconSize: Int, opacity: Int,
                              hidden: [String], autoHide: Int,
                              hoverZoom: Bool,
                              outlineWidth: Int, outlineGap: Int,
                              iconSpacing: Int, edgeSpacing: Int) -> NSView {

        /// Every numeric setting here takes the same shape as the rest of the
        /// window: buttons to step, a slider to sweep, a field to read.
        func numeric(_ value: Int, _ range: ClosedRange<Int>, _ unit: String,
                     slider action: Selector, field: Selector,
                     minus: Selector, plus: Selector) -> (NSSlider, NSTextField, NSView) {
            let slider = NSSlider(value: Double(value),
                                  minValue: Double(range.lowerBound),
                                  maxValue: Double(range.upperBound),
                                  target: self, action: action)
            let field = numberField(value: value, range: range, action: field)
            let row = sliderWithSteppers(slider: slider, field: field, unit: unit,
                                         minus: minus, plus: plus)
            return (slider, field, row)
        }

        let (iconSlider, iconField, iconRow) = numeric(
            iconSize, Settings.appPanelIconRange, "pt",
            slider: #selector(appIconSliderChanged(_:)), field: #selector(appIconFieldChanged(_:)),
            minus: #selector(appIconMinus), plus: #selector(appIconPlus))
        appIconSlider = iconSlider; appIconField = iconField

        let (opacitySl, opacityFl, opacityRow) = numeric(
            opacity, Settings.appPanelOpacityRange, "%",
            slider: #selector(appOpacitySliderChanged(_:)), field: #selector(appOpacityFieldChanged(_:)),
            minus: #selector(appOpacityMinus), plus: #selector(appOpacityPlus))
        appOpacitySlider = opacitySl; appOpacityValue = opacityFl

        let (hideSl, hideFl, hideRow) = numeric(
            autoHide, Settings.appPanelAutoHideRange, "s",
            slider: #selector(appAutoHideSliderChanged(_:)), field: #selector(appAutoHideFieldChanged(_:)),
            minus: #selector(appAutoHideMinus), plus: #selector(appAutoHidePlus))
        appAutoHideSlider = hideSl; appAutoHideValue = hideFl

        let (widthSl, widthFl, widthRow) = numeric(
            outlineWidth, Settings.appPanelOutlineWidthRange, "pt",
            slider: #selector(appOutlineWidthChanged(_:)), field: #selector(appOutlineWidthFieldChanged(_:)),
            minus: #selector(appOutlineWidthMinus), plus: #selector(appOutlineWidthPlus))
        appOutlineWidthSlider = widthSl; appOutlineWidthValue = widthFl

        let (gapSl, gapFl, gapRow) = numeric(
            outlineGap, Settings.appPanelOutlineGapRange, "pt",
            slider: #selector(appOutlineGapChanged(_:)), field: #selector(appOutlineGapFieldChanged(_:)),
            minus: #selector(appOutlineGapMinus), plus: #selector(appOutlineGapPlus))
        appOutlineGapSlider = gapSl; appOutlineGapValue = gapFl

        let (spacingSl, spacingFl, spacingRow) = numeric(
            iconSpacing, Settings.appPanelIconSpacingRange, "pt",
            slider: #selector(appIconSpacingChanged(_:)), field: #selector(appIconSpacingFieldChanged(_:)),
            minus: #selector(appIconSpacingMinus), plus: #selector(appIconSpacingPlus))
        appIconSpacingSlider = spacingSl; appIconSpacingValue = spacingFl

        let (edgeSl, edgeFl, edgeRow) = numeric(
            edgeSpacing, Settings.appPanelEdgeSpacingRange, "pt",
            slider: #selector(appEdgeSpacingChanged(_:)), field: #selector(appEdgeSpacingFieldChanged(_:)),
            minus: #selector(appEdgeSpacingMinus), plus: #selector(appEdgeSpacingPlus))
        appEdgeSpacingSlider = edgeSl; appEdgeSpacingValue = edgeFl

        let zoomBox = NSButton(checkboxWithTitle: "Grow icons under the pointer",
                               target: self, action: #selector(appHoverZoomToggled(_:)))
        zoomBox.state = hoverZoom ? .on : .off

        let (text, scroll) = textArea(hidden, height: 90)
        appHiddenView = text

        return pane([
            .setting("Icon size", iconRow),
            .setting("Space between icons", spacingRow),
            .setting("Space around icons", edgeRow),
            .setting("Background opacity", opacityRow),
            .setting("Close by itself after", hideRow),
            .note("Zero leaves the panel open until you dismiss it."),
            .gap,
            .setting("Outline thickness", widthRow),
            .setting("Outline distance", gapRow),
            .note("The white outline marks the icon the pointer is on. Zero draws none."),
            .wide(zoomBox),
            .gap,
            .tall("Never show", scroll),
            .note("One application name per line."),
        ])
    }

    // Each setting: the slider, the field and the two buttons all end in one
    // place, so they cannot drift apart from each other.

    private func applyAppIcon(_ raw: Int) {
        let pt = Settings.clampAppPanelIcon(raw)
        appIconField.integerValue = pt; appIconSlider.integerValue = pt
        onAppPanelIconChange(pt)
    }
    @objc private func appIconSliderChanged(_ s: NSSlider) { applyAppIcon(s.integerValue) }
    @objc private func appIconFieldChanged(_ f: NSTextField) { applyAppIcon(f.integerValue) }
    @objc private func appIconMinus() { applyAppIcon(appIconField.integerValue - 4) }
    @objc private func appIconPlus()  { applyAppIcon(appIconField.integerValue + 4) }

    private func applyAppOpacity(_ raw: Int) {
        let percent = Settings.clampAppPanelOpacity(raw)
        appOpacityValue.integerValue = percent; appOpacitySlider.integerValue = percent
        onAppPanelOpacityChange(percent)
    }
    @objc private func appOpacitySliderChanged(_ s: NSSlider) { applyAppOpacity(s.integerValue) }
    @objc private func appOpacityFieldChanged(_ f: NSTextField) { applyAppOpacity(f.integerValue) }
    @objc private func appOpacityMinus() { applyAppOpacity(appOpacityValue.integerValue - step) }
    @objc private func appOpacityPlus()  { applyAppOpacity(appOpacityValue.integerValue + step) }

    private func applyAppAutoHide(_ raw: Int) {
        let seconds = Settings.clampAppPanelAutoHide(raw)
        appAutoHideValue.integerValue = seconds; appAutoHideSlider.integerValue = seconds
        onAppPanelAutoHideChange(seconds)
    }
    @objc private func appAutoHideSliderChanged(_ s: NSSlider) { applyAppAutoHide(s.integerValue) }
    @objc private func appAutoHideFieldChanged(_ f: NSTextField) { applyAppAutoHide(f.integerValue) }
    @objc private func appAutoHideMinus() { applyAppAutoHide(appAutoHideValue.integerValue - 1) }
    @objc private func appAutoHidePlus()  { applyAppAutoHide(appAutoHideValue.integerValue + 1) }

    private func applyAppOutlineWidth(_ raw: Int) {
        let pt = Settings.clampAppPanelOutlineWidth(raw)
        appOutlineWidthValue.integerValue = pt; appOutlineWidthSlider.integerValue = pt
        onAppPanelOutlineWidthChange(pt)
    }
    @objc private func appOutlineWidthChanged(_ s: NSSlider) { applyAppOutlineWidth(s.integerValue) }
    @objc private func appOutlineWidthFieldChanged(_ f: NSTextField) { applyAppOutlineWidth(f.integerValue) }
    @objc private func appOutlineWidthMinus() { applyAppOutlineWidth(appOutlineWidthValue.integerValue - 1) }
    @objc private func appOutlineWidthPlus()  { applyAppOutlineWidth(appOutlineWidthValue.integerValue + 1) }

    private func applyAppIconSpacing(_ raw: Int) {
        let pt = Settings.clampAppPanelIconSpacing(raw)
        appIconSpacingValue.integerValue = pt; appIconSpacingSlider.integerValue = pt
        onAppPanelIconSpacingChange(pt)
    }
    @objc private func appIconSpacingChanged(_ s: NSSlider) { applyAppIconSpacing(s.integerValue) }
    @objc private func appIconSpacingFieldChanged(_ f: NSTextField) { applyAppIconSpacing(f.integerValue) }
    @objc private func appIconSpacingMinus() { applyAppIconSpacing(appIconSpacingValue.integerValue - 2) }
    @objc private func appIconSpacingPlus()  { applyAppIconSpacing(appIconSpacingValue.integerValue + 2) }

    private func applyAppEdgeSpacing(_ raw: Int) {
        let pt = Settings.clampAppPanelEdgeSpacing(raw)
        appEdgeSpacingValue.integerValue = pt; appEdgeSpacingSlider.integerValue = pt
        onAppPanelEdgeSpacingChange(pt)
    }
    @objc private func appEdgeSpacingChanged(_ s: NSSlider) { applyAppEdgeSpacing(s.integerValue) }
    @objc private func appEdgeSpacingFieldChanged(_ f: NSTextField) { applyAppEdgeSpacing(f.integerValue) }
    @objc private func appEdgeSpacingMinus() { applyAppEdgeSpacing(appEdgeSpacingValue.integerValue - 2) }
    @objc private func appEdgeSpacingPlus()  { applyAppEdgeSpacing(appEdgeSpacingValue.integerValue + 2) }

    private func applyAppOutlineGap(_ raw: Int) {
        let pt = Settings.clampAppPanelOutlineGap(raw)
        appOutlineGapValue.integerValue = pt; appOutlineGapSlider.integerValue = pt
        onAppPanelOutlineGapChange(pt)
    }
    @objc private func appOutlineGapChanged(_ s: NSSlider) { applyAppOutlineGap(s.integerValue) }
    @objc private func appOutlineGapFieldChanged(_ f: NSTextField) { applyAppOutlineGap(f.integerValue) }
    @objc private func appOutlineGapMinus() { applyAppOutlineGap(appOutlineGapValue.integerValue - 1) }
    @objc private func appOutlineGapPlus()  { applyAppOutlineGap(appOutlineGapValue.integerValue + 1) }

    @objc private func appHoverZoomToggled(_ sender: NSButton) {
        onAppPanelHoverZoomChange(sender.state == .on)
    }

    private func makeAboutView() -> NSView {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "\u{2014}"
        let build = (info?["CFBundleVersion"] as? String) ?? ""

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let name = NSTextField(labelWithString: "AllyKeyboard")
        name.font = .systemFont(ofSize: 18, weight: .semibold)

        let ver = NSTextField(labelWithString: "Version \(version)" + (build.isEmpty ? "" : " (\(build))"))
        ver.textColor = .secondaryLabelColor

        let desc = NSTextField(labelWithString: "On-screen keyboard for head-tracker users.")
        desc.textColor = .secondaryLabelColor

        let link = NSButton(title: "View on GitHub", target: self, action: #selector(openRepo))
        link.bezelStyle = .rounded

        let stack = NSStackView(views: [icon, name, ver, desc, link])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
        ])
        return container
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/umkasanki/ally-keyboard") {
            NSWorkspace.shared.open(url)
        }
    }

    private func makeGeneralView(currentPercent: Int, currentStartCollapsed: Bool, currentTheme: String) -> NSView {
        let loginCheck = NSButton(checkboxWithTitle: "Launch at login (starts hidden)",
                                  target: self, action: #selector(loginToggled(_:)))
        loginCheck.state = LoginItem.isEnabled ? .on : .off

        let collapsedCheck = NSButton(checkboxWithTitle: "Launch collapsed (keyboard hidden)",
                                      target: self, action: #selector(startCollapsedToggled(_:)))
        collapsedCheck.state = currentStartCollapsed ? .on : .off

        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.allowsFloats = false
        fmt.minimum = NSNumber(value: Settings.percentRange.lowerBound)
        fmt.maximum = NSNumber(value: Settings.percentRange.upperBound)
        percentField = NSTextField()
        percentField.formatter = fmt
        percentField.integerValue = currentPercent
        percentField.alignment = .center
        percentField.target = self
        percentField.action = #selector(fieldChanged(_:))

        let themePopup = NSPopUpButton()
        for t in AppConfig.Theme.allCases {
            themePopup.addItem(withTitle: t.displayName)
            themePopup.lastItem?.representedObject = t.rawValue
        }
        if let idx = AppConfig.Theme.allCases.firstIndex(where: { $0.rawValue == currentTheme }) {
            themePopup.selectItem(at: idx)
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))

        return pane([
            .wide(loginCheck),
            .wide(collapsedCheck),
            .gap,
            .setting("Keyboard size", stepperRow(field: percentField, unit: "%",
                                                 minus: #selector(minusTapped),
                                                 plus: #selector(plusTapped))),
            .setting("Theme", themePopup),
        ])
    }

    private func makeBarsView(topBarShow: Bool, topBarHeight: Int, bottomBarShow: Bool, bottomBarHeight: Int,
                              dragToMove: Bool, dragCooldownMs: Int) -> NSView {
        let topShowCheck = NSButton(checkboxWithTitle: "Show top bar",
                                    target: self, action: #selector(topShowToggled(_:)))
        topShowCheck.state = topBarShow ? .on : .off
        topBarField = makeBarField(value: topBarHeight, range: Settings.topBarHeightRange,
                                   action: #selector(topBarFieldChanged(_:)))

        let showCheck = NSButton(checkboxWithTitle: "Show bottom bar",
                                 target: self, action: #selector(bottomShowToggled(_:)))
        showCheck.state = bottomBarShow ? .on : .off
        bottomBarField = makeBarField(value: bottomBarHeight, range: Settings.bottomBarHeightRange,
                                      action: #selector(bottomBarFieldChanged(_:)))

        let dragCheck = NSButton(checkboxWithTitle: "Move keyboard by dragging keys",
                                 target: self, action: #selector(dragToMoveToggled(_:)))
        dragCheck.state = dragToMove ? .on : .off

        let cdFmt = NumberFormatter()
        cdFmt.numberStyle = .none; cdFmt.allowsFloats = false
        cdFmt.minimum = NSNumber(value: Settings.dragCooldownRange.lowerBound)
        cdFmt.maximum = NSNumber(value: Settings.dragCooldownRange.upperBound)
        cooldownField = NSTextField()
        cooldownField.formatter = cdFmt
        cooldownField.integerValue = dragCooldownMs
        cooldownField.alignment = .center
        cooldownField.target = self
        cooldownField.action = #selector(cooldownChanged(_:))
        cooldownField.translatesAutoresizingMaskIntoConstraints = false
        cooldownField.widthAnchor.constraint(equalToConstant: 62).isActive = true
        let cdUnit = NSTextField(labelWithString: "ms")
        let cdStack = NSStackView(views: [cooldownField, cdUnit])
        cdStack.orientation = .horizontal
        cdStack.spacing = 8

        let cooldownNote = "After you drag the keyboard by a key, key presses are ignored for this "
            + "long. A head tracker ends a drag with a click at the release point — this delay "
            + "prevents that click from typing a stray character. 0 disables it."

        // The cooldown row belongs to drag-to-move and is hidden with it. Whole
        // grid rows are hidden, not the views inside them, so nothing leaves a
        // hole behind.
        var rows: [NSGridRow] = []
        let view = pane([
            .wide(topShowCheck),
            .setting("Top bar height", stepperRow(field: topBarField, unit: "pt",
                                                  minus: #selector(topBarMinusTapped),
                                                  plus: #selector(topBarPlusTapped))),
            .gap,
            .wide(showCheck),
            .setting("Bottom bar height", stepperRow(field: bottomBarField, unit: "pt",
                                                     minus: #selector(bottomBarMinusTapped),
                                                     plus: #selector(bottomBarPlusTapped))),
            .gap,
            .wide(dragCheck),
            .setting("Drag cooldown", cdStack),
            .note(cooldownNote),
        ], keep: { title, row in
            if title == "Drag cooldown" || title == cooldownNote { rows.append(row) }
        })
        cooldownRows = rows
        cooldownRows.forEach { $0.isHidden = !dragToMove }
        return view
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
        let check = NSButton(checkboxWithTitle: "Show suggestions while typing",
                             target: self, action: #selector(suggestionsToggled(_:)))
        check.state = current ? .on : .off
        let (_, scroll) = textArea(savedPhrases, height: 150)
        return pane([
            .wide(check),
            .gap,
            .tall("Saved phrases", scroll),
            .note("One per line. The list key on the keyboard opens them."),
        ])
    }

    private func makeLauncherView(width: Int, opacity: Int) -> NSView {
        widthField = numberField(value: width, range: Settings.launcherWidthRange,
                                 action: #selector(widthFieldChanged(_:)))
        widthSlider = NSSlider(value: Double(width),
                               minValue: Double(Settings.launcherWidthRange.lowerBound),
                               maxValue: Double(Settings.launcherWidthRange.upperBound),
                               target: self, action: #selector(widthSliderChanged(_:)))

        opacityValue = numberField(value: opacity, range: Settings.launcherOpacityRange,
                                   action: #selector(opacityFieldChanged(_:)))
        opacitySlider = NSSlider(value: Double(opacity),
                                 minValue: Double(Settings.launcherOpacityRange.lowerBound),
                                 maxValue: Double(Settings.launcherOpacityRange.upperBound),
                                 target: self, action: #selector(opacitySliderChanged(_:)))

        return pane([
            .setting("Launcher width", sliderWithSteppers(slider: widthSlider, field: widthField,
                                                          unit: "pt",
                                                          minus: #selector(widthMinusTapped),
                                                          plus: #selector(widthPlusTapped))),
            .setting("Opacity", sliderWithSteppers(slider: opacitySlider, field: opacityValue,
                                                   unit: "%",
                                                   minus: #selector(opacityMinusTapped),
                                                   plus: #selector(opacityPlusTapped))),
            .note("The small floating button that brings the keyboard back."),
        ])
    }

    /// A field that only takes whole numbers in range.
    private func numberField(value: Int, range: ClosedRange<Int>, action: Selector) -> NSTextField {
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

    @objc private func opacitySliderChanged(_ sender: NSSlider) { applyOpacity(sender.integerValue) }
    @objc private func opacityMinusTapped() { applyOpacity(opacityValue.integerValue - step) }
    @objc private func opacityPlusTapped()  { applyOpacity(opacityValue.integerValue + step) }
    @objc private func opacityFieldChanged(_ sender: NSTextField) { applyOpacity(sender.integerValue) }

    private func applyOpacity(_ raw: Int) {
        let percent = Settings.clampLauncherOpacity(raw)
        opacityValue.integerValue = percent
        opacitySlider.integerValue = percent
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

    @objc private func dragToMoveToggled(_ sender: NSButton) {
        onDragToMoveChange(sender.state == .on)
        cooldownRows.forEach { $0.isHidden = sender.state != .on }
    }
    @objc private func cooldownChanged(_ sender: NSTextField) {
        let ms = Settings.clampDragCooldown(sender.integerValue)
        cooldownField.integerValue = ms
        onDragCooldownChange(ms)
    }

    @objc private func topShowToggled(_ sender: NSButton) { onTopBarShowChange(sender.state == .on) }
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

    /// Two text views now share this delegate — the saved phrases and the list
    /// of applications to leave out — so it must ask which one changed. Without
    /// that, typing an application name would overwrite the phrases.
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let lines = textView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if textView === appHiddenView {
            onAppPanelHiddenChange(lines)
        } else {
            onSavedPhrasesChange(lines)
        }
    }

    func present() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
