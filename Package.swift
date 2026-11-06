// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Citadel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CitadelCore", targets: ["CitadelCore"]),
        .library(name: "CitadelUI", targets: ["CitadelUI"]),
        .executable(name: "citadel", targets: ["citadel"]),
        .executable(name: "ctdl", targets: ["ctdl"]),
        .executable(name: "CitadelApp", targets: ["CitadelApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "CitadelCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "CitadelUI",
            dependencies: [
                "CitadelCore"
            ]
        ),
        .executableTarget(
            name: "citadel",
            dependencies: [
                "CitadelCore"
            ]
        ),
        .executableTarget(
            name: "ctdl",
            dependencies: [
                "CitadelCore"
            ]
        ),
        .executableTarget(
            name: "CitadelApp",
            dependencies: [
                "CitadelCore",
                "CitadelUI"
            ]
        ),
        .executableTarget(
            name: "citadel-tests",
            dependencies: [
                "CitadelCore",
                "CitadelUI"
            ],
            path: "Tests/CitadelTests"
        )
    ]
)
