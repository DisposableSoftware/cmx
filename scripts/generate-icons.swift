// Generates the app icon and the .cbz document icon at every size.
// Run from the repo root:  swift scripts/generate-icons.swift <outDir>
// (or scripts/generate-icons.sh, which also assembles the appiconset and .icns)
//
// Every size is drawn at its own pixel size rather than downscaled from a
// single master. Downscaling looked fine at 128px and turned to mush at 16px:
// a 9pt panel stroke becomes 0.14px there and disappears, so the two lower
// panels merged into one grey block. Small sizes therefore drop detail and
// separate shapes with gaps of dark background rather than hairline strokes,
// which is the only thing that survives at 16px.
import AppKit

// MARK: - Palette
let ink = NSColor(srgbRed: 0.13, green: 0.14, blue: 0.18, alpha: 1)          // #212430
let bgTop = NSColor(srgbRed: 0.165, green: 0.18, blue: 0.235, alpha: 1)      // #2A2E3C
let bgBottom = NSColor(srgbRed: 0.085, green: 0.09, blue: 0.13, alpha: 1)    // #161721
let paper = NSColor(srgbRed: 0.965, green: 0.95, blue: 0.92, alpha: 1)       // #F6F2EB
let paperShade = NSColor(srgbRed: 0.87, green: 0.85, blue: 0.81, alpha: 1)
let accent = NSColor(srgbRed: 1.0, green: 0.43, blue: 0.28, alpha: 1)        // #FF6E47

/// How much of the artwork survives at a given size.
enum Detail {
    /// 16px: three bands only — no bubble, no strokes, no texture.
    case minimal
    /// 32-64px: bubble and panels, drawn as fills with dark gutters.
    case simplified
    /// 128px+: the full drawing.
    case full

    static func forPixelSize(_ px: Int) -> Detail {
        switch px {
        case ..<24: .minimal
        case ..<128: .simplified
        default: .full
        }
    }

    var isSmall: Bool { self != .full }
}

/// Whole-pixel edges; blurry half-pixel boundaries cost more at 16px than the
/// sub-pixel accuracy is worth.
func snapped(_ rect: NSRect, _ on: Bool) -> NSRect {
    guard on else { return rect }
    return NSRect(x: rect.minX.rounded(), y: rect.minY.rounded(),
                  width: max(1, rect.width.rounded()),
                  height: max(1, rect.height.rounded()))
}

func render(_ size: Int, to path: String, draw: (CGFloat, Detail) -> Void) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(size), Detail.forPixelSize(size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

/// Snap to whole pixels, then re-centre horizontally: rounding a rect that
/// starts on a half-pixel otherwise shunts the motif a pixel or two to one
/// side, which is obvious on a 16px icon.
func centred(_ rect: NSRect, on page: NSRect) -> NSRect {
    var r = snapped(rect, true)
    r.origin.x = (page.midX - r.width / 2).rounded()
    return r
}

// MARK: - Panel motif

/// The comic page itself: an accent panel over two smaller ones.
func panelGrid(in page: NSRect, gutter: CGFloat, stroke: CGFloat, detail: Detail) {
    switch detail {
    case .minimal: minimalPanels(in: page, gutter: gutter)
    case .simplified: simplifiedPanels(in: page, gutter: gutter)
    case .full: fullPanels(in: page, gutter: gutter, stroke: stroke)
    }
}

/// Three bands: accent block, dark gutter, paper block. At 16px the page is
/// about nine pixels wide, so anything more becomes noise.
private func minimalPanels(in page: NSRect, gutter: CGFloat) {
    let inner = centred(page.insetBy(dx: gutter, dy: gutter), on: page)
    let topH = (inner.height * 0.46).rounded()
    accent.setFill()
    NSBezierPath(rect: snapped(
        NSRect(x: inner.minX, y: inner.maxY - topH, width: inner.width, height: topH),
        true)).fill()

    let gap = max(1, (gutter * 0.9).rounded())
    let lowerH = inner.height - topH - gap
    guard lowerH >= 2 else { return }

    // One bordered panel, not two: at 16px the page is about eight pixels
    // wide and a second panel would be a single ambiguous pixel. The border
    // is ink showing through from underneath — a drawn stroke this thin
    // disappears, a filled gap does not.
    let lower = snapped(
        NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: lowerH), true)
    ink.setFill()
    NSBezierPath(rect: lower).fill()

    let border = max(1, (gutter * 0.6).rounded())
    let face = lower.insetBy(dx: border, dy: border)
    guard face.width >= 1, face.height >= 1 else { return }
    paper.setFill()
    NSBezierPath(rect: snapped(face, true)).fill()
}

