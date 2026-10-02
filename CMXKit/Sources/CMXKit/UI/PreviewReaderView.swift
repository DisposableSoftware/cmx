import AppKit
import OSLog
import SwiftUI

/// The Quick Look preview: a small reader you can page through, rather than a
/// still of the cover.
///
/// Input is deliberately redundant. The Quick Look panel owns the arrow keys —
/// it uses them to move between files in the Finder selection — so paging
/// cannot rely on the keyboard. On-screen buttons and trackpad scrolling are
/// what actually work inside the panel.
public struct PreviewReaderView: View {
    private let viewModel: ReaderViewModel
    @State private var showsInfo: Bool
    @State private var controlsVisible = false

    public init(viewModel: ReaderViewModel, showsInfo: Bool = true) {
        self.viewModel = viewModel
        _showsInfo = State(initialValue: showsInfo)
    }

    private var state: ReaderState { viewModel.state }

    public var body: some View {
        HStack(spacing: 0) {
            pageArea
            if showsInfo, let metadata = state.book?.metadata, !metadata.isEmpty {
                Divider()
                ScrollView {
                    PreviewMetadataColumn(metadata: metadata, title: state.windowTitle,
                                        pageCount: state.book?.pageCount ?? 0)
                }
                .frame(width: 210)
            }
        }
        .background(Color.black)
    }

    private var pageArea: some View {
        ZStack(alignment: .bottom) {
            Color.black
            if let image = state.currentImage {
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.isLoading {
                ProgressView().controlSize(.small)
            } else if let error = state.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            controls
                .padding(.bottom, 12)
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: controlsVisible)
        }
        .background(PageScrollCatcher { forward in
            submit(forward ? .nextPage : .previousPage)
        })
        .onHover { controlsVisible = $0 }
        // Offered in case the panel ever lets them through; buttons and
        // scrolling are what carry the feature.
        .onKeyPress(keys: [.leftArrow, .rightArrow, .space]) { press in
            submit(press.key == .leftArrow ? .previousPage : .nextPage)
            return .handled
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            button("chevron.left", "Previous page") { submit(.previousPage) }
                .disabled(state.currentPageIndex == 0)

            Text(state.pageIndicator ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 62)

            button("chevron.right", "Next page") { submit(.nextPage) }
                .disabled(isAtEnd)

            Divider().frame(height: 14).overlay(Color.white.opacity(0.25))

            button(showsInfo ? "info.circle.fill" : "info.circle",
                   showsInfo ? "Hide info" : "Show info") { showsInfo.toggle() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }

    private func button(_ symbol: String, _ label: String, action: @escaping () -> Void)
        -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var isAtEnd: Bool {
        guard let book = state.book else { return true }
        return state.currentPageIndex + state.displayedPageCount >= book.pageCount
    }

    private func submit(_ action: ReaderAction) {
        // TEMP DIAGNOSTIC: proves whether the Quick Look panel forwards input.
        Logger(subsystem: "lol.weston.cmx", category: "preview")
            .notice("preview-input \(String(describing: action), privacy: .public)")
        Task { await viewModel.handleAction(action) }
    }
}

/// Metadata for the preview panel: the same fields as the inspector, laid
/// out for a narrow column.
struct PreviewMetadataColumn: View {
    let metadata: ComicMetadata
    let title: String
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.headline)
                .lineLimit(3)
            Text(pageCount == 1 ? "1 page" : "\(pageCount) pages")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            ForEach(CoverPreview.facts(metadata), id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(value).font(.callout)
                }
            }
            if let summary = metadata.summary {
                Divider()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Turns trackpad scrolling and wheel ticks into page turns. SwiftUI has no
/// scroll-wheel hook on macOS, and a `DragGesture` never fires for a two-finger
/// swipe, so this drops to AppKit.
struct PageScrollCatcher: NSViewRepresentable {
    /// Called with true to advance, false to go back.
    let onPage: (Bool) -> Void

    func makeNSView(context: Context) -> NSView { CatcherView(onPage: onPage) }
    func updateNSView(_ view: NSView, context: Context) {}

    final class CatcherView: NSView {
        private let onPage: (Bool) -> Void
        private var accumulated: CGFloat = 0
        /// One deliberate swipe, not every pixel of momentum.
        private let threshold: CGFloat = 28
        private var armed = true

        init(onPage: @escaping (Bool) -> Void) {
            self.onPage = onPage
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not used") }

        override func scrollWheel(with event: NSEvent) {
            // Whichever axis moved more: sideways swipes and ordinary wheels
            // should both page.
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? -event.scrollingDeltaX
                : -event.scrollingDeltaY

            if event.phase.contains(.began) {
                accumulated = 0
                armed = true
            }
            // Momentum after the fingers lift must not flip several pages.
            guard event.momentumPhase.isEmpty else { return }

            accumulated += delta
            if armed, abs(accumulated) >= threshold {
                onPage(accumulated > 0)
                accumulated = 0
                armed = false
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                accumulated = 0
                armed = true
            }
        }
    }
}
