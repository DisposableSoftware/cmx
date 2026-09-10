import Foundation

@MainActor
final class DefaultReaderUseCase: ReaderUseCase {
    let state: ReaderState
    private let archiveGateway: any ArchiveGateway
    private let metadataGateway: any MetadataGateway
    private let progressGateway: any ReadingProgressGateway
    private var session: ArchiveSession?

    init(
        archiveGateway: any ArchiveGateway,
        metadataGateway: any MetadataGateway,
        progressGateway: any ReadingProgressGateway,
        state: ReaderState
    ) {
        self.archiveGateway = archiveGateway
        self.metadataGateway = metadataGateway
        self.progressGateway = progressGateway
        self.state = state
    }

    func openBook(at url: URL) async {
        state.isLoading = true
        state.errorMessage = nil
        let session = ArchiveSession(archiveGateway: archiveGateway)
        do {
            let entries = try await session.open(url: url)
            let pages = PageList.pages(fromEntries: entries)
            guard !pages.isEmpty else {
                throw ReaderError.noPages(url.lastPathComponent)
            }

            // Metadata is best-effort: absent or unreadable ComicInfo.xml
            // must never fail the open.
            var metadata: ComicMetadata?
            if let infoPath = ComicInfoLocator.entry(in: entries),
               let xml = try? await session.data(forEntry: infoPath) {
                metadata = metadataGateway.metadata(fromXML: xml)
            }

            await session.configure(pages: pages)
            self.session = session
            state.book = Book(url: url, pages: pages, metadata: metadata)
            state.currentImage = nil

            let saved = progressGateway.savedPageIndex(for: url) ?? 0
            let resume = min(max(saved, 0), pages.count - 1)
            state.currentPageIndex = resume
            state.isLoading = false
            await showPage(resume)
        } catch {
            state.isLoading = false
            state.errorMessage = Self.message(for: error, url: url)
        }
    }

    func goToNextPage() async { await go(to: state.currentPageIndex + 1) }
    func goToPreviousPage() async { await go(to: state.currentPageIndex - 1) }
    func goToFirstPage() async { await go(to: 0) }

    func goToLastPage() async {
        guard let book = state.book else { return }
        await go(to: book.pageCount - 1)
    }

    func clearError() {
        state.errorMessage = nil
    }

    /// Out-of-bounds targets are a silent no-op: never wrap, never beep.
    private func go(to index: Int) async {
        guard let book = state.book, book.pages.indices.contains(index),
              index != state.currentPageIndex else { return }
        state.currentPageIndex = index
        progressGateway.save(pageIndex: index, for: book.url)
        await showPage(index)
    }

    private func showPage(_ index: Int) async {
        guard let session, let bookURL = state.book?.url else { return }
        do {
            let image = try await session.image(at: index)
            // The user may have paged on or opened another book while we
            // were decoding; a stale image must never overwrite a newer one.
            guard state.book?.url == bookURL, state.currentPageIndex == index else { return }
            state.currentImage = image
            await session.prefetch(around: index)
        } catch is CancellationError {
            // Superseded by a later page turn — nothing to report.
        } catch {
            guard state.book?.url == bookURL, state.currentPageIndex == index else { return }
            state.errorMessage = error.localizedDescription
        }
    }

    private static func message(for error: Error, url: URL) -> String {
        // Both of these already name the file and explain themselves; wrapping
        // them would repeat the filename.
        if let readerError = error as? ReaderError {
            return readerError.localizedDescription
        }
        if let archiveError = error as? ArchiveError {
            return archiveError.localizedDescription
        }
        return "Couldn't open “\(url.lastPathComponent)”: \(error.localizedDescription)"
    }
}
