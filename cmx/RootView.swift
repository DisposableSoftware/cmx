import CMXKit
import SwiftUI

/// Thin shell over the package's ReaderView. File panels belong to the app
/// target, so the importer lives here, not in CMXKit.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ReaderView(viewModel: model.viewModel)
            .frame(minWidth: 400, minHeight: 500)
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
