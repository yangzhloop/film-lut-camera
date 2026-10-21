// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LutliCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LutliCore", targets: ["LutliCore"])],
    targets: [
        .target(name: "LutliCore"),
        .testTarget(name: "LutliCoreTests", dependencies: ["LutliCore"])
    ]
)
