import Foundation

/// Everything a Quick Look extension needs from a comic: its first page,
/// whatever metadata exists, and the real page count.
public struct ComicCover: @unchecked Sendable {
    public let image: PageImage
    public let metadata: ComicMetadata?
    public let pageCount: Int

    public init(image: PageImage, metadata: ComicMetadata?, pageCount: Int) {
        self.image = image
        self.metadata = metadata
        self.pageCount = pageCount
    }

    /// What to title a preview: metadata if present, else the filename.
    public func displayTitle(for url: URL) -> String {
        metadata?.displayTitle ?? url.deletingPathExtension().lastPathComponent
    }
}
