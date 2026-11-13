import AppKit
import SwiftUI

/// Non-activating floating NSPanel that shows live dictation feedback without stealing focus.
@MainActor
final class OverlayPanelController: OverlayPresenting {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<OverlayView>?
    private var resizeObserver: NSObjectProtocol?
    private weak var settings: SettingsStore?

    func show(coordinator: DictationSessionCoordinator) {
        settings = coordinator.settingsStore
        if panel == nil { buildPanel(coordinator: coordinator) }
        reposition()
        panel?.orderFrontRegardless() // never makeKey: the target app keeps focus
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel(coordinator: DictationSessionCoordinator) {
        let controller = NSHostingController(rootView: OverlayView(coordinator: coordinator))
        controller.sizingOptions = [.preferredContentSize]
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 436, height: 80),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = controller
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        self.panel = panel
        self.hostingController = controller
        // Content height changes with the transcript: keep the panel anchored to its edge.
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Screen under the mouse cursor (works for multi-display and full-screen spaces).
    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func reposition() {
        guard let panel, let screen = targetScreen() else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let y: CGFloat = switch settings?.overlayPosition ?? .bottomCenter {
        case .bottomCenter: frame.minY + 40
        case .topCenter: frame.maxY - size.height - 40
        }
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: y))
    }
}

/// Panel that can receive clicks (copy / close buttons) but never becomes the key or main window.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
