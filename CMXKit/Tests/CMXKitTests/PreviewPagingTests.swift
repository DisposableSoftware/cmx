import CoreGraphics
import Foundation
import Testing
@testable import CMXKit

@MainActor
@Suite struct PreviewContainerTests {
    @Test func buildsAReaderTheExtensionCanPage() async {
        // The preview is a real reader: the container must hand back something
        // that opens and pages, not just a cover.
        let container = PreviewContainer.build()
        #expect(container.readerUseCase.state.book == nil)
    }

    @Test func viewModelNeedsOnlyTheReader() {
        // PreviewContainer conforms to HasReaderUseCase alone; if the view
        // model ever demands routing again this stops compiling.
        let container = PreviewContainer.build()
        _ = ReaderViewModel(useCases: container)
    }

    @Test func previewProgressStaysInMemory() {
        // A glance must not move the user's bookmark, and the sandboxed
        // extension cannot reach the app's defaults anyway.
        let gateway = InMemoryProgressGateway()
        let url = URL(fileURLWithPath: "/tmp/x.cbz")
        #expect(gateway.savedPageIndex(for: url) == nil)
        gateway.save(pageIndex: 4, for: url)
        #expect(gateway.savedPageIndex(for: url) == 4)
        // A fresh instance is a fresh session — nothing persisted.
        #expect(InMemoryProgressGateway().savedPageIndex(for: url) == nil)
    }
}

@MainActor
@Suite struct DownsampledDecodingTests {
    private let url = URL(fileURLWithPath: "/tmp/big.cbz")

    private func openBook(maxPixelSize: CGFloat?) async -> ReaderState {
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(
                entryPaths: ["p1.png", "p2.png"],
                contents: [
                    "p1.png": pngData(width: 1600, height: 2400),
                    "p2.png": pngData(width: 1600, height: 2400),
                ])),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: MockProgressGateway(),
            state: state,
            maxPixelSize: maxPixelSize)
        await useCase.openBook(at: url)
        return state
    }

    @Test func readerDecodesAtFullSize() async throws {
        let state = await openBook(maxPixelSize: nil)
        let image = try #require(state.currentImage)
        #expect(image.cgImage.width == 1600)
    }

    @Test func previewDecodesDownsampled() async throws {
        // Quick Look extensions have a tight memory budget; a full 1600x2400
        // page per cached slot is how they get jetsammed.
        let state = await openBook(maxPixelSize: 400)
        let image = try #require(state.currentImage)
        #expect(image.cgImage.width <= 400)
        #expect(image.cgImage.height <= 400)
    }

    @Test func downsamplingKeepsPagingWorking() async throws {
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(
                entryPaths: ["p1.png", "p2.png", "p3.png"],
                contents: [
                    "p1.png": pngData(width: 800, height: 1200),
                    "p2.png": pngData(width: 800, height: 1200),
                    "p3.png": pngData(width: 800, height: 1200),
                ])),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: InMemoryProgressGateway(),
            state: state,
            maxPixelSize: 300)
        await useCase.openBook(at: url)
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 1)
        #expect(state.currentImage != nil)
        await useCase.goToLastPage()
        #expect(state.currentPageIndex == 2)
    }
}
