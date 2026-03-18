// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tranfEasy",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "TransferKit",
            path: "Sources/TransferKit"
        ),
        .executableTarget(
            name: "tranfEasy",
            dependencies: ["TransferKit"],
            path: "Sources/tranfEasy",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "TransferKitTests",
            dependencies: ["TransferKit"],
            path: "Tests/TransferKitTests"
        )
    ]
)
