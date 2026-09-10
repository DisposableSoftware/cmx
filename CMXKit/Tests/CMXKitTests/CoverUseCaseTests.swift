import Foundation
import Testing
@testable import CMXKit

@Suite struct CoverUseCaseTests {
    private let url = URL(fileURLWithPath: "/tmp/fake.cbz")

    private func makeUseCase(
        entries: [String],
        contents: [String: Data] = [:],
        metadata: ComicMetadata? = nil
    ) -> DefaultCoverUseCase {
        DefaultCoverUseCase(
            archiveGateway: MockArchiveGateway(
                archive: MockArchive(entryPaths: entries, contents: contents)),
            metadataGateway: MockMetadataGateway(result: metadata)
        )
    }

    @Test func picksNaturallyFirstPageAsCover() async throws {
        // page1 is the cover even though page10 sorts first lexicographically.
        let marker = Data("cover".utf8)
        let useCase = makeUseCase(
            entries: ["page10.png", "page2.png", "page1.png"],
            contents: ["page1.png": tinyPNG, "page2.png": marker, "page10.png": marker]
        )
        // Only page1 holds decodable data, so a successful decode proves the pick.
        let cover = try await useCase.cover(for: url, maxPixelSize: nil)
        #expect(cover.pageCount == 3)
    }

    @Test func reportsRealPageCountNotMetadataPageCount() async throws {
        var metadata = ComicMetadata()
        metadata.pageCount = 99 // lies, as ComicInfo.xml often does
        let useCase = makeUseCase(
            entries: ["a.png", "b.png", "ComicInfo.xml"], metadata: metadata)
        let cover = try await useCase.cover(for: url, maxPixelSize: nil)
        #expect(cover.pageCount == 2)
    }

    @Test func attachesMetadataWhenPresent() async throws {
        var metadata = ComicMetadata()
        metadata.series = "Saga"
        metadata.number = "3"
        let useCase = makeUseCase(entries: ["a.png", "ComicInfo.xml"], metadata: metadata)
        let cover = try await useCase.cover(for: url, maxPixelSize: nil)
        #expect(cover.metadata?.series == "Saga")
        #expect(cover.displayTitle(for: url) == "Saga #3")
    }

    @Test func missingMetadataFallsBackToFilename() async throws {
        let useCase = makeUseCase(entries: ["a.png"], metadata: nil)
        let cover = try await useCase.cover(for: url, maxPixelSize: nil)
        #expect(cover.metadata == nil)
        #expect(cover.displayTitle(for: url) == "fake")
    }

    @Test func imagelessArchiveThrowsNoPages() async {
        let useCase = makeUseCase(entries: ["ComicInfo.xml", "readme.txt"])
        await #expect(throws: CoverError.noPages) {
            _ = try await useCase.cover(for: url, maxPixelSize: nil)
        }
    }

    @Test func undecodableCoverThrows() async {
        let useCase = makeUseCase(
            entries: ["a.png"], contents: ["a.png": Data("not an image".utf8)])
        await #expect(throws: CoverError.undecodableCover) {
            _ = try await useCase.cover(for: url, maxPixelSize: nil)
        }
    }

    @Test func downsamplingProducesAnImage() async throws {
        let useCase = makeUseCase(entries: ["a.png"])
        let cover = try await useCase.cover(for: url, maxPixelSize: 64)
        #expect(cover.image.cgImage.width <= 64)
    }

    @Test func containerBuildsAWorkingUseCase() async {
        // Composition root smoke test: the extensions call exactly this.
        _ = CoverContainer.build()
    }
}

@Suite struct ComicInfoLocatorTests {
    @Test func findsRootEntryCaseInsensitively() {
        #expect(ComicInfoLocator.entry(in: ["a.png", "comicinfo.xml"]) == "comicinfo.xml")
        #expect(ComicInfoLocator.entry(in: ["a.png", "ComicInfo.xml"]) == "ComicInfo.xml")
    }

    @Test func prefersRootOverNested() {
        let entries = ["book/ComicInfo.xml", "ComicInfo.xml"]
        #expect(ComicInfoLocator.entry(in: entries) == "ComicInfo.xml")
    }

    @Test func fallsBackToNested() {
        #expect(ComicInfoLocator.entry(in: ["book/ComicInfo.xml"]) == "book/ComicInfo.xml")
    }

    @Test func nilWhenAbsent() {
        #expect(ComicInfoLocator.entry(in: ["a.png", "notes.txt"]) == nil)
    }
}
