import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("用法：generate-icon.swift <AppIcon.png> <output.iconset>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let source = NSImage(contentsOf: inputURL) else {
    fputs("无法读取图标源文件\n", stderr)
    exit(3)
}

try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func write(size: Int, scale: Int) throws {
    let pixels = size * scale
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let suffix = scale == 2 ? "@2x" : ""
    try data.write(to: outputURL.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
}

for size in [16, 32, 128, 256, 512] {
    try write(size: size, scale: 1)
    try write(size: size, scale: 2)
}
