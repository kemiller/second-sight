#!/usr/bin/swift
// Generates the Second Sight app icon: a wide-awake eye whose iris is a
// clock face, on a dark squircle. Draws at any size from a 1024-pt design.
//
// Usage: swift Scripts/make-icon.swift OUTPUT_DIR
//   Writes AppIcon.iconset/*.png (all required sizes) plus preview.png (512)
//   into OUTPUT_DIR. Then: iconutil -c icns OUTPUT_DIR/AppIcon.iconset

import AppKit

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(pixels) / 1024.0
    let cx = 512 * s
    let cy = 500 * s // eye sits slightly low so the lash rays read as balanced

    // Squircle background: deep night-blue gradient on Apple's icon grid.
    let bg = NSBezierPath(
        roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
        xRadius: 185 * s, yRadius: 185 * s
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.32, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.15, alpha: 1),
    ])!.draw(in: bg, angle: -90)

    // Wide-awake lash rays fanned above the upper lid.
    let rayColor = NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.90, alpha: 0.95)
    rayColor.setStroke()
    for i in -2...2 {
        let angle = CGFloat(90 + i * 24) * .pi / 180 // fan around straight-up
        let inner: CGFloat = 246 * s
        let outer: CGFloat = 306 * s
        let ray = NSBezierPath()
        ray.lineWidth = 18 * s
        ray.lineCapStyle = .round
        ray.move(to: NSPoint(x: cx + inner * cos(angle), y: cy + inner * sin(angle)))
        ray.line(to: NSPoint(x: cx + outer * cos(angle), y: cy + outer * sin(angle)))
        ray.stroke()
    }

    // Eye white: almond shape, opened wide.
    let halfW = 302 * s
    let upper = 205 * s
    let lower = 175 * s
    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: cx - halfW, y: cy))
    eye.curve(
        to: NSPoint(x: cx + halfW, y: cy),
        controlPoint1: NSPoint(x: cx - halfW * 0.42, y: cy + upper * 1.35),
        controlPoint2: NSPoint(x: cx + halfW * 0.42, y: cy + upper * 1.35)
    )
    eye.curve(
        to: NSPoint(x: cx - halfW, y: cy),
        controlPoint1: NSPoint(x: cx + halfW * 0.42, y: cy - lower * 1.35),
        controlPoint2: NSPoint(x: cx - halfW * 0.42, y: cy - lower * 1.35)
    )
    eye.close()
    NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.93, alpha: 1).setFill()
    eye.fill()

    // Everything inside the eye clips to it.
    NSGraphicsContext.saveGraphicsState()
    eye.addClip()

    // Iris: radial teal gradient.
    let irisR = 168 * s
    let irisRect = NSRect(x: cx - irisR, y: cy - irisR, width: irisR * 2, height: irisR * 2)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.88, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.38, blue: 0.62, alpha: 1),
    ])!.draw(in: NSBezierPath(ovalIn: irisRect), relativeCenterPosition: NSPoint(x: -0.15, y: 0.25))

    // Clock tick marks around the iris rim.
    let tickColor = NSColor(calibratedWhite: 1.0, alpha: 0.85)
    tickColor.setStroke()
    for hour in 0..<12 {
        let angle = CGFloat(hour) * .pi / 6
        let isQuarter = hour % 3 == 0
        let outerR = 148 * s
        let innerR = outerR - (isQuarter ? 30 : 16) * s
        let tick = NSBezierPath()
        tick.lineWidth = (isQuarter ? 14 : 8) * s
        tick.lineCapStyle = .round
        tick.move(to: NSPoint(x: cx + innerR * cos(angle), y: cy + innerR * sin(angle)))
        tick.line(to: NSPoint(x: cx + outerR * cos(angle), y: cy + outerR * sin(angle)))
        tick.stroke()
    }

    // Pupil = clock hub.
    let pupilR = 42 * s
    NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - pupilR, y: cy - pupilR, width: pupilR * 2, height: pupilR * 2)).fill()

    // Hands at 10:10 (the classic "alert" watch pose). 12 o'clock = up.
    func hand(clockDegrees: CGFloat, length: CGFloat, width: CGFloat) {
        let angle = (90 - clockDegrees) * .pi / 180
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: cx, y: cy))
        path.line(to: NSPoint(x: cx + length * cos(angle), y: cy + length * sin(angle)))
        path.stroke()
    }
    NSColor(calibratedWhite: 1.0, alpha: 0.95).setStroke()
    hand(clockDegrees: 305, length: 88 * s, width: 24 * s)  // hour hand → ~10
    hand(clockDegrees: 60, length: 122 * s, width: 16 * s)  // minute hand → ~10 past

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed for \(url.lastPathComponent)")
    }
    try! data.write(to: url)
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift Scripts/make-icon.swift OUTPUT_DIR")
    exit(2)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = outDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// (filename, pixel size) pairs required by iconutil.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in variants {
    writePNG(drawIcon(pixels: px), to: iconset.appendingPathComponent(name))
}
writePNG(drawIcon(pixels: 512), to: outDir.appendingPathComponent("preview.png"))
print("Wrote \(iconset.path) and preview.png")
