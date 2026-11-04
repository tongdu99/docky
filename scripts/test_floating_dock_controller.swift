// Production placement controller with dependency doubles. Run on macOS with
// WindowServer access; Observation macro expansion may need an unsandboxed run:
// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/FloatingDockGeometry.swift Docky/Services/DockPositionPreset.swift Docky/Services/DockPlacementPreferences.swift Docky/Services/DockWindowInteractionPolicy.swift Docky/Views/MainWindow/FloatingDockController.swift scripts/test_floating_dock_controller.swift -o /tmp/test-floating-dock-controller
// /tmp/test-floating-dock-controller
import AppKit

@MainActor
final class MainWindow: NSPanel {
    var refreshCount = 0
    func refreshFloatingPlacement() { refreshCount += 1 }
    func placementPoint(fromWindow point: CGPoint) -> CGPoint { point }
    func chromeScreenFrame() -> CGRect? { frame }
}

enum ResolvedDockWindowPosition { case top, bottom, left, right }
enum DockWindowPosition {
    case system, top, bottom, left, right, bottomLeft, topLeft, topRight, bottomRight
    case freeVertical, freeHorizontal
    var isFree: Bool { self == .freeVertical || self == .freeHorizontal }
    func resolved(systemOrientation: DockSettingsService.Orientation) -> ResolvedDockWindowPosition {
        switch self {
        case .system:
            switch systemOrientation {
            case .bottom: return .bottom
            case .left: return .left
            case .right: return .right
            }
        case .top: return .top
        case .bottom, .freeHorizontal: return .bottom
        case .right, .topRight, .bottomRight: return .right
        case .left, .topLeft, .bottomLeft, .freeVertical: return .left
        }
    }
}
@MainActor
final class DockSettingsService {
    enum Orientation { case bottom, left, right }
    static let shared = DockSettingsService()
    var orientation: Orientation = .bottom
    var displayTileSize: CGFloat = 48
    var tileSize: CGFloat { displayTileSize }
    func setTileSize(_ value: CGFloat) { displayTileSize = value }
}
@MainActor
final class DockLayoutService {
    static let shared = DockLayoutService()
    var contentScale: CGFloat = 1
}
@MainActor
final class DockyPreferences {
    static let shared = DockyPreferences()
    var windowPosition: DockWindowPosition = .freeVertical
}
@MainActor
final class DockMagnificationService {
    static let shared = DockMagnificationService()
    var clearCount = 0
    func clearPointer() { clearCount += 1 }
}
@MainActor
final class WindowPreviewWindowController {
    static let shared = WindowPreviewWindowController()
    var dismissCount = 0
    func dismissCurrent() { dismissCount += 1 }
}
@MainActor
final class WidgetExpansionWindowController {
    static let shared = WidgetExpansionWindowController()
    var activeSourceTileID: String?
    var dismissedIDs: [String] = []
    func dismiss(sourceTileID: String) { dismissedIDs.append(sourceTileID) }
}

@main
struct FloatingDockControllerTests {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        guard let screen = NSScreen.screens.first else { fatalError("A display is required") }
        let defaults = UserDefaults.standard
        let keys = ["docky.placement.edge", "docky.placement.offset", "docky.freePosition.display",
                    "docky.placement.allowsDragging", "docky.placement.allowsResizing", "docky.placement.isCollapsed",
                    "docky.placement.showsControlTile", "docky.placement.controlIconPath"]
        let saved = keys.map { defaults.object(forKey: $0) }
        for key in keys { defaults.removeObject(forKey: key) }
        let prefs = DockPlacementPreferences.shared
        defer {
            prefs.resetToDefaults()
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            for window in NSApp.windows { window.orderOut(nil) }
        }

        precondition(!prefs.allowsDragging && !prefs.allowsResizing && !prefs.isCollapsed,
                     "Placement editing must start locked and expanded")
        precondition(!prefs.showsControlTile && !prefs.displaysControlTile, "The control tile is optional and hidden by default")
        prefs.isCollapsed = true
        precondition(prefs.displaysControlTile, "A collapsed dock must retain an expand control even when the tile is disabled")
        prefs.isCollapsed = false
        precondition(!prefs.displaysControlTile, "Expanding must restore the hidden-control preference")
        prefs.showsControlTile = true
        prefs.controlIconPath = "/tmp/custom-dock-icon.png"
        let restoredControl = DockPlacementPreferences(defaults: defaults)
        precondition(restoredControl.showsControlTile && restoredControl.displaysControlTile && restoredControl.controlIconPath == prefs.controlIconPath,
                     "The optional tile and its custom icon must persist")
        prefs.resetToDefaults()
        precondition(!prefs.showsControlTile && prefs.controlIconPath == nil, "Behavior reset must restore the optional control defaults")
        prefs.allowsDragging = true
        precondition(prefs.allowsDragging && !prefs.allowsResizing, "Editing locks must be independent")
        prefs.allowsResizing = true
        prefs.allowsDragging = false
        let restoredPrefs = DockPlacementPreferences(defaults: defaults)
        precondition(!restoredPrefs.allowsDragging && restoredPrefs.allowsResizing, "Editing locks must persist independently")
        prefs.resetToDefaults()

