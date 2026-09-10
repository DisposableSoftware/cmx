import Foundation
import Testing
@testable import CMXKit

@MainActor
@Suite struct ReaderUseCaseTests {
    private let url = URL(fileURLWithPath: "/tmp/fake.cbz")

    private func makeUseCase(
        entries: [String],
        metadata: ComicMetadata? = nil,
        progress: MockProgressGateway = MockProgressGateway()
    ) -> (DefaultReaderUseCase, ReaderState, MockProgressGateway) {
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(entryPaths: entries)),
            metadataGateway: MockMetadataGateway(result: metadata),
            progressGateway: progress,
            state: state
        )
        return (useCase, state, progress)
    }

    @Test func openSetsBookAndShowsFirstPage() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png", "c.png"])
        await useCase.openBook(at: url)
        #expect(state.book?.pageCount == 3)
        #expect(state.currentPageIndex == 0)
        #expect(state.currentImage != nil)
        #expect(state.errorMessage == nil)
        #expect(state.isLoading == false)
    }

    @Test func previousAtFirstPageIsANoOp() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png"])
        await useCase.openBook(at: url)
        await useCase.goToPreviousPage()
        #expect(state.currentPageIndex == 0)
        #expect(state.errorMessage == nil)
    }

    @Test func nextAtLastPageIsANoOp() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png"])
        await useCase.openBook(at: url)
        await useCase.goToLastPage()
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 1)
        #expect(state.errorMessage == nil)
    }

    @Test func nextAdvancesAndSavesProgress() async {
        let (useCase, state, progress) = makeUseCase(entries: ["a.png", "b.png", "c.png"])
        await useCase.openBook(at: url)
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 1)
        #expect(progress.saved[url.path] == 1)
    }

    @Test func firstAndLastJump() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png", "c.png"])
        await useCase.openBook(at: url)
        await useCase.goToLastPage()
        #expect(state.currentPageIndex == 2)
        await useCase.goToFirstPage()
        #expect(state.currentPageIndex == 0)
    }

    @Test func resumesFromSavedProgress() async {
        let progress = MockProgressGateway()
        progress.saved[url.path] = 1
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png", "c.png"], progress: progress)
        await useCase.openBook(at: url)
        #expect(state.currentPageIndex == 1)
    }

    @Test func outOfRangeSavedProgressClampsToLastPage() async {
        let progress = MockProgressGateway()
        progress.saved[url.path] = 99
        let (useCase, state, _) = makeUseCase(entries: ["a.png", "b.png"], progress: progress)
        await useCase.openBook(at: url)
        #expect(state.currentPageIndex == 1)
    }

    @Test func archiveWithNoImagesSurfacesError() async {
        let (useCase, state, _) = makeUseCase(entries: ["ComicInfo.xml", "notes.txt"])
        await useCase.openBook(at: url)
        #expect(state.book == nil)
        #expect(state.errorMessage?.contains("No pages found") == true)
    }

    @Test func missingMetadataIsNotAnError() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png"], metadata: nil)
        await useCase.openBook(at: url)
        #expect(state.book?.metadata == nil)
        #expect(state.errorMessage == nil)
    }

    @Test func metadataDrivesWindowTitle() async {
        var metadata = ComicMetadata()
        metadata.series = "Saga"
        metadata.number = "3"
        let (useCase, state, _) = makeUseCase(
            entries: ["a.png", "ComicInfo.xml"], metadata: metadata)
        await useCase.openBook(at: url)
        #expect(state.windowTitle == "Saga #3")
    }

    @Test func navigationBeforeOpenIsANoOp() async {
        let (useCase, state, _) = makeUseCase(entries: ["a.png"])
        await useCase.goToNextPage()
        await useCase.goToLastPage()
        #expect(state.currentPageIndex == 0)
        #expect(state.errorMessage == nil)
    }
}
