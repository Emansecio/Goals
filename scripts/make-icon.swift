// Gera Resources/AppIcon.icns desenhando o ícone com CoreGraphics.
// Uso: swift scripts/make-icon.swift   (precisa rodar da raiz do projeto)
import AppKit

let blue = CGColor(red: 10 / 255, green: 108 / 255, blue: 1, alpha: 1)
let track = CGColor(gray: 0.22, alpha: 1)

func drawIcon(size: CGFloat) -> CGImage {
    let px = Int(size)
    let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    // Base "squircle" no grid de ícones do macOS (824 pt dentro de 1024).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(gray: 0.08, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [CGColor(gray: 0.15, alpha: 1), CGColor(gray: 0.03, alpha: 1)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // "Notch" preto descendo do topo, como o hub aberto.
    let notch = CGMutablePath()
    let top: CGFloat = 924, left: CGFloat = 230, right: CGFloat = 794, bottom: CGFloat = 330
    let flare: CGFloat = 40, radius: CGFloat = 110
    notch.move(to: CGPoint(x: left - flare, y: top))
    notch.addQuadCurve(to: CGPoint(x: left, y: top - flare), control: CGPoint(x: left, y: top))
    notch.addLine(to: CGPoint(x: left, y: bottom + radius))
    notch.addQuadCurve(to: CGPoint(x: left + radius, y: bottom), control: CGPoint(x: left, y: bottom))
    notch.addLine(to: CGPoint(x: right - radius, y: bottom))
    notch.addQuadCurve(to: CGPoint(x: right, y: bottom + radius), control: CGPoint(x: right, y: bottom))
    notch.addLine(to: CGPoint(x: right, y: top - flare))
    notch.addQuadCurve(to: CGPoint(x: right + flare, y: top), control: CGPoint(x: right, y: top))
    notch.closeSubpath()
    ctx.addPath(notch)
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.fillPath()

    // Linha de progresso em U: trilho + trecho azul.
    let inset: CGFloat = 44
    let u = CGMutablePath()
    let ul = left + inset, ur = right - inset, ub = bottom + inset, ut = top - 20, ur2 = radius - inset + 20
    u.move(to: CGPoint(x: ul, y: ut))
    u.addLine(to: CGPoint(x: ul, y: ub + ur2))
    u.addQuadCurve(to: CGPoint(x: ul + ur2, y: ub), control: CGPoint(x: ul, y: ub))
    u.addLine(to: CGPoint(x: ur - ur2, y: ub))
    u.addQuadCurve(to: CGPoint(x: ur, y: ub + ur2), control: CGPoint(x: ur, y: ub))
    u.addLine(to: CGPoint(x: ur, y: ut))
    ctx.setLineCap(.round)
    ctx.setLineWidth(30)
    ctx.addPath(u)
    ctx.setStrokeColor(track)
    ctx.strokePath()
    ctx.addPath(u.copy(dashingWithPhase: 0, lengths: [1010, 2000]))
    ctx.setStrokeColor(blue)
    ctx.strokePath()

    // Check azul dentro do notch.
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 410, y: 630))
    check.addLine(to: CGPoint(x: 480, y: 555))
    check.addLine(to: CGPoint(x: 625, y: 720))
    ctx.setLineWidth(48)
    ctx.setLineJoin(.round)
    ctx.addPath(check)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
    ctx.strokePath()

    // Fileira de "dias" do grid de sequência embaixo.
    let levels: [CGFloat] = [1, 0.55, 1, 1, 0.3, 1]
    let cell: CGFloat = 70, gap: CGFloat = 24
    let rowWidth = cell * 6 + gap * 5
    for (i, level) in levels.enumerated() {
        let x = 512 - rowWidth / 2 + CGFloat(i) * (cell + gap)
        let rect = CGRect(x: x, y: 185, width: cell, height: cell)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.setFillColor(CGColor(red: 10 / 255 * level, green: 108 / 255 * level, blue: level, alpha: 1))
        ctx.fillPath()
    }
    ctx.restoreGState()
    return ctx.makeImage()!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let image = drawIcon(size: CGFloat(base * scale))
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent(name))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns gerado" : "iconutil falhou")
