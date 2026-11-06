import Cocoa
import WebKit

let svgUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("branding/production/citadel-app-icon-colored.svg")
guard let svgData = try? Data(contentsOf: svgUrl),
      let svgImage = NSImage(data: svgData) else {
    print("Failed to load SVG data directly, trying NSImage(contentsOf:)")
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
svgImage.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
let outUrl = URL(fileURLWithPath: "branding/production/citadel-app-icon-colored.png")
try! pngData.write(to: outUrl)
print("Rendered 1024x1024 PNG successfully via NSImage!")
