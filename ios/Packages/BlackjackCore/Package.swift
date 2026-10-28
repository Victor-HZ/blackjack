// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlackjackCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BlackjackCore", targets: ["BlackjackCore"])],
    targets: [
        .target(name: "BlackjackCore"),
        .testTarget(name: "BlackjackCoreTests", dependencies: ["BlackjackCore"])
    ]
)
