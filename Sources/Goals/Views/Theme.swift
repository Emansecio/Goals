import AppKit
import SwiftUI

enum Theme {
    static let blue = Color(red: 10 / 255, green: 108 / 255, blue: 1)
    static let blueMid = Color(red: 11 / 255, green: 77 / 255, blue: 184 / 255)
    static let blueDark = Color(red: 10 / 255, green: 35 / 255, blue: 87 / 255)
    static let cellEmpty = Color(white: 0.11)
    static let card = Color(white: 0.07)
    static let row = Color(white: 0.11)
    static let rowHover = Color(white: 0.14)
    static let track = Color(white: 0.17)
    static let muted = Color(white: 0.56)
    static let orange = Color(red: 1, green: 0.62, blue: 0.04)
    static let red = Color(red: 1, green: 0.41, blue: 0.38)

    static func level(_ level: Int) -> Color {
        switch level {
        case 3: blue
        case 2: blueMid
        case 1: blueDark
        default: cellEmpty
        }
    }
}

/// Curvas de animação usadas no app, num lugar só para manter o "feel" consistente.
enum Motion {
    /// Abrir: mola com um leve overshoot.
    static let open = Animation.spring(response: 0.44, dampingFraction: 0.74)
    /// Fechar: imediato e sem quicar.
    static let close = Animation.spring(response: 0.24, dampingFraction: 1)
    /// Efeito magnético do recolhido quando o mouse se aproxima.
    static let magnet = Animation.spring(response: 0.32, dampingFraction: 0.62)
    /// Troca de dia.
    static let nav = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// Interações pequenas (check, inserir, editar).
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.78)
    /// Progresso enchendo.
    static let fill = Animation.spring(response: 0.7, dampingFraction: 0.86)
}

enum Haptics {
    /// Toque leve no trackpad Force Touch.
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

/// Entrada em cascata: desce, desfoca → foca, aparece.
struct Reveal: ViewModifier {
    var shown: Bool
    var delay: Double
    var offset: CGFloat = -10
    var blur: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : offset)
            .scaleEffect(shown ? 1 : 0.97, anchor: .top)
            .blur(radius: shown ? 0 : blur)
            .animation(Motion.open.delay(delay), value: shown)
    }
}

extension View {
    func reveal(_ shown: Bool, delay: Double, offset: CGFloat = -10, blur: CGFloat = 6) -> some View {
        modifier(Reveal(shown: shown, delay: delay, offset: offset, blur: blur))
    }
}

/// Formato do hub: cantos de cima curvados para fora (encaixam na barra de menus)
/// e cantos de baixo arredondados. A largura inclui as "abas" de `topRadius` dos dois lados.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let t = topRadius, b = min(bottomRadius, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t), control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY), control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b), control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Linha em "U" (lado esquerdo → base → lado direito) usada como barra de progresso.
struct ProgressU: Shape {
    var top: CGFloat = 0
    var side: CGFloat = 0
    var bottom: CGFloat = 0
    var radius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let x0 = rect.minX + side, x1 = rect.maxX - side
        let y0 = rect.minY + top, y1 = rect.maxY - bottom
        let r = min(radius, (x1 - x0) / 2, y1 - y0)
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        p.addLine(to: CGPoint(x: x0, y: y1 - r))
        p.addQuadCurve(to: CGPoint(x: x0 + r, y: y1), control: CGPoint(x: x0, y: y1))
        p.addLine(to: CGPoint(x: x1 - r, y: y1))
        p.addQuadCurve(to: CGPoint(x: x1, y: y1 - r), control: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x1, y: y0))
        return p
    }
}

/// Trilho + progresso azul, com brilho opcional disparado por `glow`.
struct ProgressOutline: View {
    var shape: ProgressU
    var fraction: Double
    var lineWidth: CGFloat
    var glow = 0

    var body: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        ZStack {
            shape.stroke(Theme.track, style: style)
            shape.trim(from: 0, to: fraction)
                .stroke(Theme.blue, style: style)
                .keyframeAnimator(initialValue: 0.0, trigger: glow) { content, intensity in
                    content
                        .shadow(color: Theme.blue.opacity(intensity), radius: 8 * intensity)
                        .brightness(0.25 * intensity)
                } keyframes: { _ in
                    CubicKeyframe(1, duration: 0.22)
                    CubicKeyframe(0.6, duration: 0.25)
                    CubicKeyframe(1, duration: 0.2)
                    CubicKeyframe(0, duration: 0.7)
                }
        }
    }
}

/// ✓ desenhado com `trim`, para animar o traço.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// Botão pequeno em formato de pílula (chips do editor, ações).
struct Chip: View {
    var isOn = false
    var icon: String?
    var text: String
    var tint: Color = Theme.blue
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 9.5, weight: .semibold)) }
                Text(text).lineLimit(1).fixedSize()
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isOn ? tint : Color(white: hovering ? 0.95 : 0.82))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? tint.opacity(0.22) : Color(white: hovering ? 0.22 : 0.17))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(Motion.snappy, value: isOn)
    }
}

/// Encolhe levemente ao pressionar.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension Double {
    static func fraction(_ p: (done: Int, total: Int)) -> Double {
        p.total == 0 ? 0 : Double(p.done) / Double(p.total)
    }
}
