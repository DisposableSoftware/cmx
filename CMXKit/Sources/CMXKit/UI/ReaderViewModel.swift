import Foundation
import Observation

@MainActor
@Observable
public final class ReaderViewModel {
    public typealias UseCases = HasReaderUseCase & HasAppRoutingUseCase

    public private(set) var isInspectorVisible = false

    @ObservationIgnored
    private let useCases: any UseCases

    public init(useCases: any UseCases) {
        self.useCases = useCases
    }

    public var state: ReaderState {
        useCases.readerUseCase.state
    }

    public func handleAction(_ action: ReaderAction) async {
        switch action {
        case .openBook(let url):
            await useCases.readerUseCase.openBook(at: url)
        case .nextPage:
            await useCases.readerUseCase.goToNextPage()
        case .previousPage:
            await useCases.readerUseCase.goToPreviousPage()
        case .firstPage:
            await useCases.readerUseCase.goToFirstPage()
        case .lastPage:
            await useCases.readerUseCase.goToLastPage()
        case .toggleDualPage:
            await useCases.readerUseCase.toggleDualPage()
        case .toggleInspector:
            isInspectorVisible.toggle()
        case .dismissError:
            useCases.readerUseCase.clearError()
        }
    }
}
