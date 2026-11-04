//
//  WindowSwitcherOverlayWindowController.swift
//  Docky
//

import AppKit
import Combine
import SwiftUI

final class WindowSwitcherOverlayWindowController: NSWindowController {
    private weak var mainWindow: MainWindow?
    private var cancellables: Set<AnyCancellable> = []
    private let animationDuration: TimeInterval = 0.18
    private let preferences = DockyPreferences.shared

    private var usesInstantFocus: Bool {
        preferences.showsWindowSwitcherFocusPreview
            && preferences.windowSwitcherPreviewMode == .instantFocus
            && WindowSwitcherService.shared.resolvedLayout == .thumbnails
    }

    init(mainWindow: MainWindow) {
        self.mainWindow = mainWindow

        let overlayWindow = WindowSwitcherOverlayWindow()
        let hostingController = NSHostingController(rootView: WindowSwitcherOverlayView())
        overlayWindow.contentViewController = hostingController

        super.init(window: overlayWindow)

        prepareOverlayWindow()
        observeOverlayPresentation()
        observeMainWindow()
        observeSpaceBehavior()
        observePreviewMode()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func observeOverlayPresentation() {
        WindowSwitcherService.shared.$isPresented
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPresented in
                guard let self else { return }
                if isPresented {
                    self.presentOverlay()
                } else {
                    self.dismissOverlay()
                }
            }
            .store(in: &cancellables)
    }

    private func observeMainWindow() {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: mainWindow)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: mainWindow))
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: mainWindow))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)
    }

    private func presentOverlay() {
        guard let window else { return }

        updateFrame()
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        if usesInstantFocus {
            // Keep the selection visible without taking focus back from
            // the window that Instant Focus just activated.
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func dismissOverlay() {
        animateWindowAlpha(to: 0) { [weak self] in
            guard let self, let window = self.window else { return }

            window.ignoresMouseEvents = true
            window.orderOut(nil)
        }
    }

    private func prepareOverlayWindow() {
        guard let window else { return }

        updateFrame()
        window.collectionBehavior = preferences.windowSpaceBehavior.collectionBehavior(includesFullScreenAuxiliary: true)
        configureHiddenWindowState()
    }

    private func observeSpaceBehavior() {
        observeChanges { [weak self] in
            let behavior = DockyPreferences.shared.windowSpaceBehavior
            self?.window?.collectionBehavior = behavior.collectionBehavior(includesFullScreenAuxiliary: true)
        }
        .store(in: &cancellables)
    }

    private func observePreviewMode() {
        observeChanges { [weak self] in
            _ = DockyPreferences.shared.showsWindowSwitcherFocusPreview
            _ = DockyPreferences.shared.windowSwitcherPreviewMode
            self?.refreshOverlayPresentation()
        }
        .store(in: &cancellables)

        observeChanges { [weak self] in
            _ = DockyPreferences.shared.windowSwitcherLayout
            self?.refreshOverlayPresentation()
        }
        .store(in: &cancellables)

        PermissionsService.shared.$screenCapture
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshOverlayPresentation()
            }
            .store(in: &cancellables)
    }

    private func configureHiddenWindowState() {
        guard let window else { return }

        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderOut(nil)
    }

    private func refreshOverlayPresentation() {
        guard WindowSwitcherService.shared.isPresented else {
            configureHiddenWindowState()
            return
        }

        presentOverlay()
    }

    private func updateFrame() {
        guard let window else { return }
        let screenFrame = mainWindow?.screen?.frame ?? NSScreen.main?.frame ?? .zero
        guard !screenFrame.isEmpty else { return }
        window.setFrame(screenFrame, display: window.isVisible)
    }

    private func animateWindowAlpha(to alphaValue: CGFloat, completion: (() -> Void)? = nil) {
        guard let window else {
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = alphaValue
        } completionHandler: {
            completion?()
        }
    }
}

private final class WindowSwitcherOverlayWindow: NSWindow {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct WindowSwitcherOverlayView: View {
    @ObservedObject private var switcher = WindowSwitcherService.shared
    @Bindable private var preferences = DockyPreferences.shared
    @ObservedObject private var permissions = PermissionsService.shared

