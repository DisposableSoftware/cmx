import Foundation

/// Owns one open archive for the life of a book: extraction, off-main decode,
/// a small distance-evicted cache, neighbor prefetch, and cancellation of
/// decodes the user has paged past.
actor ArchiveSession {
    private let archiveGateway: any ArchiveGateway
    private var archive: (any ComicArchive)?
    private var pages: [Page] = []
    private var cache: [Int: PageImage] = [:]
    private var inFlight: [Int: Task<PageImage, Error>] = [:]
    private var focus = 0

    /// Decoded pages farther than this from the current page are evicted,
    /// and their in-flight decodes cancelled.
    private let keepRadius = 2

    init(archiveGateway: any ArchiveGateway) {
        self.archiveGateway = archiveGateway
    }

    /// Opens the archive and returns its raw entry paths. Runs on the actor's
    /// executor, so the blocking I/O stays off the main actor.
    func open(url: URL) throws -> [String] {
        let opened = try archiveGateway.openArchive(at: url)
        archive = opened
        return opened.entryPaths
    }

    func data(forEntry path: String) throws -> Data {
        guard let archive else { throw ReaderError.archiveNotOpen }
        return try archive.data(forEntry: path)
    }

    func configure(pages: [Page]) {
        self.pages = pages
    }

    /// - Parameter refocus: pass false for a companion page, so fetching the
    ///   right-hand page of a spread does not drag the eviction window forward.
    func image(at index: Int, refocus: Bool = true) async throws -> PageImage {
        if refocus { focusOn(index) }
        if let cached = cache[index] { return cached }
        return try await ensureTask(index).value
    }

    func prefetch(around index: Int) {
        for neighbor in [index - 1, index + 1]
        where pages.indices.contains(neighbor)
            && cache[neighbor] == nil
            && inFlight[neighbor] == nil {
            _ = ensureTask(neighbor)
        }
    }

    private func focusOn(_ index: Int) {
        focus = index
        cache = cache.filter { abs($0.key - focus) <= keepRadius }
        for (i, task) in inFlight where abs(i - focus) > keepRadius {
            task.cancel()
        }
    }

    private func ensureTask(_ index: Int) -> Task<PageImage, Error> {
        if let existing = inFlight[index] { return existing }
        guard let archive, pages.indices.contains(index) else {
            return Task { throw ReaderError.pageOutOfRange }
        }
        let path = pages[index].entryPath
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data = try archive.data(forEntry: path)
            try Task.checkCancellation()
            guard let image = ImageDecoder.decode(data) else {
                throw ReaderError.undecodablePage(path)
            }
            return image
        }
        inFlight[index] = task
        Task { await self.finish(index, with: task) }
        return task
    }

    private func finish(_ index: Int, with task: Task<PageImage, Error>) async {
        let image = try? await task.value
        if inFlight[index] == task { inFlight[index] = nil }
        if let image, abs(index - focus) <= keepRadius {
            cache[index] = image
        }
    }
}
