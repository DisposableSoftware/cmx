import Foundation

/// What a file actually is, by magic bytes rather than by extension.
///
/// RARs mislabeled as `.cbz` are common in the wild — the same reason
/// cbz-tool sniffs content instead of trusting the extension.
enum ArchiveFormat: Equatable {
    case zip
    case rar
    case unrecognized

    /// Reads only the leading bytes; never loads the file.
    static func detect(at url: URL) -> ArchiveFormat {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unrecognized }
        defer { try? handle.close() }
        guard let magic = try? handle.read(upToCount: 4), magic.count == 4 else {
            return .unrecognized
        }
        return format(ofMagic: [UInt8](magic))
    }

    static func format(ofMagic magic: [UInt8]) -> ArchiveFormat {
        guard magic.count >= 4 else { return .unrecognized }
        // "Rar!" — shared prefix of the RAR 4.x and 5.x signatures.
        if magic[0...3] == [0x52, 0x61, 0x72, 0x21] { return .rar }
        // "PK" then a local-file, central-directory, or spanned marker.
        if magic[0] == 0x50, magic[1] == 0x4B,
           [0x03, 0x05, 0x07].contains(magic[2]) { return .zip }
        return .unrecognized
    }
}
