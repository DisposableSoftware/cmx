import Testing
@testable import CMXKit

@Suite struct ComicMetadataTests {
    @Test func displayTitleWithAllParts() {
        var m = ComicMetadata()
        m.series = "Saga"
        m.number = "12"
        m.title = "Endings"
        #expect(m.displayTitle == "Saga #12 — Endings")
    }

    @Test func displayTitleWithSeriesOnly() {
        var m = ComicMetadata()
        m.series = "Saga"
        #expect(m.displayTitle == "Saga")
    }

    @Test func displayTitleWithTitleOnly() {
        var m = ComicMetadata()
        m.title = "Endings"
        #expect(m.displayTitle == "Endings")
    }

    @Test func displayTitleNilWhenNothingSet() {
        #expect(ComicMetadata().displayTitle == nil)
    }
}
