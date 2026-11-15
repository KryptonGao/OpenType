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
    private var anchor: CGRect?

    func show(controller: WritingToolsController, anchor: CGRect?) {
        self.controller = controller
        self.anchor = anchor
        hideToast()
        if panel == nil { buildPanel(controller: controller) }
        guard let panel else { return }
        place(panel, initial: true)
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
            contentRect: NSRect(x: 0, y: 0, width: WritingToolsView.width, height: 320),
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
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
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

    private func clamped(_ frame: NSRect) -> NSRect {
        guard let visible = screen(for: NSPoint(x: frame.midX, y: frame.midY))?.visibleFrame else { return frame }
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX + 8), max(visible.maxX - result.width - 8, visible.minX + 8))
        result.origin.y = min(max(result.minY, visible.minY + 8), max(visible.maxY - result.height - 8, visible.minY + 8))
        return result
    }

    /// Below the selection when there is room, above it otherwise; next to the mouse when its position is unknown.
    private func place(_ panel: NSPanel, initial: Bool) {
        let size = panel.frame.size
        let gap: CGFloat = 10
        var origin: NSPoint
        if let anchor {
            let visible = screen(for: NSPoint(x: anchor.midX, y: anchor.midY))?.visibleFrame ?? .zero
            origin = NSPoint(x: anchor.minX, y: anchor.minY - gap - size.height)
            placement = .below
            if origin.y < visible.minY + 8, anchor.maxY + gap + size.height <= visible.maxY {
                origin.y = anchor.maxY + gap
                placement = .above
            }
        } else {
            let mouse = NSEvent.mouseLocation
            origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 14)
            placement = .below
        }
        panel.setFrame(clamped(NSRect(origin: origin, size: size)), display: true)
    }

    // MARK: Click outside

    /// A click anywhere else (another window, the desktop) dismisses the panel, like Apple's Writing Tools.
    private func installMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible,
                      !panel.frame.contains(NSEvent.mouseLocation) else { return }
                self.controller?.close()
            }
        }
    }

    private func removeMouseMonitor() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
    }

    // MARK: Toast

    func showToast(message: String, anchor: CGRect?, onUndo: @escaping () -> Void) {
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
        toast.hasShadow = true
        toast.hidesOnDeactivate = false
        let point = anchor.map { NSPoint(x: $0.minX, y: $0.minY - 12 - size.height) } ?? NSPoint(x: NSEvent.mouseLocation.x - size.width / 2, y: NSEvent.mouseLocation.y - size.height - 14)
        toast.setFrame(clamped(NSRect(origin: point, size: size)), display: true)
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
        .glassEffect(.regular, in: Capsule())
        .padding(10) // room for the shadow
    }
}
