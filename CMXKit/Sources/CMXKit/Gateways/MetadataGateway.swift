import Foundation

/// Turns raw ComicInfo.xml bytes into metadata. Returns nil for anything it
/// cannot read — malformed metadata degrades to "no metadata", never an error.
public protocol MetadataGateway: Sendable {
    func metadata(fromXML data: Data) -> ComicMetadata?
}
