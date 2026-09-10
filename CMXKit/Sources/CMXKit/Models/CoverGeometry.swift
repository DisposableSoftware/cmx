import CoreGraphics
import Foundation

/// Published once per successful open so the host can size its window to the
/// page. Carries a fresh `id` because the value is an event, not a condition:
/// reopening the same file, or a different file with the same proportions,
/// must still trigger a resize.
public struct CoverGeometry: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let bookURL: URL
    /// Width ÷ height of the page shown when the book opened.
    public let aspectRatio: CGFloat

    public init(id: UUID = UUID(), bookURL: URL, aspectRatio: CGFloat) {
        self.id = id
        self.bookURL = bookURL
        self.aspectRatio = aspectRatio
    }
}
