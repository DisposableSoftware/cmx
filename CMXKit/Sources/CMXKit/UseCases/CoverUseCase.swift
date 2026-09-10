import CoreGraphics
import Foundation

/// Reads just the cover of a comic. Used by the Quick Look extensions, which
/// run in their own sandboxed processes and never touch reader state — hence
/// a plain Sendable use case rather than the @MainActor ReaderUseCase.
public protocol CoverUseCase: Sendable {
    /// - Parameter maxPixelSize: downsample the cover to fit this dimension;
    ///   nil decodes at full size.
    func cover(for url: URL, maxPixelSize: CGFloat?) async throws -> ComicCover
}

public enum CoverError: Error, LocalizedError, Equatable {
    case noPages
    case undecodableCover

    public var errorDescription: String? {
        switch self {
        case .noPages: return "No pages found in this archive."
        case .undecodableCover: return "The first page couldn't be decoded."
        }
    }
}

struct DefaultCoverUseCase: CoverUseCase {
    let archiveGateway: any ArchiveGateway
    let metadataGateway: any MetadataGateway

    func cover(for url: URL, maxPixelSize: CGFloat?) async throws -> ComicCover {
        // Off the calling thread: unzip + decode are both blocking.
        try await Task.detached(priority: .userInitiated) {
            let archive = try archiveGateway.openArchive(at: url)
            let entries = archive.entryPaths
            let pages = PageList.pages(fromEntries: entries)
            guard let first = pages.first else { throw CoverError.noPages }

            let data = try archive.data(forEntry: first.entryPath)
            let image = maxPixelSize.map { ImageDecoder.decodeThumbnail(data, maxPixelSize: $0) }
                ?? ImageDecoder.decode(data)
            guard let image else { throw CoverError.undecodableCover }

            // Metadata stays best-effort here too: never fail a preview over it.
            var metadata: ComicMetadata?
            if let infoPath = ComicInfoLocator.entry(in: entries),
               let xml = try? archive.data(forEntry: infoPath) {
                metadata = metadataGateway.metadata(fromXML: xml)
            }

            return ComicCover(image: image, metadata: metadata, pageCount: pages.count)
        }.value
    }
}
