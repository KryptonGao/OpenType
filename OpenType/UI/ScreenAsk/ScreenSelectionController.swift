import AppKit
import ScreenCaptureKit

/// Dims the live screen while the user drags a region; the pixels are captured only after the drag ends.
/// Nothing is frozen up front, so windows keep their shadows and nothing visibly jumps when the shortcut is pressed.
/// The dimming panels are excluded from the capture, so neither the dimming nor the border enter the crop.
@MainActor
final class ScreenSelectionController {
    private var panels: [(panel: ScreenAskPanel, screen: NSScreen)] = []
    private var generation = UUID()
    var onSelect: ((ScreenRegion) -> Void)?
    var onCancel: (() -> Void)?
    var onFailure: ((Error) -> Void)?

    func begin() async throws {
        hide()
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw LLMError.invalidConfig(String(localized: "请在「系统设置 → 隐私与安全性 → 屏幕与系统音频录制」中允许 OpenType，然后重试。"))
        }
        guard !NSScreen.screens.isEmpty else { throw CancellationError() }
        for screen in NSScreen.screens {
            let panel = ScreenAskPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            // Above the Dock and menu bar (they sit at levels 20 / 24), so the overlay dims and receives clicks over them too.
            panel.configure(level: .screenSaver)
            panel.animationBehavior = .none
            let view = ScreenSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onSelect = { [weak self] rect in self?.finish(selection: rect, on: screen) }
            panel.onCancel = { [weak self] in self?.onCancel?() }
            panel.contentView = view
            panel.acceptsMouseMovedEvents = true
            panel.alphaValue = 0
            panels.append((panel, screen))
            panel.orderFrontRegardless()
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.12
            panel.animator().alphaValue = 1
            NSAnimationContext.endGrouping()
        }
        let mouse = NSEvent.mouseLocation
        let active = panels.first { $0.panel.frame.contains(mouse) } ?? panels.first
        active?.panel.makeKey()
        active?.panel.makeFirstResponder(active?.panel.contentView)
    }

    /// Window ids to leave out of every capture besides the dimming panels (the question panel beside the selection).
    var extraExcludedWindows: () -> [CGWindowID] = { [] }
    private var captureSequence = 0

    /// Called after each completed drag: the first one, and every adjustment of the box afterwards.
    private func finish(selection rect: CGRect, on screen: NSScreen) {
        // Only one screen holds a selection at a time.
        for entry in panels where entry.screen != screen { (entry.panel.contentView as? ScreenSelectionView)?.clear() }
        let token = generation
        captureSequence += 1
        let sequence = captureSequence
        let excluded = Set(panels.map { CGWindowID($0.panel.windowNumber) }).union(extraExcludedWindows())
        Task { [weak self] in
            do {
                let image = try await Self.capture(screen: screen, excluding: excluded)
                // A newer adjustment (or closing) supersedes this capture.
                guard let self, token == self.generation, sequence == self.captureSequence else { return }
                let pixelRect = ScreenRegion.pixelRect(selection: rect, viewSize: screen.frame.size,
                                                       imageSize: CGSize(width: image.width, height: image.height))
                guard let crop = image.cropping(to: pixelRect) else { throw LLMError.badResponse(String(localized: "无法处理所选图片")) }
                self.onSelect?(ScreenRegion(image: crop, frame: rect.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY)))
            } catch {
                guard let self, token == self.generation, sequence == self.captureSequence else { return }
                self.onFailure?(error)
            }
        }
    }

    private static func capture(screen: NSScreen, excluding excluded: Set<CGWindowID>) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == id }) else { throw CancellationError() }
        let filter = SCContentFilter(display: display, excludingWindows: content.windows.filter { excluded.contains($0.windowID) })
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    func hide() {
        generation = UUID()
        panels.forEach { $0.panel.orderOut(nil) }
        panels.removeAll()
    }
}

