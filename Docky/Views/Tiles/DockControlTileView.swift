import AppKit
import SwiftUI

/// A compact in-dock grip. The controller distinguishes a click from a drag.
struct DockControlTileView: View {
    @State private var isShowingPositions = false
    @Bindable private var placement = DockPlacementPreferences.shared
    @Bindable private var preferences = DockyPreferences.shared

    var body: some View {
        DockBarButtonRepresentable(
            isVertical: preferences.windowPosition.resolved(systemOrientation: DockSettingsService.shared.orientation).isVertical,
            isCollapsed: placement.isCollapsed,
            onClick: { FloatingDockController.active?.toggleCollapsed() },
            onChoosePosition: { isShowingPositions = true }
        )
        .popover(isPresented: $isShowingPositions, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dock Position").font(.headline)
                DockPositionPicker(onSelect: { isShowingPositions = false })
            }
            .padding(14)
            .frame(width: 330)
        }
        .onChange(of: placement.isCollapsed) { _ in isShowingPositions = false }
    }
}

private struct DockBarButtonRepresentable: NSViewRepresentable {
    let isVertical: Bool
    let isCollapsed: Bool
    let onClick: () -> Void
    let onChoosePosition: () -> Void

    func makeNSView(context: Context) -> DockBarButton {
        let button = DockBarButton(frame: .zero)
        button.isBordered = false
        button.title = ""
        button.setButtonType(.momentaryChange)
        button.target = button
        button.action = #selector(DockBarButton.activate)
        return button
    }

    func updateNSView(_ button: DockBarButton, context: Context) {
        button.isVertical = isVertical
        button.onClick = onClick
        button.onChoosePosition = onChoosePosition
        button.toolTip = isCollapsed
            ? "Click to expand. Right-click to choose a position. Drag to move when unlocked."
            : "Click to collapse. Right-click to choose a position. Drag to move when unlocked."
        button.setAccessibilityLabel(isCollapsed ? "Expand Dock" : "Collapse Dock")
        button.needsDisplay = true
    }
}

private final class DockBarButton: NSButton {
    var isVertical = true
    var onClick: (() -> Void)?
    var onChoosePosition: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc func activate() { onClick?() }
    override func mouseDown(with event: NSEvent) {
        if FloatingDockController.active?.beginControlDrag(with: event) == true { return }
        super.mouseDown(with: event)
    }
    override func rightMouseDown(with event: NSEvent) { onChoosePosition?() }

    override func draw(_ dirtyRect: NSRect) {
        // Leave the grip transparent so it shares the dock's material.
        (isHighlighted ? NSColor.controlAccentColor : NSColor.secondaryLabelColor).setFill()
        for row in 0..<(isVertical ? 2 : 3) {
            for column in 0..<(isVertical ? 3 : 2) {
                let x = bounds.midX + CGFloat(column) * 6 - (isVertical ? 6 : 3)
                let y = bounds.midY + CGFloat(row) * 6 - (isVertical ? 3 : 6)
                NSBezierPath(ovalIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)).fill()
            }
        }
    }
}

/// Shared by Settings and the optional bar. Each miniature dock selects
/// its placement and orientation together; viewing the diagram never moves it.
struct DockPositionPicker: View {
    var onSelect: (() -> Void)? = nil
    @Bindable private var preferences = DockyPreferences.shared
    private let dockSettings = DockSettingsService.shared

    private var orientation: DockPlacementOrientation {
        preferences.windowPosition.resolved(systemOrientation: dockSettings.orientation).isVertical ? .vertical : .horizontal
    }

    private var selectedTarget: DockPositionTarget? {
        guard let preset = FloatingDockController.active?.selectedPosition.flatMap(DockPositionPreset.init(rawValue:)) else { return nil }
        return DockPositionTarget(preset: preset, orientation: orientation)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.035))
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                    VStack(spacing: 4) {
                        Text("Dock Position").font(.subheadline.weight(.semibold))
                        Text("Click a dock to place it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                    ForEach(DockPositionTarget.all) { target in
                        positionButton(target)
                            .position(center(for: target, in: proxy.size))
                    }
                }
            }
            .aspectRatio(1.65, contentMode: .fit)
            Text(selectedTarget?.title ?? String(localized: "Custom along edge"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 580)
    }

    private func positionButton(_ target: DockPositionTarget) -> some View {
        let vertical = target.orientation == .vertical
        let selected = selectedTarget == target
        return Button {
            FloatingDockController.active?.selectPosition(target.preset.rawValue, orientation: target.orientation)
            onSelect?()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: selected ? 2 : 1)
                miniatureDock(vertical: vertical, selected: selected)
            }
            .frame(width: vertical ? 28 : 46, height: vertical ? 46 : 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(target.title)
        .accessibilityLabel(target.title)
        .accessibilityValue(selected ? String(localized: "Selected") : "")
    }

    @ViewBuilder
    private func miniatureDock(vertical: Bool, selected: Bool) -> some View {
        let color = selected ? Color.accentColor : Color.secondary
        Group {
            if vertical {
                VStack(spacing: 4) {
                    ForEach(0..<3) { _ in Circle().fill(.white).frame(width: 4, height: 4) }
                }
                .frame(width: 12, height: 34)
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in Circle().fill(.white).frame(width: 4, height: 4) }
                }
                .frame(width: 34, height: 12)
            }
        }
        .background(color, in: RoundedRectangle(cornerRadius: 3))
    }

    private func center(for target: DockPositionTarget, in size: CGSize) -> CGPoint {
        // Corner horizontal targets sit beside their vertical counterparts.
        // The inset positions keep all twelve hit areas separate at popup size.
        if target.orientation == .vertical {
            let right = [.topRight, .right, .bottomRight].contains(target.preset)
            let y: CGFloat = switch target.preset {
            case .topLeft, .topRight: 38
            case .bottomLeft, .bottomRight: size.height - 38
            default: size.height / 2
            }
            return CGPoint(x: right ? size.width - 20 : 20, y: y)
        }
        let x: CGFloat = switch target.preset {
        case .topLeft, .bottomLeft: 70
        case .topRight, .bottomRight: size.width - 70
        default: size.width / 2
        }
        let top = [.topLeft, .top, .topRight].contains(target.preset)
        return CGPoint(x: x, y: top ? 20 : size.height - 20)
    }
}
