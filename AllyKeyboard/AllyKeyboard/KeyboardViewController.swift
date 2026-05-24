//
//  KeyboardViewController.swift
//  AllyKeyboard
//

import Cocoa

class KeyboardViewController: NSViewController {

    // MARK: - Layout constants

    private let keyWidth: CGFloat   = 46
    private let keyHeight: CGFloat  = 36
    private let keySpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 4
    private let padding: CGFloat    = 10

    // MARK: - Key definitions
    // Each key: (displayTitle, keyIdentifier)

    private let rows: [[(title: String, key: String)]] = [
        [("Q","Q"),("W","W"),("E","E"),("R","R"),("T","T"),
         ("Y","Y"),("U","U"),("I","I"),("O","O"),("P","P")],
        [("A","A"),("S","S"),("D","D"),("F","F"),("G","G"),
         ("H","H"),("J","J"),("K","K"),("L","L")],
        [("Z","Z"),("X","X"),("C","C"),("V","V"),
         ("B","B"),("N","N"),("M","M")],
        [("","Space"),("⌫","Backspace"),("↩","Return")]
    ]

    // MARK: - View

    override func loadView() {
        let maxKeys = rows[0].count
        let width  = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let height = CGFloat(rows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2

        view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
    }

    // MARK: - Build layout

    private func buildKeyboard() {
        let totalRows  = rows.count
        let totalWidth = CGFloat(rows[0].count) * (keyWidth + keySpacing) - keySpacing

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = totalRows - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = rowContentWidth(for: row)
            let offsetX  = padding + (totalWidth - rowWidth) / 2

            var x = offsetX
            for keyDef in row {
                let w = keyWidth(for: keyDef.key)
                let button = makeKeyButton(keyDef, frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                view.addSubview(button)
                x += w + keySpacing
            }
        }
    }

    private func rowContentWidth(for row: [(title: String, key: String)]) -> CGFloat {
        let widths = row.map { keyWidth(for: $0.key) }
        return widths.reduce(0, +) + CGFloat(row.count - 1) * keySpacing
    }

    private func keyWidth(for key: String) -> CGFloat {
        switch key {
        case "Space": return keyWidth * 3 + keySpacing * 2
        default:      return keyWidth
        }
    }

    private func makeKeyButton(_ keyDef: (title: String, key: String), frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = keyDef.title
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        button.identifier = NSUserInterfaceItemIdentifier(keyDef.key)
        button.target = self
        button.action = #selector(keyPressed(_:))
        return button
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        let key = sender.identifier?.rawValue ?? sender.title
        print("Key pressed: \(key)")
        // Phase 2: KeySender.send(key)
    }
}
