import CoreGraphics

/// The eight grips of an adjustable selection box.
enum SelectionHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

/// Hit-testing and editing math for the screen selection box. Coordinates are AppKit's (origin bottom-left, so "top" is `maxY`).
enum SelectionGeometry {
    static let minimumSide: CGFloat = 8

    static func point(of handle: SelectionHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .top: CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom: CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    /// The grip under `p`: a corner or edge-midpoint dot first, otherwise anywhere along an edge.
    static func hit(_ p: CGPoint, in rect: CGRect, tolerance: CGFloat = 9) -> SelectionHandle? {
        guard !rect.isEmpty else { return nil }
        for handle in SelectionHandle.allCases {
            let c = point(of: handle, in: rect)
            if hypot(p.x - c.x, p.y - c.y) <= tolerance { return handle }
        }
        let withinX = p.x >= rect.minX - tolerance && p.x <= rect.maxX + tolerance
        let withinY = p.y >= rect.minY - tolerance && p.y <= rect.maxY + tolerance
        if withinX, abs(p.y - rect.maxY) <= tolerance / 2 { return .top }
        if withinX, abs(p.y - rect.minY) <= tolerance / 2 { return .bottom }
        if withinY, abs(p.x - rect.minX) <= tolerance / 2 { return .left }
        if withinY, abs(p.x - rect.maxX) <= tolerance / 2 { return .right }
        return nil
    }

    /// Drags `handle` of `rect` to `p`. Dragging past the opposite side flips the box instead of collapsing it.
    static func resize(_ rect: CGRect, handle: SelectionHandle, to p: CGPoint, within bounds: CGRect) -> CGRect {
        let q = CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
        var x0 = rect.minX, x1 = rect.maxX, y0 = rect.minY, y1 = rect.maxY
        switch handle {
        case .topLeft, .left, .bottomLeft: x0 = q.x
        case .topRight, .right, .bottomRight: x1 = q.x
        case .top, .bottom: break
        }
        switch handle {
        case .topLeft, .top, .topRight: y1 = q.y
        case .bottomLeft, .bottom, .bottomRight: y0 = q.y
        case .left, .right: break
        }
        return CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1 - x0), height: abs(y1 - y0))
    }

    /// Moves `rect` by `delta`, keeping its size and staying inside `bounds`.
    static func move(_ rect: CGRect, by delta: CGSize, within bounds: CGRect) -> CGRect {
        var moved = rect.offsetBy(dx: delta.width, dy: delta.height)
        moved.origin.x = min(max(moved.origin.x, bounds.minX), bounds.maxX - moved.width)
        moved.origin.y = min(max(moved.origin.y, bounds.minY), bounds.maxY - moved.height)
        return moved
    }

    /// A new box dragged from `start` to `end`, clipped to `bounds`.
    static func rect(from start: CGPoint, to end: CGPoint, within bounds: CGRect) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
            .intersection(bounds)
    }
}
