import AppKit

/// Placement editing lives in the dock's existing window. No separate handle
/// window is needed; app tiles and the control button keep their normal events.
@MainActor
final class FloatingDockController {
    static weak var active: FloatingDockController?
    private weak var mainWindow: MainWindow?
    private let defaults = UserDefaults.standard
    private var dockFrame: CGRect = .zero
    private var dockScreen: NSScreen?
    private var interactiveFrames: [CGRect] = []
    private var controlFrame: CGRect?
    private var eventMonitor: Any?
    private var dragTimer: Timer?
    private var crossingGate = MonitorCrossingGate()
    private var cornerSnapGate = DockCornerSnapGate()
    private var gesture: Gesture?
    private var offset: CGFloat {
        get { DockPlacementPreferences.shared.offset }
        set { DockPlacementPreferences.shared.offset = newValue }
    }
    private var displayID: String?
    private let outline: NSPanel

    private struct Gesture {
        var pointer: CGPoint
        var anchor: DockDragAnchor
        var originalTileSize: CGFloat
        var resizing: Bool
        var moved = false
        var togglesCollapsedOnClick = false
    }

    var isCollapsed: Bool { DockPlacementPreferences.shared.isCollapsed }
    var isResizing: Bool { gesture?.resizing == true && gesture?.moved == true }

    init(mainWindow: MainWindow) {
        self.mainWindow = mainWindow
        displayID = defaults.string(forKey: "docky.freePosition.display")
        outline = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        outline.isReleasedWhenClosed = false
        outline.isOpaque = false
        outline.backgroundColor = .clear
        outline.hasShadow = false
        outline.ignoresMouseEvents = true
        outline.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        let view = NSView()
        view.wantsLayer = true
        view.layer?.borderWidth = 2
        view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        view.layer?.cornerRadius = 6
        outline.contentView = view
        Self.active = self
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func synchronizeSpaceBehavior() {
        outline.collectionBehavior = mainWindow?.collectionBehavior ?? [.canJoinAllSpaces]
        DockWindowInteractionPolicy.apply(to: outline)
    }

    var savedScreen: NSScreen? {
        NSScreen.screens.first { Self.identifier(for: $0) == displayID }
    }

    func origin(for size: CGSize, screen: NSScreen) -> CGPoint {
        FloatingDockGeometry.snappedOrigin(edge: effectiveEdge, offset: offset, dockSize: size, in: screen.visibleFrame)
    }

    private var effectiveEdge: DockPlacementEdge {
        let prefs = DockyPreferences.shared
        if prefs.windowPosition.isFree {
            if prefs.windowPosition == .freeVertical { return DockPlacementPreferences.shared.edge == .right ? .right : .left }
            return DockPlacementPreferences.shared.edge == .top ? .top : .bottom
        }
        switch prefs.windowPosition.resolved(systemOrientation: DockSettingsService.shared.orientation) {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .left
        case .right: return .right
        }
    }

    var selectedPosition: String? {
        if !DockyPreferences.shared.windowPosition.isFree {
            let position = DockyPreferences.shared.windowPosition
            if position == .bottomLeft { return "bottomLeft" }
            return effectiveEdge.rawValue
        }
        let edge = effectiveEdge
        if offset < 0.001 {
            switch edge {
            case .left, .bottom: return "bottomLeft"
            case .right: return "bottomRight"
            case .top: return "topLeft"
            }
        }
        if offset > 0.999 {
            switch edge {
            case .left: return "topLeft"
            case .right, .top: return "topRight"
            case .bottom: return "bottomRight"
            }
        }
        return abs(offset - 0.5) < 0.001 ? edge.rawValue : nil
    }

    func synchronize(dockFrame: CGRect, screen: NSScreen, isFree: Bool) {
        self.dockFrame = dockFrame
        dockScreen = screen
        synchronizeSpaceBehavior()
        if gesture?.moved == true, let chrome = mainWindow?.chromeScreenFrame() {
            outline.setFrame(chrome.insetBy(dx: -1, dy: -1), display: true)
            outline.orderFrontRegardless()
        }
    }

    func updateInteractiveTileFrames(_ frames: [CGRect], controlFrame: CGRect? = nil) {
        interactiveFrames = frames
        self.controlFrame = controlFrame
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let mainWindow else { return event }
        if gesture != nil {
            if event.type == .leftMouseDragged || event.type == .leftMouseUp {
                let pointer = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
                updateDrag(pointer: pointer)
                if event.type == .leftMouseUp { endDrag() }
                return nil
            }
        }
        guard event.window === mainWindow,
              let chrome = mainWindow.chromeScreenFrame() else { return event }
        let prefs = DockPlacementPreferences.shared
        let edge = effectiveEdge
        let pointer = mainWindow.convertPoint(toScreen: event.locationInWindow)
        let onResizeBorder = prefs.allowsResizing && DockResizeGeometry.contains(pointer, chrome: chrome, edge: edge)
        guard onResizeBorder || chrome.insetBy(dx: -3, dy: -3).contains(pointer) else { return event }
        if event.type == .mouseMoved {
            if onResizeBorder { (edge.isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() }
            return event
        }
        guard event.type == .leftMouseDown else { return event }
        let location = mainWindow.placementPoint(fromWindow: event.locationInWindow)
        let hitsTile = interactiveFrames.contains { $0.contains(location) }
        let hitsControl = controlFrame?.contains(location) == true
        guard onResizeBorder || (prefs.allowsDragging && (!hitsTile || hitsControl)) else { return event }
        beginGesture(pointer: pointer, chrome: chrome, resizing: onResizeBorder,
                     togglesCollapsedOnClick: hitsControl && !onResizeBorder)
        return nil
    }

    /// A native bar can start placement directly when SwiftUI's most recent
    /// geometry preference has not yet reached the event monitor.
    func beginControlDrag(with event: NSEvent) -> Bool {
        guard DockPlacementPreferences.shared.allowsDragging,
              let chrome = mainWindow?.chromeScreenFrame() else { return false }
        let pointer = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        beginGesture(pointer: pointer, chrome: chrome, resizing: false,
                     togglesCollapsedOnClick: true)
        return true
    }

    private func beginGesture(pointer: CGPoint, chrome: CGRect, resizing: Bool, togglesCollapsedOnClick: Bool) {
        gesture = Gesture(pointer: pointer,
                          anchor: DockDragAnchor(size: chrome.size,
                              point: CGPoint(x: (pointer.x - chrome.minX) / max(1, chrome.width), y: (pointer.y - chrome.minY) / max(1, chrome.height)),
                              isVertical: effectiveEdge.isVertical),
                          originalTileSize: DockSettingsService.shared.displayTileSize * DockLayoutService.shared.contentScale,
                          resizing: resizing,
                          togglesCollapsedOnClick: togglesCollapsedOnClick)
        crossingGate.reset()
        cornerSnapGate.reset()
        dragTimer?.invalidate()
        dragTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateDrag() }
        }
    }

