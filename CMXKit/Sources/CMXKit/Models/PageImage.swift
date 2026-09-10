import CoreGraphics

/// A decoded page. CGImage is immutable and thread-safe; the wrapper exists so
/// decoded pages can cross actor boundaries without depending on the SDK's
/// Sendable annotations for CoreGraphics types.
public struct PageImage: @unchecked Sendable {
    public let cgImage: CGImage

    public init(cgImage: CGImage) {
        self.cgImage = cgImage
    }
}
