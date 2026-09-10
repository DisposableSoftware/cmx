import Foundation

/// An open comic archive. Implementations must be safe to call from any
/// thread; the session keeps one handle open for the life of the book.
public protocol ComicArchive: Sendable {
    /// Raw entry paths, unfiltered and unordered. Deriving the page list
    /// from these is `PageList`'s job, not the archive's.
    var entryPaths: [String] { get }
    func data(forEntry path: String) throws -> Data
}

/// Boundary for archive I/O. Blocking; callers are responsible for staying
/// off the main actor.
public protocol ArchiveGateway: Sendable {
    func openArchive(at url: URL) throws -> any ComicArchive
}

public enum ArchiveError: Error, LocalizedError, Equatable {
    case entryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .entryNotFound(let path):
            return "The archive has no entry named “\(path)”."
        }
    }
}
