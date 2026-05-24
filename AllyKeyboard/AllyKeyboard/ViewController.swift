//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

class ViewController: NSViewController {

    // MARK: - Layout constants
    private let keyWidth: CGFloat   = 46
    private let keyHeight: CGFloat  = 36
    private let keySpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 4
    private let padding: CGFloat    = 12

    // MARK: - Key definitions (displayTitle, keyIdentifier)
    private let rows: [[(String, String)]] = [
        [("Q","Q"),("W","W"),("E","E"),("R","R"),("T","T"),
         ("Y","Y"),("U","U"),("I","I"),("O","O"),("P","P")],
        [("A","A"),("S","S"),("D","D"),("F","F"),("G","G"),
         ("H","H"),("J","J"),("K","K"),("L","L")],
        [("Z","Z"),("X","X"),("C","C"),("V","V"),
         ("B","B"),("N","N"),("M","M")],
        [("","Space"),("⌫","Backspace"),("↩","Return")]
    ]

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        configureWindow()
    }

    // MARK: - Window setup

    private func configureWindow() {
        guard let window = view.window else { return }
        let size = keyboardSize()
        window.setContentSize(size)
        view.setFrameSize(size)
        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        if UserDefaults.standard.string(forKey: "windowOrigin") == nil {
            window.center()
        }
    }

    // MARK: - Keyboard layout

    private func keyboardSize() -> NSSize {
        let maxKeys = rows[0].count
        let width  = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let height = CGFloat(rows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2
        return NSSize(width: width, height: height)
    }

    private func buildKeyboard() {
        let size = keyboardSize()
        view.setFrameSize(size)
        let totalWidth = CGFloat(rows[0].count) * (keyWidth + keySpacing) - keySpacing

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)
            let rowWidth = row.reduce(0) { $0 + keyWidthFor($1.1) } + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for (title, key) in row {
                let w = keyWidthFor(key)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title = title
                btn.bezelStyle = .rounded
                btn.font = NSFont.systemFont(ofSize: 14)
                btn.identifier = NSUserInterfaceItemIdentifier(key)
                btn.target = self
                btn.action = #selector(keyPressed(_:))
                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    private func keyWidthFor(_ key: String) -> CGFloat {
        key == "Space" ? keyWidth * 3 + keySpacing * 2 : keyWidth
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        let key = sender.identifier?.rawValue ?? sender.title
        print("Key pressed: \(key)")
    }
}
