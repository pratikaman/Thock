// Renders the app icon (lavender tile + black keycap) into an .iconset: swift Tools/icon.swift <out.iconset> <EBGaramond.ttf>
import AppKit

let args = CommandLine.arguments
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: args[2]) as CFURL, .process, nil)
try? FileManager.default.createDirectory(atPath: args[1], withIntermediateDirectories: true)

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
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGradient(colors: [rgb(0xF6E8FF), rgb(0xE6C6FA)])!.draw(in: tilePath, angle: -90)

    let w = tile.width * 0.56
    let cap = NSRect(x: s / 2 - w / 2, y: s / 2 - w / 2 - s * 0.012, width: w, height: w)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.014)
    shadow.shadowBlurRadius = s * 0.03
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    rgb(0x1A1A1A).setFill()
    NSBezierPath(roundedRect: cap, xRadius: w * 0.22, yRadius: w * 0.22).fill()
    NSGraphicsContext.restoreGraphicsState()

    let face = NSRect(x: cap.minX + w * 0.13, y: cap.minY + w * 0.22, width: w * 0.74, height: w * 0.68)
    rgb(0x3A3A3A).setFill()
    NSBezierPath(roundedRect: face, xRadius: w * 0.15, yRadius: w * 0.15).fill()

    let font = NSFont(name: "EBGaramond-Regular", size: w * 0.56) ?? NSFont.systemFont(ofSize: w * 0.5)
    let t = NSAttributedString(string: "T", attributes: [.font: font, .foregroundColor: NSColor.white])
    let size = t.size()
    t.draw(at: NSPoint(x: face.midX - size.width / 2, y: face.midY - size.height / 2 + w * 0.01))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(args[1])/icon_\(name).png"))
}
