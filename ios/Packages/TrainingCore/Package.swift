// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrainingCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TrainingCore", targets: ["TrainingCore"])],
    targets: [
        .target(name: "TrainingCore"),
        .testTarget(name: "TrainingCoreTests", dependencies: ["TrainingCore"])
    ]
)
