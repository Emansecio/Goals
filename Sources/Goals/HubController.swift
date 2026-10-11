import Foundation
import CoreGraphics

/// Estado da interface do hub, compartilhado entre o AppDelegate e as views.
@MainActor
final class HubController: ObservableObject {
    static let streakDays = 48

    @Published var isOpen = false
    @Published var today = Day.today {
        didSet { if today != oldValue { recentDays = Self.days(endingAt: today) } }
    }
    @Published private(set) var recentDays = HubController.days(endingAt: Day.today)
    @Published var selectedDay = Day.today
    @Published var editingID: UUID?
    /// Campo "Adicionar tarefa" com foco.
    @Published var isTyping = false
    @Published var notch = CGSize(width: 185, height: 32)
    /// 0…1: quão perto o mouse está do notch (efeito "magnético" do recolhido).
    @Published var proximity: CGFloat = 0
    /// Incrementa para disparar o brilho da borda (pulso, dia completo).
    @Published var glow = 0

    /// Direção da última navegação entre dias (-1 passado, +1 futuro), para a animação.
    private(set) var navDirection = 1
    /// Aberto sozinho por um aviso de "pulso"; não recolhe até o tempo acabar.
    var isPeeking = false

    var isEditing: Bool { editingID != nil || isTyping }

    static let openWidth: CGFloat = 680
    static let openTopRadius: CGFloat = 14
    static let closedTopRadius: CGFloat = 6

    var openSize: CGSize {
        CGSize(width: Self.openWidth, height: editingID != nil ? 430 : 360)
    }

    var collapsedSize: CGSize {
        CGSize(width: notch.width + 8, height: notch.height + 3)
    }

    func select(_ day: String) {
        guard day != selectedDay else { return }
        navDirection = day < selectedDay ? -1 : 1
        editingID = nil
        selectedDay = day
    }

    private static func days(endingAt today: String) -> [String] {
        (0..<streakDays).reversed().map { Day.offset(today, by: -$0) }
    }
}
