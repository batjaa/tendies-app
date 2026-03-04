// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TendiesApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TendiesApp",
            path: "Sources/TendiesApp"
        ),
    ]
)
