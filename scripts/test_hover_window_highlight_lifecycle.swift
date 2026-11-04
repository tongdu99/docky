// Compile the production service against controlled capture and presentation doubles:
// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/WindowPreviewService.swift scripts/test_hover_window_highlight_lifecycle.swift -o /tmp/test-hover-window-highlight-lifecycle
// /tmp/test-hover-window-highlight-lifecycle
import AppKit
import Combine

struct AppWindow {
    let windowIdentifier: String
    let bundleIdentifier = "test.app"
    var isMinimized = false
    var cgWindowID: Int? = 1
    var screenBounds: CGRect? = CGRect(x: 10, y: 20, width: 300, height: 200)
}

enum WindowSwitcherLayout {
    case thumbnails
    func resolved(canCaptureThumbnails: Bool) -> Self { self }
}

struct FocusedWindowPreview {
    let windowIdentifier: String
    let image: NSImage
    let screenBounds: CGRect
}

@MainActor final class DockyPreferences {
    static let shared = DockyPreferences()
    var windowPreviewLayout = WindowSwitcherLayout.thumbnails
    var includesMinimizedWindows = true
}

@MainActor final class PreviewAppearancePreferences {
    static let shared = PreviewAppearancePreferences()
    var highlightsHoveredWindow = true {
        didSet { callbacks.forEach { $0() } }
    }
    var callbacks: [() -> Void] = []
}

// Mirrors observeChanges' immediate evaluation and subsequent preference callbacks.
@MainActor func observeChanges(_ action: @escaping () -> Void) -> AnyCancellable {
    PreviewAppearancePreferences.shared.callbacks.append(action)
    action()
    return AnyCancellable {}
}

@MainActor final class PermissionsService {
    enum Status { case granted, denied }
    static let shared = PermissionsService()
    @Published var screenCapture = Status.granted
}

@MainActor final class WindowSwitcherService {
    static let shared = WindowSwitcherService()
    @Published var isPresented = false
}

@MainActor final class WindowRegistry {
    static let shared = WindowRegistry()
    func isCapturable(_ window: AppWindow) -> Bool { window.cgWindowID != nil }
}

@MainActor final class WorkspaceService {
    struct Capture {
        let identifier: String
        let continuation: CheckedContinuation<NSImage?, Never>
    }
    static let shared = WorkspaceService()
    @Published var appWindowPreviews: [String: NSImage] = [:]
    var availableWindows = [AppWindow(windowIdentifier: "A"), AppWindow(windowIdentifier: "B")]
    var captures: [Capture] = []
    var focused: [String] = []
    func appWindows(bundleIdentifier: String) -> [AppWindow] { availableWindows }
    func appWindowPreview(for window: AppWindow) -> NSImage? { appWindowPreviews[window.windowIdentifier] }
    func focus(window: AppWindow) -> Bool { focused.append(window.windowIdentifier); return true }
    func liveFocusPreviewImage(for window: AppWindow) async -> NSImage? {
        await withCheckedContinuation { captures.append(Capture(identifier: window.windowIdentifier, continuation: $0)) }
    }
    func completeFirst(image: NSImage? = NSImage(size: NSSize(width: 10, height: 10))) {
        precondition(!captures.isEmpty, "Expected an in-flight capture")
        captures.removeFirst().continuation.resume(returning: image)
    }
}

@MainActor final class HoverWindowHighlightWindowController {
    static let shared = HoverWindowHighlightWindowController()
    var shown: [String] = []
    var current: String?
    func show(_ preview: FocusedWindowPreview) {
        shown.append(preview.windowIdentifier)
        current = preview.windowIdentifier
    }
    func dismiss() { current = nil }
}

@MainActor final class WindowPreviewWindowController {
    static let shared = WindowPreviewWindowController()
    func dismissCurrent() { WindowPreviewService.shared.dismiss() }
}

@main struct HoverWindowHighlightLifecycleTests {
    @MainActor static func pause(_ milliseconds: Int) async {
        try! await Task.sleep(for: .milliseconds(milliseconds))
    }

