// Generates the app icon and the .cbz document icon.
// Run from the repo root:  swift scripts/generate-icons.swift <outDir>
// Masters are 1024x1024 PNGs; downscaling and .icns packing happen in the
// shell wrapper (sips + iconutil).
import AppKit

// MARK: - Palette
let ink = NSColor(srgbRed: 0.13, green: 0.14, blue: 0.18, alpha: 1)          // #212430
let bgTop = NSColor(srgbRed: 0.165, green: 0.18, blue: 0.235, alpha: 1)      // #2A2E3C
let bgBottom = NSColor(srgbRed: 0.085, green: 0.09, blue: 0.13, alpha: 1)    // #161721
let paper = NSColor(srgbRed: 0.965, green: 0.95, blue: 0.92, alpha: 1)       // #F6F2EB
let paperShade = NSColor(srgbRed: 0.87, green: 0.85, blue: 0.81, alpha: 1)
let accent = NSColor(srgbRed: 1.0, green: 0.43, blue: 0.28, alpha: 1)        // #FF6E47

func render(_ size: Int, to path: String, draw: (CGFloat) -> Void) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

func panelGrid(in page: NSRect, gutter: CGFloat, stroke: CGFloat) {
    // Top panel: accent-filled, with a speech bubble. Bottom: two outlined.
    let inner = page.insetBy(dx: gutter, dy: gutter)
    let topH = inner.height * 0.46
    let top = NSRect(x: inner.minX, y: inner.maxY - topH, width: inner.width, height: topH)
    let botH = inner.height - topH - gutter
    let leftW = inner.width * 0.44
    let left = NSRect(x: inner.minX, y: inner.minY, width: leftW, height: botH)
    let right = NSRect(x: inner.minX + leftW + gutter, y: inner.minY,
                       width: inner.width - leftW - gutter, height: botH)

    let r = gutter * 0.35
    accent.setFill()
    NSBezierPath(roundedRect: top, xRadius: r, yRadius: r).fill()

    // Speech bubble in the accent panel
    let bubble = NSRect(x: top.minX + top.width * 0.18, y: top.minY + top.height * 0.30,
                        width: top.width * 0.52, height: top.height * 0.46)
    let bubblePath = NSBezierPath(ovalIn: bubble)
    // Tail anchored inside the ellipse so the union reads as one shape
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: bubble.minX + bubble.width * 0.22, y: bubble.minY + bubble.height * 0.45))
    tail.line(to: NSPoint(x: bubble.minX + bubble.width * 0.10, y: top.minY + top.height * 0.12))
    tail.line(to: NSPoint(x: bubble.minX + bubble.width * 0.48, y: bubble.minY + bubble.height * 0.28))
    tail.close()
    paper.setFill()
    tail.fill()
    bubblePath.fill()

    ink.setStroke()
    for rect in [left, right] {
        let p = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        p.lineWidth = stroke
        p.stroke()
    }
    // Speed lines in the right panel
    let lines = NSBezierPath()
    lines.lineWidth = stroke * 0.6
    for i in 0..<4 {
        let t = CGFloat(i) / 3.0
        let x = right.minX + right.width * (0.25 + 0.5 * t)
        lines.move(to: NSPoint(x: x, y: right.minY + right.height * 0.22))
        lines.line(to: NSPoint(x: x + right.width * 0.10, y: right.minY + right.height * 0.78))
    }
    paperShade.blended(withFraction: 0.4, of: ink)!.setStroke()
    lines.stroke()
    // Solid ink block in the left panel (silhouette panel)
    ink.withAlphaComponent(0.12).setFill()
    NSBezierPath(roundedRect: left.insetBy(dx: stroke * 1.4, dy: stroke * 1.4),
                 xRadius: r * 0.6, yRadius: r * 0.6).fill()
}

func halftone(in rect: NSRect, spacing: CGFloat, radius: CGFloat) {
    NSColor.white.withAlphaComponent(0.05).setFill()
    var y = rect.minY
    var rowToggle = false
    while y < rect.maxY {
        var x = rect.minX + (rowToggle ? spacing / 2 : 0)
        while x < rect.maxX {
            // fade toward the top-left
            let fade = (x - rect.minX) / rect.width
            if fade > 0.35 {
                NSColor.white.withAlphaComponent(0.055 * fade).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: radius * 2, height: radius * 2)).fill()
            }
            x += spacing
        }
        rowToggle.toggle()
        y += spacing
    }
}

