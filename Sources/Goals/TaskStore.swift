import Foundation

/// Guarda as tarefas em ~/Library/Application Support/Goals/tasks.json.
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [GoalTask] = [] {
        didSet { reindex() }
    }
    @Published private(set) var dismissedCarryOver: Set<String> = []

    /// Chamado depois que as alterações são salvas (usado para reagendar notificações).
    var onChange: (() -> Void)?

    let folderURL: URL
    private let fileURL: URL

    // Índices recalculados só quando `tasks` muda, para as views lerem em O(1).
    private var byDay: [String: [GoalTask]] = [:]
    private var summaries: [String: (done: Int, total: Int)] = [:]
    private var streakMemo: (today: String, value: Int)?

    private var saveWork: DispatchWorkItem?
    private static let ioQueue = DispatchQueue(label: "goals.io", qos: .utility)
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private struct Snapshot: Codable {
        var tasks: [GoalTask]
        var dismissedCarryOver: [String]
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folderURL = support.appendingPathComponent("Goals", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("tasks.json")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: Leitura

    func tasks(on day: String) -> [GoalTask] { byDay[day] ?? [] }

    func progress(on day: String) -> (done: Int, total: Int) { summaries[day] ?? (0, 0) }

    /// 0 = nada feito / sem tarefas, 1 = menos da metade, 2 = metade ou mais, 3 = tudo.
    func level(on day: String) -> Int {
        let p = progress(on: day)
        guard p.total > 0, p.done > 0 else { return 0 }
        if p.done == p.total { return 3 }
        return p.done * 2 >= p.total ? 2 : 1
    }

    /// Dias seguidos com tudo feito. Dias sem tarefas não contam nem quebram;
    /// hoje só entra quando já estiver completo.
    func streak(today: String) -> Int {
        if let memo = streakMemo, memo.today == today { return memo.value }
        var count = 0
        var date = Day.date(today)
        let oldest = summaries.keys.min() ?? today
        while true {
            let day = Day.key(date)
            if day < oldest { break }
            let p = progress(on: day)
            if p.total > 0 {
                if p.done == p.total {
                    count += 1
                } else if day != today {
                    break
                }
            }
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        streakMemo = (today, count)
        return count
    }

    /// Pendentes do último dia (até 7 dias atrás) que teve tarefas, ainda não movidas nem ignoradas.
    func pendingCarryOver(today: String) -> (day: String, tasks: [GoalTask])? {
        for back in 1...7 {
            let day = Day.offset(today, by: -back)
            let items = tasks(on: day)
            guard !items.isEmpty else { continue }
            let open = items.filter { !$0.isDone && $0.carriedTo == nil }
            if open.isEmpty || dismissedCarryOver.contains(day) { return nil }
            return (day, open)
        }
        return nil
    }

    // MARK: Escrita

    @discardableResult
    func add(title: String, on day: String) -> GoalTask {
        let task = GoalTask(day: day, title: title)
        tasks.append(task)
        persist()
        return task
    }

    func update(_ task: GoalTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }), tasks[i] != task else { return }
        tasks[i] = task
        persist()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    func toggle(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isDone.toggle()
        persist()
    }

    /// Muda a tarefa de dia, mantendo o horário.
    func move(_ id: UUID, to day: String) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        var task = tasks[i]
        task.day = day
        if let t = task.time { task.time = Day.combine(day, time: t) }
        tasks[i] = task
        persist()
    }

    /// Copia tarefas para outro dia. O original continua registrado como não feito.
    func carry(_ ids: [UUID], to day: String) {
        var updated = tasks
        for id in ids {
            guard let i = updated.firstIndex(where: { $0.id == id }) else { continue }
            var copy = updated[i]
            copy.id = UUID()
            copy.day = day
            copy.isDone = false
            copy.carriedFrom = updated[i].day
            copy.carriedTo = nil
            copy.createdAt = Date()
            if let t = copy.time { copy.time = Day.combine(day, time: t) }
            updated[i].carriedTo = day
            updated.append(copy)
        }
        tasks = updated
        persist()
    }

    func dismissCarryOver(_ day: String) {
        dismissedCarryOver.insert(day)
        persist()
    }

    // MARK: Índices

    private func reindex() {
        var groups: [String: [GoalTask]] = [:]
        for task in tasks { groups[task.day, default: []].append(task) }
        var sums: [String: (Int, Int)] = [:]
        for (day, items) in groups {
            groups[day] = items.sorted(by: Self.order)
            sums[day] = (items.lazy.filter(\.isDone).count, items.count)
        }
        byDay = groups
        summaries = sums
        streakMemo = nil
    }

    private static func order(_ a: GoalTask, _ b: GoalTask) -> Bool {
        switch (a.time, b.time) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.createdAt < b.createdAt
        }
    }

    // MARK: Disco

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data) else { return }
        tasks = snapshot.tasks
        dismissedCarryOver = Set(snapshot.dismissedCarryOver)
    }

    /// Agrupa alterações seguidas num único salvamento, feito fora da thread principal.
    private func persist() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.flush() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Grava agora. `sync` é usado ao sair do app.
    func flush(sync: Bool = false) {
        guard let work = saveWork else { return }
        work.cancel()
        saveWork = nil
        let snapshot = Snapshot(tasks: tasks, dismissedCarryOver: dismissedCarryOver.sorted())
        guard let data = try? Self.encoder.encode(snapshot) else { return }
        let url = fileURL
        if sync {
            try? data.write(to: url, options: .atomic)
        } else {
            Self.ioQueue.async { try? data.write(to: url, options: .atomic) }
        }
        onChange?()
    }
}
