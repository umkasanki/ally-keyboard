//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa
import AllyKeyboardCore

// MARK: - CustomStatusBar

final class CustomStatusBar: NSView {

    private let titleIcon   = NSImageView()
    private let minimizeBtn = NSButton()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = AppConfig.Colors.statusBarBg.cgColor
        setupTitle()
        setupMinimizeButton()
        var constraints: [NSLayoutConstraint] = [
            titleIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleIcon.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.50),
            minimizeBtn.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            minimizeBtn.widthAnchor.constraint(equalTo: minimizeBtn.heightAnchor, multiplier: 3),
            minimizeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ]
        // Keep the glyph's aspect ratio (3-row keyboard is wider than tall).
        if let image = titleIcon.image, image.size.height > 0 {
            let aspect = image.size.width / image.size.height
            constraints.append(titleIcon.widthAnchor.constraint(equalTo: titleIcon.heightAnchor, multiplier: aspect))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func setupTitle() {
        titleIcon.translatesAutoresizingMaskIntoConstraints = false
        titleIcon.imageScaling = .scaleProportionallyUpOrDown
        if let image = NSImage(named: "keyboard-glyph") {
            image.isTemplate = true
            titleIcon.image = image
            titleIcon.contentTintColor = NSColor(white: 1.0, alpha: 1.0)
        }
        addSubview(titleIcon)
    }

    private func setupMinimizeButton() {
        minimizeBtn.isBordered             = false
        minimizeBtn.wantsLayer             = true
        minimizeBtn.layer?.cornerRadius    = 6
        minimizeBtn.layer?.backgroundColor = NSColor.systemYellow.cgColor
        minimizeBtn.layer?.masksToBounds   = true
        minimizeBtn.translatesAutoresizingMaskIntoConstraints = false
        minimizeBtn.title = ""
        minimizeBtn.target = self
        minimizeBtn.action = #selector(minimizeTapped)
        addSubview(minimizeBtn)
    }

    @objc private func minimizeTapped() { (NSApp.delegate as? AppDelegate)?.hideKeyboard() }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - DragHandle

private class DragHandle: NSView {

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = AppConfig.Colors.dragBarBg.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        let dotDiameter: CGFloat = 6
        let dotGap:      CGFloat = 8
        let totalWidth = 3 * dotDiameter + 2 * dotGap
        var x = (bounds.width - totalWidth) / 2
        let y = (bounds.height - dotDiameter) / 2

        NSColor(white: 1.0, alpha: 0.5).setFill()
        for _ in 0..<3 {
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotDiameter, height: dotDiameter)).fill()
            x += dotDiameter + dotGap
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(DragHandle.appMenu, with: event, for: self)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    static let appMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit AllyKeyboard",
                                action: #selector(NSApp.terminate(_:)),
                                keyEquivalent: ""))
        return menu
    }()
}

// MARK: - KeyButton

/// Custom keyboard key with dark styling, hover highlight, and red press feedback.
final class KeyButton: NSButton {

    private var isHovered = false
    var isActive = false { didSet { updateBackground() } }
    /// Overrides the resting background (e.g. suggestion rows blend into the keyboard bg).
    var normalColorOverride: NSColor? { didSet { updateBackground() } }

    /// Secondary symbol drawn in the top-right corner of the key (e.g. shifted character).
    var secondaryText: String? { didSet { needsDisplay = true } }
    var secondaryFontSize: CGFloat = 8
    /// Character to send when Shift is active (overrides uppercased keyID for punctuation)
    var shiftedChar: String?
    /// When set, the key always types this literal string, regardless of the active layout.
    var literalChar: String?

    /// A dimmed glyph (text/icon) hosted in a subview so its brightness can animate.
    private var glyphView: NSView?
    private var restGlyphAlpha: CGFloat = 1.0
    private var isPressed = false

    override init(frame: NSRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    /// Host a glyph that rests dimmed and brightens to full on hover/press.
    func installGlyph(_ view: NSView, restAlpha: CGFloat) {
        title = ""            // hide the button's own default title/image behind the glyph
        image = nil
        glyphView?.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: centerXAnchor),
            view.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        glyphView = view
        restGlyphAlpha = restAlpha
        updateGlyphAlpha(animated: false)
    }

