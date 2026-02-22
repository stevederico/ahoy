// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ahoy-voice",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ahoy-voice",
            path: "Sources/ahoy-voice"
        )
    ]
)
