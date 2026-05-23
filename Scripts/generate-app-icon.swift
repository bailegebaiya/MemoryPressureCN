#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("Packaging/AppIcon.iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSpecs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in iconSpecs {
    let image = drawIcon(pixels: spec.pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(spec.name))
}

func drawIcon(pixels: Int) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    NSColor.clear.setFill()
    bounds.fill()

    let scale = CGFloat(pixels) / 1024
    let outer = bounds.insetBy(dx: 70 * scale, dy: 70 * scale)
    let outerPath = NSBezierPath(roundedRect: outer, xRadius: 220 * scale, yRadius: 220 * scale)
    NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.12, alpha: 1).setFill()
    outerPath.fill()

    let ring = outer.insetBy(dx: 54 * scale, dy: 54 * scale)
    let ringPath = NSBezierPath(roundedRect: ring, xRadius: 170 * scale, yRadius: 170 * scale)
    NSColor.systemGreen.withAlphaComponent(0.22).setFill()
    ringPath.fill()
    NSColor.systemGreen.withAlphaComponent(0.82).setStroke()
    ringPath.lineWidth = max(10 * scale, 1)
    ringPath.stroke()

    let chip = NSRect(x: 270 * scale, y: 315 * scale, width: 484 * scale, height: 394 * scale)
    let chipPath = NSBezierPath(roundedRect: chip, xRadius: 74 * scale, yRadius: 74 * scale)
    NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.16, alpha: 1).setFill()
    chipPath.fill()
    NSColor.systemGreen.setStroke()
    chipPath.lineWidth = max(18 * scale, 1)
    chipPath.stroke()

    drawPins(on: chip, scale: scale)

    let percentText = "%"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 260 * scale, weight: .heavy),
        .foregroundColor: NSColor.systemGreen
    ]
    let textSize = percentText.size(withAttributes: attributes)
    percentText.draw(
        at: NSPoint(x: bounds.midX - textSize.width / 2, y: bounds.midY - textSize.height / 2 - 6 * scale),
        withAttributes: attributes
    )

    image.unlockFocus()
    return image
}

func drawPins(on chip: NSRect, scale: CGFloat) {
    let pinColor = NSColor.systemGreen.withAlphaComponent(0.72)
    pinColor.setFill()

    for index in 0..<6 {
        let offset = CGFloat(index) * 58 * scale
        NSBezierPath(roundedRect: NSRect(x: chip.minX + 68 * scale + offset, y: chip.maxY + 18 * scale, width: 26 * scale, height: 58 * scale), xRadius: 10 * scale, yRadius: 10 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: chip.minX + 68 * scale + offset, y: chip.minY - 76 * scale, width: 26 * scale, height: 58 * scale), xRadius: 10 * scale, yRadius: 10 * scale).fill()
    }

    for index in 0..<4 {
        let offset = CGFloat(index) * 72 * scale
        NSBezierPath(roundedRect: NSRect(x: chip.minX - 76 * scale, y: chip.minY + 78 * scale + offset, width: 58 * scale, height: 26 * scale), xRadius: 10 * scale, yRadius: 10 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: chip.maxX + 18 * scale, y: chip.minY + 78 * scale + offset, width: 58 * scale, height: 26 * scale), xRadius: 10 * scale, yRadius: 10 * scale).fill()
    }
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try png.write(to: url)
}