/// Bubble and panels, but as solid fills with dark gutters — no hairlines,
/// no speed lines, no shading.
private func simplifiedPanels(in page: NSRect, gutter: CGFloat) {
    let inner = centred(page.insetBy(dx: gutter, dy: gutter), on: page)
    let topH = (inner.height * 0.46).rounded()
    let top = snapped(
        NSRect(x: inner.minX, y: inner.maxY - topH, width: inner.width, height: topH), true)
    accent.setFill()
    NSBezierPath(rect: top).fill()

    // A plain ellipse: at 32px a tail is two pixels of mud.
    let bubble = NSRect(x: top.minX + top.width * 0.20, y: top.minY + top.height * 0.26,
                        width: top.width * 0.56, height: top.height * 0.46)
    paper.setFill()
    NSBezierPath(ovalIn: bubble).fill()

    let gap = max(1, (gutter * 0.8).rounded())
    let lowerH = inner.height - topH - gap
    guard lowerH >= 4 else { return }
    let lower = snapped(
        NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: lowerH), true)
    ink.setFill()
    NSBezierPath(rect: lower).fill()

    // Two paper faces inside the ink block, so ink borders every side. A
    // gutter alone is not enough: without a border the panels merge into the
    // page and all that reads is a stray vertical line.
    let border = max(1, (gutter * 0.5).rounded())
    let faceH = lower.height - border * 2
    let usable = lower.width - border * 3   // left edge, middle gutter, right edge
    let leftW = (usable * 0.46).rounded(.down)
    let rightW = usable - leftW
    guard faceH >= 1, leftW >= 1, rightW >= 1 else { return }
    paper.setFill()
    NSBezierPath(rect: NSRect(x: lower.minX + border, y: lower.minY + border,
                              width: leftW, height: faceH)).fill()
    NSBezierPath(rect: NSRect(x: lower.minX + border * 2 + leftW, y: lower.minY + border,
                              width: rightW, height: faceH)).fill()
}

private func fullPanels(in page: NSRect, gutter: CGFloat, stroke: CGFloat) {
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
func drawAppIcon(_ s: CGFloat, _ detail: Detail) {
    let unit = s / 1024
    // Apple icon grid: 824pt squircle centered in the 1024 canvas
    let bgRect = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: 186 * unit, yRadius: 186 * unit)
    NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: bg, angle: -90)

    bg.addClip()
    if detail == .full {
        halftone(in: bgRect, spacing: 40 * unit, radius: 7 * unit)
    }

    // The page is tilted only at full size: a 3.5° rotation on a nine-pixel
    // rectangle is just a ragged edge.
    if detail == .full {
        let transform = NSAffineTransform()
        transform.translateX(by: s / 2, yBy: s / 2)
        transform.rotate(byDegrees: -3.5)
        transform.translateX(by: -s / 2, yBy: -s / 2)
        transform.concat()
    }

    var page = NSRect(x: 262 * unit, y: 208 * unit, width: 500 * unit, height: 608 * unit)
    if detail.isSmall {
        // Reclaim the room the shadow and tilt used, so the page reads bigger.
        page = page.insetBy(dx: -14 * unit, dy: -18 * unit)
        page = snapped(page, true)
    } else {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = NSSize(width: 0, height: -14 * unit)
        shadow.shadowBlurRadius = 36 * unit
        shadow.set()
    }
    paper.setFill()
    let radius = detail == .minimal ? 24 * unit : 26 * unit
    NSBezierPath(roundedRect: page, xRadius: radius, yRadius: radius).fill()
    NSShadow().set()

    panelGrid(in: page, gutter: gutterFor(detail, unit: unit),
              stroke: 9 * unit, detail: detail)
}

