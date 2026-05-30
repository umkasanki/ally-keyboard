//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

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

    private let keyWidth:    CGFloat = 46
    private let keyHeight:   CGFloat = 36
    private let keySpacing:  CGFloat = 4
    private let rowSpacing:  CGFloat = 4
    private let padding:     CGFloat = 12
    private let keyFontSize: CGFloat = 14

    private var spaceKeyWidth: CGFloat { keyWidth * 3 + keySpacing * 2 }

    private lazy var keyboardSize: NSSize = {
        let maxKeys = rows[0].count
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

    private var isShifted = false
    private weak var shiftButton: KeyButton?

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.13, alpha: 1).cgColor
        buildKeyboard()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.title = "AllyKeyboard"
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(white: 0.22, alpha: 1)
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
            shiftButton?.isActive = isShifted
            return
        }

        KeySender.send(key, shifted: isShifted)

        // One-shot shift: reset after typing any key
        if isShifted {
            isShifted = false
            shiftButton?.isActive = false
            shiftButton?.state = .off
        }
    }
}
