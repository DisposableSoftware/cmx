import Foundation

/// The only way a View talks to the ViewModel.
public enum ReaderAction: Equatable, Sendable {
    case openBook(URL)
    case nextPage
    case previousPage
    case firstPage
    case lastPage
    case toggleInspector
    case dismissError
}
