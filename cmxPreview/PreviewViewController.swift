import CMXKit
import Cocoa
import Quartz
import SwiftUI

/// Space-bar preview for .cbz files. A thin shell: CMXKit reads the cover and
/// owns the view, this only hosts it. Runs sandboxed; Quick Look grants read
/// access to the previewed file.
final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let cover = try await CoverContainer.build().cover(for: url, maxPixelSize: 1600)
        let hosting = NSHostingView(
            rootView: CoverPreview(summary: CoverSummary(cover: cover, url: url)))
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
