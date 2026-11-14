//
//  LayoutPreviewView.swift
//  AllyKeyboard
//
//  The layout editor's picture of a layout: the keys drawn as the keyboard
//  draws them, larger, each one a click target. A click selects a key; the
//  selected one is outlined. Each row's width stands at its right, marked
//  when it differs from the widest, so rows can be evened up.
//

import AppKit
import AllyKeyboardCore

final class LayoutPreviewView: NSView {

    var layout = KeyboardLayout.standard { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var selection: KeyPosition? { didSet { needsDisplay = true } }
    /// Called with the key clicked, or nil for a click between keys.
    var onClick: ((KeyPosition?) -> Void)?

    /// One standard key, in points: large enough to aim at with a head mouse.
    private let unit: CGFloat = 46
    private let gap: CGFloat = 5
    private let padding: CGFloat = 12
    private let widthColumn: CGFloat = 54

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        let widest = layout.rows.map(rowWidth).max() ?? 0
        let w = padding * 2 + CGFloat(widest) * unit + widthColumn
        let h = padding * 2 + CGFloat(max(layout.rows.count, 1)) * (unit + gap) - gap
        return NSSize(width: w, height: h)
    }

    private func rowWidth(_ row: [KeySpec]) -> Double { row.reduce(0) { $0 + $1.width } }

    /// Where each key is drawn — the same arithmetic as the keyboard's `keyW`:
    /// a key n units wide also spans the n-1 gaps it covers.
    private func frames() -> [[NSRect]] {
        layout.rows.enumerated().map { r, row in
            var x = padding
            let y = padding + CGFloat(r) * (unit + gap)
            return row.map { key in
                let w = CGFloat(key.width) * unit - gap
                defer { x += CGFloat(key.width) * unit }
                return NSRect(x: x, y: y, width: max(w, 4), height: unit)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        AppConfig.Colors.keyboardBg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()

        let widths = layout.rows.map(rowWidth)
        let widest = widths.max() ?? 0
        for (r, rowFrames) in frames().enumerated() {
            for (i, frame) in rowFrames.enumerated() {
                drawKey(layout.rows[r][i], in: frame, selected: selection == KeyPosition(row: r, index: i))
            }
            // The row's width, red when it falls short of the widest.
            let label = widths[r].truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(widths[r])) : String(widths[r])
            let color: NSColor = widths[r] == widest ? .secondaryLabelColor : .systemRed
            let y = padding + CGFloat(r) * (unit + gap) + unit / 2 - 9
            (label as NSString).draw(at: NSPoint(x: bounds.width - widthColumn + 10, y: y),
                                     withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: color])
        }
    }

    private func drawKey(_ key: KeySpec, in frame: NSRect, selected: Bool) {
        let path = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        if key.action == .spacer {
            // A gap draws nothing on the keyboard; here it gets a faint dashed
            // outline, or it could not be found to select.
            NSColor(white: 1, alpha: 0.25).setStroke()
            path.setLineDash([4, 4], count: 2, phase: 0)
            path.lineWidth = 1
            path.stroke()
        } else {
            AppConfig.Colors.keyNormal.setFill()
            path.fill()
            drawFace(of: key, in: frame)
        }
        if selected {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: frame.insetBy(dx: -2, dy: -2), xRadius: 8, yRadius: 8)
            ring.lineWidth = 3
            ring.stroke()
        }
    }

    private func drawFace(of key: KeySpec, in frame: NSRect) {
        if let name = key.icon, let image = icon(named: name, colored: key.colored) {
            let side = min(frame.height * 0.5 * CGFloat(key.fontScale), frame.width - 8)
            let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
            let size = NSSize(width: side * aspect, height: side)
            image.draw(in: NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                  width: size.width, height: size.height),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            let title = key.action == .blank && key.label == nil ? "" : key.title
            // One base size for every label, scaled by the key's own font scale,
            // as the keyboard does — words (Esc, Home) already carry a smaller
            // scale, and a second reduction here left them too small to read.
            let font = NSFont.systemFont(ofSize: unit * 0.42 * CGFloat(key.fontScale),
                                         weight: title.count > 1 ? .regular : .light)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            let size = (title as NSString).size(withAttributes: attrs)
            (title as NSString).draw(at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2),
                                     withAttributes: attrs)
        }
        if let secondary = key.secondary {
            (secondary as NSString).draw(at: NSPoint(x: frame.maxX - 13, y: frame.minY + 3), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(white: 1, alpha: 0.7)])
        }
    }

    /// A bundled image or an SF Symbol, tinted white unless it keeps its colours.
    private func icon(named name: String, colored: Bool) -> NSImage? {
        guard let base = NSImage(named: name) ?? NSImage(systemSymbolName: name, accessibilityDescription: nil)
        else { return nil }
        guard !colored, let tinted = base.copy() as? NSImage else { return base }
        tinted.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (r, rowFrames) in frames().enumerated() {
            if let i = rowFrames.firstIndex(where: { $0.insetBy(dx: -gap / 2, dy: -gap / 2).contains(point) }) {
                onClick?(KeyPosition(row: r, index: i))
                return
            }
        }
        onClick?(nil)
    }
}