    @Bindable private var appearance = PreviewAppearancePreferences.shared
    private let interiorPadding: CGFloat = 8

    private var innerPreviewCornerRadius: CGFloat { appearance.cornerStyle.radius }
    private var containerCornerRadius: CGFloat { appearance.cornerStyle.radius }
    private var edgeContentCornerRadius: CGFloat { appearance.cornerStyle.radius }
    private var innerContentCornerRadius: CGFloat { appearance.cornerStyle.radius }

    private var resolvedLayout: WindowSwitcherLayout {
        preferences.windowSwitcherLayout
            .resolved(canCaptureThumbnails: permissions.screenCapture == .granted)
    }

    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        #endif

        GeometryReader { proxy in
            ZStack {
                // Stretches the ZStack to the GeometryReader's proposed size so
                // the centered child (cards or list) is centered against the
                // full screen, not the child's own bounds.
                Color.clear.ignoresSafeArea()

                if switcher.windows.isEmpty {
                    emptyStateCard
                } else if resolvedLayout == .thumbnails {
                    Color.black.opacity(switcher.focusedPreview == nil ? 0 : 0.6)
                        .ignoresSafeArea()

                    if let focusedPreview = switcher.focusedPreview {
                        FocusedWindowPreviewView(
                            preview: focusedPreview,
                            containerSize: proxy.size
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }

                    thumbnailLayout(containerSize: proxy.size)
                } else {
                    listLayout
                }
            }
            .animation(.easeInOut(duration: 0.18), value: switcher.focusedPreview?.windowIdentifier)
        }
    }

    private func thumbnailLayout(containerSize: CGSize) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(switcher.windows.enumerated()), id: \.element.id) { index, window in
                        let total = switcher.windows.count
                        let isFirst = index == 0
                        let isLast = index == total - 1
                        let leadingRadius = isFirst ? edgeContentCornerRadius : innerContentCornerRadius
                        let trailingRadius = isLast ? edgeContentCornerRadius : innerContentCornerRadius
                        WindowSwitcherCard(
                            window: window,
                            isSelected: window.windowIdentifier == switcher.selectedWindowIdentifier,
                            innerPreviewCornerRadius: innerPreviewCornerRadius,
                            leadingCornerRadius: leadingRadius,
                            trailingCornerRadius: trailingRadius
                        )
                        .id(window.windowIdentifier)
                    }
                }
                .padding(interiorPadding)
            }
            .frame(maxWidth: max(0, containerSize.width - 80))
            .fixedSize(horizontal: true, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
            .onChange(of: switcher.selectedWindowIdentifier) { selection in
                guard let selection else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    scrollProxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }

    private var listLayout: some View {
        WindowSwitcherListView(cornerRadius: containerCornerRadius, interiorPadding: interiorPadding)
    }

    private var emptyStateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.primary.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text("No windows available")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Nothing to switch to right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: containerCornerRadius, style: .continuous))
    }
}

private struct WindowSwitcherListView: View {
    let cornerRadius: CGFloat
    let interiorPadding: CGFloat

    @ObservedObject private var switcher = WindowSwitcherService.shared

    private let listWidth: CGFloat = 360
    private let rowHeight: CGFloat = 52
    private let maxVisibleRows: Int = 8

    private var edgeRowCornerRadius: CGFloat {
        cornerRadius
    }

    private var innerRowCornerRadius: CGFloat {
        cornerRadius
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(Array(switcher.windows.enumerated()), id: \.element.id) { index, window in
                        let total = switcher.windows.count
                        let isFirst = index == 0
                        let isLast = index == total - 1
                        let topRadius = isFirst ? edgeRowCornerRadius : innerRowCornerRadius
                        let bottomRadius = isLast ? edgeRowCornerRadius : innerRowCornerRadius
                        WindowSwitcherListRow(
                            window: window,
                            isSelected: window.windowIdentifier == switcher.selectedWindowIdentifier,
                            height: rowHeight,
                            topCornerRadius: topRadius,
                            bottomCornerRadius: bottomRadius
                        )
                        .id(window.windowIdentifier)
                    }
                }
                .padding(interiorPadding)
            }
            .frame(width: listWidth)
            .frame(maxHeight: CGFloat(maxVisibleRows) * rowHeight + CGFloat(maxVisibleRows - 1) * 6 + interiorPadding * 2)
            .fixedSize(horizontal: true, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onChange(of: switcher.selectedWindowIdentifier) { selection in
                guard let selection else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    scrollProxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }
}

