import SwiftUI

/// What the Quick Look preview shows. Lives in the package for the same
/// reason ReaderView does — it is a view over domain data, and it keeps the
/// extension target a thin shell.
public struct CoverSummary: Sendable {
    public let image: PageImage
    public let title: String
    public let metadata: ComicMetadata?
    public let pageCount: Int

    public init(image: PageImage, title: String, metadata: ComicMetadata?, pageCount: Int) {
        self.image = image
        self.title = title
        self.metadata = metadata
        self.pageCount = pageCount
    }

    public init(cover: ComicCover, url: URL) {
        self.init(
            image: cover.image,
            title: cover.displayTitle(for: url),
            metadata: cover.metadata,
            pageCount: cover.pageCount
        )
    }
}

/// Cover on the left, a short facts column on the right. Deliberately plain —
/// a Quick Look panel is a glance, not the reader.
public struct CoverPreview: View {
    private let summary: CoverSummary

    public init(summary: CoverSummary) {
        self.summary = summary
    }

    public var body: some View {
        HStack(spacing: 0) {
            Image(decorative: summary.image.cgImage, scale: 1)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 10) {
                Text(summary.title)
                    .font(.headline)
                    .lineLimit(3)
                Text(summary.pageCount == 1 ? "1 page" : "\(summary.pageCount) pages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let metadata = summary.metadata, !metadata.isEmpty {
                    Divider()
                    ForEach(Self.facts(metadata), id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(value).font(.callout)
                        }
                    }
                    if let summaryText = metadata.summary {
                        Divider()
                        Text(summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: 230, alignment: .leading)
        }
    }

    /// Only the fields actually present, in reading order.
    static func facts(_ m: ComicMetadata) -> [(String, String)] {
        var rows: [(String, String)] = []
        if let v = m.series { rows.append(("Series", v)) }
        if let v = m.number { rows.append(("Number", v)) }
        if let v = m.writer { rows.append(("Writer", v)) }
        if let v = m.penciller { rows.append(("Penciller", v)) }
        if let v = m.publisher { rows.append(("Publisher", v)) }
        let date = [m.year, m.month, m.day].compactMap { $0.map(String.init) }
        if !date.isEmpty { rows.append(("Date", date.joined(separator: "-"))) }
        if let v = m.genre { rows.append(("Genre", v)) }
        return rows
    }
}
