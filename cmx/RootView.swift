import AppKit
import CMXKit
import SwiftUI

/// Thin shell over the package's ReaderView. File panels belong to the app
/// target, so the importer lives here, not in CMXKit.
struct RootView: View {
    @Bindable var model: AppModel
    @State private var window: NSWindow?

    var body: some View {
        ReaderView(viewModel: model.viewModel)
            .frame(minWidth: 400, minHeight: 500)
            .background(WindowAccessor { window = $0 })
            // Opening a book publishes its page proportions; match the window
            // to them. Only on open — resizing on every page turn would fight
            // the user, and spreads would make it jump.
            // book changes only on a successful open, so a CBR or a broken
            // file never lands in Open Recent.
            .onChange(of: model.viewModel.state.book?.url) { _, url in
                if let url { model.noteOpened(url) }
            }
            .onChange(of: model.viewModel.state.coverGeometry) { _, geometry in
                guard let geometry, let window else { return }
                WindowSizing.fit(window, toAspectRatio: geometry.aspectRatio)
            }
            // App-shell keys. These sit outside the package: paging keys are
            // domain input (ReaderView), but quit and fullscreen belong to
            // the app. Unhandled presses bubble up the focus chain to here.
            .onKeyPress(keys: ["q", "f"]) { press in
                switch press.key {
                case "q":
                    NSApplication.shared.terminate(nil)
                    return .handled
                case "f":
                    NSApp.keyWindow?.toggleFullScreen(nil)
                    return .handled
                default:
                    return .ignored
                }
            }
            .fileImporter(
                isPresented: $model.isImporterPresented,
                allowedContentTypes: [.cbzArchive]
            ) { result in
                if case .success(let url) = result {
                    model.submit(.openBook(url))
                }
            }
    }
}
