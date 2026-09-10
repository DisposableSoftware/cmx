import Foundation
import Testing
@testable import CMXKit

@Suite struct SpreadRulesTests {
    private let portrait = pageImage(width: 800, height: 1200)
    private let wide = pageImage(width: 1600, height: 1200)   // a spread scan
    private let square = pageImage(width: 1000, height: 1000)

    @Test func landscapePagesAreWide() {
        #expect(SpreadRules.isWide(wide))
        #expect(!SpreadRules.isWide(portrait))
        #expect(!SpreadRules.isWide(square))  // square is pairable
    }

    @Test func pairsTwoPortraitPages() {
        #expect(SpreadRules.shouldPair(dualPage: true, current: portrait, next: portrait))
    }

    @Test func neverPairsWhenEitherPageIsAlreadyASpread() {
        // The whole point: a wide layout page stands alone.
        #expect(!SpreadRules.shouldPair(dualPage: true, current: wide, next: portrait))
        #expect(!SpreadRules.shouldPair(dualPage: true, current: portrait, next: wide))
        #expect(!SpreadRules.shouldPair(dualPage: true, current: wide, next: wide))
    }

    @Test func neverPairsWithoutACompanionOrWhenModeIsOff() {
        #expect(!SpreadRules.shouldPair(dualPage: true, current: portrait, next: nil))
        #expect(!SpreadRules.shouldPair(dualPage: false, current: portrait, next: portrait))
    }
}

@MainActor
@Suite struct DualPageTests {
    private let url = URL(fileURLWithPath: "/tmp/dual.cbz")

    /// `sizes` gives each page's pixel dimensions, in page order.
    private func open(_ sizes: [(Int, Int)]) async -> (DefaultReaderUseCase, ReaderState) {
        var entries: [String] = []
        var contents: [String: Data] = [:]
        for (i, size) in sizes.enumerated() {
            let name = "page\(i + 1).png"
            entries.append(name)
            contents[name] = pngData(width: size.0, height: size.1)
        }
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(
                archive: MockArchive(entryPaths: entries, contents: contents)),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: MockProgressGateway(),
            state: state)
        await useCase.openBook(at: url)
        return (useCase, state)
    }

    private let portrait = (800, 1200)
    private let wide = (1600, 1200)

    @Test func startsSinglePage() async {
        let (_, state) = await open([portrait, portrait])
        #expect(state.isDualPage == false)
        #expect(state.secondaryImage == nil)
        #expect(state.displayedPageCount == 1)
    }

    @Test func togglingShowsTwoPagesInPlace() async {
        let (useCase, state) = await open([portrait, portrait, portrait])
        await useCase.toggleDualPage()
        #expect(state.isDualPage)
        #expect(state.secondaryImage != nil)
        #expect(state.currentPageIndex == 0)  // no page turn from toggling
        #expect(state.displayedPageCount == 2)
    }

    @Test func togglingBackReturnsToOnePage() async {
        let (useCase, state) = await open([portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.toggleDualPage()
        #expect(state.isDualPage == false)
        #expect(state.secondaryImage == nil)
    }

    @Test func advancingSkipsBothVisiblePages() async {
        let (useCase, state) = await open([portrait, portrait, portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 2)
        #expect(state.secondaryImage != nil)   // showing 3–4
    }

    @Test func goingBackStepsByTwo() async {
        let (useCase, state) = await open([portrait, portrait, portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.goToNextPage()
        await useCase.goToPreviousPage()
        #expect(state.currentPageIndex == 0)
    }

    @Test func firstPageStaysReachableFromAnOddPosition() async {
        // Toggling mid-book can leave you on an odd index; page 1 must still
        // be reachable rather than the stride stepping past it.
        let (useCase, state) = await open([portrait, portrait, portrait])
        await useCase.goToNextPage()          // single mode -> index 1
        await useCase.toggleDualPage()        // showing 2–3
        #expect(state.currentPageIndex == 1)
        await useCase.goToPreviousPage()
        #expect(state.currentPageIndex == 0)
    }

    @Test func aWidePageIsShownAlone() async {
        let (useCase, state) = await open([wide, portrait, portrait])
        await useCase.toggleDualPage()
        #expect(state.secondaryImage == nil)   // the spread stands alone
        #expect(state.displayedPageCount == 1)
    }

    @Test func aPortraitPageIsNotPairedWithAWideOne() async {
        let (useCase, state) = await open([portrait, wide, portrait])
        await useCase.toggleDualPage()
        #expect(state.secondaryImage == nil)
    }

    @Test func advancingPastASoloWidePageMovesOnlyOne() async {
        let (useCase, state) = await open([wide, portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 1)   // stepped by 1, not 2
        #expect(state.secondaryImage != nil)   // now pairing 2–3
    }

    @Test func lastPageShowsAloneWhenNoCompanionRemains() async {
        let (useCase, state) = await open([portrait, portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.goToNextPage()
        #expect(state.currentPageIndex == 2)
        #expect(state.secondaryImage == nil)
        await useCase.goToNextPage()           // nothing left
        #expect(state.currentPageIndex == 2)
    }

    @Test func indicatorNamesBothPages() async {
        let (useCase, state) = await open([portrait, portrait, portrait, portrait])
        await useCase.toggleDualPage()
        #expect(state.pageIndicator == "1–2 / 4")
        await useCase.goToNextPage()
        #expect(state.pageIndicator == "3–4 / 4")
        await useCase.toggleDualPage()
        #expect(state.pageIndicator == "3 / 4")
    }

    @Test func dualPageSurvivesOpeningAnotherBook() async {
        // It is a view preference, so it stays on and the new book re-pairs.
        let (useCase, state) = await open([portrait, portrait])
        await useCase.toggleDualPage()
        await useCase.openBook(at: URL(fileURLWithPath: "/tmp/another.cbz"))
        #expect(state.isDualPage)
        #expect(state.secondaryImage != nil)
    }

    @Test func aFailedOpenKeepsTheCurrentBookOnScreen() async {
        // Opening a broken file must not blank out what you were reading; the
        // error explains the failure and the current spread stays put.
        let good = MockArchive(entryPaths: ["p1.png", "p2.png"], contents: [
            "p1.png": pngData(width: 800, height: 1200),
            "p2.png": pngData(width: 800, height: 1200),
        ])
        let imageless = MockArchive(entryPaths: ["notes.txt"])
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(
                archive: good, archivesByPath: ["/tmp/broken.cbz": imageless]),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: MockProgressGateway(),
            state: state)

        await useCase.openBook(at: url)
        await useCase.toggleDualPage()
        #expect(state.secondaryImage != nil)

        await useCase.openBook(at: URL(fileURLWithPath: "/tmp/broken.cbz"))
        #expect(state.errorMessage?.contains("No pages found") == true)
        #expect(state.book?.url == url)
        #expect(state.secondaryImage != nil)
    }
}
