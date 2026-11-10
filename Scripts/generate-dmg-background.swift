import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Scripts/dmg-background.png"
let size = NSSize(width: 730, height: 430)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.995, alpha: 1),
    NSColor(calibratedRed: 0.925, green: 0.945, blue: 0.975, alpha: 1)
])!
background.draw(in: bounds, angle: 90)

let accent = NSColor(calibratedRed: 0.28, green: 0.47, blue: 0.92, alpha: 1)
let secondary = NSColor(calibratedRed: 0.36, green: 0.40, blue: 0.47, alpha: 1)

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    (text as NSString).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

drawText(
    "安装 HaoPaste · Install HaoPaste",
    in: NSRect(x: 44, y: 346, width: 642, height: 42),
    font: .systemFont(ofSize: 28, weight: .bold),
    color: NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.24, alpha: 1)
)

drawText(
    "将 HaoPaste 拖入 Applications 文件夹 / Drag HaoPaste into Applications",
    in: NSRect(x: 44, y: 312, width: 642, height: 28),
    font: .systemFont(ofSize: 14.5, weight: .medium),
    color: secondary
)

// Arrow between the app icon and Applications shortcut.
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 292, y: 205))
arrow.curve(
    to: NSPoint(x: 446, y: 205),
    controlPoint1: NSPoint(x: 340, y: 238),
    controlPoint2: NSPoint(x: 398, y: 238)
)
arrow.lineWidth = 5
accent.withAlphaComponent(0.55).setStroke()
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 446, y: 205))
arrowHead.line(to: NSPoint(x: 426, y: 218))
arrowHead.line(to: NSPoint(x: 426, y: 192))
arrowHead.close()
accent.withAlphaComponent(0.65).setFill()
arrowHead.fill()

let noteBox = NSRect(x: 44, y: 14, width: 642, height: 128)
let note = NSBezierPath(roundedRect: noteBox, xRadius: 12, yRadius: 12)
NSColor.white.withAlphaComponent(0.55).setFill()
note.fill()
accent.withAlphaComponent(0.18).setStroke()
note.lineWidth = 1
note.stroke()

drawText(
    "首次打开如提示「无法验证开发者」 / If the developer cannot be verified",
    in: NSRect(x: 62, y: 114, width: 606, height: 20),
    font: .systemFont(ofSize: 12.5, weight: .semibold),
    color: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.28, alpha: 1)
)
drawText(
    "打开「系统设置 → 隐私与安全性」，在「安全性」中找到 HaoPaste，点击「仍要打开」。",
    in: NSRect(x: 62, y: 90, width: 606, height: 20),
    font: .systemFont(ofSize: 10.8, weight: .regular),
    color: secondary
)
drawText(
    "System Settings → Privacy & Security → Security → find HaoPaste → Open Anyway",
    in: NSRect(x: 62, y: 68, width: 606, height: 20),
    font: .systemFont(ofSize: 10.5, weight: .regular),
    color: secondary
)
drawText(
    "也可以右键 HaoPaste → 打开 / Or right-click HaoPaste in Finder → Open",
    in: NSRect(x: 62, y: 46, width: 606, height: 20),
    font: .systemFont(ofSize: 10.5, weight: .regular),
    color: secondary
)
drawText(
    "系统要求：macOS 14+ / Requires macOS 14 or later",
    in: NSRect(x: 62, y: 24, width: 606, height: 20),
    font: .systemFont(ofSize: 9.5, weight: .regular),
    color: secondary
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("could not render dmg background\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output), options: .atomic)
print("wrote \(output)")
