import Foundation
import Testing
@testable import CMXKit

@Suite struct ArchiveFormatTests {
    @Test func detectsRar4And5Signatures() {
        // RAR 4.x: "Rar!\x1A\x07\x00"   RAR 5.x: "Rar!\x1A\x07\x01\x00"
        #expect(ArchiveFormat.format(ofMagic: [0x52, 0x61, 0x72, 0x21]) == .rar)
    }

    @Test func detectsZipVariants() {
        #expect(ArchiveFormat.format(ofMagic: [0x50, 0x4B, 0x03, 0x04]) == .zip) // local file
        #expect(ArchiveFormat.format(ofMagic: [0x50, 0x4B, 0x05, 0x06]) == .zip) // empty
        #expect(ArchiveFormat.format(ofMagic: [0x50, 0x4B, 0x07, 0x08]) == .zip) // spanned
    }

    @Test func rejectsOtherContent() {
        #expect(ArchiveFormat.format(ofMagic: [0x25, 0x50, 0x44, 0x46]) == .unrecognized) // %PDF
        #expect(ArchiveFormat.format(ofMagic: [0x89, 0x50, 0x4E, 0x47]) == .unrecognized) // PNG
        #expect(ArchiveFormat.format(ofMagic: [0x50, 0x4B]) == .unrecognized) // truncated
        #expect(ArchiveFormat.format(ofMagic: []) == .unrecognized)
    }

    @Test func missingFileIsUnrecognizedNotACrash() {
        #expect(ArchiveFormat.detect(at: URL(fileURLWithPath: "/no/such.cbz")) == .unrecognized)
    }
}

/// The user-facing half: a mislabeled RAR must explain itself.
@Suite struct MislabeledArchiveTests {
    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(
            forResource: name, withExtension: "cbz", subdirectory: "Fixtures"))
    }

    @Test func rarDisguisedAsCbzIsDetectedFromContent() throws {
        let url = try fixture("rar-disguised")
        #expect(ArchiveFormat.detect(at: url) == .rar)
    }

    @Test func openingADisguisedRarThrowsRarArchive() throws {
        let url = try fixture("rar-disguised")
        #expect(throws: ArchiveError.rarArchive("rar-disguised.cbz")) {
            _ = try ZipArchiveGateway().openArchive(at: url)
        }
    }

    @Test func rarErrorMessageNamesCbrAndTheFile() throws {
        let message = ArchiveError.rarArchive("Vol 3.cbz").localizedDescription
        #expect(message.contains("Vol 3.cbz"))
        #expect(message.contains(".cbr"))
        #expect(message.contains(".cbz"))
    }

    @Test func nonArchiveThrowsUnrecognizedFormat() throws {
        let url = try fixture("not-an-archive")
        #expect(throws: ArchiveError.unrecognizedFormat("not-an-archive.cbz")) {
            _ = try ZipArchiveGateway().openArchive(at: url)
        }
    }

    @Test func realCbzStillOpens() throws {
        let url = try fixture("sample")
        let archive = try ZipArchiveGateway().openArchive(at: url)
        #expect(!archive.entryPaths.isEmpty)
    }
}

@MainActor
@Suite struct ReaderMislabeledArchiveTests {
    /// The reader must show the explanation verbatim, not wrapped in a
    /// second "Couldn't open …" that repeats the filename.
    @Test func readerSurfacesRarMessageDirectly() async throws {
        let url = try #require(Bundle.module.url(
            forResource: "rar-disguised", withExtension: "cbz", subdirectory: "Fixtures"))
        let state = ReaderState()
        let useCase = DefaultReaderUseCase(
            archiveGateway: ZipArchiveGateway(),
            metadataGateway: ComicInfoMetadataGateway(),
            progressGateway: MockProgressGateway(),
            state: state
        )
        await useCase.openBook(at: url)

        let message = try #require(state.errorMessage)
        #expect(message == ArchiveError.rarArchive("rar-disguised.cbz").localizedDescription)
        #expect(!message.contains("Couldn't open"))
        #expect(state.book == nil)
        #expect(state.isLoading == false)
    }
}
