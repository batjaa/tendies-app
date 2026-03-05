// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TendiesApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "TendiesApp",
            path: "Sources/TendiesApp"
        ),
        .testTarget(
            name: "TendiesAppTests",
            dependencies: [
                "TendiesApp",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/TendiesAppTests"
        ),
    ]
)
