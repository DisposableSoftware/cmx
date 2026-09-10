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

    init() {
        let coordinator = AppCoordinator()
        container = ReaderContainer.build(coordinator: coordinator)
        viewModel = ReaderViewModel(useCases: container)
    }

    func submit(_ action: ReaderAction) {
        Task { await viewModel.handleAction(action) }
    }

    func open(urls: [URL]) {
        guard let url = urls.first else { return }
        submit(.openBook(url))
    }
}
