import Foundation
import ZIPFoundation

struct ZipArchiveGateway: ArchiveGateway {
    func openArchive(at url: URL) throws -> any ComicArchive {
        try ZipComicArchive(url: url)
    }
}

/// ZIPFoundation-backed archive. `Archive` is not thread-safe, so extraction
/// is serialized behind a lock — which is what justifies @unchecked Sendable.
final class ZipComicArchive: ComicArchive, @unchecked Sendable {
    let entryPaths: [String]
    private let archive: Archive
    private let lock = NSLock()

    init(url: URL) throws {
        archive = try Archive(url: url, accessMode: .read)
        entryPaths = archive.compactMap { $0.type == .file ? $0.path : nil }
    }

    func data(forEntry path: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = archive[path] else { throw ArchiveError.entryNotFound(path) }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }
}
