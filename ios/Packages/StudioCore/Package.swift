// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "StudioCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "StudioCore", targets: ["StudioCore"])],
    dependencies: [.package(path: "../BlackjackCore"), .package(path: "../TrainingCore")],
    targets: [
        .target(name: "StudioCore", dependencies: ["BlackjackCore", "TrainingCore"]),
        .testTarget(name: "StudioCoreTests", dependencies: ["StudioCore"])
    ]
)
