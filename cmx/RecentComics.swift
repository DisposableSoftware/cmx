import AppKit

/// The system recent-documents list. Feeding NSDocumentController is what puts
/// comics in the Dock icon's menu as well as our own File ▸ Open Recent.
@MainActor
enum RecentComics {
    static var urls: [URL] {
        NSDocumentController.shared.recentDocumentURLs
    }

    static func note(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    static func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
    }
}