// MARK: - App icon
func drawAppIcon(_ s: CGFloat) {
    let unit = s / 1024
    // Apple icon grid: 824pt squircle centered in the 1024 canvas
    let bgRect = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: 186 * unit, yRadius: 186 * unit)
    NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: bg, angle: -90)

    bg.addClip()
    halftone(in: bgRect, spacing: 40 * unit, radius: 7 * unit)

    // Paper page, slightly rotated
    let transform = NSAffineTransform()
    transform.translateX(by: s / 2, yBy: s / 2)
    transform.rotate(byDegrees: -3.5)
    transform.translateX(by: -s / 2, yBy: -s / 2)
    transform.concat()

    let page = NSRect(x: 262 * unit, y: 208 * unit, width: 500 * unit, height: 608 * unit)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    shadow.shadowOffset = NSSize(width: 0, height: -14 * unit)
    shadow.shadowBlurRadius = 36 * unit
    shadow.set()
    paper.setFill()
    NSBezierPath(roundedRect: page, xRadius: 26 * unit, yRadius: 26 * unit).fill()
    NSShadow().set()

    panelGrid(in: page, gutter: 34 * unit, stroke: 9 * unit)
}

// MARK: - Document icon
func drawDocIcon(_ s: CGFloat) {
    let unit = s / 1024
    let page = NSRect(x: 192 * unit, y: 64 * unit, width: 640 * unit, height: 896 * unit)
    let fold = 190 * unit
    let r = 28 * unit

    // Page silhouette with a cut top-right corner
    let path = NSBezierPath()
    path.move(to: NSPoint(x: page.minX + r, y: page.maxY))
    path.line(to: NSPoint(x: page.maxX - fold, y: page.maxY))
    path.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
    path.line(to: NSPoint(x: page.maxX, y: page.minY + r))
    path.appendArc(withCenter: NSPoint(x: page.maxX - r, y: page.minY + r),
                   radius: r, startAngle: 0, endAngle: -90, clockwise: true)
    path.line(to: NSPoint(x: page.minX + r, y: page.minY))
    path.appendArc(withCenter: NSPoint(x: page.minX + r, y: page.minY + r),
                   radius: r, startAngle: -90, endAngle: -180, clockwise: true)
    path.line(to: NSPoint(x: page.minX, y: page.maxY - r))
    path.appendArc(withCenter: NSPoint(x: page.minX + r, y: page.maxY - r),
                   radius: r, startAngle: 180, endAngle: 90, clockwise: true)
    path.close()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -8 * unit)
    shadow.shadowBlurRadius = 22 * unit
    shadow.set()
    paper.setFill()
    path.fill()
    NSShadow().set()
    // Hairline so the page doesn't vanish on light backgrounds
    NSColor(srgbRed: 0.72, green: 0.70, blue: 0.66, alpha: 1).setStroke()
    path.lineWidth = 4 * unit
    path.stroke()

    // Fold triangle
    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: page.maxX - fold, y: page.maxY))
    foldPath.line(to: NSPoint(x: page.maxX - fold, y: page.maxY - fold))
    foldPath.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
    foldPath.close()
    paperShade.setFill()
    foldPath.fill()

    // Panel motif, clear of the fold
    let content = NSRect(x: page.minX + 70 * unit, y: page.minY + 250 * unit,
                         width: page.width - 140 * unit, height: 480 * unit)
    panelGrid(in: content, gutter: 26 * unit, stroke: 8 * unit)

    // "CBZ" tag
    let label = "CBZ" as NSString
    let font = NSFont.systemFont(ofSize: 128 * unit, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
    let textSize = label.size(withAttributes: attrs)
    label.draw(at: NSPoint(x: page.midX - textSize.width / 2, y: page.minY + 80 * unit),
               withAttributes: attrs)
}

// MARK: - Main
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
render(1024, to: "\(outDir)/appicon-1024.png", draw: drawAppIcon)
render(1024, to: "\(outDir)/docicon-1024.png", draw: drawDocIcon)
print("masters written to \(outDir)")
