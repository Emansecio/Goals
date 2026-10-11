import SwiftUI

/// Últimos 48 dias, um quadrado por dia; o último é hoje.
/// Recebe só valores, então só redesenha quando os níveis ou a seleção mudam.
struct StreakCard: View {
    let days: [String]
    let levels: [Int]
    let today: String
    let selected: String
    let streak: Int
    let appeared: Bool
    let onSelect: (String) -> Void

    @Namespace private var ringSpace
    private static let columnCount = 12
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: StreakCard.columnCount)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .symbolEffect(.bounce, options: .nonRepeating, value: streak)
                Text("Sequência")
                Spacer()
                Text("\(streak)d")
                    .font(.system(size: 12))
                    .foregroundStyle(streak > 0 ? Theme.blue : Theme.muted)
                    .contentTransition(.numericText(value: Double(streak)))
                    .animation(Motion.snappy, value: streak)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.top, 2)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    StreakCell(
                        day: day,
                        level: levels[index],
                        isSelected: day == selected,
                        isToday: day == today,
                        ringSpace: ringSpace,
                        onSelect: onSelect
                    )
                    // Onda diagonal ao abrir.
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.66)
                            .delay(0.12 + Double(index % Self.columnCount + index / Self.columnCount) * 0.014),
                        value: appeared
                    )
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("nada")
                ForEach(0..<4) { level in
                    RoundedRectangle(cornerRadius: 2.5).fill(Theme.level(level)).frame(width: 9, height: 9)
                }
                Text("tudo")
                Spacer()
                Text("\(days.count) dias")
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

private struct StreakCell: View {
    let day: String
    let level: Int
    let isSelected: Bool
    let isToday: Bool
    let ringSpace: Namespace.ID
    let onSelect: (String) -> Void

    @State private var hovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .fill(Theme.level(level))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(white: 0.4), lineWidth: 1.5)
                        .padding(-2.5)
                }
            }
            .overlay {
                // O anel de seleção desliza de um dia para o outro.
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .padding(-2.5)
                        .matchedGeometryEffect(id: "ring", in: ringSpace)
                }
            }
            .scaleEffect(hovering ? 1.18 : 1)
            .zIndex(hovering ? 1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hovering)
            .animation(.easeInOut(duration: 0.35), value: level)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture { onSelect(day) }
            .help(Day.label(day))
    }
}
