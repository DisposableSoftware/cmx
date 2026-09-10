import Testing
@testable import CMXKit

@Suite struct PageListTests {
    @Test func sortsNumericallyNotLexicographically() {
        let pages = PageList.pages(fromEntries: ["page10.png", "page2.png", "page1.png"])
        #expect(pages.map(\.entryPath) == ["page1.png", "page2.png", "page10.png"])
    }

    @Test func filtersJunkEntries() {
        let pages = PageList.pages(fromEntries: [
            "__MACOSX/._page1.png",
            ".DS_Store",
            ".hidden.png",
            "Thumbs.db",
            "THUMBS.DB",
            "folder/",
            "notes.txt",
            "ComicInfo.xml",
            "page1.png",
        ])
        #expect(pages.map(\.entryPath) == ["page1.png"])
    }

    @Test func keepsNestedImagesAndDropsHiddenDirectories() {
        let pages = PageList.pages(fromEntries: [
            "book/ch1/page1.jpg",
            ".git/objects/page1.png",
            "book/ch1/page2.jpg",
        ])
        #expect(pages.map(\.entryPath) == ["book/ch1/page1.jpg", "book/ch1/page2.jpg"])
    }

    @Test func acceptsAllDocumentedExtensionsCaseInsensitively() {
        let entries = ["a.JPG", "b.jpeg", "c.PNG", "d.gif", "e.webp", "f.avif", "g.bmp", "h.tif", "i.TIFF"]
        #expect(PageList.pages(fromEntries: entries).count == entries.count)
    }

    @Test func emptyForImagelessArchive() {
        #expect(PageList.pages(fromEntries: ["ComicInfo.xml", "readme.txt"]).isEmpty)
    }
}
