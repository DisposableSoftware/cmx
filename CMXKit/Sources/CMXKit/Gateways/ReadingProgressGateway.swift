import Foundation

/// Persists the last-read page per file. Keyed by file path — a path that has
/// gone stale simply returns nil ("no saved progress"), never an error.
public protocol ReadingProgressGateway: Sendable {
    func savedPageIndex(for url: URL) -> Int?
    func save(pageIndex: Int, for url: URL)
    /// The book to reopen on launch. Nil when none was recorded, or when the
    /// file has since moved or been deleted — a vanished file is simply "no
    /// session", never an error.
    var lastOpenedURL: URL? { get }
    func setLastOpened(_ url: URL)
}

/// UserDefaults is documented thread-safe, hence @unchecked Sendable.
final class DefaultsReadingProgressGateway: ReadingProgressGateway, @unchecked Sendable {
    private let defaults: UserDefaults
    private static let keyPrefix = "readingProgress:"
    private static let lastOpenedKey = "lastOpenedURL"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func savedPageIndex(for url: URL) -> Int? {
        defaults.object(forKey: key(for: url)) as? Int
    }

    func save(pageIndex: Int, for url: URL) {
        defaults.set(pageIndex, forKey: key(for: url))
    }

    var lastOpenedURL: URL? {
        guard let path = defaults.string(forKey: Self.lastOpenedKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func setLastOpened(_ url: URL) {
        defaults.set(url.standardizedFileURL.path, forKey: Self.lastOpenedKey)
    }

    private func key(for url: URL) -> String {
        Self.keyPrefix + url.standardizedFileURL.path
    }
}