final class ScreenAskPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    func configure(level: NSWindow.Level) {
        isFloatingPanel = true // resets `level` to .floating, so the requested level must be set after it
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
    }
}

private final class ScreenSelectionView: NSView {
    private enum Drag {
        case new(start: CGPoint, previous: CGRect)
        case move(from: CGPoint, original: CGRect)
        case resize(SelectionHandle, original: CGRect)
    }

    var onSelect: ((CGRect) -> Void)?
    private var drag: Drag?
    private var selection: CGRect = .zero
    private var notified: CGRect = .zero
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func clear() {
        selection = .zero
        notified = .zero
        drag = nil
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self))
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private func cursor(at point: CGPoint) -> NSCursor {
        if let handle = SelectionGeometry.hit(point, in: selection) { return Self.cursor(for: handle) }
        return selection.contains(point) ? .openHand : .crosshair
    }

    private static func cursor(for handle: SelectionHandle) -> NSCursor {
        let position: NSCursor.FrameResizePosition = switch handle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        }
        return .frameResize(position: position, directions: .all)
    }

    override func mouseMoved(with event: NSEvent) {
        cursor(at: convert(event.locationInWindow, from: nil)).set()
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if !selection.isEmpty { dim.appendRect(selection) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.38).setFill()
        dim.fill()
        guard !selection.isEmpty else {
            let hint = String(localized: "拖动以选取屏幕区域 · Esc 取消")
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17, weight: .medium), .foregroundColor: NSColor.white]
            let size = hint.size(withAttributes: attributes)
            hint.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 100), withAttributes: attributes)
            return
        }
        // Nearly invisible, but keeps the window server routing clicks inside the selection to this panel.
        NSColor.black.withAlphaComponent(0.01).setFill()
        NSBezierPath(rect: selection).fill()
        // Black dashes over a white line read on any background.
        let border = NSBezierPath(rect: selection)
        border.lineWidth = 1.5
        NSColor.white.setStroke()
        border.stroke()
        border.setLineDash([5, 4], count: 2, phase: 0)
        NSColor.black.setStroke()
        border.stroke()
        for handle in SelectionHandle.allCases {
            let c = SelectionGeometry.point(of: handle, in: selection)
            let dot = NSBezierPath(ovalIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
            NSColor(white: 0.62, alpha: 1).setFill()
            dot.fill()
            dot.lineWidth = 1.5
            NSColor(white: 0.93, alpha: 1).setStroke()
            dot.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let handle = SelectionGeometry.hit(point, in: selection) {
            drag = .resize(handle, original: selection)
        } else if selection.contains(point) {
            drag = .move(from: point, original: selection)
            NSCursor.closedHand.set()
        } else {
            drag = .new(start: point, previous: selection)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch drag {
        case .new(let start, _):
            // The previous box stays until the drag really starts.
            guard hypot(point.x - start.x, point.y - start.y) >= 3 || !selection.isEmpty else { return }
            selection = SelectionGeometry.rect(from: start, to: point, within: bounds)
        case .move(let from, let original):
            selection = SelectionGeometry.move(original, by: CGSize(width: point.x - from.x, height: point.y - from.y), within: bounds)
        case .resize(let handle, let original):
            selection = SelectionGeometry.resize(original, handle: handle, to: point, within: bounds)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let current = drag else { return }
        mouseDragged(with: event)
        drag = nil
        // Too small (a click, or a box squeezed shut): fall back to the box that was there before.
        if selection.width < SelectionGeometry.minimumSide || selection.height < SelectionGeometry.minimumSide {
            switch current {
            case .new(_, let previous): selection = previous
            case .move(_, let original), .resize(_, let original): selection = original
            }
            needsDisplay = true
        }
        cursor(at: convert(event.locationInWindow, from: nil)).set()
        guard selection.width >= SelectionGeometry.minimumSide, selection.height >= SelectionGeometry.minimumSide,
              selection != notified else { return }
        notified = selection
        onSelect?(selection)
    }
}
