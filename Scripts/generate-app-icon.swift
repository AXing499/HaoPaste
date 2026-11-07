#!/usr/bin/env swift

//
//  generate-app-icon.swift
//  Renders the 1024pt HaoPaste app icon as a transparent PNG.
//  Run from the repository root:
//
//      swift Scripts/generate-app-icon.swift /path/to/icon_512x512@2x.png
//

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_512x512@2x.png"

let pixelSize = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not allocate the icon bitmap")
}

bitmap.size = NSSize(width: pixelSize, height: pixelSize)

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create a graphics context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let iconRect = NSRect(x: 80, y: 80, width: 864, height: 864)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 200, yRadius: 200)

iconPath.addClip()

let background = NSGradient(colors: [
    NSColor.systemBlue,
    NSColor.systemIndigo
])
background?.draw(in: iconRect, angle: -68)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(
    ovalIn: NSRect(x: 40, y: 480, width: 990, height: 620)
).fill()

NSColor.systemTeal.withAlphaComponent(0.32).setFill()
NSBezierPath(
    ovalIn: NSRect(x: 520, y: 140, width: 560, height: 560)
).fill()

NSColor.white.withAlphaComponent(0.06).setFill()
NSBezierPath(
    roundedRect: NSRect(x: 150, y: 160, width: 400, height: 250),
    xRadius: 48,
    yRadius: 48
).fill()

let symbolConfiguration = NSImage.SymbolConfiguration(
    pointSize: 420,
    weight: .semibold
).applying(
    NSImage.SymbolConfiguration(hierarchicalColor: .white)
)

if let symbol = NSImage(
    systemSymbolName: "doc.on.clipboard.fill",
    accessibilityDescription: "HaoPaste"
)?.withSymbolConfiguration(symbolConfiguration) {
    let symbolSize = symbol.size
    let maxSide: CGFloat = 470
    let scale = min(maxSide / symbolSize.width, maxSide / symbolSize.height)
    let targetRect = NSRect(
        x: 512 - symbolSize.width * scale / 2,
        y: 512 - symbolSize.height * scale / 2,
        width: symbolSize.width * scale,
        height: symbolSize.height * scale
    )
    symbol.draw(in: targetRect)
}

NSColor.white.withAlphaComponent(0.18).setStroke()
let innerBorder = NSBezierPath(
    roundedRect: iconRect.insetBy(dx: 3, dy: 3),
    xRadius: 197,
    yRadius: 197
)
innerBorder.lineWidth = 5
innerBorder.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the icon")
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    print("Wrote \(outputPath)")
} catch {
    fatalError("Could not write \(outputPath): \(error.localizedDescription)")
}
