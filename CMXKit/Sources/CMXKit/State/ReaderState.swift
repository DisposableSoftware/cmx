import Foundation
import Observation

/// Observable shared state for the reader. Mutated only by the UseCase;
/// Views observe it through the ViewModel.
@MainActor
@Observable
public final class ReaderState {
    public internal(set) var book: Book?
    public internal(set) var currentPageIndex: Int = 0
    public internal(set) var currentImage: PageImage?
    /// The right-hand page in dual-page mode; nil whenever one page is shown.
    public internal(set) var secondaryImage: PageImage?
    public internal(set) var isDualPage = false
    public internal(set) var isLoading = false
    public internal(set) var errorMessage: String?
    /// Set once per successful open; the host observes it to size its window.
    public internal(set) var coverGeometry: CoverGeometry?

    public init() {}

    public var windowTitle: String {
        book?.windowTitle ?? "cmx"
    }

    /// How many pages are on screen right now.
    public var displayedPageCount: Int {
        secondaryImage == nil ? 1 : 2
    }

    /// "3 / 42", or "3–4 / 42" when two pages are shown. Nil with no book.
    public var pageIndicator: String? {
        guard let book, book.pageCount > 0 else { return nil }
        let first = currentPageIndex + 1
        if secondaryImage != nil {
            return "\(first)–\(first + 1) / \(book.pageCount)"
        }
        return "\(first) / \(book.pageCount)"
    }
}