private struct WindowSwitcherListRow: View {
    let window: AppWindow
    let isSelected: Bool
    let height: CGFloat
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

    @ObservedObject private var switcher = WindowSwitcherService.shared
    @ObservedObject private var workspace = WorkspaceService.shared

    private let iconSize: CGFloat = 28

    private var rowShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: topCornerRadius,
                bottomLeading: bottomCornerRadius,
                bottomTrailing: bottomCornerRadius,
                topTrailing: topCornerRadius
            ),
            style: .continuous
        )
    }

    private var displayTitle: String {
        window.isMinimized
            ? "\(window.windowTitle) \(String(localized: "(minimized)"))"
            : window.windowTitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: IconCacheService.shared.displayedIcon(forBundleIdentifier: window.bundleIdentifier))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(window.appDisplayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Selected window")
            }

            if window.isMinimized {
                Image(systemName: "minus.diamond.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.55))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background {
            rowShape
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .overlay {
                    rowShape
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .background {
            ContextActionMenuPresenter(
                actionProvider: contextActions(modifierFlags:),
                onPresentationChanged: switcher.setContextMenuPresented
            )
        }
        .contentShape(rowShape)
        .onHover { isHovering in
            if isHovering {
                switcher.selectWindow(withIdentifier: window.windowIdentifier)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    private func contextActions(modifierFlags: NSEvent.ModifierFlags) -> [ContextAction] {
        let dismiss = { switcher.dismiss() }
        var actions: [ContextAction] = [
            .action(String(localized: "Focus Window")) {
                dismiss()
                _ = workspace.focus(window: window)
            },
            .divider,
        ]
        actions.append(contentsOf: windowMenuContextActions(for: window, dismiss: dismiss))
        actions.append(contentsOf: [
            .divider,
            .action(String(localized: "Close Window"), isDestructive: true) {
                if workspace.close(window: window) {
                    switcher.removeWindow(withIdentifier: window.windowIdentifier)
                }
            },
            .divider,
            .action(String(localized: "Focus App")) {
                dismiss()
                workspace.focusApplication(bundleIdentifier: window.bundleIdentifier)
            },
            .action(String(localized: "Hide App")) {
                dismiss()
                workspace.hide(bundleIdentifier: window.bundleIdentifier)
            },
            .action(String(localized: "Quit")) {
                dismiss()
                workspace.quit(bundleIdentifier: window.bundleIdentifier)
            },
        ])
        return actions
    }
}

private struct FocusedWindowPreviewView: View {
    let preview: FocusedWindowPreview
    let containerSize: CGSize

    var body: some View {
        Image(nsImage: preview.image)
            .resizable()
            .interpolation(.high)
            .frame(width: previewSize.width, height: previewSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .position(previewCenter)
    }

    private var previewSize: CGSize {
        CGSize(
            width: min(preview.screenBounds.width, containerSize.width),
            height: min(preview.screenBounds.height, containerSize.height)
        )
    }

    private var previewCenter: CGPoint {
        CGPoint(
            x: min(max(preview.screenBounds.minX + (previewSize.width / 2), previewSize.width / 2), containerSize.width - (previewSize.width / 2)),
            y: min(max(preview.screenBounds.minY + (previewSize.height / 2), previewSize.height / 2), containerSize.height - (previewSize.height / 2))
        )
    }
}

private struct WindowSwitcherCard: View {
    let window: AppWindow
    let isSelected: Bool
    let innerPreviewCornerRadius: CGFloat
    let leadingCornerRadius: CGFloat
    let trailingCornerRadius: CGFloat
    @ObservedObject private var switcher = WindowSwitcherService.shared
    @ObservedObject private var workspace = WorkspaceService.shared
    @State private var isPreviewHovered = false
    @State private var isMoreMenuPresented = false

    private let previewWidth: CGFloat = 180
    private let previewHeight: CGFloat = 102

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: leadingCornerRadius,
                bottomLeading: leadingCornerRadius,
                bottomTrailing: trailingCornerRadius,
                topTrailing: trailingCornerRadius
            ),
            style: .continuous
        )
    }

    private var displayTitle: String {
        window.isMinimized
            ? "\(window.windowTitle) \(String(localized: "(minimized)"))"
            : window.windowTitle
    }

    var body: some View {
        VStack(spacing: 12) {
            previewSurface

            VStack(spacing: 4) {
                Text(displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(window.appDisplayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 180)
        }
        .padding(12)
        .background {
            cardShape
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .overlay {
                    cardShape
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }
        }
        .background {
            ContextActionMenuPresenter(
                actionProvider: contextActions(modifierFlags:),
                onPresentationChanged: switcher.setContextMenuPresented
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(cardShape)
        .onHover { isHovering in
            if isHovering {
                switcher.selectWindow(withIdentifier: window.windowIdentifier)
            }
        }
        .animation(.easeInOut(duration: 0.14), value: isSelected)
    }

    private var previewSurface: some View {
        Group {
            if let preview = switcher.windowPreview(for: window) {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: previewWidth, maxHeight: previewHeight)
            } else {
                Color.black.opacity(0.01)
                    .frame(maxWidth: previewWidth, maxHeight: previewHeight)
            }
        }
        .frame(width: previewWidth, height: previewHeight)
        // Desaturate the thumbnail for minimized windows so a stale
        // capture reads as "suspended" at a glance, paired with the
        // diamond badge in the bottom-right corner.
        .saturation(window.isMinimized ? 0 : 1)
        .opacity(window.isMinimized ? 0.7 : 1)
        .clipShape(RoundedRectangle(cornerRadius: innerPreviewCornerRadius, style: .continuous))
        .overlay {
            if window.isMinimized {
                minimizedBadge
            }
        }
        .overlay(alignment: .topLeading) {
            if isPreviewHovered || isMoreMenuPresented {
                MoreActionsButton(
                    onPresentationChanged: { presented in
                        isMoreMenuPresented = presented
                        switcher.setContextMenuPresented(presented)
                    },
                    actionProvider: contextActions(modifierFlags:)
                )
                .padding(6)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            isPreviewHovered = hovering
        }
        .animation(.easeInOut(duration: 0.12), value: isPreviewHovered)
    }

    private var minimizedBadge: some View {
        Image(systemName: "minus.diamond.fill")
            .font(.system(size: 32, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.55))
            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
    }

    private func contextActions(modifierFlags: NSEvent.ModifierFlags) -> [ContextAction] {
        let dismiss = { switcher.dismiss() }
        var actions: [ContextAction] = [
            .action(String(localized: "Focus Window")) {
                dismiss()
                _ = workspace.focus(window: window)
            },
            .divider,
        ]
        actions.append(contentsOf: windowMenuContextActions(for: window, dismiss: dismiss))
        actions.append(contentsOf: [
            .divider,
            .action(String(localized: "Close Window"), isDestructive: true) {
                if workspace.close(window: window) {
                    switcher.removeWindow(withIdentifier: window.windowIdentifier)
                }
            },
            .divider,
            .action(String(localized: "Focus App")) {
                dismiss()
                workspace.focusApplication(bundleIdentifier: window.bundleIdentifier)
            },
            .action(String(localized: "Hide App")) {
                dismiss()
                workspace.hide(bundleIdentifier: window.bundleIdentifier)
            },
            .action(String(localized: "Quit")) {
                dismiss()
                workspace.quit(bundleIdentifier: window.bundleIdentifier)
            },
        ])
        return actions
    }
}
