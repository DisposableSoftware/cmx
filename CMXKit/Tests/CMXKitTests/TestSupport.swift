import CoreGraphics
import Foundation
import ImageIO
@testable import CMXKit

/// A real, decodable 1×1 PNG for tests that go through the image pipeline.
let tinyPNG = Data(
    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)!

/// A solid-colour PNG of a given pixel size, for tests that care about page
/// proportions (portrait pages pair; wide pages never do).
func pngData(width: Int, height: Int) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

/// A decoded page of a given pixel size, for SpreadRules tests.
func pageImage(width: Int, height: Int) -> PageImage {
    ImageDecoder.decode(pngData(width: width, height: height))!
}

final class MockArchive: ComicArchive, @unchecked Sendable {
    let entryPaths: [String]
    let contents: [String: Data]

    init(entryPaths: [String], contents: [String: Data] = [:]) {
        self.entryPaths = entryPaths
        self.contents = contents
    }

    func data(forEntry path: String) throws -> Data {
        if let data = contents[path] { return data }
        if entryPaths.contains(path) { return tinyPNG }
        throw ArchiveError.entryNotFound(path)
    }
}

struct MockArchiveGateway: ArchiveGateway {
    let archive: MockArchive
    /// Per-path overrides, for tests that open more than one book.
    var archivesByPath: [String: MockArchive] = [:]

    func openArchive(at url: URL) throws -> any ComicArchive {
        archivesByPath[url.path] ?? archive
    }
}

struct MockMetadataGateway: MetadataGateway {
    var result: ComicMetadata?

    func metadata(fromXML data: Data) -> ComicMetadata? { result }
}

final class MockProgressGateway: ReadingProgressGateway, @unchecked Sendable {
    var saved: [String: Int] = [:]

    func savedPageIndex(for url: URL) -> Int? { saved[url.path] }
    func save(pageIndex: Int, for url: URL) { saved[url.path] = pageIndex }
}
