/// Pure function of its inputs: decides the next step, performs no
/// navigation. The Coordinator does the navigating.
public struct AppRouter: Sendable {
    public init() {}

    public func nextStep(from current: AppStep, for request: AppNavigationRequest) -> AppStep? {
        switch (current, request) {
        case (.reader, .openSettings): return .settings
        case (.settings, .closeSettings): return .reader
        default: return nil
        }
    }
}
