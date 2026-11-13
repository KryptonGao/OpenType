import AppKit
import SwiftUI

/// Non-activating floating NSPanel that shows live dictation feedback without stealing focus.
@MainActor
final class OverlayPanelController: OverlayPresenting {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?
    private var pendingContentSize: CGSize?
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
        // The window size is deliberately NOT driven by the hosting view (`sizingOptions = []`): letting SwiftUI resize the
        // window from inside its own layout pass could recurse until the stack overflowed (crash when translating).
        let hosting = NSHostingView(rootView: OverlayView(coordinator: coordinator, onContentSizeChange: { [weak self] size in
            MainActor.assumeIsolated { self?.contentSizeChanged(size) }
        }))
        hosting.sizingOptions = []
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 436, height: 80),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
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
        self.hostingView = hosting
    }

    /// Content height changes with the transcript: resize on the next run-loop turn (never inside a layout pass) and
    /// keep the panel anchored to its edge.
    private func contentSizeChanged(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let alreadyScheduled = pendingContentSize != nil
        pendingContentSize = size
        guard !alreadyScheduled else { return }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.applyPendingContentSize() }
        }
    }

    private func applyPendingContentSize() {
        guard let size = pendingContentSize else { return }
        pendingContentSize = nil
        guard let panel else { return }
        let target = NSSize(width: ceil(size.width), height: ceil(size.height))
        if abs(panel.contentLayoutRect.width - target.width) > 0.5 || abs(panel.contentLayoutRect.height - target.height) > 0.5 {
            panel.setContentSize(target)
        }
        reposition()
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
