// Exports the cobalt sound-bar mark used by BrandMark in Sources/Views.swift.
// Usage: swift Tools/icon.swift <out.iconset> <readme.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Usage: swift Tools/icon.swift <out.iconset> <readme.png>\n", stderr)
    exit(1)
}
try FileManager.default.createDirectory(atPath: args[1], withIntermediateDirectories: true)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    // Match the 32-point SwiftUI mark, with the usual macOS icon margin.
    let unit = tile.width / 32
    rgb(0x325EF5).setFill()
    NSBezierPath(roundedRect: tile, xRadius: 9 * unit, yRadius: 9 * unit).fill()
    NSColor.white.setFill()
    for (index, height) in [10.0, 18.0, 13.0].enumerated() {
        let bar = NSRect(x: tile.minX + (7 + CGFloat(index) * 7) * unit,
                         y: tile.minY + 7 * unit, width: 4 * unit, height: height * unit)
        NSBezierPath(roundedRect: bar, xRadius: 2 * unit, yRadius: 2 * unit).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try render(px).write(to: URL(fileURLWithPath: "\(args[1])/icon_\(name).png"))
}
try render(512).write(to: URL(fileURLWithPath: args[2]))
