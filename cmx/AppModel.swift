import CMXKit
import Observation
import SwiftUI

/// Owns the composition root and the single ReaderViewModel.
@MainActor
@Observable
final class AppModel {
    let container: ReaderContainer
    let viewModel: ReaderViewModel
    var isImporterPresented = false
    private(set) var recentURLs: [URL] = []

    init() {
        let coordinator = AppCoordinator()
        container = ReaderContainer.build(coordinator: coordinator)
        viewModel = ReaderViewModel(useCases: container)
        recentURLs = RecentComics.urls
    }

    /// Record a book that actually opened, so failures never reach the menu.
    func noteOpened(_ url: URL) {
        RecentComics.note(url)
        recentURLs = RecentComics.urls
    }

    func clearRecents() {
        RecentComics.clear()
        recentURLs = RecentComics.urls
    }

    func restoreLastSession() {
        Task { await container.readerUseCase.restoreLastSession() }
    }

    func submit(_ action: ReaderAction) {
        Task { await viewModel.handleAction(action) }
    }

    func open(urls: [URL]) {
        guard let url = urls.first else { return }
        submit(.openBook(url))
    }
}
