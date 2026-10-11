import Foundation

struct AlertOptions: Codable, Equatable {
    var notification = false
    var pulse = false
    var leadMinutes = 0

    var isOn: Bool { notification || pulse }
}

struct GoalTask: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Dia da tarefa no formato `yyyy-MM-dd` (ver `Day`).
    var day: String
    var title: String
    var notes = ""
    /// Horário/prazo naquele dia. `nil` = tarefa só para conferir.
    var time: Date?
    var isDone = false
    var alert = AlertOptions()
    /// Dia de onde esta cópia veio, quando foi movida como pendente.
    var carriedFrom: String?
    /// Dia para onde esta tarefa foi copiada como pendente.
    var carriedTo: String?
    var createdAt = Date()
    /// Fixada no topo do dia. Opcionais para ler arquivos antigos sem esses campos.
    var pinned: Bool?
    /// Ordem manual (definida ao arrastar). `nil` = ordem automática por horário.
    var rank: Double?

    var isPinned: Bool { pinned ?? false }

    var alertDate: Date? {
        guard let time, alert.isOn else { return nil }
        return time.addingTimeInterval(-Double(alert.leadMinutes) * 60)
    }
}

/// Utilitários de data. Os dias são chaves `yyyy-MM-dd` no fuso local,
/// o que permite comparar dias como strings.
enum Day {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE, d MMM"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static var today: String { key(Date()) }

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    static func date(_ key: String) -> Date { keyFormatter.date(from: key) ?? Date() }

    static func offset(_ key: String, by days: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: days, to: date(key)) ?? date(key)
        return Self.key(d)
    }

    static func distance(from a: String, to b: String) -> Int {
        Calendar.current.dateComponents([.day], from: date(a), to: date(b)).day ?? 0
    }

    /// Junta a hora/minuto de `time` com o dia `key`.
    static func combine(_ key: String, time: Date) -> Date {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: hm.hour ?? 9, minute: hm.minute ?? 0, second: 0, of: date(key)) ?? time
    }

    /// "Sáb, 10 out"
    static func label(_ key: String) -> String {
        let s = labelFormatter.string(from: date(key))
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " de ", with: " ")
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// "yyyy-MM" do dia.
    static func month(_ key: String) -> String { String(key.prefix(7)) }

    /// Todos os dias do mês de `key`, do dia 1 ao último.
    static func daysInMonth(of key: String) -> [String] {
        let count = Calendar.current.range(of: .day, in: .month, for: date(key))?.count ?? 30
        let prefix = month(key)
        return (1...count).map { prefix + "-" + ($0 < 10 ? "0\($0)" : "\($0)") }
    }

    /// "Outubro" (com o ano quando não é o ano atual: "Outubro 2025").
    static func monthTitle(_ key: String, today: String) -> String {
        let name = monthFormatter.string(from: date(key))
        let title = name.prefix(1).uppercased() + name.dropFirst()
        return key.prefix(4) == today.prefix(4) ? title : "\(title) \(key.prefix(4))"
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "LLLL"
        return f
    }()

    static func relative(_ key: String, today: String) -> String? {
        switch distance(from: today, to: key) {
        case 0: "HOJE"
        case -1: "ONTEM"
        case 1: "AMANHÃ"
        default: nil
        }
    }

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
}
