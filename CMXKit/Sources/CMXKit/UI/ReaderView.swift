import SwiftUI

/// The whole UI: the page fills the window, everything else stays hidden
/// until asked for.
public struct ReaderView: View {
    private let viewModel: ReaderViewModel
    @FocusState private var isFocused: Bool

    private static let pagingKeys: Set<KeyEquivalent> = [
        .space, .leftArrow, .rightArrow, .upArrow, .downArrow,
        .pageUp, .pageDown, .home, .end,
    ]

    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = viewModel.state.currentImage {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.state.isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(keys: Self.pagingKeys) { handle($0) }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "cbz" })
            else { return false }
            submit(.openBook(url))
            return true
        }
        .inspector(isPresented: inspectorBinding) {
            MetadataInspector(metadata: viewModel.state.book?.metadata)
        }
        .navigationTitle(viewModel.state.windowTitle)
        .navigationSubtitle(viewModel.state.pageIndicator ?? "")
        .alert(
            viewModel.state.errorMessage ?? "Something went wrong.",
            isPresented: errorBinding
        ) {
            Button("OK") { submit(.dismissError) }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Text("Open a comic")
                .font(.title2)
            Text("⌘O, or drop a .cbz here")
                .font(.callout)
        }
        .foregroundStyle(.secondary)
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .space:
            submit(press.modifiers.contains(.shift) ? .previousPage : .nextPage)
        case .rightArrow, .downArrow, .pageDown:
            submit(.nextPage)
        case .leftArrow, .upArrow, .pageUp:
            submit(.previousPage)
        case .home:
            submit(.firstPage)
        case .end:
            submit(.lastPage)
        default:
            return .ignored
        }
        return .handled
    }

    private func submit(_ action: ReaderAction) {
        Task { await viewModel.handleAction(action) }
    }

    /// Bindings route through actions like everything else.
    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isInspectorVisible },
            set: { newValue in
                if newValue != viewModel.isInspectorVisible {
                    submit(.toggleInspector)
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { newValue in
                if !newValue { submit(.dismissError) }
            }
        )
    }
}
