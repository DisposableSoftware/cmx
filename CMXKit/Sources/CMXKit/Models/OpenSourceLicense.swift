import Foundation

/// Attribution for third-party code. CMXKit declares this because CMXKit is
/// what depends on these packages — when a dependency is added or dropped
/// here, its attribution travels with it.
public struct OpenSourceLicense: Identifiable, Sendable {
    public let name: String
    public let version: String
    public let url: String
    public let licenseName: String
    /// Full text, because MIT requires the notice to ship with the app.
    public let licenseText: String

    public var id: String { name }

    public init(
        name: String, version: String, url: String,
        licenseName: String, licenseText: String
    ) {
        self.name = name
        self.version = version
        self.url = url
        self.licenseName = licenseName
        self.licenseText = licenseText
    }
}

public extension OpenSourceLicense {
    /// Everything cmx links that it did not write. ZIPFoundation is the only
    /// third-party dependency; it sits behind `ArchiveGateway`.
    static let all: [OpenSourceLicense] = [zipFoundation]

    static let zipFoundation = OpenSourceLicense(
        name: "ZIPFoundation",
        version: "0.9.20",
        url: "https://github.com/weichsel/ZIPFoundation",
        licenseName: "MIT License",
        licenseText: """
            MIT License

            Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)

            Permission is hereby granted, free of charge, to any person obtaining a copy \
            of this software and associated documentation files (the "Software"), to deal \
            in the Software without restriction, including without limitation the rights \
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
            copies of the Software, and to permit persons to whom the Software is \
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all \
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
            SOFTWARE.
            """
    )
}
