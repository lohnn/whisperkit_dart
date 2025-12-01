// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperWrapper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WhisperWrapper",
            type: .dynamic,
            targets: ["WhisperWrapper"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "WhisperWrapper",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
    ]
)