        // Border hit testing and displacement must be symmetric for vertical
        // width resizing and horizontal height resizing, including negative
        // monitor coordinates and rejecting points beyond the dock's length.
        let chrome = CGRect(x: -500, y: -300, width: 80, height: 240)
        for (edge, border, outward, parallel) in [
            (DockPlacementEdge.left, CGPoint(x: chrome.maxX - 2, y: chrome.midY), CGPoint(x: 20, y: 0), CGPoint(x: 0, y: 80)),
            (.right, CGPoint(x: chrome.minX + 2, y: chrome.midY), CGPoint(x: -20, y: 0), CGPoint(x: 0, y: 80)),
            (.bottom, CGPoint(x: chrome.midX, y: chrome.maxY - 2), CGPoint(x: 0, y: 20), CGPoint(x: 80, y: 0)),
            (.top, CGPoint(x: chrome.midX, y: chrome.minY + 2), CGPoint(x: 0, y: -20), CGPoint(x: 80, y: 0))
        ] {
            precondition(DockResizeGeometry.contains(border, chrome: chrome, edge: edge), "Resize border must accept \(edge)")
            precondition(!DockResizeGeometry.contains(CGPoint(x: chrome.midX, y: chrome.midY), chrome: chrome, edge: edge), "Dock center must not resize")
            precondition(!DockResizeGeometry.contains(CGPoint(x: chrome.maxX + 10, y: chrome.maxY + 10), chrome: chrome, edge: edge), "Out-of-bounds pointer must not resize")
            precondition(DockResizeGeometry.tileSize(original: 48, displacement: outward, edge: edge) == 68, "Inward resize must grow \(edge)")
            precondition(DockResizeGeometry.tileSize(original: 48, displacement: CGPoint(x: -outward.x, y: -outward.y), edge: edge) == 28, "Outward resize must shrink \(edge)")
            precondition(DockResizeGeometry.tileSize(original: 48, displacement: parallel, edge: edge) == 48, "Along-edge movement must not change thickness")
            precondition(DockResizeGeometry.tileSize(original: 120, displacement: outward, edge: edge) == 128, "Maximum tile size must be enforced")
            precondition(DockResizeGeometry.tileSize(original: 20, displacement: CGPoint(x: -outward.x, y: -outward.y), edge: edge) == 16, "Minimum tile size must be enforced")
        }

