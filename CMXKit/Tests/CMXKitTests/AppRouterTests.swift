import Testing
@testable import CMXKit

@Suite struct AppRouterTests {
    private let router = AppRouter()

    @Test func readerToSettings() {
        #expect(router.nextStep(from: .reader, for: .openSettings) == .settings)
    }

    @Test func settingsBackToReader() {
        #expect(router.nextStep(from: .settings, for: .closeSettings) == .reader)
    }

    @Test func invalidTransitionsReturnNil() {
        #expect(router.nextStep(from: .reader, for: .closeSettings) == nil)
        #expect(router.nextStep(from: .settings, for: .openSettings) == nil)
    }
}

@MainActor
@Suite struct AppRoutingUseCaseTests {
    private final class SpyCoordinator: Coordinator {
        var shown: [AppStep] = []
        func show(step: AppStep) { shown.append(step) }
    }

    @Test func validRequestNavigatesAndUpdatesStep() {
        let coordinator = SpyCoordinator()
        let routing = AppRoutingUseCase(coordinator: coordinator)
        routing.navigate(.openSettings)
        #expect(routing.currentStep == .settings)
        #expect(coordinator.shown == [.settings])
    }

    @Test func invalidRequestIsANoOp() {
        let coordinator = SpyCoordinator()
        let routing = AppRoutingUseCase(coordinator: coordinator)
        routing.navigate(.closeSettings)
        #expect(routing.currentStep == .reader)
        #expect(coordinator.shown.isEmpty)
    }
}
