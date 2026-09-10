import CoreGraphics

/// Window-sizing geometry, kept pure so it can be tested without a window.
/// The host owns the actual NSWindow; this only decides the content size.
public enum WindowFit {
    /// Fraction of the screen a never-sized window should fill.
    private static let firstOpenHeightFraction: CGFloat = 0.85
    /// Fraction of the screen any window may occupy.
    private static let maximumFraction: CGFloat = 0.95

    /// The content size that matches `aspectRatio`.
    ///
    /// Rules, in order:
    /// 1. Anchor on the window's current height, so a window the user has
    ///    already sized keeps its height and only corrects its width. A window
    ///    still at its minimum has never been sized, so it starts from a
    ///    generous fraction of the screen instead.
    /// 2. Shrink to fit the screen, preserving the aspect ratio.
    /// 3. Grow to satisfy the minimum size, also preserving the aspect ratio —
    ///    minimums win over the screen fit, which only matters on a screen too
    ///    small for the minimum.
    ///
    /// - Returns: nil when the inputs cannot produce a sane size.
    public static func contentSize(
        aspectRatio: CGFloat,
        currentContent: CGSize,
        chromeHeight: CGFloat,
        visibleFrame: CGSize,
        minimum: CGSize
    ) -> CGSize? {
        guard aspectRatio.isFinite, aspectRatio > 0,
              visibleFrame.width > 0, visibleFrame.height > 0
        else { return nil }

        // 1. Anchor height.
        let neverSized = currentContent.height <= minimum.height + 1
        let baseHeight = neverSized
            ? visibleFrame.height * firstOpenHeightFraction
            : currentContent.height
        var height = baseHeight
        var width = height * aspectRatio

        // 2. Shrink into the screen. Chrome (the title bar) eats vertical room.
        let maxWidth = visibleFrame.width * maximumFraction
        let maxHeight = max(1, visibleFrame.height * maximumFraction - chromeHeight)
        let shrink = min(1, min(maxWidth / width, maxHeight / height))
        width *= shrink
        height *= shrink

        // 3. Grow to the minimum.
        let grow = max(1, max(minimum.width / width, minimum.height / height))
        width *= grow
        height *= grow

        return CGSize(width: width.rounded(), height: height.rounded())
    }
}
