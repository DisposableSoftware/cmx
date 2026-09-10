import Foundation

/// Lenient ComicRack-schema parser. Unknown elements are ignored; numeric
/// fields that fail to parse become nil; a parse error partway through keeps
/// whatever was already collected.
struct ComicInfoMetadataGateway: MetadataGateway {
    func metadata(fromXML data: Data) -> ComicMetadata? {
        let parser = XMLParser(data: data)
        let collector = FieldCollector()
        parser.delegate = collector
        let completed = parser.parse()

        let fields = collector.fields
        guard completed || !fields.isEmpty else { return nil }

        var metadata = ComicMetadata()
        metadata.series = fields["series"]
        metadata.number = fields["number"]
        metadata.count = fields["count"].flatMap(Int.init)
        metadata.volume = fields["volume"].flatMap(Int.init)
        metadata.title = fields["title"]
        metadata.summary = fields["summary"]
        metadata.writer = fields["writer"]
        metadata.penciller = fields["penciller"]
        metadata.inker = fields["inker"]
        metadata.colorist = fields["colorist"]
        metadata.letterer = fields["letterer"]
        metadata.coverArtist = fields["coverartist"]
        metadata.publisher = fields["publisher"]
        metadata.year = fields["year"].flatMap(Int.init)
        metadata.month = fields["month"].flatMap(Int.init)
        metadata.day = fields["day"].flatMap(Int.init)
        metadata.pageCount = fields["pagecount"].flatMap(Int.init)
        metadata.languageISO = fields["languageiso"]
        metadata.genre = fields["genre"]
        metadata.web = fields["web"]
        return metadata
    }

    /// Collects the text of the root element's direct children, keyed by
    /// lowercased element name. Nested containers (e.g. <Pages>) collapse to
    /// whitespace and are dropped.
    private final class FieldCollector: NSObject, XMLParserDelegate {
        private(set) var fields: [String: String] = [:]
        private var depth = 0
        private var currentText = ""

        func parser(
            _ parser: XMLParser, didStartElement elementName: String,
            namespaceURI: String?, qualifiedName: String?, attributes: [String: String]
        ) {
            depth += 1
            currentText = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(
            _ parser: XMLParser, didEndElement elementName: String,
            namespaceURI: String?, qualifiedName: String?
        ) {
            if depth == 2 {
                let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    fields[elementName.lowercased()] = text
                }
            }
            depth -= 1
            currentText = ""
        }
    }
}
