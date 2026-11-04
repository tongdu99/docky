// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/DockWindowInteractionPolicy.swift scripts/test_dock_window_interaction.swift -o /tmp/test-dock-window-interaction
// /tmp/test-dock-window-interaction
import AppKit

@main
struct DockWindowInteractionTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let panel = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 80, height: 240),
                            styleMask: [.borderless, .nonactivatingPanel, .resizable],
                            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenAllowsTiling]
        DockWindowInteractionPolicy.apply(to: panel)
        precondition(panel.level.rawValue >= NSWindow.Level.mainMenu.rawValue && panel.isFloatingPanel,
                     "Dock must use a real elevated floating-panel level")
        panel.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let backingWindow = windows.first { ($0[kCGWindowNumber as String] as? Int) == panel.windowNumber }
        precondition((backingWindow?[kCGWindowLayer as String] as? Int) == panel.level.rawValue,
                     "WindowServer must see the actual elevated level")
        panel.orderOut(nil)
        precondition(!panel.isMovable && !panel.isMovableByWindowBackground,
                     "Native dragging must be disabled")
        precondition(!panel.styleMask.contains(.resizable), "Native resizing must be disabled")
        precondition(panel.styleMask.contains(.nonactivatingPanel), "Dock clicks must remain nonactivating")
        precondition(panel.collectionBehavior.contains(.fullScreenDisallowsTiling))
        precondition(!panel.collectionBehavior.contains(.fullScreenAllowsTiling))
        precondition(panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary),
                     "Space and fullscreen auxiliary behavior must survive the policy")
        let movedAndResized = CGRect(x: 180, y: 220, width: 100, height: 340)
        panel.setFrame(movedAndResized, display: false)
        precondition(panel.frame == movedAndResized,
                     "App-controlled placement and resizing must remain available")
        panel.collectionBehavior = [.moveToActiveSpace, .stationary]
        DockWindowInteractionPolicy.apply(to: panel)
        precondition(panel.collectionBehavior.contains(.moveToActiveSpace) && panel.collectionBehavior.contains(.fullScreenDisallowsTiling),
                     "Changing Space settings must retain the tiling exclusion")
        print("Dock native-drag/tiling exclusion and app-controlled placement tests passed")
    }
}
