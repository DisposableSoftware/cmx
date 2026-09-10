import Foundation

/// Where ComicInfo.xml lives in an archive. The spec says the root; some
/// writers nest it, so fall back to any location.
enum ComicInfoLocator {
    static func entry(in entries: [String]) -> String? {
        entries.first { $0.lowercased() == "comicinfo.xml" }
            ?? entries.first { ($0 as NSString).lastPathComponent.lowercased() == "comicinfo.xml" }
    }
}