    private func updateDrag(pointer: CGPoint = NSEvent.mouseLocation) {
        guard var gesture else { return }
        let dx = pointer.x - gesture.pointer.x
        let dy = pointer.y - gesture.pointer.y
        guard gesture.moved || hypot(dx, dy) > 3 else { return }
        let beganMoving = !gesture.moved
        if beganMoving {
            gesture.moved = true
            self.gesture = gesture
        }
        // Record a drag even while display geometry is temporarily unavailable;
        // releasing must never turn that movement into a collapse click.
        guard let mainWindow, let screen = dockScreen else { return }
        if beganMoving {
            dismissPopovers()
            DockMagnificationService.shared.clearPointer()
            captureCurrentPlacement()
        }
        if gesture.resizing {
            let size = DockResizeGeometry.tileSize(
                original: gesture.originalTileSize,
                displacement: CGPoint(x: dx, y: dy),
                edge: effectiveEdge
            )
            if DockSettingsService.shared.tileSize != size { DockSettingsService.shared.setTileSize(size) }
            mainWindow.refreshFloatingPlacement()
            return
        }
        let candidate = NSScreen.screens.first { $0.frame.contains(pointer) }
        let allowed = crossingGate.allowsTransition(currentID: Self.identifier(for: screen), candidateID: candidate.map(Self.identifier), now: ProcessInfo.processInfo.systemUptime)
        let target = allowed ? (candidate ?? screen) : screen
        let bounds = target.visibleFrame
        var edge = FloatingDockGeometry.nearestEdge(pointer: pointer, in: bounds)
        // At a corner, stay on the current edge until the pointer clearly
        // leaves it; this preserves orientation when sliding into corners.
        let current = effectiveEdge
        let currentDistance: CGFloat = switch current {
        case .left: abs(pointer.x - bounds.minX)
        case .right: abs(pointer.x - bounds.maxX)
        case .top: abs(pointer.y - bounds.maxY)
        case .bottom: abs(pointer.y - bounds.minY)
        }
        if currentDistance < 40 { edge = current }
        let size = gesture.anchor.size(for: edge)
        let proposed = gesture.anchor.proposedOrigin(pointer: pointer, edge: edge)
        let rawOffset = FloatingDockGeometry.normalizedOffset(for: proposed, edge: edge, dockSize: size, in: bounds)
        let travel = max(0, edge.isVertical ? bounds.height - size.height : bounds.width - size.width)
        let nextOffset = cornerSnapGate.resolve(offset: rawOffset, travel: travel,
                                               context: "\(Self.identifier(for: target)):\(edge.rawValue)")
        setPlacement(edge: edge, offset: nextOffset, screen: target)
    }

    private func captureCurrentPlacement() {
        guard !DockyPreferences.shared.windowPosition.isFree, let screen = dockScreen else { return }
        let edge = effectiveEdge
        let chrome = mainWindow?.chromeScreenFrame() ?? dockFrame
        let offset = FloatingDockGeometry.normalizedOffset(for: chrome.origin, edge: edge, dockSize: chrome.size, in: screen.visibleFrame)
        setPlacement(edge: edge, offset: offset, screen: screen)
    }

