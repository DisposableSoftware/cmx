import AppKit

/// Exists for one reason: Finder "Open With" document events. Opens that
/// arrive before SwiftUI has built the model are buffered and replayed.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var pendingURLs: [URL] = []
    private var hasHandledOpen = false
    private var hasBound = false

    func bind(to model: AppModel) {
        guard !hasBound else { return }
        hasBound = true
        self.model = model

        if !pendingURLs.isEmpty {
            model.open(urls: pendingURLs)
            pendingURLs = []
            return
        }
        guard !hasHandledOpen else { return }

        // Launched with no document — but Finder can still deliver one a moment
        // later, so wait a beat before reopening the previous session rather
        // than loading two comics back to back.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !self.hasHandledOpen else { return }
            model.restoreLastSession()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        hasHandledOpen = true
        if let model {
            model.open(urls: urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }
}
