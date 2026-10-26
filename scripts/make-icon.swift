// 仮のアプリアイコンを描画して PNG として書き出す。
// 使い方: swift scripts/make-icon.swift <出力PNG> <ピクセルサイズ>
import AppKit

guard CommandLine.arguments.count == 3, let pixels = Int(CommandLine.arguments[2]) else {
    FileHandle.standardError.write(Data("Usage: make-icon.swift <output.png> <pixels>\n".utf8))
    exit(2)
}
let outputPath = CommandLine.arguments[1]
let size = CGFloat(pixels)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// macOS のアイコングリッド: 1024 に対して約 824 の角丸四角（余白あり）
let inset = size * 0.0977
let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)

let shadow = NSShadow()
shadow.shadowColor = color(0x000000, alpha: 0.35)
shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
shadow.shadowBlurRadius = size * 0.025
NSGraphicsContext.saveGraphicsState()
shadow.set()
color(0x3A394C).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

// 背景: アプリの空ページと同じ紫がかったグレーのグラデーション
tilePath.addClip()
NSGradient(colors: [color(0x3A394C), color(0x413A4C), color(0x49394C)])?
    .draw(in: tile, angle: -45)

// サイドバー（縦タブ）を表す明るいパネル
let panelWidth = tile.width * 0.30
let panel = NSRect(
    x: tile.minX + tile.width * 0.09, y: tile.minY + tile.height * 0.09,
    width: panelWidth, height: tile.height * 0.82
)
let panelPath = NSBezierPath(roundedRect: panel, xRadius: tile.width * 0.07, yRadius: tile.width * 0.07)
color(0x5E5C5C).setFill()
panelPath.fill()

// パネル内のタブ行。先頭だけアクセント色（選択中のタブ）
let rowHeight = panel.height * 0.085
for index in 0..<4 {
    let rowY = panel.maxY - panel.height * 0.12 - CGFloat(index) * panel.height * 0.15 - rowHeight
    let row = NSRect(
        x: panel.minX + panel.width * 0.14, y: rowY,
        width: panel.width * 0.72, height: rowHeight
    )
    let path = NSBezierPath(roundedRect: row, xRadius: rowHeight / 2, yRadius: rowHeight / 2)
    (index == 0 ? color(0xA553A7) : color(0xEDEDED, alpha: 0.30)).setFill()
    path.fill()
}

// コンテンツ側: チョコレートのように見える丸みのある割れ板
let content = NSRect(
    x: panel.maxX + tile.width * 0.06, y: tile.minY + tile.height * 0.09,
    width: tile.maxX - panel.maxX - tile.width * 0.15, height: tile.height * 0.82
)
let card = NSBezierPath(roundedRect: content, xRadius: tile.width * 0.07, yRadius: tile.width * 0.07)
color(0xF4F4F5).setFill()
card.fill()

let chocolate = NSRect(
    x: content.minX + content.width * 0.17, y: content.midY - content.width * 0.33,
    width: content.width * 0.66, height: content.width * 0.66
)
let bar = NSBezierPath(roundedRect: chocolate, xRadius: chocolate.width * 0.18, yRadius: chocolate.width * 0.18)
color(0x4A2C3A).setFill()
bar.fill()

// 板チョコの溝（2×2）
color(0x2E1823).setStroke()
let groove = NSBezierPath()
groove.lineWidth = chocolate.width * 0.045
groove.lineCapStyle = .round
groove.move(to: NSPoint(x: chocolate.midX, y: chocolate.minY + chocolate.height * 0.1))
groove.line(to: NSPoint(x: chocolate.midX, y: chocolate.maxY - chocolate.height * 0.1))
groove.move(to: NSPoint(x: chocolate.minX + chocolate.width * 0.1, y: chocolate.midY))
groove.line(to: NSPoint(x: chocolate.maxX - chocolate.width * 0.1, y: chocolate.midY))
groove.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outputPath))
