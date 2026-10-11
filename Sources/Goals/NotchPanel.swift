import AppKit
import SwiftUI

/// Janela transparente, sem borda, acima da barra de menus e presente em todos os Spaces.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Permite posicionar a janela sobre a barra de menus.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Aceita o primeiro clique mesmo com o painel fora de foco.
final class HubHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

enum NotchGeometry {
    /// Tela interna do MacBook (onde fica o notch).
    static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    static func notchSize(on screen: NSScreen) -> CGSize {
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return CGSize(width: width, height: max(screen.safeAreaInsets.top, menuBarHeight))
        }
        // Tela sem notch: uma "ilha" falsa no centro.
        return CGSize(width: 185, height: menuBarHeight)
    }
}