    @MainActor static func main() async {
        let service = WindowPreviewService.shared
        let workspace = WorkspaceService.shared
        let overlay = HoverWindowHighlightWindowController.shared
        await pause(20) // Drain initial Combine deliveries.

        func present() {
            precondition(service.present(forBundleIdentifier: "test.app", sourceTileID: "tile"))
        }
        func hover(_ id: String = "A") { service.setWindowHovered(id, isHovered: true) }

        present()
        hover()
        await pause(80)
        precondition(workspace.captures.isEmpty, "Capture must wait for the 150 ms dwell")
        await pause(130)
        precondition(workspace.captures.map(\.identifier) == ["A"])
        hover("B")
        workspace.completeFirst()
        await pause(20)
        precondition(overlay.shown.isEmpty, "A's late completion must not replace hovered B")
        await pause(180)
        precondition(workspace.captures.map(\.identifier) == ["B"])
        workspace.completeFirst()
        await pause(20)
        precondition(overlay.current == "B")
        precondition(workspace.focused.isEmpty, "Highlighting must never activate a window")
        service.setWindowHovered("B", isHovered: false)
        precondition(overlay.current == nil)
        await pause(150)
        precondition(workspace.captures.isEmpty, "Exited hover must stop live refresh")

        // A cached thumbnail must appear after dwell even if live capture never
        // completes. Switching or dismissing must still reject that late capture.
        service.dismiss()
        workspace.appWindowPreviews = [
            "A": NSImage(size: NSSize(width: 100, height: 80)),
            "B": NSImage(size: NSSize(width: 120, height: 90))
        ]
        await pause(20)
        present()
        hover()
        await pause(80)
        precondition(overlay.current == nil, "Cached highlights must respect dwell too")
        await pause(130)
        precondition(workspace.captures.map(\.identifier) == ["A"])
        precondition(overlay.current == "A", "Cached thumbnail must show while live capture is held")
        hover("B")
        precondition(overlay.current == nil, "Changing hover clears the previous cached highlight")
        let beforeOldCapture = overlay.shown.count
        workspace.completeFirst()
        await pause(20)
        precondition(overlay.shown.count == beforeOldCapture, "A's old live capture must not overwrite B's cached highlight")
        await pause(180)
        precondition(overlay.current == "B")
        precondition(workspace.captures.map(\.identifier) == ["B"])
        service.dismiss()
        let beforeDismissedCapture = overlay.shown.count
        workspace.completeFirst()
        await pause(20)
        precondition(overlay.current == nil && overlay.shown.count == beforeDismissedCapture,
                     "Dismissed popup must reject late live capture even with cached thumbnails")

        // Each invalidation must clear an already visible highlight and reject an
        // outstanding live refresh, even when capture ignores task cancellation.
        // Temporary blockers retain physical hover and resume without another enter.
        let invalidations: [(String, () -> Void, () -> Void, Bool)] = [
            ("exit", { service.setWindowHovered("A", isHovered: false) }, {}, false),
            ("dismiss", { service.dismiss() }, {}, false),
            ("context menu", { service.setContextMenuPresented(true) }, { service.setContextMenuPresented(false) }, true),
            ("disabled setting", { PreviewAppearancePreferences.shared.highlightsHoveredWindow = false }, { PreviewAppearancePreferences.shared.highlightsHoveredWindow = true }, true),
            ("revoked permission", { PermissionsService.shared.screenCapture = .denied }, { PermissionsService.shared.screenCapture = .granted }, true),
            ("keyboard switcher", { WindowSwitcherService.shared.isPresented = true }, { WindowSwitcherService.shared.isPresented = false }, true)
        ]
        for (name, invalidate, restore, resumes) in invalidations {
            present()
            hover()
            await pause(210)
            precondition(workspace.captures.count == 1, "Expected initial capture for \(name)")
            workspace.completeFirst()
            await pause(20)
            precondition(overlay.current == "A")
            await pause(160)
            precondition(workspace.captures.count == 1, "Expected live refresh for \(name)")
            invalidate()
            await pause(20)
            precondition(overlay.current == nil, "\(name) must immediately clear the highlight")
            let showCount = overlay.shown.count
            workspace.completeFirst()
            await pause(30)
            precondition(overlay.shown.count == showCount, "\(name) must suppress a stale completion")
            restore()
            await pause(80)
            precondition(overlay.current == nil, "Restored \(name) must wait for dwell")
            await pause(130)
            if resumes {
                precondition(overlay.current == "A", "Restored \(name) must highlight without another hover enter")
                precondition(workspace.captures.map(\.identifier) == ["A"], "Restored \(name) must restart live capture")
            } else {
                precondition(overlay.current == nil && workspace.captures.isEmpty,
                             "Actual \(name) must not resume highlighting")
            }
            service.dismiss()
            if resumes { workspace.completeFirst() }
            await pause(20)
            precondition(overlay.current == nil, "Dismissal after recovery must reject late live capture")
        }

        for permissionGranted in [false, true] {
            PermissionsService.shared.screenCapture = permissionGranted ? .granted : .denied
            PreviewAppearancePreferences.shared.highlightsHoveredWindow = !permissionGranted
            await pause(20)
            present()
            hover()
            await pause(210)
            precondition(workspace.captures.isEmpty, "Disabled permission or setting must preserve ordinary previews without capturing")
            precondition(!service.windows.isEmpty)
            service.dismiss()
        }
        PermissionsService.shared.screenCapture = .granted
        PreviewAppearancePreferences.shared.highlightsHoveredWindow = true
        workspace.availableWindows[0].isMinimized = true
        await pause(20)
        present()
        hover()
        await pause(210)
        precondition(workspace.captures.isEmpty, "Minimized windows must use the ordinary preview fallback")
        precondition(service.windows.contains { $0.windowIdentifier == "A" })
        precondition(overlay.current == nil)
        service.dismiss()
        print("Hover window highlight lifecycle tests passed")
    }
}
