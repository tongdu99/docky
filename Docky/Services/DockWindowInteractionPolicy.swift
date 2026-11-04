import AppKit

/// Dock placement and resizing are app-controlled. Native window dragging and
/// resizing would let the system's tiling gestures compete with those controls.
@MainActor
enum DockWindowInteractionPolicy {
    static func apply(to window: NSWindow) {
        // Set the actual AppKit/WindowServer level. A getter-only override can
        // report a panel level while leaving the backing window ordinary.
        if let panel = window as? NSPanel { panel.isFloatingPanel = true }
        window.level = NSWindow.Level(rawValue: max(window.level.rawValue, NSWindow.Level.mainMenu.rawValue))
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.styleMask.remove(.resizable)
        var behavior = window.collectionBehavior
        behavior.remove(.fullScreenAllowsTiling)
        behavior.insert(.fullScreenDisallowsTiling)
        window.collectionBehavior = behavior
    }
}
