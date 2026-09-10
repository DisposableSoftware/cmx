import SwiftUI
import CMXKit

/// Window identities for `openWindow(id:)`.
enum AppWindow {
    static let main = "main"
    static let about = "about"
}

@main
struct CmxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var model = AppModel()

    var body: some Scene {
        Window("cmx", id: AppWindow.main) {
            RootView(model: model)
                .onAppear { appDelegate.bind(to: model) }
        }
        .commands {
            // Replace the stock About panel: it cannot show the pronunciation
            // or the license texts.
            CommandGroup(replacing: .appInfo) {
                Button("About cmx") { openWindow(id: AppWindow.about) }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.isImporterPresented = true }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .toolbar) {
                Button("Comic Info") { model.submit(.toggleInspector) }
                    .keyboardShortcut("i")
            }
        }

        Window("About cmx", id: AppWindow.about) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
