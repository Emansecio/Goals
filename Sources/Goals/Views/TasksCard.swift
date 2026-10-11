import SwiftUI

struct TasksCard: View {
    @ObservedObject var hub: HubController
    @ObservedObject var store: TaskStore
    var appeared: Bool

    @Namespace private var ns
    @State private var newTitle = ""
    @FocusState private var addFocused: Bool
    @AppStorage(AppActions.reviewHourKey) private var reviewHour = 21

    var body: some View {
        let day = hub.selectedDay
        let isPast = day < hub.today
        let isToday = day == hub.today
        let carry = isToday ? store.pendingCarryOver(today: hub.today) : nil
        let review = isToday && carry == nil ? store.openForReview(today: hub.today, hour: reviewHour) : nil
        let quick = QuickEntry.parse(newTitle, today: hub.today)
        let hint = quick.hint(today: hub.today)
        let forward = hub.navDirection > 0

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                Text("Tarefas")
                Spacer()
                if isPast {
                    Text("revisão")
                        .foregroundStyle(Theme.muted)
                        .font(.system(size: 11))
                        .transition(.opacity.combined(with: .offset(x: 6)))
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.top, 2)

            if let carry {
                let from = Day.distance(from: hub.today, to: carry.day) == -1 ? "ontem" : Day.label(carry.day).lowercased()
                ActionBanner(
                    icon: "arrow.uturn.forward.circle.fill",
                    text: "\(carry.tasks.count) \(carry.tasks.count == 1 ? "pendente" : "pendentes") de \(from)",
                    action: "Mover p/ hoje",
                    tint: Theme.orange,
                    textColor: Color(red: 1, green: 0.8, blue: 0.5)
                ) {
                    Haptics.tap()
                    withAnimation(Motion.snappy) { store.carry(carry.tasks.map(\.id), to: hub.today) }
                } onDismiss: {
                    withAnimation(Motion.snappy) { store.dismissCarryOver(carry.day) }
                }
                .transition(Self.bannerTransition)
            } else if let review {
                ActionBanner(
                    icon: "moon.stars.fill",
                    text: "Fim do dia · \(review.count) \(review.count == 1 ? "aberta" : "abertas")",
                    action: "Mover p/ amanhã",
                    tint: Theme.blue,
                    textColor: Color(red: 0.62, green: 0.78, blue: 1)
                ) {
                    Haptics.tap()
                    withAnimation(Motion.snappy) { store.carry(review.map(\.id), to: Day.offset(hub.today, by: 1)) }
                } onDismiss: {
                    withAnimation(Motion.snappy) { store.dismissCarryOver(hub.today) }
                }
                .transition(Self.bannerTransition)
            }

            // A lista inteira desliza para o lado ao trocar de dia.
            ZStack(alignment: .top) {
                TaskList(
                    day: day,
                    items: store.tasks(on: day),
                    isPast: isPast,
                    editingID: hub.editingID,
                    appeared: appeared,
                    ns: ns,
                    hub: hub,
                    store: store
                )
                .id(day)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(addFocused ? 90 : 0))
                    .foregroundStyle(addFocused ? Theme.blue : Theme.muted)
                TextField("Adicionar tarefa", text: $newTitle)
                    .textFieldStyle(.plain)
                    .focused($addFocused)
                    .onSubmit { add(quick) }
                    .onExitCommand { addFocused = false }
                // Prévia do dia/horário entendido no texto ("amanhã 15h" → Amanhã · 15:00).
                if let hint {
                    Label(hint, systemImage: "clock")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.blue.opacity(0.16)))
                        .fixedSize()
                        .transition(.scale(scale: 0.7, anchor: .trailing).combined(with: .opacity))
                }
            }
            .animation(Motion.snappy, value: hint)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(addFocused ? 0.06 : 0))
            )
            .animation(Motion.snappy, value: addFocused)
            .reveal(appeared, delay: 0.06, offset: -4, blur: 0)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .animation(Motion.snappy, value: isPast)
        .onChange(of: addFocused) { _, focused in hub.isTyping = focused }
        .onChange(of: hub.isOpen) { _, open in
            if !open { newTitle = "" }
        }
    }

    private static let bannerTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
    )

    private func add(_ entry: QuickEntry) {
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let time = entry.hour.flatMap { Calendar.current.date(bySettingHour: $0, minute: entry.minute, second: 0, of: Date()) }
        withAnimation(Motion.snappy) { _ = store.add(title: title, on: entry.day ?? hub.selectedDay, time: time) }
        newTitle = ""
        addFocused = true
    }
}

private struct TaskList: View {
    let day: String
    let items: [GoalTask]
    let isPast: Bool
    let editingID: UUID?
    let appeared: Bool
    let ns: Namespace.ID
    let hub: HubController
    let store: TaskStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                if items.isEmpty {
                    Text(isPast ? "Nenhuma tarefa neste dia." : "Nada planejado ainda.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .transition(.opacity)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                    Group {
                        if editingID == task.id {
                            TaskEditor(task: task, isPast: isPast, ns: ns, hub: hub, store: store)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        } else {
                            TaskRow(
                                task: task,
                                isPast: isPast,
                                ns: ns,
                                onToggle: {
                                    Haptics.tap()
                                    withAnimation(Motion.snappy) { store.toggle(task.id) }
                                },
                                onEdit: {
                                    withAnimation(Motion.snappy) { hub.editingID = task.id }
                                },
                                onPin: {
                                    Haptics.tap()
                                    withAnimation(Motion.snappy) { store.togglePin(task.id) }
                                },
                                onDropBefore: { dragged in
                                    Haptics.tap()
                                    withAnimation(Motion.snappy) { store.reorder(dragged, before: task.id) }
                                }
                            )
                            .equatable()
                            .transition(.opacity)
                        }
                    }
                    .reveal(appeared, delay: 0.03 + Double(min(index, 8)) * 0.02, offset: -6, blur: 0)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -6)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(.vertical, 1)
        }
    }
}

