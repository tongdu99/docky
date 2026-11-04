// Run from the repository root:
// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/PreviewAppearancePreferences.swift scripts/test_preview_appearance_preferences.swift -o /tmp/test-preview-appearance-preferences
// /tmp/test-preview-appearance-preferences
import Foundation
import Observation
import os

@main
struct PreviewAppearancePreferencesTests {
    static func main() {
        let suiteName = "docky.preview-preferences-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = PreviewAppearancePreferences(defaults: defaults)
        precondition(preferences.highlightsHoveredWindow, "Hover highlighting must default to enabled")
        precondition(preferences.cornerStyle == .subtle)

        let observedChange = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = preferences.highlightsHoveredWindow
        } onChange: {
            observedChange.withLock { $0 = true }
        }
        preferences.highlightsHoveredWindow = false
        precondition(observedChange.withLock { $0 }, "Disabling highlighting must notify observers so an active highlight can be dismissed")
        precondition(defaults.object(forKey: "docky.preview.highlightHoveredWindow") as? Bool == false)
        precondition(!PreviewAppearancePreferences(defaults: defaults).highlightsHoveredWindow,
                     "A stored false must survive relaunch instead of using the enabled default")

        preferences.cornerStyle = .square
        preferences.highlightsHoveredWindow = true
        let restored = PreviewAppearancePreferences(defaults: defaults)
        precondition(restored.highlightsHoveredWindow)
        precondition(restored.cornerStyle == .square, "Highlighting must preserve the independent corner preference")
        print("Preview appearance preferences tests passed")
    }
}
