import Foundation
import ImageIO

enum ImageDecoder {
    /// Full-size decode for the reader.
    static func decode(_ data: Data) -> PageImage? {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options)
        else { return nil }
        return PageImage(cgImage: cgImage)
    }

    /// Downsampled decode for thumbnails: ImageIO scales while decoding, so a
    /// huge page never materializes at full size.
    static func decodeThumbnail(_ data: Data, maxPixelSize: CGFloat) -> PageImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        return PageImage(cgImage: cgImage)
    }
}
