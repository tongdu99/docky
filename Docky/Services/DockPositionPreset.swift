import Foundation

enum DockPlacementOrientation: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .vertical: String(localized: "Vertical")
        case .horizontal: String(localized: "Horizontal")
        }
    }
}

/// Clickable presets are a subset of the continuous positions along an edge.
/// Their order matches their physical layout on the screen for each orientation.
enum DockPositionPreset: String, CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case left
    case right
    case bottomLeft
    case bottom
    case bottomRight

    nonisolated var id: String { rawValue }

    nonisolated static func presets(for orientation: DockPlacementOrientation) -> [Self] {
        switch orientation {
        case .vertical: [.topLeft, .topRight, .left, .right, .bottomLeft, .bottomRight]
        case .horizontal: [.topLeft, .top, .topRight, .bottomLeft, .bottom, .bottomRight]
        }
    }

    nonisolated func title(for orientation: DockPlacementOrientation) -> String {
        switch self {
        case .topLeft: String(localized: "Top Left")
        case .top: String(localized: "Top Center")
        case .topRight: String(localized: "Top Right")
        case .left: String(localized: "Middle Left")
        case .right: String(localized: "Middle Right")
        case .bottomLeft: String(localized: "Bottom Left")
        case .bottom: String(localized: "Bottom Center")
        case .bottomRight: String(localized: "Bottom Right")
        }
    }

    /// Offset 0 is the left/bottom end of an edge; offset 1 is right/top.
    /// The centered left/right presets only exist for a vertical dock, and
    /// centered top/bottom presets only exist for a horizontal dock.
    nonisolated func placement(for orientation: DockPlacementOrientation) -> (edge: DockPlacementEdge, offset: CGFloat)? {
        switch (orientation, self) {
        case (.vertical, .topLeft): (.left, 1)
        case (.vertical, .topRight): (.right, 1)
        case (.vertical, .left): (.left, 0.5)
        case (.vertical, .right): (.right, 0.5)
        case (.vertical, .bottomLeft): (.left, 0)
        case (.vertical, .bottomRight): (.right, 0)
        case (.horizontal, .topLeft): (.top, 0)
        case (.horizontal, .top): (.top, 0.5)
        case (.horizontal, .topRight): (.top, 1)
        case (.horizontal, .bottomLeft): (.bottom, 0)
        case (.horizontal, .bottom): (.bottom, 0.5)
        case (.horizontal, .bottomRight): (.bottom, 1)
        default: nil
        }
    }
}

/// Every diagram target includes orientation, so choosing a corner is one
/// atomic action rather than a category change followed by a position change.
struct DockPositionTarget: Identifiable, Hashable {
    let preset: DockPositionPreset
    let orientation: DockPlacementOrientation

    nonisolated var id: String { "\(orientation.rawValue):\(preset.rawValue)" }
    nonisolated var title: String { "\(preset.title(for: orientation)) · \(orientation.title)" }

    nonisolated static var all: [Self] {
        DockPlacementOrientation.allCases.flatMap { orientation in
            DockPositionPreset.presets(for: orientation).map { Self(preset: $0, orientation: orientation) }
        }
    }
}
