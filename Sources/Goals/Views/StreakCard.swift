import SwiftUI

/// Calendário do mês: um quadrado por dia (1…N), na ordem; hoje fica no seu número.
/// Recebe só valores, então só redesenha quando os níveis ou a seleção mudam.
struct StreakCard: View {
    let title: String
    let days: [String]
    let levels: [Int]
    let today: String
    let selected: String
    let streak: Int
    let appeared: Bool
    let onSelect: (String) -> Void

    @Namespace private var ringSpace
    private static let columnCount = 8
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: StreakCard.columnCount)

    var body: some View {
        let completed = levels.filter { $0 == 3 }.count

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .symbolEffect(.bounce, options: .nonRepeating, value: streak)
                Text(title)
                    .id(title)
                    .transition(.opacity.combined(with: .offset(y: 4)))
                Spacer()
                Text("\(streak)d")
                    .font(.system(size: 12))
                    .foregroundStyle(streak > 0 ? Theme.blue : Theme.muted)
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(Motion.snappy, value: streak)
                    .help("Dias seguidos com tudo feito")
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.top, 2)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    DayCell(
                        number: index + 1,
                        level: levels[index],
                        isSelected: day == selected,
                        isToday: day == today,
                        isFuture: day > today,
                        ringSpace: ringSpace,
                        onSelect: { onSelect(day) }
                    )
                    // Onda diagonal ao abrir.
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.72)
                            .delay(0.04 + Double(index % Self.columnCount + index / Self.columnCount) * 0.008),
                        value: appeared
                    )
                }
            }
            .id(days.first)
            .transition(.opacity)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("nada")
                ForEach(0..<4) { level in
                    RoundedRectangle(cornerRadius: 2.5).fill(Theme.level(level)).frame(width: 9, height: 9)
                }
                Text("tudo")
                Spacer()
                Text("\(completed) \(completed == 1 ? "dia completo" : "dias completos")")
                    .contentTransition(.numericText(value: Double(completed)))
                    .animation(Motion.snappy, value: completed)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 2)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }
}

private struct DayCell: View {
    let number: Int
    let level: Int
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let ringSpace: Namespace.ID
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isFuture ? Color(white: 0.09) : Theme.level(level))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text("\(number)")
                    .font(.system(size: 9.5, weight: isToday ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(numberColor)
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(white: 0.45), lineWidth: 1.5)
                        .padding(-2.5)
                }
            }
            .overlay {
                // O anel de seleção desliza de um dia para o outro.
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .padding(-2.5)
                        .matchedGeometryEffect(id: "ring", in: ringSpace)
                }
            }
            .scaleEffect(hovering ? 1.15 : 1)
            .zIndex(hovering ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hovering)
            .animation(.easeInOut(duration: 0.35), value: level)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: onSelect)
    }

    private var numberColor: Color {
        if isFuture { return Color(white: 0.32) }
        if isToday || level >= 2 { return .white }
        return Color(white: level == 1 ? 0.7 : 0.42)
    }
}
