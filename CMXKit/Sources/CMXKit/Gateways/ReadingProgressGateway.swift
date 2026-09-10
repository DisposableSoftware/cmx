import Foundation

/// Persists the last-read page per file. Keyed by file path — a path that has
/// gone stale simply returns nil ("no saved progress"), never an error.
public protocol ReadingProgressGateway: Sendable {
    func savedPageIndex(for url: URL) -> Int?
    func save(pageIndex: Int, for url: URL)
}

/// UserDefaults is documented thread-safe, hence @unchecked Sendable.
final class DefaultsReadingProgressGateway: ReadingProgressGateway, @unchecked Sendable {
    private let defaults: UserDefaults
    private static let keyPrefix = "readingProgress:"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func savedPageIndex(for url: URL) -> Int? {
        defaults.object(forKey: key(for: url)) as? Int
    }

    func save(pageIndex: Int, for url: URL) {
        defaults.set(pageIndex, forKey: key(for: url))
    }

    private func key(for url: URL) -> String {
        Self.keyPrefix + url.standardizedFileURL.path
    }
}
