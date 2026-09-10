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
    public internal(set) var isLoading = false
    public internal(set) var errorMessage: String?
    /// Set once per successful open; the host observes it to size its window.
    public internal(set) var coverGeometry: CoverGeometry?

    public init() {}

    public var windowTitle: String {
        book?.windowTitle ?? "cmx"
    }

    /// "3 / 42" for the title bar, nil when no book is open.
    public var pageIndicator: String? {
        guard let book, book.pageCount > 0 else { return nil }
        return "\(currentPageIndex + 1) / \(book.pageCount)"
    }
}
