//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

// MARK: - Theme

enum Theme {
    static let panelBg     = NSColor(white: 0.22, alpha: 1)  // title bar, drag handle
    static let keyboardBg  = NSColor(white: 0.13, alpha: 1)  // keyboard area background
    static let keyNormal   = NSColor(white: 0.22, alpha: 1)  // key default state
    static let keyHover    = NSColor(white: 0.36, alpha: 1)  // key hover state
    static let keyPressed  = NSColor(red: 0.72, green: 0.13, blue: 0.13, alpha: 1) // key press
    static let keyActive   = NSColor(red: 0.20, green: 0.45, blue: 0.80, alpha: 1) // shift on
    static let tempBg      = NSColor.red                     // temporary, for visual testing
}

// MARK: - KeyButton

/// Custom keyboard key with dark styling, hover highlight, and red press feedback.
final class KeyButton: NSButton {


    private var isHovered = false

    var isActive = false { didSet { updateBackground() } }

    override init(frame: NSRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        isBordered = false
        font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contentTintColor = .white
        updateBackground()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  updateBackground() }
    override func mouseExited (with event: NSEvent) { isHovered = false; updateBackground() }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        layer?.backgroundColor = flag ? Theme.keyPressed.cgColor : nil
        if !flag { updateBackground() }
    }

    private func updateBackground() {
        layer?.backgroundColor = (isActive ? Theme.keyActive : isHovered ? Theme.keyHover : Theme.keyNormal).cgColor
    }
}

// MARK: - ViewController

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:    String   // used for key simulation (CGEvent)
        let title: String   // displayed on the button face
        init(_ id: String, title: String? = nil) {
            self.id    = id
            self.title = title ?? id
        }
    }


    // MARK: - Layout constants

    private let keyWidth:    CGFloat = 92
    private let keyHeight:   CGFloat = 72
    private let keySpacing:  CGFloat = 8
    private let rowSpacing:  CGFloat = 8
    private let padding:     CGFloat = 24
    private let keyFontSize: CGFloat = 28

    private var spaceKeyWidth: CGFloat { keyWidth * 3 + keySpacing * 2 }

    private lazy var keyboardSize: NSSize = {
        let maxKeys = rows.map { $0.count }.max() ?? 0
        let w = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let h = CGFloat(rows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2
        return NSSize(width: w, height: h)
    }()

    private let rows: [[Key]] = [
        [Key("Q"), Key("W"), Key("E"), Key("R"), Key("T"),
         Key("Y"), Key("U"), Key("I"), Key("O"), Key("P")],
        [Key("A"), Key("S"), Key("D"), Key("F"), Key("G"),
         Key("H"), Key("J"), Key("K"), Key("L")],
        [Key("Shift", title: "⇧"), Key("Z"), Key("X"), Key("C"), Key("V"),
         Key("B"), Key("N"), Key("M")],
        [Key("Space", title: ""), Key("Backspace", title: "⌫"), Key("Return", title: "↩")]
    ]

    // MARK: - Shift state

    private var isShifted = false {
        didSet {
            shiftButton?.isActive = isShifted
            if !isShifted { shiftButton?.state = .off }
        }
    }
    private weak var shiftButton: KeyButton?

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.keyboardBg.cgColor
        buildKeyboard()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.title = "AllyKeyboard"
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.panelBg
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        window.setFrameAutosaveName(autosaveName)
        window.setContentSize(keyboardSize)

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.center()
        }
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }
        shiftButton = nil

        let totalWidth = keyboardSize.width - padding * 2

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = row.reduce(0) { $0 + width(for: $1) }
                         + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for key in row {
                let w   = width(for: key)
                let btn = KeyButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title      = key.title
                btn.font       = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
                btn.identifier = NSUserInterfaceItemIdentifier(key.id)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))

                if key.id == "Shift" {
                    btn.setButtonType(.toggle)
                    btn.alternateTitle = "⇪"
                    shiftButton = btn
                }

                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    private func width(for key: Key) -> CGFloat {
        key.id == "Space" ? spaceKeyWidth : keyWidth
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

        KeySender.send(key, shifted: isShifted)

        // One-shot shift: reset after typing any key
        if isShifted { isShifted = false }

    }
}
