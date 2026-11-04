import CoreGraphics

enum FloatingDockCorner: String, CaseIterable {
    case bottomLeft
    case bottomRight
    case topLeft
    case topRight
}

/// The dock's short axis stays flush with this display edge.
enum DockPlacementEdge: String, CaseIterable {
    case top
    case bottom
    case left
    case right

    var isVertical: Bool { self == .left || self == .right }
}

/// A different display must remain the candidate continuously before transfer.
/// Pass a monotonic timestamp and call on every drag update, including retreats.
struct MonitorCrossingGate {
    let holdDuration: Double
    private var pendingDisplayID: String?
    private var pendingSince: Double?

    init(holdDuration: Double = 0.7) {
        self.holdDuration = holdDuration.isFinite ? max(0, holdDuration) : 0.7
    }

    mutating func allowsTransition(currentID: String, candidateID: String?, now: Double) -> Bool {
        guard now.isFinite, let candidateID else {
            reset()
            return false
        }
        guard candidateID != currentID else {
            reset()
            return true
        }
        if pendingDisplayID != candidateID || pendingSince.map({ now < $0 }) == true {
            pendingDisplayID = candidateID
            pendingSince = now
        }
        guard let pendingSince, now - pendingSince >= holdDuration else { return false }
        reset()
        return true
    }

    mutating func reset() {
        pendingDisplayID = nil
        pendingSince = nil
    }
}

/// Capture chrome geometry once: snapping can change the panel's outer insets.
/// Reusing its live size would feed those changes back into the drag position.
struct DockDragAnchor {
    let size: CGSize
    let point: CGPoint
    let isVertical: Bool

    func size(for edge: DockPlacementEdge) -> CGSize {
        edge.isVertical == isVertical ? size : CGSize(width: size.height, height: size.width)
    }

    func proposedOrigin(pointer: CGPoint, edge: DockPlacementEdge) -> CGPoint {
        let size = size(for: edge)
        return CGPoint(x: pointer.x - size.width * point.x, y: pointer.y - size.height * point.y)
    }
}

/// Enter a corner within 24 pt, then require a deliberate 36 pt retreat to
/// release it. Small size changes and pointer noise cannot undo a corner snap.
struct DockCornerSnapGate {
    private var snappedEndpoint: CGFloat?
    private var context: String?

    mutating func resolve(offset: CGFloat, travel: CGFloat, context: String) -> CGFloat {
        if self.context != context {
            reset()
            self.context = context
        }
        guard travel > 0 else { return 0 }
        let offset = min(1, max(0, offset))
        if snappedEndpoint == 0, offset * travel <= 36 { return 0 }
        if snappedEndpoint == 1, (1 - offset) * travel <= 36 { return 1 }
        snappedEndpoint = nil
        // Choose the nearest end when short travel overlaps both snap zones.
        if min(offset, 1 - offset) * travel < 24 {
            snappedEndpoint = offset <= 0.5 ? 0 : 1
        }
        return snappedEndpoint ?? offset
    }

    mutating func reset() {
        snappedEndpoint = nil
        context = nil
    }
}

/// AppKit screen coordinates: the bottom-left of a screen is its origin.
struct FloatingDockGeometry {
    static let handleSize = CGSize(width: 128, height: 28)
    static let handleGap: CGFloat = 6

    /// Deterministic at corners: the current caller may keep its orientation
    /// by selecting the matching edge when two distances are equal.
    static func nearestEdge(pointer: CGPoint, in bounds: CGRect) -> DockPlacementEdge {
        let point = CGPoint(
            x: clamp(pointer.x, minimum: bounds.minX, maximum: bounds.maxX),
            y: clamp(pointer.y, minimum: bounds.minY, maximum: bounds.maxY)
        )
        let distances: [(DockPlacementEdge, CGFloat)] = [
            (.left, point.x - bounds.minX),
            (.right, bounds.maxX - point.x),
            (.bottom, point.y - bounds.minY),
            (.top, bounds.maxY - point.y)
        ]
        return distances.min { $0.1 < $1.1 }?.0 ?? .left
    }

