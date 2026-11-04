// Run from the repository root:
// swiftc -module-cache-path /tmp/docky-geometry-module-cache Docky/Services/FloatingDockGeometry.swift scripts/test_floating_dock_geometry.swift -o /tmp/test-floating-dock-geometry && /tmp/test-floating-dock-geometry
import CoreGraphics

@main
struct FloatingDockGeometryTests {
    static func main() {
        checkCornerSnapStability()
        let bounds = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let dockSize = CGSize(width: 80, height: 600)
        let top = bounds.maxY - dockSize.height - FloatingDockGeometry.handleSize.height - FloatingDockGeometry.handleGap

        check(FloatingDockGeometry.clampedOrigin(CGPoint(x: -4000, y: -900), dockSize: dockSize, in: bounds), equals: bounds.origin)
        check(FloatingDockGeometry.clampedOrigin(CGPoint(x: 100, y: 1000), dockSize: dockSize, in: bounds), equals: CGPoint(x: -80, y: top))

        for normalized in [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 0.35, y: 0.62)] {
            let origin = FloatingDockGeometry.origin(normalized: normalized, dockSize: dockSize, in: bounds)
            check(FloatingDockGeometry.normalizedOrigin(origin, dockSize: dockSize, in: bounds), equals: normalized)
        }
        check(FloatingDockGeometry.origin(normalized: CGPoint(x: -1, y: 3), dockSize: dockSize, in: bounds), equals: CGPoint(x: bounds.minX, y: top))

        let expected: [FloatingDockCorner: CGPoint] = [
            .bottomLeft: bounds.origin,
            .bottomRight: CGPoint(x: -80, y: bounds.minY),
            .topLeft: CGPoint(x: bounds.minX, y: top),
            .topRight: CGPoint(x: -80, y: top)
        ]
        for corner in FloatingDockCorner.allCases {
            let origin = FloatingDockGeometry.origin(for: corner, dockSize: dockSize, in: bounds)
            check(origin, equals: expected[corner]!)
            let dock = CGRect(origin: origin, size: dockSize)
            let handle = FloatingDockGeometry.handleFrame(dockFrame: dock, in: bounds)
            precondition(bounds.contains(dock), "Dock escaped visible bounds at \(corner)")
            precondition(bounds.contains(handle), "Handle escaped visible bounds at \(corner)")
            precondition(handle.minY >= dock.maxY + FloatingDockGeometry.handleGap, "Handle overlaps dock")
        }

        let oversized = CGSize(width: 3000, height: 2000)
        check(FloatingDockGeometry.clampedOrigin(CGPoint(x: 40, y: 40), dockSize: oversized, in: bounds), equals: bounds.origin)
        check(FloatingDockGeometry.origin(normalized: CGPoint(x: 1, y: 1), dockSize: oversized, in: bounds), equals: bounds.origin)
        check(FloatingDockGeometry.normalizedOrigin(CGPoint(x: 40, y: 40), dockSize: oversized, in: bounds), equals: .zero)
        precondition(bounds.contains(FloatingDockGeometry.handleFrame(dockFrame: CGRect(origin: bounds.origin, size: oversized), in: bounds)))

