import SwiftUI

/// Edição inline de uma tarefa: ⏎ salva, esc cancela.
struct TaskEditor: View {
    let isPast: Bool
    let ns: Namespace.ID
    let hub: HubController
    let store: TaskStore

    @State private var draft: GoalTask
    @State private var hasTime: Bool
    @State private var time: Date
    @FocusState private var titleFocused: Bool

    private static let leadOptions = [0, 5, 10, 15, 30, 60]

    init(task: GoalTask, isPast: Bool, ns: Namespace.ID, hub: HubController, store: TaskStore) {
        self.isPast = isPast
        self.ns = ns
        self.hub = hub
        self.store = store
        _draft = State(initialValue: task)
        _hasTime = State(initialValue: task.time != nil)
        _time = State(initialValue: task.time ?? Day.combine(task.day, time: Self.nextHour()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Título", text: $draft.title)
                .font(.system(size: 13, weight: .medium))
                .focused($titleFocused)
                .onSubmit(save)
            TextField("Descrição", text: $draft.notes)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
                .onSubmit(save)

            HStack(spacing: 6) {
                Chip(isOn: hasTime, icon: "clock", text: hasTime ? "Horário" : "Sem horário") {
                    withAnimation(Motion.snappy) {
                        hasTime.toggle()
                        if !hasTime { draft.alert = AlertOptions() }
                    }
                }
                if hasTime {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .fixedSize()
                        .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                    Menu {
                        ForEach(Self.leadOptions, id: \.self) { minutes in
                            Button(Self.leadLabel(minutes)) { draft.alert.leadMinutes = minutes }
                        }
                    } label: {
                        Text(Self.leadLabel(draft.alert.leadMinutes))
                    }
                    .menuStyle(.borderlessButton)
                    .font(.system(size: 11))
                    .fixedSize()
                    .disabled(!draft.alert.isOn)
                    .opacity(draft.alert.isOn ? 1 : 0.4)
                    .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                }
            }

            HStack(spacing: 6) {
                Chip(isOn: draft.alert.notification, icon: "bell", text: "Notificação") {
                    draft.alert.notification.toggle()
                }
                Chip(isOn: draft.alert.pulse, icon: "dot.radiowaves.up.forward", text: "Pulso no notch") {
                    draft.alert.pulse.toggle()
                }
            }
            .disabled(!hasTime)
            .opacity(hasTime ? 1 : 0.4)
            .help(hasTime ? "" : "Defina um horário para usar avisos")

            HStack(spacing: 6) {
                Chip(icon: "trash", text: "Apagar", tint: Theme.red) {
                    withAnimation(Motion.snappy) {
                        hub.editingID = nil
                        store.delete(draft.id)
                    }
                }
                Spacer()
                if isPast {
                    Chip(icon: "arrow.uturn.forward", text: "Copiar p/ hoje") {
                        save()
                        withAnimation(Motion.snappy) { store.carry([draft.id], to: hub.today) }
                    }
                } else {
                    Chip(icon: "arrow.right", text: "Amanhã") {
                        save()
                        withAnimation(Motion.snappy) { store.move(draft.id, to: Day.offset(draft.day, by: 1)) }
                    }
                }
                Chip(text: "Cancelar") { cancel() }
                Chip(isOn: true, text: "Salvar ⏎", action: save)
            }
        }
        .textFieldStyle(.plain)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.row)
                .matchedGeometryEffect(id: draft.id, in: ns)
        }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.blue.opacity(0.35)))
        .onAppear { titleFocused = true }
        .onExitCommand(perform: cancel)
    }

    private func cancel() {
        withAnimation(Motion.snappy) { hub.editingID = nil }
    }

    private func save() {
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.title.isEmpty else { return cancel() }
        task.time = hasTime ? Day.combine(task.day, time: time) : nil
        if !hasTime { task.alert = AlertOptions() }
        withAnimation(Motion.snappy) {
            store.update(task)
            hub.editingID = nil
        }
    }

    private static func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: "na hora"
        case 60: "1 h antes"
        default: "\(minutes) min antes"
        }
    }

    private static func nextHour() -> Date {
        let cal = Calendar.current
        let hour = min(cal.component(.hour, from: Date()) + 1, 23)
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
