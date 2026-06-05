// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pointly",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pointly", targets: ["Pointly"])
    ],
    targets: [
        .executableTarget(
            name: "Pointly",
            dependencies: [],
            path: "Sources",
            sources: [
                "PointlyTestApp.swift",
                "ShapeTools.swift"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
