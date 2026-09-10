import CoreGraphics

/// Which pages may share the window in dual-page mode. Pure, so the pairing
/// rule is testable without archives or windows.
public enum SpreadRules {
    /// A landscape page is already a two-page spread — scanned that way, or a
    /// wide layout page. Pairing it with another page would show four pages of
    /// content at once and squash both, so it is always shown alone.
    public static func isWide(_ image: PageImage) -> Bool {
        let cg = image.cgImage
        guard cg.height > 0 else { return false }
        return CGFloat(cg.width) / CGFloat(cg.height) > 1
    }

    /// Pair only when dual-page is on, a companion page exists, and neither
    /// page is itself a spread.
    public static func shouldPair(
        dualPage: Bool,
        current: PageImage,
        next: PageImage?
    ) -> Bool {
        guard dualPage, let next else { return false }
        return !isWide(current) && !isWide(next)
    }
}
