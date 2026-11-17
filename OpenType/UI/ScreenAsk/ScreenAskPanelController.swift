import AppKit
import SwiftUI

@MainActor
final class ScreenAskPanelController: ScreenAskPresenting {
    private var panel: ScreenAskPanel?
    private var selection = CGRect.zero
    private var screenFrame = CGRect.zero
    private var layoutID = UUID()
    /// Once the user drags the panel, resizing keeps its top-left corner instead of re-anchoring beside the selection.
    private var userMoved = false
    private var applyingFrame = false
    private var moveObserver: NSObjectProtocol?

    func show(controller: ScreenAskController, beside frame: CGRect) {
        hide()
        userMoved = false
        selection = frame
        screenFrame = (NSScreen.screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) } ?? NSScreen.main)?.visibleFrame ?? frame
        let id = layoutID
        let root = ScreenAskView(controller: controller)
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { [weak self] size in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.layoutID == id else { return }
                    self.resize(size)
                }
            }
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        let panel = ScreenAskPanel(contentRect: CGRect(x: 0, y: 0, width: 332, height: 148),
                                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.configure(level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)) // above the selection overlay
        panel.onCancel = { [weak controller] in controller?.close() }
        panel.contentView = hosting
        panel.isMovableByWindowBackground = true
        moveObserver = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, !self.applyingFrame { self.userMoved = true } }
        }
        self.panel = panel
        resize(CGSize(width: 332, height: 148))
        panel.makeKeyAndOrderFront(nil)
    }

    var windowIDs: [CGWindowID] { panel.map { [CGWindowID($0.windowNumber)] } ?? [] }

    func update(beside frame: CGRect) {
        selection = frame
        guard !userMoved, let panel else { return }
        resize(panel.frame.size)
    }

    func hide() {
        layoutID = UUID()
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        moveObserver = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func resize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard let panel else { return }
        var frame = Self.placement(size: size, selection: selection, screen: screenFrame)
        if userMoved {
            let area = screenFrame.insetBy(dx: 8, dy: 8)
            frame.origin = CGPoint(x: panel.frame.minX, y: panel.frame.maxY - size.height)
            frame.origin.x = min(max(frame.origin.x, area.minX), max(area.minX, area.maxX - size.width))
            frame.origin.y = min(max(frame.origin.y, area.minY), max(area.minY, area.maxY - size.height))
        }
        applyingFrame = true
        panel.setFrame(frame, display: true)
        applyingFrame = false
    }

    static func placement(size: CGSize, selection: CGRect, screen: CGRect) -> CGRect {
        let area = screen.insetBy(dx: 8, dy: 8)
        // View padding provides the separation between the selection and the visible glass.
        var origin = CGPoint(x: selection.maxX, y: selection.midY - size.height / 2)
        if origin.x + size.width > area.maxX {
            if selection.minX - size.width >= area.minX { origin.x = selection.minX - size.width }
            else { origin.x = selection.midX - size.width / 2; origin.y = selection.minY - size.height }
        }
        origin.x = min(max(origin.x, area.minX), max(area.minX, area.maxX - size.width))
        origin.y = min(max(origin.y, area.minY), max(area.minY, area.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }
}
