// Run from the repository root:
// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/FloatingDockGeometry.swift Docky/Services/DockPositionPreset.swift scripts/test_dock_position_presets.swift -o /tmp/test-dock-position-presets
// /tmp/test-dock-position-presets
import Foundation

@main
struct DockPositionPresetTests {
    static func main() {
        let expectedVertical: [DockPositionPreset] = [.topLeft, .topRight, .left, .right, .bottomLeft, .bottomRight]
        let expectedHorizontal: [DockPositionPreset] = [.topLeft, .top, .topRight, .bottomLeft, .bottom, .bottomRight]
        precondition(DockPositionPreset.presets(for: .vertical) == expectedVertical,
                     "Vertical menu must read as left/right columns from top to bottom")
        precondition(DockPositionPreset.presets(for: .horizontal) == expectedHorizontal,
                     "Horizontal menu must read as top/bottom rows from left to right")

        let allTargets = DockPositionTarget.all
        precondition(allTargets.count == 12 && Set(allTargets.map(\.id)).count == 12,
                     "The diagram must expose twelve independently selectable targets")
        precondition(Set(allTargets.map(\.title)).count == 12,
                     "Each target must have an unambiguous position and orientation label")
        for target in allTargets {
            precondition(target.preset.placement(for: target.orientation) != nil)
        }
        for corner in [DockPositionPreset.topLeft, .topRight, .bottomLeft, .bottomRight] {
            precondition(allTargets.filter { $0.preset == corner }.count == 2,
                         "Every corner must offer separate vertical and horizontal choices")
        }

        let bounds = CGRect(x: -1500, y: -200, width: 1500, height: 1000)
        let dockSize = CGSize(width: 80, height: 300)
        let expectedCorners: [DockPositionPreset: CGPoint] = [
            .topLeft: CGPoint(x: bounds.minX, y: bounds.maxY - dockSize.height),
            .topRight: CGPoint(x: bounds.maxX - dockSize.width, y: bounds.maxY - dockSize.height),
            .bottomLeft: bounds.origin,
            .bottomRight: CGPoint(x: bounds.maxX - dockSize.width, y: bounds.minY)
        ]
        for orientation in DockPlacementOrientation.allCases {
            let presets = DockPositionPreset.presets(for: orientation)
            precondition(presets.count == 6 && Set(presets).count == 6,
                         "Each orientation must offer six unique choices")
            var placements = Set<String>()
            for preset in presets {
                guard let placement = preset.placement(for: orientation) else {
                    fatalError("A visible preset must have a valid placement")
                }
                precondition(placement.edge.isVertical == (orientation == .vertical),
                             "Preset selection must preserve the chosen orientation")
                placements.insert("\(placement.edge.rawValue):\(placement.offset)")
                let actual = FloatingDockGeometry.snappedOrigin(edge: placement.edge, offset: placement.offset,
                                                               dockSize: dockSize, in: bounds)
                if let expected = expectedCorners[preset] {
                    precondition(actual == expected, "Corner placement must reach the same physical corner in both orientations")
                }
            }
            precondition(placements.count == 6, "Every visible choice must select a distinct placement")
        }
        precondition(DockPositionPreset.top.placement(for: .vertical) == nil)
        precondition(DockPositionPreset.bottom.placement(for: .vertical) == nil)
        precondition(DockPositionPreset.left.placement(for: .horizontal) == nil)
        precondition(DockPositionPreset.right.placement(for: .horizontal) == nil)

        // Mirrored choices must stay on opposing screen edges at equal offsets.
        for pair in [(DockPositionPreset.topLeft, DockPositionPreset.topRight), (.left, .right), (.bottomLeft, .bottomRight)] {
            let lhs = pair.0.placement(for: .vertical)!
            let rhs = pair.1.placement(for: .vertical)!
            precondition(lhs.edge == .left && rhs.edge == .right && lhs.offset == rhs.offset)
        }
        for pair in [(DockPositionPreset.topLeft, DockPositionPreset.bottomLeft), (.top, .bottom), (.topRight, .bottomRight)] {
            let lhs = pair.0.placement(for: .horizontal)!
            let rhs = pair.1.placement(for: .horizontal)!
            precondition(lhs.edge == .top && rhs.edge == .bottom && lhs.offset == rhs.offset)
        }
        print("Orientation-specific dock position preset tests passed")
    }
}
