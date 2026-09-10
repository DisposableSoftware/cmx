import UniformTypeIdentifiers

extension UTType {
    /// macOS declares public.cbz-archive natively (CoreTypes); the
    /// UTImportedTypeDeclarations entry in Info.plist is only a fallback.
    static let cbzArchive = UTType(importedAs: "public.cbz-archive")
}
