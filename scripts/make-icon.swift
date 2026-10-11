// Gera Resources/AppIcon.icns desenhando o ícone com CoreGraphics.
// Uso: swift scripts/make-icon.swift   (rodar da raiz do projeto)
// Opcional: swift scripts/make-icon.swift preview.png   (salva também um PNG 1024)
import AppKit

let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let blue = rgb(0x0A6CFF)
let blueLight = rgb(0x4C9BFF)
let blueMid = rgb(0x0B4DB8)
let blueDark = rgb(0x0A2357)
let cellEmpty = rgb(0x1B1E25)

/// "Squircle" (superelipse) como nos ícones do macOS, em vez de cantos circulares.
func squircle(_ rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * a * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / n) * b * (s < 0 ? -1 : 1)
        let p = CGPoint(x: rect.midX + x, y: rect.midY + y)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Contorno do hub: cantos de cima abertos para fora, cantos de baixo arredondados.
func notchPath(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, flare: CGFloat, radius: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: left - flare, y: top))
    p.addQuadCurve(to: CGPoint(x: left, y: top - flare), control: CGPoint(x: left, y: top))
    p.addLine(to: CGPoint(x: left, y: bottom + radius))
    p.addCurve(to: CGPoint(x: left + radius, y: bottom),
               control1: CGPoint(x: left, y: bottom + radius * 0.45),
               control2: CGPoint(x: left + radius * 0.45, y: bottom))
    p.addLine(to: CGPoint(x: right - radius, y: bottom))
    p.addCurve(to: CGPoint(x: right, y: bottom + radius),
               control1: CGPoint(x: right - radius * 0.45, y: bottom),
               control2: CGPoint(x: right, y: bottom + radius * 0.45))
    p.addLine(to: CGPoint(x: right, y: top - flare))
    p.addQuadCurve(to: CGPoint(x: right + flare, y: top), control: CGPoint(x: right, y: top))
    p.closeSubpath()
    return p
}

/// Linha em "U" da barra de progresso.
func uPath(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, radius: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: left, y: top))
    p.addLine(to: CGPoint(x: left, y: bottom + radius))
    p.addCurve(to: CGPoint(x: left + radius, y: bottom),
               control1: CGPoint(x: left, y: bottom + radius * 0.45),
               control2: CGPoint(x: left + radius * 0.45, y: bottom))
    p.addLine(to: CGPoint(x: right - radius, y: bottom))
    p.addCurve(to: CGPoint(x: right, y: bottom + radius),
               control1: CGPoint(x: right - radius * 0.45, y: bottom),
               control2: CGPoint(x: right, y: bottom + radius * 0.45))
    p.addLine(to: CGPoint(x: right, y: top))
    return p
}

func linearGradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

