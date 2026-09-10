import SwiftUI
import CMXKit

@main
struct CmxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("cmx", id: "main") {
            RootView(model: model)
                .onAppear { appDelegate.bind(to: model) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.isImporterPresented = true }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .toolbar) {
                Button("Comic Info") { model.submit(.toggleInspector) }
                    .keyboardShortcut("i")
            }
        }
    }
}
