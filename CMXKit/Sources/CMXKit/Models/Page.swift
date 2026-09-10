import Foundation

/// One page of a comic: an image entry inside the archive. Order is the
/// position in `Book.pages`, which is derived — never read from the archive.
public struct Page: Equatable, Sendable {
    public let entryPath: String

    public init(entryPath: String) {
        self.entryPath = entryPath
    }
}

/// Derives the page list from raw archive entry paths. Pure — fully unit-testable.
public enum PageList {
    public static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "avif", "bmp", "tif", "tiff",
    ]

    public static func pages(fromEntries entries: [String]) -> [Page] {
        entries
            .filter { !$0.hasSuffix("/") && !isJunk($0) && hasImageExtension($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map(Page.init(entryPath:))
    }

    private static func hasImageExtension(_ path: String) -> Bool {
        imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    private static func isJunk(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        guard let name = components.last else { return true }
        if components.contains(where: { $0.hasPrefix(".") || $0 == "__MACOSX" }) { return true }
        if name.lowercased() == "thumbs.db" { return true }
        return false
    }
}
