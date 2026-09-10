import Foundation

/// An opened comic: where it came from, its derived page list, and any metadata.
public struct Book: Equatable, Sendable {
    public let url: URL
    public let pages: [Page]
    public let metadata: ComicMetadata?

    public init(url: URL, pages: [Page], metadata: ComicMetadata?) {
        self.url = url
        self.pages = pages
        self.metadata = metadata
    }

    public var pageCount: Int { pages.count }

    /// Window title: metadata-derived when present, else the filename without extension.
    public var windowTitle: String {
        metadata?.displayTitle ?? url.deletingPathExtension().lastPathComponent
    }
}
