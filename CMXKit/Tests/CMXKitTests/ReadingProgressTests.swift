import Foundation
import Testing
@testable import CMXKit

@Suite struct ReadingProgressTests {
    private func makeGateway() -> (DefaultsReadingProgressGateway, UserDefaults, String) {
        let suiteName = "cmx-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (DefaultsReadingProgressGateway(defaults: defaults), defaults, suiteName)
    }

    @Test func roundTrip() {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = URL(fileURLWithPath: "/comics/nice one.cbz")
        gateway.save(pageIndex: 17, for: url)
        #expect(gateway.savedPageIndex(for: url) == 17)
    }

    @Test func unknownPathHasNoProgress() {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(gateway.savedPageIndex(for: URL(fileURLWithPath: "/no/such/file.cbz")) == nil)
    }

    @Test func distinctFilesTrackIndependently() {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }
        let a = URL(fileURLWithPath: "/comics/a.cbz")
        let b = URL(fileURLWithPath: "/comics/b.cbz")
        gateway.save(pageIndex: 3, for: a)
        gateway.save(pageIndex: 8, for: b)
        #expect(gateway.savedPageIndex(for: a) == 3)
        #expect(gateway.savedPageIndex(for: b) == 8)
    }
}
