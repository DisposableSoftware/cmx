import Foundation
import Testing
@testable import CMXKit

/// Integration tests against the real fixture archive in Fixtures/.
@Suite struct ZipArchiveGatewayTests {
    private func openFixture() throws -> any ComicArchive {
        let url = try #require(Bundle.module.url(
            forResource: "sample", withExtension: "cbz", subdirectory: "Fixtures"))
        return try ZipArchiveGateway().openArchive(at: url)
    }

    @Test func listsAllFileEntriesUnfiltered() throws {
        let archive = try openFixture()
        // The gateway reports raw entries; filtering is PageList's job.
        #expect(archive.entryPaths.contains("Thumbs.db"))
        #expect(archive.entryPaths.contains("ComicInfo.xml"))
    }

    @Test func pageListDerivesNaturalOrderFromFixture() throws {
        let archive = try openFixture()
        let pages = PageList.pages(fromEntries: archive.entryPaths)
        #expect(pages.map(\.entryPath) == ["page1.png", "page2.png", "page10.png"])
    }

    @Test func extractedPagesDecode() throws {
        let archive = try openFixture()
        let data = try archive.data(forEntry: "page1.png")
        #expect(ImageDecoder.decode(data) != nil)
    }

    @Test func fixtureMetadataParses() throws {
        let archive = try openFixture()
        let xml = try archive.data(forEntry: "ComicInfo.xml")
        let metadata = try #require(ComicInfoMetadataGateway().metadata(fromXML: xml))
        #expect(metadata.series == "Test Series")
        #expect(metadata.number == "3")
        #expect(metadata.title == "The Third One")
        #expect(metadata.year == 2020)
    }

    @Test func missingEntryThrows() throws {
        let archive = try openFixture()
        #expect(throws: ArchiveError.entryNotFound("nope.png")) {
            _ = try archive.data(forEntry: "nope.png")
        }
    }
}
