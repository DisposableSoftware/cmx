import AppKit
import CMXKit
import SwiftUI

/// Thin shell over the package's ReaderView. File panels belong to the app
/// target, so the importer lives here, not in CMXKit.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ReaderView(viewModel: model.viewModel)
            .frame(minWidth: 400, minHeight: 500)
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
