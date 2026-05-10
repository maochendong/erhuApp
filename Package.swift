// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ErhuApp",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "ErhuApp", targets: ["ErhuApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ErhuApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
