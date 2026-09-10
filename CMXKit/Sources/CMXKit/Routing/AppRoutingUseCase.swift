/// Wraps the Router (which decides) and the Coordinator (which acts).
@MainActor
public final class AppRoutingUseCase {
    public private(set) var currentStep: AppStep = .reader
    private let router: AppRouter
    private let coordinator: any Coordinator

    public init(router: AppRouter = AppRouter(), coordinator: any Coordinator) {
        self.router = router
        self.coordinator = coordinator
    }

    public func navigate(_ request: AppNavigationRequest) {
        guard let next = router.nextStep(from: currentStep, for: request) else { return }
        currentStep = next
        coordinator.show(step: next)
    }
}
