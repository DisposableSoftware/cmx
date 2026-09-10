/// Composition root for the Quick Look extensions. Separate from
/// ReaderContainer because an extension has no Coordinator, no shared state,
/// and no main-actor UI to wire.
public enum CoverContainer {
    public static func build() -> any CoverUseCase {
        DefaultCoverUseCase(
            archiveGateway: ZipArchiveGateway(),
            metadataGateway: ComicInfoMetadataGateway()
        )
    }
}
