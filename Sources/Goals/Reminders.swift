import Foundation
import UserNotifications

/// Notificações do macOS para tarefas com aviso "Notificação".
/// Só funciona rodando como Goals.app (precisa de bundle identifier).
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func start() {
        guard let center else { return }
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func reschedule(_ tasks: [GoalTask]) {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let upcoming = tasks
            .filter { $0.alert.notification && !$0.isDone }
            .compactMap { task in task.alertDate.flatMap { $0 > now ? (task, $0) : nil } }
            .sorted { $0.1 < $1.1 }
            .prefix(60) // o macOS guarda no máximo 64 pendentes

        for (task, fireDate) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = task.title
            var body = task.time.map { "Às \(Day.time($0))" } ?? ""
            if task.alert.leadMinutes > 0 { body += " · em \(task.alert.leadMinutes) min" }
            if !task.notes.isEmpty { body += "\n\(task.notes)" }
            content.body = body
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger))
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
