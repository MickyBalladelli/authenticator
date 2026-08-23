import AppKit

// Renders the Authenticator app icon into an Apple iconset directory.
// Usage: swift scripts/make_icon.swift <iconset-dir> [icns-output-path]
//
// When an output path is given, a complete .icns file is written directly
// (PNG payloads inside the classic icns container) so iconutil is not needed.

let arguments = CommandLine.arguments
guard (2...3).contains(arguments.count) else {
    FileHandle.standardError.write(Data("usage: make_icon <iconset-dir> [icns-output]\n".utf8))
    exit(2)
}
let outputDirectory = arguments[1]
let icnsOutput = arguments.count == 3 ? arguments[2] : nil

let entries: [(pixels: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func shieldPath(in rect: NSRect) -> NSBezierPath {
    let w = rect.width
    let h = rect.height
    let x = rect.minX
    let y = rect.minY
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x + w * 0.5, y: y + h))
    path.curve(
        to: NSPoint(x: x, y: y + h * 0.80),
        controlPoint1: NSPoint(x: x + w * 0.28, y: y + h),
        controlPoint2: NSPoint(x: x, y: y + h * 0.93)
    )
    path.line(to: NSPoint(x: x, y: y + h * 0.46))
    path.curve(
        to: NSPoint(x: x + w * 0.5, y: y),
        controlPoint1: NSPoint(x: x, y: y + h * 0.20),
        controlPoint2: NSPoint(x: x + w * 0.26, y: y + h * 0.05)
    )
    path.curve(
        to: NSPoint(x: x + w, y: y + h * 0.46),
        controlPoint1: NSPoint(x: x + w * 0.74, y: y + h * 0.05),
        controlPoint2: NSPoint(x: x + w, y: y + h * 0.20)
    )
    path.line(to: NSPoint(x: x + w, y: y + h * 0.80))
    path.curve(
        to: NSPoint(x: x + w * 0.5, y: y + h),
        controlPoint1: NSPoint(x: x + w, y: y + h * 0.93),
        controlPoint2: NSPoint(x: x + w * 0.72, y: y + h)
    )
    path.close()
    return path
}

func drawIcon(pixels: CGFloat) {
    let s = pixels

    let backgroundBlue = NSColor(calibratedRed: 0.043, green: 0.243, blue: 0.706, alpha: 1)

    // Rounded square with a vertical gradient.
    let radius = s * 0.205
    let background = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
        xRadius: radius,
        yRadius: radius
    )
    backgroundBlue.setFill()
    background.fill()
    if let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.180, green: 0.514, blue: 1.000, alpha: 1),
        backgroundBlue,
    ]) {
        gradient.draw(in: background, angle: -90)
    }

    // White shield.
    let shieldWidth = s * 0.52
    let shieldHeight = s * 0.62
    let shieldRect = NSRect(
        x: (s - shieldWidth) / 2,
        y: s * 0.17,
        width: shieldWidth,
        height: shieldHeight
    )
    NSColor.white.setFill()
    shieldPath(in: shieldRect).fill()

    // Keyhole cut-out in deep blue.
    let keyholeBlue = NSColor(calibratedRed: 0.086, green: 0.353, blue: 0.878, alpha: 1)
    keyholeBlue.setFill()
    let centerX = s / 2
    let holeRadius = shieldWidth * 0.155
    let holeCenterY = shieldRect.minY + shieldHeight * 0.60
    NSBezierPath(
        ovalIn: NSRect(
            x: centerX - holeRadius,
            y: holeCenterY - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        )
    ).fill()
    let stemWidth = shieldWidth * 0.22
    let stemBottom = shieldRect.minY + shieldHeight * 0.26
    NSBezierPath(
        roundedRect: NSRect(
            x: centerX - stemWidth / 2,
            y: stemBottom,
            width: stemWidth,
            height: holeCenterY - stemBottom
        ),
        xRadius: stemWidth / 2,
        yRadius: stemWidth / 2
    ).fill()
}

func renderPNG(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
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
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(pixels: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// OSType per representation, keyed by pixel size. Both 1x and @2x variants.
let icnsTypes: [Int: String] = [
    16: "icp4",
    32: "icp5",
    64: "ic12",
    128: "ic07",
    256: "ic08",
    512: "ic09",
    1024: "ic10",
]

func writeICNS(path: String, images: [Int: Data]) throws {
    var chunks = Data()
    for (pixels, type) in icnsTypes.sorted(by: { $0.key < $1.key }) {
        guard let png = images[pixels] else { continue }
        var chunk = Data()
        chunk.append(contentsOf: Array(type.utf8))
        var length = UInt32(png.count + 8).bigEndian
        chunk.append(Data(bytes: &length, count: 4))
        chunk.append(png)
        chunks.append(chunk)
    }

    var file = Data()
    file.append(Data("icns".utf8))
    var totalLength = UInt32(chunks.count + 8).bigEndian
    file.append(Data(bytes: &totalLength, count: 4))
    file.append(chunks)
    try file.write(to: URL(fileURLWithPath: path))
}

do {
    try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write(Data("mkdir failed: \(error)\n".utf8))
    exit(1)
}

var rendered: [Int: Data] = [:]

for entry in entries {
    guard let data = renderPNG(pixels: entry.pixels) else {
        FileHandle.standardError.write(Data("render failed: \(entry.name)\n".utf8))
        exit(1)
    }
    rendered[entry.pixels] = data
    do {
        try data.write(to: URL(fileURLWithPath: outputDirectory + "/" + entry.name))
    } catch {
        FileHandle.standardError.write(Data("write failed: \(entry.name): \(error)\n".utf8))
        exit(1)
    }
}
print("wrote \(entries.count) PNGs to \(outputDirectory)")

if let icnsOutput {
    do {
        let parentDirectory = (icnsOutput as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true)
        try writeICNS(path: icnsOutput, images: rendered)
        print("wrote ICNS to \(icnsOutput)")
    } catch {
        FileHandle.standardError.write(Data("icns write failed: \(error)\n".utf8))
        exit(1)
    }
}
