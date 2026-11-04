// swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Views/MainWindow/HoverWindowHighlightGeometry.swift scripts/test_hover_window_highlight_geometry.swift -o /tmp/test-hover-window-highlight-geometry
// /tmp/test-hover-window-highlight-geometry
import CoreGraphics

@main
struct HoverWindowHighlightGeometryTests {
    static func main() {
        let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        check(CGRect(x: 100, y: 200, width: 600, height: 400), quartzDisplay: main,
              appKitDisplay: main, expected: CGRect(x: 100, y: 480, width: 600, height: 400))

        // An external screen left of the primary display, with different vertical origins.
        check(CGRect(x: -1800, y: 300, width: 600, height: 400),
              quartzDisplay: CGRect(x: -1920, y: 200, width: 1920, height: 1080),
              appKitDisplay: CGRect(x: -1920, y: -200, width: 1920, height: 1080),
              expected: CGRect(x: -1800, y: 380, width: 600, height: 400))

        // A display above the primary display and a window crossing the display boundary.
        check(CGRect(x: 100, y: -100, width: 600, height: 400),
              quartzDisplay: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
              appKitDisplay: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
              expected: CGRect(x: 100, y: 780, width: 600, height: 400))

        // Preserve the full window size; clipping belongs to the selected display's view.
        let spanning = CGRect(x: 1800, y: 100, width: 600, height: 400)
        let right = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        precondition(HoverWindowHighlightGeometry.intersectionArea(spanning, right)
                     > HoverWindowHighlightGeometry.intersectionArea(spanning, main))
        check(spanning, quartzDisplay: right, appKitDisplay: right,
              expected: CGRect(x: 1800, y: 580, width: 600, height: 400))
        precondition(HoverWindowHighlightGeometry.intersectionArea(main, CGRect(x: 4000, y: 0, width: 10, height: 10)) == 0)
        precondition(!HoverWindowHighlightGeometry.isValid(.zero))
        precondition(!HoverWindowHighlightGeometry.isValid(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)))
        precondition(HoverWindowHighlightGeometry.isValid(spanning))
        print("Hover highlight multi-display geometry tests passed")
    }

    static func check(_ window: CGRect, quartzDisplay: CGRect, appKitDisplay: CGRect, expected: CGRect) {
        let result = HoverWindowHighlightGeometry.appKitBounds(for: window, displayBounds: quartzDisplay, screenFrame: appKitDisplay)
        precondition(result == expected, "Expected \(expected), received \(result)")
    }
}