    private func updateGlyphAlpha(animated: Bool) {
        guard let glyphView = glyphView else { return }
        let target: CGFloat = (isHovered || isPressed) ? 1.0 : restGlyphAlpha
        if animated {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; glyphView.animator().alphaValue = target }
        } else {
            glyphView.alphaValue = target
        }
    }

    // Keep the whole key clickable; the glyph subview is decorative.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) != nil ? self : nil
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = AppConfig.Layout.keyCornerRadius
        layer?.masksToBounds = true
        isBordered = false
        contentTintColor = .white
        updateBackground()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas
            .filter { $0.owner === self }
            .forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  updateBackground(); updateGlyphAlpha(animated: true) }
    override func mouseExited (with event: NSEvent) { isHovered = false; updateBackground(); updateGlyphAlpha(animated: true) }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        isPressed = flag
        updateGlyphAlpha(animated: true)
        if flag {
            layer?.backgroundColor = AppConfig.Colors.keyPressed.cgColor
        } else {
            updateBackground()
        }
    }

    private func updateBackground() {
        let normal = normalColorOverride ?? AppConfig.Colors.keyNormal
        layer?.backgroundColor = (isActive ? AppConfig.Colors.keyActive : isHovered ? AppConfig.Colors.keyHover : normal).cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let text = secondaryText else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: secondaryFontSize, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.5)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        // Top-right corner: x from right edge, y from top edge (flipped: y=0 is top in draw)
        let margin: CGFloat = 3
        let x = bounds.width  - size.width  - margin
        let y = margin
        str.draw(at: NSPoint(x: x, y: y))
    }
}