    private func endDrag() {
        let shouldToggle = gesture?.togglesCollapsedOnClick == true && gesture?.moved == false
        dragTimer?.invalidate()
        dragTimer = nil
        gesture = nil
        crossingGate.reset()
        cornerSnapGate.reset()
        outline.orderOut(nil)
        NSCursor.arrow.set()
        if shouldToggle { toggleCollapsed() }
    }

    func toggleCollapsed() {
        dismissPopovers()
        captureCurrentPlacement()
        DockMagnificationService.shared.clearPointer()
        DockPlacementPreferences.shared.isCollapsed.toggle()
        mainWindow?.refreshFloatingPlacement()
    }

    func rotate() {
        dismissPopovers()
        captureCurrentPlacement()
        guard let screen = dockScreen else { return }
        let current = effectiveEdge
        let atCorner = offset == 0 || offset == 1
        let next: DockPlacementEdge
        if atCorner {
            if current.isVertical { next = offset == 0 ? .bottom : .top }
            else { next = offset == 0 ? .left : .right }
        } else {
            switch current {
            case .left: next = .bottom
            case .bottom: next = .left
            case .right: next = .top
            case .top: next = .right
            }
        }
        let nextOffset: CGFloat = atCorner ? ((current == .right || current == .top) ? 1 : 0) : 0.5
        setPlacement(edge: next, offset: nextOffset, screen: screen)
    }

    /// A diagram target chooses orientation and location in one operation.
    func selectPosition(_ target: String, orientation: DockPlacementOrientation) {
        guard let screen = dockScreen,
              let placement = DockPositionPreset(rawValue: target)?.placement(for: orientation) else { return }
        dismissPopovers()
        setPlacement(edge: placement.edge, offset: placement.offset, screen: screen)
    }

    func selectPosition(_ target: String) {
        guard let screen = dockScreen else { return }
        dismissPopovers()
        let orientation: DockPlacementOrientation = effectiveEdge.isVertical ? .vertical : .horizontal
        guard let preset = DockPositionPreset(rawValue: target),
              let placement = preset.placement(for: orientation) else {
            // Existing callers may still request the opposite centered edge;
            // selecting that edge explicitly changes orientation.
            switch target {
            case "top": setPlacement(edge: .top, offset: 0.5, screen: screen)
            case "bottom": setPlacement(edge: .bottom, offset: 0.5, screen: screen)
            case "left": setPlacement(edge: .left, offset: 0.5, screen: screen)
            case "right": setPlacement(edge: .right, offset: 0.5, screen: screen)
            default: break
            }
            return
        }
        let edge = placement.edge
        let offset = placement.offset
        setPlacement(edge: edge, offset: offset, screen: screen)
    }

    private func setPlacement(edge: DockPlacementEdge, offset: CGFloat, screen: NSScreen) {
        let nextDisplayID = Self.identifier(for: screen)
        let position: DockWindowPosition = edge.isVertical ? .freeVertical : .freeHorizontal
        guard DockPlacementPreferences.shared.edge != edge || self.offset != offset
                || displayID != nextDisplayID || DockyPreferences.shared.windowPosition != position else { return }
        DockPlacementPreferences.shared.edge = edge
        self.offset = offset
        displayID = nextDisplayID
        defaults.set(displayID, forKey: "docky.freePosition.display")
        DockyPreferences.shared.windowPosition = position
        mainWindow?.refreshFloatingPlacement()
    }

    private func dismissPopovers() {
        WindowPreviewWindowController.shared.dismissCurrent()
        if let tileID = WidgetExpansionWindowController.shared.activeSourceTileID {
            WidgetExpansionWindowController.shared.dismiss(sourceTileID: tileID)
        }
    }

    private static func identifier(for screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
    }
}

/// Screen-coordinate resize math shared by both dock orientations. The dock
/// grows inward from its anchored edge; movement along that edge is ignored.
enum DockResizeGeometry {
    static func contains(_ pointer: CGPoint, chrome: CGRect, edge: DockPlacementEdge, tolerance: CGFloat = 4) -> Bool {
        guard chrome.insetBy(dx: -tolerance, dy: -tolerance).contains(pointer) else { return false }
        let distance: CGFloat = switch edge {
        case .left: abs(pointer.x - chrome.maxX)
        case .right: abs(pointer.x - chrome.minX)
        case .bottom: abs(pointer.y - chrome.maxY)
        case .top: abs(pointer.y - chrome.minY)
        }
        return distance <= tolerance
    }

    static func tileSize(original: CGFloat, displacement: CGPoint, edge: DockPlacementEdge) -> CGFloat {
        let delta: CGFloat = switch edge {
        case .left: displacement.x
        case .right: -displacement.x
        case .bottom: displacement.y
        case .top: -displacement.y
        }
        return min(128, max(16, original + delta)).rounded()
    }
}
