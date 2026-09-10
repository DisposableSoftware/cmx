import Foundation

/// Business logic for reading a comic: opening, page navigation rules, and
/// progress. Bounds logic lives here — at the first or last page the
/// corresponding call is a no-op; never wrap.
@MainActor
public protocol ReaderUseCase: AnyObject {
    var state: ReaderState { get }
    func openBook(at url: URL) async
    func goToNextPage() async
    func goToPreviousPage() async
    func goToFirstPage() async
    func goToLastPage() async
    func clearError()
}

enum ReaderError: Error, LocalizedError {
    case noPages(String)
    case archiveNotOpen
    case pageOutOfRange
    case undecodablePage(String)

    var errorDescription: String? {
        switch self {
        case .noPages(let name):
            return "No pages found in “\(name)”."
        case .archiveNotOpen:
            return "No comic is open."
        case .pageOutOfRange:
            return "That page does not exist."
        case .undecodablePage(let path):
            return "Couldn't decode the image “\(path)”."
        }
    }
}