/// Small sizes need a proportionally larger gutter, because it has to survive
/// as at least one whole pixel.
func gutterFor(_ detail: Detail, unit: CGFloat) -> CGFloat {
    switch detail {
    case .minimal: max(1, 60 * unit)
    case .simplified: max(2, 48 * unit)
    case .full: 34 * unit
    }
}

// MARK: - Document icon
func drawDocIcon(_ s: CGFloat, _ detail: Detail) {
    let unit = s / 1024
    var page = NSRect(x: 192 * unit, y: 64 * unit, width: 640 * unit, height: 896 * unit)
    if detail.isSmall {
        // Land the edges on half-pixels: a 1px stroke centred on an integer
        // boundary straddles two columns and reads as a soft grey band.
        page = snapped(page, true).insetBy(dx: 0.5, dy: 0.5)
    }
    let fold = detail.isSmall ? (240 * unit).rounded() : 190 * unit
    let r = detail == .minimal ? 0 : 28 * unit

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

    if detail == .full {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -8 * unit)
        shadow.shadowBlurRadius = 22 * unit
        shadow.set()
    }
    paper.setFill()
    path.fill()
    NSShadow().set()
    // Hairline so the page doesn't vanish on light backgrounds. Small sizes
    // need a full pixel of it or it strobes.
    NSColor(srgbRed: 0.72, green: 0.70, blue: 0.66, alpha: 1).setStroke()
    path.lineWidth = detail.isSmall ? max(1, 6 * unit) : 4 * unit
    path.stroke()

    // Fold triangle
    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: page.maxX - fold, y: page.maxY))
    foldPath.line(to: NSPoint(x: page.maxX - fold, y: page.maxY - fold))
    foldPath.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
    foldPath.close()
    paperShade.setFill()
    foldPath.fill()

    // Panel motif, clear of the fold. The CBZ tag only exists at full size —
    // three heavy letters inside eleven pixels are unreadable.
    if detail == .full {
        let content = NSRect(x: page.minX + 70 * unit, y: page.minY + 250 * unit,
                             width: page.width - 140 * unit, height: 480 * unit)
        panelGrid(in: content, gutter: 26 * unit, stroke: 8 * unit, detail: detail)

        let label = "CBZ" as NSString
        let font = NSFont.systemFont(ofSize: 128 * unit, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
        let textSize = label.size(withAttributes: attrs)
        label.draw(at: NSPoint(x: page.midX - textSize.width / 2, y: page.minY + 80 * unit),
                   withAttributes: attrs)
    } else {
        // Centred motif filling the page, since there is no tag to make room
        // for. Taller than it looks it needs to be: at 16px the panel below
        // the accent band only survives if it starts with ~4px to spend.
        let content = NSRect(x: page.minX + 60 * unit, y: page.minY + 90 * unit,
                             width: page.width - 120 * unit, height: 720 * unit)
        panelGrid(in: content, gutter: gutterFor(detail, unit: unit),
                  stroke: 8 * unit, detail: detail)
    }
}

// MARK: - Main
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for px in sizes {
    render(px, to: "\(outDir)/app-\(px).png", draw: drawAppIcon)
    render(px, to: "\(outDir)/doc-\(px).png", draw: drawDocIcon)
}
print("rendered \(sizes.count) sizes each for app and document icons in \(outDir)")
