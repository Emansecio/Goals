import AppKit
import ServiceManagement

/// Ações do app usadas tanto pela barra de menus quanto pelo menu "⋯" do hub.
@MainActor
enum AppActions {
    static var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// Hora da revisão do fim do dia (0 = desligada). Padrão: 21h.
    static let reviewHourKey = "reviewHour"
    static var reviewHour: Int { UserDefaults.standard.integer(forKey: reviewHourKey) }

    static func toggleOpenAtLogin() {
        do {
            if opensAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Não foi possível alterar o início automático"
            alert.informativeText = "\(error.localizedDescription)\n\nDica: instale com ./scripts/build-app.sh --install e abra pelo /Applications."
            alert.runModal()
        }
    }

    static func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([TaskStore.defaultFolder])
    }

    static func quit() {
        NSApp.terminate(nil)
    }
}
