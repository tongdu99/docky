import CoreGraphics

/// CGWindow bounds use Quartz's global top-left coordinates; AppKit uses bottom-left coordinates.
enum HoverWindowHighlightGeometry {
    static func isValid(_ bounds: CGRect) -> Bool {
        bounds.origin.x.isFinite && bounds.origin.y.isFinite
            && bounds.width.isFinite && bounds.height.isFinite
            && bounds.width > 0 && bounds.height > 0
    }

    static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    static func appKitBounds(for windowBounds: CGRect, displayBounds: CGRect, screenFrame: CGRect) -> CGRect {
        let scaleX = screenFrame.width / displayBounds.width
        let scaleY = screenFrame.height / displayBounds.height
        return CGRect(
            x: screenFrame.minX + (windowBounds.minX - displayBounds.minX) * scaleX,
            y: screenFrame.maxY - (windowBounds.maxY - displayBounds.minY) * scaleY,
            width: windowBounds.width * scaleX,
            height: windowBounds.height * scaleY
        )
    }
}
