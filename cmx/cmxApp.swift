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

    /// Reading commands are meaningless with nothing open.
    private var hasBook: Bool { model.viewModel.state.book != nil }

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
                Menu("Open Recent") {
                    ForEach(model.recentURLs, id: \.self) { url in
                        Button(url.deletingPathExtension().lastPathComponent) {
                            model.open(urls: [url])
                        }
                    }
                    if !model.recentURLs.isEmpty {
                        Divider()
                    }
                    Button("Clear Menu") { model.clearRecents() }
                        .disabled(model.recentURLs.isEmpty)
                }
                .disabled(model.recentURLs.isEmpty)
            }

            // The menu bar is where a Mac app documents itself: every reading
            // command appears here with a ⌘ shortcut, while the bare keys
            // (space, hjkl, d, f) stay available in the view.
            CommandMenu("Go") {
                Button("Next Page") { model.submit(.nextPage) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(!hasBook)
                Button("Previous Page") { model.submit(.previousPage) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .disabled(!hasBook)
                Divider()
                Button("First Page") { model.submit(.firstPage) }
                    .keyboardShortcut(.home, modifiers: .command)
                    .disabled(!hasBook)
                Button("Last Page") { model.submit(.lastPage) }
                    .keyboardShortcut(.end, modifiers: .command)
                    .disabled(!hasBook)
            }

            CommandGroup(after: .toolbar) {
                Toggle("Dual Page", isOn: Binding(
                    get: { model.viewModel.state.isDualPage },
                    set: { _ in model.submit(.toggleDualPage) }))
                    .keyboardShortcut("2", modifiers: .command)
                    .disabled(!hasBook)
                Toggle("Comic Info", isOn: Binding(
                    get: { model.viewModel.isInspectorVisible },
                    set: { _ in model.submit(.toggleInspector) }))
                    .keyboardShortcut("i")
                    .disabled(!hasBook)
            }
        }

        Window("About cmx", id: AppWindow.about) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
