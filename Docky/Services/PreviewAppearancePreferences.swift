import Foundation
import Observation

enum PreviewCornerStyle: String, CaseIterable, Identifiable {
    case square
    case subtle
    case rounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: String(localized: "Square · 0 pt")
        case .subtle: String(localized: "Subtle · 6 pt")
        case .rounded: String(localized: "Rounded · 14 pt")
        }
    }

    var radius: CGFloat {
        switch self {
        case .square: 0
        case .subtle: 6
        case .rounded: 14
        }
    }
}

/// Shared by hover previews and the keyboard switcher so their appearance
/// changes together without changing either presentation's selection state.
@Observable final class PreviewAppearancePreferences {
    static let shared = PreviewAppearancePreferences()
    private let defaults: UserDefaults
    private static let cornerStyleKey = "docky.preview.cornerStyle"
    private static let highlightHoveredWindowKey = "docky.preview.highlightHoveredWindow"

    var cornerStyle: PreviewCornerStyle {
        didSet { defaults.set(cornerStyle.rawValue, forKey: Self.cornerStyleKey) }
    }

    var highlightsHoveredWindow: Bool {
        didSet { defaults.set(highlightsHoveredWindow, forKey: Self.highlightHoveredWindowKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cornerStyle = defaults.string(forKey: Self.cornerStyleKey)
            .flatMap(PreviewCornerStyle.init(rawValue:)) ?? .subtle
        highlightsHoveredWindow = defaults.object(forKey: Self.highlightHoveredWindowKey) as? Bool ?? true
    }
}
