/// Screens of the app. Thin today — the Router exists so that adding a
/// settings (or any other) screen is additive rather than a restructure.
public enum AppStep: Equatable, Sendable {
    case reader
    case settings
}

/// What the user asked for; the Router decides whether it is valid from here.
public enum AppNavigationRequest: Equatable, Sendable {
    case openSettings
    case closeSettings
}
