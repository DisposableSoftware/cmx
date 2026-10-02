import CoreGraphics

/// Composition root for the Quick Look *preview*, which unlike the thumbnail
/// is a real (if small) reader: it pages, caches and prefetches through the
/// same `ReaderUseCase` the app uses.
///
/// Two deliberate differences from `ReaderContainer`: pages are decoded
/// downsampled, because a Quick Look extension has a tight memory budget; and
/// reading progress is in-memory, because the sandboxed extension cannot reach
/// the app's defaults and a glance should not move the user's bookmark.
@MainActor
public struct PreviewContainer: HasReaderUseCase {
    public let readerUseCase: any ReaderUseCase

    public static func build(maxPixelSize: CGFloat = 2000) -> PreviewContainer {
        PreviewContainer(
            readerUseCase: DefaultReaderUseCase(
                archiveGateway: ZipArchiveGateway(),
                metadataGateway: ComicInfoMetadataGateway(),
                progressGateway: InMemoryProgressGateway(),
                state: ReaderState(),
                maxPixelSize: maxPixelSize
            )
        )
    }
}
