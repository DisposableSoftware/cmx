import CoreGraphics
import Foundation
import Testing
@testable import CMXKit

@Suite struct WindowFitTests {
    private let minimum = CGSize(width: 400, height: 500)
    private let chrome: CGFloat = 28
    private let bigScreen = CGSize(width: 2000, height: 1500)

    private func fit(
        _ aspect: CGFloat,
        current: CGSize,
        screen: CGSize? = nil
    ) -> CGSize? {
        WindowFit.contentSize(
            aspectRatio: aspect,
            currentContent: current,
            chromeHeight: chrome,
            visibleFrame: screen ?? bigScreen,
            minimum: minimum)
    }

    private let portraitPage: CGFloat = 2.0 / 3.0   // a normal comic page
    private let spreadPage: CGFloat = 2.0           // a double-page spread

    @Test func keepsHeightOfAnAlreadySizedWindowAndCorrectsWidth() throws {
        let size = try #require(fit(portraitPage, current: CGSize(width: 1200, height: 800)))
        #expect(size.height == 800)
        #expect(size.width == 533)   // 800 × 2/3
    }

    @Test func neverSizedWindowStartsFromAGenerousFractionOfTheScreen() throws {
        // A window still at its minimum has not been sized by the user.
        let size = try #require(fit(portraitPage, current: minimum))
        #expect(size.height == 1275)  // 85% of 1500
        #expect(size.width == 850)
    }

    @Test func matchesTheRequestedAspectRatio() throws {
        for aspect in [portraitPage, spreadPage, 1.0, 0.5] {
            let size = try #require(fit(aspect, current: CGSize(width: 600, height: 900)))
            let produced = size.width / size.height
            #expect(abs(produced - aspect) < 0.01, "aspect \(aspect) produced \(produced)")
        }
    }

    @Test func shrinksToFitANarrowScreenKeepingAspect() throws {
        // A spread at 900 tall wants 1800 wide; the screen allows only 95%×1600.
        let size = try #require(
            fit(spreadPage, current: CGSize(width: 600, height: 900),
                screen: CGSize(width: 1600, height: 1200)))
        #expect(size.width == 1520)
        #expect(size.height == 760)
        #expect(abs(size.width / size.height - spreadPage) < 0.01)
    }

    @Test func leavesRoomForWindowChrome() throws {
        // Tall page on a short screen: the title bar must not push it off.
        let screen = CGSize(width: 2000, height: 1000)
        let size = try #require(
            fit(portraitPage, current: CGSize(width: 600, height: 2000), screen: screen))
        #expect(size.height <= screen.height * 0.95 - chrome + 1)
    }

    @Test func growsToTheMinimumPreservingAspect() throws {
        let size = try #require(
            fit(spreadPage, current: CGSize(width: 600, height: 900),
                screen: CGSize(width: 500, height: 600)))
        // Minimums win over the screen fit, but the aspect ratio survives.
        #expect(size.width >= minimum.width)
        #expect(size.height >= minimum.height)
        #expect(abs(size.width / size.height - spreadPage) < 0.01)
    }

    @Test func rejectsNonsenseInputs() {
        #expect(fit(0, current: CGSize(width: 600, height: 800)) == nil)
        #expect(fit(-1.5, current: CGSize(width: 600, height: 800)) == nil)
        #expect(fit(.nan, current: CGSize(width: 600, height: 800)) == nil)
        #expect(fit(.infinity, current: CGSize(width: 600, height: 800)) == nil)
        #expect(WindowFit.contentSize(
            aspectRatio: portraitPage, currentContent: CGSize(width: 600, height: 800),
            chromeHeight: chrome, visibleFrame: .zero, minimum: minimum) == nil)
    }

    @Test func returnsWholePoints() throws {
        let size = try #require(fit(0.6431, current: CGSize(width: 600, height: 837)))
        #expect(size.width == size.width.rounded())
        #expect(size.height == size.height.rounded())
    }
}

@MainActor
@Suite struct CoverGeometryPublishingTests {
    private let url = URL(fileURLWithPath: "/tmp/fake.cbz")

    private func openBook(entries: [String]) async -> ReaderState {
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(entryPaths: entries)),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: MockProgressGateway(),
            state: state)
        await useCase.openBook(at: url)
        return state
    }

    @Test func openingABookPublishesItsGeometry() async throws {
        let state = await openBook(entries: ["a.png", "b.png"])
        let geometry = try #require(state.coverGeometry)
        #expect(geometry.bookURL == url)
        #expect(geometry.aspectRatio == 1)  // the 1×1 test PNG
    }

    @Test func aFailedOpenPublishesNothing() async throws {
        let state = await openBook(entries: ["notes.txt"])
        #expect(state.coverGeometry == nil)
        #expect(state.errorMessage != nil)
    }

    @Test func reopeningTheSameFileIsADistinctEvent() async throws {
        // The host must resize again even though the proportions are identical.
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(entryPaths: ["a.png"])),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: MockProgressGateway(),
            state: state)
        await useCase.openBook(at: url)
        let first = try #require(state.coverGeometry)
        await useCase.openBook(at: url)
        let second = try #require(state.coverGeometry)
        #expect(first != second)
        #expect(first.aspectRatio == second.aspectRatio)
    }
}
