import Foundation
import ImageIO

enum ImageDecoder {
    static func decode(_ data: Data) -> PageImage? {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options)
        else { return nil }
        return PageImage(cgImage: cgImage)
    }
}