/// Faixa de aviso no topo da lista (pendentes de ontem, revisão do fim do dia).
private struct ActionBanner: View {
    let icon: String
    let text: String
    let action: String
    let tint: Color
    let textColor: Color
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .symbolEffect(.bounce, options: .nonRepeating, value: text)
            Text(text)
                .contentTransition(.numericText())
            Spacer()
            Button("Ignorar", action: onDismiss)
                .buttonStyle(PressableStyle())
                .foregroundStyle(Theme.muted)
            Button(action: onAction) {
                Text(action)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(tint.opacity(0.22)))
            }
            .buttonStyle(PressableStyle())
        }
        .font(.system(size: 11.5))
        .foregroundStyle(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12)))
    }
}

struct CheckCircle: View {
    var done: Bool
    var missed: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(missed ? Theme.red.opacity(0.7) : Color(white: 0.36), lineWidth: 1.5)
            Circle()
                .fill(Theme.blue)
                .scaleEffect(done ? 1 : 0.2)
                .opacity(done ? 1 : 0)
            CheckmarkShape()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 7)
                .animation(.easeOut(duration: 0.2).delay(done ? 0.08 : 0), value: done)
            if missed {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.red.opacity(0.8))
            }
        }
        .frame(width: 20, height: 20)
        // Onda que se expande ao concluir.
        .background {
            Circle()
                .stroke(Theme.blue, lineWidth: 2)
                .keyframeAnimator(initialValue: Burst(), trigger: done) { ring, burst in
                    ring.scaleEffect(burst.scale).opacity(done ? burst.opacity : 0)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1, duration: 0.01)
                        CubicKeyframe(1.9, duration: 0.45)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.7, duration: 0.01)
                        CubicKeyframe(0, duration: 0.45)
                    }
                }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: done)
        .contentShape(Circle())
    }

    private struct Burst {
        var scale = 1.0
        var opacity = 0.0
    }
}

struct TaskRow: View, Equatable {
    let task: GoalTask
    let isPast: Bool
    let ns: Namespace.ID
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onPin: () -> Void
    /// Outra tarefa foi solta em cima desta: vai para antes dela.
    let onDropBefore: (UUID) -> Void

    @State private var hovering = false
    @State private var dropTargeted = false

    // Só redesenha a linha quando a própria tarefa muda.
    static func == (a: TaskRow, b: TaskRow) -> Bool {
        a.task == b.task && a.isPast == b.isPast
    }

    private var isLate: Bool {
        guard let time = task.time, !task.isDone, !isPast else { return false }
        return time < Date()
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                CheckCircle(done: task.isDone, missed: isPast && !task.isDone)
            }
            .buttonStyle(PressableStyle())

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(task.isDone ? Theme.muted : .white)
                    // Risco que "corre" da esquerda para a direita.
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.muted)
                            .frame(height: 1.2)
                            .scaleEffect(x: task.isDone ? 1 : 0, anchor: .leading)
                    }
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
            .lineLimit(1)
            .animation(.easeOut(duration: 0.28), value: task.isDone)

            Spacer(minLength: 4)

            if task.carriedTo != nil {
                Label("movida", systemImage: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .transition(.opacity.combined(with: .offset(x: 6)))
            }
            if let time = task.time {
                HStack(spacing: 4) {
                    if task.alert.isOn {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                            .symbolEffect(.bounce, options: .nonRepeating, value: hovering)
                    }
                    Text(Day.time(time))
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(isLate ? Theme.orange : Theme.muted)
            }

            // Estrela: aparece no hover; fixa a tarefa no topo do dia.
            Button(action: onPin) {
                Image(systemName: task.isPinned ? "star.fill" : "star")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(task.isPinned ? Theme.orange : Theme.muted)
                    .symbolEffect(.bounce, options: .nonRepeating, value: task.isPinned)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .opacity(task.isPinned || hovering ? 1 : 0)
            .help(task.isPinned ? "Desafixar" : "Fixar no topo")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering ? Theme.rowHover : Theme.row)
                .matchedGeometryEffect(id: task.id, in: ns)
        }
        // Linha azul indicando onde a tarefa arrastada vai entrar.
        .overlay(alignment: .top) {
            Capsule()
                .fill(Theme.blue)
                .frame(height: 2.5)
                .padding(.horizontal, 8)
                .offset(y: -4.5)
                .opacity(dropTargeted ? 1 : 0)
                .scaleEffect(x: dropTargeted ? 1 : 0.4)
        }
        .scaleEffect(hovering ? 1.01 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.16), value: hovering)
        .animation(Motion.snappy, value: dropTargeted)
        .onTapGesture(perform: onEdit)
        .draggable(task.id.uuidString) {
            DragChip(title: task.title)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)), id != task.id else { return false }
            onDropBefore(id)
            return true
        } isTargeted: { dropTargeted = $0 }
    }
}

/// Prévia compacta da tarefa enquanto é arrastada.
struct DragChip: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "checklist")
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.blue))
    }
}
