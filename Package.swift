// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pointly",
    platforms: [
        .macOS(.v14)   // .onKeyPress requires 14.0
    ],
    products: [
        .executable(name: "Pointly", targets: ["Pointly"])
    ],
    targets: [
        .executableTarget(
            name: "Pointly",
            dependencies: [],
            path: "Pointly",
            exclude: [
                "Tests",
                "Pointly-Bridging-Header.h",
                "Pointly.entitlements",
                "Info.plist",
                "Products.storekit"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