    /// Offset 0 is bottom/left, offset 1 is top/right. No external toolbar
    /// space is reserved: the control tile is part of the dock's own size.
    static func snappedOrigin(edge: DockPlacementEdge, offset: CGFloat, dockSize: CGSize, in bounds: CGRect) -> CGPoint {
        let travel = edgeTravel(dockSize: dockSize, in: bounds)
        let fraction = clamp(offset, minimum: 0, maximum: 1)
        switch edge {
        case .left:
            return CGPoint(x: bounds.minX, y: bounds.minY + fraction * travel.height)
        case .right:
            return CGPoint(x: bounds.minX + travel.width, y: bounds.minY + fraction * travel.height)
        case .bottom:
            return CGPoint(x: bounds.minX + fraction * travel.width, y: bounds.minY)
        case .top:
            return CGPoint(x: bounds.minX + fraction * travel.width, y: bounds.minY + travel.height)
        }
    }

    static func normalizedOffset(for origin: CGPoint, edge: DockPlacementEdge, dockSize: CGSize, in bounds: CGRect) -> CGFloat {
        let travel = edgeTravel(dockSize: dockSize, in: bounds)
        let distance = edge.isVertical ? origin.y - bounds.minY : origin.x - bounds.minX
        let length = edge.isVertical ? travel.height : travel.width
        return length > 0 ? clamp(distance / length, minimum: 0, maximum: 1) : 0
    }

    private static func edgeTravel(dockSize: CGSize, in bounds: CGRect) -> CGSize {
        CGSize(
            width: max(0, bounds.width - max(0, dockSize.width)),
            height: max(0, bounds.height - max(0, dockSize.height))
        )
    }

    static func clampedOrigin(_ origin: CGPoint, dockSize: CGSize, in bounds: CGRect) -> CGPoint {
        let travel = availableTravel(dockSize: dockSize, in: bounds)
        return CGPoint(
            x: clamp(origin.x, minimum: bounds.minX, maximum: bounds.minX + travel.width),
            y: clamp(origin.y, minimum: bounds.minY, maximum: bounds.minY + travel.height)
        )
    }

    static func origin(normalized: CGPoint, dockSize: CGSize, in bounds: CGRect) -> CGPoint {
        let travel = availableTravel(dockSize: dockSize, in: bounds)
        return CGPoint(
            x: bounds.minX + clamp(normalized.x, minimum: 0, maximum: 1) * travel.width,
            y: bounds.minY + clamp(normalized.y, minimum: 0, maximum: 1) * travel.height
        )
    }

    static func normalizedOrigin(_ origin: CGPoint, dockSize: CGSize, in bounds: CGRect) -> CGPoint {
        let clamped = clampedOrigin(origin, dockSize: dockSize, in: bounds)
        let travel = availableTravel(dockSize: dockSize, in: bounds)
        return CGPoint(
            x: travel.width > 0 ? (clamped.x - bounds.minX) / travel.width : 0,
            y: travel.height > 0 ? (clamped.y - bounds.minY) / travel.height : 0
        )
    }

    static func origin(for corner: FloatingDockCorner, dockSize: CGSize, in bounds: CGRect) -> CGPoint {
        let normalized: CGPoint
        switch corner {
        case .bottomLeft: normalized = CGPoint(x: 0, y: 0)
        case .bottomRight: normalized = CGPoint(x: 1, y: 0)
        case .topLeft: normalized = CGPoint(x: 0, y: 1)
        case .topRight: normalized = CGPoint(x: 1, y: 1)
        }
        return origin(normalized: normalized, dockSize: dockSize, in: bounds)
    }

    static func handleFrame(dockFrame: CGRect, in bounds: CGRect) -> CGRect {
        // The handle remains reachable even if a disconnected display or a
        // smaller screen temporarily leaves the dock larger than its bounds.
        let size = CGSize(
            width: min(handleSize.width, max(0, bounds.width)),
            height: min(handleSize.height, max(0, bounds.height))
        )
        return CGRect(
            x: clamp(dockFrame.midX - size.width / 2, minimum: bounds.minX, maximum: bounds.maxX - size.width),
            y: clamp(dockFrame.maxY + handleGap, minimum: bounds.minY, maximum: bounds.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    private static func availableTravel(dockSize: CGSize, in bounds: CGRect) -> CGSize {
        CGSize(
            width: max(0, bounds.width - max(0, dockSize.width)),
            height: max(0, bounds.height - max(0, dockSize.height) - handleSize.height - handleGap)
        )
    }

    private static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value.isFinite ? value : minimum, minimum), maximum)
    }
}
