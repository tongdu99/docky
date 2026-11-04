import AppKit
import Combine
import SwiftUI

/// Shows a captured window in place without activating it or intercepting dock interactions.
@MainActor
final class HoverWindowHighlightWindowController: NSWindowController {
    static let shared = HoverWindowHighlightWindowController()

    private let hostingView = NSHostingView(rootView: HoverWindowHighlightView())
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let panel = HoverWindowHighlightPanel()
        super.init(window: panel)

        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        observeChanges { [weak self] in
            self?.window?.collectionBehavior = DockyPreferences.shared.windowSpaceBehavior
                .collectionBehavior(includesFullScreenAuxiliary: true)
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.dismiss() }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show(_ preview: FocusedWindowPreview) {
        guard HoverWindowHighlightGeometry.isValid(preview.screenBounds),
              preview.image.size.width > 0, preview.image.size.height > 0,
              let target = targetDisplay(for: preview.screenBounds),
              let window else {
            dismiss()
            return
        }

        let frame = target.screen.frame
        let windowBounds = HoverWindowHighlightGeometry.appKitBounds(
            for: preview.screenBounds,
            displayBounds: target.bounds,
            screenFrame: frame
        )
        hostingView.rootView = HoverWindowHighlightView(
            image: preview.image,
            windowBounds: windowBounds.offsetBy(dx: -frame.minX, dy: -frame.minY),
            displaySize: frame.size
        )
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
    }

    func dismiss() {
        window?.orderOut(nil)
        // Release the snapshot when the hover ends, including when a display disappears.
        hostingView.rootView = HoverWindowHighlightView()
    }

    private func targetDisplay(for bounds: CGRect) -> (screen: NSScreen, bounds: CGRect)? {
        NSScreen.screens.compactMap { screen -> (screen: NSScreen, bounds: CGRect)? in
            guard let identifier = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayBounds = CGDisplayBounds(identifier.uint32Value)
            guard HoverWindowHighlightGeometry.isValid(displayBounds),
                  HoverWindowHighlightGeometry.intersectionArea(bounds, displayBounds) > 0 else {
                return nil
            }
            return (screen, displayBounds)
        }
        .max {
            HoverWindowHighlightGeometry.intersectionArea(bounds, $0.bounds)
                < HoverWindowHighlightGeometry.intersectionArea(bounds, $1.bounds)
        }
    }
}

private final class HoverWindowHighlightPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovable = false
        // Below the dock and thumbnail popup, above ordinary application windows.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct HoverWindowHighlightView: View {
    var image: NSImage?
    var windowBounds: CGRect = .zero
    var displaySize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(image == nil ? 0 : 0.6)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: windowBounds.width, height: windowBounds.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
                    .position(x: windowBounds.midX, y: displaySize.height - windowBounds.midY)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

