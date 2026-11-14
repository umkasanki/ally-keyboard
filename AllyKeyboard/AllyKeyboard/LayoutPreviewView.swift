//
//  LayoutPreviewView.swift
//  AllyKeyboard
//
//  The layout editor's picture of a layout: the keys laid out and labelled
//  as the keyboard does it (`ViewController.buildKeyboard`) — the layout's own
//  key sizes, gaps and padding, short rows centred, the same label sizes and
//  weights, symbols white — scaled to fit the room given; each key a click
//  target. A click selects a key; the selected one is outlined. When rows
//  differ in width, each row's width stands at its right, red where it falls
//  short; when they are even, nothing. Not drawn: the keyboard's dimming and
//  its top and bottom bars.
//

import AppKit
import AllyKeyboardCore

final class LayoutPreviewView: NSView {

    var layout = KeyboardLayout.standard { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var selection: KeyPosition? { didSet { needsDisplay = true } }
    /// Called with the key clicked, or nil for a click between keys.
    var onClick: ((KeyPosition?) -> Void)?
    /// The room the picture may take; it is scaled down to fit, and up to
    /// `largest` for a small keyboard.
    var maximumSize = NSSize(width: 820, height: 330) { didSet { invalidateIntrinsicContentSize() } }
    private let largest: CGFloat = 1.6

    private let widthColumn: CGFloat = 54

    override var isFlipped: Bool { true }

    private var rowsAreUneven: Bool { layout.rowsAreUneven }

    /// The keyboard at 100%, in points — the same arithmetic as the keyboard's
    /// own `keyboardSize`.
    private var naturalSize: NSSize {
        let g = layout.geometry
        let widest = layout.rowWidths.max() ?? 0
        let w = CGFloat(widest) * (g.keyWidth + g.keySpacing) - g.keySpacing + 2 * g.padding
        let n = Double(max(layout.rows.count, 1))
        let h = n * (g.keyHeight + g.rowSpacing) - g.rowSpacing + 2 * g.padding
        return NSSize(width: max(w, 60), height: max(h, 40))
    }

    private var scale: CGFloat {
        let room = NSSize(width: maximumSize.width - widthColumn, height: maximumSize.height)
        let natural = naturalSize
        return min(largest, room.width / natural.width, room.height / natural.height)
    }

    override var intrinsicContentSize: NSSize {
        let natural = naturalSize, s = scale
        return NSSize(width: natural.width * s + (rowsAreUneven ? widthColumn : 0), height: natural.height * s)
    }

    /// Where each key is drawn — the keyboard's `keyW`: a key n units wide
    /// also spans the n-1 gaps it covers; a short row is centred.
    private func frames() -> [[NSRect]] {
        let g = layout.geometry, s = scale
        let unit = CGFloat(g.keyWidth + g.keySpacing) * s, gap = CGFloat(g.keySpacing) * s
        let height = CGFloat(g.keyHeight) * s, rowStep = CGFloat(g.keyHeight + g.rowSpacing) * s
        let pad = CGFloat(g.padding) * s
        let widths = layout.rowWidths, widest = widths.max() ?? 0
        return layout.rows.enumerated().map { r, row in
            var x = pad + CGFloat(widest - widths[r]) * unit / 2
            let y = pad + CGFloat(r) * rowStep
            return row.map { key in
                let w = CGFloat(key.width) * unit - gap
                defer { x += CGFloat(key.width) * unit }
                return NSRect(x: x, y: y, width: max(w, 4), height: height)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        AppConfig.Colors.keyboardBg.setFill()
        let picture = NSRect(origin: .zero, size: NSSize(width: naturalSize.width * scale, height: naturalSize.height * scale))
        NSBezierPath(roundedRect: picture, xRadius: 10, yRadius: 10).fill()

        let widths = layout.rowWidths
        let widest = widths.max() ?? 0
        let uneven = rowsAreUneven
        for (r, rowFrames) in frames().enumerated() {
            for (i, frame) in rowFrames.enumerated() {
                drawKey(layout.rows[r][i], in: frame, selected: selection == KeyPosition(row: r, index: i))
            }
            guard uneven, let first = rowFrames.first else { continue }
            // The row's width, red when it falls short of the widest.
            let label = Self.units(widths[r])
            let color: NSColor = abs(widths[r] - widest) < 1e-6 ? .secondaryLabelColor : .systemRed
            (label as NSString).draw(at: NSPoint(x: picture.maxX + 10, y: first.midY - 9),
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

    /// A width in key widths, as people write it: 16, 16.5, 16.25.
    static func units(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    /// The keyboard's label arithmetic, against the key's height: its primary
    /// font is 15 pt on a 32 pt key, its corner font 9.6 pt.
    private func drawFace(of key: KeySpec, in frame: NSRect) {
        let primary = frame.height * AppConfig.Layout.fontSizePrimary / 32
        let fontScale = CGFloat(key.fontScale)
        if let name = key.icon, let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            // A symbol, always white, as on the keyboard.
            let config = NSImage.SymbolConfiguration(pointSize: primary * 0.85 * fontScale, weight: .regular)
                .applying(.init(paletteColors: [.white]))
            if let image = symbol.withSymbolConfiguration(config) { draw(image, centredIn: frame) }
        } else if let name = key.icon, let asset = NSImage(named: name) {
            // A bundled image: white unless it keeps its colours.
            let h = frame.height * (key.colored ? 0.55 : 0.4) * fontScale
            let size = NSSize(width: h * asset.size.width / max(asset.size.height, 1), height: h)
            draw(key.colored ? asset : tinted(asset, size: size), centredIn: frame, size: size)
        } else {
            let id = key.action.legacyID
            let isLetterOrDigit = id.count == 1 && (id.first?.isLetter ?? false || id.first?.isNumber ?? false)
            let weight: NSFont.Weight = key.title.count > 1 ? .thin : (isLetterOrDigit ? .light : .regular)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: primary * fontScale * 1.1, weight: weight),
                .foregroundColor: NSColor.white]
            let size = (key.title as NSString).size(withAttributes: attrs)
            (key.title as NSString).draw(at: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2),
                                         withAttributes: attrs)
        }
        if let secondary = key.secondary {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: frame.height * AppConfig.Layout.fontSizeSecondary / 32, weight: .light),
                .foregroundColor: NSColor(white: 1, alpha: 0.75)]
            let size = (secondary as NSString).size(withAttributes: attrs)
            (secondary as NSString).draw(at: NSPoint(x: frame.maxX - size.width - 3, y: frame.minY + 3), withAttributes: attrs)
        }
    }

    private func draw(_ image: NSImage, centredIn frame: NSRect, size: NSSize? = nil) {
        let size = size ?? image.size
        image.draw(in: NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                              width: size.width, height: size.height),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    /// The image in white, drawn at the size it is shown at — not a small
    /// bitmap scaled up.
    private func tinted(_ image: NSImage, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (r, rowFrames) in frames().enumerated() {
            if let i = rowFrames.firstIndex(where: { $0.insetBy(dx: -2, dy: -2).contains(point) }) {
                onClick?(KeyPosition(row: r, index: i))
                return
            }
        }
        onClick?(nil)
    }
}
