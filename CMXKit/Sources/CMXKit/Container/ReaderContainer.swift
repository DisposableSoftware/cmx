import Foundation

/// Composition root — the only place concrete Gateway/UseCase types are
/// constructed. Everything else sees protocols.
@MainActor
public struct ReaderContainer: AllUseCases {
    public let readerUseCase: any ReaderUseCase
    public let appRoutingUseCase: AppRoutingUseCase

    public static func build(
        coordinator: any Coordinator,
        defaults: UserDefaults = .standard
    ) -> ReaderContainer {
        // 1. Gateways
        let archiveGateway = ZipArchiveGateway()
        let metadataGateway = ComicInfoMetadataGateway()
        let progressGateway = DefaultsReadingProgressGateway(defaults: defaults)

        // 2. Shared state
        let state = ReaderState()

        // 3. UseCases
        let readerUseCase = DefaultReaderUseCase(
            archiveGateway: archiveGateway,
            metadataGateway: metadataGateway,
            progressGateway: progressGateway,
            state: state
        )
        let appRoutingUseCase = AppRoutingUseCase(coordinator: coordinator)

        return ReaderContainer(
            readerUseCase: readerUseCase,
            appRoutingUseCase: appRoutingUseCase
        )
    }
}
