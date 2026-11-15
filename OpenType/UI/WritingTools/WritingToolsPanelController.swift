import AppKit
import SwiftUI

/// Non-activating floating panel for Writing Tools. The app the text came from stays frontmost (its selection stays
/// put); only the panel's own text fields take the keyboard.
@MainActor
final class WritingToolsPanelController: WritingToolsPresenting {
    private enum Placement { case below, above }

    private var panel: WritingToolsPanel?
    private var toast: NSPanel?
    private var toastTask: Task<Void, Never>?
    private var mouseMonitor: Any?
    private weak var controller: WritingToolsController?
    private var pendingContentSize: CGSize?
    private var placement = Placement.below
    /// Transparent border around the visible card: room for its soft shadow (drawn by the view, not the window).
    private let margin = WritingToolsView.margin

    func show(controller: WritingToolsController) {
        self.controller = controller
        hideToast()
        if panel == nil { buildPanel(controller: controller) }
        guard let panel else { return }
        place(panel)
        panel.makeKeyAndOrderFront(nil) // key (for typing) without activating the app
        installMouseMonitor()
    }

    func hide() {
        removeMouseMonitor()
        panel?.orderOut(nil)
    }

    private func buildPanel(controller: WritingToolsController) {
        // Like the dictation overlay, the window size is driven from the content's reported size, never by the hosting view.
        let hosting = NSHostingView(rootView: WritingToolsView(controller: controller, onContentSizeChange: { [weak self] size in
            MainActor.assumeIsolated { self?.contentSizeChanged(size) }
        }))
        hosting.sizingOptions = []
        let panel = WritingToolsPanel(
            contentRect: NSRect(x: 0, y: 0, width: WritingToolsView.width + 2 * WritingToolsView.margin, height: 320),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // the card draws its own shadow: a window shadow would not follow the rounded corners
        panel.hidesOnDeactivate = false
        panel.isMovable = true // dragged by the card's `WindowDragGesture`
        panel.onCancel = { [weak self] in self?.controller?.close() }
        self.panel = panel
    }

    // MARK: Placement

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
        guard let size = pendingContentSize, let panel else { return }
        pendingContentSize = nil
        let target = NSSize(width: ceil(size.width), height: ceil(size.height))
        guard abs(panel.frame.width - target.width) > 0.5 || abs(panel.frame.height - target.height) > 0.5 else { return }
        var frame = panel.frame
        // Grow away from the selection: below it the top edge stays, above it the bottom edge stays.
        let top = frame.maxY
        frame.size = target
        if placement == .below { frame.origin.y = top - target.height }
        panel.setFrame(clamped(frame), display: true)
    }

    private func screen(for point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// Keeps the visible card (the frame without its shadow margin) inside the screen.
    private func clamped(_ frame: NSRect) -> NSRect {
        guard let visible = screen(for: NSPoint(x: frame.midX, y: frame.midY))?.visibleFrame else { return frame }
        var card = frame.insetBy(dx: margin, dy: margin)
        let area = visible.insetBy(dx: 8, dy: 8)
        card.origin.x = min(max(card.minX, area.minX), max(area.maxX - card.width, area.minX))
        card.origin.y = min(max(card.minY, area.minY), max(area.maxY - card.height, area.minY))
        return card.insetBy(dx: -margin, dy: -margin)
    }

    /// Right under the mouse pointer (above it when there is no room below), on the screen the pointer is on.
    private func place(_ panel: NSPanel) {
        let size = panel.frame.size
        let card = NSSize(width: size.width - 2 * margin, height: size.height - 2 * margin)
        let gap: CGFloat = 14
        let mouse = NSEvent.mouseLocation
        let visible = screen(for: mouse)?.visibleFrame ?? .zero
        var cardOrigin = NSPoint(x: mouse.x - 24, y: mouse.y - gap - card.height)
        placement = .below
        if cardOrigin.y < visible.minY + 8, mouse.y + gap + card.height <= visible.maxY - 8 {
            cardOrigin.y = mouse.y + gap
            placement = .above
        }
        let frame = NSRect(origin: NSPoint(x: cardOrigin.x - margin, y: cardOrigin.y - margin), size: size)
        panel.setFrame(clamped(frame), display: true)
    }

    // MARK: Click outside

    /// A click anywhere else (another window, the desktop) dismisses the panel, like Apple's Writing Tools.
    private func installMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible,
                      !panel.frame.insetBy(dx: self.margin, dy: self.margin).contains(NSEvent.mouseLocation) else { return }
                self.controller?.close()
            }
        }
    }

    private func removeMouseMonitor() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
    }

    // MARK: Toast

    func showToast(message: String, onUndo: @escaping () -> Void) {
        hideToast()
        let hosting = NSHostingView(rootView: WritingToolsToastView(message: message) { [weak self] in
            onUndo()
            self?.hideToast()
        })
        let size = hosting.fittingSize
        let toast = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        toast.contentView = hosting
        toast.isFloatingPanel = true
        toast.level = .floating
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        toast.backgroundColor = .clear
        toast.isOpaque = false
        toast.hasShadow = false
        toast.hidesOnDeactivate = false
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 6)
        toast.setFrame(clamped(NSRect(origin: origin, size: size)), display: true)
        toast.orderFrontRegardless() // never key: the app keeps focus
        self.toast = toast
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.hideToast()
        }
    }

    private func hideToast() {
        toastTask?.cancel()
        toastTask = nil
        toast?.orderOut(nil)
        toast = nil
    }
}

/// Can take the keyboard (the panel's text fields) but is never the main window, and never activates the app.
private final class WritingToolsPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc.
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

private struct WritingToolsToastView: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(message)
            Button("还原", action: onUndo)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .fontWeight(.semibold)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator.opacity(0.5)))
        .background { CardShadow(shape: Capsule(), radius: 8, y: 3, opacity: 0.22) }
        .padding(14) // room for the shadow
    }
}
