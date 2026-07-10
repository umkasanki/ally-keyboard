import AppKit

// Renders the AllyKeyboard app icon (red squircle + white keyboard glyph with
// cut-out keys, subtle gradient + soft shadow) to a 1024×1024 PNG. Same house
// style as AllyClicker (see the macos-app-icon skill). Run:
//   swiftc make-icon.swift -o make-icon && ./make-icon icon_1024.png

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
let space = CGColorSpace(name: CGColorSpace.sRGB)!

let inset: CGFloat = 96, body: CGFloat = CGFloat(size) - inset * 2
cg.translateBy(x: inset, y: CGFloat(size) - inset)
cg.scaleBy(x: body / 200, y: -body / 200)

// Red squircle tile + top sheen.
let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 200), cornerWidth: 46, cornerHeight: 46, transform: nil)
cg.saveGState(); cg.addPath(tile); cg.clip()
cg.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgb(0.984, 0.443, 0.522), rgb(0.745, 0.071, 0.235)] as CFArray, locations: [0, 1])!,
                      start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 200), options: [])
cg.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1, 0.38), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!,
                      start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 100), options: [])
cg.restoreGState()

func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

// Keyboard glyph: body + 3×6 keys + spacebar, keys punched out (even-odd).
let glyph = CGMutablePath()
glyph.addPath(rr(40, 66, 120, 68, 14))
let keyW: CGFloat = 12, keyH: CGFloat = 10, gapX: CGFloat = 5, gapY: CGFloat = 4, startX: CGFloat = 50
for row in 0..<3 {
    let y = 78 + CGFloat(row) * (keyH + gapY)
    for col in 0..<6 { glyph.addPath(rr(startX + CGFloat(col) * (keyW + gapX), y, keyW, keyH, 3)) }
}
glyph.addPath(rr(70, 120, 60, 8, 4))

// Squeeze horizontally (~12% narrower), keep height.
cg.saveGState()
cg.translateBy(x: 100, y: 100); cg.scaleBy(x: 1.074, y: 1.22); cg.translateBy(x: -100, y: -100)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 5), blur: 7, color: rgb(0.4, 0.03, 0.13, 0.35))
cg.addPath(glyph); cg.setFillColor(rgb(1, 1, 1)); cg.fillPath(using: .evenOdd)
cg.restoreGState()

cg.saveGState()
cg.addPath(glyph); cg.clip(using: .evenOdd)
cg.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1), rgb(0.965, 0.878, 0.898)] as CFArray, locations: [0, 1])!,
                      start: CGPoint(x: 100, y: 60), end: CGPoint(x: 100, y: 140), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
cg.restoreGState()

cg.restoreGState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
