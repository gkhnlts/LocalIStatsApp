// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LocalIStats",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalIStats", targets: ["LocalIStats"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LocalIStats",
            dependencies: [],
            path: "Sources"
        )
    ]
)
