import SwiftUI

struct MetadataInspector: View {
    let metadata: ComicMetadata?

    var body: some View {
        Group {
            if let metadata, !metadata.isEmpty {
                fields(for: metadata)
            } else {
                Text("No metadata in this file.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .inspectorColumnWidth(min: 220, ideal: 260, max: 400)
    }

    private func fields(for metadata: ComicMetadata) -> some View {
        Form {
            row("Series", metadata.series)
            row("Number", metadata.number)
            row("Volume", metadata.volume.map(String.init))
            row("Count", metadata.count.map(String.init))
            row("Title", metadata.title)
            row("Writer", metadata.writer)
            row("Penciller", metadata.penciller)
            row("Inker", metadata.inker)
            row("Colorist", metadata.colorist)
            row("Letterer", metadata.letterer)
            row("Cover Artist", metadata.coverArtist)
            row("Publisher", metadata.publisher)
            row("Date", dateText(for: metadata))
            row("Pages", metadata.pageCount.map(String.init))
            row("Language", metadata.languageISO)
            row("Genre", metadata.genre)
            row("Web", metadata.web)
            if let summary = metadata.summary {
                Section("Summary") {
                    Text(summary).font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value {
            LabeledContent(label, value: value)
        }
    }

    private func dateText(for metadata: ComicMetadata) -> String? {
        let parts = [metadata.year, metadata.month, metadata.day]
            .compactMap { $0.map(String.init) }
        return parts.isEmpty ? nil : parts.joined(separator: "-")
    }
}
