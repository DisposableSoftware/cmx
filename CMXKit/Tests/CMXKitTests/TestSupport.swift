import Foundation
@testable import CMXKit

/// A real, decodable 1×1 PNG for tests that go through the image pipeline.
let tinyPNG = Data(
    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)!

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

    func openArchive(at url: URL) throws -> any ComicArchive { archive }
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
