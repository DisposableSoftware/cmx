import AppKit

/// Exists for one reason: Finder "Open With" document events. Opens that
/// arrive before SwiftUI has built the model are buffered and replayed.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var pendingURLs: [URL] = []

    func bind(to model: AppModel) {
        self.model = model
        guard !pendingURLs.isEmpty else { return }
        model.open(urls: pendingURLs)
        pendingURLs = []
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let model {
            model.open(urls: urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }
}
