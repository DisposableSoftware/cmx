import AppKit
import CMXKit
import SwiftUI

/// Hands back the NSWindow hosting this view. Scoped to the view rather than
/// reaching for `NSApp.keyWindow`, so a future settings window can never be
/// resized by mistake.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The view has no window until it is in the hierarchy.
        Task { @MainActor in
            if let window = view.window { onWindow(window) }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        Task { @MainActor in
            if let window = view.window { onWindow(window) }
        }
    }
}

@MainActor
enum WindowSizing {
    /// Resize `window` so its content matches `aspectRatio`, keeping the top-left
    /// corner planted — the geometry itself is decided by `WindowFit` in CMXKit.
    static func fit(_ window: NSWindow, toAspectRatio aspectRatio: CGFloat) {
        // Never fight the user's own window state.
        guard !window.styleMask.contains(.fullScreen), !window.isZoomed else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        let frame = window.frame
        let content = window.contentRect(forFrameRect: frame).size
        let chromeHeight = frame.height - content.height
        let minimum = window.contentMinSize.width > 0 && window.contentMinSize.height > 0
            ? window.contentMinSize
            : CGSize(width: 400, height: 500)

        guard let target = WindowFit.contentSize(
            aspectRatio: aspectRatio,
            currentContent: content,
            chromeHeight: chromeHeight,
            visibleFrame: screen.visibleFrame.size,
            minimum: minimum
        ) else { return }

        // Already right — don't nudge the window over a rounding difference.
        if abs(target.width - content.width) < 1, abs(target.height - content.height) < 1 {
            return
        }

        var newFrame = window.frameRect(
            forContentRect: CGRect(origin: .zero, size: target))
        newFrame.origin.x = frame.minX
        newFrame.origin.y = frame.maxY - newFrame.height  // keep the title bar put

        // Keep the whole window on screen.
        let visible = screen.visibleFrame
        newFrame.origin.x = min(max(newFrame.minX, visible.minX),
                                max(visible.minX, visible.maxX - newFrame.width))
        newFrame.origin.y = min(max(newFrame.minY, visible.minY),
                                max(visible.minY, visible.maxY - newFrame.height))

        window.setFrame(newFrame, display: true, animate: false)
    }
}