        let size = CGSize(width: 80, height: 240)
        let main = MainWindow(contentRect: CGRect(origin: screen.visibleFrame.origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let existingWindows = Set(NSApp.windows.map(\.windowNumber))
        let controller = FloatingDockController(mainWindow: main)
        main.orderFront(nil)
        precondition(!controller.isResizing, "Idle controller must not bypass overflow sizing")
        controller.synchronize(dockFrame: main.frame, screen: screen, isFree: true)
        let placementWindows = NSApp.windows.filter { !existingWindows.contains($0.windowNumber) }
        precondition(placementWindows.count == 1 && !placementWindows[0].isVisible,
                     "Only a hidden drag outline may exist; there must be no external toolbar")
        precondition(placementWindows[0].ignoresMouseEvents, "The drag outline must not capture pointer events")

        func assertPlacement(_ target: String, edge: DockPlacementEdge, offset: CGFloat, message: String) {
            controller.selectPosition(target)
            let expected = FloatingDockGeometry.snappedOrigin(edge: edge, offset: offset, dockSize: size, in: screen.visibleFrame)
            let actual = controller.origin(for: size, screen: screen)
            precondition(abs(expected.x - actual.x) < 0.001 && abs(expected.y - actual.y) < 0.001, message)
            precondition(DockyPreferences.shared.windowPosition == (edge.isVertical ? .freeVertical : .freeHorizontal),
                         "Selecting \(target) must use the expected orientation")
        }

        for (target, edge) in [("top", DockPlacementEdge.top), ("bottom", .bottom), ("left", .left), ("right", .right)] {
            assertPlacement(target, edge: edge, offset: 0.5, message: "Centered edge target \(target) must be centered and flush")
        }
        controller.selectPosition("left")
        for (target, edge, offset) in [("topLeft", DockPlacementEdge.left, CGFloat(1)), ("topRight", .right, 1), ("bottomLeft", .left, 0), ("bottomRight", .right, 0)] {
            assertPlacement(target, edge: edge, offset: offset, message: "Corner \(target) must preserve vertical orientation")
        }
        controller.selectPosition("bottom")
        for (target, edge, offset) in [("topLeft", DockPlacementEdge.top, CGFloat(0)), ("topRight", .top, 1), ("bottomLeft", .bottom, 0), ("bottomRight", .bottom, 1)] {
            assertPlacement(target, edge: edge, offset: offset, message: "Corner \(target) must preserve horizontal orientation")
        }

        // Each diagram target chooses orientation and position atomically,
        // independent of the preceding target's orientation.
        for target in DockPositionTarget.all {
            let expected = target.preset.placement(for: target.orientation)!
            let before = main.refreshCount
            controller.selectPosition(target.preset.rawValue, orientation: target.orientation)
            precondition(main.refreshCount == before + 1, "A direct target must apply one placement update")
            precondition(prefs.edge == expected.edge && prefs.offset == expected.offset)
            precondition(DockyPreferences.shared.windowPosition == (target.orientation == .vertical ? .freeVertical : .freeHorizontal))
        }
        precondition(DockPlacementPreferences.controlAxisLength(tileSize: 48) == 20)
        precondition(DockPlacementPreferences.controlAxisLength(tileSize: 16) == 16)

        let refreshBeforeRepeat = main.refreshCount
        let repeatedTarget = DockPositionTarget.all.last!
        controller.selectPosition(repeatedTarget.preset.rawValue, orientation: repeatedTarget.orientation)
        precondition(main.refreshCount == refreshBeforeRepeat,
                     "Repeating a stationary placement must not relayout the window")

        // Every corner must stay at the same physical corner when rotated twice.
        for target in ["topLeft", "topRight", "bottomLeft", "bottomRight"] {
            controller.selectPosition("left")
            controller.selectPosition(target)
            let initial = controller.origin(for: size, screen: screen)
            controller.rotate()
            precondition(DockyPreferences.shared.windowPosition == .freeHorizontal, "Corner rotation must switch to horizontal")
            let rotated = controller.origin(for: size, screen: screen)
            precondition(rotated == initial, "Rotation must preserve physical corner \(target)")
            controller.rotate()
            precondition(DockyPreferences.shared.windowPosition == .freeVertical && controller.origin(for: size, screen: screen) == initial,
                         "Second rotation must restore the orientation at \(target)")
        }
        for (target, nextEdge) in [("left", DockPlacementEdge.bottom), ("bottom", .left), ("right", .top), ("top", .right)] {
            controller.selectPosition(target)
            controller.rotate()
            let expected = FloatingDockGeometry.snappedOrigin(edge: nextEdge, offset: 0.5, dockSize: size, in: screen.visibleFrame)
            precondition(controller.origin(for: size, screen: screen) == expected,
                         "Rotating a centered \(target) placement must move to the corresponding centered edge")
        }

        let beforeInvalidTarget = controller.origin(for: size, screen: screen)
        let refreshBeforeInvalidTarget = main.refreshCount
        controller.selectPosition("unknown")
        precondition(controller.origin(for: size, screen: screen) == beforeInvalidTarget && main.refreshCount == refreshBeforeInvalidTarget,
                     "Unknown placement targets must leave placement unchanged")

        WidgetExpansionWindowController.shared.activeSourceTileID = "test-widget"
        let dismissBeforeCollapse = WindowPreviewWindowController.shared.dismissCount
        controller.toggleCollapsed()
        controller.synchronize(dockFrame: main.frame, screen: screen, isFree: true)
        precondition(controller.isCollapsed && main.isVisible, "Collapse must keep the existing dock window for its in-dock control")
        precondition(placementWindows.allSatisfy { !$0.isVisible }, "Collapse must not reveal an external toolbar")
        precondition(WindowPreviewWindowController.shared.dismissCount > dismissBeforeCollapse && WidgetExpansionWindowController.shared.dismissedIDs.contains("test-widget"),
                     "Placement changes must dismiss previews tied to old tile coordinates")
        let persistedCollapsed = DockPlacementPreferences(defaults: defaults)
        precondition(persistedCollapsed.isCollapsed, "Collapsed state must persist")
        controller.toggleCollapsed()
        precondition(!controller.isCollapsed && main.isVisible, "Expanding must retain the main dock window")
        precondition(main.refreshCount > 0 && DockMagnificationService.shared.clearCount > 0,
                     "Placement actions must refresh layout and clear stale magnification")

        controller.selectPosition("right")
        let expectedSaved = controller.origin(for: size, screen: screen)
        let reloaded = FloatingDockController(mainWindow: main)
        reloaded.synchronize(dockFrame: main.frame, screen: screen, isFree: true)
        precondition(reloaded.origin(for: size, screen: screen) == expectedSaved && reloaded.savedScreen === screen,
                     "Display, edge, and offset must survive controller recreation")
        DockyPreferences.shared.windowPosition = .left
        reloaded.synchronize(dockFrame: main.frame, screen: screen, isFree: false)
        reloaded.toggleCollapsed()
        precondition(main.isVisible, "Collapsing from an existing fixed edge must keep the in-dock control window")
        print("Edge dock controller placement, rotation, collapse, persistence, and editing-lock tests passed")
    }
}
