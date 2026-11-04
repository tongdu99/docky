import Foundation
import Observation

/// Editing locks are independent of the dock's chosen edge or corner.
@MainActor
@Observable
final class DockPlacementPreferences {
    static let shared = DockPlacementPreferences()

    @ObservationIgnored private let defaults: UserDefaults

    var showsControlTile: Bool {
        didSet { defaults.set(showsControlTile, forKey: Keys.showsControlTile) }
    }

    var controlIconPath: String? {
        didSet { defaults.set(controlIconPath, forKey: Keys.controlIconPath) }
    }

    var displaysControlTile: Bool { showsControlTile || isCollapsed }

    nonisolated static func controlAxisLength(tileSize: CGFloat) -> CGFloat { min(20, tileSize) }

    var offset: CGFloat {
        didSet { defaults.set(Double(offset), forKey: "docky.placement.offset") }
    }

    var edge: DockPlacementEdge {
        didSet { defaults.set(edge.rawValue, forKey: "docky.placement.edge") }
    }

    var allowsDragging: Bool {
        didSet { defaults.set(allowsDragging, forKey: Keys.allowsDragging) }
    }

    var allowsResizing: Bool {
        didSet { defaults.set(allowsResizing, forKey: Keys.allowsResizing) }
    }

    var isCollapsed: Bool {
        didSet { defaults.set(isCollapsed, forKey: Keys.isCollapsed) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsControlTile = defaults.bool(forKey: Keys.showsControlTile)
        controlIconPath = defaults.string(forKey: Keys.controlIconPath)
        offset = min(1, max(0, (defaults.object(forKey: "docky.placement.offset") as? Double) ?? 0.5))
        edge = DockPlacementEdge(rawValue: defaults.string(forKey: "docky.placement.edge") ?? "") ?? .left
        allowsDragging = defaults.bool(forKey: Keys.allowsDragging)
        allowsResizing = defaults.bool(forKey: Keys.allowsResizing)
        isCollapsed = defaults.bool(forKey: Keys.isCollapsed)
    }

    func resetToDefaults() {
        showsControlTile = false
        controlIconPath = nil
        allowsDragging = false
        allowsResizing = false
        isCollapsed = false
    }

    private enum Keys {
        static let showsControlTile = "docky.placement.showsControlTile"
        static let controlIconPath = "docky.placement.controlIconPath"
        static let allowsDragging = "docky.placement.allowsDragging"
        static let allowsResizing = "docky.placement.allowsResizing"
        static let isCollapsed = "docky.placement.isCollapsed"
    }
}
