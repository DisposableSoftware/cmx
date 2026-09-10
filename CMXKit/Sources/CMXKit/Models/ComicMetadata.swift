import Foundation

/// Fields read from ComicInfo.xml (ComicRack schema). Every field is optional —
/// absence of metadata is the normal case and must never surface as an error.
public struct ComicMetadata: Equatable, Sendable {
    public var series: String?
    public var number: String?      // deliberately a String: "7.1" and "Annual 1" occur in the wild
    public var count: Int?
    public var volume: Int?
    public var title: String?
    public var summary: String?
    public var writer: String?
    public var penciller: String?
    public var inker: String?
    public var colorist: String?
    public var letterer: String?
    public var coverArtist: String?
    public var publisher: String?
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var pageCount: Int?      // never trusted for navigation; display only
    public var languageISO: String?
    public var genre: String?
    public var web: String?

    public init() {}

    public var isEmpty: Bool {
        self == ComicMetadata()
    }

    /// "Series #Number — Title" from whatever parts exist; nil when none do.
    public var displayTitle: String? {
        var lead: [String] = []
        if let series { lead.append(series) }
        if let number { lead.append("#\(number)") }
        let leadText = lead.joined(separator: " ")
        switch (leadText.isEmpty, title) {
        case (false, let title?): return "\(leadText) — \(title)"
        case (false, nil): return leadText
        case (true, let title?): return title
        case (true, nil): return nil
        }
    }
}
