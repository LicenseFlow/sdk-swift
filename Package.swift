// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LicenseFlow",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "LicenseFlow",
            targets: ["LicenseFlow"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LicenseFlow",
            dependencies: []
        ),
        .testTarget(
            name: "LicenseFlowTests",
            dependencies: ["LicenseFlow"]
        ),
    ]
)
