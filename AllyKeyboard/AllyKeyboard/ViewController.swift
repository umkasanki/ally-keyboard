//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:    String   // used for key simulation (CGEvent in Phase 2)
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
        [Key("Z"), Key("X"), Key("C"), Key("V"),
         Key("B"), Key("N"), Key("M")],
        [Key("Space", title: ""), Key("Backspace", title: "⌫"), Key("Return", title: "↩")]
    ]

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        window.setFrameAutosaveName(autosaveName)
        // Enforce correct size even if a stale frame was saved from a previous build.
        window.setContentSize(keyboardSize)

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.center()
        }
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let totalWidth = keyboardSize.width - padding * 2

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = row.reduce(0) { $0 + width(for: $1) }
                         + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for key in row {
                let w   = width(for: key)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title      = key.title
                btn.bezelStyle = .rounded
                btn.font       = NSFont.systemFont(ofSize: keyFontSize)
                btn.identifier = NSUserInterfaceItemIdentifier(key.id)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))
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
        print("Key pressed: \(key)")
    }
}
