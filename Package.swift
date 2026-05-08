// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ErhuApp",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .executable(name: "ErhuApp", targets: ["ErhuApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ErhuApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
