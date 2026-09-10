/// Single-requirement dependency protocols. ViewModels compose exactly the
/// slice they need; the Container conforms to all of them.
@MainActor
public protocol HasReaderUseCase {
    var readerUseCase: any ReaderUseCase { get }
}

@MainActor
public protocol HasAppRoutingUseCase {
    var appRoutingUseCase: AppRoutingUseCase { get }
}

public typealias AllUseCases = HasReaderUseCase & HasAppRoutingUseCase
