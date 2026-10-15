import CoreGraphics

/// The screen values `NotchGeometry` needs, copied out of `NSScreen` so the math stays testable.
public struct NotchScreenInfo: Sendable, Equatable {
    /// Screen frame in global AppKit coordinates (origin at bottom-left).
    public var frame: CGRect
    /// `NSScreen.safeAreaInsets.top`
    public var safeAreaTop: CGFloat
    /// `NSScreen.auxiliaryTopLeftArea?.width`
    public var leftAreaWidth: CGFloat?
    /// `NSScreen.auxiliaryTopRightArea?.width`
    public var rightAreaWidth: CGFloat?

    public init(frame: CGRect, safeAreaTop: CGFloat, leftAreaWidth: CGFloat?, rightAreaWidth: CGFloat?) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.leftAreaWidth = leftAreaWidth
        self.rightAreaWidth = rightAreaWidth
    }
}

/// Rectangles around the notch, all in global AppKit coordinates.
public struct NotchGeometry: Sendable, Equatable {
    public static let expandedSize = CGSize(width: 480, height: 200)
    /// How far inside each side of the notch the hover zone starts, so passing
    /// the cursor near the notch does not open the panel by accident.
    public static let hoverInset: CGFloat = 3

    public let notchRect: CGRect
    /// The notch narrowed by `hoverInset` on the left and right; nothing below it.
    public let hoverRect: CGRect
    /// The expanded panel: centered on the notch, flush with the top of the screen.
    public let panelRect: CGRect

    /// Returns nil for a screen without a notch.
    public init?(screen: NotchScreenInfo) {
        guard screen.safeAreaTop > 0,
              let left = screen.leftAreaWidth,
              let right = screen.rightAreaWidth else { return nil }
        let frame = screen.frame
        notchRect = CGRect(x: frame.minX + left,
                           y: frame.maxY - screen.safeAreaTop,
                           width: frame.width - left - right,
                           height: screen.safeAreaTop)
        hoverRect = notchRect.insetBy(dx: Self.hoverInset, dy: 0)
        let size = Self.expandedSize
        panelRect = CGRect(x: notchRect.midX - size.width / 2,
                           y: frame.maxY - size.height,
                           width: size.width,
                           height: size.height)
    }
}
