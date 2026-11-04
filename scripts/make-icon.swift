import AppKit
import Foundation

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let paper = NSColor(hex: 0xF3ECE1)
let terracotta = NSColor(hex: 0xB85C43)
let ink = NSColor(hex: 0x211C17)
let hairline = NSColor(hex: 0xD8CEBF)
let inkTertiary = NSColor(hex: 0x9B8F7F)
let sage = NSColor(hex: 0x6E7F5E)

// Warm paper tile
let tileRect = NSRect(x: 40, y: 40, width: 944, height: 944)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 212, yRadius: 212)
paper.setFill()
tile.fill()
ink.withAlphaComponent(0.08).setStroke()
tile.lineWidth = 3
tile.stroke()

// Timer ring
let center = NSPoint(x: 512, y: 505)
let ringRadius: CGFloat = 248
let ring = NSBezierPath(ovalIn: NSRect(
    x: center.x - ringRadius,
    y: center.y - ringRadius,
    width: ringRadius * 2,
    height: ringRadius * 2
))
ring.lineWidth = 46
terracotta.setStroke()
ring.stroke()

// Tick marks
for index in 0..<12 {
    let angle = CGFloat(index) * .pi / 6
    let outer = NSPoint(
        x: center.x + cos(angle) * (ringRadius + 54),
        y: center.y + sin(angle) * (ringRadius + 54)
    )
    let inner = NSPoint(
        x: center.x + cos(angle) * (ringRadius + 30),
        y: center.y + sin(angle) * (ringRadius + 30)
    )
    let tick = NSBezierPath()
    tick.move(to: inner)
    tick.line(to: outer)
    tick.lineWidth = index % 3 == 0 ? 12 : 6
    (index % 3 == 0 ? inkTertiary : hairline).setStroke()
    tick.stroke()
}

// Hand and hub
let hand = NSBezierPath()
hand.move(to: center)
hand.line(to: NSPoint(x: center.x + 8, y: center.y + 146))
hand.lineWidth = 30
hand.lineCapStyle = .round
ink.setStroke()
hand.stroke()

let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48))
ink.setFill()
hub.fill()

// Stem and leaves
let stem = NSBezierPath(roundedRect: NSRect(x: 494, y: 742, width: 36, height: 98), xRadius: 16, yRadius: 16)
sage.setFill()
stem.fill()

func leaf(center: NSPoint, rotation: CGFloat) {
    let leafPath = NSBezierPath(ovalIn: NSRect(x: -74, y: -30, width: 148, height: 60))
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    leafPath.transform(using: transform as AffineTransform)
    sage.setFill()
    leafPath.fill()
}

leaf(center: NSPoint(x: 442, y: 826), rotation: 28)
leaf(center: NSPoint(x: 582, y: 826), rotation: -28)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png")
try png.write(to: output)
print("Wrote \(output.path)")
