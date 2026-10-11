import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = TaskStore()
    private let hub = HubController()
    private let reminders = Reminders()

    private var panel: NotchPanel!
    private var screen: NSScreen?
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!

    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var tickTimer: Timer?
    private var closeWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var peekWork: DispatchWorkItem?
    private var lastPulseCheck = Date()
    private var carryPromptedDay: String?

    /// Janela grande só enquanto aberto; recolhida, ela encolhe para economizar memória de vídeo.
    private let openWindowSize = CGSize(width: 820, height: 520)
    private var closedWindowSize: CGSize { CGSize(width: hub.notch.width + 120, height: hub.notch.height + 24) }

    /// Raio (pt) em que o notch começa a "sentir" o mouse.
    private let proximityRadius: CGFloat = 70

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotchPanel()
        let hosting = HubHostingView(rootView: HubRootView(hub: hub, store: store))
        hosting.sizingOptions = []
        panel.contentView = hosting
        layoutPanel()

        setupStatusItem()

        reminders.start()
        store.onChange = { [weak self] in
            guard let self else { return }
            self.reminders.reschedule(self.store.tasks)
        }
        reminders.reschedule(store.tasks)

        // Mouse por eventos em vez de polling: zero CPU com o mouse parado.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouse() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouse() }
            return event
        }) {
            monitors.append(local)
        }

        // Reavalia o recolhimento quando a edição termina ou o foco vai para outro app.
        hub.$editingID.combineLatest(hub.$isTyping)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleMouse() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: panel)
            .sink { [weak self] _ in self?.handleMouse() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layoutPanel() }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1.5
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Clicar no ícone do Dock (ou abrir o app de novo) mostra o hub.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        peek(seconds: 4)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush(sync: true)
    }

    // MARK: Janela

    private func layoutPanel() {
        guard let builtIn = NotchGeometry.builtInScreen() else {
            screen = nil
            panel.orderOut(nil)
            return
        }
        screen = builtIn
        hub.notch = NotchGeometry.notchSize(on: builtIn)
        setWindowSize(open: hub.isOpen)
        panel.orderFrontRegardless()
    }

    private func setWindowSize(open: Bool) {
        guard let screen else { return }
        let size = open ? openWindowSize : closedWindowSize
        let frame = NSRect(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    private func handleMouse() {
        guard let screen else { return }
        let mouse = NSEvent.mouseLocation
        let top = screen.frame.maxY
        let centerX = screen.frame.midX

        if !hub.isOpen {
            let onScreen = mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.frame.minY && mouse.y <= top
            guard onScreen else { return setProximity(0) }

            let notch = hub.notch
            let dx = max(0, abs(mouse.x - centerX) - notch.width / 2)
            let dy = max(0, (top - notch.height) - mouse.y)
            if dx <= 10 && dy <= 2 { return open() }

            let distance = hypot(dx, dy)
            let raw = max(0, 1 - distance / proximityRadius)
            setProximity((raw * 10).rounded() / 10) // degraus de 0.1: poucas atualizações de view
            return
        }

        let size = hub.openSize
        let flare = HubController.openTopRadius
        let area = NSRect(
            x: centerX - size.width / 2 - flare,
            y: top - size.height,
            width: size.width + flare * 2,
            height: size.height + 4
        ).insetBy(dx: -14, dy: -14)

        if area.contains(mouse) {
            hub.isPeeking = false
            closeWork?.cancel()
            closeWork = nil
            return
        }
        if hub.isPeeking { return }
        // Enquanto edita, só recolhe se você clicou em outro app.
        if hub.isEditing && panel.isKeyWindow { return }
        scheduleClose()
    }

    private func setProximity(_ value: CGFloat) {
        guard value != hub.proximity else { return }
        withAnimation(Motion.magnet) { hub.proximity = value }
    }

    private func open() {
        closeWork?.cancel()
        closeWork = nil
        shrinkWork?.cancel()
        shrinkWork = nil
        setWindowSize(open: true)
        panel.ignoresMouseEvents = false
        withAnimation(Motion.open) {
            hub.proximity = 0
            hub.isOpen = true
        }
    }

    private func scheduleClose() {
        guard closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func close() {
        closeWork = nil
        hub.isPeeking = false
        panel.ignoresMouseEvents = true
        withAnimation(Motion.close) {
            hub.editingID = nil
            hub.isTyping = false
            hub.isOpen = false
        }
        hub.selectedDay = hub.today
        if panel.isKeyWindow {
            // Devolve o teclado ao app que estava em uso.
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        // Encolhe a janela depois que a animação de fechar termina.
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.hub.isOpen else { return }
                self.setWindowSize(open: false)
                self.handleMouse()
                // Devolve ao sistema a memória que o painel aberto usou e já liberou.
                malloc_zone_pressure_relief(nil, 0)
            }
        }
        shrinkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// Abre o hub sozinho por alguns segundos (aviso "pulso").
    private func peek(seconds: Double = 4) {
        guard screen != nil, !hub.isOpen else { return }
        hub.isPeeking = true
        open()
        // Brilho na borda depois que o painel terminou de descer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            MainActor.assumeIsolated { self?.hub.glow += 1 }
        }
        peekWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.hub.isPeeking = false
                self?.handleMouse()
            }
        }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: Relógio

    private func tick() {
        let now = Date()
        let today = Day.today

        if today != hub.today {
            let wasOnToday = hub.selectedDay == hub.today
            hub.today = today
            if wasOnToday { hub.selectedDay = today }
        }

        let pulseDue = store.tasks(on: today).contains { task in
            guard task.alert.pulse, !task.isDone, let at = task.alertDate else { return false }
            return at > lastPulseCheck && at <= now
        }
        lastPulseCheck = now
        if pulseDue { peek(seconds: 5) }

        // Pergunta sobre pendentes uma vez por dia.
        if carryPromptedDay != today, store.pendingCarryOver(today: today) != nil {
            carryPromptedDay = today
            peek(seconds: 6)
        }
    }

    // MARK: Barra de menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Goals")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Mostrar hub", action: #selector(showHub), keyEquivalent: "").target = self
        menu.addItem(.separator())
        loginItem = menu.addItem(withTitle: "Abrir ao iniciar sessão", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(withTitle: "Mostrar dados no Finder", action: #selector(revealData), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair do Goals", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            loginItem.state = AppActions.opensAtLogin ? .on : .off
        }
    }

    @objc private func showHub() { peek(seconds: 4) }
    @objc private func toggleLogin() { AppActions.toggleOpenAtLogin() }
    @objc private func revealData() { AppActions.revealData() }
}
