import CMXKit

/// The navigation engine the package's Router drives. The reader is the only
/// screen today; the settings step hooks in here when it exists.
@MainActor
final class AppCoordinator: Coordinator {
    func show(step: AppStep) {
        switch step {
        case .reader, .settings:
            break
        }
    }
}
