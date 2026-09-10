// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CMXKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "CMXKit", targets: ["CMXKit"])
    ],
    dependencies: [
        // The one third-party dependency. It stays behind ArchiveGateway so it
        // can be swapped without touching another file.
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "CMXKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CMXKitTests",
            dependencies: ["CMXKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
