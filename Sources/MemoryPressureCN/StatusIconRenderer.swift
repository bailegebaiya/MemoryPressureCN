import AppKit

enum StatusIconRenderer {
    static func image(percent: Int, level: MemoryPressureLevel) -> NSImage {
        let clampedPercent = min(max(percent, 0), 100)
        let size = NSSize(width: 38, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let pillRect = NSRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
        let backgroundPath = NSBezierPath(roundedRect: pillRect, xRadius: 5, yRadius: 5)
        level.nsColor.withAlphaComponent(0.16).setFill()
        backgroundPath.fill()

        level.nsColor.withAlphaComponent(0.75).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()

        let mainText = "\(clampedPercent)"
        let symbolText = "%"
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: clampedPercent == 100 ? 10 : 11, weight: .semibold),
            .foregroundColor: level.nsColor
        ]
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: level.nsColor.withAlphaComponent(0.92)
        ]
        let mainSize = mainText.size(withAttributes: mainAttributes)
        let symbolSize = symbolText.size(withAttributes: symbolAttributes)
        let totalWidth = mainSize.width + symbolSize.width + 1
        let startX = (size.width - totalWidth) / 2
        let baselineY = (size.height - max(mainSize.height, symbolSize.height)) / 2 + 0.5

        mainText.draw(at: NSPoint(x: startX, y: baselineY), withAttributes: mainAttributes)
        symbolText.draw(
            at: NSPoint(x: startX + mainSize.width + 1, y: baselineY + 1.2),
            withAttributes: symbolAttributes
        )

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}
