import CMXKit
import Cocoa
import OSLog
import Quartz
import SwiftUI

/// Space-bar preview for .cbz files: a small reader you can page through.
///
/// A thin shell — CMXKit opens the book and owns the view; this only hosts it.
/// Runs sandboxed, with Quick Look granting read access to the previewed file.
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let container = PreviewContainer.build()

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        // Load before handing over the view, so Quick Look never shows an
        // empty panel that fills in a moment later.
        await container.readerUseCase.openBook(at: url)
        // TEMP DIAGNOSTIC: control line — proves logging works at all.
        Logger(subsystem: "lol.weston.cmx", category: "preview")
            .notice("preview-loaded pages=\(self.container.readerUseCase.state.book?.pageCount ?? -1, privacy: .public)")

        let hosting = NSHostingView(
            rootView: PreviewReaderView(
                viewModel: ReaderViewModel(useCases: container)))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
