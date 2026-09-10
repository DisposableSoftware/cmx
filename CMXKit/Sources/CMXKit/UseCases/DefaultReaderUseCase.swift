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
            progressGateway.setLastOpened(url)
            state.currentImage = nil
            state.secondaryImage = nil

            let saved = progressGateway.savedPageIndex(for: url) ?? 0
            let resume = min(max(saved, 0), pages.count - 1)
            state.currentPageIndex = resume
            state.isLoading = false
            await showPage(resume)
            publishGeometry(for: url)
        } catch {
            state.isLoading = false
            state.errorMessage = Self.message(for: error, url: url)
        }
    }

    /// Advance past everything on screen — two pages when a spread is shown.
    /// Deliberately not clamped: with nothing left to show, this is a no-op.
    func goToNextPage() async {
        await go(to: state.currentPageIndex + state.displayedPageCount)
    }

    /// Step back by the dual-page stride, clamped so page 1 stays reachable
    /// from an odd position (which happens after toggling mid-book).
    func goToPreviousPage() async {
        let stride = state.isDualPage ? 2 : 1
        await go(to: max(0, state.currentPageIndex - stride))
    }

    func goToFirstPage() async { await go(to: 0) }

    func goToLastPage() async {
        guard let book = state.book else { return }
        await go(to: book.pageCount - 1)
    }

    func restoreLastSession() async {
        guard state.book == nil, let url = progressGateway.lastOpenedURL else { return }
        await openBook(at: url)
    }

    func toggleDualPage() async {
        state.isDualPage.toggle()
        // Re-render in place so the change is visible without a page turn.
        await showPage(state.currentPageIndex)
    }

    func clearError() {
        state.errorMessage = nil
    }

    /// The right-hand page of a spread, or nil when this page stands alone.
    /// A wide page is skipped before its companion is ever decoded.
    private func companion(
        for image: PageImage, at index: Int, in session: ArchiveSession
    ) async -> PageImage? {
        guard state.isDualPage,
              !SpreadRules.isWide(image),
              let book = state.book,
              book.pages.indices.contains(index + 1)
        else { return nil }

        // refocus: false — the companion must not drag the cache window along.
        guard let next = try? await session.image(at: index + 1, refocus: false),
              SpreadRules.shouldPair(dualPage: true, current: image, next: next)
        else { return nil }
        return next
    }

    /// Announce the opening page's proportions so the host can fit its window.
    /// Uses the page actually shown — page 1, unless progress resumed further
    /// in — because that is what the user is looking at.
    private func publishGeometry(for url: URL) {
        guard let image = state.currentImage?.cgImage, image.height > 0 else { return }
        state.coverGeometry = CoverGeometry(
            bookURL: url,
            aspectRatio: CGFloat(image.width) / CGFloat(image.height)
        )
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
            state.secondaryImage = await companion(for: image, at: index, in: session)
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
