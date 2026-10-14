// Draws Brow's app icon: a black notch "drop" on a light macOS-style squircle.
// Usage: swift scripts/make-icon.swift <output.png>   (1024×1024)
import AppKit

let size: CGFloat = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])

let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
    // Canvas with the standard macOS icon margin.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor.white.setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(starting: NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 1),
               ending: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.89, alpha: 1))!
        .draw(in: squircle, angle: 90)

    // The notch growing into a panel: flush with the tile's top edge, round bottom corners.
    squircle.addClip()
    let drop = NSRect(x: tile.midX - 250, y: tile.minY, width: 500, height: 300)
    let radius: CGFloat = 110
    let path = NSBezierPath()
    path.move(to: NSPoint(x: drop.minX, y: drop.minY))
    path.line(to: NSPoint(x: drop.maxX, y: drop.minY))
    path.line(to: NSPoint(x: drop.maxX, y: drop.maxY - radius))
    path.appendArc(withCenter: NSPoint(x: drop.maxX - radius, y: drop.maxY - radius),
                   radius: radius, startAngle: 0, endAngle: 90)
    path.line(to: NSPoint(x: drop.minX + radius, y: drop.maxY))
    path.appendArc(withCenter: NSPoint(x: drop.minX + radius, y: drop.maxY - radius),
                   radius: radius, startAngle: 90, endAngle: 180)
    path.close()
    NSColor.black.setFill()
    path.fill()

    // A hint of content inside the panel: artwork tile and a progress line.
    NSColor(calibratedRed: 0.36, green: 0.55, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: drop.minX + 70, y: drop.minY + 140, width: 90, height: 90),
                 xRadius: 22, yRadius: 22).fill()
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: drop.minX + 190, y: drop.minY + 150, width: 230, height: 22),
                 xRadius: 11, yRadius: 11).fill()
    NSColor.white.withAlphaComponent(0.4).setFill()
    NSBezierPath(roundedRect: NSRect(x: drop.minX + 190, y: drop.minY + 198, width: 150, height: 18),
                 xRadius: 9, yRadius: 9).fill()
    return true
}

guard let tiff = image.tiffRepresentation,
      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: output)
