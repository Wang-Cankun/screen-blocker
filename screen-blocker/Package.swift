// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "screen-blocker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "screen-blocker",
            path: "Sources"
        )
    ]
)
