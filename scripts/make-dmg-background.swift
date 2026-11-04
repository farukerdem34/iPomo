import AppKit
import Foundation

// Renders the DMG window background in the Warm Editorial palette.
// Usage: swift scripts/make-dmg-background.swift <output-directory>

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

let canvas = NSSize(width: 660, height: 440)
let paper = NSColor(hex: 0xF5F0E7)
let terracotta = NSColor(hex: 0xB85C43)
let ink = NSColor(hex: 0x211C17)
let inkSecondary = NSColor(hex: 0x6D6458)

// Finder positions icons from the top of the window; the layout script matches
// these two anchors.
let iconRowFromTop: CGFloat = 210
let wordmarkFromTop: CGFloat = 42
let captionFromTop: CGFloat = 356

func y(_ fromTop: CGFloat) -> CGFloat { canvas.height - fromTop }

func serifFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
    return NSFont(descriptor: descriptor.withDesign(.serif) ?? descriptor, size: size)
        ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func render(scale: CGFloat) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width * scale),
        pixelsHigh: Int(canvas.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create bitmap context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)

    paper.setFill()
    NSRect(origin: .zero, size: canvas).fill()

    // Wordmark: timer mark + serif title, echoing the sidebar.
    let titleFont = serifFont(size: 30, weight: .semibold)
    let title = NSAttributedString(string: "iPomo", attributes: [
        .font: titleFont,
        .foregroundColor: ink,
        .kern: 0.3
    ])
    let titleSize = title.size()
    let markSize: CGFloat = 18
    let markGap: CGFloat = 11
    let groupLeft = (canvas.width - (markSize + markGap + titleSize.width)) / 2
    let groupTop = y(wordmarkFromTop)

    title.draw(at: NSPoint(x: groupLeft + markSize + markGap, y: groupTop - titleSize.height))

    let mark = NSBezierPath()
    mark.appendArc(
        withCenter: NSPoint(x: groupLeft + markSize / 2, y: groupTop - titleSize.height / 2),
        radius: (markSize - 2.5) / 2,
        startAngle: 50,
        endAngle: 130,
        clockwise: true
    )
    mark.lineWidth = 2.5
    mark.lineCapStyle = .round
    terracotta.setStroke()
    mark.stroke()

    // Drag arrow between the two icon slots.
    let arrowY = y(iconRowFromTop)
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 262, y: arrowY))
    arrow.line(to: NSPoint(x: 399, y: arrowY))
    arrow.move(to: NSPoint(x: 390, y: arrowY + 7))
    arrow.line(to: NSPoint(x: 399, y: arrowY))
    arrow.line(to: NSPoint(x: 390, y: arrowY - 7))
    arrow.lineWidth = 1.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    terracotta.withAlphaComponent(0.55).setStroke()
    arrow.stroke()

    // Install hint.
    let caption = NSAttributedString(string: "Drag to Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: inkSecondary,
        .kern: 0.1
    ])
    let captionSize = caption.size()
    caption.draw(at: NSPoint(
        x: (canvas.width - captionSize.width) / 2,
        y: y(captionFromTop) - captionSize.height
    ))

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render background")
    }
    return png
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
for (scale, name) in [(CGFloat(1), "background.png"), (CGFloat(2), "background@2x.png")] {
    let url = outputDirectory.appendingPathComponent(name)
    try render(scale: scale).write(to: url)
    print("Wrote \(url.path)")
}