func drawIcon(size: CGFloat) -> CGImage {
    let px = Int(size)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: size / 1024, y: size / 1024)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Base no grid de ícones do macOS: 824 pt centrados em 1024, com sombra.
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let body = squircle(bodyRect)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: rgb(0x000000, 0.5))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0x0C0E12))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()

    // Fundo: grafite em cima → quase preto embaixo, com brilho azul vindo de baixo.
    ctx.drawLinearGradient(linearGradient([rgb(0x22262F), rgb(0x0B0C10)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.drawRadialGradient(linearGradient([rgb(0x0A6CFF, 0.38), rgb(0x0A6CFF, 0)]),
                           startCenter: CGPoint(x: 512, y: 150), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 150), endRadius: 520, options: [])

    // Hub descendo do topo.
    let hubLeft: CGFloat = 214, hubRight: CGFloat = 810, hubBottom: CGFloat = 400
    let hub = notchPath(left: hubLeft, right: hubRight, top: 924, bottom: hubBottom, flare: 34, radius: 112)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x000000, 0.7))
    ctx.addPath(hub)
    ctx.setFillColor(rgb(0x000000))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(hub)
    ctx.clip()
    ctx.drawLinearGradient(linearGradient([rgb(0x000000), rgb(0x0A0C11)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: hubBottom), options: [])
    ctx.restoreGState()

    // Linha de progresso em U: trilho + trecho azul com gradiente e brilho.
    let u = uPath(left: hubLeft + 34, right: hubRight - 34, top: 900, bottom: hubBottom + 34, radius: 80)
    ctx.setLineWidth(20)
    ctx.addPath(u)
    ctx.setStrokeColor(rgb(0x262A33))
    ctx.strokePath()

    let progress = u.copy(dashingWithPhase: 0, lengths: [1080, 4000])
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 34, color: rgb(0x0A6CFF, 0.95))
    ctx.setLineWidth(20)
    ctx.addPath(progress)
    ctx.setStrokeColor(blue)
    ctx.strokePath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(progress.copy(strokingWithWidth: 20, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.clip()
    ctx.drawLinearGradient(linearGradient([blueLight, blue]),
                           start: CGPoint(x: 0, y: 900), end: CGPoint(x: 0, y: hubBottom), options: [])
    ctx.restoreGState()

    // Três tarefas: duas feitas, uma aberta.
    let rows: [(y: CGFloat, done: Bool, bar: CGFloat)] = [(712, true, 250), (612, true, 200), (512, false, 280)]
    let rowLeft = hubLeft + 82, rowRight = hubRight - 82
    for row in rows {
        let rect = CGRect(x: rowLeft, y: row.y, width: rowRight - rowLeft, height: 80)
        ctx.addPath(roundedRect(rect, 24))
        ctx.setFillColor(rgb(0x171A21))
        ctx.fillPath()

        let center = CGPoint(x: rect.minX + 44, y: rect.midY)
        let circle = CGRect(x: center.x - 21, y: center.y - 21, width: 42, height: 42)
        if row.done {
            ctx.addEllipse(in: circle)
            ctx.setFillColor(blue)
            ctx.fillPath()
            let check = CGMutablePath()
            check.move(to: CGPoint(x: center.x - 10, y: center.y + 1))
            check.addLine(to: CGPoint(x: center.x - 3, y: center.y - 7))
            check.addLine(to: CGPoint(x: center.x + 11, y: center.y + 9))
            ctx.setLineWidth(7)
            ctx.addPath(check)
            ctx.setStrokeColor(rgb(0xFFFFFF))
            ctx.strokePath()
        } else {
            ctx.setLineWidth(5)
            ctx.addEllipse(in: circle.insetBy(dx: 2.5, dy: 2.5))
            ctx.setStrokeColor(rgb(0x5B606C))
            ctx.strokePath()
        }

        let bar = CGRect(x: rect.minX + 88, y: rect.midY - 8, width: row.bar, height: 16)
        ctx.addPath(roundedRect(bar, 8))
        ctx.setFillColor(row.done ? rgb(0x3A3F4A) : rgb(0xE8EAEE))
        ctx.fillPath()
    }

    // Grid de sequência: 2 × 7 dias, o último é hoje.
    let levels: [[Int]] = [[3, 2, 3, 3, 0, 3, 1], [3, 3, 2, 3, 3, 3, 3]]
    let cell: CGFloat = 58, gap: CGFloat = 16
    let gridWidth = cell * 7 + gap * 6
    let gridLeft = 512 - gridWidth / 2
    for (r, line) in levels.enumerated() {
        for (c, level) in line.enumerated() {
            let rect = CGRect(x: gridLeft + CGFloat(c) * (cell + gap), y: 262 - CGFloat(r) * (cell + gap), width: cell, height: cell)
            let color = [cellEmpty, blueDark, blueMid, blue][level]
            if level == 3 {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: 18, color: rgb(0x0A6CFF, 0.55))
                ctx.addPath(roundedRect(rect, 15))
                ctx.setFillColor(color)
                ctx.fillPath()
                ctx.restoreGState()
            } else {
                ctx.addPath(roundedRect(rect, 15))
                ctx.setFillColor(color)
                ctx.fillPath()
            }
            if r == 1 && c == 6 {
                ctx.setLineWidth(5)
                ctx.addPath(roundedRect(rect.insetBy(dx: -9, dy: -9), 21))
                ctx.setStrokeColor(rgb(0xFFFFFF, 0.9))
                ctx.strokePath()
            }
        }
    }

    // Brilho fino na borda de cima (acabamento de vidro).
    ctx.addPath(body)
    ctx.setLineWidth(4)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(linearGradient([rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)], [0, 0.35]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    return ctx.makeImage()!
}

func png(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try png(drawIcon(size: CGFloat(base * scale))).write(to: iconset.appendingPathComponent(name))
    }
}

if CommandLine.arguments.count > 1 {
    try png(drawIcon(size: 1024)).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try? fm.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns gerado" : "iconutil falhou")
