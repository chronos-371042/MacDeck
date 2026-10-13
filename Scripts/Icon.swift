import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = destination.appendingPathComponent("MacDeck.iconset")
if FileManager.default.fileExists(atPath: iconset.path) { try FileManager.default.removeItem(at: iconset) }
var chunks = Data()
func appendChunk(_ type: String, _ png: Data) {
    chunks.append(contentsOf: type.utf8)
    var size = UInt32(png.count + 8).bigEndian
    withUnsafeBytes(of: &size) { chunks.append(contentsOf: $0) }
    chunks.append(png)
}
let types = [16: "icp4", 32: "icp5", 64: "icp6", 128: "ic07", 256: "ic08", 512: "ic09", 1024: "ic10"]
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let p = CGFloat(pixels)
    NSColor(calibratedRed: 0.045, green: 0.065, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88), xRadius: p * 0.20, yRadius: p * 0.20).fill()
    if let symbol = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: p * 0.5, weight: .bold)) {
        let rect = NSRect(x: p * 0.19, y: p * 0.31, width: p * 0.62, height: p * 0.38)
        symbol.draw(in: rect)
        NSColor(calibratedRed: 0.53, green: 0.95, blue: 0.75, alpha: 1).setFill()
        rect.fill(using: .sourceAtop)
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    appendChunk(types[pixels]!, data)
}
var container = Data("icns".utf8)
var size = UInt32(chunks.count + 8).bigEndian
withUnsafeBytes(of: &size) { container.append(contentsOf: $0) }
container.append(chunks)
try container.write(to: destination.appendingPathComponent("MacDeck.icns"))
