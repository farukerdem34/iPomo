// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "iPomo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "iPomo", targets: ["iPomoApp"]),
        .library(name: "iPomoCore", targets: ["iPomoCore"]),
        .library(name: "iPomoUI", targets: ["iPomoUI"]),
    ],
    targets: [
        .target(
            name: "iPomoCore",
            path: "Sources/iPomoCore"
        ),
        .target(
            name: "iPomoUI",
            dependencies: ["iPomoCore"],
            path: "Sources/iPomoUI"
        ),
        .executableTarget(
            name: "iPomoApp",
            dependencies: ["iPomoUI"],
            path: "Sources/iPomoApp"
        ),
        .testTarget(
            name: "iPomoCoreTests",
            dependencies: ["iPomoCore"],
            path: "Tests/iPomoCoreTests"
        ),
        .testTarget(
            name: "iPomoAppTests",
            dependencies: ["iPomoUI", "iPomoCore"],
            path: "Tests/iPomoAppTests"
        ),
    ]
)