// MARK: - ViewController

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:              String      // used for key simulation (CGEvent)
        let title:           String      // primary label on the key face
        let secondary:       String?     // secondary label (top-left, small) — e.g. shifted symbol
        let image:           String?     // SF Symbol — overrides title when set
        let widthMultiplier: CGFloat     // 1.0 = standard key width
        let fontScale:       CGFloat     // title font size multiplier (1.0 = default)
        let fixed:           Bool        // label/output never change with the active layout
        let colored:         Bool        // render the image in full color (not a template tint)

        init(_ id: String,
             title: String? = nil,
             secondary: String? = nil,
             image: String? = nil,
             w: CGFloat = 1.0,
             fontScale: CGFloat = 1.0,
             fixed: Bool = false,
             colored: Bool = false) {
            self.id              = id
            self.title           = title ?? id
            self.secondary       = secondary
            self.image           = image
            self.widthMultiplier = w
            self.fontScale       = fontScale
            self.fixed           = fixed
            self.colored         = colored
        }

        /// An empty, non-interactive gap used to keep rows aligned.
        static func spacer(_ w: CGFloat) -> Key { Key("__spacer__", title: "", w: w) }
        var isSpacer: Bool { id == "__spacer__" }
    }


    // MARK: - Scale

    var scale: CGFloat = AppConfig.Layout.keyboardScale {
        didSet {
            guard windowConfigured, let window = view.window else { return }
            let size = keyboardSize
            window.setContentSize(size)
            buildKeyboard()
        }
    }

    // MARK: - Settings

    private let settingsStore = SettingsStore()
    private var settings = Settings()

    var currentSizePercent: Int { settings.sizePercent }

    /// Apply and persist a new size preset (live-resizes the keyboard).
    func applySizePercent(_ percent: Int) {
        settings.sizePercent = percent
        settingsStore.save(settings)
        scale = CGFloat(settings.scale)
    }

    var currentShowSuggestions: Bool { settings.showSuggestions }

    func applyShowSuggestions(_ on: Bool) {
        settings.showSuggestions = on
        settingsStore.save(settings)
        if !on { hideSuggestions() }
    }

    var currentSavedPhrases: [String] { settings.savedPhrases }

    func applySavedPhrases(_ phrases: [String]) {
        settings.savedPhrases = phrases
        settingsStore.save(settings)
    }

    var currentLauncherWidth: Int { settings.launcherWidth }

    func applyLauncherWidth(_ width: Int) {
        settings.launcherWidth = width
        settingsStore.save(settings)
        (NSApp.delegate as? AppDelegate)?.updateLauncherWidth(settings.launcherWidth)
    }

    var currentLauncherOpacity: Int { settings.launcherOpacityPercent }

    func applyLauncherOpacity(_ percent: Int) {
        settings.launcherOpacityPercent = percent
        settingsStore.save(settings)
        (NSApp.delegate as? AppDelegate)?.updateLauncherOpacity(settings.launcherOpacityPercent)
    }

    var currentTopBarHeight: Int { settings.topBarHeight }

    /// Apply and persist the top-bar height in points (live-resizes the keyboard window).
    func applyTopBarHeight(_ pt: Int) {
        settings.topBarHeight = pt
        settingsStore.save(settings)
        rebuildForBarChange()
    }

    var currentBottomBarShow: Bool { settings.bottomBarShow }

    func applyBottomBarShow(_ show: Bool) {
        settings.bottomBarShow = show
        settingsStore.save(settings)
        rebuildForBarChange()
    }

    var currentBottomBarHeight: Int { settings.bottomBarHeight }

    func applyBottomBarHeight(_ pt: Int) {
        settings.bottomBarHeight = pt
        settingsStore.save(settings)
        rebuildForBarChange()
    }

    /// Resize the window and rebuild the layout after a bar setting changes.
    private func rebuildForBarChange() {
        guard windowConfigured, let window = view.window else { return }
        window.setContentSize(keyboardSize)
        buildKeyboard()
    }

    // MARK: - Saved phrases (list key)

    // MARK: - Scaled layout values (base constants live in AppConfig.Layout)

    private var keyWidth:         CGFloat { AppConfig.Layout.keyWidth    * scale }
    private var keyHeight:        CGFloat { AppConfig.Layout.keyHeight   * scale }
    private var keySpacing:       CGFloat { AppConfig.Layout.keySpacing  * scale }
    private var rowSpacing:       CGFloat { AppConfig.Layout.rowSpacing  * scale }
    private var padding:          CGFloat { AppConfig.Layout.padding     * scale }
    private var keyFontSizePrimary:   CGFloat { AppConfig.Layout.fontSizePrimary   * scale }
    private var keyFontSizeSecondary: CGFloat { AppConfig.Layout.fontSizeSecondary * scale }
    private func keyW(_ key: Key) -> CGFloat {
        key.widthMultiplier == 1.0
            ? keyWidth
            : keyWidth * key.widthMultiplier + keySpacing * (key.widthMultiplier - 1)
    }

    /// Top minimize strip — a fixed height in points (from Settings).
    private var customStatusBarHeight: CGFloat { CGFloat(settings.topBarHeight) }
    /// Bottom drag bar — a fixed height in points, or 0 when hidden.
    private var dragBarHeight: CGFloat { settings.bottomBarShow ? CGFloat(settings.bottomBarHeight) : 0 }

    // MARK: - Keyboard rows

    private let functionRow: [Key] = [
        Key("Escape", title: "Esc", w: 1.5, fontScale: 0.7),
        Key("Hi",     image: "list.bullet"),
        Key("Blank", title: ""),
        Key("Blank", title: ""),
        Key("@",  title: "@", fixed: true),
        Key("!",  title: "!", fixed: true),
        Key("?",  title: "?", fixed: true),
        Key(".",  title: ".", fixed: true),
        Key(",",  title: ",", fixed: true),
        Key("+",  title: "+", fixed: true),
        Key("-",  title: "-", fixed: true),
        Key("=",  title: "=", fixed: true),
        Key("Mute",       image: "volume-off-icon",  fontScale: 0.95, colored: true),
        Key("VolumeDown", image: "volume-down-icon", fontScale: 1.08, colored: true),
        Key("VolumeUp",   image: "volume-up-icon",   fontScale: 0.95, colored: true),
        Key("LangSwitch", title: "🇺🇸", fontScale: 1.5),        // right column
    ]

    private let numberRow: [Key] = [
        Key("`",   title: "~", secondary: "`"),
        Key("1",   secondary: "!"),
        Key("2",   secondary: "@"),
        Key("3",   secondary: "#"),
        Key("4",   secondary: "$"),
        Key("5",   secondary: "%"),
        Key("6",   secondary: "^"),
        Key("7",   secondary: "&"),
        Key("8",   secondary: "*"),
        Key("9",   secondary: "("),
        Key("0",   secondary: ")"),
        Key("-",   secondary: "_"),
        Key("=",   secondary: "+"),
        Key("Backspace", image: "delete.backward", w: 1.5, fontScale: 1.25),
        Key("Home",      title: "Home", fontScale: 0.7),
        Key("Cmd+C",     image: "copy-icon", fontScale: 0.85, colored: true),    // right column
    ]

    private let letterRows: [[Key]] = [
        // QWERTY row
        [Key("Tab",     title: "Tab", w: 1.5, fontScale: 0.7),
         Key("Q", title: "q"), Key("W", title: "w"), Key("E", title: "e"),
         Key("R", title: "r"), Key("T", title: "t"), Key("Y", title: "y"),
         Key("U", title: "u"), Key("I", title: "i"), Key("O", title: "o"),
         Key("P", title: "p"),
         Key("[",        secondary: "{"),
         Key("]",        secondary: "}"),
         Key("\\",       secondary: "|"),
         Key("PageUp",   title: "Up",   fontScale: 0.7),
         Key("Cmd+X",    image: "cut-icon", fontScale: 0.85, colored: true)],   // right column
        // ASDF row
        [Key("CapsLock", title: "Caps", w: 1.75, fontScale: 0.7),
         Key("A", title: "a"), Key("S", title: "s"), Key("D", title: "d"),
         Key("F", title: "f"), Key("G", title: "g"), Key("H", title: "h"),
         Key("J", title: "j"), Key("K", title: "k"), Key("L", title: "l"),
         Key(";", secondary: ":"),
         Key("'", secondary: "\""),
         Key("Return", image: "return", w: 1.75),
         Key("PageDown", title: "Down", fontScale: 0.7),
         Key("Cmd+V",    image: "paste-icon", fontScale: 0.85, colored: true)],  // right column
        // ZXCV row
        [Key("Shift",      image: "shift", w: 2.25),
         Key("Z", title: "z"), Key("X", title: "x"), Key("C", title: "c"),
         Key("V", title: "v"), Key("B", title: "b"), Key("N", title: "n"),
         Key("M", title: "m"),
         Key(",", secondary: "<"),
         Key(".", secondary: ">"),
         Key("/", secondary: "?"),
         Key("Shift",      image: "shift", w: 1.25),
         Key("ArrowUp",    image: "arrow.up"),
         Key("End",        title: "End",  fontScale: 0.7),
         Key("Cmd+Z",      image: "undo-icon", fontScale: 0.85, colored: true)], // right column
        // Bottom row
        [Key("Ctrl",       title: "^",  w: 1.5),
         Key("Alt",        title: "⌥", w: 1.5),
         Key("Cmd",        title: "⌘", w: 1.5),
         Key("Space",      title: "",  w: 5.0),
         Key("Delete",     title: "Del", w: 1.5, fontScale: 0.7),
         Key("HideKeyboard", image: "keyboard-glyph", w: 1.5),
         Key("ArrowLeft",  image: "arrow.left"),
         Key("ArrowDown",  image: "arrow.down"),
         Key("ArrowRight", image: "arrow.right"),
         Key("Translate",  image: "translate-icon", fontScale: 0.85, colored: true)], // right column
    ]

    private var allRows: [[Key]] { [functionRow, numberRow] + letterRows }

    private func rowPixelWidth(_ row: [Key]) -> CGFloat {
        row.reduce(0) { $0 + keyW($1) } + CGFloat(row.count - 1) * keySpacing
    }

    private var keyboardSize: NSSize {
        let contentW = allRows.map { rowPixelWidth($0) }.max() ?? 0
        let w = contentW + padding * 2
        let statusBarH = AppConfig.useCustomTitleBar ? customStatusBarHeight : 0
        let h = CGFloat(allRows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2 + dragBarHeight + statusBarH
        return NSSize(width: w, height: h)
    }

    // MARK: - Shift state

    private var isShifted = false {
        didSet {
            shiftButtons.forEach {
                $0.isActive = isShifted
                if !isShifted { $0.state = .off }
            }
        }
    }
    private var shiftButtons: [KeyButton] = []

    // MARK: - Modifier state (Ctrl / Alt / Cmd — sticky, one-shot like Shift)

    private static let modifierIDs: Set<String> = ["Ctrl", "Alt", "Cmd"]

    /// Function/service keys drawn slightly dimmed; their glyph brightens on hover/press.
    private static let functionKeyIDs: Set<String> = [
        "Escape", "Tab", "CapsLock", "Home", "PageUp", "PageDown", "End", "Delete",
        "Ctrl", "Alt", "Cmd", "Shift",
        "Return", "Backspace", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
        "HideKeyboard",
    ]
    private var activeModifiers: Set<String> = []
    private var modifierButtons: [String: [KeyButton]] = [:]
    private var langSwitchButtons: [KeyButton] = []

    /// Keys whose label follows the active layout, paired with their keycode.
    private var characterButtons: [(button: KeyButton, keyCode: CGKeyCode)] = []
    /// Keycode keys that are NOT character keys (never relabelled).
    private static let nonCharacterKeys: Set<String> = [
        "Space", "Return", "Tab", "Escape",
        "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
        "Home", "End", "PageUp", "PageDown",
    ]

    // MARK: - Word prediction state
    private let suggestionBarSlots = 4
    private var suggestionRowHeight: CGFloat { (keyFontSizePrimary * 1.7).rounded() }
    private let suggestionSpacing: CGFloat = 0
    private var suggestionPanel: NSPanel?
    private var clickMonitors: [Any] = []
    /// The balloon currently shows saved phrases (from the list key) rather than word predictions.
    private var balloonIsGreetings = false
    private var currentSuggestions: [String] = []
    private let textTracker = TextTracker()
    private let speller = SpellCheckerPredictionEngine()

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = AppConfig.Colors.keyboardBg.cgColor
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        settings = settingsStore.load()
        scale = CGFloat(settings.scale)   // windowConfigured still false -> just stores
        windowConfigured = true

        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = AppConfig.Colors.statusBarBg
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Non-activating panel: clicking keys must not steal focus from
        // the app the user is typing into.
        if let panel = window as? NSPanel {
            panel.styleMask.insert(.nonactivatingPanel)
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
        }

        if AppConfig.useCustomTitleBar {
            // Expand content into title bar zone so CustomStatusBar can sit there
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.title = ""
            [NSWindow.ButtonType.closeButton,
             NSWindow.ButtonType.miniaturizeButton,
             NSWindow.ButtonType.zoomButton].forEach {
                window.standardWindowButton($0)?.isHidden = true
            }
        } else {
            window.titlebarAppearsTransparent = true
            window.title = "AllyKeyboard"
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }

        window.setFrameAutosaveName(autosaveName)
        // setContentSize enforces the scale-based size on every launch.
        // Autosave persists position only (size is always derived from scale).
        let size = keyboardSize
        window.setContentSize(size)
        buildKeyboard()
        refreshForCurrentLayout()
        observeInputSourceChanges()
        observeKeyboardMove()
        installClickDismissMonitors()

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.center()
        }
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }
        shiftButtons = []
        modifierButtons = [:]
        activeModifiers = []
        langSwitchButtons = []
        characterButtons = []

        let size       = keyboardSize  // compute once
        let contentW   = size.width - padding * 2
        let symbolSize = keyFontSizePrimary * 0.85

        if settings.bottomBarShow {
            let handle = DragHandle(frame: NSRect(x: 0, y: 0, width: size.width, height: dragBarHeight))
            view.addSubview(handle)
        }

        if AppConfig.useCustomTitleBar {
            let statusBar = CustomStatusBar(frame: NSRect(
                x: 0,
                y: size.height - customStatusBarHeight,
                width: size.width,
                height: customStatusBarHeight
            ))
            view.addSubview(statusBar)
        }

        for (rowIndex, row) in allRows.enumerated() {
            let flippedRow = allRows.count - 1 - rowIndex
            let y = dragBarHeight + padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = rowPixelWidth(row)
            var x = padding + (contentW - rowWidth) / 2

            for key in row {
                let w = keyW(key)
                if key.isSpacer { x += w + keySpacing; continue }   // empty gap, no button
                let btn = KeyButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.identifier = NSUserInterfaceItemIdentifier(key.id)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))

                if let imageName = key.image,
                   let sym = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) {
                    let cfg = NSImage.SymbolConfiguration(pointSize: symbolSize * key.fontScale, weight: .medium)
                    let img = sym.withSymbolConfiguration(cfg)
                    if Self.functionKeyIDs.contains(key.id) {
                        let iv = NSImageView()
                        iv.image = img
                        iv.contentTintColor = .white
                        btn.installGlyph(iv, restAlpha: 0.65)  // dimmed, brightens on hover/press
                    } else {
                        btn.image         = img
                        btn.imagePosition = .imageOnly
                    }
                } else if let imageName = key.image, let asset = NSImage(named: imageName) {
                    asset.isTemplate = !key.colored          // colored assets keep their own colors
                    let h = keyHeight * (key.colored ? 0.55 : 0.4) * key.fontScale
                    let sized = (asset.copy() as! NSImage)
                    sized.isTemplate = !key.colored
                    sized.size = NSSize(width: h * asset.size.width / max(asset.size.height, 1), height: h)
                    if Self.functionKeyIDs.contains(key.id) {
                        let iv = NSImageView()
                        iv.image = sized
                        iv.contentTintColor = .white
                        btn.installGlyph(iv, restAlpha: 0.65)  // dimmed, brightens on hover/press
                    } else {
                        btn.image         = sized
                        btn.imagePosition = .imageOnly
                    }
                } else {
                    // Single letters look heavier than digits at the same weight (more ink),
                    // so give the letter keys a lighter weight to match the number row.
                    let isLetter = key.id.count == 1 && (key.id.first?.isLetter ?? false)
                    let font = NSFont.systemFont(ofSize: keyFontSizePrimary * key.fontScale * 1.1,
                                                 weight: isLetter ? .regular : .medium)
                    if Self.functionKeyIDs.contains(key.id) {
                        let label = NSTextField(labelWithString: key.title)
                        label.font = font
                        label.textColor = .white
                        label.alignment = .center
                        btn.installGlyph(label, restAlpha: 0.65)  // dimmed, brightens on hover/press
                    } else {
                        btn.title = key.title
                        btn.font  = font
                    }
                }

                // Secondary symbol drawn in top-right corner via KeyButton.draw()
                if let secondary = key.secondary {
                    btn.secondaryText     = secondary
                    btn.secondaryFontSize = keyFontSizeSecondary
                    btn.shiftedChar       = secondary
                }

                if key.id == "Shift" {
                    btn.setButtonType(.toggle)
                    if let altImg = NSImage(systemSymbolName: "shift.fill",
                                           accessibilityDescription: nil) {
                        let cfg = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
                        btn.alternateImage = altImg.withSymbolConfiguration(cfg)
                    }
                    shiftButtons.append(btn)
                }

                if Self.modifierIDs.contains(key.id) {
                    modifierButtons[key.id, default: []].append(btn)
                }

                if key.id == "LangSwitch" {
                    langSwitchButtons.append(btn)
                }

                if key.fixed {
                    // Fixed keys always type their own literal and never relabel.
                    btn.literalChar = key.id
                } else if let code = KeySender.keyCode(for: key.id),
                          !Self.nonCharacterKeys.contains(key.id) {
                    characterButtons.append((btn, code))
                }

                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    // MARK: - Context menu

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(DragHandle.appMenu, with: event, for: view)
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else {
            assertionFailure("Key button missing identifier — fix buildKeyboard()")
            return
        }

        if key == "Shift" {
            isShifted = sender.state == .on
            return
        }

        if Self.modifierIDs.contains(key) {
            if activeModifiers.contains(key) { activeModifiers.remove(key) }
            else { activeModifiers.insert(key) }
            updateModifierHighlights()
            return
        }

        if key == "LangSwitch" {
            InputSourceSwitcher.selectNext()
            refreshForCurrentLayout()
            return
        }

        if key == "HideKeyboard" {
            (NSApp.delegate as? AppDelegate)?.hideKeyboard()
            return
        }

        if key == "Blank" { return }   // empty placeholder key — does nothing

        if key == "Hi" {
            showGreetings()
            return
        }

        if key == "Translate" {
            translateSelection()
            return
        }

        // Fixed keys (top-row punctuation) type their literal, independent of layout.
        if activeModifiers.isEmpty, let literal = (sender as? KeyButton)?.literalChar {
            KeySender.sendText(literal)
            if let c = literal.first { textTracker.handle(.character(c)) }
            if isShifted { isShifted = false }
            refreshSuggestions()
            return
        }

        let modifierFlags = eventFlags(from: activeModifiers)
        let wasShifted = isShifted
        KeySender.send(key, shifted: isShifted, modifiers: modifierFlags)
        updateTextTracker(key: key, shifted: wasShifted, hasModifiers: !modifierFlags.isEmpty)

        // One-shot: reset Shift and modifiers after any real keystroke.
        if isShifted { isShifted = false }
        if !activeModifiers.isEmpty {
            activeModifiers.removeAll()
            updateModifierHighlights()
        }
        refreshSuggestions()
    }

    /// Copy the current selection and open it in Google Translate (auto → Russian).
    private func translateSelection() {
        let pb = NSPasteboard.general
        let previousChange = pb.changeCount
        KeySender.send("Cmd+C")   // copy the current selection
        // Give the frontmost app a moment to write the selection to the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard pb.changeCount != previousChange,
                  let text = pb.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://translate.google.com/?sl=auto&tl=ru&op=translate&text=\(encoded)")
            else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private func eventFlags(from mods: Set<String>) -> CGEventFlags {
        var flags: CGEventFlags = []
        if mods.contains("Ctrl") { flags.insert(.maskControl) }
        if mods.contains("Alt")  { flags.insert(.maskAlternate) }
        if mods.contains("Cmd")  { flags.insert(.maskCommand) }
        return flags
    }

    private func updateModifierHighlights() {
        for (id, buttons) in modifierButtons {
            let on = activeModifiers.contains(id)
            buttons.forEach { $0.isActive = on }
        }
    }

    // MARK: - Word prediction

    /// Feed the buffer the actual character produced under the current layout.
    private func updateTextTracker(key: String, shifted: Bool, hasModifiers: Bool) {
        if hasModifiers { textTracker.reset(); return }
        switch key {
        case "Space", "Return", "Tab":
            textTracker.handle(.wordBoundary)
        case "Backspace":
            textTracker.handle(.backspace)
        default:
            if let code = KeySender.keyCode(for: key),
               !Self.nonCharacterKeys.contains(key),
               let ch = InputSourceSwitcher.character(forKeyCode: code, shift: shifted, from: InputSourceSwitcher.currentSource()),
               let c = ch.first {
                textTracker.handle(.character(c))
            } else {
                textTracker.reset()   // navigation / non-text key ends the word
            }
        }
    }

    private func refreshSuggestions() {
        guard settings.showSuggestions, textTracker.hasPartialWord else { hideSuggestions(); return }
        speller.language = InputSourceSwitcher.currentLanguageCode()
        let words = speller.suggestions(for: textTracker.currentWord, limit: suggestionBarSlots)
        showSuggestions(words)
    }

    // MARK: - Suggestion panel (docked outside the keyboard)

    private func ensureSuggestionPanel() -> NSPanel {
        if let panel = suggestionPanel { return panel }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: keyHeight + padding),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        let bar = SuggestionBarView(frame: NSRect(origin: .zero, size: panel.frame.size),
                                    maxSlots: 10, spacing: suggestionSpacing, fontSize: keyFontSizePrimary)
        bar.autoresizingMask = [.width, .height]
        bar.wantsLayer = true
        bar.onSelect = { [weak self] item in self?.balloonSelected(item) }
        panel.contentView = bar
        suggestionPanel = panel
        return panel
    }

    private func showSuggestions(_ words: [String]) {
        showBalloon(words, prefixLength: textTracker.currentWord.count,
                    widthFactor: 0.32, greetings: false)
    }

    /// Show the saved phrases in the same docked balloon (top or bottom, where there's room).
    private func showGreetings() {
        let phrases = settings.savedPhrases
        guard !phrases.isEmpty else { hideSuggestions(); return }
        // prefixLength larger than any phrase => the whole phrase is drawn bright.
        showBalloon(phrases, prefixLength: Int.max, widthFactor: 0.5, greetings: true)
    }

    private func showBalloon(_ items: [String], prefixLength: Int, widthFactor: CGFloat, greetings: Bool) {
        currentSuggestions = items
        balloonIsGreetings = greetings
        guard !items.isEmpty, let keyboard = view.window else { hideSuggestions(); return }
        let panel = ensureSuggestionPanel()
        let n = items.count
        let tailHeight: CGFloat = 7
        let bodyHeight = CGFloat(n) * suggestionRowHeight + CGFloat(n - 1) * suggestionSpacing
        let size = NSSize(width: keyboard.frame.width * widthFactor, height: bodyHeight + tailHeight)
        let tailOnTop = positionSuggestionPanel(panel, relativeTo: keyboard, size: size)
        (panel.contentView as? SuggestionBarView)?.setSuggestions(
            items, prefixLength: prefixLength,
            tailOnTop: tailOnTop, tailHeight: tailHeight,
            cornerRadius: AppConfig.Layout.keyCornerRadius * scale)
        panel.order(.above, relativeTo: keyboard.windowNumber)
    }

    /// Handle a click on a balloon row: insert a phrase as-is, or apply a word prediction.
    private func balloonSelected(_ item: String) {
        if balloonIsGreetings {
            KeySender.sendText(item)
            textTracker.reset()
            hideSuggestions()
        } else {
            applySuggestion(item)
        }
    }

    private func hideSuggestions() {
        currentSuggestions = []
        suggestionPanel?.orderOut(nil)
    }

    /// Dismiss the suggestion balloon when the user clicks away from the keys —
    /// in another app (global) or on the keyboard's own bars/background (local).
    private func installClickDismissMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideSuggestions()
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleLocalClick(event)
            return event
        }
        clickMonitors = [global, local].compactMap { $0 }
    }

    private func handleLocalClick(_ event: NSEvent) {
        guard suggestionPanel?.isVisible == true else { return }
        // Clicking a suggestion selects it — the panel handles that itself.
        if let panel = suggestionPanel, event.window == panel { return }
        // Clicking a key is a normal keystroke (it refreshes suggestions on its own).
        if let window = event.window, window == view.window,
           window.contentView?.hitTest(event.locationInWindow) is KeyButton {
            return
        }
        // Anything else — top/bottom bars, background, another window — dismisses.
        hideSuggestions()
    }

    /// Dock the panel to the keyboard on whichever vertical side has more room.
    /// Docks the balloon to the keyboard; returns true when placed below it
    /// (so the tail should point up).
    @discardableResult
    private func positionSuggestionPanel(_ panel: NSPanel, relativeTo keyboard: NSWindow, size: NSSize) -> Bool {
        let kf = keyboard.frame
        let visible = (keyboard.screen ?? NSScreen.main)?.visibleFrame ?? kf
        let spaceBelow = kf.minY - visible.minY
        let spaceAbove = visible.maxY - kf.maxY
        // Prefer the side that fits the whole balloon; otherwise the roomier side.
        let below: Bool
        if spaceBelow >= size.height { below = true }
        else if spaceAbove >= size.height { below = false }
        else { below = spaceBelow >= spaceAbove }
        // Gap equal to the tail height (padding * 0.7).
        let gap: CGFloat = 2
        var y = below ? (kf.minY - gap - size.height) : (kf.maxY + gap)
        y = max(visible.minY, min(y, visible.maxY - size.height))
        panel.setFrame(NSRect(x: kf.minX + kf.width / 3, y: y, width: size.width, height: size.height), display: true)
        return below
    }

    private func observeKeyboardMove() {
        guard let keyboard = view.window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardMoved),
                                               name: NSWindow.didMoveNotification, object: keyboard)
    }

    @objc private func keyboardMoved() {
        guard let panel = suggestionPanel, panel.isVisible, !currentSuggestions.isEmpty else { return }
        if balloonIsGreetings { showGreetings() } else { showSuggestions(currentSuggestions) }
    }

    /// Replace the partial word with the chosen suggestion, then a space.
    private func applySuggestion(_ word: String) {
        let plan = SuggestionApplier.plan(currentWord: textTracker.currentWord, suggestion: word)
        for _ in 0..<plan.backspaces { KeySender.send("Backspace") }
        KeySender.sendText(plan.textToInsert)
        textTracker.reset()
        hideSuggestions()
    }

    // MARK: - Language switch

    /// Show the flag of the current keyboard layout.
    private func updateLangFlag() {
        let source = InputSourceSwitcher.currentSource()
        for button in langSwitchButtons {
            if let region = InputSourceSwitcher.regionCode(for: source),
               let base = NSImage(named: "flag_\(region)") {
                // Render as a rounded card with a thin border. flagpack flags are a
                // uniform 4:3, so every language keeps the same shape.
                let h = button.bounds.height * 0.5
                let size = NSSize(width: h * 4.0 / 3.0, height: h)
                button.image = Self.roundedCard(base, size: size, cornerRadius: h * 0.2)
                button.imageScaling = .scaleNone
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = InputSourceSwitcher.languageAbbrev(for: source)
            }
        }
    }

    /// Draw a flag image as a rounded card with a subtle border.
    private static func roundedCard(_ base: NSImage, size: NSSize, cornerRadius: CGFloat) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let clip = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGraphicsContext.current?.saveGraphicsState()
        clip.addClip()
        base.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.current?.restoreGraphicsState()
        clip.lineWidth = 1
        NSColor(white: 1, alpha: 0.35).setStroke()
        clip.stroke()
        image.unlockFocus()
        return image
    }

    /// Refresh everything that depends on the active layout: the flag and the
    /// character-key labels.
    private func refreshForCurrentLayout() {
        updateLangFlag()
        relabelForCurrentLayout()
        textTracker.reset()
        hideSuggestions()
    }

    /// Relabel character keys to match the active keyboard layout (language).
    private func relabelForCurrentLayout() {
        let source = InputSourceSwitcher.currentSource()
        for (button, code) in characterButtons {
            guard let base = InputSourceSwitcher.character(forKeyCode: code, shift: false, from: source),
                  !base.isEmpty else { continue }
            button.title = base
            if let shifted = InputSourceSwitcher.character(forKeyCode: code, shift: true, from: source),
               shifted != base, shifted.lowercased() != base.lowercased() {
                button.secondaryText = shifted   // punctuation / digit symbol
            } else {
                button.secondaryText = nil       // letter — no secondary
            }
            button.needsDisplay = true
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        clickMonitors.forEach { NSEvent.removeMonitor($0) }
    }

    private func observeInputSourceChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: InputSourceSwitcher.changeNotification,
            object: nil)
    }

    @objc private func inputSourceChanged() {
        DispatchQueue.main.async { [weak self] in self?.refreshForCurrentLayout() }
    }
}


/// Floating, non-activating panel: clicking keys must never steal focus
/// from the app the user is typing into.
final class KeyboardPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
