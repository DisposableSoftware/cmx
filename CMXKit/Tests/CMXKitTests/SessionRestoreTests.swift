import Foundation
import Testing
@testable import CMXKit

@MainActor
@Suite struct SessionRestoreTests {
    private let url = URL(fileURLWithPath: "/tmp/last.cbz")

    private func makeUseCase(
        progress: MockProgressGateway
    ) -> (DefaultReaderUseCase, ReaderState) {
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(entryPaths: ["a.png"])),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: progress,
            state: state)
        return (useCase, state)
    }

    @Test func openingABookRecordsItAsTheLastSession() async {
        let progress = MockProgressGateway()
        let (useCase, _) = makeUseCase(progress: progress)
        await useCase.openBook(at: url)
        #expect(progress.lastOpenedURL == url)
    }

    @Test func restoreReopensTheRecordedBook() async {
        let progress = MockProgressGateway()
        progress.lastOpenedURL = url
        let (useCase, state) = makeUseCase(progress: progress)
        await useCase.restoreLastSession()
        #expect(state.book?.url == url)
    }

    @Test func restoreDoesNothingWithNoRecordedSession() async {
        let (useCase, state) = makeUseCase(progress: MockProgressGateway())
        await useCase.restoreLastSession()
        #expect(state.book == nil)
        #expect(state.errorMessage == nil)
    }

    @Test func restoreNeverClobbersAnAlreadyOpenBook() async {
        // A document handed over at launch must win over the saved session.
        let progress = MockProgressGateway()
        progress.lastOpenedURL = URL(fileURLWithPath: "/tmp/other.cbz")
        let (useCase, state) = makeUseCase(progress: progress)
        await useCase.openBook(at: url)
        await useCase.restoreLastSession()
        #expect(state.book?.url == url)
    }

    @Test func aFailedOpenIsNotRecorded() async {
        let progress = MockProgressGateway()
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: MockArchiveGateway(archive: MockArchive(entryPaths: ["notes.txt"])),
            metadataGateway: MockMetadataGateway(result: nil),
            progressGateway: progress,
            state: state)
        await useCase.openBook(at: url)
        #expect(state.errorMessage != nil)
        #expect(progress.lastOpenedURL == nil)
    }
}

@Suite struct LastOpenedPersistenceTests {
    private func makeGateway() -> (DefaultsReadingProgressGateway, UserDefaults, String) {
        let suite = "cmx-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DefaultsReadingProgressGateway(defaults: defaults), defaults, suite)
    }

    @Test func roundTripsAnExistingFile() throws {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }

        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cmx-\(UUID().uuidString).cbz")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        gateway.setLastOpened(file)
        #expect(gateway.lastOpenedURL?.path == file.path)
    }

    @Test func aDeletedFileIsNoSessionRatherThanAnError() throws {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }

        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cmx-\(UUID().uuidString).cbz")
        try Data("x".utf8).write(to: file)
        gateway.setLastOpened(file)
        try FileManager.default.removeItem(at: file)

        #expect(gateway.lastOpenedURL == nil)
    }

    @Test func nothingRecordedYet() {
        let (gateway, defaults, suite) = makeGateway()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(gateway.lastOpenedURL == nil)
    }
}