        let tinyBounds = CGRect(x: 10, y: 20, width: 60, height: 16)
        precondition(tinyBounds.contains(FloatingDockGeometry.handleFrame(dockFrame: CGRect(origin: .zero, size: oversized), in: tinyBounds)))
        check(FloatingDockGeometry.clampedOrigin(CGPoint(x: CGFloat.nan, y: CGFloat.infinity), dockSize: dockSize, in: bounds), equals: bounds.origin)
        checkEdgePlacement()
        checkMonitorCrossing()
        print("Floating dock geometry and monitor crossing checks passed")
    }

    private static func checkEdgePlacement() {
        let bounds = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let dock = CGSize(width: 80, height: 600)
        let expected: [DockPlacementEdge: CGPoint] = [
            .left: CGPoint(x: -1920, y: 40),
            .right: CGPoint(x: -80, y: 40),
            .bottom: CGPoint(x: -1000, y: -200),
            .top: CGPoint(x: -1000, y: 280)
        ]
        for edge in DockPlacementEdge.allCases {
            check(FloatingDockGeometry.snappedOrigin(edge: edge, offset: 0.5, dockSize: dock, in: bounds), equals: expected[edge]!)
            for offset: CGFloat in [0, 0.3, 1] {
                let origin = FloatingDockGeometry.snappedOrigin(edge: edge, offset: offset, dockSize: dock, in: bounds)
                let recovered = FloatingDockGeometry.normalizedOffset(for: origin, edge: edge, dockSize: dock, in: bounds)
                precondition(abs(offset - recovered) < 0.0001, "Edge offset did not survive placement")
                precondition(bounds.contains(CGRect(origin: origin, size: dock)), "Edge dock escaped display")
            }
        }
        // Unlike the old floating-toolbar helper, the new tile uses no extra
        // vertical space, even when attached to the very top of a display.
        check(FloatingDockGeometry.snappedOrigin(edge: .left, offset: 1, dockSize: dock, in: bounds), equals: CGPoint(x: -1920, y: 280))
        check(FloatingDockGeometry.snappedOrigin(edge: .bottom, offset: -5, dockSize: dock, in: bounds), equals: bounds.origin)
        check(FloatingDockGeometry.snappedOrigin(edge: .top, offset: .nan, dockSize: dock, in: bounds), equals: CGPoint(x: -1920, y: 280))
        precondition(FloatingDockGeometry.nearestEdge(pointer: CGPoint(x: -1910, y: 100), in: bounds) == .left)
        precondition(FloatingDockGeometry.nearestEdge(pointer: CGPoint(x: -10, y: 100), in: bounds) == .right)
        precondition(FloatingDockGeometry.nearestEdge(pointer: CGPoint(x: -1000, y: 870), in: bounds) == .top)
        precondition(FloatingDockGeometry.nearestEdge(pointer: CGPoint(x: -1000, y: -190), in: bounds) == .bottom)
        precondition(FloatingDockGeometry.nearestEdge(pointer: CGPoint(x: -3000, y: 100), in: bounds) == .left)
        let oversized = CGSize(width: 3000, height: 2000)
        for edge in DockPlacementEdge.allCases {
            check(FloatingDockGeometry.snappedOrigin(edge: edge, offset: 1, dockSize: oversized, in: bounds), equals: bounds.origin)
            precondition(FloatingDockGeometry.normalizedOffset(for: bounds.origin, edge: edge, dockSize: oversized, in: bounds) == 0)
        }
    }

    private static func checkCornerSnapStability() {
        // Reproduce the old loop: endpoint insets alternated measured sizes
        // between 602 and 600 while the pointer and anchor stayed fixed.
        for edge in DockPlacementEdge.allCases {
            for endpoint in [CGFloat(0), CGFloat(1)] {
                var gate = DockCornerSnapGate()
                let context = "display-a:\(edge.rawValue)"
                for tick in 0..<100 {
                    let size: CGFloat = tick.isMultiple(of: 2) ? 602 : 600
                    let distance = CGFloat(613.46) - size * 0.98
                    let travel = 1080 - size
                    let raw = endpoint == 0 ? distance / travel : 1 - distance / travel
                    precondition(gate.resolve(offset: raw, travel: travel, context: context) == endpoint,
                                 "Stationary corner snap must not oscillate for \(edge)")
                }
                let travel: CGFloat = 480
                let withinRelease = endpoint == 0 ? 35 / travel : 1 - 35 / travel
                precondition(gate.resolve(offset: withinRelease, travel: travel, context: context) == endpoint)
                let retreat = endpoint == 0 ? 37 / travel : 1 - 37 / travel
                precondition(gate.resolve(offset: retreat, travel: travel, context: context) == retreat,
                             "A deliberate retreat must release the corner")
                let reenter = endpoint == 0 ? 23 / travel : 1 - 23 / travel
                precondition(gate.resolve(offset: reenter, travel: travel, context: context) == endpoint)
                precondition(gate.resolve(offset: withinRelease, travel: travel, context: "display-b") == withinRelease,
                             "Display or edge changes must clear the old snap")
                _ = gate.resolve(offset: reenter, travel: travel, context: context)
                gate.reset()
                precondition(gate.resolve(offset: withinRelease, travel: travel, context: context) == withinRelease,
                             "New gestures must not inherit the previous snap")
                precondition(gate.resolve(offset: 0.7, travel: 0, context: context) == 0)
            }
        }
        let anchor = DockDragAnchor(size: CGSize(width: 80, height: 600), point: CGPoint(x: 0.5, y: 0.98), isVertical: true)
        let pointer = CGPoint(x: 40, y: 613.46)
        check(anchor.proposedOrigin(pointer: pointer, edge: .left), equals: CGPoint(x: 0, y: 25.46))
        precondition(anchor.size(for: .bottom) == CGSize(width: 600, height: 80),
                     "Changing orientation must transpose the captured chrome size")
        var short = DockCornerSnapGate()
        precondition(short.resolve(offset: 0.2, travel: 10, context: "short") == 0,
                     "Overlapping corner zones must choose the nearest endpoint")
    }

    private static func checkMonitorCrossing() {
        var gate = MonitorCrossingGate()
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 1))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 1.69))
        precondition(gate.allowsTransition(currentID: "a", candidateID: "b", now: 1.71))
        // Returning to the current display resets the accumulated hold.
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 2))
        precondition(gate.allowsTransition(currentID: "a", candidateID: "a", now: 2.5))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 2.6))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 3.1))
        precondition(gate.allowsTransition(currentID: "a", candidateID: "b", now: 3.31))
        // A third display starts a new hold, and leaving all displays clears it.
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 4))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "c", now: 4.5))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "c", now: 5))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: nil, now: 5.1))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "c", now: 5.2))
        precondition(gate.allowsTransition(currentID: "a", candidateID: "c", now: 5.91))
        // Invalid or backwards timestamps cannot skip the delay.
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: .nan))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 10))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 9))
        precondition(!gate.allowsTransition(currentID: "a", candidateID: "b", now: 9.5))
        precondition(gate.allowsTransition(currentID: "a", candidateID: "b", now: 9.71))
        var immediate = MonitorCrossingGate(holdDuration: 0)
        precondition(immediate.allowsTransition(currentID: "a", candidateID: "b", now: 1))
    }

    private static func check(_ actual: CGPoint, equals expected: CGPoint) {
        precondition(abs(actual.x - expected.x) < 0.0001 && abs(actual.y - expected.y) < 0.0001,
                     "Expected \(expected), got \(actual)")
    }
}
