import Foundation
import Testing
@testable import CMXKit

@Suite struct ComicInfoParserTests {
    private let gateway = ComicInfoMetadataGateway()

    private func parse(_ xml: String) -> ComicMetadata? {
        gateway.metadata(fromXML: Data(xml.utf8))
    }

    @Test func parsesFullDocument() throws {
        let metadata = try #require(parse("""
            <?xml version="1.0"?>
            <ComicInfo>
              <Series>Saga of Testing</Series>
              <Number>7</Number>
              <Count>12</Count>
              <Volume>2</Volume>
              <Title>The Mock Menace</Title>
              <Summary>A comic about tests.</Summary>
              <Writer>W. Riter</Writer>
              <Publisher>Unit Press</Publisher>
              <Year>1999</Year>
              <Month>4</Month>
              <Day>15</Day>
              <PageCount>22</PageCount>
              <LanguageISO>en</LanguageISO>
              <Genre>Testing</Genre>
              <Web>https://example.com</Web>
            </ComicInfo>
            """))
        #expect(metadata.series == "Saga of Testing")
        #expect(metadata.number == "7")
        #expect(metadata.count == 12)
        #expect(metadata.title == "The Mock Menace")
        #expect(metadata.year == 1999)
        #expect(metadata.pageCount == 22)
        #expect(metadata.web == "https://example.com")
    }

    @Test func partialDocumentKeepsWhatExists() throws {
        let metadata = try #require(parse("<ComicInfo><Series>Solo</Series></ComicInfo>"))
        #expect(metadata.series == "Solo")
        #expect(metadata.title == nil)
        #expect(metadata.year == nil)
    }

    @Test func nonNumericNumericFieldsBecomeNil() throws {
        let metadata = try #require(parse("""
            <ComicInfo><Year>MCMXCIX</Year><PageCount>three</PageCount><Number>Annual 1</Number></ComicInfo>
            """))
        #expect(metadata.year == nil)
        #expect(metadata.pageCount == nil)
        #expect(metadata.number == "Annual 1") // Number is a string on purpose
    }

    @Test func nestedContainersAreIgnored() throws {
        let metadata = try #require(parse("""
            <ComicInfo><Title>Real</Title><Pages><Page Image="0"/></Pages></ComicInfo>
            """))
        #expect(metadata.title == "Real")
    }

    @Test func garbageReturnsNil() {
        #expect(parse("this is not xml at all") == nil)
    }

    @Test func truncatedDocumentKeepsCollectedFields() throws {
        let metadata = try #require(parse("<ComicInfo><Series>Cut</Series><Title>Off"))
        #expect(metadata.series == "Cut")
    }

    @Test func emptyDocumentYieldsEmptyMetadata() throws {
        let metadata = try #require(parse("<ComicInfo></ComicInfo>"))
        #expect(metadata.isEmpty)
    }
}
