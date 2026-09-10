import CMXKit
import QuickLookThumbnailing

/// Finder thumbnails for .cbz files: the comic's cover page.
///
/// Runs in its own sandboxed process — Quick Look grants read access to the
/// one file being thumbnailed, so no user-selected-file entitlement is
/// involved. Archive reading and page ordering come from CMXKit, and the
/// cover is decoded downsampled so a 4000px page never materializes at full
/// size. This target stays nonisolated: QLThumbnailProvider is a nonisolated
/// superclass, and there is no UI here to put on the main actor.
final class ThumbnailProvider: QLThumbnailProvider {
    private let coverUseCase = CoverContainer.build()

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, (any Error)?) -> Void
    ) {
        // Read everything off the request up front: it is not Sendable, so it
        // must not cross into the task.
        let url = request.fileURL
        let maxSize = request.maximumSize
        let maxPixel = max(maxSize.width, maxSize.height) * request.scale
        let useCase = coverUseCase
        let reply = HandlerBox(call: handler)

        Task {
            do {
                let cover = try await useCase.cover(for: url, maxPixelSize: maxPixel)
                let image = cover.image.cgImage
                let drawSize = Self.fit(
                    CGSize(width: image.width, height: image.height), into: maxSize)

                reply.call(QLThumbnailReply(contextSize: drawSize) { context in
                    // Fill the context's real pixel extent, not drawSize: on a
                    // Retina display Quick Look hands back a context scaled up
                    // by the screen factor, and drawing into the smaller
                    // point-sized rect leaves the page in the bottom-left
                    // quadrant (CoreGraphics origin is bottom-left).
                    // contextSize already carries the page's aspect ratio, so
                    // filling the whole context preserves proportions.
                    let pixelBounds = CGRect(
                        x: 0, y: 0,
                        width: CGFloat(context.width), height: CGFloat(context.height))
                    context.draw(image, in: pixelBounds)
                    return true
                }, nil)
            } catch {
                // Reporting an error means Finder falls back to the document icon.
                reply.call(nil, error)
            }
        }
    }

    /// Aspect-fit, so a tall comic page keeps its proportions in the icon.
    private static func fit(_ size: CGSize, into bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: max(1, size.width * scale),
                      height: max(1, size.height * scale))
    }
}

/// Quick Look documents its completion handler as safe to call asynchronously
/// from any thread, but the closure type carries no Sendable guarantee — this
/// box is what lets it cross into the task.
private struct HandlerBox: @unchecked Sendable {
    let call: (QLThumbnailReply?, (any Error)?) -> Void
}
