import Foundation

/// Lê dia e horário escritos no título: "Ligar pro contador amanhã 15h",
/// "Reunião sex 14:30", "Treino às 7h", "Pagar boleto quinta".
struct QuickEntry: Equatable {
    var title: String
    var day: String?
    var hour: Int?
    var minute = 0

    /// Resumo para o chip de prévia: "Amanhã · 15:00".
    func hint(today: String) -> String? {
        var parts: [String] = []
        if let day {
            parts.append(Day.relative(day, today: today).map { $0.prefix(1) + $0.dropFirst().lowercased() } ?? Day.label(day))
        }
        if let hour { parts.append(String(format: "%02d:%02d", hour, minute)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // "15h", "15h30", "15:30", com "às"/"as"/"a" opcional antes.
    private static let timeRegex = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\d])(?:[àa]s?\s+)?([01]?\d|2[0-3])(?:h([0-5]\d)?|:([0-5]\d))(?![\p{L}\d])"#,
        options: [.caseInsensitive]
    )
    // Dias por extenso (sempre) e abreviados (só junto de um horário, para "ter que…" não virar terça).
    private static let dayRegex = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\d])(depois de amanh[aã]|amanh[aã]|hoje|segunda|ter[cç]a|quarta|quinta|sexta|s[aá]bado|domingo|seg|ter|qua|qui|sex|s[aá]b|dom)(?:-feira)?(?![\p{L}\d])"#,
        options: [.caseInsensitive]
    )
    private static let shortDays: Set<String> = ["seg", "ter", "qua", "qui", "sex", "sab", "sáb", "dom"]
    private static let weekdays: [String: Int] = [
        "dom": 1, "seg": 2, "ter": 3, "qua": 4, "qui": 5, "sex": 6, "sab": 7, "sáb": 7,
    ]

    static func parse(_ text: String, today: String) -> QuickEntry {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var entry = QuickEntry(title: text)
        var remove: [NSRange] = []

        if let m = timeRegex.firstMatch(in: text, range: whole) {
            entry.hour = Int(ns.substring(with: m.range(at: 1)))
            for group in [2, 3] where m.range(at: group).location != NSNotFound {
                entry.minute = Int(ns.substring(with: m.range(at: group))) ?? 0
            }
            remove.append(m.range)
        }

        if let m = dayRegex.firstMatch(in: text, range: whole) {
            let word = ns.substring(with: m.range(at: 1)).lowercased()
            if !shortDays.contains(word) || entry.hour != nil, let offset = dayOffset(word, today: today) {
                entry.day = Day.offset(today, by: offset)
                remove.append(m.range)
            }
        }

        guard !remove.isEmpty else { return entry }
        let stripped = NSMutableString(string: text)
        for range in remove.sorted(by: { $0.location > $1.location }) {
            stripped.replaceCharacters(in: range, with: " ")
        }
        let title = (stripped as String)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,-–·"))
        // Se só sobrou data/hora, mantém o texto como título.
        guard !title.isEmpty else { return QuickEntry(title: text) }
        entry.title = title.prefix(1).uppercased() + title.dropFirst()
        return entry
    }

    private static func dayOffset(_ word: String, today: String) -> Int? {
        if word == "hoje" { return 0 }
        if word.hasPrefix("depois") { return 2 }
        if word.hasPrefix("amanh") { return 1 }
        guard let target = weekdays[String(word.prefix(3))] else { return nil }
        let current = Calendar.current.component(.weekday, from: Day.date(today))
        return (target - current + 7) % 7 // 0 = hoje mesmo
    }
}
